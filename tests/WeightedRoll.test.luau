--!strict
local WeightedRoll = require("../src/shared/Modules/WeightedRoll")

return function(t)
	-- Deterministic pick: with a stubbed rng returning a fixed value,
	-- selection must land in the correct cumulative bucket.
	local entries = {
		{ key = "a", weight = 70 },
		{ key = "b", weight = 25 },
		{ key = "c", weight = 5 },
	}
	-- total = 100. rng returns value in [0,1); pick = floor(v*total)+1
	t.eq(WeightedRoll.pick(entries, function()
		return 0.0
	end), "a", "0.0 -> a")
	t.eq(WeightedRoll.pick(entries, function()
		return 0.69
	end), "a", "0.69 -> a")
	t.eq(WeightedRoll.pick(entries, function()
		return 0.70
	end), "b", "0.70 -> b")
	t.eq(WeightedRoll.pick(entries, function()
		return 0.94
	end), "b", "0.94 -> b")
	t.eq(WeightedRoll.pick(entries, function()
		return 0.95
	end), "c", "0.95 -> c")
	t.eq(WeightedRoll.pick(entries, function()
		return 0.999
	end), "c", "0.999 -> c")

	-- Distribution sanity: many samples roughly match weights.
	math.randomseed(1)
	local counts = { a = 0, b = 0, c = 0 }
	for _ = 1, 100000 do
		counts[WeightedRoll.pick(entries, math.random)] += 1
	end
	t.approx(counts.a / 100000, 0.70, 0.02, "a freq ~70%")
	t.approx(counts.c / 100000, 0.05, 0.02, "c freq ~5%")
end
