--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local SocialControl = {}

local _character: Model
local _activeCall = false
local _callID = 0
local _highlightsTable: { Instance } = {}

function SocialControl:CallDissipate(id: number): ()
	if id ~= _callID then return end

	local cart: Model? = workspace.Map.Cart:FindFirstChild("Cart")
	if not cart then return end

	for _, highlight in _highlightsTable do
		TweenService:Create(highlight, TweenInfo.new(0.25), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
		task.delay(0.25, function()
			highlight:Destroy()
		end)
	end

	_highlightsTable = {}
	TweenService:Create(cart.Highlight, TweenInfo.new(1), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	TweenService:Create(cart.HighlightUI.Frame, TweenInfo.new(1), { ImageTransparency = 1 }):Play()
	_activeCall = false
end

function SocialControl:Call(): ()
	local weld: WeldConstraint = Instance.new("WeldConstraint")
	local areaGrowl = ReplicatedStorage.Assets.VFX.AreaGrowl:Clone()
	areaGrowl.Parent = _character
	areaGrowl.CFrame = _character:GetPivot()
	areaGrowl.Anchored = false

	weld.Part0 = areaGrowl
	weld.Part1 = _character.PrimaryPart
	weld.Parent = areaGrowl

	local ts = TweenService:Create(areaGrowl, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = Vector3.new(10, 10, 10), Transparency = 1 })
	ts.Completed:Once(function()
		weld:Destroy()
		areaGrowl:Destroy()
	end)
	ts:Play()

	local cart: Model? = workspace.Map.Cart:FindFirstChild("Cart")
	if not cart then return end

	if _activeCall then
		_callID += 1
		local id = _callID
		task.delay(5, function()
			self:CallDissipate(id)
		end)
		return
	end
	_activeCall = true

	TweenService:Create(cart.Highlight, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FillTransparency = 0.35, OutlineTransparency = 0 }):Play()
	TweenService:Create(cart.HighlightUI.Frame, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { ImageTransparency = 0.5 }):Play()

	for _, character in workspace.Map.Players:GetChildren() do
		if character == _character then continue end

		local highlight = ReplicatedStorage.Assets.VFX.CharacterHighlight:Clone()
		highlight.Parent = character
		TweenService:Create(highlight, TweenInfo.new(0.25), { FillTransparency = 0.35, OutlineTransparency = 0 }):Play()
		table.insert(_highlightsTable, highlight)
	end

	_callID += 1
	local id = _callID
	task.delay(5, function()
		self:CallDissipate(id)
	end)
end

function SocialControl:Init(character: Model): ()
	_character = character
	_activeCall = false
	_callID = 0
	_highlightsTable = {}
end

export type SocialControl = typeof(SocialControl)
return SocialControl
