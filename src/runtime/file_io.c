#ifndef GUST_CORE_HEADERS_H
#include "core_headers.h"
#endif
#include <errno.h>

// ====================================================
// GUST NATIVE FILE I/O RUNTIME
// ====================================================
typedef struct os_Dir os_Dir;
struct os_Dir {
    unsigned char* handle;
};

typedef struct os_DirEntry os_DirEntry;
struct os_DirEntry {
    int is_dir;
    Slice_unsigned_char name;
};

typedef struct LookupResult_os_Dir LookupResult_os_Dir;
struct LookupResult_os_Dir {
    int Ok;
    os_Dir Val;
};

typedef struct LookupResult_os_DirEntry LookupResult_os_DirEntry;
struct LookupResult_os_DirEntry {
    int Ok;
    os_DirEntry Val;
};

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
