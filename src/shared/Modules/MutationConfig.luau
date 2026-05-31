--!strict
export type Mutation = { Weight: number, Mult: number, Vfx: string? }

local MutationConfig: { [string]: Mutation } = {
	None = { Weight = 1000000, Mult = 1, Vfx = nil },
	Gold = { Weight = 50000, Mult = 3, Vfx = "GoldShimmer" },
	Rainbow = { Weight = 5000, Mult = 10, Vfx = "RainbowCycle" },
	Divine = { Weight = 100, Mult = 50, Vfx = "DivineGlow" },
}

return MutationConfig
