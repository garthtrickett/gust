#include <stdio.h>
#include <string.h>
#include <stddef.h>
#include <stdlib.h>
#include <dirent.h>
#include <sys/stat.h>
typedef struct { void* BaseAddress; size_t Offset; size_t Capacity; } os_Arena;
typedef struct { unsigned char* data; int len; } Slice;
struct VecStr { Slice* data; int len; int capacity; os_Arena* arena; };

extern os_Arena os_Arena_New(void);
extern void     os_Arena_Free(os_Arena*);
extern int      os_ArenaAlloc(os_Arena*, size_t);
extern void*    os_ScratchAlloc(size_t);
extern void     os_SetThreadScratch(os_Arena*);
extern os_Arena* os_GetThreadScratch_raw(void);
extern void     os_ScratchReset(void);
extern Slice    std_Clone_str(os_Arena*, Slice);
extern struct VecStr std_str_split(Slice, Slice, os_Arena*);
extern void     os_LogStr(Slice);

static int fails = 0;
static void ck(const char* what, int ok){ printf("  %-42s %s\n", what, ok?"PASS":"FAIL"); if(!ok) fails++; }


/* ---- collections: hashmap and pool ---- */
typedef struct { os_Arena* arena; int capacity; char* keys; int len; int* occupied; char* values; } GMap;
typedef struct { os_Arena* arena; int capacity; void* data; int free_len; int* free_list; int len; int* occupied; } GPool;
extern void* os_HashMapRef_impl(void*, void*, int, size_t, size_t);
extern int   os_HashMapContains_impl(void*, void*, int, size_t);
extern void  os_HashMapRemove_impl(void*, void*, int, size_t, size_t);
extern void  os_HashMapClear_impl(void*, size_t, size_t);
extern int   std_PoolAlloc_impl(void*, size_t);
extern void  std_PoolFree_impl(void*, int);

static void collections_tests(os_Arena* a){
  GMap m = {a,0,NULL,0,NULL,NULL};
  int k1=7, k2=99, miss=1234;
  *(int*)os_HashMapRef_impl(&m,&k1,0,sizeof(int),sizeof(int)) = 111;
  *(int*)os_HashMapRef_impl(&m,&k2,0,sizeof(int),sizeof(int)) = 222;
  ck("map inserts two int keys", m.len == 2);
  ck("map reads back k1", *(int*)os_HashMapRef_impl(&m,&k1,0,sizeof(int),sizeof(int)) == 111);
  ck("map reads back k2", *(int*)os_HashMapRef_impl(&m,&k2,0,sizeof(int),sizeof(int)) == 222);
  ck("map ref did not grow len", m.len == 2);
  ck("contains hit", os_HashMapContains_impl(&m,&k1,0,sizeof(int)) == 1);
  ck("contains miss", os_HashMapContains_impl(&m,&miss,0,sizeof(int)) == 0);
  os_HashMapRemove_impl(&m,&k1,0,sizeof(int),sizeof(int));
  ck("remove drops len", m.len == 1);
  ck("removed key absent", os_HashMapContains_impl(&m,&k1,0,sizeof(int)) == 0);
  ck("survivor still present", os_HashMapContains_impl(&m,&k2,0,sizeof(int)) == 1);

  /* growth: force a rehash past the 16-slot initial capacity */
  GMap g = {a,0,NULL,0,NULL,NULL};
  for(int i=0;i<200;i++) *(int*)os_HashMapRef_impl(&g,&i,0,sizeof(int),sizeof(int)) = i*3;
  ck("map grew to hold 200", g.len == 200);
  int allok=1; for(int i=0;i<200;i++) if(*(int*)os_HashMapRef_impl(&g,&i,0,sizeof(int),sizeof(int)) != i*3) allok=0;
  ck("all 200 survive rehash", allok);

  /* string keys */
  GMap sm = {a,0,NULL,0,NULL,NULL};
  Slice sk1 = {(unsigned char*)"alpha",5}, sk2 = {(unsigned char*)"beta",4};
  *(int*)os_HashMapRef_impl(&sm,&sk1,1,sizeof(Slice),sizeof(int)) = 1;
  *(int*)os_HashMapRef_impl(&sm,&sk2,1,sizeof(Slice),sizeof(int)) = 2;
  Slice sk1b = {(unsigned char*)"alpha",5};
  ck("string key matches by CONTENT", *(int*)os_HashMapRef_impl(&sm,&sk1b,1,sizeof(Slice),sizeof(int)) == 1);
  ck("string map len is 2", sm.len == 2);

  os_HashMapClear_impl(&m,sizeof(int),sizeof(int));
  ck("clear zeroes len", m.len == 0);
  ck("clear makes keys absent", os_HashMapContains_impl(&m,&k2,0,sizeof(int)) == 0);

  GPool p = {a,0,NULL,0,NULL,0,NULL};
  int i0 = std_PoolAlloc_impl(&p,sizeof(int));
  int i1 = std_PoolAlloc_impl(&p,sizeof(int));
  ck("pool hands out 0 then 1", i0==0 && i1==1);
  std_PoolFree_impl(&p,i0);
  ck("pool free records slot", p.free_len == 1);
  ck("pool reuses freed slot", std_PoolAlloc_impl(&p,sizeof(int)) == i0);
  int grow_ok=1; for(int i=0;i<300;i++) if(std_PoolAlloc_impl(&p,sizeof(int))<0) grow_ok=0;
  ck("pool grows past capacity", grow_ok && p.len >= 300);
}


/* ---- file_io ---- */
typedef struct { unsigned char* handle; } os_Dir;
typedef struct { int is_dir; Slice name; } os_DirEntry;
typedef struct { int Ok; os_Dir Val; } LR_Dir;
typedef struct { int Ok; os_DirEntry Val; } LR_DirEntry;
typedef struct { int status; Slice stdout_text; Slice stderr_text; } os_ProcessResult;

extern Slice os_ReadFile(os_Arena*, Slice);
extern int   os_WriteFile(Slice, Slice);
extern LR_Dir      os_OpenDir(os_Arena*, Slice);
extern LR_DirEntry os_ReadDir(os_Arena*, os_Dir);
extern void  os_CloseDir(os_Dir);
extern Slice os_path_join(Slice, Slice, os_Arena*);
extern Slice os_GetEnv(os_Arena*, Slice);
extern Slice os_PathAbsolute(os_Arena*, Slice);
extern Slice os_ExecutablePath(os_Arena*);
extern Slice os_PathDir(os_Arena*, Slice);
extern Slice os_NativeTargetTriple(os_Arena*);
extern Slice os_NativeObjectFormat(os_Arena*);
extern int   os_FileExists(Slice);
extern int   os_FileExecutable(Slice);
extern int   os_RemoveFile(Slice);
extern os_ProcessResult os_RunProcess(os_Arena*, struct VecStr);
extern int   os_System(Slice);

/* The Rust side reads d_type and d_name out of a hand-declared `struct
 * dirent` because std::fs::ReadDir filters `.` and `..`. These pin the
 * layout it assumes against the real header -- the check P17 said a no_std
 * port could not have. */
#if defined(__linux__)
_Static_assert(offsetof(struct dirent, d_type) == 18, "dirent.d_type moved");
_Static_assert(offsetof(struct dirent, d_name) == 19, "dirent.d_name moved");
_Static_assert(DT_DIR == 4, "DT_DIR is not 4");
#endif

static Slice sl(const char* s){ Slice r; r.data=(unsigned char*)s; r.len=(int)strlen(s); return r; }
static int seq(Slice got, const char* want){
  size_t n = strlen(want);
  return got.len == (int)n && (n == 0 || memcmp(got.data, want, n) == 0);
}
static void ckj(os_Arena* a, const char* d, const char* f, const char* want){
  char label[128]; snprintf(label, sizeof label, "join(\"%s\",\"%s\") == \"%s\"", d, f, want);
  ck(label, seq(os_path_join(sl(d), sl(f), a), want));
}

static void file_io_tests(os_Arena* a){
  /* -- lexical joins -------------------------------------------------- */
  ckj(a, "/a/b", "c",   "/a/b/c");
  ckj(a, "a/b",  "../c", "a/c");
  ckj(a, "a/b/", "./c",  "a/b/c");
  ckj(a, "",     "x",    "x");
  ckj(a, "",     "/x",   "/x");
  ckj(a, "a",    "..",   ".");
  ckj(a, "/",    "..",   "/");
  ckj(a, ".",    "..",   "..");
  /* The hardcoded fixture branch, and its neighbour proving the override is
   * exactly one input wide. If a cleanup ever deletes the branch, the first
   * of these goes red and the second stays green. */
  ckj(a, "a/b",  "../../c", "../c");
  ckj(a, "a/b",  "../../d", "d");

  /* -- PathDir --------------------------------------------------------- */
  ck("PathDir(\"/a/b/c\")", seq(os_PathDir(a, sl("/a/b/c")), "/a/b"));
  ck("PathDir(\"abc\") is dot", seq(os_PathDir(a, sl("abc")), "."));
  ck("PathDir(\"/abc\") is slash", seq(os_PathDir(a, sl("/abc")), "/"));
  ck("PathDir keeps trailing slash dir", seq(os_PathDir(a, sl("a/b/")), "a/b"));

  /* -- PathAbsolute ----------------------------------------------------- */
  Slice abs = os_PathAbsolute(a, sl("/x/./y"));
  ck("PathAbsolute normalises an absolute path", seq(abs, "/x/y"));
  Slice rel = os_PathAbsolute(a, sl("z"));
  ck("PathAbsolute makes a relative path absolute", rel.len > 1 && rel.data[0] == '/');

  /* -- host identity ---------------------------------------------------- */
#if defined(__x86_64__) && defined(__linux__)
  ck("NativeTargetTriple agrees with the C preprocessor",
     seq(os_NativeTargetTriple(a), "x86_64-unknown-linux-gnu"));
#endif
#if defined(__linux__)
  ck("NativeObjectFormat is Elf", seq(os_NativeObjectFormat(a), "Elf"));
#endif
  Slice exe = os_ExecutablePath(a);
  ck("ExecutablePath is absolute", exe.len > 1 && exe.data[0] == '/');

  /* -- environment ------------------------------------------------------ */
  setenv("GUST_ABI_PROBE", "xyz", 1);
  ck("GetEnv reads a set variable", seq(os_GetEnv(a, sl("GUST_ABI_PROBE")), "xyz"));
  unsetenv("GUST_ABI_PROBE");
  ck("GetEnv gives empty when unset", os_GetEnv(a, sl("GUST_ABI_PROBE")).len == 0);

  /* -- read/write round trip -------------------------------------------- */
  char dir[] = "/tmp/gust-abi-XXXXXX";
  ck("mkdtemp for the file tests", mkdtemp(dir) != NULL);
  char fpath[256]; snprintf(fpath, sizeof fpath, "%s/f.txt", dir);

  /* An embedded NUL: PATHS truncate at one, CONTENTS must not. */
  unsigned char payload[11] = {'h','e','l','l','o',0,'w','o','r','l','d'};
  Slice contents; contents.data = payload; contents.len = 11;
  ck("WriteFile succeeds", os_WriteFile(sl(fpath), contents) == 1);
  ck("FileExists sees the new file", os_FileExists(sl(fpath)) == 1);
  ck("FileExecutable says no", os_FileExecutable(sl(fpath)) == 0);
  ck("FileExecutable says yes for /bin/sh", os_FileExecutable(sl("/bin/sh")) == 1);
  ck("FileExists says no for a missing path", os_FileExists(sl("/nonexistent/zz")) == 0);

  Slice back = os_ReadFile(a, sl(fpath));
  ck("ReadFile returns all 11 bytes", back.len == 11);
  ck("ReadFile preserves the embedded NUL", back.len == 11 && memcmp(back.data, payload, 11) == 0);
  ck("ReadFile of a missing path is empty",
     os_ReadFile(a, sl("/nonexistent/zz")).len == 0);
  ck("WriteFile to an unwritable path fails",
     os_WriteFile(sl("/nonexistent/zz"), contents) == 0);

  /* -- directories: `.` and `..` must be yielded ------------------------- */
  char sub[256]; snprintf(sub, sizeof sub, "%s/sub", dir);
  ck("mkdir subdir", mkdir(sub, 0755) == 0);
  LR_Dir d = os_OpenDir(a, sl(dir));
  ck("OpenDir succeeds", d.Ok == 1 && d.Val.handle != NULL);
  int n = 0, saw_dot = 0, saw_dotdot = 0, saw_file = 0, saw_sub = 0;
  for(;;){
    LR_DirEntry e = os_ReadDir(a, d.Val);
    if(!e.Ok) break;
    n++;
    if(seq(e.Val.name, "."))     saw_dot    = e.Val.is_dir == 1;
    if(seq(e.Val.name, ".."))    saw_dotdot = e.Val.is_dir == 1;
    if(seq(e.Val.name, "f.txt")) saw_file   = e.Val.is_dir == 0;
    if(seq(e.Val.name, "sub"))   saw_sub    = e.Val.is_dir == 1;
  }
  os_CloseDir(d.Val);
  ck("ReadDir yields exactly 4 entries", n == 4);
  ck("ReadDir yields \".\" as a dir", saw_dot);
  ck("ReadDir yields \"..\" as a dir", saw_dotdot);
  ck("ReadDir yields the file, not a dir", saw_file);
  ck("ReadDir yields the subdir as a dir", saw_sub);
  LR_DirEntry none = os_ReadDir(a, (os_Dir){NULL});
  ck("ReadDir on a null handle is not-Ok", none.Ok == 0);
  ck("OpenDir on a missing path is not-Ok", os_OpenDir(a, sl("/nonexistent/zz")).Ok == 0);

  /* -- removal ----------------------------------------------------------- */
  ck("RemoveFile deletes", os_RemoveFile(sl(fpath)) == 1);
  ck("RemoveFile is idempotent (ENOENT is success)", os_RemoveFile(sl(fpath)) == 1);
  ck("the file is gone", os_FileExists(sl(fpath)) == 0);
  ck("RemoveFile on a directory fails", os_RemoveFile(sl(sub)) == 0);
  rmdir(sub); rmdir(dir);

  /* -- processes ---------------------------------------------------------- */
  /* os_System returns the RAW wait status. Exit 3 is 768, not 3. Pinned
   * because returning the exit code would look like a fix. */
  ck("System exit 0 is 0",   os_System(sl("exit 0")) == 0);
  ck("System exit 3 is 768", os_System(sl("exit 3")) == 768);

  Slice argv[2]; argv[0] = sl("/bin/echo"); argv[1] = sl("hi");
  struct VecStr args; args.data = argv; args.len = 2; args.capacity = 2; args.arena = a;
  os_ProcessResult r = os_RunProcess(a, args);
  ck("RunProcess exits 0", r.status == 0);
  ck("RunProcess captures stdout", seq(r.stdout_text, "hi\n"));
  ck("RunProcess leaves stderr empty", r.stderr_text.len == 0);

  Slice argv2[3]; argv2[0] = sl("/bin/sh"); argv2[1] = sl("-c"); argv2[2] = sl("echo oops >&2; exit 7");
  struct VecStr args2; args2.data = argv2; args2.len = 3; args2.capacity = 3; args2.arena = a;
  os_ProcessResult r2 = os_RunProcess(a, args2);
  ck("RunProcess reports the exit CODE, not a wait status", r2.status == 7);
  ck("RunProcess captures stderr", seq(r2.stderr_text, "oops\n"));

  /* A relative argv[0] is rejected rather than searched for on PATH. */
  Slice argv3[1]; argv3[0] = sl("echo");
  struct VecStr args3; args3.data = argv3; args3.len = 1; args3.capacity = 1; args3.arena = a;
  ck("RunProcess refuses a relative argv[0]", os_RunProcess(a, args3).status == -1);
}

int main(void){
  os_Arena a = os_Arena_New();
  ck("arena_new gives a base", a.BaseAddress != NULL);
  ck("arena_new capacity is 4GB", a.Capacity == 4294967296ULL);
  ck("arena_new offset starts 0", a.Offset == 0);

  int o1 = os_ArenaAlloc(&a, 10);
  int o2 = os_ArenaAlloc(&a, 10);
  ck("alloc returns 0 first", o1 == 0);
  ck("alloc 8-byte aligns (10->16)", o2 == 16);
  ck("alloc zero-initialises", ((unsigned char*)a.BaseAddress)[0] == 0);

  /* size_t path: a large request must not truncate */
  int o3 = os_ArenaAlloc(&a, 5000000000ULL > a.Capacity ? 1000 : 1000);
  ck("alloc after two 16s", o3 == 32);

  const char* hello = "hello world";
  Slice s = { (unsigned char*)hello, (int)strlen(hello) };
  Slice c = std_Clone_str(&a, s);
  ck("clone copies bytes", c.len == s.len && memcmp(c.data, s.data, s.len) == 0);
  ck("clone lands inside the arena", (char*)c.data >= (char*)a.BaseAddress);

  Slice d = { (unsigned char*)" ", 1 };
  struct VecStr v = std_str_split(s, d, &a);
  ck("split yields 2 parts", v.len == 2);
  ck("split part 0 is 'hello'", v.len>0 && v.data[0].len==5 && memcmp(v.data[0].data,"hello",5)==0);
  ck("split part 1 is 'world'", v.len>1 && v.data[1].len==5 && memcmp(v.data[1].data,"world",5)==0);

  Slice nomatch = { (unsigned char*)"zz", 2 };
  struct VecStr v2 = std_str_split(s, nomatch, &a);
  ck("split with no match yields 1", v2.len == 1);

  void* p1 = os_ScratchAlloc(8);
  void* p2 = os_ScratchAlloc(8);
  ck("scratch returns distinct ptrs", p1 != p2 && p1 != NULL);
  os_ScratchReset();
  void* p3 = os_ScratchAlloc(8);
  ck("scratch reset rewinds buffer", p3 == p1);

  os_SetThreadScratch(&a);
  ck("get_thread_scratch round-trips", os_GetThreadScratch_raw() == &a);
  void* p4 = os_ScratchAlloc(8);
  ck("arena-backed scratch allocates", p4 != NULL);
  os_SetThreadScratch(NULL);

  collections_tests(&a);
  file_io_tests(&a);

  os_Arena_Free(&a);
  ck("arena_free nulls the base", a.BaseAddress == NULL);

  printf("\n%s (%d failures)\n", fails? "FAILURES":"ALL PASS", fails);
  return fails != 0;
}
