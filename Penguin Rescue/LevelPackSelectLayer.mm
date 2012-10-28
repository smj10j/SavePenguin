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
		
		self.isTouchEnabled = YES;

		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"LevelPackSelect"]];

		b2Vec2 gravity;
		gravity.Set(0.0f, 0.0f);
		_world = new b2World(gravity);

		//create all objects from the level file and adds them to the cocos2d layer (self)
		[_levelLoader addObjectsToWorld:_world cocos2dLayer:self];
		
		
		LHSprite* backButton = [_levelLoader createSpriteWithName:@"Back_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[backButton prepareAnimationNamed:@"Menu_Back_Button" fromSHScene:@"Spritesheet"];
		[backButton transformPosition: ccp(20*SCALING_FACTOR_H + backButton.boundingBox.size.width/2,
											20*SCALING_FACTOR_V + backButton.boundingBox.size.height/2)];
		[backButton registerTouchBeganObserver:self selector:@selector(onTouchAnyButton:)];
		[backButton registerTouchEndedObserver:self selector:@selector(onTouchEndedBack:)];
		
		[self loadLevelPacks];
	}
	
	NSLog(@"Initialized LevelPackSelectLayer");
	
	return self;
}




-(void) loadLevelPacks {

	//load all available level packs
	_levelPacksDictionary = [LevelPackManager allLevelPacks];

	//load ones the user has completed
	_completedLevelPacks = [LevelPackManager completedPacks];
	_availableLevelPacks = [LevelPackManager availablePacks];
	_spriteNameToLevelPackPath = [[NSMutableDictionary alloc] init];


	NSMutableArray* scrollableLayers = [[NSMutableArray alloc] init];

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	LHSprite* levelPackButton = [_levelLoader createSpriteWithName:@"Level_Pack_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	const CGSize levelPackButtonSize = levelPackButton.boundingBox.size;
	[levelPackButton removeSelf];
			
	for(int i = 0; i < _levelPacksDictionary.count; i++) {
	
		CCLayer* scrollableLayer = [[CCLayer alloc] init];
		[scrollableLayers addObject:scrollableLayer];

		NSDictionary* levelPackData = [_levelPacksDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelPackName = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_NAME];
		NSString* levelPackPath = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_PATH];
		NSArray* completedLevels = [LevelPackManager completedLevelsInPack:levelPackPath];
		NSDictionary* allLevels = [LevelPackManager allLevelsInPack:levelPackPath];

		//create the sprite
		//TODO: this can cause a crash with LevelHelper because of the same sprite/touch delegate issue
		LHSprite* levelPackButton = [_levelLoader createSpriteWithName:@"Level_Pack_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:scrollableLayer];
		[levelPackButton prepareAnimationNamed:@"Menu_Level_Pack_Select_Button" fromSHScene:@"Spritesheet"];

		//display the pack background
		CCSprite* packBackground = [CCSprite spriteWithFile:[NSString stringWithFormat:@"Levels/%@/%@", levelPackPath, @"IconBackground.png"]];
		packBackground.scale = levelPackButton.contentSize.width/packBackground.contentSize.width;
		packBackground.position = ccp(levelPackButtonSize.width/2,levelPackButtonSize.height/2);
		packBackground.opacity = 200;
		[levelPackButton addChild:packBackground];
		
		bool isLocked = false;

		if([_completedLevelPacks containsObject:levelPackPath]) {
			NSLog(@"Pack %@ is completed!", levelPackPath);

			//add a checkmark on top
			LHSprite* completedMark = [_levelLoader createSpriteWithName:@"Level_Pack_Completed" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelPackButton];
			[completedMark transformPosition:ccp(levelPackButtonSize.width/2,levelPackButtonSize.height/2)];
					
		}else if([_availableLevelPacks containsObject:levelPackPath]) {
			NSLog(@"Pack %@ is available!", levelPackPath);
					
		}else {
			NSLog(@"Pack %@ is NOT available!", levelPackPath);

			//add a lock on top
			LHSprite* lockIcon = [_levelLoader createSpriteWithName:@"Level_Pack_Locked" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelPackButton];
			[lockIcon transformPosition:ccp(levelPackButtonSize.width/2,levelPackButtonSize.height/2)];
			
			isLocked = true;
		}
		
		
		//display the pack name
		CCLabelTTF* packNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", levelPackName] fontName:@"Helvetica" fontSize:36*SCALING_FACTOR_FONTS];
		packNameLabel.color = ccWHITE;
		packNameLabel.position = ccp(levelPackButtonSize.width/2,levelPackButtonSize.height + 40*SCALING_FACTOR_V);
		[levelPackButton addChild:packNameLabel];
		
		
		
		if(!isLocked) {
		
			//used when clicking the sprite
			[_spriteNameToLevelPackPath setObject:levelPackPath forKey:levelPackButton.uniqueName];
			[levelPackButton registerTouchBeganObserver:self selector:@selector(onTouchAnyButton:)];
			[levelPackButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelSelect:)];

			//display the % completion
			double percentComplete = (double)completedLevels.count/(allLevels.count > 0 ? allLevels.count : 1) * 100.0;
			CCLabelTTF* percentCompleteLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%% complete", (int)percentComplete] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS];
			percentCompleteLabel.color = ccWHITE;
			percentCompleteLabel.position = ccp(levelPackButtonSize.width/2, -25*SCALING_FACTOR_V);
			[levelPackButton addChild:percentCompleteLabel];
			
		}
		
		
		//positioning
		[levelPackButton transformPosition: ccp(winSize.width/2, winSize.height/2 + 20*SCALING_FACTOR_V)];
	}
	
	
	// now create the scroller and pass-in the pages (set widthOffset to 0 for fullscreen pages)
	CCScrollLayer *scroller = [[CCScrollLayer alloc] initWithLayers:scrollableLayers widthOffset: 230];

	// finally add the scroller to your scene
	[self addChild:scroller];

}





/************* Touch handlers ***************/

-(void)onTouchAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
}

-(void)onTouchEndedLevelSelect:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelSelectLayer sceneWithLevelPackPath:[_spriteNameToLevelPackPath objectForKey:info.sprite.uniqueName]] ]];
}


-(void)onTouchEndedBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[MainMenuLayer scene] ]];
}


-(void) onEnter
{
	[super onEnter];

}


-(void) dealloc
{
	NSLog(@"LevelPackSelectLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	delete _world;
	_world = NULL;
	
	[super dealloc];
}	


@end
