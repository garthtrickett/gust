// Transpiled C Code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

typedef void Any;

/* Builtin slice structs are runtime-owned in src/runtime/core_headers.h. */

// Forward Declarations
typedef struct APIRequest APIRequest;
typedef struct SessionNode SessionNode;
typedef struct CastResult_APIRequest CastResult_APIRequest;
typedef struct CastResult_SessionNode CastResult_SessionNode;

// Function Forward Declarations
os_Arena os_Arena_New(void);
void os_SetThreadScratch(os_Arena* arg0);
int os_System(Slice_unsigned_char arg0);
os_Arena os_Arena_New(void);
os_Arena os_Arena_New(void);
void os_SetThreadScratch(os_Arena* arg0);
int os_System(Slice_unsigned_char arg0);
void std_Yield(void);
void std_Yield(void);

// Structures
struct APIRequest {
    int Active;
    int SessionID;
    int UserID;
};

struct SessionNode {
    int Next;
    int SessionID;
};

// pthread_wrapper forward declarations

// Invariant Validator forward declarations

// Invariant Validator implementations
// Program Statements
static int gust_user_exit_status = 0;

int gust_user_main_impl(void* _gust_arg) {
    int trusted_scope_shape = 7;
    int row_workspace_shape = 7;
    if ((row_workspace_shape == trusted_scope_shape)) {
    return 21;
    }
    return 1;
}

void gust_user_main(void* _gust_arg) {
    gust_user_exit_status = (int)gust_user_main_impl(_gust_arg);
}

int main(int argc, char** argv) {
    os_argc = argc;
    os_argv = argv;
    gust_scheduler_init(get_num_threads_to_use());
    gust_scheduler_spawn(8388608, gust_user_main, NULL);
    gust_scheduler_destroy();
    return gust_user_exit_status;
}
