//
//  AppDelegate.m
//  Replete
//
//  Created by Mike Fikes on 6/27/15.
//  Copyright (c) 2015 FikesFarm. All rights reserved.
//

#import "AppDelegate.h"
#include <Foundation/Foundation.h>
#include <JavaScriptCore/JavaScriptCore.h>
#include "bundle.h"

@interface AppDelegate ()

@property (assign, nonatomic) JSContext* context;
@property (strong, nonatomic) JSValue* readEvalPrintFn;
@property (strong, nonatomic) JSValue* formatFn;
@property (strong, nonatomic) JSValue* setWidthFn;
@property (nonatomic, copy) void (^myPrintCallback)(BOOL, NSString*);
@property BOOL initialized;
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
}

- (void)initializeJavaScriptEnvironment {
    
    JSGlobalContextRef ctx = JSGlobalContextCreate(NULL);
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
    
    self.context[@"REPLETE_PRINT_FN"] = ^(NSString *message) {
//        NSLog(@"repl out: %@", message);
        if (self.initialized) {
            if (self.myPrintCallback) {
                self.myPrintCallback(true, message);
            } else {
                NSLog(@"printed without callback set: %@", message);
            }
        }
        //self.outputTextView.text = [self.outputTextView.text stringByAppendingString:message];
    };
    [self.context evaluateScript:@"cljs.core.set_print_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    [self.context evaluateScript:@"cljs.core.set_print_err_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    
    [self.readEvalPrintFn callWithArguments:@[@"(ns cljs.user (:require [replete.core :refer [eval]]))"]];
    
    // TODO look into this. Without it thngs won't work.
    [self.context evaluateScript:@"var window = global;"];
    
    self.initialized = true;
    
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

-(void)evaluate:(NSString*)text asExpression:(BOOL)expression
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        [self.readEvalPrintFn callWithArguments:@[text, @(expression)]];
    });
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
