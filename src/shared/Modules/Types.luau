--!strict
export type InventoryItem = {
	Id: string, -- key into ItemConfig
	Mutation: string?, -- key into MutationConfig (nil == "None")
	Count: number,
}

export type Profile = {
	Leaderstats: { Cash: number, Gems: number, Rebirths: number },
	Inventory: { [string]: InventoryItem }, -- keyed by UID
	Placed: { string }, -- UIDs generating income
	MaxSlots: number,
	Upgrades: { LuckLevel: number, SpeedLevel: number, OfflineLevel: number },
	Timestamps: { LastDisconnect: number, DailyStreak: number, LastDailyClaim: number },
	Stats: { TotalRolls: number, BestRarity: number },
}

export type RollResult = {
	ok: boolean,
	reason: string?, -- set when ok == false
	uid: string?,
	id: string?,
	mutation: string?,
	rarity: string?,
}

return {}
