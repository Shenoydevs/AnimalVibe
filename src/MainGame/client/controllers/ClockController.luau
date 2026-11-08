--!strict
local _collectionService = game:GetService("CollectionService")
local _lighting = game:GetService("Lighting")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _troveModule = require(_replicatedStorage.Packages.Trove)

local _trove = _troveModule.new()
local _clockTroves: { [Instance]: typeof(_troveModule.new()) } = {}
local _labels: { [Instance]: TextLabel } = {}
local _lastHour: number = -1
local clockController = {}

local function _formatHour(hour: number): string
	local displayHour: number = hour % 12
	if displayHour == 0 then displayHour = 12 end
	local period: string = if hour >= 12 then "PM" else "AM"
	return `{displayHour}:00 {period}`
end

local function _refreshClock(instance: Instance): ()
	_labels[instance] = nil
	if not _clockTroves[instance] or not instance:IsDescendantOf(workspace) then return end
	local surfaceGui: SurfaceGui? = instance:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surfaceGui then return end
	local label: TextLabel? = surfaceGui:FindFirstChildWhichIsA("TextLabel", true)
	if not label then return end
	_labels[instance] = label
	label.Text = _formatHour(math.floor(_lighting.ClockTime))
end

local function _trackClock(instance: Instance): ()
	if _clockTroves[instance] then return end
	local clockTrove = _trove:Extend()
	_clockTroves[instance] = clockTrove
	clockTrove:Connect(instance.AncestryChanged, function(): ()
		_refreshClock(instance)
	end)
	clockTrove:Connect(instance.DescendantAdded, function(descendant: Instance): ()
		if descendant:IsA("SurfaceGui") or descendant:IsA("TextLabel") then _refreshClock(instance) end
	end)
	clockTrove:Connect(instance.DescendantRemoving, function(descendant: Instance): ()
		local label: TextLabel? = _labels[instance]
		if label and (label == descendant or label:IsDescendantOf(descendant)) then _labels[instance] = nil end
	end)
	_refreshClock(instance)
end

local function _untrackClock(instance: Instance): ()
	local clockTrove = _clockTroves[instance]
	_clockTroves[instance] = nil
	_labels[instance] = nil
	if clockTrove then _trove:Remove(clockTrove) end
end

function clockController:OnStart(): ()
	_trove:Connect(_collectionService:GetInstanceAddedSignal("Clock"), _trackClock)
	_trove:Connect(_collectionService:GetInstanceRemovedSignal("Clock"), _untrackClock)
	for _, instance in _collectionService:GetTagged("Clock") do _trackClock(instance) end
	_trove:Connect(_lighting:GetPropertyChangedSignal("ClockTime"), function(): ()
		local hour: number = math.floor(_lighting.ClockTime)
		if hour == _lastHour then return end
		_lastHour = hour
		local text: string = _formatHour(hour)
		for _, label in _labels do label.Text = text end
	end)
end

export type clockController = typeof(clockController)
return clockController
