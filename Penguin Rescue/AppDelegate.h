//
//  AppDelegate.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "cocos2d.h"
#import "Constants.h"

@class Reachability;

@interface AppController : NSObject <UIApplicationDelegate, CCDirectorDelegate>
{
	UIWindow* _window;
	UINavigationController* _navController;
	
	CCDirectorIOS* _director_;							// weak ref
	
	Reachability* _hostReachable;
}

@property (nonatomic, retain) UIWindow *window;
@property (readonly) UINavigationController *navController;
@property (readonly) CCDirectorIOS *director;


-(void) checkNetworkStatus:(NSNotification *)notice;

@end
