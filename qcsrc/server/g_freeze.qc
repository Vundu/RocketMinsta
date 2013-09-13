
void Freeze_Init(void) {
    if(!teams_matter || g_jailbreak || (!cvar("g_freeze") && !g_freezetag))
        return;
    
    g_freeze = TRUE;
    Freeze_Precache();
    
    addstat(STAT_REDALIVE, AS_INT, redalive_stat);
    addstat(STAT_BLUEALIVE, AS_INT, bluealive_stat);
    addstat(STAT_YELLOWALIVE, AS_INT, yellowalive_stat);
    addstat(STAT_PINKALIVE, AS_INT, pinkalive_stat);
    addstat(STAT_FROZEN, AS_INT, frozen);
    addstat(STAT_REVIVE_PROGRESS, AS_FLOAT, revprogress);
    
    if(g_soulmates)
        addstat(STAT_SM_HASGEM, AS_INT, sm_canattach);
    
    g_freeze_globalwarming_reset = TRUE;
    
    entity e = spawn();
    e.think = Freeze_Frame;
    e.nextthink = time;
}

void Freeze_Precache(void) {
    precache_sound("kh/alarm.wav");
    precache_sound("freezetag/freezing.wav");
    precache_model("models/ice/ice.md3");
}

string Freeze_CVarName(string s) {
    if(g_freezetag)
        return strcat("g_freezetag_", s);
    return strcat("g_freeze_", s);
}

void Freeze_GlobalWarming_Warn(float s) {
    entity e; FOR_EACH_PLAYER(e)
        bigprint_spec(e, strcat(ftos(floor(s)), " seconds until ^xFB0Global Warming"), "", 2);
}

void Freeze_Frame(void) {
    float gw, r, wr;
    self.nextthink = time;
    
    if(!Freeze_GameInProgress()) {
        g_freeze_globalwarming_reset = TRUE;
        g_freeze_globalwarming_warned = 0;
        return;
    }
    
    gw = Freeze_CVar("global_warming");
    
    if(gw) {
        if(g_freeze_globalwarming_reset && !g_freeze_globalwarming_warned) {
            Freeze_SetGlobalWarming(gw);
            g_freeze_globalwarming_reset = FALSE;
        }
        
        r = 1;
        wr = Freeze_CVar("global_warming_minratio");
        
        if(!g_freeze_globalwarming_warned && wr < 1) {
            r = min(r, (g_freeze_playerstotal[0]? g_freeze_playersalive[0]/g_freeze_playerstotal[0] : 1));
            r = min(r, (g_freeze_playerstotal[1]? g_freeze_playersalive[1]/g_freeze_playerstotal[1] : 1));
            r = min(r, (g_freeze_playerstotal[2]? g_freeze_playersalive[2]/g_freeze_playerstotal[2] : 1));
            r = min(r, (g_freeze_playerstotal[3]? g_freeze_playersalive[3]/g_freeze_playerstotal[3] : 1));
        } else r = 0;
        
        if(r <= wr) {
            g_freeze_globalwarming -= frametime;
            
            if(g_freeze_globalwarming < 5 && g_freeze_globalwarming_warned < 2) {
                Freeze_GlobalWarming_Warn(5);
                g_freeze_globalwarming_warned = 2;
            } else if(g_freeze_globalwarming < 10 && g_freeze_globalwarming_warned < 1) {
                Freeze_GlobalWarming_Warn(10);
                g_freeze_globalwarming_warned = 1;
            } else if(g_freeze_globalwarming <= 0) {
                play2all("kh/alarm.wav");
                entity e; FOR_EACH_PLAYER(e)
                    bigprint_spec(e, "^xFB0Global Warming!", "Everyone has been unfrozen!", 3);
                Freeze_UnfreezeAll();
                g_freeze_globalwarming_warned = 0;
            }
        }
    }
}

float Freeze_GameInProgress(void) {
    return !(!g_freeze || time < game_starttime || time < warmup || (g_vip && (!vip_started || vip_ended)) || (g_total_domination && !tdom_maycap));
}

void Freeze_Ice_Think() {
    setorigin(self, self.owner.origin - '0 0 16');
    self.nextthink = time;
    self.alpha = 1 - self.owner.revprogress;
}

float Freeze_GetPlayersAlive(float t) {
    return g_freeze_playersalive[Team_Index(t)];
}

float Freeze_GetPlayersTotal(float t) {
    return g_freeze_playerstotal[Team_Index(t)];
}

void Freeze_RecountPlayers(void) {
    float i;
    entity e;
    
    if(!g_freeze)
        return;
        
    for(i = 0; i < 4; ++i) {
        g_freeze_playersalive[i] = 0;
        g_freeze_playerstotal[i] = 0;
    }
    
    FOR_EACH_PLAYER(e) {
        float idx = Team_Index(e.team);
        float fteqcc_sucks;
        
        fteqcc_sucks = g_freeze_playerstotal[idx];
        g_freeze_playerstotal[idx] = fteqcc_sucks + 1;
        if(!e.frozen) {
            fteqcc_sucks = g_freeze_playersalive[idx];
            g_freeze_playersalive[idx] = fteqcc_sucks + 1;
        }
    }
    
    if(g_freezetag) FOR_EACH_REALCLIENT(e) {
        e.redalive_stat     = g_freeze_playersalive[0];
        e.bluealive_stat    = g_freeze_playersalive[1];
        e.yellowalive_stat  = ((ft_teams > 2)? g_freeze_playersalive[2] : -1);
        e.pinkalive_stat    = ((ft_teams > 3)? g_freeze_playersalive[3] : -1);
    }
}

void Freeze_FreezePlayer(entity plr, entity attacker) {
    entity ice;
    
    if(plr.frozen)
        return;
    
    PlayerScore_Set(plr, SP_FROZENSTATUS, 1);
    
    plr.revrow = 0;
    plr.frozen = 1;
    plr.revprogress = 0;
    plr.freezetime = time;
    plr.meltprogress = 0;
    RemoveGrapplingHook(plr);

    if(!plr.iceblock) {
        ice = spawn();
        ice.owner = plr;
        ice.classname = "freeze_ice";
        ice.think = Freeze_Ice_Think;
        ice.nextthink = time;
        ice.frame = floor(random() * 21); // ice model has 20 different looking frames
        ice.effects |= EF_ADDITIVE;
        setmodel(ice, "models/ice/ice.md3");
        setorigin(ice, plr.origin - '0 0 16');
        plr.iceblock = ice;
    }
    
    if(Freeze_CVar("iceblocks_teamcolored"))
        ice.skin = TeamColorSkin(plr.team);
        
    if(Freeze_CVar("freezesound"))
        sound(plr, CHAN_TRIGGER, "freezetag/freezing.wav", VOL_BASE, ATTN_NORM);
    
    WaypointSprite_Spawn("freezetag_frozen", 0, 0, plr, '0 0 64', world, plr.team, plr, freeze_waypoint, TRUE);
    if(plr.freeze_waypoint)
        WaypointSprite_UpdateTeamRadar(plr.freeze_waypoint, RADARICON_WAYPOINT, '0.25 0.90 1');

    if(attacker == plr) {
        PlayerScore_Add(plr, SP_SCORE, -Freeze_CVar("penalty_death"));
    } else if(attacker.classname == "player") {
        if(attacker.team != plr.team) {
            PlayerScore_Add(plr, SP_SCORE, -Freeze_CVar("penalty_death"));
            PlayerScore_Add(attacker, SP_SCORE, Freeze_CVar("score_freeze"));
        } else // teamkill
            PlayerScore_Add(attacker, SP_SCORE, -Freeze_CVar("penalty_teamkill"));
    }
    
    Freeze_RecountPlayers();
}

void Freeze_UnfreezePlayer(entity plr)
{
    if(!plr)
        return;
    
    PlayerScore_Set(plr, SP_FROZENSTATUS, 0);
    
    plr.frozen = 0;
    plr.revprogress = 0;
    
    if(plr.iceblock) {
        remove(plr.iceblock);
        plr.iceblock = world;
    }
    
    // remove waypoint
    if(plr.freeze_waypoint)
        WaypointSprite_Disown(plr.freeze_waypoint, 0.5);
    
    plr.disableclientprediction = 0;
    
    if(g_handgrenades) {
        if(cvar("g_handgrenades_regen_time")) {
            plr.hg_bonus = 0;
            plr.hg_bonustype = HG_NORMAL;
            plr.hg_power = 0;
        } else HG_PlayerSpawnEx(plr);
    }
    
    Freeze_RecountPlayers();
}

void Freeze_SetGlobalWarming(float d) {
    if(d < 10) {
        if(d < 5)
            g_freeze_globalwarming_warned = 2;
        else 
            g_freeze_globalwarming_warned = 1;
    } else
        g_freeze_globalwarming_warned = 0;
    
    g_freeze_globalwarming = d;
}

void Freeze_UnfreezeAll(void) {
    entity e; FOR_EACH_PLAYER(e) if(e.frozen)
        Freeze_UnfreezePlayer(e);
    g_freeze_globalwarming_reset = TRUE;
}

float Freeze_AliveCheck(entity plr) {
    return !plr.frozen;
}

void Freeze_SaveSpawnState(entity plr) {
    plr.spawnstate_saved = TRUE;
    plr.spawnstate_team = plr.team;
    plr.spawnstate_origin = plr.origin;
    plr.spawnstate_angles = plr.angles;
}

void Freeze_RestoreSpawnState(entity plr) {
    if(plr.spawnstate_saved && plr.team == plr.spawnstate_team) {
        plr.angles = plr.spawnstate_angles;
        plr.angles_z = 0;
        plr.fixangle = 1;
        setorigin(plr, plr.spawnstate_origin + '0 0 1' * (1 - plr.mins_z - 24));
    }
    
    plr.spawnstate_saved = FALSE;
}

void Freeze_DangerShortcut(void) {
    if(self.BUTTON_ATCK) {
        if(!self.danger_used) {
            stuffcmd(self, "cl_cmd danger\n");
            self.danger_used = 1;
        }
    } else self.danger_used = 0;
}

string W_ThrowNewWeapon(entity, float, float, vector, vector);
float Freeze_Hook_PlayerDies(entity attacker, vector frce) {
    if(!g_freeze)
        return 0;
    
    if(warmup >= time)
        return 0;
    
    if(g_vip && ISVIP(self))
        return 0;
    
    if(!self.frozen) {
        Boobs_DropAllAndRespawn(frce);
        Freeze_FreezePlayer(self, attacker);
    }
    
    self.health = Freeze_CVar("frozen_health");
    self.armorvalue = Freeze_CVar("frozen_armor");
    
    if(g_minstagib)
        W_ThrowNewWeapon(self, WEP_MINSTANEX, 0, self.origin, self.velocity);
        
    AloneWarning(self.team, Freeze_AliveCheck);

    return 1;
}

void Freeze_Hook_PlayerQuits(void) {
    if(!g_freeze)
        return;
    
    sm_RemovePlayer();
    Freeze_UnfreezePlayer(self);
    Freeze_SaveSpawnState(self);
    // Do it in the next frame
    defer(0, Freeze_RecountPlayers);
}

void Freeze_Hook_PlayerSpawns(void) {
    Freeze_UnfreezePlayer(self);
    
    if(!Freeze_GameInProgress())
        return;
    
    self.revprogress = 0;
    self.meltprogress = 0;
    
    centerprint_spec(self, "^5You spawned after the game started, you'll spawn frozen\n");
    Freeze_FreezePlayer(self, world);
    Freeze_RestoreSpawnState(self);
}

void Freeze_Hook_PlayerPreThink(void) {
    vector revive_extra_size;
    entity o, oPrev, h;
    string names;
    float first;
    
    if(!g_freeze)
        return;
    
    revive_extra_size = '1 1 1' * Freeze_CVar("revive_extra_size");

    o = world;
    
    if(time < warmup || time < next_round) {
        self.revprogress = 0;
        return;
    }
    
    if(!self.frozen) {
        if(time - self.revupdatetime >= 0.01)
            self.revprogress = 0;
        
        sm_Frame();
        return;
    }
    
    // frozen
    
    Freeze_DangerShortcut();
    
    if(self.freezetime + Freeze_CVar("revive_delay") < time)
        FOR_EACH_PLAYER(other) if(self != other && !other.frozen && other.team == self.team) {
            if(boxesoverlap(self.absmin - revive_extra_size, self.absmax + revive_extra_size, other.absmin, other.absmax)) {
                o = other;
                break;
            } else oPrev = other;
        } else oPrev = other;
    
    if(o) // OK, there is at least one teammate reviving us
    {
        self.revfinished = 0;
        self.revprogress = bound(0, self.revprogress + frametime * Freeze_CVar("revive_speed"), 1);

        if(self.revprogress >= 1) {
            Freeze_UnfreezePlayer(self);

            // EVERY team mate nearby gets a point (even if multiple!)
            
            first = TRUE;
            
            for(other = oPrev; (other = find(other, classname, STR_PLAYER));)
            if(self != other && !other.frozen && other.team == self.team)
            if(boxesoverlap(self.absmin - revive_extra_size, self.absmax + revive_extra_size, other.absmin, other.absmax)) {
                PlayerScore_Add(other, SP_REVIVALS, +1);
                PlayerScore_Add(other, SP_SCORE, Freeze_CVar("score_revival"));
                
                other.health = max(other.health, Freeze_CVar("revive_heal"));
                centerprint_spec(other, strcat("^5You revived ^7", self.netname, "\n"));
                
                other.revrow++;
                if(Freeze_CVar("revive_bonusgrenade"))
                if(other.revrow >= Freeze_CVar("revive_bonusgrenade_requirement")) {
                    HG_GiveBonus(other, HG_NameToType(Freeze_CVarString("revive_bonusgrenade_type")), 1,
                                strcat(ftos(other.revrow), " revivals in a row")
                    );
                    other.revrow = 0;
                }
                
                if(first) {
                    names = other.netname;
                    first = FALSE;
                } else
                    names = strcat(names, "^7, ", other.netname);
            }

            centerprint_spec(self, strcat("^5You were revived by ^7", names, "\n"));
            bprint("^7", names, "^5 revived ^7", self.netname, "\n");
            
            return;
        }

        // now find EVERY teammate within reviving radius, set their revive_progress values correct
        for(other = oPrev; (other = find(other, classname, STR_PLAYER)) != world; )
        if(self != other && !other.frozen && other.team == self.team)
        if(boxesoverlap(self.absmin - revive_extra_size, self.absmax + revive_extra_size, other.absmin, other.absmax)) {
            other.revprogress = self.revprogress;
            other.revupdatetime = time;
        }
    } else if(self.revfinished) {
        if(Freeze_CVar("melt"))
        {
            for(h = world; (h = find(h, classname, "grapplinghook")); )
                if(h.aiment == self)
                    return;
            
            if(self.freezetime + Freeze_CVar("melt_delay") <= time) {
                self.meltprogress = bound(0, self.meltprogress + frametime * Freeze_CVar("melt_speed"), 1);
                
                if(self.meltprogress >= 1) {
                    self.meltprogress = 0;
                    Freeze_UnfreezePlayer(self);
                    bprint(self.netname, "^5's iceblock has melted\n");
                    centerprint_spec(self, "^5Your iceblock has melted");
                    return;
                }
            }
            
            self.revprogress = self.meltprogress;
            self.revupdatetime = time;
        }
        else
            self.meltprogress = 0;
    } else { // only if no teammate is nearby will we reset
        self.revprogress = bound(0, self.revprogress - frametime * Freeze_CVar("revive_clearspeed"), 1);
        self.meltprogress = self.revprogress;
        
        if(!self.revprogress)
            self.revfinished = 1;
    }
}

void Freeze_Hook_PlayerPhysics(void) {
    if(!g_freeze)
        return;
    
    if(self.frozen) {
        float s = Freeze_CVar("frozen_movespeed");
        
        if(s > 0) {
            if(Freeze_CVar("movespeed_dependonmelt"))
                s *= self.revprogress;
            
            self.movement_x = (
                (self.movement_x > 0)?
                    bound( 0, self.movement_x, s)
                :	bound(-s, self.movement_x, 0)
            );
            
            self.movement_y = (
                (self.movement_y > 0)?
                    bound( 0, self.movement_y, s)
                :	bound(-s, self.movement_y, 0)
            );
            
            self.movement_z = (
                (self.movement_z > 0)?
                    bound( 0, self.movement_z, s)
                :	bound(-s, self.movement_z, 0)
            );
        } else
            self.movement = '0 0 0';
        
        self.disableclientprediction = 1;
    }
}