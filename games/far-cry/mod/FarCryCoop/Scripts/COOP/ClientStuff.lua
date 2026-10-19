-- FarCryCoop: client side of the co-op rules = single-player ClientStuff plus weapon preload.
Script:LoadScript("scripts/Default/ClientStuff.lua");

-- Campaign missions list only a few weapons in <Weapons><Used>; the server loads the rest on demand,
-- a remote client never does, so it cannot select, draw or fire them. OnInit runs after the level
-- is loaded and before the server sends the player, so load every weapon class here.
Coop_DefaultClientOnInit = ClientStuff.OnInit;
function ClientStuff:OnInit()
	Coop_DefaultClientOnInit(self);
	for name, def in WeaponClassesEx do
		Game:AddWeapon(name);
	end
end

-- coop_noclip from the server: switch fly mode for our own (predicted) player too
ClientStuff.ServerCommandTable["NOCLIP"] = function(String, toktable)
	if (_localplayer and CoopSetNoclip) then CoopSetNoclip(_localplayer, tonumber(toktable[2]) or 0); end
end
