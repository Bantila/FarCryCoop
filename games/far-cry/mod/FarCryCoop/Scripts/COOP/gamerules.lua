-- FarCryCoop: campaign co-op rules. For now the single-player rules as they are:
-- they already handle per-slot connect, disconnect and checkpoint respawn.
Script:LoadScript("scripts/Default/gamerules.lua");
Script:LoadScript("scripts/COOP/Monitor.lua");
CoopMonEvent("S", "map "..tostring(COOP_Map)); -- this file runs on every map load

-- Load every weapon class on the server before players spawn: a player's weapon table
-- (CPlayer::m_mapPlayerWeapons) only has the classes loaded at that time, so weapons outside the
-- mission's <Weapons><Used> list could never be given (MakeWeaponAvailable returned -1).
-- On the first map load this file runs before WeaponClassesEx exists, so GameRules:OnUpdate
-- does it on its first tick (a loop here aborted the whole file: no co-op rules at all).
COOP_WeaponsLoaded = nil -- this file runs on every map load
function CoopPreloadWeapons()
	if (COOP_WeaponsLoaded or not WeaponClassesEx) then return; end
	COOP_WeaponsLoaded = 1;
	for name, def in WeaponClassesEx do
		Game:AddWeapon(name);
	end
end

-- On a dedicated server the AI puppets stay asleep: they stand still and never notice
-- anyone (the single-player game wakes them around its local player). Once a second wake
-- the puppets near any player. Puppets placed asleep on purpose (bSleepOnSpawn) or hidden
-- (Event_Hide) are left to their mission triggers.
COOP_WAKE_RADIUS = 150 -- ponytail: fixed radius, tune if far snipers or patrols stay frozen
COOP_NextWake = 0

-- AI melee without animations. The server deals AI melee damage on the KEYFRAME_APPLY_MELEE
-- animation event, but a dedicated server never ticks character animations (nothing is rendered),
-- so mutants run up and stand there. Every behaviour's OnCloseContact (it starts the melee
-- animation, every frame while in contact) marks the entity; COOP_MELEE_DELAY later the
-- keyframe handler runs as if the animation had reached the hit, at most every COOP_MELEE_PERIOD.
-- A real keyframe (listen-server host watching) cancels the pending fake one.
-- ponytail: fixed timing for every AI, read it from the melee animation length if it feels off
COOP_MELEE_DELAY = 0.35
COOP_MELEE_PERIOD = 1.2
COOP_MeleeContact = {}
COOP_MeleeDue = {}
-- AI behaviours compare players with _localplayer (nil on a dedicated server, the host on a
-- listen server): "retaliate against who shot me", the trigen jump, cars and boats (which even
-- index _localplayer.theVehicle and break). While any behaviour function runs, _localplayer is
-- the player this AI deals with: the sender if it is a player, else its attention target if it
-- is a player, else the nearest player. Errors are caught so _localplayer is always restored,
-- and logged once per function.
COOP_AIPlayers = {}
function CoopAIPlayer(entity, sender)
	if (type(sender) == "table" and sender.classname == "Player") then return sender; end
	local t = AI:GetAttentionTargetOf(entity.id);
	if (type(t) == "table" and t.classname == "Player") then return t; end
	local best, bd, p = nil, nil, entity:GetPos();
	for i, P in COOP_AIPlayers do
		local q = P:GetPos();
		local d = (p.x-q.x)*(p.x-q.x) + (p.y-q.y)*(p.y-q.y) + (p.z-q.z)*(p.z-q.z);
		if (not bd or d < bd) then best, bd = P, d; end
	end
	return best;
end
function CoopWrapBehaviour(bname, fname, old)
	local where = bname.."."..fname;
	return function(...)
		local saved, entity, where = _localplayer, arg[2], %where; -- Lua 4: upvalues reach one level only
		if (type(entity) == "table" and entity.id) then
			_localplayer = CoopAIPlayer(entity, arg[3]) or saved;
		end
		local r = call(%old, arg, "x", function(msg)
			if (not COOP_AIErrors[%where]) then
				COOP_AIErrors[%where] = 1;
				System:LogAlways("coop: AI error in "..%where..": "..tostring(msg));
			end
		end);
		_localplayer = saved;
		return r;
	end
end
if (not COOP_AIErrors) then COOP_AIErrors = {}; end

-- behaviours load on demand, so this runs once a second for new ones
function CoopWrapBehaviours()
	for bname, b in AIBehaviour do
		if (type(b) == "table" and not b.COOP_Wrapped) then
			b.COOP_Wrapped = 1;
			for fname, f in b do
				if (type(f) == "function") then b[fname] = CoopWrapBehaviour(bname, fname, f); end
			end
			if (b.OnCloseContact) then
				local old = b.OnCloseContact;
				b.OnCloseContact = function(self, entity, sender)
					COOP_MeleeContact[entity.id] = 1;
					return %old(self, entity, sender);
				end
			end
		end
	end
end
if (not COOP_OrigAnimKey) then
	COOP_OrigAnimKey = BasicPlayer.Server_EventHandler[ScriptEvent_AnimationKey];
end
BasicPlayer.Server_EventHandler[ScriptEvent_AnimationKey] = function(self, Params)
	if (not COOP_FakeKey and type(Params) == "table" and Params.number == KEYFRAME_APPLY_MELEE) then
		COOP_MeleeDue[self.id] = nil; -- the real animation got there
	end
	return COOP_OrigAnimKey(self, Params);
end
function CoopUpdateMelee()
	for id, v in COOP_MeleeContact do
		local e = System:GetEntity(id);
		if (e and not COOP_MeleeDue[id] and _time >= (e.COOP_MeleeNext or 0)) then
			COOP_MeleeDue[id] = _time + COOP_MELEE_DELAY;
			e.COOP_MeleeNext = _time + COOP_MELEE_PERIOD;
			-- AI animations are not sent over the network: tell the clients to play the swing
			if ((e.MELEE_ANIM_COUNT or 0) > 0) then
				Server:BroadcastCommand(format("ANIM %d attack_melee%d", id, random(1, e.MELEE_ANIM_COUNT)));
			end
		end
	end
	COOP_MeleeContact = {};
	for id, t in COOP_MeleeDue do
		if (_time >= t or t - _time > COOP_MELEE_DELAY) then -- second test: _time restarted on map load
			COOP_MeleeDue[id] = nil;
			local e = System:GetEntity(id);
			if (e and e.cnt and e.cnt.health > 0) then
				COOP_FakeKey = 1;
				BasicPlayer.Server_EventHandler[ScriptEvent_AnimationKey](e, {number = KEYFRAME_APPLY_MELEE});
				COOP_FakeKey = nil;
			end
		end
	end
end

function GameRules:OnUpdate(DeltaTime)
	CoopPreloadWeapons()
	COOP_AIPlayers = CoopPlayers() -- for CoopAIPlayer; every frame, players respawn as new entities
	CoopMonitor("S")
	CoopUpdateMelee()
	if COOP_God == 1 then -- coop_god: refill every frame
		for i, P in CoopPlayers() do
			if P.cnt.health > 0 then P.cnt.health = P.cnt.max_health; end
		end
	end
	-- _time restarts with every map load, but Lua globals survive coop_restart
	if _time < COOP_NextWake and COOP_NextWake - _time <= 1 then return end
	COOP_NextWake = _time + 1
	CoopWrapBehaviours()
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

-- Movie sequences (e.g. the heli fly-by on Pier, started by a ProximityTrigger) play only on
-- the machine that calls Movie:PlaySequence, and the entities they animate are not sent over
-- the network. The server forwards every sequence start/stop to the clients ("SEQ"/"SEQSTOP",
-- handled in COOP ClientStuff). Once: this file reloads on coop_restart.
if (not COOP_OrigPlaySequence) then
	COOP_OrigPlaySequence, COOP_OrigStopSequence = Movie.PlaySequence, Movie.StopSequence;
	Movie.PlaySequence = function(self, name)
		CoopMonEvent("S", "sequence "..tostring(name));
		COOP_OrigPlaySequence(self, name);
		Server:BroadcastCommand("SEQ "..tostring(name));
	end
	Movie.StopSequence = function(self, name)
		COOP_OrigStopSequence(self, name);
		Server:BroadcastCommand("SEQSTOP "..tostring(name));
	end
end
