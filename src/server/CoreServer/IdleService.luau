--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local MutationConfig = require(ReplicatedStorage.Modules.MutationConfig)
local FormulaModule = require(ReplicatedStorage.Modules.FormulaModule)
local DataManager = require(script.Parent.DataManager)

local IdleService = {}

local TICK = 1 -- seconds

-- cash/sec for a player from placed creatures.
function IdleService.RateOf(player: Player): number
	local profile = DataManager.Get(player)
	if not profile then
		return 0
	end
	local data = profile.Data
	local rate = 0
	for _, uid in data.Placed do
		local item = data.Inventory[uid]
		if item then
			local base = ItemConfig[item.Id].BaseIncome
			local mult = if item.Mutation then MutationConfig[item.Mutation].Mult else 1
			rate += base * mult
		end
	end
	-- global rebirth bonus
	rate *= FormulaModule.incomeMultiplier(data.Leaderstats.Rebirths)
	return rate
end

function IdleService.Start()
	-- Let DataManager compute offline earnings using the live rate.
	DataManager.RateProvider = IdleService.RateOf
	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local profile = DataManager.Get(player)
				if profile then
					profile.Data.Leaderstats.Cash += IdleService.RateOf(player) * TICK
				end
			end
		end
	end)
end

return IdleService
