#include <JavaScriptCore/JavaScript.h>

void set_ca_root_path(const char* path);

JSValueRef function_http_request(JSContextRef ctx, JSObjectRef function, JSObjectRef this_object,
                                 size_t argc, const JSValueRef args[], JSValueRef *exception);
