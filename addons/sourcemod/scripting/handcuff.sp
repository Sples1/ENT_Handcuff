/*
 * SourceMod Entity Projects
 * by: Entity
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <smlib>
#include <sdkhooks>
#include <sdktools_sound>
#include <emitsoundany>
#include <entcuff>

#pragma newdecls required

//Global Vars
int nearest;

int g_bMinimumP = 2;
bool g_bEnabled = true;
bool g_bSounds = true;
float g_bRadius = 50.0;

Handle UseTimer[MAXPLAYERS + 1];
Handle UnUseTimer[MAXPLAYERS + 1];
Handle OPRC_CD[MAXPLAYERS + 1] = INVALID_HANDLE;
int C_UseTimer[MAXPLAYERS + 1] = 1;
int C_UnUseTimer[MAXPLAYERS + 1] = 1;
int C_Nearest[MAXPLAYERS + 1] = -1;

//Prisoner Vars
int C_ChoosedBy[MAXPLAYERS + 1];
bool C_HandCuffed[MAXPLAYERS + 1] = false;
bool C_GettingArrested[MAXPLAYERS + 1] = false;

//Guard Vars
int C_Choosen[MAXPLAYERS + 1];
bool C_HandCuffUsed[MAXPLAYERS + 1] = false;
bool C_Arresting[MAXPLAYERS + 1] = false;

//Translations
char Prefix[32] = "\x01[\x07HandCuff\x01] \x0B";
char t_Name[16] = "\x07HandCuff\x0B";

//ConVars
ConVar g_hEnabled;
ConVar g_hSounds;
ConVar g_hMinimum;
ConVar g_hRadius;

public Plugin myinfo = 
{
	name = "[CSGO][JB] Guard HandCuff", 
	author = "Entity", 
	description = "Adds the HandCuff feature to jailbreak.", 
	version = "0.1.2"
};

public void OnPluginStart()
{
	LoadTranslations("ent_handcuff.phrases");
	
	g_hEnabled = CreateConVar("sm_hc_enabled", "1", "Enable/Disable handcuff feature", 0, true, 0.0, true, 1.0);
	g_hSounds = CreateConVar("sm_hc_sounds", "1", "Use handcuff sounds on use", 0, true, 0.0, true, 1.0);
	g_hMinimum = CreateConVar("sm_hc_minimum", "2", "Minimum players to enable handcuffs", 0, true, 0.0, false, _);
	g_hRadius = CreateConVar("sm_hc_radius", "50.0", "Maxmimum radius to target players with handcuff", 0, true, 0.0, true, 1000.0);
	
	HookConVarChange(g_hEnabled, OnCvarChange_Enabled);
	HookConVarChange(g_hSounds, OnCvarChange_Sounds);
	HookConVarChange(g_hMinimum, OnCvarChange_Minimum);
	HookConVarChange(g_hRadius, OnCvarChange_Radius);
	
	HookEvent("player_spawn", OnPlayerSpawn);
	
	RegConsoleCmd("sm_handcuff", Command_HandCuff);
	RegConsoleCmd("sm_hc", Command_HandCuff);
	
	if (FileExists("sound/entity/handcuff/handcuff_on.mp3"))
	{
		AddFileToDownloadsTable("sound/entity/handcuff/handcuff_on.mp3");
		PrecacheSoundAny("entity/handcuff/handcuff_on.mp3");
	}
	else
	{
		g_bSounds = false;
		SetConVarInt(g_hSounds, 0);
	}
	
	if (FileExists("sound/entity/handcuff/handcuff_off.mp3"))
	{
		AddFileToDownloadsTable("sound/entity/handcuff/handcuff_off.mp3");
		PrecacheSoundAny("entity/handcuff/handcuff_off.mp3");
	}
	else
	{
		g_bSounds = false;
		SetConVarInt(g_hSounds, 0);
	}
	
	AutoExecConfig(true, "ent_handcuff");
}

public void OnPluginEnd()
{
	UnCuffAll();
}

public void OnMapStart()
{
	if (FileExists("sound/entity/handcuff/handcuff_on.mp3"))
	{
		AddFileToDownloadsTable("sound/entity/handcuff/handcuff_on.mp3");
		PrecacheSoundAny("entity/handcuff/handcuff_on.mp3");
	}
	else
	{
		g_bSounds = false;
		SetConVarInt(g_hSounds, 0);
	}
	
	if (FileExists("sound/entity/handcuff/handcuff_off.mp3"))
	{
		AddFileToDownloadsTable("sound/entity/handcuff/handcuff_off.mp3");
		PrecacheSoundAny("entity/handcuff/handcuff_off.mp3");
	}
	else
	{
		g_bSounds = false;
		SetConVarInt(g_hSounds, 0);
	}
}

public Action OnWeaponThingy(int client, int weapon)  
{
    return Plugin_Handled;
} 

public void OnCvarChange_Enabled(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	if (StrEqual(newvalue, "1"))
	{
		g_bEnabled = true;
	}
	else if (StrEqual(newvalue, "0"))
	{
		g_bEnabled = false;
		UnCuffAll();
	}
}

public void OnCvarChange_Sounds(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	if (StrEqual(newvalue, "1"))
	{
		if (FileExists("sound/entity/handcuff/handcuff_off.mp3") && FileExists("sound/entity/handcuff/handcuff_on.mp3"))
		{
			g_bSounds = true;
		}
		else
		{
			SetConVarInt(g_hSounds, 0);
			PrintToChatAll("%s %t", Prefix, "SoundsNotFound");
		}
	}
	else if (StrEqual(newvalue, "0"))
	{
		g_bSounds = false;
	}
}

public void OnCvarChange_Radius(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	g_bRadius = GetConVarFloat(g_hRadius);
}

public void OnCvarChange_Minimum(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	g_bMinimumP = GetConVarInt(g_hMinimum);
}

public Action Command_HandCuff(int client, int args)
{
	if (!g_bEnabled)
	{
		PrintToChat(client, "%s %t", Prefix, "TurnedOff", t_Name);
		return;
	}
	
	if (GetClientTeam(client) == 3)
	{
		if (IsPlayerAlive(client))
		{
			if (IsClientInGame(client))
			{
				float clientOrigin[3];
				float searchOrigin[3];
				
				GetClientAbsOrigin(client, clientOrigin);
				nearest = Client_GetClosestToClient(client);
				GetClientAbsOrigin(nearest, searchOrigin);

				float distance = GetVectorDistance(clientOrigin, searchOrigin);

				if (nearest != 0)
				{
					if(!IsFakeClient(nearest))
					{
						if (GetClientTeam(client) != GetClientTeam(nearest))
						{
							if (GetClientCount(true) < g_bMinimumP)
							{
								PrintToChat(client, "%s %t", Prefix, "NotEnough");
							}
							else
							{	
								if (distance <= g_bRadius && GetClientAimTarget(client, true) == nearest)
								{
									if (!C_HandCuffed[nearest])
									{
										if (!C_HandCuffUsed[client])
										{
											C_GettingArrested[nearest] = true;
											C_Arresting[client] = true;
											
											C_Nearest[client] = nearest;
											
											C_Choosen[client] = nearest;
											C_ChoosedBy[nearest] = client;
											
											PrintToChatAll("%s %t", Prefix, "StartedToHandCuff", client, nearest);
											
											UseTimer[client] = CreateTimer(1.0, Timer_UseTimerTick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
										}
										else
										{
											PrintToChat(client, "%s %t", Prefix, "UsedElse");
										}
									}
									else
									{
										if ((IsPlayerAlive(C_ChoosedBy[nearest]) && IsClientConnected(C_ChoosedBy[nearest]) && IsClientInGame(C_ChoosedBy[nearest]) && C_Choosen[client] != nearest) || C_Choosen[client] == nearest)
										{
											if (C_Choosen[client] == nearest)
											{
												C_Nearest[client] = nearest;
												
												PrintToChatAll("%s %t", Prefix, "StartedToUnCuff", client, nearest);
											
												UnUseTimer[client] = CreateTimer(1.0, Timer_UnUseTimerTick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
											}
											else
											{
											
												PrintToChat(client, "%s %t", Prefix, "WrongChoosen");
											}
										}
										else
										{
											C_Nearest[client] = nearest;
										
											PrintToChatAll("%s %t", Prefix, "StartedToUnCuff", client, nearest);
											
											UnUseTimer[client] = CreateTimer(1.0, Timer_UnUseTimerTick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
										}
									}
								}
								else
								{
									PrintToChat(client, "%s %t", Prefix, "NoOneFound");
								}
							}
						}
						else
						{
							PrintToChat(client, "%s %t", Prefix, "NearestCT");
						}
					}
					else
					{
						PrintToChat(client, "%s %t", Prefix, "ItsABot");
					}
				}
				else
				{
					PrintToChat(client, "%s %t", Prefix, "NoOneFound");
				}
			}
			else
			{
				PrintToChat(client, "%s %t", Prefix, "MustBeInGame");
			}
		}
		else
		{
			PrintToChat(client, "%s %t", Prefix, "MustBeAlive");
		}
	}
	else
	{
		PrintToChat(client, "%s %t", Prefix, "OnlyCT");
	}
}

public Action Timer_UseTimerTick(Handle timer, int client)
{
	if (C_UseTimer[client] == 0)
	{
		KillTimer(UseTimer[client]);
		UseTimer[client] = INVALID_HANDLE;
		
		C_UseTimer[client] = 1;
		
		HandCuffOn(client, C_Nearest[client]);
	}
	else
	{
		C_UseTimer[client] = C_UseTimer[client] - 1;
	}
	return Plugin_Continue;
}

public Action Timer_UnUseTimerTick(Handle timer, int client)
{
	if (C_UnUseTimer[client] == 0)
	{
		KillTimer(UnUseTimer[client]);
		UnUseTimer[client] = INVALID_HANDLE;
		
		C_UnUseTimer[client] = 1;
		
		HandCuffOff(client, C_Nearest[client], false);
	}
	else
	{
		C_UnUseTimer[client] = C_UnUseTimer[client] - 1;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client,int &buttons,int &impulse, float vel[3], float angles[3],int &weapon)
{
	if (IsValidClient(client) && (OPRC_CD[client] == INVALID_HANDLE))
	{
		if (buttons == IN_ATTACK || buttons == IN_JUMP || buttons == IN_DUCK || buttons == IN_FORWARD || buttons == IN_BACK || \
			buttons == IN_LEFT || buttons == IN_RIGHT || buttons == IN_WALK || buttons == IN_RUN || buttons == IN_SPEED || \
			buttons == IN_RELOAD || buttons == IN_ATTACK2 || buttons == IN_MOVELEFT || buttons == IN_MOVERIGHT)
		{
			if (GetClientTeam(client) == 2)
			{
				if (UseTimer[C_ChoosedBy[client]] != INVALID_HANDLE)
				{
					if (OPRC_CD[client] == INVALID_HANDLE)
					{
						KillTimer(UseTimer[C_ChoosedBy[client]]);
						UseTimer[C_ChoosedBy[client]] = INVALID_HANDLE;
						C_UseTimer[C_ChoosedBy[client]] = 1;
						
						PrintToChatAll("%s %t", Prefix, "StoppedHandCuff", C_ChoosedBy[client], client);
						OPRC_CD[client] = CreateTimer(0.25, Timer_OPRC_CD_Tick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
				else if (UnUseTimer[C_ChoosedBy[client]] != INVALID_HANDLE)
				{
					if (OPRC_CD[client] == INVALID_HANDLE)
					{
						KillTimer(UnUseTimer[C_ChoosedBy[client]]);
						UseTimer[C_ChoosedBy[client]] = INVALID_HANDLE;
						C_UseTimer[C_ChoosedBy[client]] = 1;
						
						PrintToChatAll("%s %t", Prefix, "StoppedUnCuff", C_ChoosedBy[client], client);
						OPRC_CD[client] = CreateTimer(0.25, Timer_OPRC_CD_Tick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
			else if (GetClientTeam(client) == 3)
			{
				int Choosen = C_Choosen[client]
				if (UseTimer[client] != INVALID_HANDLE)
				{
					if (OPRC_CD[client] == INVALID_HANDLE)
					{
						KillTimer(UseTimer[client]);
						UseTimer[client] = INVALID_HANDLE;
						C_UseTimer[client] = 1;
						
						PrintToChatAll("%s %t", Prefix, "StoppedHandCuff", client, C_Nearest[client]);
						OPRC_CD[client] = CreateTimer(0.25, Timer_OPRC_CD_Tick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
				else if (UnUseTimer[client] != INVALID_HANDLE)
				{
					if (OPRC_CD[client] == INVALID_HANDLE)
					{
						C_GettingArrested[Choosen] = false;
						C_Arresting[client] = false;
						
						KillTimer(UnUseTimer[client]);
						UnUseTimer[client] = INVALID_HANDLE;
						C_UnUseTimer[client] = 1;
						
						PrintToChatAll("%s %t", Prefix, "StoppedUnCuff", client, C_Nearest[client]);
						OPRC_CD[client] = CreateTimer(0.25, Timer_OPRC_CD_Tick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_OPRC_CD_Tick(Handle timer, int client)
{
	KillTimer(OPRC_CD[client]);
	OPRC_CD[client] = INVALID_HANDLE;
}

public Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	C_Choosen[client] = -1;
	C_ChoosedBy[client] = -1;
	C_HandCuffUsed[client] = false;
	C_HandCuffed[client] = false;
}

void HandCuffOn(int client, int target)
{
	PlaySound(false);
	
	C_HandCuffed[target] = true;
	C_HandCuffUsed[client] = true;

	SetEntityRenderColor(target, 50, 160, 255, 75);

	PrintToChatAll("%s %t", Prefix, "Handcuffed", client, target);
	SDKHook(target, SDKHook_WeaponCanUse, OnWeaponThingy);
	SaveWeapons(target);
}

void HandCuffOff(int client, int target, bool forced)
{
	PlaySound(true);
	
	C_Choosen[client] = -1;
	C_ChoosedBy[target] = -1;										

	C_HandCuffUsed[client] = false;
	C_HandCuffed[target] = false;

	SetEntityRenderColor(target, 255, 255, 255, 255);

	if (!forced) PrintToChatAll("%s %t", Prefix, "Uncuffed", client, target);
	SDKUnhook(target, SDKHook_WeaponCanUse, OnWeaponThingy);
	RestoreWeapons(target);
}

void PlaySound(bool Cuffed) 
{ 
	if (g_bSounds)
	{
		if (Cuffed)
		{
			if (FileExists("sound/entity/handcuff/handcuff_off.mp3"))
			{
				EmitSoundToAllAny("entity/handcuff/handcuff_off.mp3");
			}
		}
		else
		{
			if (FileExists("sound/entity/handcuff/handcuff_on.mp3"))
			{
				EmitSoundToAllAny("entity/handcuff/handcuff_on.mp3");
			}
		}
	}
}

void UnCuffAll()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && C_HandCuffed[i])
		{
			HandCuffOff(C_ChoosedBy[i], i, true);
			PrintToChatAll("%s %t", Prefix, "PluginStopped", i);
		}
	}
}