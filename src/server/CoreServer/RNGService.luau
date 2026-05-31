--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local ItemConfig = require(ReplicatedStorage.Modules.ItemConfig)
local MutationConfig = require(ReplicatedStorage.Modules.MutationConfig)
local WeightedRoll = require(ReplicatedStorage.Modules.WeightedRoll)
local Types = require(ReplicatedStorage.Modules.Types)

local DataManager = require(script.Parent.DataManager)

local RNGService = {}

local ROLL_COST = 10 -- cash per roll (vertical slice)
local ROLL_COOLDOWN = 0.4 -- seconds, anti-spam
local RARE_BROADCAST = { Epic = true, Divine = true } -- rarities that ping the whole server

local creatureEntries = WeightedRoll.fromConfig(ItemConfig)
local mutationEntries = WeightedRoll.fromConfig(MutationConfig)

local lastRoll: { [Player]: number } = {}

-- onRare(player, id, mutation, rarity) injected by the bootstrap for BroadcastRareRoll.
RNGService.OnRare = function(_p: Player, _id: string, _m: string, _r: string) end

function RNGService.Roll(player: Player): Types.RollResult
	local profile = DataManager.Get(player)
	if not profile then
		return { ok = false, reason = "no_profile" }
	end
	local data = profile.Data

	local now = os.clock()
	if now - (lastRoll[player] or 0) < ROLL_COOLDOWN then
		return { ok = false, reason = "cooldown" }
	end

	-- inventory full?
	local count = 0
	for _ in data.Inventory do
		count += 1
	end
	if count >= data.MaxSlots then
		return { ok = false, reason = "inventory_full" }
	end

	if data.Leaderstats.Cash < ROLL_COST then
		return { ok = false, reason = "not_enough_cash" }
	end

	lastRoll[player] = now
	data.Leaderstats.Cash -= ROLL_COST

	local id = WeightedRoll.pick(creatureEntries, math.random)
	local mutation: string? = WeightedRoll.pick(mutationEntries, math.random)
	if mutation == "None" then
		mutation = nil
	end

	local uid = HttpService:GenerateGUID(false)
	data.Inventory[uid] = { Id = id, Mutation = mutation, Count = 1 }
	data.Stats.TotalRolls += 1

	local rarity = ItemConfig[id].Rarity
	if RARE_BROADCAST[rarity] then
		RNGService.OnRare(player, id, mutation or "None", rarity)
	end

	return { ok = true, uid = uid, id = id, mutation = mutation, rarity = rarity }
end

return RNGService
