//
//  IntroLayer.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "IntroLayer.h"
#import "MainMenuLayer.h"
#import "AppDelegate.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"
#import "Analytics.h"
#import "Utilities.h"
#import "APIManager.h"

#pragma mark - IntroLayer

// IntroLayer implementation
@implementation IntroLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	IntroLayer *layer = [IntroLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		
		CCSprite *background;
		
		if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ) {
			if(IS_STUPID_IPHONE_5) {
				background = [CCSprite spriteWithFile:@"Default-568h@2x.png"];
			}else {
				background = [CCSprite spriteWithFile:@"Default.png"];
			}
			background.rotation = 90;
		} else {
			background = [CCSprite spriteWithFile:@"Default-Landscape~ipad.png"];
		}
		
		background.position = ccp(winSize.width/2, winSize.height/2);
		[self addChild: background];
		
	
		/*********** Sound Settings ************/
		[[SimpleAudioEngine sharedEngine] setBackgroundMusicVolume:0.40f];
		[[SimpleAudioEngine sharedEngine] setEffectsVolume:0.80f];
		
		
		double lastRun = [SettingsManager doubleForKey:SETTING_LAST_RUN_TIMESTAMP];
		DebugLog(@"Last run was: %f", lastRun);
		
		//INITIAL SETTINGS TIME!!
		if(lastRun == 0) {
			//first run
			
			//set up the default user preferences
			[SettingsManager setBool:true forKey:SETTING_SOUND_ENABLED];
			[SettingsManager setBool:true forKey:SETTING_MUSIC_ENABLED];
			[SettingsManager setInt:1 forKey:SETTING_NUM_APP_OPENS];

			[SettingsManager setInt:INITIAL_FREE_COINS forKey:SETTING_TOTAL_EARNED_COINS];
			[SettingsManager setInt:INITIAL_FREE_COINS forKey:SETTING_TOTAL_AVAILABLE_COINS];
			
		}
		[APIManager createUser];
		[Analytics setUserId:[SettingsManager getUUID]];
		DebugLog(@"Launching with uuid=%@", [SettingsManager getUUID]);
		
		//set our current version (can be used in future version to test for update
		NSDictionary* infoDict = [[NSBundle mainBundle] infoDictionary];
		NSString* version = [infoDict objectForKey:@"CFBundleShortVersionString"];
		[SettingsManager setString:version forKey:SETTING_CURRENT_VERSION];
		if(DEBUG_SETTINGS) DebugLog(@"Updated Current Version setting to %@", version);
		
		//set our boot time (can be used for applying settings on updates
		[SettingsManager setDouble:[[NSDate date] timeIntervalSince1970] forKey:SETTING_LAST_RUN_TIMESTAMP];
		[SettingsManager incrementIntBy:1 forKey:SETTING_NUM_APP_OPENS];
	}

	[[SimpleAudioEngine sharedEngine] preloadBackgroundMusic:@"sounds/menu/ambient/theme.wav"];

	
	if(DEBUG_MEMORY) DebugLog(@"Initialized IntroLayer");	
	
	return self;
}

-(void) onEnter
{
	[super onEnter];
	[self scheduleOnce:@selector(showMainLayer) delay:(DISTRIBUTION_MODE ? 1.0f : 0.0f)];
}

-(void)showMainLayer {
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFadeBL transitionWithDuration:0.5 scene:[MainMenuLayer scene]]];
	//[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[MainMenuLayer scene] ]];
}

-(void) onExit {
	if(DEBUG_MEMORY) DebugLog(@"IntroLayer onExit");

	[super onExit];
}
@end
