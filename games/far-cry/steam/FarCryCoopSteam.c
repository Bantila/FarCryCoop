// FarCryCoopSteam.exe - Steam bridge for Far Cry co-op: friends join the host from the Steam
// friends list (Join / Invite), whatever copy of the game they have, without port forwarding,
// Hamachi or Radmin. Runs as Spacewar (AppID 480, steam_appid.txt next to it), which every
// Steam account may use. Steam carries the game's UDP packets (NAT punch, else Valve relays);
// the game itself only ever talks to this program on 127.0.0.1, as on a LAN.
//
// Host: while a Far Cry server runs on this PC (UDP port 49001 taken), rich presence "connect"
// is set, so friends see Join. Every friend gets a local UDP socket that talks to the server
// on 127.0.0.1:49001; the server sees him as 127.0.0.1:<port>.
// Friend: Join (or an accepted invite) gives the host's SteamID; this program listens on
// 127.0.0.1:49011 and writes the console line that connects the game there into
// Mods\FarCryCoop\join.txt, which FarCryCoopNet.asi runs in the game.
// -loop: no Steam; the friend side is tunnelled straight to the own host side (local test).
//
// Steam: flat C API of steam_api.dll (Steamworks SDK 1.6x, loaded at run time), callbacks by
// manual dispatch. Built without the Windows SDK and CRT, like the ASI: see build.ps1.
#include <stdarg.h>

typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef unsigned __int64 U64;
typedef int BOOL;
typedef void *HANDLE;
typedef unsigned int SOCKET;
#define HI(u64) (((DWORD *)&(u64))[1]) // no CRT: a 64-bit shift would call __aullshr

#define API(t) __declspec(dllimport) t __stdcall
API(HANDLE) GetStdHandle(DWORD);
API(BOOL) WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
API(void) Sleep(DWORD);
API(DWORD) GetTickCount(void);
API(HANDLE) LoadLibraryA(const char *);
API(void *) GetProcAddress(HANDLE, const char *);
API(DWORD) GetModuleFileNameA(HANDLE, char *, DWORD);
API(HANDLE) CreateFileA(const char *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
API(BOOL) CloseHandle(HANDLE);
API(void) ExitProcess(DWORD);
API(char *) GetCommandLineA(void);
API(BOOL) SetConsoleTitleA(const char *);
API(BOOL) SetConsoleOutputCP(DWORD);
API(int) wvsprintfA(char *, const char *, va_list);
API(int) WSAStartup(WORD, void *);
API(SOCKET) socket(int, int, int);
API(int) bind(SOCKET, const void *, int);
API(int) closesocket(SOCKET);
API(int) ioctlsocket(SOCKET, long, DWORD *);
API(int) recvfrom(SOCKET, char *, int, int, void *, int *);
API(int) sendto(SOCKET, const char *, int, int, const void *, int);

int _fltused = 1;
void *__cdecl memset(void *d, int c, unsigned n)
{
	BYTE *p = (BYTE *)d;
	while (n--)
		*p++ = (BYTE)c;
	return d;
}
void *__cdecl memcpy(void *d, const void *s, unsigned n)
{
	BYTE *p = (BYTE *)d;
	const BYTE *q = (const BYTE *)s;
	while (n--)
		*p++ = *q++;
	return d;
}

#define SERVER_PORT 49001 // Far Cry sv_port default
#define CLIENT_PORT 49011 // the friend's game connects here
#define MAX_PEERS 16
#define PEER_IDLE 60000 // ms without packets: drop the friend's local socket
#define LOOP_HOST 1     // -loop: fake SteamIDs
#define LOOP_CLIENT 2

static void say(const char *fmt, ...)
{
	char buf[1024 + 2];
	DWORD n, w;
	va_list va;
	va_start(va, fmt);
	n = (DWORD)wvsprintfA(buf, fmt, va);
	va_end(va);
	buf[n++] = '\r';
	buf[n++] = '\n';
	WriteFile(GetStdHandle((DWORD)-11), buf, n, &w, 0); // STD_OUTPUT_HANDLE
}

// ---- Steam (steamnetworkingtypes.h, isteamfriends.h; Windows packs callbacks at 8) ----
typedef struct { int type; int size; union { U64 steamID; BYTE raw[128]; } u; } Identity; // SteamNetworkingIdentity, pack 1
typedef struct { int user; int id; BYTE *param; int size; } CallbackMsg;                  // CallbackMsg_t
#define MSG_DATA(m) (*(BYTE **)(m))                // SteamNetworkingMessage_t::m_pData
#define MSG_SIZE(m) (*(int *)((BYTE *)(m) + 4))    // m_cbSize
#define MSG_FROM(m) (*(U64 *)((BYTE *)(m) + 20))   // m_identityPeer (at 12) .m_steamID64 (at +8)
#define CB_SESSION_REQUEST 1251 // SteamNetworkingMessagesSessionRequest_t { Identity remote; }
#define CB_JOIN_REQUESTED 337   // GameRichPresenceJoinRequested_t { U64 friend; char connect[256]; }
#define SEND_FLAGS (0 | 1 | 32) // Unreliable | NoNagle | AutoRestartBrokenSession

static HANDLE g_steam;
static void *sym(const char *name)
{
	void *f = GetProcAddress(g_steam, name);
	if (!f) {
		say("steam_api.dll has no %s: wrong version", name);
		Sleep(10000);
		ExitProcess(1);
	}
	return f;
}
static int(__cdecl *InitFlat)(char *);
static void(__cdecl *DispatchInit)(void);
static int(__cdecl *GetPipe)(void);
static void(__cdecl *RunFrame)(int);
static BYTE(__cdecl *NextCallback)(int, CallbackMsg *);
static void(__cdecl *FreeCallback)(int);
static void *g_user, *g_friends, *g_msgs, *g_utils;
static U64(__cdecl *GetSteamID)(void *);
static const char *(__cdecl *PersonaName)(void *);
static BYTE(__cdecl *SetRichPresence)(void *, const char *, const char *);
static void(__cdecl *ClearRichPresence)(void *);
static int(__cdecl *SendToUser)(void *, const Identity *, const void *, DWORD, int, int);
static int(__cdecl *Receive)(void *, int, void **, int);
static BYTE(__cdecl *AcceptSession)(void *, const Identity *);
static void(__cdecl *InitRelay)(void *);
static void(__cdecl *Release)(void *);
static int g_pipe;

static void steamInit(void)
{
	char err[1024], dir[300];
	int n = (int)GetModuleFileNameA(0, dir, 260);
	while (n > 0 && dir[n - 1] != '\\')
		n--;
	wvsprintfA(dir + n, "steam_api.dll", 0);
	if (!(g_steam = LoadLibraryA(dir))) {
		say("steam_api.dll not found next to FarCryCoopSteam.exe");
		Sleep(10000);
		ExitProcess(1);
	}
	InitFlat = (int(__cdecl *)(char *))sym("SteamAPI_InitFlat");
	err[0] = 0;
	if (InitFlat(err)) {
		say("Steam did not start: %s", err);
		say("Start Steam and log in, then start FarCryCoop.bat again.");
		Sleep(15000);
		ExitProcess(1);
	}
	DispatchInit = (void(__cdecl *)(void))sym("SteamAPI_ManualDispatch_Init");
	GetPipe = (int(__cdecl *)(void))sym("SteamAPI_GetHSteamPipe");
	RunFrame = (void(__cdecl *)(int))sym("SteamAPI_ManualDispatch_RunFrame");
	NextCallback = (BYTE(__cdecl *)(int, CallbackMsg *))sym("SteamAPI_ManualDispatch_GetNextCallback");
	FreeCallback = (void(__cdecl *)(int))sym("SteamAPI_ManualDispatch_FreeLastCallback");
	g_user = ((void *(__cdecl *)(void))sym("SteamAPI_SteamUser_v023"))();
	g_friends = ((void *(__cdecl *)(void))sym("SteamAPI_SteamFriends_v018"))();
	g_msgs = ((void *(__cdecl *)(void))sym("SteamAPI_SteamNetworkingMessages_SteamAPI_v002"))();
	g_utils = ((void *(__cdecl *)(void))sym("SteamAPI_SteamNetworkingUtils_SteamAPI_v004"))();
	GetSteamID = (U64(__cdecl *)(void *))sym("SteamAPI_ISteamUser_GetSteamID");
	PersonaName = (const char *(__cdecl *)(void *))sym("SteamAPI_ISteamFriends_GetPersonaName");
	SetRichPresence = (BYTE(__cdecl *)(void *, const char *, const char *))sym("SteamAPI_ISteamFriends_SetRichPresence");
	ClearRichPresence = (void(__cdecl *)(void *))sym("SteamAPI_ISteamFriends_ClearRichPresence");
	SendToUser = (int(__cdecl *)(void *, const Identity *, const void *, DWORD, int, int))sym("SteamAPI_ISteamNetworkingMessages_SendMessageToUser");
	Receive = (int(__cdecl *)(void *, int, void **, int))sym("SteamAPI_ISteamNetworkingMessages_ReceiveMessagesOnChannel");
	AcceptSession = (BYTE(__cdecl *)(void *, const Identity *))sym("SteamAPI_ISteamNetworkingMessages_AcceptSessionWithUser");
	InitRelay = (void(__cdecl *)(void *))sym("SteamAPI_ISteamNetworkingUtils_InitRelayNetworkAccess");
	Release = (void(__cdecl *)(void *))sym("SteamAPI_SteamNetworkingMessage_t_Release");
	DispatchInit();
	g_pipe = GetPipe();
	InitRelay(g_utils); // fetch the relay network now, not on the first Join
	say("Steam: %s", PersonaName(g_friends));
}

// ---- sockets ----
typedef struct { short family; WORD port; DWORD ip; BYTE zero[8]; } Addr; // sockaddr_in
static Addr addr(DWORD ip, int port) // ip and port in host order
{
	Addr a;
	memset(&a, 0, sizeof a);
	a.family = 2; // AF_INET
	a.port = (WORD)(((port & 0xff) << 8) | ((port >> 8) & 0xff));
	a.ip = ((ip & 0xff) << 24) | ((ip & 0xff00) << 8) | ((ip >> 8) & 0xff00) | (ip >> 24);
	return a;
}
#define LOCALHOST 0x7f000001
static SOCKET udp(DWORD ip, int port) // bound, non-blocking; -1 if the port is taken
{
	SOCKET s = socket(2, 2, 17); // AF_INET, SOCK_DGRAM, IPPROTO_UDP
	Addr a = addr(ip, port);
	DWORD on = 1;
	if (s == (SOCKET)-1)
		return s;
	if (bind(s, &a, sizeof a)) {
		closesocket(s);
		return (SOCKET)-1;
	}
	ioctlsocket(s, 0x8004667e, &on); // FIONBIO
	return s;
}

// ---- tunnel ----
static int g_loop;
static U64 g_me, g_host;          // friend side: the host we joined
static SOCKET g_game = (SOCKET)-1; // friend side: 127.0.0.1:49011
static Addr g_gameAddr;
static int g_gameKnown;
static struct { U64 id; SOCKET s; DWORD last; } g_peers[MAX_PEERS]; // host side: one per friend
static BYTE g_buf[65536];

static void hostReceived(U64 from, const BYTE *data, int n);
static void friendReceived(U64 from, const BYTE *data, int n);
static void sendSteam(U64 to, const BYTE *data, int n)
{
	Identity id;
	if (g_loop) {
		if (to == LOOP_HOST)
			hostReceived(LOOP_CLIENT, data, n);
		else
			friendReceived(LOOP_HOST, data, n);
		return;
	}
	memset(&id, 0, sizeof id);
	id.type = 16; // k_ESteamNetworkingIdentityType_SteamID
	id.size = 8;
	id.u.steamID = to;
	SendToUser(g_msgs, &id, data, (DWORD)n, SEND_FLAGS, 0);
}

static void hostReceived(U64 from, const BYTE *data, int n) // friend's game -> our server
{
	Addr server = addr(LOCALHOST, SERVER_PORT);
	int i, free = -1;
	for (i = 0; i < MAX_PEERS; i++) {
		if (g_peers[i].s != (SOCKET)-1 && g_peers[i].id == from)
			break;
		if (free < 0 && g_peers[i].s == (SOCKET)-1)
			free = i;
	}
	if (i == MAX_PEERS) {
		if (free < 0)
			return;
		i = free;
		g_peers[i].id = from;
		g_peers[i].s = udp(LOCALHOST, 0);
		say("friend %x%08x joins", HI(from), (DWORD)from);
	}
	g_peers[i].last = GetTickCount();
	sendto(g_peers[i].s, (const char *)data, n, 0, &server, sizeof server);
}

static void friendReceived(U64 from, const BYTE *data, int n) // host's server -> our game
{
	if (from == g_host && g_gameKnown)
		sendto(g_game, (const char *)data, n, 0, &g_gameAddr, sizeof g_gameAddr);
}

static void pump(void) // move every waiting packet once
{
	int i, n, len;
	void *msgs[32];
	for (i = 0; i < MAX_PEERS; i++) {
		if (g_peers[i].s == (SOCKET)-1)
			continue;
		while ((n = recvfrom(g_peers[i].s, (char *)g_buf, sizeof g_buf, 0, 0, 0)) > 0)
			sendSteam(g_peers[i].id, g_buf, n);
		if (GetTickCount() - g_peers[i].last > PEER_IDLE) {
			say("friend %x%08x left", HI(g_peers[i].id), (DWORD)g_peers[i].id);
			closesocket(g_peers[i].s);
			g_peers[i].s = (SOCKET)-1;
		}
	}
	if (g_game != (SOCKET)-1 && g_host) {
		len = sizeof g_gameAddr;
		while ((n = recvfrom(g_game, (char *)g_buf, sizeof g_buf, 0, &g_gameAddr, &len)) > 0) {
			g_gameKnown = 1;
			sendSteam(g_host, g_buf, n);
			len = sizeof g_gameAddr;
		}
	}
	if (g_loop)
		return;
	while ((n = Receive(g_msgs, 0, msgs, 32)) > 0)
		for (i = 0; i < n; i++) {
			U64 from = MSG_FROM(msgs[i]);
			if (from == g_host)
				friendReceived(from, MSG_DATA(msgs[i]), MSG_SIZE(msgs[i]));
			else
				hostReceived(from, MSG_DATA(msgs[i]), MSG_SIZE(msgs[i]));
			Release(msgs[i]);
		}
}

// ---- joining ----
static char g_join[300]; // ..\join.txt: the ASI runs it in the game
static void join(U64 host)
{
	char line[200];
	HANDLE f;
	DWORD w;
	int n, port[1];
	if (g_game == (SOCKET)-1 && (g_game = udp(LOCALHOST, CLIENT_PORT)) == (SOCKET)-1) {
		say("UDP port %d is taken: is another FarCryCoopSteam.exe running?", CLIENT_PORT);
		return;
	}
	g_host = host;
	g_gameKnown = 0;
	port[0] = CLIENT_PORT;
	// as the LAN server list: late switch, no CD key check (that one crashed the game)
	n = wvsprintfA(line, "#Game:Connect(\"127.0.0.1:%d\",1)", (va_list)port);
	f = CreateFileA(g_join, 0x40000000, 0, 0, 2, 0x80, 0); // GENERIC_WRITE, CREATE_ALWAYS
	if (f == (HANDLE)-1) {
		say("cannot write %s", g_join);
		return;
	}
	WriteFile(f, line, (DWORD)n, &w, 0);
	CloseHandle(f);
	say("joining %x%08x: the game connects now", HI(host), (DWORD)host);
}

static U64 parseHex(const char *s)
{
	U64 v = 0;
	for (; *s; s++) {
		int d = *s >= '0' && *s <= '9' ? *s - '0' : *s >= 'a' && *s <= 'f' ? *s - 'a' + 10 : *s >= 'A' && *s <= 'F' ? *s - 'A' + 10 : -1;
		if (d < 0)
			break;
		v = (v << 4) | (U64)d;
	}
	return v;
}

static void callbacks(void)
{
	CallbackMsg cb;
	RunFrame(g_pipe);
	while (NextCallback(g_pipe, &cb)) {
		if (cb.id == CB_SESSION_REQUEST)
			AcceptSession(g_msgs, (const Identity *)cb.param); // anyone who got our SteamID from Join
		else if (cb.id == CB_JOIN_REQUESTED) {
			const char *c = (const char *)cb.param + 8;
			if (c[0] == '+' && c[1] == 'c' && c[5] == 'p' && c[6] == ' ') // "+coop <hex SteamID>"
				join(parseHex(c + 7));
		}
		FreeCallback(g_pipe);
	}
}

static int serverUp(void) // a Far Cry server (listen host or FarCry_WinSV) holds UDP 49001
{
	SOCKET s = udp(0, SERVER_PORT);
	if (s == (SOCKET)-1)
		return 1;
	closesocket(s);
	return 0;
}

void __cdecl start(void)
{
	BYTE wsa[400];
	char *cmd = GetCommandLineA(), connect[40];
	int i, n, up = -1;
	DWORD check = 0, id[2];
	SetConsoleTitleA("Far Cry co-op: Steam");
	SetConsoleOutputCP(65001); // Steam names are UTF-8
	WSAStartup(0x0202, wsa);
	for (i = 0; i < MAX_PEERS; i++)
		g_peers[i].s = (SOCKET)-1;
	n = (int)GetModuleFileNameA(0, g_join, 260);
	for (i = 0; n > 0 && i < 2; ) // strip "\FarCryCoopSteam.exe" and "\Steam"
		if (g_join[--n] == '\\')
			i++;
	wvsprintfA(g_join + n, "\\join.txt", 0);
	for (; *cmd; cmd++)
		if (cmd[0] == '-' && cmd[1] == 'l' && cmd[2] == 'o' && cmd[3] == 'o' && cmd[4] == 'p')
			g_loop = 1;
	if (g_loop)
		say("-loop: no Steam; once a server is up, the other game window connects to it through this program");
	else
		steamInit();
	g_me = g_loop ? LOOP_HOST : GetSteamID(g_user);
	id[0] = HI(g_me);
	id[1] = (DWORD)g_me;
	wvsprintfA(connect, "+coop %x%08x", (va_list)id);
	say("Keep this window open while you play. Host: start a level, friends click Join on you in Steam.");
	for (;;) {
		if (GetTickCount() - check > 2000) {
			int now = serverUp();
			check = GetTickCount();
			if (now != up) {
				up = now;
				if (!g_loop && up) {
					SetRichPresence(g_friends, "status", "Far Cry co-op host");
					SetRichPresence(g_friends, "connect", connect);
				} else if (!g_loop)
					ClearRichPresence(g_friends);
				say(up ? "server up: friends can join" : "no server on this PC");
				if (g_loop && up)
					join(LOOP_HOST);
			}
		}
		if (!g_loop)
			callbacks();
		pump();
		Sleep(1);
	}
}
