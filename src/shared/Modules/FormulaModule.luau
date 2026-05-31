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

return F
