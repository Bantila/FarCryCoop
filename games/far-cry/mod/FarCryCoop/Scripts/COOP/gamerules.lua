-- FarCryCoop: campaign co-op rules. For now the single-player rules as they are:
-- they already handle per-slot connect, disconnect and checkpoint respawn.
Script:LoadScript("scripts/Default/gamerules.lua");

-- On a dedicated server the AI puppets stay asleep: they stand still and never notice
-- anyone (the single-player game wakes them around its local player). Once a second wake
-- the puppets near any player. Puppets placed asleep on purpose (bSleepOnSpawn) or hidden
-- (Event_Hide) are left to their mission triggers.
COOP_WAKE_RADIUS = 150 -- ponytail: fixed radius, tune if far snipers or patrols stay frozen
COOP_NextWake = 0

function GameRules:OnUpdate(DeltaTime)
	if COOP_God == 1 then -- coop_god: refill every frame
		for i, P in CoopPlayers() do
			if P.cnt.health > 0 then P.cnt.health = P.cnt.max_health; end
		end
	end
	-- _time restarts with every map load, but Lua globals survive coop_restart
	if _time < COOP_NextWake and COOP_NextWake - _time <= 1 then return end
	COOP_NextWake = _time + 1
	if COOP_PendingLoad then CoopApplyLoad(); end
	local players = {}
	for i, P in CoopPlayers() do
		local t = P:GetPos() -- GetPos returns a shared table: copy the values
		players[i] = {x = t.x, y = t.y, z = t.z}
	end
	if getn(players) == 0 then return end
	local r2 = COOP_WAKE_RADIUS * COOP_WAKE_RADIUS
	for i, e in System:GetEntities() do
		if e.Behaviour and e.cnt and e.Properties and e.Properties.species and not e.COOP_Awake
			and e.Properties.bSleepOnSpawn ~= 1 and e.Enemy_Hidden ~= 1 then
			local t = e:GetPos()
			for j = 1, getn(players) do
				local q = players[j]
				if (t.x-q.x)*(t.x-q.x) + (t.y-q.y)*(t.y-q.y) + (t.z-q.z)*(t.z-q.z) < r2 then
					-- one bad entity must not stop the wake-up of the rest: catch and log once
					call(CoopWake, {e}, "x", CoopWakeError)
					break
				end
			end
		end
	end
end

function CoopWake(e)
	e.COOP_Awake = 1 -- set first, so a failing entity is not retried every second
	e:TriggerEvent(AIEVENT_WAKEUP)
	e:TriggerEvent(AIEVENT_ENABLE)
end

function CoopWakeError(msg)
	if not COOP_WakeErrorLogged then
		COOP_WakeErrorLogged = 1
		System:LogAlways("coop: AI wake-up error: "..tostring(msg))
	end
end

-- Client-side hits (see COOP ClientStuff): apply the damage a client reports for its own shot.
function GameRules:OnClientCmd(server_slot, cmd)
	local tk = tokenize(cmd);
	if (tk[1] == "CHIT") then CoopClientHit(server_slot, tk); end
end

function CoopClientHit(server_slot, tk)
	local shooter = System:GetEntity(server_slot:GetPlayerId());
	local target = System:GetEntity(tonumber(tk[2]) or 0);
	local damage = tonumber(tk[3]) or 0;
	if (not shooter or not target or target.type ~= "Player" or not BasicPlayer.IsAlive(shooter)
		or not BasicPlayer.IsAlive(target) or damage <= 0 or damage > 1000) then
		return; -- ponytail: trusts the client otherwise (co-op among friends), add checks if cheating matters
	end
	local hit = {
		shooter = shooter, target = target, weapon = shooter.cnt.weapon,
		damage = damage, ipart = tonumber(tk[4]) or -1, damage_type = "normal", landed = 1,
		target_material = Materials["mat_"..tk[5]] or Materials["mat_flesh"],
		pos = {x = tonumber(tk[6]), y = tonumber(tk[7]), z = tonumber(tk[8])},
		dir = {x = tonumber(tk[9]), y = tonumber(tk[10]), z = tonumber(tk[11])},
		normal = {x = -tonumber(tk[9]), y = -tonumber(tk[10]), z = -tonumber(tk[11])},
		impact_force_mul = 0, impact_force_mul_final = 0, impact_force_mul_final_torso = 0,
		COOP_ClientHit = 1,
	};
	target:Damage(hit);
end

-- Server-side bullets of remote players would double the client-reported damage: drop them.
-- The host of a listen server (its _localplayer) keeps server-side hits.
if (not COOP_OldOnDamage) then COOP_OldOnDamage = GameRules.OnDamage; end -- once: this file reloads on coop_restart
function GameRules:OnDamage(hit)
	local s, t = hit.shooter, hit.target;
	if (s and not s.ai and s ~= _localplayer and t and t.ai and not hit.COOP_ClientHit) then return end
	return COOP_OldOnDamage(self, hit);
end

-- coop_save / coop_load (testing checkpoint, kept in server memory, survives coop_restart but
-- not a server restart): players' position, health, armor and ammo, and which AI are dead.
-- Mission scripts, triggers and pickups are not saved. Static entity ids from the level XML
-- stay the same when the same map reloads, so dead AI are matched by id.
function CoopSave()
	if (not COOP_Map) then System:LogAlways("coop_save: no co-op map running"); return; end
	local save = {map = COOP_Map, players = {}, dead = {}};
	for i, P in CoopPlayers() do
		local t, a = P:GetPos(), P:GetAngles();
		save.players[i] = {
			pos = {x = t.x, y = t.y, z = t.z}, ang = {x = a.x, y = a.y, z = a.z},
			health = P.cnt.health, armor = P.cnt.armor, ammo = new(P.Ammo or {}),
		};
	end
	local nd = 0;
	for i, e in System:GetEntities() do
		if (e.ai and e.cnt and e.cnt.health and e.cnt.health <= 0) then nd = nd + 1; save.dead[nd] = e.id; end
	end
	COOP_Save = save;
	System:LogAlways(format("coop_save: %d players, %d dead AI on %s", getn(save.players), nd, save.map));
end
Game:AddCommand("coop_save", "CoopSave()", "coop_save: remember players and dead AI (testing checkpoint)");

function CoopLoad()
	if (not COOP_Save) then System:LogAlways("coop_load: nothing saved"); return; end
	COOP_PendingLoad = COOP_Save;
	CoopMap(COOP_Save.map); -- clients stay connected; CoopApplyLoad runs once players are back
end
Game:AddCommand("coop_load", "CoopLoad()", "coop_load: restart the map and restore the coop_save state");

function CoopApplyLoad()
	local save = COOP_PendingLoad;
	local list = CoopPlayers();
	if (getn(list) == 0) then return; end
	for i, P in list do
		if (not BasicPlayer.IsAlive(P)) then return; end -- wait until every player has spawned
	end
	COOP_PendingLoad = nil;
	for i = 1, getn(save.dead) do
		local e = System:GetEntity(save.dead[i]);
		if (e and e.ai) then System:RemoveEntity(e.id); end
	end
	for i, P in list do
		local s = save.players[i] or save.players[1];
		P:SetPos(s.pos);
		P:SetAngles(s.ang);
		P.cnt.health = s.health;
		P.cnt.armor = s.armor;
		for ammotype, n in s.ammo do P.Ammo[ammotype] = n; end
	end
	_LastCheckPPos = new(save.players[1].pos);
	_LastCheckPAngles = new(save.players[1].ang);
	System:LogAlways(format("coop_load: restored %d players, removed %d dead AI", getn(list), getn(save.dead)));
end
