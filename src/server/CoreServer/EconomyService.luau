--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local MutationConfig = require(ReplicatedStorage.Modules.MutationConfig)
local DataManager = require(script.Parent.DataManager)

local EconomyService = {}

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

return EconomyService
