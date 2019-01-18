#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <dirent.h>
#include <limits.h>
#include <pthread.h>
#include <errno.h>
#include <time.h>

#include <JavaScriptCore/JavaScript.h>

#include "bundle.h"
#include "io.h"
#include "jsc_utils.h"
#include "file.h"

#define CONSOLE_LOG_BUF_SIZE 1000
char console_log_buf[CONSOLE_LOG_BUF_SIZE];

static const char* root_directory;

void set_root_directory(const char* path) {
    root_directory = path;
}

static char sandbox_path_buffer[FILENAME_MAX];
static char unsandbox_path_buffer[FILENAME_MAX];

const char* sandbox(const char* path) {
    sprintf((char*)sandbox_path_buffer, "%s%s", root_directory, path);
    return (const char*)sandbox_path_buffer;
}

const char* unsandbox(const char* path) {
    return path + strlen(root_directory);
}

JSValueRef function_console_stdout(JSContextRef ctx, JSObjectRef function, JSObjectRef this_object,
                                   size_t argc, JSValueRef const *args, JSValueRef *exception) {
    int i;
    for (i = 0; i < argc; i++) {
        if (i > 0) {
            fprintf(stdout, " ");
        }
        
        JSStringRef str = to_string(ctx, args[i]);
        JSStringGetUTF8CString(str, console_log_buf, CONSOLE_LOG_BUF_SIZE);
        fprintf(stdout, "%s", console_log_buf);
    }
    fprintf(stdout, "\n");
    
    return JSValueMakeUndefined(ctx);
}

JSValueRef function_console_stderr(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                   size_t argc, JSValueRef const *args, JSValueRef *exception) {
    int i;
    for (i = 0; i < argc; i++) {
        if (i > 0) {
            fprintf(stderr, " ");
        }
        
        JSStringRef str = to_string(ctx, args[i]);
        JSStringGetUTF8CString(str, console_log_buf, CONSOLE_LOG_BUF_SIZE);
        fprintf(stderr, "%s", console_log_buf);
    }
    fprintf(stderr, "\n");
    
    return JSValueMakeUndefined(ctx);
}

JSValueRef function_read_file(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                              size_t argc, const JSValueRef args[], JSValueRef *exception) {
    // TODO: implement fully
    
    if (argc == 1 && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        char path[PATH_MAX];
        JSStringRef path_str = JSValueToStringCopy(ctx, args[0], NULL);
        assert(JSStringGetLength(path_str) < PATH_MAX);
        JSStringGetUTF8CString(path_str, path, PATH_MAX);
        JSStringRelease(path_str);
        
        // debug_print_value("read_file", ctx, args[0]);
        
        time_t last_modified = 0;
        char *contents = get_contents(path, &last_modified);
        if (contents != NULL) {
            JSStringRef contents_str = JSStringCreateWithUTF8CString(contents);
            free(contents);
            
            JSValueRef res[2];
            res[0] = JSValueMakeString(ctx, contents_str);
            res[1] = JSValueMakeNumber(ctx, last_modified);
            return JSObjectMakeArray(ctx, 2, res, NULL);
        }
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_eval(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                         size_t argc, const JSValueRef args[], JSValueRef *exception) {
    JSValueRef val = NULL;
    
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeString
        && JSValueGetType(ctx, args[1]) == kJSTypeString) {
        // debug_print_value("eval", ctx, args[0]);
        
        JSStringRef sourceRef = JSValueToStringCopy(ctx, args[0], NULL);
        JSStringRef pathRef = JSValueToStringCopy(ctx, args[1], NULL);
        
        JSEvaluateScript(ctx, sourceRef, NULL, pathRef, 0, &val);
        
        JSStringRelease(pathRef);
        JSStringRelease(sourceRef);
    }
    
    return val != NULL ? val : JSValueMakeNull(ctx);
}

JSValueRef function_raw_write_stdout(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1 && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        char *s = value_to_c_string(ctx, args[0]);
        fprintf(stdout, "%s", s);
        free(s);
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_raw_flush_stdout(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    fflush(stdout);
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_raw_write_stderr(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1 && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        char *s = value_to_c_string(ctx, args[0]);
        fprintf(stderr, "%s", s);
        free(s);
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_raw_flush_stderr(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    fflush(stderr);
    
    return JSValueMakeNull(ctx);
}


#ifdef DEFHASHFNS
unsigned long hash(unsigned char *str) {
    unsigned long hash = 5381;
    int c;
    
    while ((c = *str++))
        hash = ((hash << 5) + hash) + c; /* hash * 33 + c */
    
    return hash;
}

static unsigned long loaded_goog_hashes[2048];
static size_t count_loaded_goog_hashes = 0;

bool is_loaded(unsigned long h) {
    size_t i;
    for (i = 0; i < count_loaded_goog_hashes; ++i) {
        if (loaded_goog_hashes[i] == h) {
            return true;
        }
    }
    return false;
}

void add_loaded_hash(unsigned long h) {
    if (count_loaded_goog_hashes < 2048) {
        loaded_goog_hashes[count_loaded_goog_hashes++] = h;
    }
}
#endif

descriptor_t descriptor_str_to_int(const char *s) {
    return (descriptor_t) atoll(s);
}

char *descriptor_int_to_str(descriptor_t i) {
    char *rv = malloc(21);
    sprintf(rv, "%llu", (unsigned long long) i);
    return rv;
}

JSValueRef function_file_reader_open(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *path = value_to_c_string(ctx, args[0]);
        char *encoding = value_to_c_string(ctx, args[1]);
        
        descriptor_t descriptor = ufile_open_read(sandbox(path), encoding);
        
        free(path);
        free(encoding);
        
        char *descriptor_str = descriptor_int_to_str(descriptor);
        JSValueRef rv = c_string_to_value(ctx, descriptor_str);
        free(descriptor_str);
        
        return rv;
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_reader_read(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        
        JSStringRef result = ufile_read(descriptor_str_to_int(descriptor));
        
        free(descriptor);
        
        JSValueRef arguments[2];
        if (result != NULL) {
            arguments[0] = JSValueMakeString(ctx, result);
            JSStringRelease(result);
        } else {
            arguments[0] = JSValueMakeNull(ctx);
        }
        arguments[1] = JSValueMakeNull(ctx);
        return JSObjectMakeArray(ctx, 2, arguments, NULL);
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_reader_close(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                      size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        ufile_close(descriptor_str_to_int(descriptor));
        free(descriptor);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_writer_open(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                     size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 3
        && JSValueGetType(ctx, args[0]) == kJSTypeString
        && JSValueGetType(ctx, args[1]) == kJSTypeBoolean) {
        
        char *path = value_to_c_string(ctx, args[0]);
        bool append = JSValueToBoolean(ctx, args[1]);
        char *encoding = value_to_c_string(ctx, args[2]);
        
        uint64_t descriptor = ufile_open_write(sandbox(path), append, encoding);
        
        free(path);
        free(encoding);
        
        char *descriptor_str = descriptor_int_to_str(descriptor);
        JSValueRef rv = c_string_to_value(ctx, descriptor_str);
        free(descriptor_str);
        
        return rv;
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_writer_write(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                      size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeString
        && JSValueGetType(ctx, args[1]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        JSStringRef str_ref = JSValueToStringCopy(ctx, args[1], NULL);
        
        ufile_write(descriptor_str_to_int(descriptor), str_ref);
        
        free(descriptor);
        JSStringRelease(str_ref);
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_writer_flush(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                      size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        ufile_flush(descriptor_str_to_int(descriptor));
        free(descriptor);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_writer_close(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                      size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        ufile_close(descriptor_str_to_int(descriptor));
        free(descriptor);
    }
    return JSValueMakeNull(ctx);
}


JSValueRef function_file_input_stream_open(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                           size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *path = value_to_c_string(ctx, args[0]);
        
        uint64_t descriptor = file_open_read(sandbox(path));
        
        free(path);
        
        char *descriptor_str = descriptor_int_to_str(descriptor);
        JSValueRef rv = c_string_to_value(ctx, descriptor_str);
        free(descriptor_str);
        
        return rv;
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_input_stream_read(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                           size_t argc, const JSValueRef args[], JSValueRef *exception) {
    
    static JSValueRef *charmap = NULL;
    if (!charmap) {
        charmap = malloc(256 * sizeof (JSValueRef));
        int i;
        for (i = 0; i < 256; i++) {
            charmap[i] = JSValueMakeNumber(ctx, i);
            JSValueProtect(ctx, charmap[i]);
        }
    }
    
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        
        size_t buf_size = 4096;
        uint8_t *buf = malloc(buf_size * sizeof(uint8_t));
        
        size_t read = file_read(descriptor_str_to_int(descriptor), buf_size, buf);
        
        free(descriptor);
        
        if (read) {
            // TODO distinguish between eof and error down in fread call and throw if errro
            JSValueRef arguments[read];
            int num_arguments = (int) read;
            int i;
            for (i = 0; i < num_arguments; i++) {
                arguments[i] = charmap[buf[i]];
            }
            
            return JSObjectMakeArray(ctx, num_arguments, arguments, NULL);
        }
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_input_stream_close(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                            size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        file_close(descriptor_str_to_int(descriptor));
        free(descriptor);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_output_stream_open(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                            size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeString
        && JSValueGetType(ctx, args[1]) == kJSTypeBoolean) {
        
        char *path = value_to_c_string(ctx, args[0]);
        bool append = JSValueToBoolean(ctx, args[1]);
        
        uint64_t descriptor = file_open_write(sandbox(path), append);
        
        free(path);
        
        char *descriptor_str = descriptor_int_to_str(descriptor);
        JSValueRef rv = c_string_to_value(ctx, descriptor_str);
        free(descriptor_str);
        
        return rv;
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_output_stream_write(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                             size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeString
        && JSValueGetType(ctx, args[1]) == kJSTypeObject) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        
        unsigned int count = (unsigned int) array_get_count(ctx, (JSObjectRef) args[1]);
        uint8_t buf[count];
        unsigned int i;
        for (i = 0; i < count; i++) {
            JSValueRef v = array_get_value_at_index(ctx, (JSObjectRef) args[1], i);
            if (JSValueIsNumber(ctx, v)) {
                double n = JSValueToNumber(ctx, v, NULL);
                if (0 <= n && n <= 255) {
                    buf[i] = (uint8_t) n;
                } else {
                    fprintf(stderr, "Output stream value out of range %f", n);
                }
            } else {
                fprintf(stderr, "Output stream value not a number");
            }
        }
        
        file_write(descriptor_str_to_int(descriptor), count, buf);
        
        free(descriptor);
    }
    
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_output_stream_flush(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                             size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        file_flush(descriptor_str_to_int(descriptor));
        free(descriptor);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_file_output_stream_close(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                             size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *descriptor = value_to_c_string(ctx, args[0]);
        file_close(descriptor_str_to_int(descriptor));
        free(descriptor);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_mkdirs(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                           size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        char *path = value_to_c_string(ctx, args[0]);
        int rv = mkdir_parents(sandbox(path));
        free(path);
        
        if (rv == -1) {
            return JSValueMakeBoolean(ctx, false);
        }
    }
    return JSValueMakeBoolean(ctx, true);
}

JSValueRef function_delete_file(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *path = value_to_c_string(ctx, args[0]);
        remove(sandbox(path));
        free(path);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_copy_file(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                              size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeString
        && JSValueGetType(ctx, args[1]) == kJSTypeString) {
        
        char *src = value_to_c_string(ctx, args[0]);
        char *dst = value_to_c_string(ctx, args[1]);
        
        char *sandboxed_src = strdup(sandbox(src));
        char *sandboxed_dst = strdup(sandbox(dst));
        
        int rv = copy_file(sandboxed_src, sandboxed_dst);
        if (rv) {
            JSValueRef arguments[1];
            arguments[0] = c_string_to_value(ctx, strerror(errno));
            *exception = JSObjectMakeError(ctx, 1, arguments, NULL);
        }
        
        free(sandboxed_src);
        free(sandboxed_dst);
        free(src);
        free(dst);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_list_files(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                               size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *path = value_to_c_string(ctx, args[0]);
        char *sandboxed_path = strdup(sandbox(path));
        
        size_t capacity = 32;
        size_t count = 0;
        
        JSValueRef *paths = malloc(capacity * sizeof(JSValueRef));
        
        DIR *d = opendir(sandboxed_path);
        
        if (d) {
            size_t path_len = strlen(sandboxed_path);
            if (path_len && sandboxed_path[path_len - 1] == '/') {
                sandboxed_path[--path_len] = 0;
            }
            
            struct dirent *dir;
            while ((dir = readdir(d)) != NULL) {
                if (strcmp(dir->d_name, ".") && strcmp(dir->d_name, "..")) {
                    
                    size_t buf_len = path_len + strlen(dir->d_name) + 2;
                    char *buf = malloc(buf_len);
                    snprintf(buf, buf_len, "%s/%s", sandboxed_path, dir->d_name);
                    JSValueRef path_ref = c_string_to_value(ctx, unsandbox(buf));
                    paths[count++] = path_ref;
                    JSValueProtect(ctx, path_ref);
                    free(buf);
                    
                    if (count == capacity) {
                        capacity *= 2;
                        paths = realloc(paths, capacity * sizeof(JSValueRef));
                    }
                }
            }
            
            closedir(d);
        }
        
        JSValueRef rv = JSObjectMakeArray(ctx, count, paths, NULL);
        
        size_t i = 0;
        for (i=0; i<count; ++i) {
            JSValueUnprotect(ctx, paths[i]);
        }
        
        free(sandboxed_path);
        free(path);
        free(paths);
        
        return rv;
    }
    return JSValueMakeNull(ctx);
}


JSValueRef function_is_directory(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                 size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *path = value_to_c_string(ctx, args[0]);
        
        bool is_directory = false;
        
        struct stat file_stat;
        
        int retval = stat(sandbox(path), &file_stat);
        
        free(path);
        
        if (retval == 0) {
            is_directory = S_ISDIR(file_stat.st_mode);
        }
        
        return JSValueMakeBoolean(ctx, is_directory);
        
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_fstat(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                          size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *path = value_to_c_string(ctx, args[0]);
        
        struct stat file_stat;
        
        int retval = lstat(sandbox(path), &file_stat);
        
        if (retval == 0) {
            JSObjectRef result = JSObjectMake(ctx, NULL, NULL);
            
            char *type = "unknown";
            if (S_ISDIR(file_stat.st_mode)) {
                type = "directory";
            } else if (S_ISREG(file_stat.st_mode)) {
                type = "file";
            } else if (S_ISLNK(file_stat.st_mode)) {
                type = "symbolic-link";
            } else if (S_ISSOCK(file_stat.st_mode)) {
                type = "socket";
            } else if (S_ISFIFO(file_stat.st_mode)) {
                type = "fifo";
            } else if (S_ISCHR(file_stat.st_mode)) {
                type = "character-special";
            } else if (S_ISBLK(file_stat.st_mode)) {
                type = "block-special";
            }
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("type"),
                                c_string_to_value(ctx, type),
                                kJSPropertyAttributeReadOnly, NULL);
            
            
            double device_id = (double) file_stat.st_rdev;
            if (device_id) {
                JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("device-id"),
                                    JSValueMakeNumber(ctx, device_id),
                                    kJSPropertyAttributeReadOnly, NULL);
            }
            
            double file_number = (double) file_stat.st_ino;
            if (file_number) {
                JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("file-number"),
                                    JSValueMakeNumber(ctx, file_number),
                                    kJSPropertyAttributeReadOnly, NULL);
            }
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("permissions"),
                                JSValueMakeNumber(ctx, (double) (ACCESSPERMS & file_stat.st_mode)),
                                kJSPropertyAttributeReadOnly, NULL);
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("reference-count"),
                                JSValueMakeNumber(ctx, (double) file_stat.st_nlink),
                                kJSPropertyAttributeReadOnly, NULL);
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("uid"),
                                JSValueMakeNumber(ctx, (double) file_stat.st_uid),
                                kJSPropertyAttributeReadOnly, NULL);
            
            struct passwd *uid_passwd = getpwuid(file_stat.st_uid);
            
            if (uid_passwd) {
                JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("uname"),
                                    c_string_to_value(ctx, uid_passwd->pw_name),
                                    kJSPropertyAttributeReadOnly, NULL);
            }
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("gid"),
                                JSValueMakeNumber(ctx, (double) file_stat.st_gid),
                                kJSPropertyAttributeReadOnly, NULL);
            
            struct group *gid_group = getgrgid(file_stat.st_gid);
            
            if (gid_group) {
                JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("gname"),
                                    c_string_to_value(ctx, gid_group->gr_name),
                                    kJSPropertyAttributeReadOnly, NULL);
            }
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("file-size"),
                                JSValueMakeNumber(ctx, (double) file_stat.st_size),
                                kJSPropertyAttributeReadOnly, NULL);
            
#ifdef __APPLE__
#define birthtime(x) x.st_birthtime
#else
#define birthtime(x) x.st_ctime
#endif
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("created"),
                                JSValueMakeNumber(ctx, 1000 * birthtime(file_stat)),
                                kJSPropertyAttributeReadOnly, NULL);
            
            JSObjectSetProperty(ctx, result, JSStringCreateWithUTF8CString("modified"),
                                JSValueMakeNumber(ctx, 1000 * file_stat.st_mtime),
                                kJSPropertyAttributeReadOnly, NULL);
            
            return result;
        }
        
        free(path);
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_read_password(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                  size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        
        char *prompt = value_to_c_string(ctx, args[0]);
        
        char *pass = getpass(prompt);
        
        JSValueRef rv;
        
        if (pass) {
            rv = c_string_to_value(ctx, pass);
            memset(pass, 0, strlen(pass));
        } else {
            rv = JSValueMakeNull(ctx);
        }
        
        free(prompt);
        return rv;
    }
    return JSValueMakeNull(ctx);
}

JSValueRef function_sleep(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                          size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeNumber
        && JSValueGetType(ctx, args[1]) == kJSTypeNumber) {
        
        int millis = (int) JSValueToNumber(ctx, args[0], NULL);
        int nanos = (int) JSValueToNumber(ctx, args[1], NULL);
        
        struct timespec t;
        t.tv_sec = millis / 1000;
        t.tv_nsec = 1000 * 1000 * (millis % 1000) + nanos;
        
        if (t.tv_sec != 0 || t.tv_nsec != 0) {
            int err = nanosleep(&t, NULL);
            if (err) {
                //engine_perror("sleep");
            }
        }
    }
    return JSValueMakeNull(ctx);
}
