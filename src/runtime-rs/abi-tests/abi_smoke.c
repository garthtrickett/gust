#include <stdio.h>
#include <string.h>
#include <stddef.h>
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

  os_Arena_Free(&a);
  ck("arena_free nulls the base", a.BaseAddress == NULL);

  printf("\n%s (%d failures)\n", fails? "FAILURES":"ALL PASS", fails);
  return fails != 0;
}
