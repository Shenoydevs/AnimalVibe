--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local AbilityControl = {}
local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Include
local RADARTICK = 1

local _hostileFolder = game.Workspace:WaitForChild("Map"):WaitForChild("Hostiles")

function AbilityControl:Pack(hitdamage: number, character: Model, chosedAnimal: string): number
    if chosedAnimal ~= "Wolf" then return hitdamage end

    local closeCharacters = 0
    for _, v in workspace.Map.Players:GetChildren() do
        if v.Name == character.Name then continue end
        local dist = (v:GetPivot().Position - character:GetPivot().Position).Magnitude
        if dist <= 150 then closeCharacters += 1 end
    end

    if closeCharacters > 0 then
        return hitdamage * (1 + (closeCharacters * 0.1))
    end
    return hitdamage * 0.8
end

local function radarClean(character, model)
    if model == nil then return end  
    local dist = (character:GetPivot().Position - model:GetPivot().Position).Magnitude
    if dist > 500 then task.delay(RADARTICK * 40, radarClean, character, model) return end
    model:RemoveTag("DeerRadar")
end

function AbilityControl:Radar(character : Model): ()
    task.spawn(function()
        while true do
            if not character:GetAttribute("alive") then task.wait(RADARTICK) continue end
            params.FilterDescendantsInstances = {_hostileFolder}
                
            local partsInRange = workspace:GetPartBoundsInRadius(character.PrimaryPart.Position, 500, params)
            local checkedCharacters = {}
            
            for _, part in ipairs(partsInRange) do
                local model = part.Parent
                if model and model:FindFirstChild("Humanoid") and not checkedCharacters[model] and not model:HasTag("DeerRadar") then
                    checkedCharacters[model] = true
                    model:AddTag("DeerRadar")
                    task.delay(RADARTICK * 40, radarClean, character, model)
                end
            end

            for tohighlight,_ in checkedCharacters do
                local highlight = ReplicatedStorage.Assets.VFX.SpotHighlight:Clone()
                highlight.Parent = tohighlight
                TweenService:Create(highlight, TweenInfo.new(0.25), {FillTransparency = 0.35, OutlineTransparency = 0}):Play()

                task.delay(7, function()
                    if highlight == nil then return end
                    TweenService:Create(highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {FillTransparency = 1, OutlineTransparency = 1}):Play()
                    Debris:AddItem(highlight, 0.5)
                end)
            end

            task.wait(RADARTICK)
        end
   end)
end

return AbilityControl
