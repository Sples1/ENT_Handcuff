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

bool g_bEnabled = true;
bool g_bDebug = false;
int g_bMinimumP = 2;
bool g_bSounds = true;
float g_bRadius = 50.0;

Handle UseTimer[MAXPLAYERS + 1];
bool C_Checkable[MAXPLAYERS + 1];
bool S_TargetCuffed[MAXPLAYERS + 1];
int C_UseTimer[MAXPLAYERS + 1] = 1;
int C_Nearest[MAXPLAYERS + 1] = -1;

//Prisoner Vars
int C_ChoosedBy[MAXPLAYERS + 1];
bool C_HandCuffed[MAXPLAYERS + 1] = false;

//Guard Vars
int C_Choosen[MAXPLAYERS + 1];
bool C_HandCuffUsed[MAXPLAYERS + 1] = false;

//Translations
char Prefix[32] = "\x01[\x07HandCuff\x01] \x0B";
char DPrefix[32] = "\x01[\x07HandCuff-Debug\x01] \x0B";
char t_Name[16] = "\x07HandCuff\x0B";

//ConVars
ConVar g_hEnabled;
ConVar g_hDebug;
ConVar g_hMinimum;
ConVar g_hSounds;
ConVar g_hRadius;

public Plugin myinfo = 
{
	name = "[CSGO][JB] Guard HandCuff", 
	author = "Entity", 
	description = "Adds the HandCuff feature to jailbreak.", 
	version = "0.2"
};

public void OnPluginStart()
{
	LoadTranslations("ent_handcuff.phrases");
	
	g_hEnabled = CreateConVar("sm_hc_enabled", "1", "Enable/Disable handcuff feature", 0, true, 0.0, true, 1.0);
	g_hDebug = CreateConVar("sm_hc_debug", "0", "Enable/Disable handcuff debugs", 0, true, 0.0, true, 1.0);
	g_hSounds = CreateConVar("sm_hc_sounds", "1", "Use handcuff sounds on use", 0, true, 0.0, true, 1.0);
	g_hMinimum = CreateConVar("sm_hc_minimum", "2", "Minimum players to enable handcuffs", 0, true, 0.0, false, _);
	g_hRadius = CreateConVar("sm_hc_radius", "50.0", "Maxmimum radius to target players with handcuff", 0, true, 0.0, true, 1000.0);
	
	HookConVarChange(g_hEnabled, OnCvarChange_Enabled);
	HookConVarChange(g_hDebug, OnCvarChange_Debug);
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
		
		if (g_bDebug) PrintToChatAll("%s handcuff_on.mp3 found", DPrefix);
	}
	else
	{
		g_bSounds = false;
		SetConVarInt(g_hSounds, 0);
		
		if (g_bDebug) PrintToChatAll("%s handcuff_on.mp3 is missing", DPrefix);
	}
	
	if (FileExists("sound/entity/handcuff/handcuff_off.mp3"))
	{
		AddFileToDownloadsTable("sound/entity/handcuff/handcuff_off.mp3");
		PrecacheSoundAny("entity/handcuff/handcuff_off.mp3");
		
		if (g_bDebug) PrintToChatAll("%s handcuff_off.mp3 found", DPrefix);
	}
	else
	{
		g_bSounds = false;
		SetConVarInt(g_hSounds, 0);
		
		if (g_bDebug) PrintToChatAll("%s handcuff_off.mp3 is missing", DPrefix);
	}
}

public Action OnWeaponThingy(int client, int weapon)  
{
	if (g_bDebug) PrintToChatAll("%s %N tried to interact with a weapon", DPrefix, client);
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

public void OnCvarChange_Debug(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	if (StrEqual(newvalue, "1")) g_bDebug = true;
	else if (StrEqual(newvalue, "0")) g_bDebug = false;
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
					if(nearest != 0 /*!IsFakeClient(nearest)*/)
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
											C_Nearest[client] = nearest;
											
											C_Choosen[client] = nearest;
											C_ChoosedBy[nearest] = client;
											
											PrintToChatAll("%s %t", Prefix, "StartedToHandCuff", client, nearest);
											
											C_Checkable[client] = true;
											C_Checkable[nearest] = true;
											S_TargetCuffed[client] = false;
											
											if (g_bDebug) PrintToChatAll("%s %N started to handcuff %N", DPrefix, client, nearest);
											
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
											
												C_Checkable[client] = true;
												C_Checkable[nearest] = true;
												S_TargetCuffed[client] = true;
												
												if (g_bDebug) PrintToChatAll("%s %N started to uncuff %N", DPrefix, client, nearest);
												
												UseTimer[client] = CreateTimer(1.0, Timer_UseTimerTick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
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
											
											C_Checkable[client] = true;
											C_Checkable[nearest] = true;
											S_TargetCuffed[client] = true;
											
											if (g_bDebug) PrintToChatAll("%s %N started to uncuff %N", DPrefix, client, nearest);
											
											UseTimer[client] = CreateTimer(1.0, Timer_UseTimerTick, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
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
		
		C_Checkable[client] = false;
		C_Checkable[C_Nearest[client]] = false;
	
		if (!S_TargetCuffed[client])
		{		
			if (g_bDebug) PrintToChatAll("%s %N handcuff timer stopped", DPrefix, client);		
			HandCuffOn(client, C_Nearest[client]);
		}
		else
		{	
			if (g_bDebug) PrintToChatAll("%s %N uncuff timer stopped", DPrefix, client);		
			HandCuffOff(client, C_Nearest[client], false);
		}
	}
	else
	{
		C_UseTimer[client] = C_UseTimer[client] - 1;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client,int &buttons,int &impulse, float vel[3], float angles[3],int &weapon)
{
	if (IsValidClient(client) && C_Checkable[client])
	{
		if (buttons == IN_ATTACK || buttons == IN_JUMP || buttons == IN_DUCK || buttons == IN_FORWARD || buttons == IN_BACK || \
			buttons == IN_LEFT || buttons == IN_RIGHT || buttons == IN_WALK || buttons == IN_RUN || buttons == IN_SPEED || \
			buttons == IN_RELOAD || buttons == IN_ATTACK2 || buttons == IN_MOVELEFT || buttons == IN_MOVERIGHT)
		{
			if (GetClientTeam(client) == 2)
			{
				if (UseTimer[C_ChoosedBy[client]] != INVALID_HANDLE)
				{
					KillTimer(UseTimer[C_ChoosedBy[client]]);
					UseTimer[C_ChoosedBy[client]] = INVALID_HANDLE;
					C_UseTimer[C_ChoosedBy[client]] = 1;
					
					C_Checkable[client] = false;
					C_Checkable[C_Nearest[client]] = false;
					
					if (!S_TargetCuffed[C_ChoosedBy[client]])
					{
						if (g_bDebug) PrintToChatAll("%s %N stopped %N handcuff timer", DPrefix, client, C_ChoosedBy[client]);
						PrintToChatAll("%s %t", Prefix, "StoppedHandCuff", C_ChoosedBy[client], client);
					}
					else
					{
						if (g_bDebug) PrintToChatAll("%s %N stopped %N unndcuff timer", DPrefix, client, C_ChoosedBy[client]);
						PrintToChatAll("%s %t", Prefix, "StoppedUnCuff", C_ChoosedBy[client], client);
					}
				}
			}
			else if (GetClientTeam(client) == 3)
			{			
				if (UseTimer[client] != INVALID_HANDLE)
				{
					KillTimer(UseTimer[client]);
					UseTimer[client] = INVALID_HANDLE;
					C_UseTimer[client] = 1;
					
					C_Checkable[client] = false;
					C_Checkable[C_Nearest[client]] = false;
					
					if (!S_TargetCuffed[client])
					{
						if (g_bDebug) PrintToChatAll("%s %N stopped %N handcuff timer", DPrefix, client, client);
						PrintToChatAll("%s %t", Prefix, "StoppedHandCuff", client, C_Nearest[client]);
					}
					else
					{
						if (g_bDebug) PrintToChatAll("%s %N stopped %N uncuff timer", DPrefix, client, client);
						PrintToChatAll("%s %t", Prefix, "StoppedUnCuff", client, C_Nearest[client]);
					}
				}
			}
		}
	}
	return Plugin_Continue;
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
	
	if (g_bDebug) PrintToChatAll("%s %N got handcuffed succesfully", DPrefix, target);
	
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
	
	if (g_bDebug) PrintToChatAll("%s %N got uncuffed succesfully", DPrefix, target);
	
	RestoreWeapons(target);
}

void PlaySound(bool Cuffed) 
{ 
	if (g_bSounds)
	{
		if (g_bDebug) PrintToChatAll("%s Handcuff sounds found", DPrefix);
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
	if (g_bDebug) PrintToChatAll("%s Every player has been uncuffed", DPrefix);
}