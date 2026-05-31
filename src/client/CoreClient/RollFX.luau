--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")
local events = network:WaitForChild("RemoteEvents")

local RollFX = {}

local RARITY_INTENSITY: { [string]: number } = {
	Common = 0.15,
	Uncommon = 0.3,
	Rare = 0.55,
	Epic = 0.8,
	Divine = 1,
}
-- How long the suspense lasts based on the rolled rarity (rarer = more drama).
local RARITY_SUSPENSE: { [string]: number } = {
	Common = 1.2,
	Uncommon = 1.3,
	Rare = 1.7,
	Epic = 2.3,
	Divine = 3.0,
}

local creatureIds: { string } = {}
for id in ItemConfig do
	table.insert(creatureIds, id)
end

local function color3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- internal state / UI refs
local rolling = false
local pending: any = nil
local card: TextLabel
local cardStroke: UIStroke
local flash: Frame

function RollFX.IsRolling(): boolean
	return rolling
end

-- Camera shake that survives the camera controller (runs after camera update each frame).
local function cameraShake(duration: number, magnitude: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local elapsed = 0
	local id = "AscendShake"
	RunService:BindToRenderStep(id, Enum.RenderPriority.Camera.Value + 1, function(dt)
		elapsed += dt
		local left = 1 - (elapsed / duration)
		if left <= 0 then
			RunService:UnbindFromRenderStep(id)
			return
		end
		local a = magnitude * left
		cam.CFrame = cam.CFrame
			* CFrame.Angles(
				math.rad((math.random() - 0.5) * a),
				math.rad((math.random() - 0.5) * a),
				math.rad((math.random() - 0.5) * a * 0.5)
			)
	end)
end

-- UI shake of the reveal card.
local function cardShake(duration: number, pixels: number)
	local base = UDim2.fromScale(0.25, 0.32)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < duration do
			local left = 1 - (os.clock() - t0) / duration
			card.Position = base
				+ UDim2.fromOffset((math.random() - 0.5) * pixels * left, (math.random() - 0.5) * pixels * left)
			RunService.RenderStepped:Wait()
		end
		card.Position = base
	end)
end

local function doFlash(c: Color3, strength: number)
	flash.BackgroundColor3 = c
	flash.BackgroundTransparency = 1 - strength
	flash.Visible = true
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
end

local function reveal(id: string, mutation: string?, rarity: string)
	local cfg = ItemConfig[id]
	local intensity = RARITY_INTENSITY[rarity] or 0.15
	local mut = if mutation and mutation ~= "None" then `[{mutation}] ` else ""
	local col = color3(cfg.Color)

	card.Text = `{mut}{cfg.Name}!\n{rarity}`
	card.BackgroundColor3 = col
	cardStroke.Color = col
	cardStroke.Thickness = 2 + 10 * intensity
	card.Visible = true

	-- pop scale
	card.Size = UDim2.fromScale(0.2, 0.1)
	TweenService:Create(
		card,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.5, 0.25) }
	):Play()

	doFlash(col, intensity)
	cameraShake(0.35 + 0.5 * intensity, 1 + 7 * intensity)
	if intensity >= 0.5 then
		cardShake(0.4, 14 * intensity)
	end

	local hold = 1.2 + 1.5 * intensity
	task.delay(hold, function()
		if not rolling then
			card.Visible = false
		end
	end)
end

function RollFX.RollStarted()
	if rolling then
		return
	end
	rolling = true
	pending = nil
	task.spawn(function()
		card.Visible = true
		card.Size = UDim2.fromScale(0.45, 0.22)
		card.Position = UDim2.fromScale(0.25, 0.32)
		cardStroke.Thickness = 2
		local t0 = os.clock()
		local interval = 0.04
		while true do
			local elapsed = os.clock() - t0
			local suspense = 1.2
			if pending then
				local r = (pending.ok and pending.rarity) or "Common"
				suspense = RARITY_SUSPENSE[r] or 1.2
			end
			if pending and elapsed >= suspense then
				break
			end
			if elapsed > 7 then
				break -- safety net if the server never answers
			end
			local id = creatureIds[math.random(1, #creatureIds)]
			local cfg = ItemConfig[id]
			card.Text = `{cfg.Name}?`
			card.BackgroundColor3 = color3(cfg.Color)
			interval = math.min(0.2, interval + 0.007) -- decelerate (slot-machine feel)
			task.wait(interval)
		end
		if pending and pending.ok then
			reveal(pending.id, pending.mutation, pending.rarity)
		else
			card.Visible = false
		end
		rolling = false
	end)
end

function RollFX.Start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AscendFX"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	-- full-screen flash
	flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.Visible = false
	flash.ZIndex = 1
	flash.Parent = gui

	-- reveal / suspense card
	card = Instance.new("TextLabel")
	card.Size = UDim2.fromScale(0.5, 0.25)
	card.Position = UDim2.fromScale(0.25, 0.32)
	card.BackgroundTransparency = 0
	card.TextScaled = true
	card.Font = Enum.Font.GothamBlack
	card.TextColor3 = Color3.fromRGB(255, 255, 255)
	card.TextStrokeTransparency = 0.4
	card.ZIndex = 2
	card.Visible = false
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = card
	cardStroke = Instance.new("UIStroke")
	cardStroke.Thickness = 2
	cardStroke.Color = Color3.fromRGB(255, 255, 255)
	cardStroke.Parent = card

	-- Server returns the roll result on the same RequestRoll event.
	events.RequestRoll.OnClientEvent:Connect(function(result)
		pending = result
	end)

	-- Global rare toast (top-center)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.fromScale(0.6, 0.06)
	toast.Position = UDim2.fromScale(0.2, 0.02)
	toast.BackgroundColor3 = Color3.fromRGB(234, 179, 8)
	toast.TextColor3 = Color3.fromRGB(0, 0, 0)
	toast.TextScaled = true
	toast.Font = Enum.Font.GothamBold
	toast.ZIndex = 3
	toast.Visible = false
	toast.Parent = gui

	events.BroadcastRareRoll.OnClientEvent:Connect(function(playerName, id, mutation, rarity)
		local cfg = ItemConfig[id]
		local mut = if mutation and mutation ~= "None" then `[{mutation}] ` else ""
		toast.Text = `⭐ {playerName} rolled {mut}{cfg.Name} ({rarity})!`
		toast.Visible = true
		task.delay(4, function()
			toast.Visible = false
		end)
	end)
end

return RollFX
