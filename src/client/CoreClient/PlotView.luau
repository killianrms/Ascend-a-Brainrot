--!strict
-- Client-side visual of the player's placed creatures. Purely cosmetic: the server
-- remains authoritative over income. Renders one spinning block per placed creature.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local MutationConfig = require(ReplicatedStorage.Modules.MutationConfig)

local network = ReplicatedStorage:WaitForChild("Network")
local events = network:WaitForChild("RemoteEvents")

local PlotView = {}

local BASE = Vector3.new(-10, 4, -14) -- where the row of creatures starts
local SPACING = 5
local PER_ROW = 5

local function color3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function incomeOf(item): number
	local base = ItemConfig[item.Id].BaseIncome
	local mult = if item.Mutation then MutationConfig[item.Mutation].Mult else 1
	return base * mult
end

function PlotView.Start()
	local folder = Instance.new("Folder")
	folder.Name = "AscendPlotView"
	folder.Parent = workspace

	local spinning: { BasePart } = {}
	local currentSignature = ""

	-- one shared spin for life
	RunService.Heartbeat:Connect(function(dt)
		for _, part in spinning do
			if part.Parent then
				part.CFrame = part.CFrame * CFrame.Angles(0, math.rad(40 * dt), 0)
			end
		end
	end)

	local function rebuild(data)
		folder:ClearAllChildren()
		table.clear(spinning)
		for index, uid in data.Placed do
			local item = data.Inventory[uid]
			if not item then
				continue
			end
			local cfg = ItemConfig[item.Id]
			local col = (index - 1) % PER_ROW
			local row = math.floor((index - 1) / PER_ROW)
			local pos = BASE + Vector3.new(col * SPACING, 0, -row * SPACING)

			local part = Instance.new("Part")
			part.Size = Vector3.new(3, 3, 3)
			part.Position = pos
			part.Anchored = true
			part.CanCollide = false
			part.Material = Enum.Material.Neon
			part.Color = color3(cfg.Color)
			part.Parent = folder

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(4, 1.4)
			bb.StudsOffset = Vector3.new(0, 2.4, 0)
			bb.AlwaysOnTop = true
			bb.Parent = part

			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255, 255, 255)
			label.TextStrokeTransparency = 0
			label.TextScaled = true
			label.Font = Enum.Font.GothamBold
			local mut = if item.Mutation then `[{item.Mutation}] ` else ""
			label.Text = `{mut}{cfg.Name}\n${incomeOf(item)}/s`
			label.Parent = bb

			table.insert(spinning, part)
		end
	end

	-- Only rebuild when the placed set actually changes (avoids resetting spins each tick).
	events.ProfileUpdated.OnClientEvent:Connect(function(data)
		local sig = ""
		for _, uid in data.Placed do
			local item = data.Inventory[uid]
			sig ..= uid .. (if item and item.Mutation then item.Mutation else "") .. ";"
		end
		if sig ~= currentSignature then
			currentSignature = sig
			rebuild(data)
		end
	end)
end

return PlotView
