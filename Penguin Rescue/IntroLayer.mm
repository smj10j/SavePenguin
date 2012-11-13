//
//  IntroLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "IntroLayer.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"
#import "LevelPackManager.h"
#import "Analytics.h"
#import "Utilities.h"
#import "GameLayer.h"
#import "APIManager.h"

#pragma mark - IntroLayer

@implementation IntroLayer

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
			
		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"Blank"]];
		[_levelLoader addObjectsToWorld:nil cocos2dLayer:self];
				
		LHSprite* panel1 = [_levelLoader createSpriteWithName:@"Panel1" fromSheet:@"Intro1" fromSHFile:@"Spritesheet"];
		_panelSize = panel1.contentSize;
		[panel1 transformPosition:ccp(_panelSize.width/2,_panelSize.height*3/2)];
		
		LHSprite* panel2 = [_levelLoader createSpriteWithName:@"Panel2" fromSheet:@"Intro1" fromSHFile:@"Spritesheet"];
		[panel2 transformPosition:ccp(_panelSize.width*3/2,_panelSize.height*3/2)];
		LHSprite* panel3 = [_levelLoader createSpriteWithName:@"Panel3" fromSheet:@"Intro2" fromSHFile:@"Spritesheet"];
		[panel3 transformPosition:ccp(_panelSize.width*3/2,_panelSize.height/2)];
		LHSprite* panel4 = [_levelLoader createSpriteWithName:@"Panel4" fromSheet:@"Intro2" fromSHFile:@"Spritesheet"];
		[panel4 transformPosition:ccp(_panelSize.width/2,_panelSize.height/2)];

		CCLayerColor* background = [[CCLayerColor alloc] initWithColor:ccc4(0, 0, 0, 255) width:_panelSize.width*2 height:_panelSize.width*2];
		[[_levelLoader layerWithUniqueName:@"MAIN_LAYER"] addChild:background];
		
		background.zOrder = 1;
		panel1.zOrder = 2;
		panel2.zOrder = 2;
		panel3.zOrder = 2;
		panel4.zOrder = 2;
		
		if([SettingsManager boolForKey:SETTING_MUSIC_ENABLED] && ![[SimpleAudioEngine sharedEngine] isBackgroundMusicPlaying]) {
			[[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"sounds/menu/ambient/menu.mp3" loop:YES];
		}
		
		[SettingsManager setBool:true forKey:SETTING_HAS_SEEN_INTRO_STORYBOARD];
	}

	if(DEBUG_MEMORY) DebugLog(@"Initialized IntroLayer");	
	
	return self;
}

-(void) onEnter {

	[super onEnter];
	
	self.position = ccp(0, -_panelSize.height);

	[self runAction:[CCSequence actions:
		[CCDelayTime actionWithDuration:10],
		[CCMoveBy actionWithDuration:0.5 position:ccp(-_panelSize.width, 0)],
		[CCDelayTime actionWithDuration:3],
		[CCMoveBy actionWithDuration:0.5 position:ccp(0, _panelSize.height)],
		//[CCDelayTime actionWithDuration:4],
		//[CCMoveBy actionWithDuration:0.5 position:ccp(_panelSize.width, 0)],
		[CCDelayTime actionWithDuration:3],
		[CCCallBlock actionWithBlock:^{
			for(LHSprite* sprite in [_levelLoader allSprites]) {
				[sprite runAction:[CCFadeOut actionWithDuration:5]];
			}
			[self showGameLayer];
		}],
		nil]
	];

}

-(void)showGameLayer {
	NSString* lastLevelPackPath = [SettingsManager stringForKey:SETTING_LAST_LEVEL_PACK_PATH];
	NSString* lastLevelPath = [SettingsManager stringForKey:SETTING_LAST_LEVEL_PATH];

	if(lastLevelPackPath == nil) {
		//get the first level pack and level
		NSArray* availableLevelPacks = [LevelPackManager availablePacks];
		lastLevelPackPath = [availableLevelPacks objectAtIndex:0];
		lastLevelPath = [LevelPackManager levelAfter:nil inPack:lastLevelPackPath];
	}

	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:3 scene:[GameLayer sceneWithLevelPackPath:lastLevelPackPath levelPath:lastLevelPath] ]];

}

-(void) onExit {
	[super onExit];
	if(DEBUG_MEMORY) DebugLog(@"IntroLayer onExit");	
}

-(void) dealloc
{
	if(DEBUG_MEMORY) DebugLog(@"IntroLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();

}	

@end
