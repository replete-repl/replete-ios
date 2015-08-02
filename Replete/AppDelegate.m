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
@property (nonatomic, copy) void (^myPrintCallback)(BOOL, NSString*);
@property BOOL initialized;
@property NSString *codeToBeEvaluatedWhenReady;

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
    
    NSURL* srcURL = [[AppDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:@"src/" isDirectory:YES];
    NSString* srcPath = srcURL.path;
    
    self.contextManager = [[ABYContextManager alloc] initWithContext:JSGlobalContextCreate(NULL)
                                             compilerOutputDirectory:outURL];
    [self.contextManager setUpConsoleLog];
    [self.contextManager setupGlobalContext];
    [self.contextManager setUpAmblyImportScript];
    
    NSString* mainJsFilePath = [[outURL URLByAppendingPathComponent:@"main" isDirectory:NO]
                                URLByAppendingPathExtension:@"js"].path;
    
    NSURL* googDirectory = [outURL URLByAppendingPathComponent:@"goog"];
    
    [self.contextManager bootstrapWithDepsFilePath:mainJsFilePath
                                      googBasePath:[[googDirectory URLByAppendingPathComponent:@"base" isDirectory:NO] URLByAppendingPathExtension:@"js"].path];
    
    JSContext* context = [JSContext contextWithJSGlobalContextRef:self.contextManager.context];
    
    [self requireAppNamespaces:context];
    
    JSValue* setupCljsUser = [self getValue:@"setup-cljs-user" inNamespace:@"replete.core" fromContext:context];
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
    
    JSValue* initAppEnvFn = [self getValue:@"init-app-env" inNamespace:@"replete.core" fromContext:context];
    [initAppEnvFn callWithArguments:@[@{@"debug-build": @(debugBuild),
                                        @"target-simulator": @(targetSimulator),
                                        @"user-interface-idiom": (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"iPad": @"iPhone")}]];
    
    self.readEvalPrintFn = [self getValue:@"read-eval-print" inNamespace:@"replete.core" fromContext:context];
    NSAssert(!self.readEvalPrintFn.isUndefined, @"Could not find the read-eval-print function");
    
    self.isReadableFn = [self getValue:@"is-readable?" inNamespace:@"replete.core" fromContext:context];
    NSAssert(!self.isReadableFn.isUndefined, @"Could not find the is-readable? function");

    
    context[@"REPLETE_PRINT_FN"] = ^(NSString *message) {
//        NSLog(@"repl out: %@", message);
        if (self.myPrintCallback) {
            self.myPrintCallback(true, message);
        } else {
            NSLog(@"printed without callback set: %@", message);
        }
        //self.outputTextView.text = [self.outputTextView.text stringByAppendingString:message];
    };
    [context evaluateScript:@"cljs.core.set_print_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    [context evaluateScript:@"cljs.core.set_print_err_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    
    context[@"REPLETE_LOAD"] = ^(NSString *path) {
        // First try in the srcPath
        
        NSString* fullPath = [NSURL URLWithString:path
                                    relativeToURL:[NSURL URLWithString:srcPath]].path;
        
        NSString* rv = [NSString stringWithContentsOfFile:fullPath
                                                 encoding:NSUTF8StringEncoding error:nil];
        // Now try in the outPath
        if (!rv) {
            fullPath = [NSURL URLWithString:path
                                  relativeToURL:[NSURL URLWithString:[outPath stringByAppendingString:@"/"]]].path;
                rv = [NSString stringWithContentsOfFile:fullPath
                                               encoding:NSUTF8StringEncoding error:nil];
        }
        
        return rv;
    };

    
    // TODO look into this. Without it thngs won't work.
    [context evaluateScript:@"var window = global;"];
    
    //JSValue* response = [readEvalPrintFn callWithArguments:@[@"(def a 3)"]];
    //NSLog(@"%@", [response toString]);

    self.initialized = true;

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

-(BOOL)isReadable:(NSString*)text
{
    return [self.isReadableFn callWithArguments:@[text]].toBool;
}

-(BOOL)application:(UIApplication *)application
           openURL:(NSURL *)url
 sourceApplication:(NSString *)sourceApplication
        annotation:(id)annotation
{
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

@end
