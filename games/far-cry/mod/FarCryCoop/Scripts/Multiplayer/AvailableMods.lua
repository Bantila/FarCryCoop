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
	-- entities (AI included) update only when potentially visible from the camera; a dedicated
	-- server has no player camera, so the AI would stand still (hypothesis, test in game)
	setglobal("es_VisCheckForUpdate", 0);
	Game:LoadLevelListen(name);
end
Game:AddCommand("coop_map", "CoopMap(%line)", "coop_map <campaign map>: start a campaign map as a co-op server");

