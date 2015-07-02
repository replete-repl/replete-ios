//
//  AppDelegate.m
//  Replete
//
//  Created by Mike Fikes on 6/27/15.
//  Copyright (c) 2015 FikesFarm. All rights reserved.
//

#import "AppDelegate.h"
#import "ABYContextManager.h"

@interface AppDelegate ()

@property (strong, nonatomic) ABYContextManager* contextManager;
@property (strong, nonatomic) JSValue* readEvalPrintFn;
@property (strong, nonatomic) JSValue* isReadableFn;
@property (nonatomic, copy) void (^myPrintCallback)(NSString*);

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
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

- (void)initializeJavaScriptEnvironment {
    
    NSString *outPath = [[NSBundle mainBundle] pathForResource:@"out" ofType:nil];
    NSURL* outURL = [NSURL URLWithString:outPath];
    
    self.contextManager = [[ABYContextManager alloc] initWithContext:JSGlobalContextCreate(NULL)
                                             compilerOutputDirectory:outURL];
    [self.contextManager setUpConsoleLog];
    [self.contextManager setupGlobalContext];
    [self.contextManager setUpAmblyImportScript];
    
    NSString* mainJsFilePath = [[outURL URLByAppendingPathComponent:@"deps" isDirectory:NO]
                                URLByAppendingPathExtension:@"js"].path;
    
    NSURL* googDirectory = [outURL URLByAppendingPathComponent:@"goog"];
    
    [self.contextManager bootstrapWithDepsFilePath:mainJsFilePath
                                      googBasePath:[[googDirectory URLByAppendingPathComponent:@"base" isDirectory:NO] URLByAppendingPathExtension:@"js"].path];
    
    JSContext* context = [JSContext contextWithJSGlobalContextRef:self.contextManager.context];
    
    NSURL* outCljsURL = [outURL URLByAppendingPathComponent:@"cljs"];
    NSString* macrosJsPath = [[outCljsURL URLByAppendingPathComponent:@"core$macros"]
                              URLByAppendingPathExtension:@"js"].path;
    
    [self processFile:macrosJsPath calling:nil inContext:context];
    
    [self requireAppNamespaces:context];
    
    [self processFile:[[NSBundle mainBundle] pathForResource:@"core.cljs.cache.aot" ofType:@"transit"]
              calling:@"load-core-cache" inContext:context];
    
    [self processFile:[[NSBundle mainBundle] pathForResource:@"core$macros.cljc.cache" ofType:@"transit"]
              calling:@"load-macros-cache" inContext:context];
        
    self.readEvalPrintFn = [self getValue:@"read-eval-print" inNamespace:@"replete.core" fromContext:context];
    NSAssert(!self.readEvalPrintFn.isUndefined, @"Could not find the read-eval-print function");
    
    self.isReadableFn = [self getValue:@"is-readable?" inNamespace:@"replete.core" fromContext:context];
    NSAssert(!self.isReadableFn.isUndefined, @"Could not find the is-readable? function");

    
    context[@"REPLETE_PRINT_FN"] = ^(NSString *message) {
        if (self.myPrintCallback) {
            self.myPrintCallback(message);
        } else {
            NSLog(@"printed without callback set: %@", message);
        }
        //self.outputTextView.text = [self.outputTextView.text stringByAppendingString:message];
    };
    [context evaluateScript:@"cljs.core.set_print_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    
    // TODO look into this. Without it thngs won't work.
    [context evaluateScript:@"var window = global;"];
    
    //JSValue* response = [readEvalPrintFn callWithArguments:@[@"(def a 3)"]];
    //NSLog(@"%@", [response toString]);

}

- (void)processFile:(NSString*)path calling:(NSString*)fn inContext:(JSContext*)context
{
    NSError* error = nil;
    NSString* contents = [NSString stringWithContentsOfFile:path
                                                   encoding:NSUTF8StringEncoding error:&error];
    
    if (!fn) {
        [context evaluateScript:contents];
    } else {
        JSValue* processFileFn = [self getValue:fn inNamespace:@"replete.core" fromContext:context];
        NSAssert(!processFileFn.isUndefined, @"Could not find the process file function");
        
        if (!error && contents) {
            [processFileFn callWithArguments:@[contents]];
        }
    }
}

-(void)requireAppNamespaces:(JSContext*)context
{
    [context evaluateScript:[NSString stringWithFormat:@"goog.require('%@');", [self munge:@"replete.ui"]]];
    [context evaluateScript:[NSString stringWithFormat:@"goog.require('%@');", [self munge:@"replete.core"]]];
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

-(void)setPrintCallback:(void (^)(NSString*))thePrintCallback
{
    self.myPrintCallback = thePrintCallback;
}

-(void)evaluate:(NSString*)text
{
    [self.readEvalPrintFn callWithArguments:@[text]];
}

-(BOOL)isReadable:(NSString*)text
{
    return [self.isReadableFn callWithArguments:@[text]].toBool;
}


@end
