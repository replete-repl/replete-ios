//
//  AppDelegate.m
//  Replete
//
//  Created by Mike Fikes on 6/27/15.
//  Copyright (c) 2015 FikesFarm. All rights reserved.
//

#include <pthread.h>

#import "AppDelegate.h"
#include <Foundation/Foundation.h>
#include <JavaScriptCore/JavaScriptCore.h>
#include <mach/mach_time.h>
#include "bundle.h"


@interface AppDelegate ()

@property (assign, nonatomic) JSContext* context;
@property (strong, nonatomic) JSValue* readEvalPrintFn;
@property (strong, nonatomic) JSValue* chivorcamReferred;
@property (strong, nonatomic) JSValue* formatFn;
@property (strong, nonatomic) JSValue* setWidthFn;
@property (nonatomic, copy) void (^myPrintCallback)(BOOL, NSString*);
@property BOOL initialized;
@property BOOL consentedToChivorcam;
@property BOOL suppressPrinting;
@property NSString *codeToBeEvaluatedWhenReady;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDidChangeStatusBarOrientationNotification:)
                                                 name:UIApplicationDidChangeStatusBarOrientationNotification
                                               object:nil];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

JSValueRef evaluate_script(JSContextRef ctx, char *script, char *source) {
    JSStringRef script_ref = JSStringCreateWithUTF8CString(script);
    JSStringRef source_ref = NULL;
    if (source != NULL) {
        source_ref = JSStringCreateWithUTF8CString(source);
    }
    
    JSValueRef ex = NULL;
    JSValueRef val = JSEvaluateScript(ctx, script_ref, NULL, source_ref, 0, &ex);
    JSStringRelease(script_ref);
    if (source != NULL) {
        JSStringRelease(source_ref);
    }
    
    // debug_print_value("evaluate_script", ctx, ex);
    
    return val;
}

void register_global_function(JSContextRef ctx, char *name, JSObjectCallAsFunctionCallback handler) {
    JSObjectRef global_obj = JSContextGetGlobalObject(ctx);
    
    JSStringRef fn_name = JSStringCreateWithUTF8CString(name);
    JSObjectRef fn_obj = JSObjectMakeFunctionWithCallback(ctx, fn_name, handler);
    
    JSObjectSetProperty(ctx, global_obj, fn_name, fn_obj, kJSPropertyAttributeNone, NULL);
}

int str_has_prefix(const char *str, const char *prefix) {
    size_t len = strlen(str);
    size_t prefix_len = strlen(prefix);
    
    if (len < prefix_len) {
        return -1;
    }
    
    return strncmp(str, prefix, prefix_len);
}

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

JSGlobalContextRef ctx = NULL;

JSValueRef function_import_script(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                  size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1 && JSValueGetType(ctx, args[0]) == kJSTypeString) {
        JSStringRef path_str_ref = JSValueToStringCopy(ctx, args[0], NULL);
        assert(JSStringGetLength(path_str_ref) < PATH_MAX);
        char tmp[PATH_MAX];
        tmp[0] = '\0';
        JSStringGetUTF8CString(path_str_ref, tmp, PATH_MAX);
        JSStringRelease(path_str_ref);
        
        bool can_skip_load = false;
        char *path = tmp;
        if (str_has_prefix(path, "goog/../") == 0) {
            path = path + 8;
        } else {
            unsigned long h = hash((unsigned char *) path);
            if (is_loaded(h)) {
                can_skip_load = true;
            } else {
                add_loaded_hash(h);
            }
        }
        
        if (!can_skip_load) {
            char *source = bundle_get_contents(path);
            if (source != NULL) {
                evaluate_script(ctx, source, path);
                free(source);
            } else {
                NSLog(@"Failed to get source for %s", path);
            }
        }
    }
    
    return JSValueMakeUndefined(ctx);
}

pthread_mutex_t eval_lock = PTHREAD_MUTEX_INITIALIZER;

void acquire_eval_lock() {
    pthread_mutex_lock(&eval_lock);
}

void release_eval_lock() {
    pthread_mutex_unlock(&eval_lock);
}


char *munge(char *s) {
    size_t len = strlen(s);
    size_t new_len = 0;
    int i;
    for (i = 0; i < len; i++) {
        switch (s[i]) {
            case '!':
                new_len += 6; // _BANG_
                break;
            case '?':
                new_len += 7; // _QMARK_
                break;
            default:
                new_len += 1;
        }
    }
    
    char *ms = malloc((new_len + 1) * sizeof(char));
    int j = 0;
    for (i = 0; i < len; i++) {
        switch (s[i]) {
            case '-':
                ms[j++] = '_';
                break;
            case '!':
                ms[j++] = '_';
                ms[j++] = 'B';
                ms[j++] = 'A';
                ms[j++] = 'N';
                ms[j++] = 'G';
                ms[j++] = '_';
                break;
            case '?':
                ms[j++] = '_';
                ms[j++] = 'Q';
                ms[j++] = 'M';
                ms[j++] = 'A';
                ms[j++] = 'R';
                ms[j++] = 'K';
                ms[j++] = '_';
                break;
                
            default:
                ms[j++] = s[i];
        }
    }
    ms[new_len] = '\0';
    
    return ms;
}

JSValueRef get_value_on_object(JSContextRef ctx, JSObjectRef obj, char *name) {
    JSStringRef name_str = JSStringCreateWithUTF8CString(name);
    JSValueRef val = JSObjectGetProperty(ctx, obj, name_str, NULL);
    JSStringRelease(name_str);
    return val;
}

JSValueRef get_value(JSContextRef ctx, char *namespace, char *name) {
    JSValueRef ns_val = NULL;
    
    // printf("get_value: '%s'\n", namespace);
    char *ns_tmp = strdup(namespace);
    char *saveptr;
    char *ns_part = strtok_r(ns_tmp, ".", &saveptr);
    while (ns_part != NULL) {
        char *munged_ns_part = munge(ns_part);
        if (ns_val) {
            ns_val = get_value_on_object(ctx, JSValueToObject(ctx, ns_val, NULL), munged_ns_part);
        } else {
            ns_val = get_value_on_object(ctx, JSContextGetGlobalObject(ctx), munged_ns_part);
        }
        free(munged_ns_part); // TODO: Use a fixed buffer for this?  (Which would restrict namespace part length...)
        
        ns_part = strtok_r(NULL, ".", &saveptr);
    }
    free(ns_tmp);
    
    char *munged_name = munge(name);
    JSValueRef val = get_value_on_object(ctx, JSValueToObject(ctx, ns_val, NULL), munged_name);
    free(munged_name);
    return val;
}

JSObjectRef get_function(char *namespace, char *name) {
    JSValueRef val = get_value(ctx, namespace, name);
    if (JSValueIsUndefined(ctx, val)) {
        char buffer[1024];
        snprintf(buffer, 1024, "Failed to get function %s/%s\n", namespace, name);
        //engine_print(buffer);
        assert(false);
    }
    return JSValueToObject(ctx, val, NULL);
}

typedef void (*timer_callback_t)(void *data);

struct timer_data_t {
    long millis;
    timer_callback_t timer_callback;
    void *data;
};

void *timer_thread(void *data) {
    
    struct timer_data_t *timer_data = data;
    
    struct timespec t;
    t.tv_sec = timer_data->millis / 1000;
    t.tv_nsec = 1000 * 1000 * (timer_data->millis % 1000);
    if (t.tv_sec == 0 && t.tv_nsec == 0) {
        t.tv_nsec = 1; /* Evidently needed on Ubuntu 14.04 */
    }
    
    int err = nanosleep(&t, NULL);
    if (err) {
        free(data);
        //engine_perror("timer nanosleep");
        return NULL;
    }
    
    timer_data->timer_callback(timer_data->data);
    
    free(data);
    
    return NULL;
}

int start_timer(long millis, timer_callback_t timer_callback, void *data) {
    
    struct timer_data_t *timer_data = malloc(sizeof(struct timer_data_t));
    if (!timer_data) return -1;
    
    timer_data->millis = millis;
    timer_data->timer_callback = timer_callback;
    timer_data->data = data;
    
    pthread_attr_t attr;
    int err = pthread_attr_init(&attr);
    if (err) {
        free(timer_data);
        return err;
    }
    
    err = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    if (err) {
        free(timer_data);
        return err;
    }
    
    pthread_t thread;
    err = pthread_create(&thread, &attr, timer_thread, timer_data);
    if (err) {
        free(timer_data);
    }
    return err;
}

void do_run_timeout(void *data) {
    
    unsigned long *timeout_data = data;
    
    JSValueRef args[1];
    args[0] = JSValueMakeNumber(ctx, (double)*timeout_data);
    free(timeout_data);
    
    static JSObjectRef run_timeout_fn = NULL;
    if (!run_timeout_fn) {
        run_timeout_fn = get_function("global", "REPLETE_RUN_TIMEOUT");
        JSValueProtect(ctx, run_timeout_fn);
    }
    acquire_eval_lock();
    JSObjectCallAsFunction(ctx, run_timeout_fn, NULL, 1, args, NULL);
    release_eval_lock();
}

static unsigned long timeout_id = 0;

JSValueRef function_set_timeout(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 1
        && JSValueGetType(ctx, args[0]) == kJSTypeNumber) {
        
        int millis = (int) JSValueToNumber(ctx, args[0], NULL);
        
        if (timeout_id == 9007199254740991) {
            timeout_id = 0;
        } else {
            ++timeout_id;
        }
        
        JSValueRef rv = JSValueMakeNumber(ctx, (double)timeout_id);
        
        unsigned long *timeout_data = malloc(sizeof(unsigned long));
        *timeout_data = timeout_id;
        
        start_timer(millis, do_run_timeout, (void *) timeout_data);
        
        return rv;
    }
    return JSValueMakeNull(ctx);
}

void do_run_interval(void *data) {
    
    unsigned long *interval_data = data;
    
    JSValueRef args[1];
    args[0] = JSValueMakeNumber(ctx, (double)*interval_data);
    free(interval_data);
    
    static JSObjectRef run_interval_fn = NULL;
    if (!run_interval_fn) {
        run_interval_fn = get_function("global", "REPLETE_RUN_INTERVAL");
        JSValueProtect(ctx, run_interval_fn);
    }
    acquire_eval_lock();
    JSObjectCallAsFunction(ctx, run_interval_fn, NULL, 1, args, NULL);
    release_eval_lock();
}

static unsigned long interval_id = 0;

JSValueRef function_set_interval(JSContextRef ctx, JSObjectRef function, JSObjectRef thisObject,
                                 size_t argc, const JSValueRef args[], JSValueRef *exception) {
    if (argc == 2
        && JSValueGetType(ctx, args[0]) == kJSTypeNumber) {
        
        int millis = (int) JSValueToNumber(ctx, args[0], NULL);
        
        unsigned long curr_interval_id;
        
        if (JSValueIsNull(ctx, args[1])) {
            if (interval_id == 9007199254740991) {
                interval_id = 0;
            } else {
                ++interval_id;
            }
            curr_interval_id = interval_id;
        } else {
            curr_interval_id = (unsigned long) JSValueToNumber(ctx, args[1], NULL);
        }
        
        JSValueRef rv = JSValueMakeNumber(ctx, (double)curr_interval_id);
        
        unsigned long *interval_data = malloc(sizeof(unsigned long));
        *interval_data = curr_interval_id;
        
        start_timer(millis, do_run_interval, (void *) interval_data);
        
        return rv;
    }
    return JSValueMakeNull(ctx);
}


void bootstrap(JSContextRef ctx) {
    
    char *deps_file_path = "main.js";
    char *goog_base_path = "goog/base.js";
    
    char source[] = "<bootstrap>";
    
    // Setup CLOSURE_IMPORT_SCRIPT
    evaluate_script(ctx, "CLOSURE_IMPORT_SCRIPT = function(src) { AMBLY_IMPORT_SCRIPT('goog/' + src); return true; }",
                    source);
    
    // Load goog base
    char *base_script_str = bundle_get_contents(goog_base_path);
    if (base_script_str == NULL) {
        fprintf(stderr, "The goog base JavaScript text could not be loaded\n");
        exit(1);
    }
    evaluate_script(ctx, base_script_str, "<bootstrap:base>");
    free(base_script_str);
    
    // Load the deps file
    char *deps_script_str = bundle_get_contents(deps_file_path);
    if (deps_script_str == NULL) {
        fprintf(stderr, "The deps JavaScript text could not be loaded\n");
        exit(1);
    }
    evaluate_script(ctx, deps_script_str, "<bootstrap:deps>");
    free(deps_script_str);
    
    evaluate_script(ctx, "goog.isProvided_ = function(x) { return false; };", source);
    
    evaluate_script(ctx,
                    "goog.require = function (name) { return CLOSURE_IMPORT_SCRIPT(goog.dependencies_.nameToPath[name]); };",
                    source);
    
    evaluate_script(ctx, "goog.require('cljs.core');", source);
    
    // redef goog.require to track loaded libs
    evaluate_script(ctx,
                    "cljs.core._STAR_loaded_libs_STAR_ = cljs.core.into.call(null, cljs.core.PersistentHashSet.EMPTY, [\"cljs.core\"]);\n"
                    "goog.require = function (name, reload) {\n"
                    "    if(!cljs.core.contains_QMARK_(cljs.core._STAR_loaded_libs_STAR_, name) || reload) {\n"
                    "        var AMBLY_TMP = cljs.core.PersistentHashSet.EMPTY;\n"
                    "        if (cljs.core._STAR_loaded_libs_STAR_) {\n"
                    "            AMBLY_TMP = cljs.core._STAR_loaded_libs_STAR_;\n"
                    "        }\n"
                    "        cljs.core._STAR_loaded_libs_STAR_ = cljs.core.into.call(null, AMBLY_TMP, [name]);\n"
                    "        CLOSURE_IMPORT_SCRIPT(goog.dependencies_.nameToPath[name]);\n"
                    "    }\n"
                    "};", source);
    
    register_global_function(ctx, "REPLETE_SET_TIMEOUT", function_set_timeout);
    register_global_function(ctx, "REPLETE_SET_INTERVAL", function_set_interval);
    evaluate_script(ctx,
                    "var REPLETE_TIMEOUT_CALLBACK_STORE = {};\
                    var setTimeout = function( fn, ms ) {\
                    var id = REPLETE_SET_TIMEOUT(ms);\
                    REPLETE_TIMEOUT_CALLBACK_STORE[id] = fn;\
                    return id;\
                    };\
                    var REPLETE_RUN_TIMEOUT = function( id ) {\
                    if( REPLETE_TIMEOUT_CALLBACK_STORE[id] ) {\
                    REPLETE_TIMEOUT_CALLBACK_STORE[id]();\
                    delete REPLETE_TIMEOUT_CALLBACK_STORE[id];\
                    }\
                    };\
                    var clearTimeout = function( id ) {\
                    delete REPLETE_TIMEOUT_CALLBACK_STORE[id];\
                    };\
                    var REPLETE_INTERVAL_CALLBACK_STORE = {};\
                    var setInterval = function( fn, ms ) {\
                    var id = REPLETE_SET_INTERVAL(ms, null);\
                    REPLETE_INTERVAL_CALLBACK_STORE[id] = \
                    function(){ fn(); REPLETE_SET_INTERVAL(ms, id); };\
                    return id;\
                    };\
                    var REPLETE_RUN_INTERVAL = function( id ) {\
                    if( REPLETE_INTERVAL_CALLBACK_STORE[id] ) {\
                    REPLETE_INTERVAL_CALLBACK_STORE[id]();\
                    }\
                    };\
                    var clearInterval = function( id ) {\
                    delete REPLETE_INTERVAL_CALLBACK_STORE[id];\
                    };",
                    "<init>");
}

- (void)initializeJavaScriptEnvironment {
    
    ctx = JSGlobalContextCreate(NULL);
    self.context = [JSContext contextWithJSGlobalContextRef:ctx];

    evaluate_script(ctx, "var global = this;", "<init>");

    register_global_function(ctx, "AMBLY_IMPORT_SCRIPT", function_import_script);
    bootstrap(ctx);
    
    evaluate_script(ctx, "goog.provide('cljs.user');", "<init>");
    evaluate_script(ctx, "goog.require('cljs.core');", "<init>");
    
    [self requireAppNamespaces:self.context];
    
    JSValue* setupCljsUser = [self getValue:@"setup-cljs-user" inNamespace:@"replete.repl" fromContext:self.context];
    NSAssert(!setupCljsUser.isUndefined, @"Could not find the setup-cljs-user function");
    [setupCljsUser callWithArguments:@[]];
    
#ifdef DEBUG
    BOOL debugBuild = YES;
#else
    BOOL debugBuild = NO;
#endif
    
#ifdef TARGET_IPHONE_SIMULATOR
    BOOL targetSimulator = YES;
#else
    BOOL targetSimulator = NO;
#endif
    
    self.context[@"REPLETE_LOAD"] = ^(NSString *path) {
        
        //NSLog(@"Loading %@", path);
        char* contents = bundle_get_contents((char*)[path UTF8String]);
        
        if (contents) {
            return [NSString stringWithUTF8String:contents];
        } else {
            //NSLog(@"Failed to load %@", path);
        }
        
        return (NSString*)nil;
    };
    
    JSValue* initAppEnvFn = [self getValue:@"init-app-env" inNamespace:@"replete.repl" fromContext:self.context];
    [initAppEnvFn callWithArguments:@[@{@"debug-build": @(debugBuild),
                                        @"target-simulator": @(targetSimulator),
                                        @"user-interface-idiom": (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"iPad": @"iPhone")}]];
    
    self.readEvalPrintFn = [self getValue:@"read-eval-print" inNamespace:@"replete.repl" fromContext:self.context];
    NSAssert(!self.readEvalPrintFn.isUndefined, @"Could not find the read-eval-print function");
    
    self.formatFn = [self getValue:@"format" inNamespace:@"replete.repl" fromContext:self.context];
    NSAssert(!self.formatFn.isUndefined, @"Could not find the format function");
    
    self.setWidthFn = [self getValue:@"set-width" inNamespace:@"replete.repl" fromContext:self.context];
    NSAssert(!self.setWidthFn.isUndefined, @"Could not find the set-width function");
    
    self.chivorcamReferred = [self getValue:@"chivorcam-referred" inNamespace:@"replete.repl" fromContext:self.context];
    NSAssert(!self.chivorcamReferred.isUndefined, @"Could not find the chivorcam-referred function");
    
    self.suppressPrinting = false;
    
    self.context[@"REPLETE_HIGH_RES_TIMER"] = ^() {
        return mach_absolute_time() / 1e6;
    };
    
    // Monkey patch cljs.core/system-time to use Replete's high-res timer
    [self.context evaluateScript:@"cljs.core.system_time = REPLETE_HIGH_RES_TIMER;"];
    
    self.context[@"REPLETE_PRINT_FN"] = ^(NSString *message) {
//        NSLog(@"repl out: %@", message);
        if (self.initialized) {
            if (self.myPrintCallback) {
                if (!self.suppressPrinting) {
                    self.myPrintCallback(true, message);
                }
            } else {
                NSLog(@"printed without callback set: %@", message);
            }
        }
        //self.outputTextView.text = [self.outputTextView.text stringByAppendingString:message];
    };
    [self.context evaluateScript:@"cljs.core.set_print_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    [self.context evaluateScript:@"cljs.core.set_print_err_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    
    // TODO look into this. Without it thngs won't work.
    [self.context evaluateScript:@"var window = global;"];
    
    self.initialized = true;
    
    self.consentedToChivorcam = false;
    
    [self updateWidth];

    if ([self codeToBeEvaluatedWhenReady]) {
        NSLog(@"Delayed code to be evaluated: %@", [self codeToBeEvaluatedWhenReady]);
        [self evaluate:[self codeToBeEvaluatedWhenReady] asExpression:NO];
        if (self.myPrintCallback) {
            self.myPrintCallback(NO, @"(Loaded Code)");
        }
    }

}

-(void)requireAppNamespaces:(JSContext*)context
{
    [context evaluateScript:[NSString stringWithFormat:@"goog.require('%@');", [self munge:@"replete.repl"]]];
}

- (JSValue*)getValue:(NSString*)name inNamespace:(NSString*)namespace fromContext:(JSContext*)context
{
    JSValue* namespaceValue = nil;
    for (NSString* namespaceElement in [namespace componentsSeparatedByString: @"."]) {
        if (namespaceValue) {
            namespaceValue = namespaceValue[[self munge:namespaceElement]];
        } else {
            namespaceValue = context[[self munge:namespaceElement]];
        }
    }
    
    return namespaceValue[[self munge:name]];
}

- (NSString*)munge:(NSString*)s
{
    return [[[s stringByReplacingOccurrencesOfString:@"-" withString:@"_"]
             stringByReplacingOccurrencesOfString:@"!" withString:@"_BANG_"]
            stringByReplacingOccurrencesOfString:@"?" withString:@"_QMARK_"];
}

-(void)setPrintCallback:(void (^)(BOOL, NSString*))thePrintCallback
{
    self.myPrintCallback = thePrintCallback;
}

-(void)evaluate:(NSString*)text
{
    [self evaluate:text asExpression:YES];
}

- (void)defmacroCalled:(NSString*)text
{
    if (self.consentedToChivorcam) {
        self.suppressPrinting = true;
        [self.readEvalPrintFn callWithArguments:@[@"(require '[chivorcam.core :refer [defmacro defmacfn]])"]];
        self.suppressPrinting = false;
        [self.readEvalPrintFn callWithArguments:@[text, @true]];
    } else {
        UIAlertController * alert = [UIAlertController
                                     alertControllerWithTitle:@"Enable REPL\nMacro Definitions?"
                                     message:@""
                                     preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction* noButton = [UIAlertAction
                                   actionWithTitle:@"Cancel"
                                   style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction * action) {
                                   }];
        
        UIAlertAction* yesButton = [UIAlertAction
                                    actionWithTitle:@"OK"
                                    style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction * action) {
                                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
                                            self.consentedToChivorcam = true;
                                            self.suppressPrinting = true;
                                            [self.readEvalPrintFn callWithArguments:@[@"(require '[chivorcam.core :refer [defmacro defmacfn]])"]];
                                            self.suppressPrinting = false;
                                            [self.readEvalPrintFn callWithArguments:@[text, @true]];
                                        });
                                    }];
        
        [alert addAction:noButton];
        [alert addAction:yesButton];
       
        NSString* message = @"ClojureScript macros must be defined in a separate namespace and required appropriately."
        "\n\nFor didactic purposes, we can support defining macros directly in the Replete REPL. "
        "\n\nAny helper functions called during macroexpansion must be defined using defmacfn in lieu of defn.";
        
        NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
        paraStyle.alignment = NSTextAlignmentLeft;
        
        NSMutableAttributedString *atrStr = [[NSMutableAttributedString alloc] initWithString:message attributes:@{NSParagraphStyleAttributeName:paraStyle,NSFontAttributeName:[UIFont systemFontOfSize:14.0]}];
        
        [atrStr addAttribute:NSFontAttributeName value:[UIFont italicSystemFontOfSize:14] range:[message rangeOfString:@"during"]];
        [atrStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Menlo" size:14] range:[message rangeOfString:@"defmacfn"]];
        [atrStr addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"Menlo" size:14] range:[message rangeOfString:@"defn"]];
        
        [alert setValue:atrStr forKey:@"attributedMessage"];
        
        // Left justify text
        NSArray *subViewArray = alert.view.subviews;
        for(int x = 0; x < [subViewArray count]; x++){
            if([[[subViewArray objectAtIndex:x] class] isSubclassOfClass:[UILabel class]]) {
                UILabel *label = [subViewArray objectAtIndex:x];
                label.textAlignment = NSTextAlignmentLeft;
            }
        }
        
        [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

-(void)evaluate:(NSString*)text asExpression:(BOOL)expression
{
    if (([text hasPrefix:@"(defmacro"] || [text hasPrefix:@"(defmacfn"])
        && ![self.chivorcamReferred callWithArguments:@[]].toBool) {
        [self defmacroCalled:text];
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
            [self.readEvalPrintFn callWithArguments:@[text, @(expression)]];
        });
    }
}

-(NSArray*)parinferFormat:(NSString*)text pos:(int)pos enterPressed:(BOOL)enterPressed
{
    return [self.formatFn callWithArguments:@[text, @(pos), @(enterPressed)]].toArray;
}

-(BOOL)application:(UIApplication *)application
           openURL:(NSURL *)url
 sourceApplication:(NSString *)sourceApplication
        annotation:(id)annotation
{
    NSLog(@"this is passed in: %@", [url absoluteString]);

    if (url != nil && [url isFileURL]) {

        NSLog(@"Accepting file URL for evaluation: %@", [url absoluteString]);
        NSError *err;
        NSString *urlContent = [NSString stringWithContentsOfURL:url
                                                    usedEncoding: NULL
                                                           error: &err];
        if (urlContent != nil) {

            if ([self initialized]) {
                NSLog(@"Evaluating code: %@", urlContent);
                [self evaluate:urlContent asExpression:NO];
                if (self.myPrintCallback) {
                    self.myPrintCallback(NO, @"(Loaded Code)");
                }
            } else {
                NSLog(@"Code to be evaluated when ready: %@", urlContent);
                self.codeToBeEvaluatedWhenReady = urlContent;
            }

        } else {

            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error accepting file"
                                                                message:[err localizedDescription]
                                                               delegate:self
                                                      cancelButtonTitle:@"Cancel"
                                                      otherButtonTitles:nil];
            [alertView show];

        }
    }
    return YES;
}

+ (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)updateWidth
{
    if (self.setWidthFn) {
        
        int width = ([[UIScreen mainScreen] applicationFrame].size.width - 10)/9;
        
        [self.setWidthFn callWithArguments:@[@(width)]];
        
    }
}

- (void)handleDidChangeStatusBarOrientationNotification:(NSNotification *)notification;
{
    // Do something interesting
    NSLog(@"The orientation is %@", [notification.userInfo objectForKey: UIApplicationStatusBarOrientationUserInfoKey]);
    [self updateWidth];
}

-(NSString*)getClojureScriptVersion
{
    // Grab bundle.js; it is relatively small
    NSString* bundleJs = [NSString stringWithUTF8String:bundle_get_contents("replete/bundle.js")];
    
    if (bundleJs) {
        return [[bundleJs substringFromIndex:29] componentsSeparatedByString:@" "][0];
    } else {
        return @"(Unknown)";
    }
}

@end
