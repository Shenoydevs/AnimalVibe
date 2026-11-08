--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.config.BoulderConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)

type Puller = {
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	handle: BasePart,
	prompt: ProximityPrompt,
	rope: RopeConstraint,
	trove: typeof(Trove.new()),
	input: Vector3,
	lastInput: number,
	overstretch: number,
}

local BoulderPullSession = {}
BoulderPullSession.__index = BoulderPullSession

export type Session = typeof(setmetatable({} :: {
	model: Model,
	_trove: typeof(Trove.new()),
	_pullers: { [Player]: Puller },
	_direction: Vector3,
	_distance: number,
	_travel: number,
	_start: CFrame,
	_destroyed: boolean,
	_changed: (Player, boolean) -> (),
}, BoulderPullSession))

function BoulderPullSession.new(model: Model, changed: (Player, boolean) -> ()): Session
	local direction = model:GetAttribute("pullDirection")
	local distance = model:GetAttribute("pullDistance")
	assert(typeof(direction) == "Vector3" and direction.Magnitude > 0.9, "Boulder needs a pullDirection")
	assert(typeof(distance) == "number" and distance > 0, "Boulder needs a pullDistance")
	local self: Session = setmetatable({
		model = model,
		_trove = Trove.new(),
		_pullers = {},
		_direction = direction.Unit,
		_distance = distance,
		_travel = 0,
		_start = model:GetPivot(),
		_destroyed = false,
		_changed = changed,
	}, BoulderPullSession)
	local ropes = assert(model:FindFirstChild("PullRopes"), "Boulder needs PullRopes")
	for _, handle in ropes:GetChildren() do
		if not handle:IsA("BasePart") then continue end
		local prompt = handle:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then
			self._trove:Connect(prompt.Triggered, function(player: Player)
				self:attach(player, handle)
			end)
		end
	end
	return self
end

function BoulderPullSession._refresh(self: Session): ()
	local count = 0
	for _ in self._pullers do count += 1 end
	self.model:SetAttribute("pullerCount", count)
end

function BoulderPullSession.attach(self: Session, player: Player, handle: BasePart): boolean
	if self._destroyed or self.model:GetAttribute("cleared") == true or self._pullers[player] then return false end
	if not self.model:IsDescendantOf(workspace) or handle.Parent ~= self.model:FindFirstChild("PullRopes") then return false end
	local prompt = handle:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt or not prompt.Enabled then return false end
	local rope = handle:FindFirstChild("PullRope")
	if not rope or not rope:IsA("RopeConstraint") or not rope.Attachment0 or not rope.Attachment1 then return false end
	local count = 0
	for _, puller in self._pullers do
		if puller.handle == handle then return false end
		count += 1
	end
	if count >= Config.maxPullers then return false end
	local character = player.Character
	if not character or character:GetAttribute("alive") ~= true
		or character:GetAttribute("pullingCart") == true or character:GetAttribute("pullingBoulder") == true then return false end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not root:IsDescendantOf(workspace)
		or not humanoid or humanoid.Health <= 0 or humanoid.Sit
		or (root.Position - handle.Position).Magnitude > Config.interactDistance then return false end
	-- All rope slots are outside the mouth; reject an interaction through the seal.
	if (root.Position - handle.Position):Dot(self._direction) < -2 then return false end
	local trove = Trove.new()
	local puller: Puller = {
		character = character, root = root, humanoid = humanoid, handle = handle,
		prompt = prompt, rope = rope, trove = trove, input = Vector3.zero, lastInput = -math.huge, overstretch = 0,
	}
	self._pullers[player] = puller
	prompt.Enabled = false
	character:SetAttribute("pullingBoulder", true)
	local walkSpeed = character:GetAttribute("walkSpeed")
	if typeof(walkSpeed) == "number" then humanoid.WalkSpeed = math.min(humanoid.WalkSpeed, walkSpeed) end
	local attachment = trove:Add(Instance.new("Attachment"))
	attachment.Name = "BoulderRopeAttachment"
	attachment.Parent = root
	local idleTip = rope.Attachment1
	local idleLength = rope.Length
	-- Transfer the loose end to HumanoidRootPart; the other end stays on the boulder.
	-- Allow the current reach on pickup so grabbing it does not snap the player backward.
	rope.Length = math.max(
		Config.ropeHandleOffset + 4 + Config.tautDistance,
		(rope.Attachment0.WorldPosition - attachment.WorldPosition).Magnitude + 1
	)
	rope.Attachment1 = attachment
	trove:Add(function()
		rope.Attachment1 = idleTip
		rope.Length = idleLength
	end)
	trove:Connect(humanoid.Died, function() self:detach(player) end)
	trove:Connect(character:GetAttributeChangedSignal("alive"), function()
		if character:GetAttribute("alive") ~= true then self:detach(player) end
	end)
	trove:Connect(player.CharacterRemoving, function() self:detach(player) end)
	trove:Connect(humanoid.StateChanged, function(_, state)
		if state == Enum.HumanoidStateType.Jumping then self:detach(player) end
	end)
	self:_refresh()
	self._changed(player, true)
	return true
end

function BoulderPullSession.detach(self: Session, player: Player): ()
	local puller = self._pullers[player]
	if not puller then return end
	self._pullers[player] = nil
	puller.trove:Destroy()
	puller.character:SetAttribute("pullingBoulder", false)
	puller.prompt.Enabled = not self._destroyed and self.model:GetAttribute("cleared") ~= true
	self:_refresh()
	self._changed(player, false)
end

function BoulderPullSession.setInput(self: Session, player: Player, direction: Vector3): ()
	local puller = self._pullers[player]
	if not puller then return end
	local now = os.clock()
	if now - puller.lastInput < Config.pullInputInterval / 2 then return end
	puller.input = direction
	puller.lastInput = now
end

function BoulderPullSession._clearSeal(self: Session): ()
	local reference = self.model:FindFirstChild("EntranceSeal")
	if reference and reference:IsA("ObjectValue") and reference.Value then
		reference.Value:Destroy()
	end
	local container = self.model.Parent
	if container then container:SetAttribute("blocked", false) end
end

function BoulderPullSession._complete(self: Session): ()
	self.model:SetAttribute("cleared", true)
	self.model:SetAttribute("pullProgress", 1)
	self:_clearSeal()
	for player in self._pullers do self:detach(player) end
	for _, descendant in self.model:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then descendant.Enabled = false end
	end
end

function BoulderPullSession.tick(self: Session, dt: number): ()
	if self._destroyed or self.model:GetAttribute("cleared") == true then return end
	local speed = 0
	local helperPower = 0
	local contributors = 0
	local roomToMove = 0
	local now = os.clock()
	local detach = {}
	for player, puller in self._pullers do
		if player.Character ~= puller.character or puller.character:GetAttribute("alive") ~= true
			or not puller.root:IsDescendantOf(workspace) or puller.humanoid.Health <= 0
			or puller.humanoid.Sit or puller.character:GetAttribute("pullingCart") == true then
			table.insert(detach, player)
			continue
		end
		local offset = puller.root.Position - puller.handle.Position
		local length = offset.Magnitude
		if length > Config.maxRopeDistance then
			puller.overstretch += dt
			if puller.overstretch >= Config.ropeBreakGraceTime then table.insert(detach, player) end
			continue
		end
		puller.overstretch = 0
		local outwardGap = offset:Dot(self._direction)
		local anchor = puller.rope.Attachment0
		local taut = anchor ~= nil
			and (puller.root.Position - anchor.WorldPosition).Magnitude >= puller.rope.Length - 0.5
		-- A taut physical rope can stop the character's velocity. Keep responding
		-- to fresh outward walking input under tension so extraction cannot stall.
		if now - puller.lastInput > Config.pullInputTimeout or puller.input:Dot(self._direction) < 0.25
			or (not taut and puller.root.AssemblyLinearVelocity:Dot(self._direction) < 0.5)
			or puller.humanoid.FloorMaterial == Enum.Material.Air or outwardGap <= Config.slackDistance then continue end
		local tension = math.clamp((outwardGap - Config.slackDistance) / (Config.tautDistance - Config.slackDistance), 0, 1)
		local surge = math.clamp((outwardGap - Config.tautDistance) / (Config.surgeDistance - Config.tautDistance), 0, 1)
		local walkSpeed = puller.character:GetAttribute("walkSpeed")
		local baseSpeed = if typeof(walkSpeed) == "number" and walkSpeed > 0 and walkSpeed < math.huge then walkSpeed else 16
		local modifier = puller.character:GetAttribute("cartModifier")
		local power = if typeof(modifier) == "number" and modifier == modifier then math.clamp(modifier, 0.5, 3) else 1
		speed = math.max(speed, baseSpeed * Config.soloSpeedMultiplier * power * tension * (1 + surge))
		helperPower += power
		contributors += 1
		roomToMove = math.max(roomToMove, outwardGap - Config.slackDistance)
	end
	for _, player in detach do self:detach(player) end
	if contributors == 0 then return end
	speed = math.min(Config.maxPullSpeed, speed * (1 + Config.helperEfficiency * helperPower * (contributors - 1) / contributors))
	local step = math.min(speed * math.min(dt, 0.1), roomToMove, self._distance - self._travel)
	if step <= 0 then return end
	self._travel += step
	-- A fixed extraction direction prevents the rock from being pushed back into
	-- the cave or steered into the terrain. Players retain normal cart-style movement.
	self.model:PivotTo(self._start + self._direction * self._travel)
	self.model:SetAttribute("pullProgress", self._travel / self._distance)
	if self._travel >= self._distance then self:_complete() end
end

function BoulderPullSession.destroy(self: Session): ()
	if self._destroyed then return end
	self._destroyed = true
	for player in self._pullers do self:detach(player) end
	self:_clearSeal()
	self._trove:Destroy()
end

return BoulderPullSession
