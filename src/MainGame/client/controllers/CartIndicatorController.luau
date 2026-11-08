--!strict
local _collectionService = game:GetService("CollectionService")
local _players = game:GetService("Players")
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _runService = game:GetService("RunService")

local _troveModule = require(_replicatedStorage.Packages.Trove)
local _cartConfig = require(_replicatedStorage.Shared.config.CartConfig)
local _characterUtils = require(_replicatedStorage.Shared.utils.CharacterUtils)

local _trove = _troveModule.new()
local _carts: { [Instance]: boolean } = {}
local cartIndicatorController = {}

function cartIndicatorController:OnStart(): ()
	local gui: ScreenGui = _trove:Add(Instance.new("ScreenGui"))
	gui.Name = "CartIndicator"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = _players.LocalPlayer:WaitForChild("PlayerGui")

	local label: TextLabel = Instance.new("TextLabel")
	label.Name = "Marker"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Size = UDim2.fromOffset(120, 44)
	label.BackgroundColor3 = Color3.fromRGB(30, 25, 20)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(255, 210, 110)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Visible = false
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local arrow: TextLabel = Instance.new("TextLabel")
	arrow.Name = "Direction"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.new(0.5, 0, 0, -15)
	arrow.Size = UDim2.fromOffset(28, 28)
	arrow.BackgroundTransparency = 1
	arrow.Text = "▲"
	arrow.TextColor3 = label.TextColor3
	arrow.TextSize = 24
	arrow.Parent = label

	_trove:Connect(_collectionService:GetInstanceAddedSignal("Cart"), function(cart: Instance): ()
		_carts[cart] = true
	end)
	_trove:Connect(_collectionService:GetInstanceRemovedSignal("Cart"), function(cart: Instance): ()
		_carts[cart] = nil
	end)
	for _, cart in _collectionService:GetTagged("Cart") do _carts[cart] = true end

	_trove:Connect(_runService.RenderStepped, function(): ()
		local camera = workspace.CurrentCamera
		local root = _characterUtils.getPlayerRoot(_players.LocalPlayer)
		label.Visible = false
		if not camera or not root then return end
		local target: Vector3? = nil
		local distance: number = math.huge
		for cart in _carts do
			if not cart:IsA("Model") or not cart.PrimaryPart or not cart:IsDescendantOf(workspace) then continue end
			local position = cart.PrimaryPart.Position
			local candidateDistance = (position - root.Position).Magnitude
			if candidateDistance < distance then
				target = position + Vector3.new(0, 6, 0)
				distance = candidateDistance
			end
		end
		if not target or distance < _cartConfig.indicatorMinDistance then return end

		local point, onScreen = camera:WorldToViewportPoint(target)
		local center = camera.ViewportSize / 2
		local bounds = Vector2.new(
			math.max(1, center.X - _cartConfig.indicatorScreenMargin),
			math.max(1, center.Y - _cartConfig.indicatorScreenMargin)
		)
		local offset = Vector2.new(point.X, point.Y) - center
		local offscreen = not onScreen or math.abs(offset.X) > bounds.X or math.abs(offset.Y) > bounds.Y
		if offscreen then
			if point.Z <= 0 then offset = -offset end
			if offset.Magnitude < 0.001 then offset = Vector2.new(0, 1) end
			local scale = math.max(math.abs(offset.X) / bounds.X, math.abs(offset.Y) / bounds.Y)
			offset /= scale
			arrow.Rotation = math.deg(math.atan2(offset.Y, offset.X)) + 90
		end
		arrow.Visible = offscreen
		label.Position = UDim2.fromOffset(center.X + offset.X, center.Y + offset.Y)
		label.Text = `CART\n{math.floor(distance + 0.5)} studs`
		label.Visible = true
	end)
end

return cartIndicatorController
