--!strict
local _replicatedStorage = game:GetService("ReplicatedStorage")
local _serverScriptService = game:GetService("ServerScriptService")

local _component = require(_replicatedStorage.Packages.Component)
local _troveModule = require(_replicatedStorage.Packages.Trove)
local _signals = require(_serverScriptService.Server.signals)

local _cartSignals = _signals.cartSignals

local _cartTypes = require(_replicatedStorage.Shared.types.CartTypes)
export type wheelComponent = _cartTypes.wheelComponentInterface & {
	Instance: Model,
	_trove: typeof(_troveModule.new()),
	_part: BasePart,
	_axle: Attachment,
	_prompt: ProximityPrompt,
}
local wheelComponent = _component.new({ Tag = "Wheel" })

function wheelComponent.Construct(self: wheelComponent): ()
	self._trove = _troveModule.new()

	local model: Instance = self.Instance
	assert(model:IsA("Model"), "Wheel must be a Model")
	local primaryPart: BasePart? = model.PrimaryPart
	assert(primaryPart, `[wheelComponent] {self.Instance.Name} is missing PrimaryPart`)

	local axle: Instance? = primaryPart:FindFirstChild("Axle")
	assert(axle and axle:IsA("Attachment"), `[wheelComponent] {self.Instance.Name} Part is missing Axle Attachment`)

	local prompt: ProximityPrompt? = primaryPart:FindFirstChildWhichIsA("ProximityPrompt")
	assert(prompt, `[wheelComponent] {self.Instance.Name} Part is missing ProximityPrompt`)

	self._part = primaryPart :: BasePart
	self._axle = axle :: Attachment
	self._prompt = prompt :: ProximityPrompt
end

function wheelComponent.Start(self: wheelComponent): ()
	self._trove:Connect(self._prompt.Triggered, function(player: Player): ()
		_cartSignals.wheelPickup:Fire(self, player)
	end)
end

function wheelComponent.Stop(self: wheelComponent): ()
	self._trove:Clean()
end

function wheelComponent.getPart(self: wheelComponent): BasePart
	return self._part
end

function wheelComponent.getAxle(self: wheelComponent): Attachment
	return self._axle
end

function wheelComponent.setPromptEnabled(self: wheelComponent, enabled: boolean): ()
	self._prompt.Enabled = enabled
end

return wheelComponent
