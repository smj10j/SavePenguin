//
//  MainMenuLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "MainMenuLayer.h"
#import "IntroLayer.h"
#import "AboutLayer.h"
#import "InAppPurchaseLayer.h"
#import "LevelPackSelectLayer.h"
#import "GameLayer.h"
#import "SimpleAudioEngine.h"
#import "Utilities.h"
#import "Analytics.h"


#pragma mark - MainMenuLayer

@implementation MainMenuLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	MainMenuLayer *layer = [MainMenuLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(instancetype) init
{
	if( (self=[super init])) {
		
		self.isTouchEnabled = YES;

		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		
		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"MainMenu"]];
		[_levelLoader addObjectsToWorld:nil cocos2dLayer:self];
		
		
		LHSprite* playButton = [_levelLoader createSpriteWithName:@"Play_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[playButton prepareAnimationNamed:@"Menu_Play_Button" fromSHScene:@"Spritesheet"];
		[playButton transformPosition: ccp(winSize.width/2, winSize.height/2)];
		[playButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[playButton registerTouchEndedObserver:self selector:@selector(onPlay:)];

		LHSprite* IAPButton = [_levelLoader createSpriteWithName:@"IAP_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[IAPButton prepareAnimationNamed:@"Menu_IAP_Button" fromSHScene:@"Spritesheet"];
		[IAPButton transformPosition: ccp(
								20*SCALING_FACTOR_H + IAPButton.boundingBox.size.width/2,
								20*SCALING_FACTOR_V + IAPButton.boundingBox.size.height/2)];
		[IAPButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[IAPButton registerTouchEndedObserver:self selector:@selector(onIAP:)];
				
		
		LHSprite* infoButton = [_levelLoader createSpriteWithName:@"Info_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[infoButton prepareAnimationNamed:@"Menu_Info_Button" fromSHScene:@"Spritesheet"];
		[infoButton transformPosition: ccp(
								winSize.width - 20*SCALING_FACTOR_H - infoButton.boundingBox.size.width/2,
								20*SCALING_FACTOR_V + infoButton.boundingBox.size.height/2)];
		[infoButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[infoButton registerTouchEndedObserver:self selector:@selector(onInfo:)];

		LHSprite* toggleSoundButton = [_levelLoader createSpriteWithName:@"Sound_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[toggleSoundButton prepareAnimationNamed:@"Menu_Sound_Button" fromSHScene:@"Spritesheet"];
		[toggleSoundButton transformPosition: ccp(
								winSize.width - 40*SCALING_FACTOR_H - toggleSoundButton.boundingBox.size.width/2 - infoButton.boundingBox.size.width,
								20*SCALING_FACTOR_V + toggleSoundButton.boundingBox.size.height/2)];
		[toggleSoundButton registerTouchBeganObserver:self selector:@selector(ignoreTouch:)];
		[toggleSoundButton registerTouchEndedObserver:self selector:@selector(onToggleSound:)];

		LHSprite* toggleMusicButton = [_levelLoader createSpriteWithName:@"Music_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[toggleMusicButton prepareAnimationNamed:@"Menu_Music_Button" fromSHScene:@"Spritesheet"];
		[toggleMusicButton transformPosition: ccp(
								winSize.width - 60*SCALING_FACTOR_H - toggleMusicButton.boundingBox.size.width/2 - infoButton.boundingBox.size.width - toggleSoundButton.boundingBox.size.width,
								20*SCALING_FACTOR_V + toggleMusicButton.boundingBox.size.height/2)];
		[toggleMusicButton registerTouchBeganObserver:self selector:@selector(ignoreTouch:)];
		[toggleMusicButton registerTouchEndedObserver:self selector:@selector(onToggleMusic:)];

		
			
		bool isMusicEnabled = [SettingsManager boolForKey:SETTING_MUSIC_ENABLED];
		bool isSoundEnabled = [SettingsManager boolForKey:SETTING_SOUND_ENABLED];
	
		if(isMusicEnabled) {
			[toggleMusicButton setFrame:toggleMusicButton.currentFrame+1];	//active state
		}
		if(isSoundEnabled) {
			[toggleSoundButton setFrame:toggleSoundButton.currentFrame+1];	//active state
		}
		DebugLog(@"Music is %@. Sound is %@", isMusicEnabled ? @"ON": @"OFF", isSoundEnabled ? @"ON" : @"OFF");
		
		
		
		
		/*********** Sounds preloading ***********/
		[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/menu/button.wav"];


		if(isMusicEnabled && ![[SimpleAudioEngine sharedEngine] isBackgroundMusicPlaying]) {
			[self fadeInBackgroundMusic:@"sounds/menu/ambient/theme.mp3"];
		}

		[Analytics logEvent:@"View_Main_Menu"];
	}
		
	if(DEBUG_MEMORY) DebugLog(@"Initialized MainMenuLayer");
	if(DEBUG_MEMORY) report_memory();
	
	return self;
}

-(void)ignoreTouch:(LHTouchInfo*)info {}

-(void)onTouchBeganAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onPlay:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
	
	if(TEST_MODE) {
		//TESTING CODE
		
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[GameLayer sceneWithLevelPackPath:TEST_LEVEL_PACK levelPath:TEST_LEVEL]]];

	}else {
	
		if(![SettingsManager boolForKey:SETTING_HAS_SEEN_INTRO_STORYBOARD]) {
			[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:4.0 scene:[IntroLayer scene]]];
		}else {
			[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[LevelPackSelectLayer scene] ]];
		}
	}
}


-(void)onIAP:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	[SettingsManager remove:SETTING_LAST_LEVEL_PACK_PATH];
	[SettingsManager remove:SETTING_LAST_LEVEL_PATH];
	
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[InAppPurchaseLayer scene] ]];
}

-(void)onInfo:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	//[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];

	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[AboutLayer scene] ]];
}

-(void)onToggleSound:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	bool isSoundEnabled = [SettingsManager boolForKey:SETTING_SOUND_ENABLED];
	DebugLog(@"Sound was %d - setting to %d", isSoundEnabled, !isSoundEnabled);

	if(isSoundEnabled) {
		[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state

		[Analytics logEvent:@"Sound_Disabled"];
	}else {
		[info.sprite setFrame:info.sprite.currentFrame+1];	//active state

		[Analytics logEvent:@"Sound_Enabled"];
	}
	
	[SettingsManager setBool:!isSoundEnabled forKey:SETTING_SOUND_ENABLED];
	
	
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
}

-(void)onToggleMusic:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	bool isMusicEnabled = [SettingsManager boolForKey:SETTING_MUSIC_ENABLED];
	DebugLog(@"Music was %d - setting to %d", isMusicEnabled, !isMusicEnabled);

	if(isMusicEnabled) {
		[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
		[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
	
		[Analytics logEvent:@"Background_Music_Disabled"];
	
	}else {
		[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
		[self fadeInBackgroundMusic:@"sounds/menu/ambient/theme.mp3"];

		[Analytics logEvent:@"Background_Music_Enabled"];
	}
	
	
	[SettingsManager setBool:!isMusicEnabled forKey:SETTING_MUSIC_ENABLED];
}



-(void)fadeInBackgroundMusic:(NSString*)path {
	
	float prevVolume = [SimpleAudioEngine sharedEngine].backgroundMusicVolume;
	float fadeInTimeOffset = 0;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, fadeInTimeOffset * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
		[SimpleAudioEngine sharedEngine].backgroundMusicVolume = .1;
		[[SimpleAudioEngine sharedEngine] playBackgroundMusic:path loop:YES];
	});
	
	for(float volume = .1; volume <= prevVolume; volume+= .1) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, fadeInTimeOffset + volume * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
			[SimpleAudioEngine sharedEngine].backgroundMusicVolume = volume;
		});
	}
}




-(void) onEnter
{
	[super onEnter];
}


-(void) onExit {
	if(DEBUG_MEMORY) DebugLog(@"MainMenuLayer onExit");

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}
	
	[super onExit];
}

-(void) dealloc
{
	if(DEBUG_MEMORY) DebugLog(@"MainMenuLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();

}	
@end
