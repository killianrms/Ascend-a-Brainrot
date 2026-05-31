--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local MutationConfig = require(ReplicatedStorage.Modules.MutationConfig)
local FormulaModule = require(ReplicatedStorage.Modules.FormulaModule)
local DataManager = require(script.Parent.DataManager)

local EconomyService = {}

local BASE_MAX_PLACED = 5
local BASE_MAX_SLOTS = 12

-- Sell value = 5s of the item's income (tunable).
local SELL_SECONDS = 5

local function itemValue(item): number
	local base = ItemConfig[item.Id].BaseIncome
	local mult = if item.Mutation then MutationConfig[item.Mutation].Mult else 1
	return math.max(1, math.floor(base * mult * SELL_SECONDS))
end

function EconomyService.Sell(player: Player, uid: string): boolean
	local profile = DataManager.Get(player)
	if not profile then
		return false
	end
	local data = profile.Data
	local item = data.Inventory[uid]
	if not item then
		return false
	end
	-- can't sell a placed creature; unplace first
	if table.find(data.Placed, uid) then
		return false
	end
	data.Leaderstats.Cash += itemValue(item)
	data.Inventory[uid] = nil
	return true
end

function EconomyService.Place(player: Player, uid: string): boolean
	local profile = DataManager.Get(player)
	if not profile then
		return false
	end
	local data = profile.Data
	if not data.Inventory[uid] then
		return false
	end
	if table.find(data.Placed, uid) then
		return false
	end
	-- enforce plot capacity
	if #data.Placed >= data.MaxPlaced then
		return false
	end
	table.insert(data.Placed, uid)
	return true
end

function EconomyService.Unplace(player: Player, uid: string): boolean
	local profile = DataManager.Get(player)
	if not profile then
		return false
	end
	local idx = table.find(profile.Data.Placed, uid)
	if not idx then
		return false
	end
	table.remove(profile.Data.Placed, idx)
	return true
end

-- Generic spend helper. Returns true if the player could afford `cost`.
local function spend(data, cost: number): boolean
	if data.Leaderstats.Cash < cost then
		return false
	end
	data.Leaderstats.Cash -= cost
	return true
end

-- Upgrade purchases. `kind` is "plot" | "inv" | "luck" | "speed".
function EconomyService.BuyUpgrade(player: Player, kind: string): boolean
	local profile = DataManager.Get(player)
	if not profile then
		return false
	end
	local data = profile.Data

	if kind == "plot" then
		local bought = data.MaxPlaced - BASE_MAX_PLACED
		if spend(data, FormulaModule.plotSlotCost(bought)) then
			data.MaxPlaced += 1
			return true
		end
	elseif kind == "inv" then
		local bought = data.MaxSlots - BASE_MAX_SLOTS
		if spend(data, FormulaModule.slotCost(bought)) then
			data.MaxSlots += 1
			return true
		end
	elseif kind == "luck" then
		if spend(data, FormulaModule.luckCost(data.Upgrades.LuckLevel)) then
			data.Upgrades.LuckLevel += 1
			return true
		end
	elseif kind == "speed" then
		if spend(data, FormulaModule.speedCost(data.Upgrades.SpeedLevel)) then
			data.Upgrades.SpeedLevel += 1
			return true
		end
	end
	return false
end

return EconomyService
