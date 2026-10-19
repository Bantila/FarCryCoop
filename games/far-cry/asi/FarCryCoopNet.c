// FarCryCoopNet.asi - logger and fix for the snapshot pipeline of CryGame.dll 1.4.0.1405.
// Hooks (addresses found with REA/Ghidra, checked against MOD SDK 1.4 sources):
//   CXSnapshot::BuildAndSendSnapshot  0x3306faba (server)
//   CNetEntityInfo::Update            0x330bb9b7 (server)
//   CNetEntityInfo::Write             0x330bb82d (server)
//   CXServerSlot::SendUnreliableMsg   0x3306c620 (server)
//   CXClient::ParseIncomingStream     0x3308354b (client)
//   CXClient::OnServerMsgTimeStamp    0x33080227 (client)
//   CXClient::OnServerMsgUpdateEntity 0x330816ef (client)
//   GameWarning                       0x3307019e (both; catches "Updated but not spawned")
//   CMovieUser::Begin/EndCutScene     0x330cfd25 / 0x330cfed6 (dedicated server: skipped, it has no input)
//   CryMovie.dll sound track key      0x3401a396 (skipped when there is no sound system)
// Fix: sorts the snapshot entity list by priority and keeps each snapshot under the 8992-bit
// unreliable buffer of CryNetwork, so nothing is dropped and held-back entities rotate in.
// Built without the Windows SDK and CRT (none on this PC outside drive C:), see build.ps1.
#include <stdarg.h>

typedef unsigned char BYTE;
typedef unsigned short WORD;
typedef unsigned long DWORD;
typedef int BOOL;
typedef void *HANDLE;

#define API(t) __declspec(dllimport) t __stdcall
API(HANDLE) GetModuleHandleA(const char *);
API(DWORD) GetModuleFileNameA(HANDLE, char *, DWORD);
API(void *) VirtualAlloc(void *, DWORD, DWORD, DWORD);
API(BOOL) VirtualProtect(void *, DWORD, DWORD, DWORD *);
API(BOOL) FlushInstructionCache(HANDLE, const void *, DWORD);
API(HANDLE) GetCurrentProcess(void);
API(DWORD) GetCurrentProcessId(void);
API(HANDLE) CreateThread(void *, DWORD, DWORD(__stdcall *)(void *), void *, DWORD, DWORD *);
API(void) Sleep(DWORD);
API(HANDLE) CreateFileA(const char *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
API(BOOL) WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
API(DWORD) GetTickCount(void);
API(BOOL) DisableThreadLibraryCalls(HANDLE);
API(int) wvsprintfA(char *, const char *, va_list);

int _fltused = 1;

// No CRT: the optimizer may still emit calls to memset for byte loops.
void *__cdecl memset(void *d, int c, unsigned n)
{
	BYTE *p = (BYTE *)d;
	while (n--)
		*p++ = (BYTE)c;
	return d;
}

#define CRYGAME_BASE 0x33000000u
#define CRYGAME_TIMESTAMP 0x44e2f64du // PE header of the 1.4.0.1405 build
#define CRYMOVIE_BASE 0x34000000u
#define CRYMOVIE_TIMESTAMP 0x44ae37b4u
#define CG(va) (g_base + ((va) - CRYGAME_BASE))

static HANDLE g_log = (HANDLE)-1;
static BYTE *g_base, *g_movie; // CryGame.dll, CryMovie.dll

static void logf(const char *fmt, ...)
{
	char buf[1024 + 2]; // wvsprintfA writes at most 1024 chars
	DWORD n, w;
	va_list va;
	va_start(va, fmt);
	n = (DWORD)wvsprintfA(buf, fmt, va);
	va_end(va);
	buf[n++] = '\r';
	buf[n++] = '\n';
	if (g_log != (HANDLE)-1)
		WriteFile(g_log, buf, n, &w, 0);
}

// ---- per-second counters ----
static struct {
	DWORD snap, snapBits;             // BuildAndSendSnapshot calls, last snapshot size in bits
	DWORD upd, upd0, updHi;           // Update calls, priority 0 (not sent), priority >= 1000000 (slot's own player)
	DWORD plId, plPrio;               // last slot player seen in Update
	DWORD ts, tsIgn; int tsWorld;     // TimeStamp calls, of them set m_bIgnoreSnapshot, last world time
	DWORD ue, ueFail, ueIgn;          // UpdateEntity calls, returned false (packet aborted), read while ignoring
	DWORD myId, ueOwn;                // client: m_wPlayerID, UpdateEntity calls for it
	DWORD idMin, idMax;               // client: range of entity ids peeked from UpdateEntity
	DWORD wr, wrOwn;                  // server: CNetEntityInfo::Write calls (entities really sent), of them slot player
	int px, py, pz;                   // own player position x10 (server: slot player, client: m_wPlayerID)
	DWORD skip, rx, rxMax;            // server: entity updates held back by the budget; client: packets, biggest in bits
	DWORD gap, lastAt;                // longest pause in ms between snapshots (server) / TimeStamps (client)
} s;
static void *(__cdecl *getISystem)(void); // CryGame GetISystem() at 0x330be6e8
#define VFN(obj, off) ((*(void ***)(obj))[(off) / 4])
static DWORD g_lastTick;

static void gap(void) // a stutter shows up as a long pause between two network frames
{
	DWORD now = GetTickCount();
	if (s.lastAt && now - s.lastAt > s.gap)
		s.gap = now - s.lastAt;
	s.lastAt = now;
}

static void tick(void)
{
	DWORD now = GetTickCount();
	if (now - g_lastTick < 1000)
		return;
	g_lastTick = now;
	if (s.snap || s.upd || s.ts || s.ue)
		{
			// CAISystem (CryAISystem.dll): +0x1e4 byte gates CAISystem::Update (0x31020103),
			// +0x1e0 counts its working passes
			void *sys = getISystem ? getISystem() : 0;
			BYTE *ai = sys ? ((BYTE * (__fastcall *)(void *, void *))VFN(sys, 0x7c))(sys, 0) : 0; // GetAISystem
			if (ai)
				logf("ai: enabled=%u passes=%u", ai[0x1e4], *(DWORD *)(ai + 0x1e0));
		}
		logf("t=%u snap=%u bits=%u upd=%u prio0=%u own=%u(id %u prio %u) | ts=%u ign=%u world=%d ue=%u fail=%u ueIgn=%u my=%u(%u) ids=%u..%u | sent=%u own=%u skip=%u | rx=%u max=%u | gap=%ums | pos=%d,%d,%d",
			now, s.snap, s.snapBits, s.upd, s.upd0, s.updHi, s.plId, s.plPrio,
			s.ts, s.tsIgn, s.tsWorld, s.ue, s.ueFail, s.ueIgn, s.myId, s.ueOwn, s.idMin, s.idMax, s.wr, s.wrOwn, s.skip, s.rx, s.rxMax, s.gap, s.px, s.py, s.pz);
	s.snap = s.upd = s.upd0 = s.updHi = s.ts = s.tsIgn = s.ue = s.ueFail = s.ueIgn = s.ueOwn = s.idMax = s.wr = s.wrOwn = s.skip = s.rx = s.rxMax = s.gap = 0;
	s.idMin = 0xffff;
}

// ---- hooks (thiscall emulated with fastcall: ECX = this, EDX unused) ----
typedef struct { float x, y, z; } Vec3;

static void savePos(void *ent) // IEntity::GetPos(bool bWorldOnly) at vtable +0x04
{
	Vec3 *v = ((Vec3 * (__fastcall *)(void *, void *, int))VFN(ent, 0x04))(ent, 0, 1);
	s.px = (int)(v->x * 10);
	s.py = (int)(v->y * 10);
	s.pz = (int)(v->z * 10);
}

// FIX: on campaign maps a snapshot is bigger than one unreliable packet and its tail never
// reaches the client. The tail is the end of m_lstNetEntities, where the slot's own player
// (spawned last) sits. Sort the list by CNetEntityInfo::GetTimeAffectedPriority
// (m_nPriority * time since last send) so the important entities go first and the rest rotate.
// std::list node (VS 2003): +0 next, +4 prev, +8 CNetEntityInfo
// (+0x10 m_fLastUpdate, +0x24 m_nPriority from the previous Update).
#define MAX_NET 4096
static BYTE *v[MAX_NET];    // list nodes in send order
static float k[MAX_NET], lu[MAX_NET]; // sort key, m_fLastUpdate before the snapshot
static int g_n;             // nodes in v, 0 if the list was not sorted
static void sortNetEntities(BYTE *snap)
{
	BYTE *head = *(BYTE **)(snap + 8), *n, *prev; // m_lstNetEntities
	void *timer = *(void **)(snap + 0x18);        // m_pTimer
	float now = ((float(__fastcall *)(void *, void *))VFN(timer, 0x08))(timer, 0), dt, key; // ITimer::GetCurrTime
	int c = 0, i, j;
	g_n = 0;
	for (n = *(BYTE **)head; n != head; n = *(BYTE **)n) {
		if (c == MAX_NET)
			return; // ponytail: list too big, keep engine order and no budget
		dt = now - *(float *)(n + 0x10);
		v[c] = n;
		k[c++] = (float)*(int *)(n + 0x24) * (dt > 0 ? dt : 0);
	}
	for (i = 1; i < c; i++) { // ponytail: insertion sort, list is nearly sorted after the first frame
		n = v[i];
		key = k[i];
		for (j = i; j > 0 && k[j - 1] < key; j--) {
			v[j] = v[j - 1];
			k[j] = k[j - 1];
		}
		v[j] = n;
		k[j] = key;
	}
	for (prev = head, i = 0; i < c; prev = v[i++]) {
		*(BYTE **)prev = v[i];
		*(BYTE **)(v[i] + 4) = prev;
	}
	*(BYTE **)prev = head;
	*(BYTE **)(head + 4) = prev;
	for (i = 0; i < c; i++)
		lu[i] = *(float *)(v[i] + 0x10);
	g_n = c;
}

// FIX 2: CryNetwork collects the unreliable data of a frame in a CStream with a fixed stack
// buffer: DEFAULT_STREAM_BYTESIZE 1124 bytes = 8992 bits (CryCommon/Stream.h, CStream ctor
// FUN_34502810 in CryNetwork.dll). Writes past it are dropped silently. So hold back entity
// updates past a budget, and give the held-back entities their old m_fLastUpdate back:
// their time-affected priority keeps growing and they move to the front of a later snapshot.
#define SNAP_BUDGET_BITS 8800 // ponytail: margin for TIMESTAMP/CLIENTSTRING/CTP headers (seen 20-100 bits); lower if rx max passes 8992
static int g_inSnap, g_sent, g_full; // in snapshot, updates sent, budget used up
static DWORD g_bits;

static DWORD(__fastcall *oSend)(void *, void *, DWORD, void *, const char *, DWORD);
static DWORD __fastcall hSend(void *slot, void *edx, DWORD msg, void *stm, const char *name, DWORD withSize)
{ // CXServerSlot::SendUnreliableMsg(XSERVERMSG, CStream&, const char*, bool), returns bits sent
	DWORD bits;
	if (g_inSnap && (BYTE)msg == 0 && g_n) { // XSERVERMSG_UPDATEENTITY from our sorted snapshot
		bits = *(DWORD *)((BYTE *)stm + 0x470) + 8; // payload + message id
		if (g_full || g_bits + bits > SNAP_BUDGET_BITS) { // strict prefix: list order = send order
			g_full = 1;
			s.skip++;
			return 0;
		}
		g_bits += bits;
		g_sent++;
	}
	return oSend(slot, edx, msg, stm, name, withSize);
}

static void restoreHeldBack(void)
{
	int i, tried = 0;
	for (i = 0; i < g_n; i++)
		if (*(float *)(v[i] + 0x10) != lu[i] && ++tried > g_sent) // Reset() ran, but nothing was sent
			*(float *)(v[i] + 0x10) = lu[i];
}

static void(__fastcall *oSnap)(void *, void *);
static void __fastcall hSnap(void *self, void *edx)
{
	sortNetEntities((BYTE *)self);
	g_inSnap = 1;
	g_sent = g_full = 0;
	g_bits = 0;
	oSnap(self, edx);
	g_inSnap = 0;
	gap();
	if (g_n)
		restoreHeldBack();
	s.snap++;
	s.snapBits = ((DWORD *)self)[1]; // m_nLastSnapshotBitSize
	tick();
}

static void(__fastcall *oUpd)(void *, void *, Vec3);
static void __fastcall hUpd(void *self, void *edx, Vec3 viewer)
{
	DWORD prio;
	void **ent;
	oUpd(self, edx, viewer);
	prio = *(DWORD *)((BYTE *)self + 0x1c); // m_nPriority
	s.upd++;
	if (!prio)
		s.upd0++;
	if (prio >= 1000000) {
		ent = *(void ***)((BYTE *)self + 4); // m_pEntity
		s.updHi++;
		s.plPrio = prio;
		s.plId = 0;
		if (ent) {
			s.plId = ((WORD(__fastcall *)(void *, void *))VFN(ent, 0xc4))(ent, 0); // IEntity::GetId
			savePos(ent);
		}
	}
}

static BYTE(__fastcall *oWr)(void *, void *, void *, void *);
static BYTE __fastcall hWr(void *self, void *edx, void *server, void *stm)
{
	s.wr++;
	if (*(DWORD *)((BYTE *)self + 0x1c) >= 1000000) // m_nPriority: slot's own player
		s.wrOwn++;
	return oWr(self, edx, server, stm);
}

static BYTE(__fastcall *oRx)(void *, void *, void *);
static BYTE __fastcall hRx(void *self, void *edx, void *stm)
{ // CXClient::ParseIncomingStream(CStream&): size of every packet that reaches the game
	DWORD bits = *(DWORD *)((BYTE *)stm + 0x470);
	s.rx++;
	if (bits > s.rxMax)
		s.rxMax = bits;
	return oRx(self, edx, stm);
}

static BYTE(__fastcall *oTs)(void *, void *, void *);
static BYTE __fastcall hTs(void *self, void *edx, void *stm)
{
	BYTE r = oTs(self, edx, stm);
	s.ts++;
	gap();
	if (*((BYTE *)self + 0x14)) // m_bIgnoreSnapshot
		s.tsIgn++;
	s.tsWorld = *(int *)((BYTE *)self + 0x10); // m_iPhysicalWorldTime
	tick();
	return r;
}

static BYTE(__fastcall *oUe)(void *, void *, void *);
static BYTE __fastcall hUe(void *self, void *edx, void *stm)
{
	DWORD *rd = (DWORD *)((BYTE *)stm + 0x474), at = *rd, id = 0; // CStream read position
	void *game = *(void **)((BYTE *)self + 0x44), *bs, *sys, *ent;  // m_pGame
	BYTE r;
	// peek the entity id the same way the original does, then rewind the stream
	bs = ((void *(__fastcall *)(void *, void *))VFN(game, 0x104))(game, 0); // GetIBitStream
	((BYTE(__fastcall *)(void *, void *, void *, DWORD *, int))VFN(bs, 0x10))(bs, 0, stm, &id, 4); // ReadBitStream(stm, id, eEntityId)
	*rd = at;
	if ((WORD)id < s.idMin)
		s.idMin = (WORD)id;
	if ((WORD)id > s.idMax)
		s.idMax = (WORD)id;
	r = oUe(self, edx, stm);
	s.ue++;
	s.myId = *(WORD *)((BYTE *)self + 0xc); // m_wPlayerID
	if ((WORD)id == s.myId) {
		s.ueOwn++;
		sys = *(void **)((BYTE *)self + 0x4c); // m_pISystem (IXSystem)
		ent = ((void *(__fastcall *)(void *, void *, int))VFN(sys, 0x58))(sys, 0, (WORD)id); // GetEntity
		if (ent)
			savePos(ent);
	}
	if (*((BYTE *)self + 0x14))
		s.ueIgn++;
	if (!r) {
		s.ueFail++;
		if (s.ueFail <= 3)
			logf("UpdateEntity returned false: rest of this packet is dropped");
	}
	return r;
}

// FIX 3: CMovieUser::BeginCutScene / EndCutScene (GameMovieUser.cpp) call
// GetISystem()->GetIInput()->GetIKeyboard()->ClearKeyState(). The dedicated server has no
// input, so the first cutscene (e.g. in Training) crashes it with a NULL read at 0x330cfe4a.
// The server shows no cutscene, so on a server without input both callbacks are skipped
// (in pairs, so the cutscene counter at +0x0c stays consistent).
static int noInput(void)
{
	void *sys = getISystem();
	return !((void *(__fastcall *)(void *, void *))VFN(sys, 0x58))(sys, 0); // ISystem::GetIInput
}

static void(__fastcall *oBeginCut)(void *, void *, DWORD, DWORD);
static void __fastcall hBeginCut(void *self, void *edx, DWORD flags, DWORD resetFx)
{
	if (noInput())
		return;
	oBeginCut(self, edx, flags, resetFx);
}

static void(__fastcall *oEndCut)(void *, void *);
static void __fastcall hEndCut(void *self, void *edx)
{
	if (noInput())
		return;
	oEndCut(self, edx);
}

// FIX 4: the cutscene sound track in CryMovie (key handler 0x3401a396) loads its sound with
// GetISystem()->GetISoundSystem()->LoadSound(...); the dedicated server has no sound system,
// so it crashes with a NULL read at 0x3401a4eb. Skip only the sound key; the sequence itself
// (entity animation, events that drive the mission) keeps running on the server.
static void(__fastcall *oSoundKey)(void *, void *, void *, DWORD, DWORD, void *, void *);
static void __fastcall hSoundKey(void *self, void *edx, void *a, DWORD b, DWORD c, void *key, void *anim)
{ // thiscall with 5 arguments, RET 0x14
	void *sys = getISystem();
	if (!((void *(__fastcall *)(void *, void *))VFN(sys, 0x6c))(sys, 0)) // ISystem::GetISoundSystem
		return;
	oSoundKey(self, edx, a, b, c, key, anim);
}

static DWORD g_warns;
static void __cdecl logWarn(const char *fmt, va_list va)
{ // log only the raw format: wvsprintfA has no %f, so formatting float arguments could
  // shift the va_list and make a later %s read a garbage pointer
	char buf[300];
	int i;
	if (++g_warns > 500) // ponytail: hard cap so a spamming warning cannot fill the disk
		return;
	for (i = 0; i < 299 && fmt[i]; i++)
		buf[i] = fmt[i];
	buf[i] = 0;
	logf("warn: %s", buf);
}

static void *oWarn;
static __declspec(naked) void hWarn(void)
{
	__asm {
		lea eax, [esp + 8]      // va_list after fmt
		push eax
		push dword ptr [esp + 8] // fmt (shifted by the push above)
		call logWarn
		add esp, 8
		jmp dword ptr [oWarn]
	}
}

// ---- inline hook: copy whole prologue instructions to a trampoline, jump to the hook ----
static int hook(BYTE *p, int len, const BYTE *expect, void *fn, void **orig, const char *name)
{
	BYTE *t;
	DWORD old;
	int i;
	for (i = 0; i < len; i++) // B8 imm32 prologues: only the opcode is checked, imm32 may be relocated
		if (expect[i] != 0xff && p[i] != expect[i]) {
			logf("SKIP %s: unexpected byte %u at +%d", name, p[i], i);
			return 0;
		}
	t = (BYTE *)VirtualAlloc(0, 32, 0x3000, 0x40); // MEM_COMMIT|MEM_RESERVE, PAGE_EXECUTE_READWRITE
	for (i = 0; i < len; i++)
		t[i] = p[i];
	t[len] = 0xe9;
	*(DWORD *)(t + len + 1) = (DWORD)(p + len) - (DWORD)(t + len + 5);
	*orig = t;
	VirtualProtect(p, len, 0x40, &old);
	p[0] = 0xe9;
	*(DWORD *)(p + 1) = (DWORD)fn - (DWORD)(p + 5);
	for (i = 5; i < len; i++)
		p[i] = 0x90;
	VirtualProtect(p, len, old, &old);
	FlushInstructionCache(GetCurrentProcess(), p, len);
	logf("hooked %s at %x", name, (DWORD)p);
	return 1;
}

static DWORD __stdcall worker(void *unused)
{
	static const BYTE eh[] = {0xb8, 0xff, 0xff, 0xff, 0xff};                // mov eax, imm32 (EH prolog)
	static const BYTE ue[] = {0x55, 0x8b, 0xec, 0x83, 0xec, 0x14};          // push ebp; mov ebp,esp; sub esp,14
	static const BYTE wr[] = {0x55, 0x8b, 0xec, 0x53, 0x56};                // push ebp; mov ebp,esp; push ebx; push esi
	static const BYTE ts[] = {0x55, 0x8b, 0xec, 0x51, 0x51};                // push ebp; mov ebp,esp; push ecx x2
	static const BYTE gw[] = {0x55, 0x8b, 0xec, 0xb8, 0x00, 0x10, 0, 0};    // push ebp; mov ebp,esp; mov eax,1000h
	BYTE *nt;
	int i;
	for (i = 0; i < 120000 && !(g_base = (BYTE *)GetModuleHandleA("CryGame.dll")); i++)
		Sleep(1);
	if (!g_base) {
		logf("CryGame.dll not loaded in 120 s, nothing hooked");
		return 0;
	}
	nt = g_base + *(DWORD *)(g_base + 0x3c);
	if (*(DWORD *)(nt + 8) != CRYGAME_TIMESTAMP) {
		logf("CryGame.dll timestamp %x is not 1.4.0.1405, nothing hooked", *(DWORD *)(nt + 8));
		return 0;
	}
	logf("CryGame.dll at %x", (DWORD)g_base);
	g_movie = (BYTE *)GetModuleHandleA("CryMovie.dll");
	if (g_movie && *(DWORD *)(g_movie + *(DWORD *)(g_movie + 0x3c) + 8) == CRYMOVIE_TIMESTAMP) {
		static const BYTE sk[] = {0x55, 0x8b, 0xec, 0x51, 0x8b, 0x45, 0x10}; // push ebp; mov ebp,esp; push ecx; mov eax,[ebp+10]
		hook(g_movie + (0x3401a396 - CRYMOVIE_BASE), 7, sk, hSoundKey, (void **)&oSoundKey, "CryMovie sound track key");
	} else
		logf("CryMovie.dll missing or not the 1.4 build, sound key not hooked");
	getISystem = (void *(__cdecl *)(void))(g_base + (0x330be6e8 - CRYGAME_BASE));
	hook(CG(0x330cfd25), 5, eh, hBeginCut, (void **)&oBeginCut, "CMovieUser::BeginCutScene");
	hook(CG(0x330cfed6), 5, eh, hEndCut, (void **)&oEndCut, "CMovieUser::EndCutScene");
	hook(CG(0x3306faba), 5, eh, hSnap, (void **)&oSnap, "CXSnapshot::BuildAndSendSnapshot");
	hook(CG(0x330bb9b7), 5, eh, hUpd, (void **)&oUpd, "CNetEntityInfo::Update");
	hook(CG(0x330bb82d), 5, wr, hWr, (void **)&oWr, "CNetEntityInfo::Write");
	hook(CG(0x3306c620), 5, eh, hSend, (void **)&oSend, "CXServerSlot::SendUnreliableMsg");
	hook(CG(0x3308354b), 6, ue, hRx, (void **)&oRx, "CXClient::ParseIncomingStream");
	hook(CG(0x33080227), 5, ts, hTs, (void **)&oTs, "CXClient::OnServerMsgTimeStamp");
	hook(CG(0x330816ef), 6, ue, hUe, (void **)&oUe, "CXClient::OnServerMsgUpdateEntity");
	hook(CG(0x3307019e), 8, gw, hWarn, &oWarn, "GameWarning");
	return 0;
}

// Log file: <game>\Mods\FarCryCoop\netlog_<exe>_<pid>.txt (the ASI sits in <game>\Bin32).
BOOL __stdcall DllMain(HANDLE self, DWORD reason, void *reserved)
{
	char path[600], exe[260], *p, *name;
	void *args[2];
	int n, cut = 0;
	if (reason != 1) // DLL_PROCESS_ATTACH
		return 1;
	DisableThreadLibraryCalls(self);
	GetModuleFileNameA(0, exe, sizeof exe);
	for (name = p = exe; *p; p++)
		if (*p == '\\')
			name = p + 1;
	for (p = name; *p; p++)
		if (*p == '.')
			*p = 0;
	n = (int)GetModuleFileNameA(self, path, 260);
	while (n > 0 && cut < 2) // strip "\FarCryCoopNet.asi" and "\Bin32"
		if (path[--n] == '\\')
			cut++;
	args[0] = name;
	args[1] = (void *)GetCurrentProcessId();
	wvsprintfA(path + n, "\\Mods\\FarCryCoop\\netlog_%s_%u.txt", (va_list)args);
	g_log = CreateFileA(path, 0x40000000, 1, 0, 2, 0x80, 0); // GENERIC_WRITE, FILE_SHARE_READ, CREATE_ALWAYS
	logf("FarCryCoopNet loaded in %s", name);
	CreateThread(0, 0, worker, 0, 0, 0);
	return 1;
}
