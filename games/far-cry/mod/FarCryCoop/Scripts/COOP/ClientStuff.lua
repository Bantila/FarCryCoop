-- FarCryCoop: client side of the co-op rules = single-player ClientStuff plus weapon preload.
Script:LoadScript("scripts/Default/ClientStuff.lua");
Script:LoadScript("scripts/COOP/Monitor.lua");

-- Campaign missions list only a few weapons in <Weapons><Used>; the server loads the rest on demand,
-- a remote client never does, so it cannot select, draw or fire them. OnInit runs after the level
-- is loaded and before the server sends the player, so load every weapon class here.
Coop_DefaultClientOnInit = ClientStuff.OnInit;
function ClientStuff:OnInit()
	Coop_DefaultClientOnInit(self);
	for name, def in WeaponClassesEx do
		Game:AddWeapon(name);
	end
	CoopMonEvent("C", "map");
end

Coop_DefaultClientOnUpdate = ClientStuff.OnUpdate;
function ClientStuff:OnUpdate()
	Coop_DefaultClientOnUpdate(self);
	CoopMonitor("C");
end

-- Client-side hit detection: the shooter's own client decides what its bullets hit and tells
-- the server ("CHIT", handled in COOP GameRules:OnClientCmd), so aiming does not depend on the
-- host's connection. CWeaponClass caches each weapon's Client.OnHit when the class loads, so the
-- hook sits on the global ExecuteMaterial2(hit, effect), which Client:OnHit calls for every hit.
if (not COOP_OrigExecuteMaterial2) then
	COOP_OrigExecuteMaterial2 = ExecuteMaterial2;
	ExecuteMaterial2 = function(hit, effect)
		CoopReportHit(hit);
		return COOP_OrigExecuteMaterial2(hit, effect);
	end
end
function CoopReportHit(hit)
	local t, s = hit.target, hit.shooter;
	if (s ~= _localplayer or not t or t == s or t.type ~= "Player" or not BasicPlayer.IsAlive(t)) then return end
	Hud.hit = 5; -- red crosshair right away, as in single player
	if (Game:IsServer()) then return end -- listen-server host: its shots are already server-side
	local p, d = hit.pos, hit.dir;
	local mat = hit.target_material and hit.target_material.type or "flesh";
	Client:SendCommand(format("CHIT %d %.2f %d %s %.2f %.2f %.2f %.3f %.3f %.3f", t.id, hit.damage or 0,
		hit.ipart or -1, mat, p.x, p.y, p.z, d.x, d.y, d.z));
end

-- coop_noclip from the server: switch fly mode for our own (predicted) player too
ClientStuff.ServerCommandTable["NOCLIP"] = function(String, toktable)
	if (_localplayer and CoopSetNoclip) then CoopSetNoclip(_localplayer, tonumber(toktable[2]) or 0); end
end

-- AI animation started by the server (melee swing, see COOP gamerules CoopUpdateMelee)
ClientStuff.ServerCommandTable["ANIM"] = function(String, toktable)
	local e = System:GetEntity(tonumber(toktable[2]) or 0);
	if (e and toktable[3]) then
		e:StartAnimation(0, toktable[3], 3, 0.1);
		CoopMonEvent("C", "anim "..e:GetName().." "..toktable[3]);
	end
end

-- sequences forwarded by the server (see COOP gamerules); names may contain spaces ("HIDE ALL").
-- Cutscene-flagged sequences stay off like on the server (mov_NoCutscenes).
setglobal("mov_NoCutscenes", 1);
ClientStuff.ServerCommandTable["SEQ"] = function(String, toktable)
	CoopMonEvent("C", "sequence "..strsub(String, 5));
	if (not Game:IsServer()) then Movie:PlaySequence(strsub(String, 5)); end
end
ClientStuff.ServerCommandTable["SEQSTOP"] = function(String, toktable)
	if (not Game:IsServer()) then Movie:StopSequence(strsub(String, 9)); end
end
