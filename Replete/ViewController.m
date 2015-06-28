//
//  ViewController.m
//  Replete
//
//  Created by Mike Fikes on 6/27/15.
//  Copyright (c) 2015 FikesFarm. All rights reserved.
//

#import "ViewController.h"
#import "ABYContextManager.h"

@interface ViewController ()

@property (strong, nonatomic) ABYContextManager* contextManager;
@property (strong, nonatomic) JSValue* readEvalPrintFn;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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
    
    [self processFile:[[NSBundle mainBundle] pathForResource:@"core.cljs.cache.aot" ofType:@"edn"]
              calling:@"load-core-cache" inContext:context];
    
    NSString* coreMacrosCacheAotEdn = [[outCljsURL URLByAppendingPathComponent:@"core$macros.cljc.cache"]
                                       URLByAppendingPathExtension:@"edn"].path;
    
    
    [self processFile:coreMacrosCacheAotEdn calling:@"load-macros-cache" inContext:context];
    
    self.readEvalPrintFn = [self getValue:@"read-eval-print" inNamespace:@"replete.core" fromContext:context];
    NSAssert(!self.readEvalPrintFn.isUndefined, @"Could not find the Read-Eval-Print function");
    
    context[@"REPLETE_PRINT_FN"] = ^(NSString *message) {
        self.outputTextView.text = [self.outputTextView.text stringByAppendingString:message];
    };
    [context evaluateScript:@"cljs.core.set_print_fn_BANG_.call(null,REPLETE_PRINT_FN);"];
    
    // TODO look into this. Without it thngs won't work.
    [context evaluateScript:@"var window = global;"];
    
    //JSValue* response = [readEvalPrintFn callWithArguments:@[@"(def a 3)"]];
    //NSLog(@"%@", [response toString]);

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

- (IBAction)evalButtonPressed:(id)sender {
    NSString* inputText = self.inputTextView.text;
    self.inputTextView.text = @"";
    self.outputTextView.text = [self.outputTextView.text stringByAppendingString:
                                [NSString stringWithFormat:@"replete.core=> %@\n", inputText]];
    [self.readEvalPrintFn callWithArguments:@[inputText]];
}

@end
