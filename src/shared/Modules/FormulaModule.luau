--!strict
local F = {}

local BASE_SLOT_COST = 500
local SLOT_MULT = 1.8
local OFFLINE_BASE_CAP = 43200 -- 12h in seconds
local OFFLINE_CAP_PER_LEVEL = 7200 -- +2h per OfflineLevel
local BASE_REBIRTH_COST = 10000
local REBIRTH_SCALE = 2.5

function F.slotCost(n: number): number
	return math.floor(BASE_SLOT_COST * SLOT_MULT ^ n + 0.5)
end

-- dt seconds away, rate cash/sec, offlineLevel from Upgrades.
function F.offlineEarnings(dt: number, rate: number, offlineLevel: number): number
	local cap = OFFLINE_BASE_CAP + OFFLINE_CAP_PER_LEVEL * offlineLevel
	local effective = math.min(dt, cap)
	return math.floor(effective * rate)
end

function F.rebirthCost(r: number): number
	return math.floor(BASE_REBIRTH_COST * REBIRTH_SCALE ^ r + 0.5)
end

-- Plot slot (placement capacity) cost. `bought` = how many extra slots already purchased.
function F.plotSlotCost(bought: number): number
	return math.floor(1000 * 1.7 ^ bought + 0.5)
end

-- Luck upgrade cost. `level` = current LuckLevel.
function F.luckCost(level: number): number
	return math.floor(750 * 2 ^ level + 0.5)
end

-- Roll-speed upgrade cost. `level` = current SpeedLevel.
function F.speedCost(level: number): number
	return math.floor(750 * 2.2 ^ level + 0.5)
end

-- Luck multiplier applied to rare-tier roll weights: +15% per level (GDD "Chance Divine").
function F.luckMultiplier(level: number): number
	return 1 + 0.15 * level
end

-- Roll cooldown after speed upgrades (seconds), floored so it never hits zero.
function F.rollCooldown(baseCooldown: number, speedLevel: number): number
	return math.max(0.1, baseCooldown * (1 - 0.1 * speedLevel))
end

return F
