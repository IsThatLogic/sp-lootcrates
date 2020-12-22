#pragma semicolon 1

#define DEBUG

#define PLUGIN_NAME "Loot Crates"
#define PLUGIN_AUTHOR "log-ical"
#define PLUGIN_VERSION "2.4.5"
#define PLUGIN_DESCRIPTION ""
#define PLUGIN_URL ""

#include <colors>
#include <sdktools>
#include <store>
#include <sourcemod>

public Plugin myinfo = 
{
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

int client_choice[64];
const int TIER_SIZE = 5;
int tier_price[TIER_SIZE] =  { 1000, 2500, 3000, 4000, 5000 };

bool g_aBought[MAXPLAYERS+1] = false; //boolean array to prevent players from buying crate >1 per round

Handle g_hTimer;

MenuHandler buy_callbacks[TIER_SIZE];

typedef TIER_CALLBACK_FUNC = function Action (int client);

public void OnPluginStart()
{
	RegConsoleCmd("sm_mcrate", menu1);

	buy_callbacks[0] = tier1buycallback;
 	buy_callbacks[1] = tier2buycallback; 
 	buy_callbacks[2] = tier3buycallback; 
 	buy_callbacks[3] = tier4buycallback; 
 	buy_callbacks[4] = tier5buycallback;

	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd);
}


public Action TimeCheck(Handle timer) //prevents crate buying after certain time
{
	g_hTimer = null;
}


public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for(int i=0;i<MAXPLAYERS;i++)
	{
		g_aBought[i] = false;
	}
	//resets bool array at start of round
	g_hTimer = CreateTimer(45.0, TimeCheck); //45 seconds after round, client cant buy crate
	return Plugin_Handled;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;
}

//checks if client issuing mcrate command is a member or not, this check is only so plugin can tell which menu to show
stock IsMember(int client)
{
	new AdminId:admin = GetUserAdmin(client);
	if ((admin != INVALID_ADMIN_ID) && (GetAdminFlag(admin, Admin_Reservation, Access_Effective)))
    {
        return true;
    }
	return false;
}


public Action menu1(int client, int args)
{
	if (IsPlayerAlive(client))
	{
		if (GetClientTeam(client) == 2)
		{
			if (g_aBought[client])
			{
				CPrintToChat(client, "{green}[SM] {lightgreen}You can only purchace one crate per round.");
				return Plugin_Handled;
			}
			if (g_hTimer == null)
			{
				CPrintToChat(client, "{green}[SM] {lightgreen}You can not purchase 45 seconds after round start.");
				return Plugin_Handled;
			}
			client_choice[client] = -1;

			Menu menu = new Menu(Menu_Callback);
			menu.SetTitle("Crates");
			menu.AddItem("t1", "Tier 1 (1000 Credits)");
			menu.AddItem("t2", "Tier 2 (2500 Credits)");
			menu.AddItem("t3", "Tier 3 (3000 Credits)");
			if(IsMember(client))
			{
				menu.AddItem("t4", "Tier 4 (4000 Credits)");
				menu.AddItem("t5", "Tier 5 (5000 Credits)");					
			}
			else
			{
				menu.AddItem("", "Tier 4 (Member Only)", ITEMDRAW_DISABLED);
				menu.AddItem("", "Tier 5 (Member Only)", ITEMDRAW_DISABLED);					
			}
			menu.Display(client, MENU_TIME_FOREVER);
			return Plugin_Handled;
		}
		else
		{
			CPrintToChat(client, "{green}[SM] {lightgreen}You need to be on the Terrorist team to use this command");
			return Plugin_Handled;
		}
	}
	else
	{
		CPrintToChat(client, "{green}[SM] {lightgreen}You need to be alive to use this command");
		return Plugin_Handled;
	}
}


//array of rewards for different tiers
//only for display
const int LIST_SIZE = 6;
new const String:reward[TIER_SIZE][LIST_SIZE][] =
{	
    {"HE","Smoke","Flash","Flash 2x","Body Armor","USP"},
    {"USP","Dual Elites","Flash 2x + HE","Full Nades","Armor + Helm","Armor + HE"},
    {"Armor + Helm","Deagle","HE + Smoke","Full Nades","Five Seven","Armor + USP"},
    {"Armor + Deagle","Armor+Helm+Full Nades","Deagle","Mac-10","Armor+Helm+p228","Armor + p228"},
    {"Armor+Helm+Mac-10","Armor+Mac-10","Armor+Deagle+Full Nades","Armor+Helm+Deagle","Scout","Mac-10"}

};

//name for each tier
new const String:tier_name[TIER_SIZE][] = 
{
    "Tier 1", "Tier 2", "Tier 3", "Tier 4", "Tier 5"
};

public int Menu_Callback(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
            client_choice[param1] = param2; //copies the clients choice to their very own personallized array cell
			//forwards item and tier information to tier function
            tier(param1, tier_name[param2],reward[param2][0] ,reward[param2][1], reward[param2][2], reward[param2][3], reward[param2][4], reward[param2][5], tier_name[param2]);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

public Action tier(int client, char[] tier, char [] item, char[] item2, char[] item3, char[] item4, char[] item5, char[] item6, char[] tierbuycallback)
{
	Menu menu = new Menu(tiercallback);
	menu.SetTitle(tier);
	menu.AddItem("", item, ITEMDRAW_DISABLED);
	menu.AddItem("", item2, ITEMDRAW_DISABLED);
	menu.AddItem("", item3, ITEMDRAW_DISABLED);
	menu.AddItem("", item4, ITEMDRAW_DISABLED);
	menu.AddItem("", item5, ITEMDRAW_DISABLED);
	menu.AddItem("", item6, ITEMDRAW_DISABLED);

	menu.AddItem("buy", "Buy");

	menu.Display(client, MENU_TIME_FOREVER);
}
public int tiercallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "buy"))
			{
				if (Store_GetClientCredits(param1) >= tier_price[client_choice[param1]]) //checks if clients credits is greater than or equal to the clients tier choice
				{
					tierbuyconf(param1, buy_callbacks[client_choice[param1]]); //if true move on to confirm the purchace 
				}
				else
				{//if the client doesnt have enough credits
					CPrintToChat(param1, "{green}[SM] {lightgreen}You do not have enough credits. Required credits: {default}%d {lightgreen}Your credits {default}%i{lightgreen}.", tier_price[client_choice[param1]], Store_GetClientCredits(param1));
				}
			}
			else
			{
				PrintToChat(param1, "[SM] A fatal error occured, please try again"); //just a check i put in incase anything breaks, cant imagine this ever being triggered
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}
public Action tierbuyconf(int client, MenuHandler callback)
{
	Menu menu = new Menu(callback);
	
	menu.SetTitle("Confirm Your Purchase");
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.AddItem("", "Warning!", ITEMDRAW_DISABLED);
	menu.AddItem("", "You may recieve duplicate items,", ITEMDRAW_DISABLED);
	menu.AddItem("", "if you do, they will be dropped on the floor", ITEMDRAW_DISABLED);
	menu.Display(client, MENU_TIME_FOREVER);
}

public int tier1buycallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			if (StrEqual(info, "yes"))
			{
				if (!IsPlayerAlive(param1) || GetClientTeam(param1) != 2) //should prevent people from obtaining items and losing credits when they arent supposed to.
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You need to be alive and on T to use this command");
					return 0;
				}
				if (g_hTimer == null) //second check, incase client opened menu prior to 45 second mark
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You can not purchase 45 seconds after round start.");
					return 0;
				}
				g_aBought[param1] = true;
				//deducts credits for tier
				int oldcredits = Store_GetClientCredits(param1); 
				int newcredits = oldcredits - 1000;
				Store_SetClientCredits(param1, newcredits);
				//picks random int
				int RandomInt = GetRandomInt(1, 6);
   				switch(RandomInt)
   				{
   					case 1: 
   					{
   						GivePlayerItem(param1, "weapon_hegrenade");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}HE Grenade{lightgreen}.");
   						return 0;
   					}
   					case 2:
   					{
   						GivePlayerItem(param1, "weapon_flashbang");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Flashbang{lightgreen}.");
   						return 0;
   					}
   					case 3: 
   					{
   						GivePlayerItem(param1, "weapon_flashbang");
   						GivePlayerItem(param1, "weapon_flashbang");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}2x Flashbangs{lightgreen}.");
   						return 0;
   					}
   					case 4:
   					{
   						GivePlayerItem(param1, "item_kevlar");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Body Armor{lightgreen}.");
   						return 0;
   					}
   					case 5:
   					{
   						GivePlayerItem(param1, "weapon_smokegrenade");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Smoke Grenade{lightgreen}.");
   						return 0;
   					}
   					case 6:
   					{
   						GivePlayerItem(param1, "weapon_usp");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}USP{lightgreen}.");
   						return 0;
   					}
    			}				
			}
			else if (StrEqual(info, "no"))
			{
				//I would have this point back to menu1, however, doing so could lead to players being able to break something.
				return 0;
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~TIER 2~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

public int tier2buycallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "yes"))
			{
				if (!IsPlayerAlive(param1) || GetClientTeam(param1) != 2)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You need to be alive and on T to use this command");
					return 0;
				}
				if (g_hTimer == null)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You can not purchase 45 seconds after round start.");
					return 0;
				}
				g_aBought[param1] = true;
				int oldcredits = Store_GetClientCredits(param1);
				int newcredits = oldcredits - 2500;
				Store_SetClientCredits(param1, newcredits);
				
				int RandomInt = GetRandomInt(1, 6);
   				switch(RandomInt)
   				{
   					case 1:
   					{
                        GivePlayerItem(param1, "weapon_usp", 0);
                        CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}USP{lightgreen}.");
                        GivePlayerAmmo(param1, 12, 6);
                        return 0;
   					}
   					case 2:
   					{
                        GivePlayerItem(param1, "weapon_elite");
                        CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Duel Elites{lightgreen}.");
                        return 0;
   					}
   					case 3:
   					{
                        GivePlayerItem(param1, "weapon_flashbang");
                        GivePlayerItem(param1, "weapon_flashbang");
                        GivePlayerItem(param1, "weapon_hegrenade");
                        CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}2x Flashbangs + HE Grenade{lightgreen}.");
                        return 0;
   					}
   					case 4:
   					{
                        GivePlayerItem(param1, "item_assaultsuit");
                        CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Armor + Helmet{lightgreen}.");
                        return 0;
   					}
   					case 5:
   					{
                        GivePlayerItem(param1, "item_kevlar");
                        GivePlayerItem(param1, "weapon_hegrenade");
                        CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Body Armor + HE Grenade{lightgreen}.");
                        return 0;
   					}
   					case 6:
   					{
                        GivePlayerItem(param1, "weapon_flashbang");
                        GivePlayerItem(param1, "weapon_flashbang");
                        GivePlayerItem(param1, "weapon_hegrenade"); 
                        GivePlayerItem(param1, "weapon_smokegrenade");
                        CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Full Nades{lightgreen}.");
                        return 0;
   					}
    			}				
			}
			else if (StrEqual(info, "no"))
			{
				return 0;
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~TIER 3~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

public int tier3buycallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "yes"))
			{
				if (!IsPlayerAlive(param1) || GetClientTeam(param1) != 2)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You need to be alive and on T to use this command");
					return 0;
				}
				if (g_hTimer == null)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You can not purchase 45 seconds after round start.");
					return 0;
				}
				g_aBought[param1] = true;
				int oldcredits = Store_GetClientCredits(param1);
				int newcredits = oldcredits - 3000;
				Store_SetClientCredits(param1, newcredits);
				
				int RandomInt = GetRandomInt(1, 6);
   				switch(RandomInt)
   				{
   					case 1: 
   					{
						GivePlayerItem(param1, "item_assaultsuit");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Armor + Helmet{lightgreen}.");
   						return 0;
   					}
   					case 2:
   					{
						GivePlayerItem(param1, "weapon_deagle");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Deagle{lightgreen}.");
   						GivePlayerAmmo(param1, 7, 8);
   						return 0;
   					}
   					case 3: 
   					{
						GivePlayerItem(param1, "weapon_hegrenade");
						GivePlayerItem(param1, "weapon_smokegrenade");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}HE Grenade + Smoke Grenade{lightgreen}.");
   						return 0;
   					}
   					case 4:
   					{
						GivePlayerItem(param1, "weapon_flashbang");
						GivePlayerItem(param1, "weapon_flashbang");
						GivePlayerItem(param1, "weapon_hegrenade"); 
						GivePlayerItem(param1, "weapon_smokegrenade");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Full Nades{lightgreen}.");
						return 0;
   					}
   					case 5: 
   					{
						GivePlayerItem(param1, "weapon_fiveseven");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Fiveseven{lightgreen}.");
						GivePlayerAmmo(param1, 20, 7);
   						return 0;
   					}
   					case 6: 
   					{
						GivePlayerItem(param1, "item_kevlar");
						GivePlayerItem(param1, "weapon_usp");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Body Armor + USP{lightgreen}.");
						GivePlayerAmmo(param1, 36, 6);
   						return 0;
   					}
    			}				
			}
			else if (StrEqual(info, "no"))
			{
				return 0;
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~TIER 4~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

public int tier4buycallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "yes"))
			{
				if (!IsPlayerAlive(param1) || GetClientTeam(param1) != 2)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You need to be alive and on T to use this command");
					return 0;
				}
				if (g_hTimer == null)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You can not purchase 45 seconds after round start.");
					return 0;
				}
				g_aBought[param1] = true;
				int oldcredits = Store_GetClientCredits(param1);
				int newcredits = oldcredits - 4000;
				Store_SetClientCredits(param1, newcredits);
				
				int RandomInt = GetRandomInt(1, 6);
   				switch(RandomInt)
   				{
   					case 1:
   					{
						GivePlayerItem(param1, "item_kevlar");
						GivePlayerItem(param1, "weapon_deagle");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Body Armor + Deagle{lightgreen}.");
						GivePlayerAmmo(param1, 35, 8);
   						return 0;
   					}
   					case 2:
   					{
						GivePlayerItem(param1, "item_assaultsuit");
						GivePlayerItem(param1, "weapon_flashbang");
						GivePlayerItem(param1, "weapon_flashbang");
   						GivePlayerItem(param1, "weapon_hegrenade"); 
						GivePlayerItem(param1, "weapon_smokegrenade");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Body Armor + Full Nades{lightgreen}.");
						return 0;
   					}
   					case 3:
   					{
						GivePlayerItem(param1, "weapon_deagle");
						GivePlayerAmmo(param1, 35, 8);
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Deagle{lightgreen}.");
   						return 0;
   					}
   					case 4:
   					{
						GivePlayerItem(param1, "weapon_mac10");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}MAC-10{lightgreen}.");
						GivePlayerAmmo(param1, 80, 6);
   						return 0;
   					}
   					case 5:
   					{
						GivePlayerItem(param1, "item_assaultsuit");
						GivePlayerItem(param1, "weapon_p228");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Armor + Helm + P228{lightgreen}.");
						GivePlayerAmmo(param1, 100, 9);
   						return 0;
   					}
					case 6:
					{
						GivePlayerItem(param1, "weapon_p228");
						GivePlayerAmmo(param1, 100, 9);
						GivePlayerItem(param1, "item_kevlar");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Armor + P228{lightgreen}.");
					}
    			}				
			}
			else if (StrEqual(info, "no"))
			{
				return 0;
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~TIER 5~~~~~~~~~~~~~~~~~~~~~~~~
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
public int tier5buycallback(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "yes"))
			{
				if (!IsPlayerAlive(param1) || GetClientTeam(param1) != 2)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You need to be alive and on T to use this command");
					return 0;
				}
				if (g_hTimer == null)
				{
					CPrintToChat(param1, "{green}[SM] {lightgreen}You can not purchase 45 seconds after round start.");
					return 0;
				}
				g_aBought[param1] = true;
				int oldcredits = Store_GetClientCredits(param1);
				int newcredits = oldcredits - 5000;
				Store_SetClientCredits(param1, newcredits);
				
				int RandomInt = GetRandomInt(1, 6);
   				switch(RandomInt)
   				{
   					case 1:
   					{
						GivePlayerItem(param1, "weapon_mac10");
						GivePlayerAmmo(param1, 80, 6);
						GivePlayerItem(param1, "item_assaultsuit");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}MAC-10 + Armor + Helm{lightgreen}.");
   						return 0;
   					}
   					case 2:
   					{
						GivePlayerItem(param1, "weapon_mac10");
						GivePlayerAmmo(param1, 80, 6);
						GivePlayerItem(param1, "item_kevlar");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}MAC-10 + Body Armor{lightgreen}.");
   						return 0;
   					}
   					case 3:
   					{
						GivePlayerItem(param1, "weapon_deagle");
						GivePlayerAmmo(param1, 35, 8);
						GivePlayerItem(param1, "item_kevlar");
						GivePlayerItem(param1, "weapon_flashbang");
						GivePlayerItem(param1, "weapon_flashbang");
						GivePlayerItem(param1, "weapon_hegrenade"); 
						GivePlayerItem(param1, "weapon_smokegrenade");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Full Nades + Deagle + Body Armor{lightgreen}.");
						return 0;
   					}
   					case 4:
   					{
						GivePlayerItem(param1, "item_assaultsuit");
						GivePlayerItem(param1, "weapon_deagle");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found {default}Armor + Helm + Deagle{lightgreen}.");
						GivePlayerAmmo(param1, 35, 8);
   						return 0;
   					}
   					case 5:
   					{
						GivePlayerItem(param1, "weapon_scout");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}Scout{lightgreen}.");
						GivePlayerAmmo(param1, 10, 2);
   						return 0;
   					}
   					case 6: 
   					{
						GivePlayerItem(param1, "weapon_mac10");
						CPrintToChat(param1, "{green}[SM]{lightgreen} You found a {default}MAC-10{lightgreen}.");
						GivePlayerAmmo(param1, 100, 6);
   						return 0;
   					}
    			}				
			}
			else if (StrEqual(info, "no"))
			{
				return 0;
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}
