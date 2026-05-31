--!strict
-- Pure data. Color stored as {r,g,b} (0-255) to stay Roblox-free / Lune-testable.
-- Converted to Color3 at the UI layer.
export type Creature = {
	Name: string,
	Weight: number, -- relative roll weight
	BaseIncome: number, -- cash per second when placed
	Color: { number }, -- {r, g, b}
	Rarity: string,
}

local ItemConfig: { [string]: Creature } = {
	creature_doge = { Name = "Doge", Weight = 700000, BaseIncome = 1, Color = { 150, 150, 150 }, Rarity = "Common" },
	creature_skibid = { Name = "Skibidi", Weight = 200000, BaseIncome = 5, Color = { 80, 200, 120 }, Rarity = "Uncommon" },
	creature_sigma = { Name = "Sigma", Weight = 50000, BaseIncome = 25, Color = { 59, 130, 246 }, Rarity = "Rare" },
	creature_giga = { Name = "GigaChad", Weight = 5000, BaseIncome = 150, Color = { 168, 85, 247 }, Rarity = "Epic" },
	creature_omega = { Name = "Omega God", Weight = 10, BaseIncome = 5000, Color = { 234, 179, 8 }, Rarity = "Divine" },
}

return ItemConfig
