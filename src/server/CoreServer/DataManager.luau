--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local FormulaModule = require(ReplicatedStorage.Modules.FormulaModule)

local PROFILE_TEMPLATE = {
	Leaderstats = { Cash = 0, Gems = 0, Rebirths = 0 },
	Inventory = {},
	Placed = {},
	MaxSlots = 12,
	Upgrades = { LuckLevel = 0, SpeedLevel = 0, OfflineLevel = 0 },
	Timestamps = { LastDisconnect = 0, DailyStreak = 0, LastDailyClaim = 0 },
	Stats = { TotalRolls = 0, BestRarity = 0 },
}

local STORE_NAME = if RunService:IsStudio() then "AscendDev_v1" else "AscendProd_v1"
local store = ProfileStore.New(STORE_NAME, PROFILE_TEMPLATE)

local DataManager = {}
local profiles: { [Player]: any } = {}

-- Pending offline payout to surface to the client after it asks for its profile.
local pendingOffline: { [Player]: number } = {}

function DataManager.Get(player: Player)
	return profiles[player]
end

function DataManager.GetPendingOffline(player: Player): number
	return pendingOffline[player] or 0
end

function DataManager.ClearPendingOffline(player: Player)
	pendingOffline[player] = nil
end

-- Current passive rate (cash/sec) from placed creatures. Injected by IdleService to avoid a
-- circular require; default returns 0 until injected.
DataManager.RateProvider = function(_player: Player): number
	return 0
end

local function onProfileLoaded(player: Player, profile)
	local data = profile.Data
	-- Offline earnings
	local last = data.Timestamps.LastDisconnect
	if last > 0 then
		local dt = os.time() - last
		if dt > 60 then
			local rate = DataManager.RateProvider(player)
			local earned = FormulaModule.offlineEarnings(dt, rate, data.Upgrades.OfflineLevel)
			if earned > 0 then
				data.Leaderstats.Cash += earned
				pendingOffline[player] = earned
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		player:Kick("Data load failed. Please rejoin.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("Data session ended. Please rejoin.")
	end)
	if player.Parent == Players then
		profiles[player] = profile
		onProfileLoaded(player, profile)
		print(`[Ascend] profile loaded for {player.Name}`)
	else
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Data.Timestamps.LastDisconnect = os.time()
		profile:EndSession()
	end
end

function DataManager.Start()
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- Autosave is handled by ProfileStore; LastDisconnect is updated on leave.
end

return DataManager
