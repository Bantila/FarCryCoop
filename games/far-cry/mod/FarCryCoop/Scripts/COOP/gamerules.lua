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
	if _time < COOP_NextWake then return end
	COOP_NextWake = _time + 1
	local players = {}
	for i, slot in Server:GetServerSlotMap() do
		local P = System:GetEntity(slot:GetPlayerId())
		if P then
			local t = P:GetPos() -- GetPos returns a shared table: copy the values
			tinsert(players, {x = t.x, y = t.y, z = t.z})
		end
	end
	if getn(players) == 0 then return end
	local r2 = COOP_WAKE_RADIUS * COOP_WAKE_RADIUS
	for i, e in System:GetEntities() do
		if e.Behaviour and e.cnt and e.Properties and e.Properties.species and not e.COOP_Awake
			and e.Properties.bSleepOnSpawn ~= 1 and e.Enemy_Hidden ~= 1 then
			local p = e:GetPos()
			for j = 1, getn(players) do
				local q = players[j]
				if (p.x-q.x)*(p.x-q.x) + (p.y-q.y)*(p.y-q.y) + (p.z-q.z)*(p.z-q.z) < r2 then
					e:TriggerEvent(AIEVENT_WAKEUP)
					e:TriggerEvent(AIEVENT_ENABLE)
					e.COOP_Awake = 1
					break
				end
			end
		end
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
COOP_OldOnDamage = GameRules.OnDamage;
function GameRules:OnDamage(hit)
	local s, t = hit.shooter, hit.target;
	if (s and not s.ai and s ~= _localplayer and t and t.ai and not hit.COOP_ClientHit) then return end
	return COOP_OldOnDamage(self, hit);
end
