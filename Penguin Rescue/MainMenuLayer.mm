//
//  MainMenuLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "MainMenuLayer.h"
#import "AboutLayer.h"
#import "LevelPackSelectLayer.h"
#import "GameLayer.h"
#import "SimpleAudioEngine.h"


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
-(id) init
{
	if( (self=[super init])) {
		
		self.isTouchEnabled = YES;

		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		
		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"MainMenu"]];

		
		LHSprite* playButton = [_levelLoader createSpriteWithName:@"Play_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[playButton prepareAnimationNamed:@"Menu_Play_Button" fromSHScene:@"Spritesheet"];
		[playButton transformPosition: ccp(winSize.width/2, winSize.height/2)];
		[playButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[playButton registerTouchEndedObserver:self selector:@selector(onPlay:)];
		
		
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
		[toggleSoundButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[toggleSoundButton registerTouchEndedObserver:self selector:@selector(onToggleSound:)];

		LHSprite* toggleMusicButton = [_levelLoader createSpriteWithName:@"Music_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[toggleMusicButton prepareAnimationNamed:@"Menu_Music_Button" fromSHScene:@"Spritesheet"];
		[toggleMusicButton transformPosition: ccp(
								winSize.width - 60*SCALING_FACTOR_H - toggleMusicButton.boundingBox.size.width/2 - infoButton.boundingBox.size.width - toggleSoundButton.boundingBox.size.width,
								20*SCALING_FACTOR_V + toggleMusicButton.boundingBox.size.height/2)];
		[toggleMusicButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[toggleMusicButton registerTouchEndedObserver:self selector:@selector(onToggleMusic:)];

		
			
		bool isMusicEnabled = [SettingsManager boolForKey:@"MusicEnabled"];
		bool isSoundEnabled = [SettingsManager boolForKey:@"SoundEnabled"];
	
		if(isMusicEnabled) {
			[toggleMusicButton setFrame:toggleMusicButton.currentFrame+1];	//active state
		}
		if(isSoundEnabled) {
			[toggleSoundButton setFrame:toggleSoundButton.currentFrame+1];	//active state
		}
		NSLog(@"Music is %@. Sound is %@", isMusicEnabled ? @"ON": @"OFF", isSoundEnabled ? @"ON" : @"OFF");
		
		
		
		
		/*********** Sounds preloading ***********/
		[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/menu/button.wav"];


		if(isMusicEnabled && ![[SimpleAudioEngine sharedEngine] isBackgroundMusicPlaying]) {
			[[SimpleAudioEngine sharedEngine] preloadBackgroundMusic:@"sounds/menu/background.wav"];
			[[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"sounds/menu/background.wav" loop:YES];
		}
	}
	
	NSLog(@"Initialized MainMenuLayer");
	
	return self;
}

-(void)onTouchBeganAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
}

-(void)onPlay:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	if(TEST_MODE) {
		//TESTING CODE
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:TEST_LEVEL_PACK levelPath:TEST_LEVEL]]];

	}else {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelPackSelectLayer scene] ]];
	}
}

-(void)onInfo:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[AboutLayer scene] ]];
}

-(void)onToggleSound:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state

	bool isSoundEnabled = [SettingsManager boolForKey:@"SoundEnabled"];
	NSLog(@"Sound was %d - setting to %d", isSoundEnabled, !isSoundEnabled);

	if(isSoundEnabled) {
		[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	}else {
		[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	}
	
	[SettingsManager setBool:!isSoundEnabled forKey:@"SoundEnabled"];
	
	
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
}

-(void)onToggleMusic:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	bool isMusicEnabled = [SettingsManager boolForKey:@"MusicEnabled"];
	NSLog(@"Music was %d - setting to %d", isMusicEnabled, !isMusicEnabled);

	if(isMusicEnabled) {
		[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
		[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
	}else {
		[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
		[[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"sounds/menu/background.wav" loop:YES];
	}
	
	
	[SettingsManager setBool:!isMusicEnabled forKey:@"MusicEnabled"];
}




-(void) onEnter
{
	[super onEnter];
}

-(void) dealloc
{
	NSLog(@"MainMenuLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
}	
@end
