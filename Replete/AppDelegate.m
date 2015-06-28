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

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    NSString *outPath = [[NSBundle mainBundle] pathForResource:@"out" ofType:nil];
    NSURL* outURL = [NSURL URLWithString:outPath];
    
    self.contextManager = [[ABYContextManager alloc] initWithContext:JSGlobalContextCreate(NULL)
                                             compilerOutputDirectory:outURL];
    [self.contextManager setUpConsoleLog];
    [self.contextManager setUpAmblyImportScript];
    
    NSString* mainJsFilePath = [[outURL URLByAppendingPathComponent:@"deps" isDirectory:NO]
                                URLByAppendingPathExtension:@"js"].path;
    
    NSURL* googDirectory = [outURL URLByAppendingPathComponent:@"goog"];
    
    [self.contextManager bootstrapWithDepsFilePath:mainJsFilePath
                                      googBasePath:[[googDirectory URLByAppendingPathComponent:@"base" isDirectory:NO] URLByAppendingPathExtension:@"js"].path];
    
    JSContext* context = [JSContext contextWithJSGlobalContextRef:self.contextManager.context];
    
    NSURL* outCljsURL = [outURL URLByAppendingPathComponent:@"cljs"];
    NSString* macrosJsPath = [outCljsURL URLByAppendingPathComponent:@"core$macros"].path;
    
    [self processFile:macrosJsPath withExt:@"js" calling:nil inContext:context];
    
    [self requireAppNamespaces:context];
    
    [self processFile:@"core.cljs.cache.aot" withExt:@"edn" calling:@"load-core-cache" inContext:context];
    [self processFile:@"core$macros.cljc.cache" withExt:@"edn" calling:@"load-macros-cache" inContext:context];
  
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

- (void)processFile:(NSString*)path withExt:(NSString*)ext calling:(NSString*)fn inContext:(JSContext*)context
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
    [context evaluateScript:[NSString stringWithFormat:@"goog.require('%@');", [self munge:@"niode.ui"]]];
    [context evaluateScript:[NSString stringWithFormat:@"goog.require('%@');", [self munge:@"niode.core"]]];
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


@end
