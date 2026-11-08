--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GachaConfig = require(ReplicatedStorage.Shared.config.GachaConfig)
local GachaTypes = require(ReplicatedStorage.Shared.types.GachaTypes)
local SpinMotion = require(script.Parent.SpinMotion)

type GachaData = GachaTypes.GachaData

local _pityBase: ImageLabel
local _secretPityBase: ImageLabel
local _pityLabel: TextLabel
local _secretPityLabel: TextLabel

local Shared = {}

function Shared.bind(bottomRight: Frame): ()
	_pityBase = bottomRight:WaitForChild("PityBase") :: ImageLabel
	_secretPityBase = bottomRight:WaitForChild("SecretPityBase") :: ImageLabel
	_pityLabel = _pityBase:WaitForChild("PityAmount") :: TextLabel
	_secretPityLabel = _secretPityBase:WaitForChild("PityAmount") :: TextLabel
	SpinMotion.button(_pityBase, _pityBase:WaitForChild("HitBox") :: ImageButton, _pityBase, nil)
	SpinMotion.button(_secretPityBase, _secretPityBase:WaitForChild("HitBox") :: ImageButton, _secretPityBase, nil)
end

-- Given the previously shown data, a changed counter pops, harder when it resets.
function Shared.render(gacha: GachaData, previous: GachaData?): ()
	_pityLabel.Text = `PITY: {gacha.pity}/{GachaConfig.pityTarget}`
	_secretPityLabel.Text = `SECRET PITY: {gacha.secretPity}/{GachaConfig.secretPityTarget}`
	if not previous then
		return
	end
	if gacha.pity ~= previous.pity then
		SpinMotion.pop(_pityBase, if gacha.pity == 0 then 1.3 else 1.12, 0.35)
	end
	if gacha.secretPity ~= previous.secretPity then
		SpinMotion.pop(_secretPityBase, if gacha.secretPity == 0 then 1.3 else 1.12, 0.35)
	end
end

return Shared
