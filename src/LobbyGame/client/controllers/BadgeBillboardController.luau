--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)

local BadgeConfig = require(ReplicatedStorage.Common.config.BadgeConfig)

local _playerTroves = {}

local Private = {}
local Shared = {}

function Private._renderBadge(player, stroke, innerBase, icon)
	local badgeId = player:GetAttribute("equippedBadgeId")
	local badge = BadgeConfig.badges[badgeId]
	stroke.Visible = badge ~= nil
	if not badge then
		return
	end

	local color = BadgeConfig.rarityColors[badge.rarity]
	stroke.ImageColor3 = color
	innerBase.ImageColor3 = color
	icon.Image = badge.icon
end

function Private._createBillboard(player, character, rootPart, template, trove)
	local billboard = template:Clone()
	trove:Add(billboard)
	billboard.Adornee = rootPart

	local base = billboard:WaitForChild("PlayerName"):WaitForChild("Base")
	local displayName: TextLabel = base:WaitForChild("PlayerName")
	local userName: TextLabel = base:WaitForChild("UserName")
	local playerIcon: ImageLabel = base:WaitForChild("PlayerPFP"):WaitForChild("PlayerIcon")
	local stroke: ImageLabel = base:WaitForChild("CrowBaseStroke")
	local innerBase: ImageLabel = stroke:WaitForChild("InnerBase")
	local icon: ImageLabel = innerBase:WaitForChild("Crow")

	displayName.Text = player.DisplayName
	userName.Text = `@{player.Name}`
	playerIcon.Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`

	trove:Connect(player:GetAttributeChangedSignal("equippedBadgeId"), function()
		Private._renderBadge(player, stroke, innerBase, icon)
	end)
	Private._renderBadge(player, stroke, innerBase, icon)
	billboard.Parent = character
end

function Private._watchPlayer(player, template)
	if _playerTroves[player] or player.Parent ~= Players then
		return
	end

	local playerTrove = Trove.new()
	local characterTrove = playerTrove:Extend()
	local currentCharacter: Model? = nil
	_playerTroves[player] = playerTrove

	local function clearCharacter(character)
		if currentCharacter ~= character then
			return
		end

		currentCharacter = nil
		characterTrove:Clean()
	end

	local function showCharacter(character)
		if currentCharacter == character or player.Character ~= character or _playerTroves[player] ~= playerTrove then
			return
		end

		characterTrove:Clean()
		currentCharacter = character
		characterTrove:Connect(character.Destroying, function()
			clearCharacter(character)
		end)
		-- Defer so the waiting thread is registered before it can run or be cancelled.
		characterTrove:Add(task.defer(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 10)
			if
				not rootPart
				or currentCharacter ~= character
				or player.Character ~= character
				or _playerTroves[player] ~= playerTrove
			then
				return
			end

			Private._createBillboard(player, character, rootPart, template, characterTrove)
		end))
	end

	playerTrove:Connect(player.CharacterAdded, showCharacter)
	playerTrove:Connect(player.CharacterRemoving, clearCharacter)
	if player.Character then
		showCharacter(player.Character)
	end
end

function Private._removePlayer(player)
	local trove = _playerTroves[player]
	if not trove then
		return
	end

	_playerTroves[player] = nil
	trove:Destroy()
end

function Shared.OnStart()
	local template: BillboardGui = ReplicatedStorage.Assets.GUIs:WaitForChild("Badges"):WaitForChild("BadgeBillboard")

	Players.PlayerAdded:Connect(function(player)
		Private._watchPlayer(player, template)
	end)
	Players.PlayerRemoving:Connect(Private._removePlayer)
	for _, player in Players:GetPlayers() do
		Private._watchPlayer(player, template)
	end
end

return Shared
