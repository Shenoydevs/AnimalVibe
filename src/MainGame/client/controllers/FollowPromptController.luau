--!strict
local _collectionService = game:GetService("CollectionService")
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _runService = game:GetService("RunService")

local _troveModule = require(_replicatedStorage.Packages.Trove)
local _followConfig = require(_replicatedStorage.Shared.config.FollowPromptConfig)
local _characterUtils = require(_replicatedStorage.Shared.utils.CharacterUtils)

type zoneEntry = { anchor: Attachment?, radius: number, height: number, childAdded: RBXScriptConnection? }

-- Generous upper bound on any prompt's MaxActivationDistance, used only to skip far zones cheaply.
local _maxPromptDistance: number = 20

local _trove = _troveModule.new()
local _zones: { [BasePart]: zoneEntry } = {}
local followPromptController = {}

local function _track(instance: Instance): ()
	if not instance:IsA("BasePart") then
		return
	end
	local previous: zoneEntry? = _zones[instance]
	if previous and previous.childAdded then
		previous.childAdded:Disconnect()
	end
	_zones[instance] = {
		anchor = nil,
		childAdded = nil,
		radius = (instance:GetAttribute(_followConfig.radiusAttribute) :: number?) or instance.Size.X / 2,
		height = (instance:GetAttribute(_followConfig.heightAttribute) :: number?) or 0,
	}
end

local function _applyClientDistance(prompt: Instance): ()
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local distance: number? = prompt:GetAttribute(_followConfig.clientDistanceAttribute) :: number?
	if distance then
		prompt.MaxActivationDistance = distance
	end
end

local function _adoptAnchor(entry: zoneEntry, anchor: Attachment): ()
	if entry.childAdded then
		entry.childAdded:Disconnect()
	end
	entry.anchor = anchor
	for _, child in anchor:GetChildren() do
		_applyClientDistance(child)
	end
	entry.childAdded = anchor.ChildAdded:Connect(_applyClientDistance)
end

-- Moves the anchor locally only: each player sees the prompt on the zone edge nearest them.
local function _placeAnchor(zone: BasePart, entry: zoneEntry, rootPosition: Vector3): ()
	local center: Vector3 = zone.Position
	local dx: number, dz: number = rootPosition.X - center.X, rootPosition.Z - center.Z
	local reach: number = entry.radius + _maxPromptDistance + _followConfig.updateMargin
	if dx * dx + dz * dz > reach * reach then
		return
	end
	local anchor: Attachment? = entry.anchor
	if not anchor or anchor.Parent ~= zone then
		local found: Instance? = zone:FindFirstChild(_followConfig.anchorName)
		if not found or not found:IsA("Attachment") then
			return
		end
		anchor = found
		_adoptAnchor(entry, found)
	end
	local flat: Vector3 = Vector3.new(dx, 0, dz)
	if flat.Magnitude > entry.radius then
		flat = flat.Unit * entry.radius
	end
	local height: number = math.max(center.Y + entry.height, rootPosition.Y - 1)
	;(anchor :: Attachment).WorldPosition = Vector3.new(center.X + flat.X, height, center.Z + flat.Z)
end

function followPromptController:OnStart(): ()
	for _, instance in _collectionService:GetTagged(_followConfig.tag) do
		_track(instance)
	end
	_trove:Connect(_collectionService:GetInstanceAddedSignal(_followConfig.tag), _track)
	_trove:Connect(_collectionService:GetInstanceRemovedSignal(_followConfig.tag), function(instance: Instance): ()
		if not instance:IsA("BasePart") then
			return
		end
		local entry: zoneEntry? = _zones[instance]
		if entry and entry.childAdded then
			entry.childAdded:Disconnect()
		end
		_zones[instance] = nil
	end)

	_trove:Connect(_runService.Heartbeat, function(): ()
		local root: BasePart? = _characterUtils.getPlayerRoot(_players.LocalPlayer)
		if not root then
			return
		end
		local rootPosition: Vector3 = root.Position
		for zone, entry in _zones do
			_placeAnchor(zone, entry, rootPosition)
		end
	end)
end

export type followPromptController = typeof(followPromptController)
return followPromptController
