/* See LICENSE file for copyright and license details. */

#include <X11/XF86keysym.h>

/* appearance */
static const unsigned int borderpx  = 1;        /* border pixel of windows */
static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const char *fonts[]          = { "JetBrainsMono Nerd Font Mono:size=11", "JetBrainsMono Nerd Font Mono:size=14" };
static const char col_gray1[]       = "#0b0b0b";
static const char col_gray2[]       = "#353535";
static const char col_gray3[]       = "#e0e0e0";
static const char col_cyan[]        = "#bdbdbd";
static const char col_selected[]    = "#0b0b0b";
static const char col_bar_dim[]     = "#a6a6a6";
static const char col_tag_active[]  = "#292929";
static int gappx = 10;
static const char *colors[][3]      = {
	/*               fg         bg         border   */
	[SchemeNorm] = { col_gray3, col_gray1, col_gray2 },
	[SchemeSel]  = { col_gray3, col_selected, col_cyan },
	[SchemeBarDim] = { col_bar_dim, col_gray1, col_gray2 },
	[SchemeBarTag] = { col_gray3, col_tag_active, col_gray2 },
};

/* tagging */
static const char *tags[] = { "\uf269", "\uf120", "\uec82", "\uf07b", "\uf013" };

static const Rule rules[] = {
	/* xprop(1):
	 *	WM_CLASS(STRING) = instance, class
	 *	WM_NAME(STRING) = title
	 */
	/* class      instance    title       tags mask     isfloating   monitor */
	/* Neutral defaults; add routing only for confirmed WM_CLASS values. */
	{ NULL, NULL, NULL, 0, 0, -1 },
	{ "T480Popup", NULL, NULL, 0, 1, -1 },
	{ NULL, NULL, "T480 Controls", 0, 1, -1 },
	{ NULL, NULL, "T480 Clipboard", 0, 1, -1 },
	{ NULL, NULL, "T480 Spotlight", 0, 1, -1 },
	{ NULL, NULL, "T480 Shortcuts", 0, 1, -1 },
};

/* layout(s) */
static const float mfact     = 0.50; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
static const int resizehints = 0;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* key definitions */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* commands */
static const char *controlcmd[] = { "t480-controls", NULL };
static const char *filescmd[] = { "pcmanfm", NULL };
static const char *webcmd[] = { "librewolf-bin", NULL };
static const char *codexcmd[] = { "chatgpt", NULL };
static const char *sendcmd[] = { "localsend", NULL };
static const char *wificmd[] = { "t480-tui", "wifi", NULL };
static const char *btcmd[] = { "t480-tui", "bluetooth", NULL };
static const char *monitorcmd[] = { "t480-tui", "monitor", NULL };
static const char *termcmd[]  = { "st", NULL };

static const char *mutecmd[] = { "qs", "ipc", "-c", "t480", "call", "controls", "toggleMute", NULL };
static const char *voldowncmd[] = { "qs", "ipc", "-c", "t480", "call", "controls", "volumeDown", NULL };
static const char *volupcmd[] = { "qs", "ipc", "-c", "t480", "call", "controls", "volumeUp", NULL };
static const char *dimcmd[] = { "t480-brightness", "down", NULL };
static const char *brightcmd[] = { "t480-brightness", "up", NULL };

static const char *shotcmd[] = { "t480-shot", "select", NULL };
static const char *screenshotcmd[] = { "t480-shot", "screen", NULL };
static const char *clipcmd[] = { "qs", "ipc", "-c", "t480", "call", "clipboard", "toggle", NULL };
static const char *spotcmd[] = { "qs", "ipc", "-c", "t480", "call", "spotlight", "toggle", NULL };
static const char *keyguidecmd[] = { "qs", "ipc", "-c", "t480", "call", "keyguide", "toggle", NULL };

static const Key keys[] = {
    { 0, XK_Print, spawn, {.v = shotcmd} },
    { MODKEY, XK_Print, spawn, {.v = screenshotcmd} },
    { MODKEY|ShiftMask, XK_v, spawn, {.v = clipcmd} },
    { MODKEY, XK_a, clipboardkey, {.i = 2} },
    { MODKEY, XK_c, clipboardkey, {.i = 0} },
    { MODKEY, XK_v, clipboardkey, {.i = 1} },

    /* Plain function keys and hardware media signals (both Fn Lock modes). */
    { 0, XK_F1, spawn, {.v = mutecmd} },
    { 0, XK_F2, spawn, {.v = voldowncmd} },
    { 0, XK_F3, spawn, {.v = volupcmd} },
    { 0, XK_F5, spawn, {.v = dimcmd} },
    { 0, XK_F6, spawn, {.v = brightcmd} },
    { 0, XF86XK_AudioMute, spawn, {.v = mutecmd} },
    { 0, XF86XK_AudioLowerVolume, spawn, {.v = voldowncmd} },
    { 0, XF86XK_AudioRaiseVolume, spawn, {.v = volupcmd} },
    { 0, XF86XK_MonBrightnessDown, spawn, {.v = dimcmd} },
    { 0, XF86XK_MonBrightnessUp, spawn, {.v = brightcmd} },

    { MODKEY,           XK_p, spawn, {.v = controlcmd } },
    { MODKEY,           XK_e, spawn, {.v = filescmd } },
    { MODKEY|ShiftMask, XK_b, spawn, {.v = webcmd } },
    { MODKEY|ShiftMask, XK_c, spawn, {.v = codexcmd } },
    { MODKEY|ShiftMask, XK_s, spawn, {.v = sendcmd } },
    { MODKEY|ShiftMask, XK_w, spawn, {.v = wificmd } },
    { MODKEY|ShiftMask, XK_n, spawn, {.v = btcmd } },
    { MODKEY|ShiftMask, XK_t, spawn, {.v = monitorcmd } },
	/* modifier                     key        function        argument */


    { MODKEY|ShiftMask, XK_h, shiftdir, {.i = DirLeft} },
    { MODKEY|ShiftMask, XK_j, shiftdir, {.i = DirDown} },
    { MODKEY|ShiftMask, XK_k, shiftdir, {.i = DirUp} },
    { MODKEY|ShiftMask, XK_l, shiftdir, {.i = DirRight} },
    { MODKEY, XK_minus, resizefocused, {.f = -1.0} },
    { MODKEY, XK_equal, resizefocused, {.f = +1.0} },
	{ MODKEY,                       XK_Return, spawn,          {.v = termcmd } },
	{ MODKEY,                       XK_b,      togglebar,      {0} },
	{ MODKEY,                       XK_j,      focusdir,        {.i = DirDown} },
	{ MODKEY,                       XK_Up,     focusdir,        {.i = DirUp} },
	{ MODKEY,                       XK_k,      spawn,           {.v = keyguidecmd} },
	{ MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
	{ MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
	{ MODKEY,                       XK_h,      focusdir,        {.i = DirLeft} },
	{ MODKEY,                       XK_l,      focusdir,        {.i = DirRight} },
	{ MODKEY,                       XK_z,      zoom,           {0} },
	{ MODKEY,                       XK_Tab,    view,           {0} },
	{ MODKEY,                       XK_q,      killclient,     {0} },
	{ MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_f,      togglefloating, {0} },
	{ MODKEY|ShiftMask,             XK_f,      togglefullscreen, {0} },
	{ MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                       XK_space,  spawn,           {.v = spotcmd} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
	{ MODKEY,                       XK_0,      view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period, focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
	TAGKEYS(                        XK_1,                      0)
	TAGKEYS(                        XK_2,                      1)
	TAGKEYS(                        XK_3,                      2)
	TAGKEYS(                        XK_4,                      3)
	TAGKEYS(                        XK_5,                      4)
	{ MODKEY|ShiftMask,             XK_r,      quit,           {.i = 1} },
	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} },
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button1,        spawn,          {.v = controlcmd } },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};
