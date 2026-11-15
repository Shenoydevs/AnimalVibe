--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ENEMY_FLICKER_COLOR = Color3.fromRGB(219, 27, 27)
local OWN_FLICKER_COLOR = Color3.fromRGB(255, 0, 0)

local VFXUtils = {}

local function flicker(character: Model, color: Color3, own: boolean): ()
	if not character.Parent then return end

	local existing: Instance? = character:FindFirstChild("DamageFlicker")
	if existing then existing:Destroy() end

	local highlight = Instance.new("Highlight")
	highlight.Name = "DamageFlicker"
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillColor = color
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = 0.25
	highlight.Parent = character

	local tween = TweenService:Create(highlight, TweenInfo.new(if own then 0.6 else 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { FillTransparency = 1 })
	tween.Completed:Once(function()
		highlight:Destroy()
	end)
	tween:Play()
end

local function spawnHitVFX(character: Model, own: boolean): ()
	local root: BasePart? = character.PrimaryPart
	if not root then return end

	local hitVFX = ReplicatedStorage.Assets.VFX.HitVFX:Clone()
	hitVFX.Parent = workspace.Stuff
	hitVFX.CFrame = root.CFrame
	-- Scheduled before anything below can throw, so a bad asset never leaks the part.
	Debris:AddItem(hitVFX, 3)

	hitVFX.Effect.Hit:Emit(13)
	hitVFX.Hit:Play()
	if own then
		local animalClass: string = tostring(character:GetAttribute("animalClass"))
		local damageSound: Instance? = hitVFX.AnimalDamage:FindFirstChild(animalClass)
		if damageSound and damageSound:IsA("Sound") then
			damageSound:Play()
		else
			warn(`[VFXUtils] HitVFX.AnimalDamage has no Sound named "{animalClass}"`)
		end
	end
end

function VFXUtils:DamageFlicker(character: Model, smackVFX: boolean): ()
	flicker(character, ENEMY_FLICKER_COLOR, false)
	if smackVFX then
		spawnHitVFX(character, false)
	end
end

function VFXUtils:OwnDamageFlicker(character: Model, smackVFX: boolean): ()
	flicker(character, OWN_FLICKER_COLOR, true)
	if smackVFX then
		spawnHitVFX(character, true)
	end
end

return VFXUtils
