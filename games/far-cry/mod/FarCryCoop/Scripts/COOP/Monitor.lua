-- FarCryCoop monitor: once a second the server ("S") and every client ("C") log the same "MON"
-- lines, so tools/mon-diff.ps1 can compare what each side sees:
--   MON S t=12 P <id> <name> pos=x,y,z hp= ar= w= clip= ammo= veh=      players
--   MON S t=12 A <id> <name> pos=x,y,z hp= beh= tgt=                   AI near players
--   MON S t=12 V <id> <name> pos=x,y,z drv=                             vehicles near players
--   MON S t=12 E <what> ...                                             events
-- Loaded by COOP gamerules (server) and COOP ClientStuff (client). coop_monitor 0/1 toggles it.
COOP_MON_AI_RADIUS = 60
COOP_MON_VEH_RADIUS = 150
if (COOP_MonitorOn == nil) then COOP_MonitorOn = 1; end
COOP_MonNext = {} -- per side, _time of the next sample
COOP_MonLast = {} -- per side and player id, last state for events

function CoopMonEvent(side, what)
	if (COOP_MonitorOn == 1) then System:LogAlways(format("MON %s t=%.1f E %s", side, _time, what)); end
end

-- human players: class "Player" (AI puppets have their own classes: Grunt, MercCover, ...)
function CoopMonPlayers()
	local t, k = {}, 0;
	for i, e in System:GetEntities() do
		if (e.classname == "Player") then k = k + 1; t[k] = e; end
	end
	return t;
end

function CoopMonPos(e)
	local p = e:GetPos();
	return {x = p.x, y = p.y, z = p.z}; -- GetPos returns a shared table: copy
end

function CoopMonNear(p, players, r)
	for i = 1, getn(players) do
		local q = players[i].pos;
		if ((p.x-q.x)*(p.x-q.x) + (p.y-q.y)*(p.y-q.y) + (p.z-q.z)*(p.z-q.z) < r*r) then return 1; end
	end
end

function CoopMonitor(side)
	if (COOP_MonitorOn ~= 1) then return; end
	-- _time restarts with every map load
	local nxt = COOP_MonNext[side] or 0;
	if (_time < nxt and nxt - _time <= 1) then return; end
	COOP_MonNext[side] = _time + 1;
	local head = format("MON %s t=%.1f", side, _time);
	local players = {};
	local last = COOP_MonLast[side] or {};
	COOP_MonLast[side] = last;
	for i, P in CoopMonPlayers() do
		local c, pos = P.cnt or {}, CoopMonPos(P);
		players[i] = {pos = pos};
		local veh = P.theVehicle and P.theVehicle:GetName() or "-";
		local w = c.GetCurrWeaponId and c:GetCurrWeaponId() or -1;
		System:LogAlways(format("%s P %d %s pos=%.1f,%.1f,%.1f hp=%s ar=%s w=%s clip=%s ammo=%s veh=%s", head, P.id,
			P:GetName(), pos.x, pos.y, pos.z, tostring(c.health), tostring(c.armor), tostring(w),
			tostring(c.ammo_in_clip), tostring(c.ammo), veh));
		local key = P:GetName(); -- not the id: a respawned player is a new entity
		local l = last[key];
		if (l) then
			local alive = (c.health or 0) > 0;
			if (l.id ~= P.id) then CoopMonEvent(side, "respawn "..P:GetName().." (new entity)");
			elseif (l.alive and not alive) then CoopMonEvent(side, "death "..P:GetName()); end
			if (alive and not l.alive) then CoopMonEvent(side, "spawn "..P:GetName()); end
			if (l.w ~= w) then CoopMonEvent(side, format("weapon %s %s->%s", P:GetName(), tostring(l.w), tostring(w))); end
			if (l.veh ~= veh) then CoopMonEvent(side, format("vehicle %s %s->%s", P:GetName(), l.veh, veh)); end
		end
		last[key] = {id = P.id, alive = (c.health or 0) > 0, w = w, veh = veh};
	end
	if (getn(players) == 0) then return; end
	for i, e in System:GetEntities() do
		if (e.classname ~= "Player") then
			if (e.type == "Player" or e.Behaviour) and e.Properties and e.Properties.species and e.cnt then
				local p = CoopMonPos(e);
				if (CoopMonNear(p, players, COOP_MON_AI_RADIUS)) then
					local tgt = AI and AI.GetAttentionTargetOf and AI:GetAttentionTargetOf(e.id);
					if (type(tgt) == "table") then tgt = tgt.GetName and tgt:GetName() or "table"; end
					System:LogAlways(format("%s A %d %s pos=%.1f,%.1f,%.1f hp=%s beh=%s tgt=%s", head, e.id, e:GetName(),
						p.x, p.y, p.z, tostring(e.cnt.health), tostring(e.Behaviour and e.Behaviour.Name), tostring(tgt)));
				end
			elseif (e.type == "Vehicle" or e.classname == "Gunship" or e.classname == "CargoChopper") then
				local p = CoopMonPos(e);
				if (CoopMonNear(p, players, COOP_MON_VEH_RADIUS)) then
					local d = e.driverT and e.driverT.entity;
					System:LogAlways(format("%s V %d %s pos=%.1f,%.1f,%.1f drv=%s", head, e.id, e:GetName(),
						p.x, p.y, p.z, d and d:GetName() or "-"));
				end
			elseif (e.classname == "AreaTrigger") then
				-- mission progress: every state change (enter/leave) and enable/disable, map-wide
				local st, key = tostring(e:GetState()).."/"..tostring(e.Enabled), "trg"..e.id;
				if (last[key] and last[key] ~= st) then
					CoopMonEvent(side, format("trigger %s %s->%s", e:GetName(), last[key], st));
				end
				last[key] = st;
			end
		end
	end
end

function CoopMonitorSet(on)
	COOP_MonitorOn = tonumber(on) or (1 - COOP_MonitorOn);
	System:LogAlways("coop_monitor "..COOP_MonitorOn);
end
Game:AddCommand("coop_monitor", "CoopMonitorSet(%line)", "coop_monitor [0/1]: log MON lines for tools/mon-diff.ps1");
