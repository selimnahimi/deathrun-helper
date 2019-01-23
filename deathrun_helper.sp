#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "HUNcamper"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <kvizzle>

// Constant variables
#define TF_TEAM_BLU			3
#define TF_TEAM_RED			2

// Sounds
#define SOUND_10SEC			"vo/announcer_ends_10sec.mp3"
#define SOUND_5SEC			"vo/announcer_ends_5sec.mp3"
#define SOUND_4SEC			"vo/announcer_ends_4sec.mp3"
#define SOUND_3SEC			"vo/announcer_ends_3sec.mp3"
#define SOUND_2SEC			"vo/announcer_ends_2sec.mp3"
#define SOUND_1SEC			"vo/announcer_ends_1sec.mp3"

// Convars
Handle g_drBluSpeed;					// Movement speed for BLU
Handle g_drRedSpeed;					// Movement speed for RED
Handle g_drSpeedEnabled;				// Enable/Disable the movement speed modifier
Handle g_drTimerEnabled;				// Enable/Disable the HUD timer
Handle g_drTimerTime;					// Timer start time
Handle g_drTimerTeam;					// Which team should win when the timer runs out (0: STALEMATE, 1: RED, 2: BLU)

// Player variables
new playerQueuePoints[MAXPLAYERS + 1];	// Queue points

// Sorted queue points array
new sortedQueuePoints[MAXPLAYERS + 1];
new sortedIDs[MAXPLAYERS + 1];

// Entity variables (they store the entity ID, not the entity itself)
new ent_stalemate;
new ent_bluwin;
new ent_redwin;

// Handles
Handle hudTimer; 

// Other
bool roundStarted = true;
float timerTime;

public Plugin myinfo = 
{
	name = "Deathrun Helper",
	author = PLUGIN_AUTHOR,
	description = "Queue point system for joining blue team",
	version = PLUGIN_VERSION,
	url = "https://github.com/HUNcamper/"
};


/*
 *	PLUGIN LOAD
*/
//- Check if server is running TF2
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	if (GetEngineVersion() != Engine_TF2) // If game isn't TF2
	{
		Format(error, err_max, "Deathrun Helper only works with Team Fortress 2");
		return APLRes_Failure; // Don't load the plugin
	}
	return APLRes_Success; // Load the plugin
}

/*
 *	PLUGIN START
*/
//- Initialize convars, hooks and other
public void OnPluginStart()
{
	// C O N V A R S //
	g_drBluSpeed = CreateConVar("dr_speed_blu", "400", "BLU team movement speed (in hammer units)");
	g_drRedSpeed = CreateConVar("dr_speed_red", "300", "RED team movement speed (in hammer units)");
	g_drSpeedEnabled = CreateConVar("dr_speed_enabled", "1", "Enable/Disable the movement speed modifier");
	g_drTimerEnabled = CreateConVar("dr_timer_enabled", "1", "Enable/Disable the HUD timer");
	g_drTimerTime = CreateConVar("dr_timer_time", "300", "Timer start time");
	g_drTimerTeam = CreateConVar("dr_timer_team", "2", "Which team should win when the timer runs out (0: STALEMATE, 1: RED, 2: BLU)");
	
	// A D M I N   C O M M A N D S //
	RegAdminCmd("sm_reloadmapconfig", Command_DR_ReloadConfig, ADMFLAG_ROOT, "sm_reloadmapconfig");
	
	// C O M M A N D S //
	RegConsoleCmd("jointeam", Command_Jointeam);
	RegConsoleCmd("next", Command_PanelViewQueuePoints);
	
	// H O O K S //
	HookEvent("teamplay_round_start", teamplay_round_start);
	HookEvent("arena_round_start", arena_round_start);
	
	// H U D   E L E M E N T S //
	hudTimer = CreateHudSynchronizer();
	
	// O T H E R //
	LoadTranslations("common.phrases"); // Load common translation file
	
	for (int i = 0; i <= MaxClients; i++)
	{
		playerQueuePoints[i] = 0;
		OnClientPutInServer(i);
	}
	
	CreateTimer(1.0, UpdateTimers, _, TIMER_REPEAT);
	Precache();
	reloadConfig();
}

/*
 *	PRECACHE
*/
//- Precaches sounds
stock Precache()
{
	// S O U N D S //
	PrecacheSound(SOUND_10SEC, true);
	PrecacheSound(SOUND_5SEC, true);
	PrecacheSound(SOUND_4SEC, true);
	PrecacheSound(SOUND_3SEC, true);
	PrecacheSound(SOUND_2SEC, true);
	PrecacheSound(SOUND_1SEC, true);
}

/*
 *	RELOAD CONFIG COMMAND
*/
//- Reloads the config file using kvizzle
public Action:Command_DR_ReloadConfig(client, args)
{
	reloadConfig();
	return Plugin_Handled;
}

/*
 *	RELOAD CONFIG
*/
//- Reloads the config file using kvizzle
public reloadConfig()
{
	// load config file
	decl String:config[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, config, PLATFORM_MAX_PATH, "configs/dr_maps.cfg");
	
	char currmap[32];
	GetCurrentMap(currmap, sizeof(currmap));
	
	new Handle:kv = KvizCreateFromFile("maps", config);
	
	if (kv != INVALID_HANDLE)
	{
		for (new i = 1; KvizExists(kv, ":nth-child(%i)", i); i++)
		{
			decl String:map[32], Float:ctimertime;
			int cspeedenabled, cbluspeed, credspeed, cwinteam, ctimerenabled;
			
			KvizGetStringExact(kv, map, sizeof(map), ":nth-child(%i):key", i);
			if (StrEqual(map, currmap, false))
			{
				if (KvizGetFloatExact(kv, ctimertime, ":nth-child(%i).roundtime", i))		SetConVarFloat(g_drTimerTime, ctimertime);
				if (KvizGetNumExact(kv, ctimerenabled, ":nth-child(%i).timerenabled", i))	SetConVarInt(g_drTimerEnabled, ctimerenabled);
				if (KvizGetNumExact(kv, cspeedenabled, ":nth-child(%i).speedenabled", i))	SetConVarInt(g_drSpeedEnabled, cspeedenabled);
				if (KvizGetNumExact(kv, cbluspeed, ":nth-child(%i).speedblu", i))			SetConVarInt(g_drBluSpeed, cbluspeed);
				if (KvizGetNumExact(kv, credspeed, ":nth-child(%i).speedred", i))			SetConVarInt(g_drRedSpeed, credspeed);
				if (KvizGetNumExact(kv, cwinteam, ":nth-child(%i).winteam", i))				SetConVarInt(g_drTimerTeam, cwinteam);
				PrintToServer("[DEATHRUN] Map config present and loaded.");
				break;
			}
		}
		
		KvizClose(kv);
	}
	else
	{
		PrintToServer("[DEATHRUN] NOTE There is no map config present!");
	}
}

/*
 *	UPDATE TIMER
*/
//- Handles HUD timer
public Action:UpdateTimers(Handle:timer)
{
	if(GetConVarBool(g_drTimerEnabled))
	{
		// If there is only 1 player, don't show the timer
		if(GetClientCount() > 1)
		{
			for (int i = 1; i < MaxClients; i++)
			{
				if (IsValidClient(i, false))
				{
					SetHudTextParams(-1.0, 0.20, 2.0, 0, 0, 255, 255);
					ShowSyncHudText(i, hudTimer, "%s", FormatTimer(timerTime));
				}
			}
			
			if (roundStarted)
			{
				if (timerTime > 0.0)
				{
					if (timerTime <= 10.0)
					{
						switch (timerTime)
						{
							case 10.0:
								EmitSoundToAll(SOUND_10SEC);
							case 5.0:
								EmitSoundToAll(SOUND_5SEC);
							case 4.0:
								EmitSoundToAll(SOUND_4SEC);
							case 3.0:
								EmitSoundToAll(SOUND_3SEC);
							case 2.0:
								EmitSoundToAll(SOUND_2SEC);
							case 1.0:
								EmitSoundToAll(SOUND_1SEC);
						}
					}
					timerTime--;
				}
				else
				{
					int winteam = GetConVarInt(g_drTimerTeam);
					
					if(winteam < 0 || winteam > 2)
						winteam = 2;
					
					Win(winteam);
				}
			}
		}
	}
}

/*
 *	FORMAT TIMER
*/
//- Returns a formatted time in mm:ss
String:FormatTimer(float sec)
{
	int cTime = RoundFloat(sec);
	int cmin = cTime / 60;
	int csec = cTime % 60;
	char ctext[32];
	if (csec < 10 && cmin >= 10)
		ctext = "%i:0%i";
	else if (csec < 10 && cmin < 10)
		ctext = "0%i:0%i";
	else if (csec >= 10 && cmin < 10)
		ctext = "0%i:%i";
	else
		ctext = "%i:%i";
	
	Format(ctext, sizeof(ctext), ctext, cmin, csec);
	
	return ctext;
}

/*
 *	ON CLIENT CONNECTED
*/
//- Triggers when a client connects
public OnClientPostAdminCheck(client)
{
	playerQueuePoints[client] = 0; // Reset their queue points
}

public OnClientPutInServer(client)
{
	if(IsValidClient(client, false)) SDKHook(client, SDKHook_PreThink, SDKHooks_OnPreThink);
}

public SDKHooks_OnPreThink(client)
{
	if(IsValidClient(client) && GetConVarBool(g_drSpeedEnabled))
	{
		if(roundStarted)
		{
			float speed = GetSpeedForTeam(client);
			if(speed != -1.0) SetSpeed(client, speed);
		}
	}
}

stock SetSpeed(client, Float:flSpeed)
{
	SetEntPropFloat(client, Prop_Send, "m_flMaxspeed", flSpeed);
}

stock Float:GetSpeedForTeam(client)
{
	if(GetClientTeam(client) == TF_TEAM_BLU)
	{
		return GetConVarFloat(g_drBluSpeed);
	}
	else if(GetClientTeam(client) == TF_TEAM_RED)
	{
		return GetConVarFloat(g_drRedSpeed);
	}
	
	return -1.0;
}

/*
 *	TEAMPLAY ROUND START
*/
//- Triggers when a round starts
public teamplay_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	InitializeRound();
	CreateWinEntities();
	roundStarted = false;
	reloadConfig();
}

/*
 *	ARENA ROUND START
*/
//- Triggers when an arena round starts
public arena_round_start(Handle:event, const String:name[], bool:dontBroadcast)
{
	roundStarted = true;
	
	int blucount = CountTeamPlayers(TF_TEAM_BLU);
	
	if(blucount == 0)
	{
		PrintToChatAll("[DEATHRUN] No players as Death, restarting round");
		Win(0);
	}
	else if(blucount >= 2)
	{
		PrintToChatAll("[DEATHRUN] Only 1 Death allowed, restarting match");
		Win(0);
	}
}


/*
 *	WIN
*/
//- Forces a win for a team
//+ team: 0: stalemate, 1: red, 2: blu
stock Win(int team)
{
	switch(team)
	{
		case 1:
			if (IsValidEntity(ent_redwin)) AcceptEntityInput(ent_redwin, "RoundWin");
		case 2:
			if (IsValidEntity(ent_bluwin)) AcceptEntityInput(ent_bluwin, "RoundWin");
		default:
			if (IsValidEntity(ent_stalemate)) AcceptEntityInput(ent_stalemate, "RoundWin");
	}
}

/*
 *	WIN ENTITY CREATION
*/
//- Creates custom entities to trigger team win when needed
stock CreateWinEntities()
{
	ent_stalemate = CreateEntityByName("game_round_win");
	
	if (IsValidEntity(ent_stalemate))
	{
		DispatchKeyValue(ent_stalemate, "force_map_reset", "1");
		DispatchKeyValue(ent_stalemate, "targetname", "win_stalemate");
		DispatchKeyValue(ent_stalemate, "teamnum", "0");
		SetVariantInt(0);
		AcceptEntityInput(ent_stalemate, "SetTeam");
		if (!DispatchSpawn(ent_stalemate))
			PrintToServer("[DEATHRUN] ERROR Failed to dispatch stalemate entity");
	}
	
	ent_bluwin = CreateEntityByName("game_round_win");
	
	if (IsValidEntity(ent_bluwin))
	{
		DispatchKeyValue(ent_bluwin, "force_map_reset", "1");
		DispatchKeyValue(ent_bluwin, "targetname", "win_blue");
		DispatchKeyValue(ent_bluwin, "teamnum", "3");
		SetVariantInt(3);
		AcceptEntityInput(ent_bluwin, "SetTeam");
		if (!DispatchSpawn(ent_bluwin))
			PrintToServer("[DEATHRUN] ERROR Failed to dispatch blue win entity");
	}
	
	ent_redwin = CreateEntityByName("game_round_win");
	
	if (IsValidEntity(ent_redwin))
	{
		DispatchKeyValue(ent_redwin, "force_map_reset", "1");
		DispatchKeyValue(ent_redwin, "targetname", "win_red");
		DispatchKeyValue(ent_redwin, "teamnum", "2");
		SetVariantInt(2);
		AcceptEntityInput(ent_redwin, "SetTeam");
		if (!DispatchSpawn(ent_redwin))
			PrintToServer("[DEATHRUN] ERROR Failed to dispatch red win entity");
	}
}

/*
 *	COUNT TEAM PLAYERS
*/
//- Count the amount of players in a team
stock int CountTeamPlayers(team)
{
	int count = 0;
	for (int i = 0; i <= MaxClients; i++)
	{
		if(IsValidClient(i, false))
		{
			if(GetClientTeam(i) == team) count++;
		}
	}
	
	return count;
}

/*
 *	INITIALIZE ROUND
*/
//- Initializes a round
stock InitializeRound()
{
	// Set HUD timer
	timerTime = GetConVarFloat(g_drTimerTime);
	
	int max_points = -1; // Store the player ID with the most points
	
	// Get the first valid client
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i)) max_points = i;
	}
	
	if(max_points == -1)
	{
		// No valid clients!
		PrintToServer("[DEATHRUN] WARNING Round started, but no valid clients found?");
		return;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && GetClientTeam(i) == TF_TEAM_RED)
		{
			playerQueuePoints[i] = playerQueuePoints[i] + 10;
			//PrintToChat(i, "Your points: %i", playerQueuePoints[i]);
			
			if(playerQueuePoints[i] > playerQueuePoints[max_points])
			{
				max_points = i;
			}
		}
	}
	
	// We got the player with the highest points, now:
	// - switch previous BLU players to RED
	// - switch them to BLU
	// - reset their points
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && GetClientTeam(i) == TF_TEAM_BLU && i != max_points)
		{
			PrintCenterText(i, "Your turn is over. You're a Runner now!");
			
			// Safely change the player's team, and teleport them to spawn
			ChangeClientTeam_Safe(i, TF_TEAM_RED);
			TeleportPlayerToSpawn(i, TF_TEAM_RED);
		}
	}
	
	// Safely change the player's team, and teleport them to spawn
	ChangeClientTeam_Safe(max_points, TF_TEAM_BLU);
	TeleportPlayerToSpawn(max_points, TF_TEAM_BLU);
	
	PrintCenterText(max_points, "You have been selected as Death!");
	PrintToChatAll("[DEATHRUN] %N has been selected as Death!", max_points);
	playerQueuePoints[max_points] = 0;
}

/*
 *	JOIN TEAM COMMAND
*/
//- Overwrite the join team command
public Action:Command_Jointeam(client, args)
{
	decl String:buffer[10], newteam, oldteam;
	GetCmdArg(1,buffer,sizeof(buffer));
	StripQuotes(buffer);
	TrimString(buffer);
	
	if(strlen(buffer) == 0) return Plugin_Handled; // If nothing was given, break the command
	else if (StrEqual(buffer, "blue", false)) newteam = TF_TEAM_BLU;
	else if (StrEqual(buffer, "spectator", false)) return Plugin_Continue;
	else newteam = TF_TEAM_RED; // Anything else drops the player to red
	
	oldteam = GetClientTeam(client);
	
	if (newteam == oldteam)return Plugin_Handled;
	
	if(IsValidClient(client, false))
	{
		if(newteam == TF_TEAM_BLU && CountTeamPlayers(TF_TEAM_BLU) != 0)
		{
			PrintCenterText(client, "You must wait for your turn!");
			TF2_ChangeClientTeam(client, TFTeam_Red);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

/*
 *	NEXT COMMAND
*/
//- View players queued to be Death, and your own points
public Action:Command_PanelViewQueuePoints(client, args)
{
	// First, copy the existing array
	for (int i = 1; i <= MaxClients; i++)
	{
		sortedIDs[i] = i;
		if(IsValidClient(i, false)) sortedQueuePoints[i] = playerQueuePoints[i];
		else sortedQueuePoints[i] = -1;
	}
	
	// Sort players score in order in new array
	for (int i = 0; i <= MaxClients; i++)
	{
		for (int j = i; j <= MaxClients; j++)
		{
			if(sortedQueuePoints[j] > sortedQueuePoints[i])
			{
				// If current element bigger than last, replace
				int temp1 = sortedQueuePoints[i];
				sortedQueuePoints[i] = sortedQueuePoints[j];
				sortedQueuePoints[j] = temp1;
				
				// also replace IDs to know which player is at what position
				int temp2 = sortedIDs[i];
				sortedIDs[i] = sortedIDs[j];
				sortedIDs[j] = temp2;
			}
		}
	}
	
	// Lastly, print clients via panel
	Panel panel = new Panel();
	panel.SetTitle("Death Queue");
	
	int maxprint = 8; // In case the current player is in the list, print 1 more player
	int done = 0;
	for (int i = 0; i <= maxprint; i++)
	{
		if(IsValidClient(sortedIDs[i], false) && sortedQueuePoints[i] != -1)
		{
			if(sortedIDs[i] != client)
			{
				// If sorted player isn't the current player
				char buffer[64];
				Format(buffer, sizeof(buffer), "%N-%i", sortedIDs[i], sortedQueuePoints[i]);
				panel.DrawItem(buffer);
			}
			else
			{
				// Otherwise print as normal text
				char buffer[64];
				Format(buffer, sizeof(buffer), "%N-%i", sortedIDs[i], sortedQueuePoints[i]);
				panel.DrawText(buffer);
				maxprint++;
			}
			
			done++;
			if (i == 1) panel.DrawText("---");
		}
	}
	
	// Fill in remaining slots
	for (int i = done; i <= maxprint; i++)
	{
		panel.DrawItem(" ");
	}
	
	char buffer[128];
	Format(buffer, sizeof(buffer), "Your queue point(s) is %i. (set to 0)", playerQueuePoints[client]);
	panel.DrawItem(buffer);
 	
	panel.Send(client, PanelHandler_ViewQueuePoints, 10);
 
	delete panel;
	
	return Plugin_Handled;
}

public int PanelHandler_ViewQueuePoints(Menu menu, MenuAction action, int client, int selected)
{
	if (action == MenuAction_Select)
	{
		if(selected == 10)
		{
			Panel panel = new Panel();
			panel.SetTitle("Are you sure that you want to reset your queue points?");
			panel.DrawItem("Yes");
			panel.DrawItem("Cancel");
			
			panel.Send(client, PanelHandler_ResetQueuePoints, 10);
		}
	}
}

public int PanelHandler_ResetQueuePoints(Menu menu, MenuAction action, int client, int selected)
{
	if (action == MenuAction_Select)
	{
		if(selected == 1)
		{
			PrintToServer("%N has reset their queue points", client);
			PrintToChat(client, "[DEATHRUN] Your queue points have been reset.");
		}
		if(selected == 2)
		{
			PrintToChat(client, "[DEATHRUN] You canceled your point reset.");
		}
	}
}

/*
 *	SWITCH PLAYER TEAM NOKILL
*/
//- Switch a player's team without killing them
stock ChangeClientTeam_Safe(client, team)
{
    new EntProp = GetEntProp(client, Prop_Send, "m_lifeState");
    SetEntProp(client, Prop_Send, "m_lifeState", 2);
    ChangeClientTeam(client, team);
    SetEntProp(client, Prop_Send, "m_lifeState", EntProp);
}  

/*
 *	TELEPORT PLAYER TO TEAM SPAWN
*/
//- Teleport a player to their team's spawn
stock TeleportPlayerToSpawn(client, team)
{
	new Float:SpawnLoc[3];
	GetSpawnPointTeam(team, SpawnLoc);
	
	//PrintToServer("Found entity: %i %i %i", SpawnLoc[0], SpawnLoc[1], SpawnLoc[2]);
	//SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", SpawnLoc); // BROKEN!!!
	TeleportEntity(client, SpawnLoc, NULL_VECTOR, NULL_VECTOR);
}

/*
 *	FIND SPAWNPOINT
*/
//- Find a spawnpoint's location for a team
stock GetSpawnPointTeam(team, Float:buffer[3])
{
	new index = -1;
	while ((index = FindEntityByClassname(index, "info_player_teamspawn")) != -1)
	{
		int teamnum = GetEntProp(index, Prop_Data, "m_iTeamNum");
		
		//int spawnmode = GetEntProp(index, Prop_Data, "m_iszRoundRedSpawn");
		//PrintToServer("Teamnum: %i spawnmode: %s", teamnum, buffer2);
		
		if(teamnum == team) // If spawnpoint is the given team's
		{
			new Float:SpawnLoc[3];
			GetEntPropVector(index, Prop_Data, "m_vecAbsOrigin", SpawnLoc); // We get the location of the entity
			
			buffer = SpawnLoc;
			return true;
		}
	}
	
	return false;
}

/*
 *	IS VALID CLIENT
*/
//- Checks if a client is valid or not
stock bool:IsValidClient(client, bool:bCheckAlive = true)
{
	if (client < 1 || client > MaxClients)return false;
	if (!IsClientInGame(client))return false;
	if (IsClientSourceTV(client) || IsClientReplay(client))return false;
	if (bCheckAlive)return IsPlayerAlive(client);
	return true;
}