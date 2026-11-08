--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")

local _networker = require(_replicatedStorage.Packages.Networker)
local _troveModule = require(_replicatedStorage.Packages.Trove)

local _campfireConfig = require(_replicatedStorage.Shared.config.CampfireConfig)
local _campfireNetwork = require(_replicatedStorage.Shared.network.CampfireNetwork)
local _campfireTypes = require(_replicatedStorage.Shared.types.CampfireTypes)

type campfireZone = _campfireTypes.campfireZone

local _zonesFolder: Folder? = nil
local _zones: { campfireZone } = {}
local _trove = _troveModule.new()
local _visualTrove = _troveModule.new()
local _session: number = 0
local _cancelled: boolean = true

local campfireController = {}

local function _createCircle(zone: campfireZone, parent: Instance): ()
	local circleConfig = _campfireConfig.circle
	local circle: Part = Instance.new("Part")
	circle.Name = "CampfireZoneCircle"
	circle.Shape = Enum.PartType.Cylinder
	circle.Size = Vector3.new(circleConfig.thickness, zone.radius * 2, zone.radius * 2)
	local groundPosition: Vector3 = zone.groundPosition
	local centerY: number = groundPosition.Y + (circleConfig.thickness / 2 - circleConfig.embed)
	circle.CFrame = CFrame.new(groundPosition.X, centerY, groundPosition.Z) * CFrame.Angles(0, 0, math.rad(90))
	circle.Anchored = true
	circle.CanCollide = false
	circle.CanQuery = false
	circle.CanTouch = false
	circle.CastShadow = false
	circle.Material = Enum.Material.Neon
	circle.Color = circleConfig.color
	circle.Transparency = circleConfig.transparency
	circle.Parent = parent
end

function campfireController:onCampfireList(zones: { campfireZone }): ()
	if _cancelled then
		return
	end
	_visualTrove:Clean()

	local folder: Folder = _visualTrove:Add(Instance.new("Folder"))
	folder.Name = "CampfireZones"
	for _, zone in zones do
		_createCircle(zone, folder)
	end
	folder.Parent = workspace
	_zonesFolder = folder
	_zones = zones
end

function campfireController:getZones(): { campfireZone }
	return _zones
end

function campfireController.stop(): ()
	_cancelled = true
	_session += 1
	_trove:Clean()
	_visualTrove:Clean()
	_zonesFolder = nil
	_zones = {}
end

function campfireController:OnStart(): ()
	campfireController.stop()
	_cancelled = false
	local session: number = _session

	_trove:Add(task.defer(function(): ()
		local networker: _networker.Client =
			_trove:Add(_networker.client.new(_campfireNetwork.campfire, campfireController), "destroy")
		local zones: { campfireZone }? = networker:fetch("getCampfires")
		if _cancelled or session ~= _session then
			return
		end
		if zones and #zones > 0 and not _zonesFolder then
			campfireController:onCampfireList(zones)
		end
	end))
end

export type campfireController = typeof(campfireController)
return campfireController
