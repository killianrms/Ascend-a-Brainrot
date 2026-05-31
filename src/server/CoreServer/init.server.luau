--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataManager = require(script.DataManager)
local RNGService = require(script.RNGService)
local IdleService = require(script.IdleService)
local EconomyService = require(script.EconomyService)

-- Build Network folders/instances.
local network = Instance.new("Folder")
network.Name = "Network"
local events = Instance.new("Folder")
events.Name = "RemoteEvents"
events.Parent = network
local funcs = Instance.new("Folder")
funcs.Name = "RemoteFunctions"
funcs.Parent = network

local function makeEvent(name: string): RemoteEvent
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = events
	return e
end
local function makeFunc(name: string): RemoteFunction
	local f = Instance.new("RemoteFunction")
	f.Name = name
	f.Parent = funcs
	return f
end

local RequestRoll = makeEvent("RequestRoll")
local SellItem = makeEvent("SellItem")
local PlaceItem = makeEvent("PlaceItem") -- arg: { uid = string, place = boolean }
local BuyUpgrade = makeEvent("BuyUpgrade") -- arg: kind ("plot"|"inv"|"luck"|"speed")
local ClaimOffline = makeEvent("ClaimOffline")
local BroadcastRareRoll = makeEvent("BroadcastRareRoll")
local ProfileUpdated = makeEvent("ProfileUpdated")
local GetProfile = makeFunc("GetProfile")

network.Parent = ReplicatedStorage

-- Start services.
DataManager.Start()
IdleService.Start()

-- Replicate a player's profile data to its owner.
local function pushProfile(player: Player)
	local profile = DataManager.Get(player)
	if profile then
		ProfileUpdated:FireClient(player, profile.Data)
	end
end

-- Push updated profile to everyone on a fixed cadence (simple slice replication).
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in Players:GetPlayers() do
			pushProfile(p)
		end
	end
end)

-- Roll
RequestRoll.OnServerEvent:Connect(function(player)
	local result = RNGService.Roll(player)
	RequestRoll:FireClient(player, result)
	pushProfile(player)
end)

-- Rare broadcast hook
RNGService.OnRare = function(player, id, mutation, rarity)
	BroadcastRareRoll:FireAllClients(player.Name, id, mutation, rarity)
end

-- Sell
SellItem.OnServerEvent:Connect(function(player, uid)
	if typeof(uid) == "string" then
		EconomyService.Sell(player, uid)
	end
	pushProfile(player)
end)

-- Place / unplace
PlaceItem.OnServerEvent:Connect(function(player, payload)
	if typeof(payload) == "table" and typeof(payload.uid) == "string" then
		if payload.place then
			EconomyService.Place(player, payload.uid)
		else
			EconomyService.Unplace(player, payload.uid)
		end
	end
	pushProfile(player)
end)

-- Buy an upgrade
BuyUpgrade.OnServerEvent:Connect(function(player, kind)
	if typeof(kind) == "string" then
		EconomyService.BuyUpgrade(player, kind)
	end
	pushProfile(player)
end)

-- Offline claim (already credited at load; this just clears the pending banner)
ClaimOffline.OnServerEvent:Connect(function(player)
	DataManager.ClearPendingOffline(player)
end)

-- Profile fetch (returns data + pending offline amount)
GetProfile.OnServerInvoke = function(player)
	local profile = DataManager.Get(player)
	if not profile then
		return nil
	end
	return { data = profile.Data, offline = DataManager.GetPendingOffline(player) }
end

print("[Ascend] server ready")
