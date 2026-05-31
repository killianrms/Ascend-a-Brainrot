--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local FormulaModule = require(ReplicatedStorage.Modules.FormulaModule)
local RollFX = require(script.Parent.RollFX)

local BASE_MAX_PLACED = 5
local BASE_MAX_SLOTS = 12

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

	-- Gems label (under cash)
	local gems = Instance.new("TextLabel")
	gems.Name = "Gems"
	gems.Size = UDim2.fromScale(0.25, 0.05)
	gems.Position = UDim2.fromScale(0.02, 0.09)
	gems.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	gems.BackgroundTransparency = 0.2
	gems.TextColor3 = Color3.fromRGB(150, 230, 255)
	gems.TextScaled = true
	gems.Font = Enum.Font.GothamBold
	gems.Text = "0 Gems"
	gems.Parent = gui

	-- Income multiplier label (under gems)
	local income = Instance.new("TextLabel")
	income.Name = "Income"
	income.Size = UDim2.fromScale(0.25, 0.045)
	income.Position = UDim2.fromScale(0.02, 0.145)
	income.BackgroundTransparency = 1
	income.TextColor3 = Color3.fromRGB(120, 255, 150)
	income.TextScaled = true
	income.Font = Enum.Font.GothamBold
	income.TextXAlignment = Enum.TextXAlignment.Left
	income.Text = "Revenu x1"
	income.Parent = gui

	-- Rebirth confirmation dialog (hidden)
	local confirm = Instance.new("Frame")
	confirm.Name = "RebirthConfirm"
	confirm.Size = UDim2.fromScale(0.5, 0.32)
	confirm.Position = UDim2.fromScale(0.25, 0.34)
	confirm.BackgroundColor3 = Color3.fromRGB(25, 20, 15)
	confirm.Visible = false
	confirm.ZIndex = 5
	confirm.Parent = gui
	local confirmText = Instance.new("TextLabel")
	confirmText.Name = "Text"
	confirmText.Size = UDim2.fromScale(0.92, 0.55)
	confirmText.Position = UDim2.fromScale(0.04, 0.05)
	confirmText.BackgroundTransparency = 1
	confirmText.TextColor3 = Color3.fromRGB(255, 255, 255)
	confirmText.TextScaled = true
	confirmText.Font = Enum.Font.GothamBold
	confirmText.TextWrapped = true
	confirmText.ZIndex = 6
	confirmText.Parent = confirm
	local yesBtn = Instance.new("TextButton")
	yesBtn.Name = "Yes"
	yesBtn.Size = UDim2.fromScale(0.44, 0.3)
	yesBtn.Position = UDim2.fromScale(0.04, 0.65)
	yesBtn.BackgroundColor3 = Color3.fromRGB(40, 170, 80)
	yesBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	yesBtn.TextScaled = true
	yesBtn.Font = Enum.Font.GothamBlack
	yesBtn.Text = "REBIRTH !"
	yesBtn.ZIndex = 6
	yesBtn.Parent = confirm
	local noBtn = Instance.new("TextButton")
	noBtn.Name = "No"
	noBtn.Size = UDim2.fromScale(0.44, 0.3)
	noBtn.Position = UDim2.fromScale(0.52, 0.65)
	noBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
	noBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	noBtn.TextScaled = true
	noBtn.Font = Enum.Font.GothamBlack
	noBtn.Text = "Annuler"
	noBtn.ZIndex = 6
	noBtn.Parent = confirm

	-- Rebirth button (bottom-left)
	local rebirth = Instance.new("TextButton")
	rebirth.Name = "Rebirth"
	rebirth.Size = UDim2.fromScale(0.22, 0.1)
	rebirth.Position = UDim2.fromScale(0.02, 0.85)
	rebirth.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
	rebirth.TextColor3 = Color3.fromRGB(255, 255, 255)
	rebirth.TextScaled = true
	rebirth.Font = Enum.Font.GothamBlack
	rebirth.Text = "REBIRTH"
	rebirth.Parent = gui
	local rbCorner = Instance.new("UICorner")
	rbCorner.CornerRadius = UDim.new(0.2, 0)
	rbCorner.Parent = rebirth

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

	-- Shop toggle button
	local shopBtn = Instance.new("TextButton")
	shopBtn.Name = "ShopBtn"
	shopBtn.Size = UDim2.fromScale(0.18, 0.06)
	shopBtn.Position = UDim2.fromScale(0.61, 0.02)
	shopBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	shopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	shopBtn.TextScaled = true
	shopBtn.Font = Enum.Font.GothamBold
	shopBtn.Text = "Shop"
	shopBtn.Parent = gui

	-- Shop panel with one buy button per upgrade
	local shop = Instance.new("Frame")
	shop.Name = "Shop"
	shop.Size = UDim2.fromScale(0.4, 0.5)
	shop.Position = UDim2.fromScale(0.3, 0.2)
	shop.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	shop.BackgroundTransparency = 0.1
	shop.Visible = false
	shop.Parent = gui
	local shopList = Instance.new("UIListLayout")
	shopList.Padding = UDim.new(0.03, 0)
	shopList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	shopList.VerticalAlignment = Enum.VerticalAlignment.Center
	shopList.Parent = shop

	local shopButtons: { [string]: TextButton } = {}
	for _, kind in { "plot", "inv", "luck", "speed" } do
		local b = Instance.new("TextButton")
		b.Name = kind
		b.Size = UDim2.fromScale(0.9, 0.18)
		b.BackgroundColor3 = Color3.fromRGB(120, 80, 255)
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextScaled = true
		b.Font = Enum.Font.GothamBold
		b.Text = kind
		b.Parent = shop
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.2, 0)
		c.Parent = b
		shopButtons[kind] = b
	end

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
		shopBtn = shopBtn,
		shop = shop,
		shopButtons = shopButtons,
		gems = gems,
		rebirth = rebirth,
		income = income,
		confirm = confirm,
		confirmText = confirmText,
		confirmYes = yesBtn,
		confirmNo = noBtn,
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
		-- R to roll (Space is reserved for jumping)
		if input.KeyCode == Enum.KeyCode.R then
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

	-- Shop: label each upgrade button with its current value and next cost.
	local function renderShop(data)
		local plotBought = data.MaxPlaced - BASE_MAX_PLACED
		local invBought = data.MaxSlots - BASE_MAX_SLOTS
		ui.shopButtons.plot.Text = `+1 Plot slot ({data.MaxPlaced}) - ${FormulaModule.plotSlotCost(plotBought)}`
		ui.shopButtons.inv.Text = `+1 Inventaire ({data.MaxSlots}) - ${FormulaModule.slotCost(invBought)}`
		ui.shopButtons.luck.Text =
			`Chance Lv.{data.Upgrades.LuckLevel} (+15%/lv) - ${FormulaModule.luckCost(data.Upgrades.LuckLevel)}`
		ui.shopButtons.speed.Text =
			`Vitesse Lv.{data.Upgrades.SpeedLevel} (-10%/lv) - ${FormulaModule.speedCost(data.Upgrades.SpeedLevel)}`
	end

	for kind, btn in ui.shopButtons do
		btn.Activated:Connect(function()
			events.BuyUpgrade:FireServer(kind)
		end)
	end

	ui.shopBtn.Activated:Connect(function()
		ui.shop.Visible = not ui.shop.Visible
		if ui.shop.Visible and latestData then
			renderShop(latestData)
		end
	end)

	-- Rebirth: open a confirmation that spells out the trade-off.
	ui.rebirth.Activated:Connect(function()
		if not latestData then
			return
		end
		local nextR = latestData.Leaderstats.Rebirths + 1
		local cost = FormulaModule.rebirthCost(nextR)
		if latestData.Leaderstats.Cash < cost then
			notify(`Rebirth: il te faut ${cost}`)
			return
		end
		local gemsGain = FormulaModule.gemsForRebirth(nextR)
		local newMult = FormulaModule.incomeMultiplier(nextR)
		ui.confirmText.Text = `REBIRTH {nextR} ?\n\nTu perds ton Cash ($ {math.floor(latestData.Leaderstats.Cash)})`
			.. `\nMais tu gagnes : +{gemsGain} Gems et revenu PERMANENT x{newMult}`
			.. `\n(tes créatures et améliorations sont conservées)`
		ui.confirm.Visible = true
	end)

	ui.confirmYes.Activated:Connect(function()
		ui.confirm.Visible = false
		events.RebirthRequest:FireServer()
	end)
	ui.confirmNo.Activated:Connect(function()
		ui.confirm.Visible = false
	end)

	-- HUD bits that depend on profile values (gems + income mult + rebirth button label).
	local function renderHud(data)
		ui.gems.Text = `{data.Leaderstats.Gems} Gems`
		ui.income.Text = `Revenu x{FormulaModule.incomeMultiplier(data.Leaderstats.Rebirths)}`
		local cost = FormulaModule.rebirthCost(data.Leaderstats.Rebirths + 1)
		local can = data.Leaderstats.Cash >= cost
		ui.rebirth.Text = `REBIRTH {data.Leaderstats.Rebirths} -> ${cost}`
		ui.rebirth.BackgroundColor3 = if can then Color3.fromRGB(230, 150, 40) else Color3.fromRGB(90, 70, 50)
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
		renderHud(data)
		if ui.inv.Visible then
			renderInventory(data)
		end
		if ui.shop.Visible then
			renderShop(data)
		end
	end)

	-- Initial fetch + offline banner.
	local payload = GetProfile:InvokeServer()
	if payload then
		latestData = payload.data
		ui.cash.Text = `${math.floor(payload.data.Leaderstats.Cash)}`
		renderHud(payload.data)
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
