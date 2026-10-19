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
