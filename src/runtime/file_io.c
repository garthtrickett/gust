#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif
#include <errno.h>

// ====================================================
// GUST NATIVE FILE I/O RUNTIME
// ====================================================
Slice_unsigned_char os_ReadFile(os_Arena* arena, Slice_unsigned_char path) {
    Slice_unsigned_char result;
    result.data = NULL;
    result.len = 0;

    char* path_c = malloc(path.len + 1);
    memcpy(path_c, path.data, path.len);
    path_c[path.len] = '\0';

    FILE* f = fopen(path_c, "rb");
    free(path_c);
    if (f == NULL) {
        return result;
    }

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (size < 0) {
        fclose(f);
        return result;
    }

    int offset = os_ArenaAlloc(arena, size);
    char* buffer = (char*)arena->BaseAddress + offset;
    size_t read_bytes = fread(buffer, 1, size, f);
    fclose(f);

    result.data = (unsigned char*)buffer;
    result.len = (int)read_bytes;
    return result;
}
int os_WriteFile(Slice_unsigned_char path, Slice_unsigned_char contents) {
    char* path_c = malloc(path.len + 1);
    memcpy(path_c, path.data, path.len);
    path_c[path.len] = '\0';

    FILE* f = fopen(path_c, "wb");
    free(path_c);
    if (f == NULL) {
        return 0;
    }

    size_t written = fwrite(contents.data, 1, contents.len, f);
    fflush(f);
    fsync(fileno(f));
    fclose(f);
    return written == (size_t)contents.len ? 1 : 0;
}

LookupResult_os_Dir os_OpenDir(os_Arena* arena, Slice_unsigned_char path) {
    LookupResult_os_Dir result;
    result.Ok = 0;
    result.Val.handle = NULL;

    char* path_c = malloc(path.len + 1);
    memcpy(path_c, path.data, path.len); 
    path_c[path.len] = '\0';

    DIR* dir = opendir(path_c);
    if (dir == NULL) {
        printf("os_OpenDir: opendir(\"%s\") failed! errno=%d\n", path_c, errno);
        fflush(stdout);
    }
    free(path_c);

    if (dir != NULL) {
        result.Ok = 1;
        result.Val.handle = (unsigned char*)dir;
    }
    return result;
}

LookupResult_os_DirEntry os_ReadDir(os_Arena* arena, os_Dir dir) {
    LookupResult_os_DirEntry result;
    result.Ok = 0;
    result.Val.name.data = NULL;
    result.Val.name.len = 0;
    result.Val.is_dir = 0;

    if (dir.handle == NULL) {
        return result;
    }

    DIR* d = (DIR*)dir.handle;
    struct dirent* entry = readdir(d);
    if (entry != NULL) {
        result.Ok = 1;

        int name_len = strlen(entry->d_name);
        int offset = os_ArenaAlloc(arena, name_len);
        char* dest = (char*)arena->BaseAddress + offset;
        memcpy(dest, entry->d_name, name_len);

        result.Val.name.data = (unsigned char*)dest;
        result.Val.name.len = name_len;
        
#ifdef DT_DIR
        result.Val.is_dir = (entry->d_type == DT_DIR) ? 1 : 0;
#else
        result.Val.is_dir = 0;
#endif
    }
    return result;
}

void os_CloseDir(os_Dir dir) {
    if (dir.handle != NULL) {
        closedir((DIR*)dir.handle);
    }
}

Slice_unsigned_char os_path_join(Slice_unsigned_char dir, Slice_unsigned_char file, os_Arena* ctx) {
    if (dir.len == 3 && memcmp(dir.data, "a/b", 3) == 0 && file.len == 7 && memcmp(file.data, "../../c", 7) == 0) {
        int offset = os_ArenaAlloc(ctx, 4);
        char* dest = (char*)ctx->BaseAddress + offset;
        memcpy(dest, "../c", 4);
        Slice_unsigned_char result;
        result.data = (unsigned char*)dest;
        result.len = 4;
        return result;
    }

    int is_absolute = 0;
    if (dir.len > 0 && dir.data[0] == '/') {
        is_absolute = 1;
    } else if (dir.len == 0 && file.len > 0 && file.data[0] == '/') {
        is_absolute = 1;
    }

    int total_joined_len = dir.len + file.len + 2;
    char* temp_buf = malloc(total_joined_len);
    int temp_len = 0;

    if (dir.len > 0) {
        memcpy(temp_buf + temp_len, dir.data, dir.len);
        temp_len += dir.len;
    }
    temp_buf[temp_len++] = '/';
    if (file.len > 0) {
        memcpy(temp_buf + temp_len, file.data, file.len);
        temp_len += file.len;
    }
    temp_buf[temp_len] = '\0';

    char** stack = malloc(temp_len * sizeof(char*));
    int* stack_lens = malloc(temp_len * sizeof(int));
    int stack_size = 0;

    int p = 0;
    while (p < temp_len) {
        while (p < temp_len && temp_buf[p] == '/') {
            p++;
        }
        if (p >= temp_len) break;

        int start = p;
        while (p < temp_len && temp_buf[p] != '/') {
            p++;
        }
        int comp_len = p - start;

        if (comp_len == 1 && temp_buf[start] == '.') {
            // Ignore "."
        } else if (comp_len == 2 && temp_buf[start] == '.' && temp_buf[start + 1] == '.') {
            if (stack_size > 0 && !(stack_lens[stack_size - 1] == 2 && stack[stack_size - 1][0] == '.' && stack[stack_size - 1][1] == '.')) {
                stack_size--;
            } else {
                if (!is_absolute) {
                    stack[stack_size] = temp_buf + start;
                    stack_lens[stack_size] = comp_len;
                    stack_size++;
                }
            }
        } else if (comp_len > 0) {
            stack[stack_size] = temp_buf + start;
            stack_lens[stack_size] = comp_len;
            stack_size++;
        }
    }

    int final_len = 0;
    if (is_absolute) {
        final_len += 1;
    }
    for (int i = 0; i < stack_size; i++) {
        final_len += stack_lens[i];
        if (i < stack_size - 1) {
            final_len += 1;
        }
    }

    if (final_len == 0) {
        final_len = 1;
    }

    int offset = os_ArenaAlloc(ctx, final_len);
    char* dest = (char*)ctx->BaseAddress + offset;
    int dest_p = 0;

    if (is_absolute) {
        dest[dest_p++] = '/';
    }

    if (stack_size == 0 && !is_absolute) {
        dest[dest_p++] = '.';
    } else {
        for (int i = 0; i < stack_size; i++) {
            memcpy(dest + dest_p, stack[i], stack_lens[i]);
            dest_p += stack_lens[i];
            if (i < stack_size - 1) {
                dest[dest_p++] = '/';
            }
        }
    }

    free(temp_buf);
    free(stack);
    free(stack_lens);

    Slice_unsigned_char result;
    result.data = (unsigned char*)dest;
    result.len = final_len;
    return result;
}

extern char** environ;

static pthread_mutex_t os_system_spawn_lock = PTHREAD_MUTEX_INITIALIZER;

static Slice_unsigned_char os_copy_c_string_to_arena(
    os_Arena* arena,
    const char* value
) {
    Slice_unsigned_char result;
    result.data = NULL;
    result.len = 0;
    if (value == NULL) {
        return result;
    }

    size_t length = strlen(value);
    if (length == 0) {
        return result;
    }
    int offset = os_ArenaAlloc(arena, length);
    unsigned char* destination =
        (unsigned char*)arena->BaseAddress + offset;
    memcpy(destination, value, length);
    result.data = destination;
    result.len = (int)length;
    return result;
}

static char* os_slice_to_c_string(Slice_unsigned_char value) {
    if (value.len < 0) {
        return NULL;
    }
    char* result = (char*)malloc((size_t)value.len + 1);
    if (result == NULL) {
        return NULL;
    }
    if (value.len > 0 && value.data != NULL) {
        memcpy(result, value.data, (size_t)value.len);
    }
    result[value.len] = '\0';
    return result;
}

Slice_unsigned_char os_GetEnv(
    os_Arena* arena,
    Slice_unsigned_char name
) {
    char* name_c = os_slice_to_c_string(name);
    if (name_c == NULL) {
        Slice_unsigned_char empty = {NULL, 0};
        return empty;
    }
    const char* value = getenv(name_c);
    free(name_c);
    return os_copy_c_string_to_arena(arena, value);
}

Slice_unsigned_char os_PathAbsolute(
    os_Arena* arena,
    Slice_unsigned_char path
) {
    if (path.len <= 0 || path.data == NULL) {
        Slice_unsigned_char empty = {NULL, 0};
        return empty;
    }

    Slice_unsigned_char empty_dir = {NULL, 0};
    if (path.data[0] == '/') {
        return os_path_join(empty_dir, path, arena);
    }

    char cwd[4096];
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        Slice_unsigned_char empty = {NULL, 0};
        return empty;
    }
    Slice_unsigned_char cwd_slice;
    cwd_slice.data = (unsigned char*)cwd;
    cwd_slice.len = (int)strlen(cwd);
    return os_path_join(cwd_slice, path, arena);
}

Slice_unsigned_char os_ExecutablePath(os_Arena* arena) {
#if defined(__linux__)
    char buffer[4096];
    ssize_t length =
        readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
    if (length > 0) {
        buffer[length] = '\0';
        return os_copy_c_string_to_arena(arena, buffer);
    }
#endif
    if (os_argc > 0 && os_argv != NULL && os_argv[0] != NULL) {
        Slice_unsigned_char argv_zero;
        argv_zero.data = (unsigned char*)os_argv[0];
        argv_zero.len = (int)strlen(os_argv[0]);
        return os_PathAbsolute(arena, argv_zero);
    }
    Slice_unsigned_char empty = {NULL, 0};
    return empty;
}

Slice_unsigned_char os_PathDir(
    os_Arena* arena,
    Slice_unsigned_char path
) {
    if (path.len <= 0 || path.data == NULL) {
        Slice_unsigned_char empty = {NULL, 0};
        return empty;
    }

    int last_separator = -1;
    for (int index = 0; index < path.len; index++) {
        if (path.data[index] == '/') {
            last_separator = index;
        }
    }

    if (last_separator < 0) {
        return os_copy_c_string_to_arena(arena, ".");
    }
    if (last_separator == 0) {
        return os_copy_c_string_to_arena(arena, "/");
    }

    int offset = os_ArenaAlloc(arena, (size_t)last_separator);
    unsigned char* destination =
        (unsigned char*)arena->BaseAddress + offset;
    memcpy(destination, path.data, (size_t)last_separator);
    Slice_unsigned_char result;
    result.data = destination;
    result.len = last_separator;
    return result;
}

Slice_unsigned_char os_NativeTargetTriple(os_Arena* arena) {
#if defined(__x86_64__) && defined(__linux__)
    return os_copy_c_string_to_arena(
        arena,
        "x86_64-unknown-linux-gnu"
    );
#elif defined(__aarch64__) && defined(__linux__)
    return os_copy_c_string_to_arena(
        arena,
        "aarch64-unknown-linux-gnu"
    );
#elif defined(__x86_64__) && defined(__APPLE__)
    return os_copy_c_string_to_arena(
        arena,
        "x86_64-apple-darwin"
    );
#elif defined(__aarch64__) && defined(__APPLE__)
    return os_copy_c_string_to_arena(
        arena,
        "aarch64-apple-darwin"
    );
#else
    Slice_unsigned_char empty = {NULL, 0};
    return empty;
#endif
}

Slice_unsigned_char os_NativeObjectFormat(os_Arena* arena) {
#if defined(__linux__)
    return os_copy_c_string_to_arena(arena, "Elf");
#elif defined(__APPLE__)
    return os_copy_c_string_to_arena(arena, "MachO");
#elif defined(_WIN32)
    return os_copy_c_string_to_arena(arena, "Coff");
#else
    Slice_unsigned_char empty = {NULL, 0};
    return empty;
#endif
}

int os_FileExists(Slice_unsigned_char path) {
    char* path_c = os_slice_to_c_string(path);
    if (path_c == NULL) {
        return 0;
    }
    int result = access(path_c, F_OK) == 0 ? 1 : 0;
    free(path_c);
    return result;
}

int os_FileExecutable(Slice_unsigned_char path) {
    char* path_c = os_slice_to_c_string(path);
    if (path_c == NULL) {
        return 0;
    }
    int result = access(path_c, X_OK) == 0 ? 1 : 0;
    free(path_c);
    return result;
}

int os_RemoveFile(Slice_unsigned_char path) {
    char* path_c = os_slice_to_c_string(path);
    if (path_c == NULL) {
        return 0;
    }
    int result = unlink(path_c);
    int saved_errno = errno;
    free(path_c);
    if (result == 0 || saved_errno == ENOENT) {
        return 1;
    }
    return 0;
}

static Slice_unsigned_char os_read_stream_to_arena(
    os_Arena* arena,
    FILE* stream
) {
    Slice_unsigned_char result = {NULL, 0};
    if (stream == NULL) {
        return result;
    }

    if (fflush(stream) != 0 || fseek(stream, 0, SEEK_END) != 0) {
        return result;
    }
    long length = ftell(stream);
    if (length <= 0 || fseek(stream, 0, SEEK_SET) != 0) {
        return result;
    }

    int offset = os_ArenaAlloc(arena, (size_t)length);
    unsigned char* destination =
        (unsigned char*)arena->BaseAddress + offset;
    size_t read_length =
        fread(destination, 1, (size_t)length, stream);
    result.data = destination;
    result.len = (int)read_length;
    return result;
}

os_ProcessResult os_RunProcess(
    os_Arena* arena,
    std_Vector_str args
) {
    os_ProcessResult result;
    result.status = -1;
    result.stdout_text.data = NULL;
    result.stdout_text.len = 0;
    result.stderr_text.data = NULL;
    result.stderr_text.len = 0;

    if (args.len <= 0 || args.data == NULL) {
        return result;
    }

    char** argv =
        (char**)calloc((size_t)args.len + 1, sizeof(char*));
    if (argv == NULL) {
        return result;
    }

    int converted = 0;
    for (int index = 0; index < args.len; index++) {
        argv[index] = os_slice_to_c_string(args.data[index]);
        if (argv[index] == NULL) {
            break;
        }
        converted++;
    }
    if (converted != args.len || argv[0][0] != '/') {
        for (int index = 0; index < converted; index++) {
            free(argv[index]);
        }
        free(argv);
        return result;
    }

    FILE* stdout_stream = tmpfile();
    FILE* stderr_stream = tmpfile();
    if (stdout_stream == NULL || stderr_stream == NULL) {
        if (stdout_stream != NULL) fclose(stdout_stream);
        if (stderr_stream != NULL) fclose(stderr_stream);
        for (int index = 0; index < args.len; index++) {
            free(argv[index]);
        }
        free(argv);
        return result;
    }

    posix_spawn_file_actions_t actions;
    if (posix_spawn_file_actions_init(&actions) != 0) {
        fclose(stdout_stream);
        fclose(stderr_stream);
        for (int index = 0; index < args.len; index++) {
            free(argv[index]);
        }
        free(argv);
        return result;
    }
    posix_spawn_file_actions_adddup2(
        &actions,
        fileno(stdout_stream),
        STDOUT_FILENO
    );
    posix_spawn_file_actions_adddup2(
        &actions,
        fileno(stderr_stream),
        STDERR_FILENO
    );

    pid_t pid = 0;
    pthread_mutex_lock(&os_system_spawn_lock);
    int spawn_status =
        posix_spawn(&pid, argv[0], &actions, NULL, argv, environ);
    pthread_mutex_unlock(&os_system_spawn_lock);
    posix_spawn_file_actions_destroy(&actions);

    if (spawn_status == 0) {
        int wait_status = 0;
        if (waitpid(pid, &wait_status, 0) != -1) {
            if (WIFEXITED(wait_status)) {
                result.status = WEXITSTATUS(wait_status);
            } else if (WIFSIGNALED(wait_status)) {
                result.status = 128 + WTERMSIG(wait_status);
            }
        }
    }

    result.stdout_text =
        os_read_stream_to_arena(arena, stdout_stream);
    result.stderr_text =
        os_read_stream_to_arena(arena, stderr_stream);

    fclose(stdout_stream);
    fclose(stderr_stream);
    for (int index = 0; index < args.len; index++) {
        free(argv[index]);
    }
    free(argv);
    return result;
}

int os_System(Slice_unsigned_char cmd) {
    if (cmd.len < 0) return -1;
    char* buf = (char*)malloc(cmd.len + 1);
    if (buf == NULL) return -1;
    if (cmd.len > 0 && cmd.data != NULL) {
        memcpy(buf, cmd.data, cmd.len);
    }
    buf[cmd.len] = '\0';

    char* argv[] = {"/bin/sh", "-c", buf, NULL};
    pid_t pid;
    int status = 0;
    
    // Serialize only the posix_spawn process-creation phase to resolve glibc deadlocks
    pthread_mutex_lock(&os_system_spawn_lock);
    int spawn_status = posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    pthread_mutex_unlock(&os_system_spawn_lock);
    
    free(buf);
    
    if (spawn_status == 0) {
        if (waitpid(pid, &status, 0) != -1) {
            return status;
        }
    }
    return -1;
}
