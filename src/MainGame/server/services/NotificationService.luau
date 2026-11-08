--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Networker = require(Packages.Networker)

local NotificationNetwork = require(ReplicatedStorage.Shared.network.NotificationNetwork)
local NotificationTypes = require(ReplicatedStorage.Shared.types.NotificationTypes)

type NetworkerServer = Networker.Server
type NotificationKind = NotificationTypes.NotificationKind

local _networker: NetworkerServer

local NotificationService = {}

function NotificationService:notify(player: Player, kind: NotificationKind, message: string, duration: number, priority: number): ()
	_networker:fire(player, "onNotification", {
		kind = kind,
		message = message,
		duration = duration,
		priority = priority,
	})
end

function NotificationService:notifyAll(kind: NotificationKind, message: string, duration: number, priority: number): ()
	_networker:fireAll("onNotification", {
		kind = kind,
		message = message,
		duration = duration,
		priority = priority,
	})
end

function NotificationService:transition(player: Player, message: string, duration: number): ()
	_networker:fire(player, "onTransition", { message = message, duration = duration })
end

function NotificationService:transitionAll(message: string, duration: number): ()
	_networker:fireAll("onTransition", { message = message, duration = duration })
end

function NotificationService:OnStart(): ()
	_networker = Networker.server.new(NotificationNetwork.Notification)
end

export type NotificationService = typeof(NotificationService)
return NotificationService
