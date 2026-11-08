--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages

local _package = require(Packages.DataService).client

local DataController = {}

function DataController:OnStart(): ()
	_package:init()
end


export type DataController = typeof(DataController)

return DataController
