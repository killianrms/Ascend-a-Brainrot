--!strict
local F = require("../src/shared/Modules/FormulaModule")

return function(t)
	-- Slot cost: BaseSlotCost(500) * Multiplier(1.8)^n
	t.eq(F.slotCost(0), 500, "slot 0 = 500")
	t.eq(F.slotCost(1), 900, "slot 1 = 900")
	t.approx(F.slotCost(2), 1620, 0.5, "slot 2 = 1620")

	-- Offline earnings: floor(min(dt, cap) * rate). cap = 12h.
	t.eq(F.offlineEarnings(10, 2, 0), 20, "10s * 2/s = 20")
	t.eq(F.offlineEarnings(50, 2, 0), 100, "under cap")
	-- capped at 12h = 43200s
	t.eq(F.offlineEarnings(999999, 2, 0), 43200 * 2, "capped at 12h")
	-- offline upgrade adds 2h cap per level
	t.eq(F.offlineEarnings(999999, 1, 1), (43200 + 7200) * 1, "cap +2h at level 1")

	-- Rebirth cost (used in later layer): 10000 * 2.5^R
	t.eq(F.rebirthCost(1), 25000, "rebirth 1")
end
