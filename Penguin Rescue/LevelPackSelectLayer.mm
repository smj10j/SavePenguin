//
//  LevelPackSelectLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "LevelPackSelectLayer.h"
#import "MainMenuLayer.h"
#import "LevelSelectLayer.h"
#import "LevelPackManager.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"
#import "CCScrollLayer.h"
#import "Utilities.h"
#import "Analytics.h"
#import "AppDelegate.h"

#pragma mark - LevelPackSelectLayer

@implementation LevelPackSelectLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	LevelPackSelectLayer *layer = [LevelPackSelectLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		CGSize winSize = [[CCDirector sharedDirector] winSize];

		self.isTouchEnabled = YES;

		_iapManager = [[IAPManager alloc] init];

		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"LevelPackSelect"]];
		[_levelLoader addObjectsToWorld:nil cocos2dLayer:self];
				
		//draw the background water tiles
		LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND];
		for(int x = -waterTile.boundingBox.size.width/2; x < winSize.width + waterTile.boundingBox.size.width/2; ) {
			for(int y = -waterTile.boundingBox.size.height/2; y < winSize.height + waterTile.boundingBox.size.width/2; ) {
				LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND parent:[_levelLoader layerWithUniqueName:@"MAIN_LAYER"]];
				waterTile.zOrder = -1;
				[waterTile transformPosition:ccp(x,y)];
				y+= waterTile.boundingBox.size.height;
			}
			x+= waterTile.boundingBox.size.width;
		}
		[waterTile removeSelf];

		_spriteNameToLevelPackPath = [[NSMutableDictionary alloc] init];
				
		LHSprite* backButton = [_levelLoader createSpriteWithName:@"Back_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:[_levelLoader layerWithUniqueName:@"MAIN_LAYER"]];
		[backButton prepareAnimationNamed:@"Menu_Back_Button" fromSHScene:@"Spritesheet"];
		[backButton transformPosition: ccp(20*SCALING_FACTOR_H + backButton.boundingBox.size.width/2,
											20*SCALING_FACTOR_V + backButton.boundingBox.size.height/2)];
		[backButton registerTouchBeganObserver:self selector:@selector(onTouchAnyButton:)];
		[backButton registerTouchEndedObserver:self selector:@selector(onTouchEndedBack:)];
		
		//100 coins
		[_iapManager requestProduct:IAP_PACKAGE_ID_1 successCallback:^(NSString* productPrice){
			if(DEBUG_IAP) DebugLog(@"Requested IAP product successfully!");
		}];		
		
		
		[self loadLevelPacks];
		
		if([SettingsManager boolForKey:SETTING_MUSIC_ENABLED] && ![[SimpleAudioEngine sharedEngine] isBackgroundMusicPlaying]) {
			[self fadeInBackgroundMusic: @"sounds/menu/ambient/menu.mp3"];
		}
		
		[Analytics logEvent:@"View_Level_Packs"];
	}
	
	if(DEBUG_MEMORY) DebugLog(@"Initialized LevelPackSelectLayer");
	if(DEBUG_MEMORY) report_memory();
	
	return self;
}




-(void) loadLevelPacks {

	//load all available level packs
	NSDictionary* levelPacksDictionary = [LevelPackManager allLevelPacks];

	//load ones the user has completed
	NSArray* completedLevelPacks = [LevelPackManager completedPacks];
	NSArray* availableLevelPacks = [LevelPackManager availablePacks];


	NSMutableArray* scrollableLayers = [[NSMutableArray alloc] init];

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	LHSprite* levelPackButton = [_levelLoader createSpriteWithName:@"Level_Pack_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	const CGSize levelPackButtonSize = levelPackButton.boundingBox.size;
	[levelPackButton removeSelf];
			
	for(int i = 0; i < levelPacksDictionary.count; i++) {
	
		CCLayer* scrollableLayer = [[CCLayer alloc] init];
		[scrollableLayers addObject:scrollableLayer];
		[scrollableLayer release];

		NSDictionary* levelPackData = [levelPacksDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelPackName = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_NAME];
		NSString* levelPackPath = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_PATH];
		NSDictionary* completedLevels = [LevelPackManager completedLevelsInPack:levelPackPath];
		NSDictionary* allLevels = [LevelPackManager allLevelsInPack:levelPackPath];

		//create the sprite
		LHSprite* levelPackButton = [_levelLoader createSpriteWithName:@"Level_Pack_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:scrollableLayer];
		[levelPackButton prepareAnimationNamed:@"Menu_Level_Pack_Select_Button" fromSHScene:@"Spritesheet"];

		//display the pack background
		CCSprite* packBackground = [CCSprite spriteWithFile:[NSString stringWithFormat:@"Levels/%@/%@", levelPackPath, @"IconBackground.png"]];
		packBackground.scale = levelPackButton.contentSize.width/packBackground.contentSize.width;
		packBackground.position = ccp(levelPackButtonSize.width/2,levelPackButtonSize.height/2);
		[levelPackButton addChild:packBackground];
		
		bool isLocked = false;

		if([completedLevelPacks containsObject:levelPackPath]) {
			//DebugLog(@"Pack %@ is completed!", levelPackPath);

			//add a checkmark icon
			LHSprite* completedMark = [_levelLoader createSpriteWithName:@"Level_Pack_Completed" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelPackButton];
			[completedMark transformPosition:ccp(levelPackButtonSize.width/2,
												levelPackButtonSize.height/2 - 40*SCALING_FACTOR_V)];
					
		}else if([availableLevelPacks containsObject:levelPackPath]) {
			//DebugLog(@"Pack %@ is available!", levelPackPath);
					
		}else {
			//DebugLog(@"Pack %@ is NOT available!", levelPackPath);

			//add a lock on top
			LHSprite* lockIcon = [_levelLoader createSpriteWithName:@"Level_Pack_Locked" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelPackButton];
			[lockIcon transformPosition:ccp(levelPackButtonSize.width/2,
											levelPackButtonSize.height/2 - 60*SCALING_FACTOR_V)];
			
			isLocked = true;
		}
		
		
		//display the pack name
		CCLabelTTF* packNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", levelPackName] fontName:@"Helvetica" fontSize:36*SCALING_FACTOR_FONTS];
		packNameLabel.color = ccWHITE;
		packNameLabel.position = ccp(levelPackButtonSize.width/2,
									levelPackButtonSize.height + 40*SCALING_FACTOR_V);
		[levelPackButton addChild:packNameLabel];
		
		
		[_spriteNameToLevelPackPath setObject:levelPackPath forKey:levelPackButton.uniqueName];
		
		if(!isLocked) {
		
			//used when clicking the sprite
			[levelPackButton registerTouchBeganObserver:self selector:@selector(onTouchAnyButton:)];
			[levelPackButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelPackSelect:)];

			//display the % completion
			double percentComplete = (double)completedLevels.count/(allLevels.count > 0 ? allLevels.count : 1) * 100.0;
			CCLabelTTF* percentCompleteLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%% complete", (int)percentComplete] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS];
			percentCompleteLabel.color = ccWHITE;
			percentCompleteLabel.position = ccp(levelPackButtonSize.width/2, -25*SCALING_FACTOR_V);
			[levelPackButton addChild:percentCompleteLabel];
			
		}else {
			//used when clicking the sprite
			[levelPackButton registerTouchBeganObserver:self selector:@selector(onTouchAnyButton:)];
			[levelPackButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLockedLevelPackSelect:)];
		
			//display the coin cost
			CCLabelTTF* coinCostLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"75 Needed to Unlock"] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS];
			coinCostLabel.color = ccWHITE;
			coinCostLabel.position = ccp(levelPackButtonSize.width/2, -25*SCALING_FACTOR_V);
			[levelPackButton addChild:coinCostLabel];
		
		}
				
		//positioning
		[levelPackButton transformPosition: ccp(winSize.width/2, winSize.height/2 + 20*SCALING_FACTOR_V)];
	}
	
	
	// now create the scroller and pass-in the pages (set widthOffset to 0 for fullscreen pages)
	_scrollLayer = [[CCScrollLayer alloc] initWithLayers:scrollableLayers widthOffset: 0];
	[scrollableLayers release];
	[[_levelLoader layerWithUniqueName:@"MAIN_LAYER"] addChild:_scrollLayer];
	_scrollLayer.zOrder = [_levelLoader layerWithUniqueName:@"Map"].zOrder+1;
	

	//move to the last viewed page if appropriate
	[_scrollLayer selectPage:[SettingsManager intForKey:SETTING_LAST_LEVEL_PACK_SELECT_SCREEN_NUM]];
}





/************* Touch handlers ***************/

-(void)onTouchAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
}

-(void)onTouchEndedLockedLevelPackSelect:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	[SettingsManager setInt:_scrollLayer.currentScreen forKey:SETTING_LAST_LEVEL_PACK_SELECT_SCREEN_NUM];	
	
	NSString* levelPackPath = [_spriteNameToLevelPackPath objectForKey:info.sprite.uniqueName];
	
	int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
	if(availableCoins < 75) {
		if(DEBUG_IAP) DebugLog(@"Not enough coins to unlock %@ - prompting", levelPackPath);

		UIAlertView *promptForPurchaseAlert = [[UIAlertView alloc] initWithTitle:@"Not Enough Coins" message:[NSString stringWithFormat:@"You need %d coins and you only have %d. Would you like to buy 100 coins for %@", 75, availableCoins, (_iapManager.selectedProduct == nil ? @"$0.99" : _iapManager.selectedProduct.localizedPrice)] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Not Now", nil];
		[promptForPurchaseAlert show];
		[promptForPurchaseAlert release];
		
		//analytics logging
		int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			levelPackPath, @"Level_Pack",
			[NSNumber numberWithInt:availableCoins], @"AvailableCoins",
		nil];
		[Analytics logEvent:@"LevelPackSelectLayer_Prompt_To_Buy_Coins" withParameters:flurryParams];
		
	}else {
		if(DEBUG_IAP) DebugLog(@"Unlocking level pack %@", levelPackPath);

		//analytics logging
		int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			levelPackPath, @"Level_Pack",
			[NSNumber numberWithInt:availableCoins], @"AvailableCoins",
		nil];
		[Analytics logEvent:@"LevelPackSelectLayer_Unlock_Locked_Pack" withParameters:flurryParams];


		//unlock
		[SettingsManager setBool:false forKey:[NSString stringWithFormat:@"%@%@", SETTING_LOCKED_LEVEL_PACK_PATH, levelPackPath]];

		//charge
		availableCoins = [SettingsManager decrementIntBy:75 forKey:SETTING_TOTAL_AVAILABLE_COINS];
		
		//reload
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[LevelPackSelectLayer scene] ]];
	}
}

-(void)onTouchEndedLevelPackSelect:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	[SettingsManager setInt:_scrollLayer.currentScreen forKey:SETTING_LAST_LEVEL_PACK_SELECT_SCREEN_NUM];
	
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[LevelSelectLayer sceneWithLevelPackPath:[_spriteNameToLevelPackPath objectForKey:info.sprite.uniqueName]] ]];
}


-(void)onTouchEndedBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
	
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[MainMenuLayer scene] ]];
}


-(void)fadeInBackgroundMusic:(NSString*)path {
	
	float prevVolume = [[SimpleAudioEngine sharedEngine] backgroundMusicVolume];
	float fadeInTimeOffset = 0;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, fadeInTimeOffset * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
		[[SimpleAudioEngine sharedEngine] setBackgroundMusicVolume:.1];
		[[SimpleAudioEngine sharedEngine] playBackgroundMusic:path loop:YES];
	});
	
	for(float volume = .1; volume <= prevVolume; volume+= .1) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, fadeInTimeOffset + volume * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
			[[SimpleAudioEngine sharedEngine] setBackgroundMusicVolume:volume];
		});
	}
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	NSString *title = [alertView buttonTitleAtIndex:buttonIndex];
	if([title isEqualToString:@"OK"])
	{

        // Then, call the purchase method.
		
        if (![_iapManager purchase:_iapManager.selectedProduct
						successCallback:^(bool isRestore){
						
							int availableCoins = [SettingsManager incrementIntBy:100 forKey:SETTING_TOTAL_AVAILABLE_COINS];
									
							NSString *alertMessage = [NSString stringWithFormat:@"Your purchase for %@ was %@. You now have %d coins. Enjoy!", _iapManager.selectedProduct.localizedTitle, (isRestore ? @"restored" : @"successful"), availableCoins];
							UIAlertView *updatedAlert = [[UIAlertView alloc] initWithTitle:@"Thank You!" message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
							[updatedAlert show];
							[updatedAlert release];
							
							//analytics logging
							NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSNumber numberWithInt:availableCoins], @"AvailableCoins",
							nil];
							[Analytics logEvent:@"LevelPackSelectLayer_Buy_Coins" withParameters:flurryParams];
									
							[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[LevelPackSelectLayer scene] ]];
						
						}]) {
            // Returned NO, so notify user that In-App Purchase is Disabled in their Settings.
            UIAlertView *settingsAlert = [[UIAlertView alloc] initWithTitle:@"Allow Purchases" message:@"You must first enable In-App Purchase in your iOS Settings before making this purchase." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [settingsAlert show];
            [settingsAlert release];
        }
	}else {
		
		//analytics logging
		int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:availableCoins], @"AvailableCoins",
		nil];
		[Analytics logEvent:@"LevelPackSelectLayer_Ignore_Buy_Coins" withParameters:flurryParams];
	}
	
	
}



-(void) onEnter
{
	[super onEnter];

}


-(void) onExit {
	if(DEBUG_MEMORY) DebugLog(@"LevelPackSelectLayer onExit");

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}	

	[super onExit];
}


-(void) dealloc
{
	if(DEBUG_MEMORY) DebugLog(@"LevelPackSelectLayer dealloc");

	//[[CCTextureCache sharedTextureCache] dumpCachedTextureInfo];

	[_iapManager release];

	[_spriteNameToLevelPackPath release];
	
	[_scrollLayer release];
	
	[_levelLoader release];
	_levelLoader = nil;

	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();
}


@end
