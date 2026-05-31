--!strict
-- Pure weighted selection. No Roblox globals -> Lune-testable.
local WeightedRoll = {}

export type Entry = { key: string, weight: number }

-- rng() must return a float in [0,1). Returns the selected entry key.
function WeightedRoll.pick(entries: { Entry }, rng: () -> number): string
	local total = 0
	for _, e in entries do
		total += e.weight
	end
	-- target in [1, total]
	local target = math.floor(rng() * total) + 1
	local cumulative = 0
	for _, e in entries do
		cumulative += e.weight
		if target <= cumulative then
			return e.key
		end
	end
	return entries[#entries].key -- fallback (float edge)
end

-- Convenience: build a sorted Entry list from a config map of {key = {Weight=n,...}}.
function WeightedRoll.fromConfig(config: { [string]: { Weight: number } }): { Entry }
	local entries = {}
	for key, data in config do
		table.insert(entries, { key = key, weight = data.Weight })
	end
	table.sort(entries, function(a, b)
		return a.key < b.key
	end) -- stable order
	return entries
end

return WeightedRoll
