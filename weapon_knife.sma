#include <amxmodx>
#include <reapi>
#include <engine>
#include <fakemeta>
#include <hamsandwich>

#include <xs>

#include <msg_floatstocks>
 
new PLUGIN_NAME[] = "UNREAL KNIFE";
new PLUGIN_VERSION[] = "1.1";
new PLUGIN_AUTHOR[] = "Karaulov";

new UNREAL_KNIFE_MAX_AMMO = 10;
new Float:UNREAL_KNIFE_MAX_DMG = 20.0;
new Float:UNREAL_KNIFE_RELOAD_RATE = 1.0;
new Float:UNREAL_KNIFE_REMOVE_DELAY = 0.5;
new Float:UNREAL_KNIFE_GRAVITY_DELAY = 0.4;

new KNIFE_TAILS_COLOR_RGB[3] = {50,50,50};
new KNIFE_TAIL_LEN = 7;
new KNIFE_TAIL_WIDTH = 4;

new UNREAL_KNIFE_CLASSNAME[] = "weapon_unrealknife";
new UNREAL_KNIFE_AMMO1_CLASSNAME[] = "unrealknife_bolt1";
new UNREAL_KNIFE_WEAPONNAME[] = "weapon_unrealknife";

new UNREAL_KNIFE_MAGIC_NUMBER = 0xDEAD1111;

new UNREAL_KNIFE_WEAPON[] = "weapon_knife";

new const UNREAL_KNIFE_AMMO_NAME[] = "KnifeAmmo";
new const UNREAL_KNIFE_AMMO_ID = 16;

new const UNREAL_KNIFE_P_MODEL[] = "models/rm_reloaded/p_unreknife.mdl";
new const UNREAL_KNIFE_V_MODEL[] = "models/rm_reloaded/v_unreknife.mdl";
new const UNREAL_KNIFE_W_MODEL[] = "models/rm_reloaded/w_unreknife.mdl";

new const UNREAL_KNIFE_SOUND_TARGET[] = "weapons/knife_deploy1.wav";
new const UNREAL_KNIFE_SOUND_SHOOT[] = "weapons/knife_slash1.wav";

new UNREAL_KNIFE_SPRITE_AMMO[] = "sprites/laserbeam.spr"
new UNREAL_KNIFE_SPRITE_AMMO_ID = 0;

new UNREAL_KNIFE_W_MODEL_ID = 0;

new WeaponIdType: UNREAL_KNIFE_UNUSED_WEAPONID = WEAPON_GLOCK;
new WeaponIdType: UNREAL_KNIFE_FAKE_WEAPONID = WeaponIdType:77;

new MsgIdWeaponList,MsgIdAmmoPickup, FwdRegUserMsg, MsgHookWeaponList;
 
enum _:knife_e
{
	UNREAL_KNIFE_IDLE = 0,
	UNREAL_KNIFE_ATTACK1HIT,
	UNREAL_KNIFE_ATTACK2HIT,
	UNREAL_KNIFE_DRAW,
	UNREAL_KNIFE_STABHIT,
	UNREAL_KNIFE_STABMISS,
	UNREAL_KNIFE_MIDATTACK1HIT,
	UNREAL_KNIFE_MIDATTACK2HIT
}

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	MsgIdAmmoPickup = get_user_msgid("AmmoPickup");
	
	register_clcmd(UNREAL_KNIFE_WEAPONNAME, "CmdSelect")
	
	RegisterHookChain(RG_CBasePlayer_AddPlayerItem, "AddItem", true);
	RegisterHookChain(RG_CBasePlayer_GiveAmmo, "CBasePlayer_GiveAmmo_Pre", false);
	
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "PrimaryAttack");
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_knife", "SecondaryAttack");
	
	RegisterHookChain(RG_CBasePlayerWeapon_CanDeploy, "CBasePlayerWeapon_CanDeploy");
	RegisterHookChain(RG_CBasePlayerWeapon_DefaultDeploy, "CBasePlayerWeapon_DefaultDeploy_Pre");
}


public plugin_precache() {

	precache_generic("sprites/weapon_unrealknife.txt");
	precache_generic("sprites/unreal_knife.spr");
	
	precache_sound(UNREAL_KNIFE_SOUND_TARGET);
	precache_sound(UNREAL_KNIFE_SOUND_SHOOT);

	UNREAL_KNIFE_SPRITE_AMMO_ID = precache_model(UNREAL_KNIFE_SPRITE_AMMO);
	
	precache_model(UNREAL_KNIFE_P_MODEL);
	UNREAL_KNIFE_W_MODEL_ID = precache_model(UNREAL_KNIFE_W_MODEL);
	precache_model(UNREAL_KNIFE_V_MODEL);
	
	MsgIdWeaponList = get_user_msgid("WeaponList");
	if (MsgIdWeaponList) 
	{
		MsgHookWeaponList = register_message(MsgIdWeaponList, "HookWeaponList");
	}
	else 
	{
		FwdRegUserMsg = register_forward(FM_RegUserMsg, "RegUserMsg_Post", true);
	}
}

public CmdSelect(const id)
{
	if(!is_user_alive(id)) return PLUGIN_HANDLED;

	new item = rg_get_player_item(id, UNREAL_KNIFE_CLASSNAME, KNIFE_SLOT);

	if(item != 0 && get_member(id, m_pActiveItem) != item) rg_switch_weapon(id, item);

	return PLUGIN_HANDLED;
}

public PrimaryAttack(pItem)
{
	if (WeaponIdType:rg_get_iteminfo(pItem,ItemInfo_iId) == UNREAL_KNIFE_FAKE_WEAPONID)
	{
		new pAttacker = get_entvar(pItem, var_owner);
		
		if (!is_user_connected(pAttacker))
			return HAM_SUPERCEDE;

			
		new iAmmo = get_member(pItem, m_Weapon_iClip);
		
		if (iAmmo <= 0)
		{
			return HAM_SUPERCEDE;
		}
		
		rh_emit_sound2(pAttacker, 0, CHAN_WEAPON , UNREAL_KNIFE_SOUND_SHOOT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		
		iAmmo--;
		
		set_member(pItem, m_Weapon_iClip, iAmmo);
		
		UTIL_WeaponAnim(pItem, UNREAL_KNIFE_MIDATTACK1HIT, 0.7);
		
		set_member(pItem, m_Weapon_flNextPrimaryAttack, 0.7);
		set_member(pItem, m_Weapon_flNextSecondaryAttack, 0.7);
		set_member(pItem, m_Weapon_flTimeWeaponIdle, 0.7);
		
		set_member(pAttacker, m_flTimeWeaponIdle, 0.7);
		
		set_entvar(pItem, var_nextthink, get_gametime() + (UNREAL_KNIFE_RELOAD_RATE * 2.0));
		SetThink(pItem,"IncreaseAmmo");
		
		new Float:vVelocity[3] = {0.0,0.0,0.0};
		new Float:vAngles[3];
		new Float:vMins[3];
		new Float:vMaxs[3];
		new Float:vOrigin[3];
		
		get_entvar(pAttacker, var_origin, vOrigin);
		get_entvar(pAttacker, var_maxs, vMins);
		get_entvar(pAttacker, var_mins, vMaxs);
		
		for (new i = 0; i < 3; ++i)
			vOrigin[i] = (vMaxs[i] + vMins[i]) * 0.5 + vOrigin[i];
		
		get_entvar(pAttacker,var_v_angle,vAngles);
		velocity_by_angle(vAngles, 1000.0, vVelocity);
		
		UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
		
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}


public SecondaryAttack(pItem)
{
	if (WeaponIdType:rg_get_iteminfo(pItem,ItemInfo_iId) == UNREAL_KNIFE_FAKE_WEAPONID)
	{	
		new pAttacker = get_entvar(pItem, var_owner);
		
		if (!is_user_connected(pAttacker))
			return HAM_SUPERCEDE;
			
		new iAmmo = get_member(pItem, m_Weapon_iClip);
		
		if (iAmmo < 2)
		{
			return HAM_SUPERCEDE;
		}
		
		rh_emit_sound2(pAttacker, 0, CHAN_WEAPON , UNREAL_KNIFE_SOUND_SHOOT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
		
		new shotammo = 0;
		
		while(shotammo < 4 && iAmmo > 0)
		{
			iAmmo--;
			shotammo++;
		}	
		
		set_member(pItem, m_Weapon_iClip, iAmmo);
		
		UTIL_WeaponAnim(pItem, UNREAL_KNIFE_STABHIT, 2.0);
		
		set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.5);
		set_member(pItem, m_Weapon_flNextSecondaryAttack, 2.0);
		set_member(pItem, m_Weapon_flTimeWeaponIdle, 2.0);
		
		set_member(pAttacker, m_flTimeWeaponIdle, 2.0);
		
		set_entvar(pItem, var_nextthink, get_gametime() + 2.0);
		SetThink(pItem,"IncreaseAmmo");
		
		new Float:vVelocity[3] = {0.0,0.0,0.0};
		new Float:vAngles[3];
		new Float:vMins[3];
		new Float:vMaxs[3];
		new Float:vOrigin[3];
		
		get_entvar(pAttacker, var_origin, vOrigin);
		get_entvar(pAttacker, var_maxs, vMins);
		get_entvar(pAttacker, var_mins, vMaxs);
		
		for (new i = 0; i < 3; ++i)
			vOrigin[i] = (vMaxs[i] + vMins[i]) * 0.5 + vOrigin[i];
		
		get_entvar(pAttacker,var_v_angle,vAngles);
		
		if (shotammo == 2)
		{
			vAngles[1] -= 2.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
			
			vAngles[1] += 4.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
		}
		else if (shotammo == 3)
		{
			vAngles[1] -= 3.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
			
			vAngles[1] += 3.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
		
			vAngles[1] += 3.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
		}
		else if (shotammo == 4)
		{
			vAngles[1] -= 1.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
			
			vAngles[1] -= 2.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
			
			vAngles[1] += 4.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
			
			vAngles[1] += 2.0;
			velocity_by_angle(vAngles, 1000.0, vVelocity);
			UNREAL_KNIFE_SHOT1(pItem, pAttacker,vOrigin,vVelocity,vAngles);
		}
		
		
		return HAM_SUPERCEDE;
	}
	return HAM_IGNORED;
}

public UNREAL_KNIFE_SHOT1(const item, const id, Float:fvOrigin[3], Float:fvVelocity[3], Float:fvAngles[3])
{
	new iEnt = rg_create_entity("info_target");
	if (!iEnt || is_nullent(iEnt))
	{
		return;
	}
	
	set_entvar(iEnt, var_classname, UNREAL_KNIFE_AMMO1_CLASSNAME);
	
	set_entvar(iEnt, var_model, UNREAL_KNIFE_W_MODEL);
	set_entvar(iEnt, var_modelindex, UNREAL_KNIFE_W_MODEL_ID);
	
	set_entvar(iEnt, var_solid, SOLID_TRIGGER );

	set_entvar(iEnt, var_movetype, MOVETYPE_FLY);
	
	set_entvar(iEnt, var_sequence, 0);
	set_entvar(iEnt, var_framerate, 1.0);
	
	set_entvar(iEnt, var_iuser1, id);
	set_entvar(iEnt, var_iuser2, UNREAL_KNIFE_MAGIC_NUMBER);
	set_entvar(iEnt, var_iuser3, item);
	
	entity_set_origin(iEnt, fvOrigin);

	set_entvar(iEnt, var_velocity, fvVelocity);
	
	static Float:tmpAngles[3];
	tmpAngles = fvAngles;
	tmpAngles[0] = 360 - fvAngles[0];
	
	// reversed angles
	set_entvar(iEnt, var_angles, tmpAngles);

	te_create_following_beam(iEnt, UNREAL_KNIFE_SPRITE_AMMO_ID, KNIFE_TAIL_LEN, KNIFE_TAIL_WIDTH, 
								KNIFE_TAILS_COLOR_RGB[0], KNIFE_TAILS_COLOR_RGB[1], KNIFE_TAILS_COLOR_RGB[2], 200);
	
	SetThink(iEnt, "MAKEGRAVITY");
	SetTouch(iEnt, "TouchAmmo1");
	
	set_entvar(iEnt, var_nextthink, get_gametime() + UNREAL_KNIFE_GRAVITY_DELAY);
}

public TouchAmmo1(const knife_ent, const other_ent)
{
	if (!is_nullent(knife_ent))
	{
		if ( other_ent == 0 || !is_nullent(other_ent) )
		{
			new pAttacker = get_entvar(knife_ent,var_iuser1);
			new pInflector = get_entvar(knife_ent,var_iuser3);
			if (!is_nullent(pInflector) && is_user_connected(pAttacker))
			{
				new pTarget = get_entvar(other_ent,var_iuser1);
				// Fast check
				new bool:isTouchKnife = get_entvar(other_ent,var_iuser2) == UNREAL_KNIFE_MAGIC_NUMBER;
				if (pAttacker != other_ent && !isTouchKnife)
				{
					SetTouch(knife_ent, "");
					set_entvar(knife_ent, var_velocity, Float:{0.0,0.0,0.0});
					set_entvar(knife_ent, var_nextthink, get_gametime() + UNREAL_KNIFE_REMOVE_DELAY);
					SetThink(knife_ent, "KILLME");
					new Float:fHealth = get_entvar(other_ent,var_health);
					if (fHealth > 0.0)
					{
						rg_multidmg_clear();
						rg_multidmg_add(pInflector, other_ent, UNREAL_KNIFE_MAX_DMG, DMG_NEVERGIB | DMG_BULLET);
						rg_multidmg_apply(pAttacker, pAttacker);
						if (fHealth == get_entvar(other_ent,var_health))
						{
							rh_emit_sound2(knife_ent, 0, CHAN_BODY , UNREAL_KNIFE_SOUND_TARGET, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
						}
					}
					else 
					{
						rh_emit_sound2(knife_ent, 0, CHAN_BODY , UNREAL_KNIFE_SOUND_TARGET, VOL_NORM, ATTN_NORM, 0, PITCH_NORM );
					}
				}
				else if (isTouchKnife && pTarget != pAttacker)
				{
					if (FClassnameIs(other_ent, UNREAL_KNIFE_AMMO1_CLASSNAME))
					{
						KILLME(knife_ent);
						KILLME(other_ent);
					}
				}
			}
			else 
			{
				KILLME(knife_ent);
			}
		}
		else 
		{
			KILLME(knife_ent);
		}
	}
}

public KILLME(const knife_ent)
{
	if (!is_nullent(knife_ent))
	{
		set_entvar(knife_ent, var_nextthink, get_gametime());
		set_entvar(knife_ent, var_flags, FL_KILLME);
	}
}

public MAKEGRAVITY(const knife_ent)
{
	if (!is_nullent(knife_ent))
	{
		new Float:vAngles[3];
		new Float:vVelocity[3];
		get_entvar(knife_ent, var_angles, vAngles);
		get_entvar(knife_ent, var_velocity, vVelocity);
		vAngles[0]-=1.0;
		vVelocity[2]-=15.0;
		set_entvar(knife_ent, var_angles, vAngles);
		set_entvar(knife_ent, var_velocity, vVelocity);
		set_entvar(knife_ent, var_nextthink, get_gametime() + 0.1);
	}
}

public IncreaseAmmo(pItem)
{
	if (!is_nullent(pItem))
	{
		new iAmmo = get_member(pItem, m_Weapon_iClip);
		
		if (iAmmo >= UNREAL_KNIFE_MAX_AMMO)
		{
			return;
		}
		
		iAmmo++;
		set_member(pItem, m_Weapon_iClip, iAmmo);
		set_entvar(pItem, var_nextthink, get_gametime() + UNREAL_KNIFE_RELOAD_RATE);
	}
}


public CBasePlayerWeapon_CanDeploy(const pItem) {

	if(is_nullent(pItem))
		return HC_CONTINUE;

	if (WeaponIdType:rg_get_iteminfo(pItem,ItemInfo_iId) == UNREAL_KNIFE_FAKE_WEAPONID)
	{
		SetHookChainReturn(ATYPE_INTEGER, true);
	}
	return HC_CONTINUE;
}

public CBasePlayerWeapon_DefaultDeploy_Pre(const pItem, szViewModel[], szWeaponModel[], iAnim, szAnimExt[], skiplocal)
{
	if (is_nullent(pItem)) return HC_CONTINUE;

	if (WeaponIdType:rg_get_iteminfo(pItem,ItemInfo_iId) == UNREAL_KNIFE_FAKE_WEAPONID)
	{
		SetHookChainArg(2, ATYPE_STRING, UNREAL_KNIFE_V_MODEL);
		SetHookChainArg(3, ATYPE_STRING, UNREAL_KNIFE_P_MODEL);
		
		UTIL_WeaponAnim(pItem, UNREAL_KNIFE_DRAW, 2.0);
		set_member(pItem, m_Weapon_flNextPrimaryAttack, 1.0);
		set_member(pItem, m_Weapon_flNextSecondaryAttack, 1.0);
		set_member(pItem, m_Weapon_flTimeWeaponIdle, 1.0);
		
		
		new pAttacker = get_entvar(pItem, var_owner);
		
		if (!is_user_connected(pAttacker))
			return HC_CONTINUE;
			
		
		set_member(pAttacker, m_flTimeWeaponIdle, 1.0);
	}
	return HC_CONTINUE;
}

public RegUserMsg_Post(const name[]) 
{
	if (strcmp(name, "WeaponList") == 0) 
	{
		MsgIdWeaponList = get_orig_retval();
		MsgHookWeaponList = register_message(MsgIdWeaponList, "HookWeaponList");
	}
}

public HookWeaponList(const msg_id, const msg_dst, const msg_entity) 
{
	enum 
	{
		arg_ammo2 = 4,
		arg_ammo2_max = 5,
		arg_slot = 6,
		arg_position = 7,
		arg_id = 8,
		arg_flags = 9,
	};

	if (msg_dst != MSG_INIT || WeaponIdType:get_msg_arg_int(arg_id) != WEAPON_KNIFE) 
	{
		return PLUGIN_CONTINUE;
	}
	
	if (FwdRegUserMsg) 
	{
		unregister_forward(FM_RegUserMsg, FwdRegUserMsg, true);
	}
	
	unregister_message(MsgIdWeaponList, MsgHookWeaponList);
	
	UTIL_WeaponList(MSG_INIT,0,_, UNREAL_KNIFE_WEAPONNAME,UNREAL_KNIFE_AMMO_ID,
					1,get_msg_arg_int(arg_ammo2),get_msg_arg_int(arg_ammo2_max),
					get_msg_arg_int(arg_slot),get_msg_arg_int(arg_position) + 1,cell:UNREAL_KNIFE_UNUSED_WEAPONID,get_msg_arg_int(arg_flags));
	
	return PLUGIN_CONTINUE;
}

public CBasePlayer_GiveAmmo_Pre(const id, const amount, const name[]) {
	if (strcmp(name, UNREAL_KNIFE_AMMO_NAME) != 0) {
		return HC_CONTINUE;
	}

	giveAmmo(id, amount, UNREAL_KNIFE_AMMO_ID, 1);
	SetHookChainReturn(ATYPE_INTEGER, UNREAL_KNIFE_AMMO_ID);
	return HC_SUPERCEDE;
}

stock rg_get_player_item(const id, const classname[], const InventorySlotType:slot = NONE_SLOT) {
	new item = get_member(id, m_rgpPlayerItems, slot);
	
	while (!is_nullent(item)) {
		if (FClassnameIs(item, classname)) {
			return item;
		}
		item = get_member(item, m_pNext);
	}

	return 0;
}

giveKnife(const id) 
{
	new item = rg_get_player_item(id, UNREAL_KNIFE_CLASSNAME, KNIFE_SLOT);
	if (item != 0) {
		set_member(item, m_Weapon_iClip, UNREAL_KNIFE_MAX_AMMO);
		return item;
	}

	item = rg_create_entity(UNREAL_KNIFE_WEAPON, false);
	if (is_nullent(item)) {
		return NULLENT;
	}

	new Float:origin[3];
	get_entvar(id, var_origin, origin);
	set_entvar(item, var_origin, origin);
	set_entvar(item, var_spawnflags, get_entvar(item, var_spawnflags) | SF_NORESPAWN);

	set_member(item, m_Weapon_iPrimaryAmmoType, UNREAL_KNIFE_AMMO_ID);
	set_member(item, m_Weapon_iSecondaryAmmoType, -1);

	set_entvar(item, var_classname, UNREAL_KNIFE_CLASSNAME);

	dllfunc(DLLFunc_Spawn, item);

	set_member(item, m_iId, UNREAL_KNIFE_UNUSED_WEAPONID);


	rg_set_iteminfo(item, ItemInfo_pszName, UNREAL_KNIFE_WEAPONNAME);
	rg_set_iteminfo(item, ItemInfo_pszAmmo1, UNREAL_KNIFE_AMMO_NAME);
	rg_set_iteminfo(item, ItemInfo_iMaxAmmo1, 10);
	rg_set_iteminfo(item, ItemInfo_iMaxAmmo1, -1);
	rg_set_iteminfo(item, ItemInfo_iId, UNREAL_KNIFE_FAKE_WEAPONID);
	rg_set_iteminfo(item, ItemInfo_iPosition, 10);
	rg_set_iteminfo(item, ItemInfo_iWeight, 1);
	rg_set_iteminfo(item, ItemInfo_iSlot, KNIFE_SLOT);

	dllfunc(DLLFunc_Touch, item, id);

	if (get_entvar(item, var_owner) != id) {
		set_entvar(item, var_flags, FL_KILLME);
		return NULLENT;
	}
	
	set_member(item, m_Weapon_iClip, UNREAL_KNIFE_MAX_AMMO);
	return item;
}

giveAmmo(const id, const amount, const ammo, const maxammo) {
	if (!is_user_connected(id) || get_entvar(id, var_flags) & FL_SPECTATOR) {
		return;
	}

	new count = get_member(id, m_rgAmmo, ammo);
	new addammo = min(amount, maxammo - count);
	if (addammo < 1) {
		return;
	}

	set_member(id, m_rgAmmo, count + addammo, ammo);

	message_begin(MSG_ONE, MsgIdAmmoPickup, .player = id);
	write_byte(ammo);
	write_byte(addammo);
	message_end();
}
 
public AddItem(id, pItem)
{
	if (is_nullent(pItem))
		return HC_CONTINUE;
	
	if (get_member(pItem, m_iId) == WEAPON_KNIFE)
		giveKnife(id);
	
	return HC_CONTINUE;
}


stock UTIL_WeaponAnim(pItem, iSequence, Float:flDuration) {
	PlayWeaponAnim(pItem, iSequence);
	set_member(pItem, m_Weapon_flTimeWeaponIdle, flDuration);
}

stock SendPlayerWeaponAnim(pPlayer, pWeapon, iAnim)
{
	if (!is_user_connected(pPlayer))
		return;
	set_entvar(pPlayer, var_weaponanim, iAnim);
	message_begin(MSG_ONE, SVC_WEAPONANIM, _, pPlayer);
	write_byte(iAnim);
	write_byte(get_entvar(pWeapon, var_body));
	message_end();

}

stock PlayWeaponAnim(pItem, iAnim) {
	new pPlayer = get_entvar(pItem,var_owner);
	
	SendPlayerWeaponAnim(pPlayer, pItem, iAnim);

	for (new pSpectator = 1; pSpectator <= MaxClients; pSpectator++) {
		if (!is_user_connected(pSpectator)) {
			continue;
		}

		if (get_entvar(pSpectator, var_iuser1) != OBS_IN_EYE) {
			continue;
		}

		if (get_entvar(pSpectator, var_iuser2) != pPlayer) {
			continue;
		}

		SendPlayerWeaponAnim(pSpectator, pItem, iAnim);
	}
}

 
// from https://github.com/YoshiokaHaruki/AMXX-Dynamic-Crosshair
stock UTIL_WeaponList( const iDest, const pReceiver, const pItem = -1, szWeaponName[ ] = "", const iPrimaryAmmoType = -2, iMaxPrimaryAmmo = -2, iSecondaryAmmoType = -2, iMaxSecondaryAmmo = -2, iSlot = -2, iPosition = -2, iWeaponId = -2, iFlags = -2 ) 
{
	if (pReceiver != 0 && !is_user_connected(pReceiver))
		return;
	static iMsgId_Weaponlist; if ( !iMsgId_Weaponlist ) iMsgId_Weaponlist = get_user_msgid( "WeaponList" );
 
	message_begin( iDest, iMsgId_Weaponlist, .player = pReceiver );
	if ( szWeaponName[ 0 ] == EOS && pItem > 0)
	{	
		new szWeaponName2[128];
		rg_get_iteminfo( pItem, ItemInfo_pszName, szWeaponName2, charsmax( szWeaponName2 ) )
		write_string( szWeaponName2 );
	}
	else 
		write_string( szWeaponName );
		
	write_byte( ( iPrimaryAmmoType <= -2 && pItem > 0 ) ? get_member( pItem, m_Weapon_iPrimaryAmmoType ) : iPrimaryAmmoType );
	write_byte( ( iMaxPrimaryAmmo <= -2 && pItem > 0 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo1 ) : iMaxPrimaryAmmo );
	write_byte( ( iSecondaryAmmoType <= -2 && pItem > 0 ) ? get_member( pItem, m_Weapon_iSecondaryAmmoType ) : iSecondaryAmmoType );
	write_byte( ( iMaxSecondaryAmmo <= -2 && pItem > 0 ) ? rg_get_iteminfo( pItem, ItemInfo_iMaxAmmo2 ) : iMaxSecondaryAmmo );
	write_byte( ( iSlot <= -2 && pItem > 0 ) ? rg_get_iteminfo( pItem, ItemInfo_iSlot ) : iSlot );
	write_byte( ( iPosition <= -2 && pItem > 0 ) ? rg_get_iteminfo( pItem, ItemInfo_iPosition ) : iPosition );
	write_byte( ( iWeaponId <= -2 && pItem > 0 ) ? rg_get_iteminfo( pItem, ItemInfo_iId ) : iWeaponId );
	write_byte( ( iFlags <= -2 && pItem > 0 ) ? rg_get_iteminfo( pItem, ItemInfo_iFlags ) : iFlags );
	
	message_end( );
}

stock velocity_by_angle(Float:fvAngles[3],Float:fVelocity, Float:fvAnglesOut[3])
{
	static Float:tmpVector[3];
	tmpVector = fvAngles; 
	engfunc(EngFunc_MakeVectors, tmpVector);
	global_get(glb_v_forward, tmpVector);
	xs_vec_mul_scalar(tmpVector, fVelocity, fvAnglesOut)
}