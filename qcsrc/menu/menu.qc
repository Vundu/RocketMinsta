///////////////////////////////////////////////
// Menu Source File
///////////////////////
// This file belongs to dpmod/darkplaces
// AK contains all menu functions (especially the required ones)
///////////////////////////////////////////////

float mouseButtonsPressed;
vector menuMousePos;
float menuShiftState;
float menuPrevTime;
float menuAlpha;
float menuLogoAlpha;
float prevMenuAlpha;
float menuInitialized;
float menuNotTheFirstFrame;
float menuMouseMode;

void SUB_Null() { };

void() m_init =
{
	registercvar("_menu_alpha", "0", 0);
	cvar_set("_menu_alpha", "0");
	registercvar("menu_slist_showonlyrm", "0", 0);
	registercvar("_menu_vote_string", "", 0);
    
    localcmd("alias menu_shownadeselect \"menu_cmd directmenu NadeMenu\"\n");

	dprint_load();
	check_unacceptable_compiler_bugs();

	// list all game dirs (TEST)
	if(cvar("developer"))
	{
		float i;
		string s;
		for(i = 0; ; ++i)
		{
			s = getgamedirinfo(i, GETGAMEDIRINFO_NAME);
			if not(s)
				break;
			print(s, ": ", getgamedirinfo(i, GETGAMEDIRINFO_DESCRIPTION));
		}
	}
	
	IP2C_Init();
	DPRM_Start();
}

void UpdateConWidthHeight()
{
    conwidth_s = conwidth;
    conheight_s = conheight;
    realconwidth = cvar("vid_conwidth");
    realconheight = cvar("vid_conheight");
    if(realconwidth / realconheight > MENU_ASPECT)
    {
        // widescreen
        conwidth = realconheight * MENU_ASPECT;
        conheight = realconheight;
    }
    else
    {
        // squarescreen
        conwidth = realconwidth;
        conheight = realconwidth / MENU_ASPECT;
    }
    screenconwidth = conwidth;
    screenconheight = conheight;
    if(conwidth < MENU_MINHEIGHT * MENU_ASPECT)
    {
        conheight *= MENU_MINHEIGHT * MENU_ASPECT / conwidth;
        conwidth = MENU_MINHEIGHT * MENU_ASPECT;
    }
    if(conheight < MENU_MINHEIGHT)
    {
        conwidth *= MENU_MINHEIGHT / conheight;
        conheight = MENU_MINHEIGHT;
    }
    if(main)
    {   
        if(conwidth_s != conwidth || conheight_s != conheight)
        {
            draw_reset();
            main.resizeNotify(main, '0 0 0', eX * conwidth + eY * conheight, '0 0 0', eX * conwidth + eY * conheight);
        }
    }
}

void() m_init_delayed =
{
	float fh, glob, n, i;
	string s;

	dprint_load();

	menuInitialized = 0;
	if(!preMenuInit())
		return;
	menuInitialized = 1;
	GameCommand_Init();

	RegisterWeapons();

	fh = -1;
	if(cvar_string("menu_rmskin") != "")
	{
		draw_currentSkin = strcat("gfx/menu/", cvar_string("menu_rmskin"));
		fh = fopen(strcat(draw_currentSkin, "/skinvalues.txt"), FILE_READ);
	}
	if(fh < 0)
	{
		draw_currentSkin = "gfx/menu/rmdefault";
		fh = fopen(strcat(draw_currentSkin, "/skinvalues.txt"), FILE_READ);
        registercvar("menu_rmskin", "rmdefault", CVAR_SAVE);
	}
    if(fh < 0)
	{
		draw_currentSkin = "gfx/menu/default";
		fh = fopen(strcat(draw_currentSkin, "/skinvalues.txt"), FILE_READ);
	}
    
    draw_originalSkin = draw_currentSkin;
    draw_overrides = buf_create();
    
	while((s = fgets(fh)))
	{
		// these two are handled by skinlist.qc
		if(substring(s, 0, 6) == "title ")
			continue;
		if(substring(s, 0, 7) == "author ")
			continue;
        
		n = tokenize_console(s);
		if(n >= 2) {
            string comd = argv(0);
            
            switch(comd) {
                case "baseskin":
                    draw_currentSkin = strcat("gfx/menu/", argv(1));
                    break;
                
                case "override":
                    bufstr_set(draw_overrides, draw_overrideCount++, argv(1));
                    break;
                
                default:
                    Skin_ApplySetting(argv(0), substring(s, argv_start_index(1), argv_end_index(-1) - argv_start_index(1)));
                    break;
            }
        }
	}
    
	draw_currentSkin = strzone(draw_currentSkin);
	draw_originalSkin = strzone(draw_originalSkin);
    
	fclose(fh);

	glob = search_begin(strcat(draw_currentSkin, "/*.tga"), TRUE, TRUE);
	if(glob >= 0)
	{
		n = search_getsize(glob);
		for(i = 0; i < n; ++i)
			precache_pic(search_getfilename(glob, i));
		search_end(glob);
	}

	draw_setMousePointer(SKINGFX_CURSOR, SKINSIZE_CURSOR, SKINOFFSET_CURSOR);

	conwidth = conheight = -1;
	draw_reset();
	UpdateConWidthHeight();

	loadTooltips();
	main = spawnMainWindow(); main.configureMainWindow(main);
	unloadTooltips();

	main.resizeNotify(main, '0 0 0', eX * conwidth + eY * conheight, '0 0 0', eX * conwidth + eY * conheight);
	main.focused = 1;
	menuShiftState = 0;
	menuMousePos = '0.5 0.5 0';
    
    rm_watermark = RM_BUILD_NAME " " RM_BUILD_VERSION " " RM_BUILD_COMMIT " " RM_BUILD_DATE;
    
	if(Menu_Active)
		m_display(); // delayed menu display
};

void(float key, float ascii) m_keyup =
{
	if(!menuInitialized)
		return;
	if(!Menu_Active)
		return;
	draw_reset();
	main.keyUp(main, key, ascii, menuShiftState);
	if(key >= K_MOUSE1 && key <= K_MOUSE3)
	{
		--mouseButtonsPressed;
		if(!mouseButtonsPressed)
			main.mouseRelease(main, menuMousePos);
		if(mouseButtonsPressed < 0)
		{
			mouseButtonsPressed = 0;
			print("Warning: released an already released button\n");
		}
	}
	if(key == K_ALT) menuShiftState -= (menuShiftState & S_ALT);
	if(key == K_CTRL) menuShiftState -= (menuShiftState & S_CTRL);
	if(key == K_SHIFT) menuShiftState -= (menuShiftState & S_SHIFT);
};

void(float key, float ascii) m_keydown =
{
	if(!menuInitialized)
		return;
	if(!Menu_Active)
		return;
	if(keyGrabber)
	{
		entity e;
		e = keyGrabber;
		keyGrabber = NULL;
		e.keyGrabbed(e, key, ascii);
	}
	else
	{
		draw_reset();
		if(key >= K_MOUSE1 && key <= K_MOUSE3)
			if(!mouseButtonsPressed)
				main.mousePress(main, menuMousePos);
		if(!main.keyDown(main, key, ascii, menuShiftState))
			if(key == K_ESCAPE)
				if(gamestatus & (GAME_ISSERVER | GAME_CONNECTED)) // don't back out to console only
					m_hide(); // disable menu on unhandled ESC
	}
	if(key >= K_MOUSE1 && key <= K_MOUSE3)
	{
		++mouseButtonsPressed;
		if(mouseButtonsPressed > 10)
		{
			mouseButtonsPressed = 10;
			print("Warning: pressed an already pressed button\n");
		}
	}
	if(key == K_ALT) menuShiftState |= S_ALT;
	if(key == K_CTRL) menuShiftState |= S_CTRL;
	if(key == K_SHIFT) menuShiftState |= S_SHIFT;
};

void(string img, float a, float algn, float force1) drawBackground =
{
	vector sz;
	vector isz;
	vector tl, ce, br;
	vector v;
	string s;
	float i, f;
    
    draw_reset_full();
	sz = draw_PictureSize(img);
	// keep aspect of image
	if(sz_x * draw_scale_y >= sz_y * draw_scale_x)
	{
		// that is, sz_x/sz_y >= draw_scale_x/draw_scale_y
		// match up the height
		isz_y = 1;
		isz_x = isz_y * (sz_x / sz_y) * (draw_scale_y / draw_scale_x);
	}
	else
	{
		// that is, sz_x/sz_y <= draw_scale_x/draw_scale_y
		// match up the width
		isz_x = 1;
		isz_y = isz_x * (sz_y / sz_x) * (draw_scale_x / draw_scale_y);
	}
	tl = '0 0 0';
	ce = '0.5 0.5 0' - 0.5 * isz;
	br = '1 1 0' - isz;

	s = ftos(algn);
	v_z = 0;
	for(i = 0; i < strlen(s); ++i)
	{
		f = stof(substring(s, i, 1));
		switch(f)
		{
			case 1: case 4: case 7: v_x = tl_x; break;
			case 2: case 5: case 8: v_x = ce_x; break;
			case 3: case 6: case 9: v_x = br_x; break;
			default: v_x = tl_x + (br_x - tl_x) * random(); break;
		}
		switch(f)
		{
			case 7: case 8: case 9: v_y = tl_y; break;
			case 4: case 5: case 6: v_y = ce_y; break;
			case 1: case 2: case 3: v_y = br_y; break;
			default: v_y = tl_y + (br_y - tl_y) * random(); break;
		}
		if(i == 0)
			draw_Picture(v, img, isz, '1 1 1', a);
		else if(force1)
			// force all secondary layers to use alpha 1. Prevents ugly issues
			// with overlap. It's a flag because it cannot be used for the
			// ingame background
			draw_Picture(v, strcat(img, "_l", ftos(i+1)), isz, '1 1 1', 1);
		else
			draw_Picture(v, strcat(img, "_l", ftos(i+1)), isz, '1 1 1', a);
	}
    draw_reset();
}

vector menuTooltipAveragedMousePos;
entity menuTooltipItem;
vector menuTooltipOrigin;
vector menuTooltipSize;
float menuTooltipAlpha;
float menuTooltipState; // 0: no tooltip, 1: fading in, 2: displaying, 3: fading out
float m_testmousetooltipbox(vector pos)
{
	if(pos_x >= menuTooltipOrigin_x && pos_x < menuTooltipOrigin_x + menuTooltipSize_x)
	if(pos_y >= menuTooltipOrigin_y && pos_y < menuTooltipOrigin_y + menuTooltipSize_y)
		return FALSE;
	return TRUE;
}
float m_testtooltipbox(vector tooltippos)
{
	if(tooltippos_x < 0)
		return FALSE;
	if(tooltippos_y < 0)
		return FALSE;
	if(tooltippos_x + menuTooltipSize_x > 1)
		return FALSE;
	if(tooltippos_y + menuTooltipSize_y > 1)
		return FALSE;
	/*
	menuTooltipOrigin_x = rint(tooltippos_x * cvar("vid_width")) / cvar("vid_width");
	menuTooltipOrigin_y = rint(tooltippos_y * cvar("vid_height")) / cvar("vid_height");
	menuTooltipOrigin_z = 0;
	*/
	menuTooltipOrigin = tooltippos;
	return TRUE;
}
float m_allocatetooltipbox(vector pos)
{
	vector avoidplus, avoidminus;
	vector v;

	avoidplus_x = (SKINAVOID_TOOLTIP_x + SKINSIZE_CURSOR_x - SKINOFFSET_CURSOR_x) / conwidth;
	avoidplus_y = (SKINAVOID_TOOLTIP_y + SKINSIZE_CURSOR_y - SKINOFFSET_CURSOR_y) / conheight;
	avoidplus_z = 0;

	avoidminus_x = (SKINAVOID_TOOLTIP_x + SKINOFFSET_CURSOR_x) / conwidth + menuTooltipSize_x;
	avoidminus_y = (SKINAVOID_TOOLTIP_y + SKINOFFSET_CURSOR_y) / conheight + menuTooltipSize_y;
	avoidminus_z = 0;

	// bottom right
	v = pos + avoidplus;
	if(m_testtooltipbox(v))
		return TRUE;
	
	// bottom center
	v_x = pos_x - menuTooltipSize_x * 0.5;
	if(m_testtooltipbox(v))
		return TRUE;

	// bottom left
	v_x = pos_x - avoidminus_x;
	if(m_testtooltipbox(v))
		return TRUE;

	// top left
	v_y = pos_y - avoidminus_y;
	if(m_testtooltipbox(v))
		return TRUE;

	// top center
	v_x = pos_x - menuTooltipSize_x * 0.5;
	if(m_testtooltipbox(v))
		return TRUE;
	
	// top right
	v_x = pos_x + avoidplus_x;
	if(m_testtooltipbox(v))
		return TRUE;
	
	return FALSE;
}
entity m_findtooltipitem(entity root, vector pos)
{
	entity it;
	entity best;

	best = world;
	it = root;

	while(it.instanceOfContainer)
	{
		while(it.instanceOfNexposee && it.focusedChild)
		{
			it = it.focusedChild;
			pos = globalToBox(pos, it.Container_origin, it.Container_size);
		}
		if(it.instanceOfNexposee)
		{
			it = it.itemFromPoint(it, pos);
			if(it.tooltip)
				best = it;
			it = world;
		}
		else if(it.instanceOfModalController)
			it = it.focusedChild;
		else
			it = it.itemFromPoint(it, pos);
		if(!it)
			break;
		if(it.tooltip)
			best = it;
		pos = globalToBox(pos, it.Container_origin, it.Container_size);
	}

	return best;
}
void m_tooltip(vector pos)
{
	float f, i, w;
	entity it;
	vector fontsize, p;
	string s;

	fontsize = '1 0 0' * (SKINFONTSIZE_TOOLTIP / conwidth) + '0 1 0' * (SKINFONTSIZE_TOOLTIP / conheight);

	f = bound(0, frametime * 2, 1);
	menuTooltipAveragedMousePos = menuTooltipAveragedMousePos * (1 - f) + pos * f;
	f = vlen(pos - menuTooltipAveragedMousePos);

	if(f < 0.01)
		it = m_findtooltipitem(main, pos);
	else	
		it = world;

	// float menuTooltipState; // 0: static, 1: fading in, 2: fading out
	if(it != menuTooltipItem)
	{
		switch(menuTooltipState)
		{
			case 0:
				if(menuTooltipItem)
				{
					// another item: fade out first
					menuTooltipState = 2;
				}
				else
				{
					// new item: fade in
					menuTooltipState = 1;
					menuTooltipItem = it;

					menuTooltipOrigin_x = -1; // unallocated
					i = 0;
					w =  0;
					getWrappedLine_remaining = it.tooltip;
					while(getWrappedLine_remaining)
					{
						s = getWrappedLine(SKINWIDTH_TOOLTIP / fontsize_x, draw_TextWidth_WithoutColors);
						++i;
						f = draw_TextWidth(s, FALSE);
						if(f > w)
							w = f;
					}
					menuTooltipSize_x = w * fontsize_x + 2 * (SKINMARGIN_TOOLTIP_x / conwidth);
					menuTooltipSize_y = i * fontsize_y + 2 * (SKINMARGIN_TOOLTIP_y / conheight);
					menuTooltipSize_z = 0;
				}
				break;
			case 1:
				// changing item while fading in: fade out first
				menuTooltipState = 2;
				break;
			case 2:
				// changing item while fading out: can't
				break;
		}
	}
	else if(menuTooltipState == 2) // re-fade in?
		menuTooltipState = 1;

	if(menuTooltipItem)
		if(!m_testmousetooltipbox(pos))
			menuTooltipState = 2; // fade out if mouse touches it

	switch(menuTooltipState)
	{
		case 1:
			menuTooltipAlpha = bound(0, menuTooltipAlpha + 5 * frametime, 1);
			if(menuTooltipAlpha == 1)
				menuTooltipState = 0;
			break;
		case 2:
			menuTooltipAlpha = bound(0, menuTooltipAlpha - 2 * frametime, 1);
			if(menuTooltipAlpha == 0)
			{
				menuTooltipState = 0;
				menuTooltipItem = world;
			}
			break;
	}

	if(menuTooltipItem)
	{
		if(menuTooltipOrigin_x < 0) // unallocated?
			m_allocatetooltipbox(pos);

		if(menuTooltipOrigin_x >= 0)
		{
			// draw the tooltip!
			p = SKINBORDER_TOOLTIP;
			p_x *= 1 / conwidth;
			p_y *= 1 / conheight;
			draw_BorderPicture(menuTooltipOrigin, SKINGFX_TOOLTIP, menuTooltipSize, '1 1 1', menuTooltipAlpha, p);
			p = menuTooltipOrigin;
			p_x += SKINMARGIN_TOOLTIP_x / conwidth;
			p_y += SKINMARGIN_TOOLTIP_y / conheight;
			getWrappedLine_remaining = menuTooltipItem.tooltip;
			while(getWrappedLine_remaining)
			{
				s = getWrappedLine(SKINWIDTH_TOOLTIP / fontsize_x, draw_TextWidth_WithoutColors);
				draw_Text(p, s, fontsize, '1 1 1', SKINALPHA_TOOLTIP * menuTooltipAlpha, FALSE);
				p_y += fontsize_y;
			}
		}
	}
}

void() m_draw =
{
	float t;
	float realFrametime;

	menuMouseMode = cvar("menu_mouse_absolute");

	if(main)
		UpdateConWidthHeight();

	if(!menuInitialized)
	{
		// TODO draw an info image about this situation
		m_init_delayed();
		return;
	}
	if(!menuNotTheFirstFrame)
	{
		menuNotTheFirstFrame = 1;
		if(Menu_Active)
		if(!cvar("menu_video_played"))
		{
			localcmd("set menu_video_played 1; cd loop $menu_cdtrack; play sound/announcer/male/welcome.ogg\n");
			menuLogoAlpha = -0.8; // no idea why, but when I start this at zero, it jumps instead of fading
		}
	}

	t = gettime();
	realFrametime = frametime = min(0.2, t - menuPrevTime);
	menuPrevTime = t;
	time += frametime;

	t = cvar("menu_slowmo");
	if(t)
	{
		frametime *= t;
		realFrametime *= t;
	}
	else
		t = 1;

	if(Menu_Active)
	{
		if(getmousetarget() == (menuMouseMode ? MT_CLIENT : MT_MENU) && (getkeydest() == KEY_MENU || getkeydest() == KEY_MENU_GRABBED))
			setkeydest(keyGrabber ? KEY_MENU_GRABBED : KEY_MENU);
		else
			m_hide();
	}

	if(cvar("cl_capturevideo"))
		frametime = t / cvar("cl_capturevideo_fps"); // make capturevideo work smoothly

	dprint_load();
	gamestatus = 0;
	if(isserver())
		gamestatus = gamestatus | GAME_ISSERVER;
	if(clientstate() == CS_CONNECTED)
		gamestatus = gamestatus | GAME_CONNECTED;
	if(cvar("developer"))
		gamestatus = gamestatus | GAME_DEVELOPER;

	prevMenuAlpha = menuAlpha;
	if(Menu_Active)
	{
		if(menuAlpha == 0 && menuLogoAlpha < 2)
		{
			menuLogoAlpha = menuLogoAlpha + frametime * 2;
		}
		else
		{
			menuAlpha = min(1, menuAlpha + frametime * 5);
			menuLogoAlpha = 2;
		}
	}
	else
	{
		menuAlpha = max(0, menuAlpha - frametime * 5);
		menuLogoAlpha = 2;
	}

	draw_reset();

	if(!(gamestatus & (GAME_CONNECTED | GAME_ISSERVER)))
	{
		if(menuLogoAlpha > 0)
		{
			drawBackground(SKINGFX_BACKGROUND, bound(0, menuLogoAlpha, 1), SKINALIGN_BACKGROUND, TRUE);
			if(menuAlpha <= 0 && SKINALPHA_CURSOR_INTRO > 0)
			{
				draw_alpha = SKINALPHA_CURSOR_INTRO * bound(0, menuLogoAlpha, 1);
				draw_drawMousePointer(menuMousePos);
				draw_alpha = 1;
			}
		}
	}
	else if(SKINALPHA_BACKGROUND_INGAME)
	{
		if(menuAlpha > 0)
			drawBackground(SKINGFX_BACKGROUND_INGAME, menuAlpha * SKINALPHA_BACKGROUND_INGAME, SKINALIGN_BACKGROUND_INGAME, FALSE);
	}

	if(menuAlpha != prevMenuAlpha)
		cvar_set("_menu_alpha", ftos(menuAlpha));

	draw_reset();
	preMenuDraw();
	draw_reset();

	if(menuAlpha <= 0)
	{
		if(prevMenuAlpha > 0)
			main.initializeDialog(main, main.firstChild);
		draw_reset();
		postMenuDraw();
		return;
	}

	draw_alpha *= menuAlpha;

	if(menuMouseMode)
	{
		vector newMouse;
		newMouse = globalToBoxSize(getmousepos(), draw_scale);
		if(newMouse != '0 0 0')
			if(newMouse != menuMousePos)
			{
				menuMousePos = newMouse;
				if(mouseButtonsPressed)
					main.mouseDrag(main, menuMousePos);
				else
					main.mouseMove(main, menuMousePos);
			}
	}
	else
	{
		if(frametime > 0)
		{
			vector dMouse;
			dMouse = getmousepos() * (frametime / realFrametime); // for capturevideo
			if(dMouse != '0 0 0')
			{
				dMouse = globalToBoxSize(dMouse, draw_scale);
				menuMousePos += dMouse * cvar("menu_mouse_speed");
				menuMousePos_x = bound(0, menuMousePos_x, 1);
				menuMousePos_y = bound(0, menuMousePos_y, 1);
				if(mouseButtonsPressed)
					main.mouseDrag(main, menuMousePos);
				else
					main.mouseMove(main, menuMousePos);
			}
		}
	}
	main.draw(main);

	m_tooltip(menuMousePos);

	draw_alpha = max(draw_alpha, SKINALPHA_CURSOR_INTRO * bound(0, menuLogoAlpha, 1));

    if(!(gamestatus & (GAME_CONNECTED | GAME_ISSERVER)))
	{
		vector position;
		position = '0 0 0';
		position_y = conheight - 8;
		drawstring(position, rm_watermark, '8 8 0', '1 1 1', 0.2, DRAWFLAG_NORMAL);
	}

	draw_drawMousePointer(menuMousePos);
    
	draw_reset();
	postMenuDraw();

	IP2C_CheckTimedOut();

	frametime = 0;
};

void() m_display =
{
	Menu_Active = true;
	setkeydest(KEY_MENU);
	setmousetarget((menuMouseMode ? MT_CLIENT : MT_MENU));

	if(!menuInitialized)
		return;

	if(mouseButtonsPressed)
		main.mouseRelease(main, menuMousePos);
	mouseButtonsPressed = 0;

	main.focusEnter(main);
	main.showNotify(main);
};

void() m_hide =
{
	Menu_Active = false;
	setkeydest(KEY_GAME);
	setmousetarget(MT_CLIENT);

	if(!menuInitialized)
		return;

	main.focusLeave(main);
	main.hideNotify(main);
};

void() m_toggle =
{
	if(Menu_Active)
		m_hide();
	else
	{
		if(gamestatus & (GAME_ISSERVER | GAME_CONNECTED))
		if(!cvar("rm_nogamemenu") && cvar("_rm_server"))
			m_activate_window(main.gameMenuDialog);
		m_display();
	}
};

void() m_shutdown =
{
	entity e;

	IP2C_Shutdown();


	for(e = world; (e = findfloat(e, instanceOfNexuizServerList, TRUE)); )
		if(e.ip2c_localdb > -1)
			db_close(e.ip2c_localdb);

	m_hide();
	for(e = NULL; (e = nextent(e)) != NULL; )
	{
		if(e.destroy)
			e.destroy(e);
	}
};

void m_focus_item_chain(entity outermost, entity innermost)
{
	if(innermost.parent != outermost)
		m_focus_item_chain(outermost, innermost.parent);
	innermost.parent.setFocus(innermost.parent, innermost);
}

void m_activate_window(entity wnd)
{
	entity par;
	par = wnd.parent;
	if(par)
		m_activate_window(par);

	if(par.instanceOfModalController)
	{
		if(wnd.tabSelectingButton)
			// tabs
			TabButton_Click(wnd.tabSelectingButton, wnd);
		else
			// root
			par.initializeDialog(par, wnd);
	}
	else if(par.instanceOfNexposee)
	{
		// nexposee (sorry for violating abstraction here)
		par.selectedChild = wnd;
		par.animationState = 1;
		setFocusContainer(par, NULL);
	}
	else if(par.instanceOfContainer)
	{
		// other containers
		if(par.focused)
			par.setFocus(par, wnd);
	}
}

void m_setpointerfocus(entity wnd)
{
	if(wnd.instanceOfContainer)
	{
		entity focus = wnd.preferredFocusedGrandChild(wnd);
		if(focus)
		{
			menuMousePos = focus.origin + 0.5 * focus.size;
			menuMousePos_x *= 1 / conwidth;
			menuMousePos_y *= 1 / conheight;
			if(wnd.focused) // why does this never happen?
				m_focus_item_chain(wnd, focus);
		}
	}
}

void(string itemname) m_goto =
{
	entity e;
	if(!menuInitialized)
		return;
	if(itemname == "") // this can be called by GameCommand
	{
		if(gamestatus & (GAME_ISSERVER | GAME_CONNECTED))
			m_hide();
		else
		{
			m_activate_window(main.mainNexposee);
			m_display();
		}
	}
	else
	{
		e = findstring(NULL, name, itemname);
		if(e)
		{
			m_hide();
			m_activate_window(e);
			m_setpointerfocus(e);
			m_display();
		}
	}
}

void() m_goto_skin_selector =
{
	if(!menuInitialized)
		return;
	// TODO add code to switch back to the skin selector (no idea how to do it now)
	m_goto("skinselector");
}

void URI_Get_Callback(float id, float status, string data)
{
	if(id == URI_GET_IP2C)
	{
		IP2C_URI_Get_Callback(id, status, data);
		return;
	}
}
