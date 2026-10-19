-- this structure is used from C++ as well
-- gametype has to be upper case 

AvailableMODList=
{
	ASSAULT={	team=1, 		respawntime=1,	mission="ASSAULT", },
	FFA=		{	team=0, 		respawntime=0,	mission="FFA", },
	TDM=		{	team=1, 		respawntime=0,	mission="TDM", },
	-- FarCryCoop: campaign co-op. mission is set per map by coop_map (campaign mission name = map name).
	COOP=		{	team=0, 		respawntime=0,	mission="Training", },
};

-- FarCryCoop: start a campaign map as a co-op server, e.g. "coop_map Pier"
function CoopMap(name)
	local mission = Game:GetMapDefaultMission(name);
	if (not mission) then
		System:LogAlways("coop_map: map '"..tostring(name).."' not found");
		return;
	end
	AvailableMODList.COOP.mission = mission;
	setglobal("g_GameType", "COOP");
	-- cutscene sequences need input and sound, which a dedicated server lacks (crashes in
	-- CMovieUser::BeginCutScene and CryMovie sound tracks); remote clients never see them anyway
	setglobal("mov_NoCutscenes", 1);
	local running = COOP_Map;
	COOP_Map = name; -- before loading: the COOP gamerules (and the monitor) read it on load
	if (running) then
		Game:LoadLevelMPServer(name, mission); -- server already up: keep the clients connected
	else
		Game:LoadLevelListen(name);
	end
end
Game:AddCommand("coop_map", "CoopMap(%line)", "coop_map <campaign map>: start a campaign map as a co-op server");
Game:AddCommand("coop_restart", "if (COOP_Map) then CoopMap(COOP_Map) end", "coop_restart: reload the current co-op map, clients stay connected");

-- FarCryCoop test commands for the host (server console) ------------------------------------

-- player entities of all connected slots; built without tinsert, which adds a field "n"
-- (Lua 4) that would show up as a number in "for i, P in CoopPlayers()"
function CoopPlayers()
	local t, k = {}, 0;
	for i, slot in Server:GetServerSlotMap() do
		local P = System:GetEntity(slot:GetPlayerId());
		if (P) then k = k + 1; t[k] = P; end
	end
	return t;
end

-- move every player next to pos and make it the respawn point
function CoopTeleport(pos, ang)
	_LastCheckPPos = new(pos);
	_LastCheckPAngles = new(ang);
	for i, P in CoopPlayers() do
		P:SetPos({x = pos.x + i, y = pos.y, z = pos.z}); -- 1 m apart so players do not stack
		P:SetAngles(ang);
	end
	System:LogAlways(format("coop: teleported to %.0f,%.0f,%.0f", pos.x, pos.y, pos.z));
end

-- campaign checkpoints are GameEvent entities (Properties.nId, nAllowedDeaths)
function CoopGoto(n)
	n = tonumber(n);
	local list = {};
	for i, e in System:GetEntities() do
		if (e.Properties and e.Properties.nId and e.Properties.nAllowedDeaths) then tinsert(list, e); end
	end
	sort(list, function(a, b) return a.Properties.nId < b.Properties.nId; end);
	for i = 1, getn(list) do
		local e = list[i];
		local t = e:GetPos(); -- GetPos/GetAngles return shared tables: copy the values
		local pos = {x = t.x, y = t.y, z = t.z};
		if (not n) then
			System:LogAlways(format("checkpoint %d at %.0f,%.0f,%.0f", e.Properties.nId, pos.x, pos.y, pos.z));
		elseif (e.Properties.nId == n) then
			t = e:GetAngles();
			CoopTeleport(pos, {x = t.x, y = t.y, z = t.z});
			return;
		end
	end
	if (n) then System:LogAlways("coop_goto: no checkpoint "..n); end
end
Game:AddCommand("coop_goto", "CoopGoto(%line)", "coop_goto [id]: list checkpoints, or move all players to checkpoint <id>");

function CoopSpawn(n)
	local pt = Server:GetRespawnPoint("Respawn"..tostring(n));
	if (not pt) then
		System:LogAlways("coop_spawn: no tagpoint Respawn"..tostring(n));
		return;
	end
	CoopTeleport({x = pt.x, y = pt.y, z = pt.z}, {x = pt.xA, y = pt.yA, z = pt.zA});
end
Game:AddCommand("coop_spawn", "CoopSpawn(%1)", "coop_spawn <n>: move all players to tagpoint Respawn<n>");

-- god mode is applied in COOP GameRules:OnUpdate
COOP_God = 0;
function CoopGod(on)
	COOP_God = tonumber(on) or (1 - COOP_God);
	System:LogAlways("coop_god "..COOP_God);
end
Game:AddCommand("coop_god", "CoopGod(%line)", "coop_god [0/1]: toggle god mode for all players");

-- refill every ammo type
function CoopAmmo()
	for i, P in CoopPlayers() do
		for ammotype, amount in MaxAmmo do
			if (P.Ammo and P.Ammo[ammotype]) then
				BasicPlayer.AddAmmo(P, ammotype, amount);
			end
		end
	end
	System:LogAlways("coop_ammo: all ammo types refilled");
end
Game:AddCommand("coop_ammo", "CoopAmmo()", "coop_ammo: refill every ammo type for all players");

-- noclip ("designer fly mode" of DevMode.lua): no gravity/inertia and no collision. Movement is
-- predicted on the client, so the server switches it for its copy of each player and tells
-- every client to do the same for its own player (ServerCommandTable["NOCLIP"] in COOP ClientStuff).
COOP_Noclip = 0;
function CoopSetNoclip(P, on)
	if (on == 1) then
		if (not P.COOP_SavedDyn) then P.COOP_SavedDyn = new(P.DynProp); end
		P.DynProp.gravity = 0; P.DynProp.inertia = 0;
		P.DynProp.swimming_gravity = 0; P.DynProp.swimming_inertia = 0; P.DynProp.air_control = 1;
		P.cnt:SetDynamicsProperties(P.DynProp);
		P:ActivatePhysics(0);
	elseif (P.COOP_SavedDyn) then
		P.DynProp = P.COOP_SavedDyn; P.COOP_SavedDyn = nil;
		P.cnt:SetDynamicsProperties(P.DynProp);
		P:ActivatePhysics(1);
	end
end
function CoopNoclip(on)
	COOP_Noclip = tonumber(on) or (1 - COOP_Noclip);
	for i, P in CoopPlayers() do CoopSetNoclip(P, COOP_Noclip); end
	for i, slot in Server:GetServerSlotMap() do slot:SendCommand("NOCLIP "..COOP_Noclip); end
	System:LogAlways("coop_noclip "..COOP_Noclip);
end
Game:AddCommand("coop_noclip", "CoopNoclip(%line)", "coop_noclip [0/1]: toggle noclip fly mode for all players");

-- give all players every weapon (9 slots, PLAYER_MAX_WEAPONS) plus full ammo
function CoopWeapons()
	for i, P in CoopPlayers() do
		for name, w in WeaponClassesEx do
			Game:AddWeapon(name);
			P.cnt:MakeWeaponAvailable(w.id);
		end
	end
	CoopAmmo();
	System:LogAlways("coop_weapons: all weapons given");
end
Game:AddCommand("coop_weapons", "CoopWeapons()", "coop_weapons: give all players every weapon and full ammo");
