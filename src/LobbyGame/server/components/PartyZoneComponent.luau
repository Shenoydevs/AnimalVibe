--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local QuickZone = require(ReplicatedStorage.Packages.QuickZone)
local Trove = require(ReplicatedStorage.Packages.Trove)
local enums = require(ReplicatedStorage.Shared.enums)
local signals = require(ServerScriptService.Server.signals)

local PartySignals = signals.PartySignals
local PartyZoneGui = ReplicatedStorage.Assets.GUIs.PartyZoneGui
local PartyStateEnum = enums.PartyState

local _messages = {
	[PartyStateEnum.EMPTY] = "Waiting for players...",
	[PartyStateEnum.CREATING] = "Creating party",
	[PartyStateEnum.INTERMISSION] = "Waiting for players (%s/%s)...",
	[PartyStateEnum.STARTING] = "Starting match...",
}

-- One tracked player group serves every party zone.
local _players = QuickZone.Group.players()

local PartyZoneComponent = Component.new({ Tag = "PartyZone" })

function PartyZoneComponent:Construct()
	self._trove = Trove.new()

	local primaryPart = self.Instance.PrimaryPart
	assert(primaryPart, `[PartyZoneComponent] {self.Instance.Name} is missing a PrimaryPart`)

	self._primaryPart = primaryPart
	self._isOpen = true

	self:_createGui()

	self.Instance:SetAttribute("IsOpen", true)
	self.Instance:SetAttribute("State", PartyStateEnum.EMPTY)
end

function PartyZoneComponent:Start()
	-- The zone is the cage's box: joining places members inside it, and walking out of the cage exits.
	local zone = QuickZone.Zone.fromPart(self._primaryPart)
	local observer = QuickZone.Observer.new({ groups = { _players }, zones = { zone } })
	self._trove:Add(zone, "destroy")
	self._trove:Add(observer, "destroy")

	observer:onPlayerEnter(function(player: Player)
		if self._isOpen then
			PartySignals.PlayerEntered:Fire(self.Instance, player)
		end
	end)

	observer:onPlayerExit(function(player: Player)
		PartySignals.PlayerExited:Fire(self.Instance, player)
	end)

	self._trove:Connect(self.Instance:GetAttributeChangedSignal("IsOpen"), function()
		self:_onIsOpenChanged()
	end)

	self._trove:Connect(self.Instance:GetAttributeChangedSignal("State"), function()
		self:_onStateChanged()
	end)

	self._trove:Connect(self.Instance:GetAttributeChangedSignal("MemberCount"), function()
		self:_onStateChanged()
	end)

	self._trove:Connect(self.Instance:GetAttributeChangedSignal("Duration"), function()
		self:_onDurationChanged()
	end)

	self:_onIsOpenChanged()
	self:_onStateChanged()
end

function PartyZoneComponent:Stop()
	self._trove:Clean()
end

function PartyZoneComponent:_onIsOpenChanged()
	local isOpen = self.Instance:GetAttribute("IsOpen")
	self._isOpen = isOpen
end

function PartyZoneComponent:_onStateChanged()
	local state = self.Instance:GetAttribute("State")
	local template = _messages[state] or ""

	if state == PartyStateEnum.INTERMISSION then
		local count = self.Instance:GetAttribute("MemberCount") or 0
		local max = self.Instance:GetAttribute("MaxPlayers") or 0

		self._label.Text = string.format(template, count, max)
	else
		self._label.Text = template
	end
end

function PartyZoneComponent:_onDurationChanged()
	local value = self.Instance:GetAttribute("Duration") or 0

	self._timer.Visible = value > 0
	if value > 0 then
		self._timer.Text = tostring(value)
	end
end

function PartyZoneComponent:_createGui()
	local gui = PartyZoneGui:Clone()
	gui.Adornee = self._primaryPart
	gui.Parent = self._primaryPart

	self._label = gui.Wrapper.Label
	self._timer = gui.Wrapper.Timer
end

return PartyZoneComponent
