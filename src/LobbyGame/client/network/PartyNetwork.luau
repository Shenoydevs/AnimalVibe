local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networker = require(ReplicatedStorage.Packages.Networker)
local Network = require(ReplicatedStorage.Shared.network)
local NetworkClientType = require(ReplicatedStorage.Shared.types.NetworkClientType)

local _handlers: { [string]: (...any) -> () } = {}
local _networker: NetworkClientType.NetworkerClient? = Networker.client.new(Network.Party, _handlers)

return {
	handlers = _handlers,
	fire = function(method: string, ...: any?)
		if not _networker then
			return
		end

		_networker:fire(method, ...)
	end,
}
