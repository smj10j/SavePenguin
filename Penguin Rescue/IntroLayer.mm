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
#import "Utilities.h"
#import "SSKeychain.h"
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
		CGSize size = [[CCDirector sharedDirector] winSize];
		
		CCSprite *background;
		
		if( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ) {
			background = [CCSprite spriteWithFile:@"Default.png"];
			background.rotation = 90;
		} else {
			background = [CCSprite spriteWithFile:@"Default-Landscape~ipad.png"];
		}
		background.position = ccp(size.width/2, size.height/2);
		
		// add the label as a child to this Layer
		[self addChild: background];
		
		
		/*********** Sound Settings ************/
		[[SimpleAudioEngine sharedEngine] setBackgroundMusicVolume:0.20f];
		[[SimpleAudioEngine sharedEngine] setEffectsVolume:0.80f];


		
		
		
		double lastRun = [SettingsManager doubleForKey:SETTING_LAST_RUN_TIMESTAMP];
		DebugLog(@"Last run was: %f", lastRun);
		
		//INITIAL SETTINGS TIME!!
		if(lastRun == 0) {
			//first run
			
			//set up the default user preferences
			[SettingsManager setBool:true forKey:@"SoundEnabled"];
			[SettingsManager setBool:true forKey:@"MusicEnabled"];
			
			
			
			
			
			
			//set a user id
			//first see if the userId is in the keychain
			NSError *error = nil;
			NSString* UUID = [SSKeychain passwordForService:COMPANY_IDENTIFIER account:@"user" error:&error];
			if (error != nil) {
				DebugLog(@"@@@@ ERROR SSKeychain passwordForService error code: %d", [error code]);
			}
			if(UUID == nil) {
				UUID = [Utilities UUID];
				DebugLog(@"Created a new uuid");
								
				//store the userId to the keychain
				error = nil;
				[SSKeychain setPassword:UUID forService:COMPANY_IDENTIFIER account:@"user" error:&error];
				if (error!= nil) {
					DebugLog(@"@@@@ ERROR SSKeychain setPassword error code: %d", [error code]);
				}
				
			}else {
				DebugLog(@"Retrieved uuid from the keychain!");
			}
			[SettingsManager setString:UUID forKey:SETTING_UUID];
						
			//TODO: also store this to iCloud: refer to: http://stackoverflow.com/questions/7273014/ios-unique-user-identifier
			/*
				To make sure ALL devices have the same UUID in the Keychain.

				Setup your app to use iCloud.
				Save the UUID that is in the Keychain to NSUserDefaults as well.
				Pass the UUID in NSUserDefaults to the Cloud with Key-Value Data Store.
				On App first run, Check if the Cloud Data is available and set the UUID in the Keychain on the New Device.
			*/
			
			
			
		}
		
		//create the user on the server
		if(![SettingsManager boolForKey:SETTING_HAS_CREATED_UUID_ON_SERVER]) {
			[APIManager addUserWithUUID:[SettingsManager stringForKey:SETTING_UUID] 
				onSuccess:^(NSDictionary* response) {
					if(DEBUG_SCORING) DebugLog(@"Added new user to server. response = %@", response);
					[SettingsManager setBool:true forKey:SETTING_HAS_CREATED_UUID_ON_SERVER];
				}
				onError:^(NSError* error) {
					if(DEBUG_SCORING) DebugLog(@"Error sending new user data to server: %@", error.localizedDescription);
					[SettingsManager setBool:false forKey:SETTING_HAS_CREATED_UUID_ON_SERVER];
				}
			];
		}
		
		//output our UserId
		DebugLog(@"Launching with uuid=%@", [SettingsManager stringForKey:SETTING_UUID]);
		
		//set our boot time (can be used for applying settings on updates
		[SettingsManager setDouble:[[NSDate date] timeIntervalSince1970] forKey:SETTING_LAST_RUN_TIMESTAMP];
	}
	
	if(DEBUG_MEMORY) DebugLog(@"Initialized IntroLayer");	
	
	return self;
}

-(void) onEnter
{
	[super onEnter];
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[MainMenuLayer scene] ]];
}

-(void) onExit {
	if(DEBUG_MEMORY) DebugLog(@"IntroLayer onExit");

	[super onExit];
}
@end
