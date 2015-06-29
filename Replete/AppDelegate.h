//
//  AppDelegate.h
//  Replete
//
//  Created by Mike Fikes on 6/27/15.
//  Copyright (c) 2015 FikesFarm. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

- (void)initializeJavaScriptEnvironment;
-(void)setPrintCallback:(void (^)(NSString*))printCallback;
-(void)evaluate:(NSString*)text;

@end

