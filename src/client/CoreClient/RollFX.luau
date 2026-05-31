--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")
local events = network:WaitForChild("RemoteEvents")

local RollFX = {}

local ROLL_ANIM_DURATION = 1.0 -- seconds of suspense before the reveal
local RARITY_INTENSITY: { [string]: number } = {
	Common = 0.1,
	Uncommon = 0.2,
	Rare = 0.45,
	Epic = 0.75,
	Divine = 1,
}

-- precomputed list of creature ids for the cycling animation
local creatureIds: { string } = {}
for id in ItemConfig do
	table.insert(creatureIds, id)
end

local function color3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- internal state
local rolling = false
local pending: any = nil -- the roll result once it arrives from the server
local card: TextLabel

function RollFX.IsRolling(): boolean
	return rolling
end

local function reveal(id: string, mutation: string?, rarity: string)
	local cfg = ItemConfig[id]
	local intensity = RARITY_INTENSITY[rarity] or 0.1
	local mut = if mutation and mutation ~= "None" then `[{mutation}] ` else ""
	card.Text = `{mut}{cfg.Name}!\n{rarity}`
	card.BackgroundColor3 = color3(cfg.Color)
	card.Visible = true
	-- pop scale
	card.Size = UDim2.fromScale(0.2, 0.1)
	TweenService:Create(
		card,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.5, 0.25) }
	):Play()
	-- screen shake proportional to rarity
	local cam = workspace.CurrentCamera
	task.spawn(function()
		local shakes = math.floor(6 * intensity)
		for _ = 1, shakes do
			cam.CFrame = cam.CFrame
				* CFrame.Angles(
					math.rad((math.random() - 0.5) * 2 * intensity),
					math.rad((math.random() - 0.5) * 2 * intensity),
					0
				)
			task.wait(0.02)
		end
	end)
	task.delay(1.4, function()
		if not rolling then
			card.Visible = false
		end
	end)
end

-- Called by UIController the moment the player triggers a roll.
function RollFX.RollStarted()
	if rolling then
		return
	end
	rolling = true
	pending = nil
	task.spawn(function()
		local t0 = os.clock()
		card.Visible = true
		-- cycle through random creatures for suspense
		while os.clock() - t0 < ROLL_ANIM_DURATION do
			local id = creatureIds[math.random(1, #creatureIds)]
			local cfg = ItemConfig[id]
			card.Text = `{cfg.Name}?`
			card.BackgroundColor3 = color3(cfg.Color)
			card.Size = UDim2.fromScale(0.44, 0.22)
			task.wait(0.07)
		end
		-- wait for the server result (usually already here)
		local waited = 0
		while pending == nil and waited < 3 do
			task.wait(0.05)
			waited += 0.05
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

	-- Reveal / suspense card (center)
	card = Instance.new("TextLabel")
	card.Size = UDim2.fromScale(0.5, 0.25)
	card.Position = UDim2.fromScale(0.25, 0.32)
	card.BackgroundTransparency = 0
	card.TextScaled = true
	card.Font = Enum.Font.GothamBlack
	card.TextColor3 = Color3.fromRGB(255, 255, 255)
	card.Visible = false
	card.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.1, 0)
	corner.Parent = card

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
