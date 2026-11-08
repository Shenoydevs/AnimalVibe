--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local CharacterUtils = require(ReplicatedStorage.Shared.utils.CharacterUtils)

export type Swing = {
	startedAt: number,
	hitCount: number,
	hitTargets: { [Model]: boolean },
}

export type Attacker = {
	root: BasePart,
	damage: number,
}

local SwingSession = {}

function SwingSession.begin(swings: { [Player]: Swing }, player: Player, targets: any): (Swing?, Attacker?)
	if type(targets) ~= "table" or #targets == 0 then return nil, nil end

	local character: Model? = player.Character
	if not character or character:GetAttribute("alive") ~= true then return nil, nil end

	local root: BasePart? = CharacterUtils.getRoot(character)
	if not root then return nil, nil end

	local damageAttr = character:GetAttribute("attackDamage")
	local cooldownAttr = character:GetAttribute("attackSpeed")
	if type(damageAttr) ~= "number" or damageAttr <= 0 then return nil, nil end
	if type(cooldownAttr) ~= "number" or cooldownAttr <= 0 then return nil, nil end

	local now: number = os.clock()
	local previous: Swing? = swings[player]
	local swing: Swing

	if previous and now - previous.startedAt < CombatConfig.swingWindow then
		swing = previous
	else
		if previous and now - previous.startedAt < cooldownAttr * CombatConfig.cooldownTolerance then
			return nil, nil
		end
		swing = { startedAt = now, hitCount = 0, hitTargets = {} }
		swings[player] = swing
	end

	return swing, { root = root, damage = damageAttr }
end

function SwingSession.eachHit<T>(
	swing: Swing,
	attacker: Attacker,
	targets: { any },
	resolve: (target: any) -> (T?, Vector3?),
	apply: (target: Model, resolved: T) -> ()
): ()
	for index = 1, math.min(#targets, CombatConfig.maxTargetsPerSwing) do
		if swing.hitCount >= CombatConfig.maxTargetsPerSwing then break end

		local target = targets[index]
		local resolved: T?, position: Vector3? = resolve(target)
		if resolved == nil or position == nil then continue end
		if swing.hitTargets[target] then continue end
		if ((position :: Vector3) - attacker.root.Position).Magnitude > CombatConfig.maxHitDistance then continue end

		swing.hitTargets[target] = true
		swing.hitCount += 1
		apply(target, resolved :: T)
	end
end

return SwingSession
