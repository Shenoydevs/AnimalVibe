--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local signals = require(ServerScriptService.Server.signals)
local CharacterSignals = signals.CharacterSignals

local ShareItemComponent = Component.new({ Tag = "ShareItem" })

function ShareItemComponent:Construct()
	self._trove = Trove.new()

	local primaryPart : BasePart? = self.Instance.PrimaryPart
	assert(primaryPart, `[ShareItemComponent] {self.Instance.Name} is missing PrimaryPart`)

	local prompt : ProximityPrompt? = primaryPart:FindFirstChildWhichIsA("ProximityPrompt")
	assert(prompt, `[ShareItemComponent] {self.Instance.Name} Part is missing ProximityPrompt`)

	prompt.ActionText = `Use on {self.Instance.Name}!`

	self._prompt = prompt :: ProximityPrompt
end

function ShareItemComponent:Start()
	self._trove:Connect(self._prompt.Triggered, function(player : Player)
		local targetPlayer: Player? = Players:GetPlayerFromCharacter(self.Instance)
		if not targetPlayer then return end
		CharacterSignals.ShareItem:Fire(player, targetPlayer)
	end)
end

function ShareItemComponent:Stop()
	self._trove:Clean()
end

return ShareItemComponent
