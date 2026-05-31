--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local RollFX = require(script.Parent.RollFX)

local player = Players.LocalPlayer
local network = ReplicatedStorage:WaitForChild("Network")
local events = network:WaitForChild("RemoteEvents")
local GetProfile = network:WaitForChild("RemoteFunctions"):WaitForChild("GetProfile")

local UIController = {}
local latestData -- last replicated profile

local function color3(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function makeUI()
	local gui = Instance.new("ScreenGui")
	gui.Name = "AscendUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")

	-- HUD: cash label (top-left)
	local cash = Instance.new("TextLabel")
	cash.Name = "Cash"
	cash.Size = UDim2.fromScale(0.25, 0.06)
	cash.Position = UDim2.fromScale(0.02, 0.02)
	cash.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	cash.BackgroundTransparency = 0.2
	cash.TextColor3 = Color3.fromRGB(255, 215, 0)
	cash.TextScaled = true
	cash.Font = Enum.Font.GothamBold
	cash.Text = "$0"
	cash.Parent = gui

	-- Roll button (bottom-center, big for touch)
	local roll = Instance.new("TextButton")
	roll.Name = "Roll"
	roll.Size = UDim2.fromScale(0.4, 0.12)
	roll.Position = UDim2.fromScale(0.3, 0.84)
	roll.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
	roll.TextColor3 = Color3.fromRGB(255, 255, 255)
	roll.TextScaled = true
	roll.Font = Enum.Font.GothamBlack
	roll.Text = "ROLL ($10)"
	roll.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = roll

	-- Inventory toggle button + frame
	local invBtn = Instance.new("TextButton")
	invBtn.Name = "InvBtn"
	invBtn.Size = UDim2.fromScale(0.18, 0.06)
	invBtn.Position = UDim2.fromScale(0.8, 0.02)
	invBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	invBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	invBtn.TextScaled = true
	invBtn.Font = Enum.Font.GothamBold
	invBtn.Text = "Inventory"
	invBtn.Parent = gui

	local inv = Instance.new("ScrollingFrame")
	inv.Name = "Inventory"
	inv.Size = UDim2.fromScale(0.6, 0.6)
	inv.Position = UDim2.fromScale(0.2, 0.15)
	inv.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	inv.BackgroundTransparency = 0.1
	inv.Visible = false
	inv.Parent = gui
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromScale(0.3, 0.22)
	grid.CellPadding = UDim2.fromScale(0.02, 0.02)
	grid.Parent = inv

	-- Transient notification (center, above roll button)
	local notif = Instance.new("TextLabel")
	notif.Name = "Notif"
	notif.Size = UDim2.fromScale(0.5, 0.06)
	notif.Position = UDim2.fromScale(0.25, 0.74)
	notif.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	notif.TextColor3 = Color3.fromRGB(255, 255, 255)
	notif.TextScaled = true
	notif.Font = Enum.Font.GothamBold
	notif.Visible = false
	notif.Parent = gui

	-- Offline banner
	local banner = Instance.new("TextButton")
	banner.Name = "Offline"
	banner.Size = UDim2.fromScale(0.5, 0.12)
	banner.Position = UDim2.fromScale(0.25, 0.4)
	banner.BackgroundColor3 = Color3.fromRGB(30, 120, 60)
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextScaled = true
	banner.Font = Enum.Font.GothamBold
	banner.Visible = false
	banner.Parent = gui

	return {
		gui = gui,
		cash = cash,
		roll = roll,
		invBtn = invBtn,
		inv = inv,
		banner = banner,
		notif = notif,
	}
end

function UIController.Start()
	local ui = makeUI()

	-- transient notification helper
	local notifToken = 0
	local function notify(text: string)
		ui.notif.Text = text
		ui.notif.Visible = true
		notifToken += 1
		local myToken = notifToken
		task.delay(2.5, function()
			if myToken == notifToken then
				ui.notif.Visible = false
			end
		end)
	end

	-- Roll: click or keyboard (R / Space on PC). Blocked while an animation plays.
	local function doRoll()
		if RollFX.IsRolling() then
			return
		end
		RollFX.RollStarted()
		events.RequestRoll:FireServer()
	end
	ui.roll.Activated:Connect(doRoll)
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == Enum.KeyCode.R or input.KeyCode == Enum.KeyCode.Space then
			doRoll()
		end
	end)

	-- Render inventory from data.
	local function renderInventory(data)
		for _, child in ui.inv:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		for uid, item in data.Inventory do
			local cfg = ItemConfig[item.Id]
			local cell = Instance.new("TextButton")
			cell.BackgroundColor3 = color3(cfg.Color)
			cell.TextColor3 = Color3.fromRGB(0, 0, 0)
			cell.TextScaled = true
			cell.Font = Enum.Font.GothamBold
			local placed = table.find(data.Placed, uid) ~= nil
			local mut = if item.Mutation then `[{item.Mutation}] ` else ""
			cell.Text = `{mut}{cfg.Name}\n{if placed then "PLACED (tap=remove)" else "tap=place | right=sell"}`
			cell.Parent = ui.inv
			-- tap: toggle place (client-side cap feedback; server is authoritative)
			cell.Activated:Connect(function()
				if not placed then
					local placedCount = #data.Placed
					local maxPlaced = data.MaxPlaced or 5
					if placedCount >= maxPlaced then
						notify(`Plot plein ({placedCount}/{maxPlaced}) - retire ou vends`)
						return
					end
				end
				events.PlaceItem:FireServer({ uid = uid, place = not placed })
			end)
			-- right-click (PC): sell when not placed
			cell.MouseButton2Click:Connect(function()
				if not placed then
					events.SellItem:FireServer(uid)
				end
			end)
		end
	end

	ui.invBtn.Activated:Connect(function()
		ui.inv.Visible = not ui.inv.Visible
		if ui.inv.Visible and latestData then
			renderInventory(latestData)
		end
	end)

	-- React to replicated profile.
	events.ProfileUpdated.OnClientEvent:Connect(function(data)
		latestData = data
		ui.cash.Text = `${math.floor(data.Leaderstats.Cash)}`
		if ui.inv.Visible then
			renderInventory(data)
		end
	end)

	-- Initial fetch + offline banner.
	local payload = GetProfile:InvokeServer()
	if payload then
		latestData = payload.data
		ui.cash.Text = `${math.floor(payload.data.Leaderstats.Cash)}`
		if payload.offline and payload.offline > 0 then
			ui.banner.Text = `Welcome back! +${payload.offline} earned offline.\n(tap to claim)`
			ui.banner.Visible = true
			ui.banner.Activated:Connect(function()
				events.ClaimOffline:FireServer()
				ui.banner.Visible = false
			end)
		end
	end
end

return UIController
