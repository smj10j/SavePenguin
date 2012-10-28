//
//  LevelSelectLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "LevelSelectLayer.h"
#import "LevelPackSelectLayer.h"
#import "GameLayer.h"
#import "LevelPackManager.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"


#pragma mark - LevelSelectLayer

@implementation LevelSelectLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) sceneWithLevelPackPath:(NSString*)levelPackPath 
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	LevelSelectLayer *layer = [LevelSelectLayer node];
	
	[layer loadLevelsWithLevelPackPath:levelPackPath];
	
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
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"LevelSelect"]];

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

	}
	
	NSLog(@"Initialized LevelSelectLayer");	
	
	return self;
}



-(void) loadLevelsWithLevelPackPath:(NSString*)levelPackPath {

	_levelPackPath = [levelPackPath retain];

	//load all available levels for this pack
	_levelsDictionary = [LevelPackManager allLevelsInPack:_levelPackPath];
	
	//load all levels for this pack that the user has completed
	_completedLevels = [LevelPackManager completedLevelsInPack:_levelPackPath];
	_availableLevels = [LevelPackManager availableLevelsInPack:_levelPackPath];
	_spriteNameToLevelPath = [[NSMutableDictionary alloc] init];
	
	
	CGSize winSize = [[CCDirector sharedDirector] winSize];

	LHSprite* levelButton = [_levelLoader createSpriteWithName:@"Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	const CGSize levelButtonSize = levelButton.boundingBox.size;
	const int levelButtonMargin = 50*SCALING_FACTOR_H;
	const int columns = winSize.width / (levelButtonMargin+levelButtonSize.width);
	const int levelButtonXInitial = winSize.width/2 - (columns/2 * (levelButtonSize.width+levelButtonMargin)) + (levelButtonSize.width+levelButtonMargin)/2;
	[levelButton removeSelf];

	int levelButtonX = levelButtonXInitial;
	int levelButtonY = winSize.height + levelButtonSize.height/2;

	for(int i = 0; i < _levelsDictionary.count; i++) {
	
		if(i%columns == 0) {
			//new row
			levelButtonY-= (levelButtonSize.height + levelButtonMargin);
			levelButtonX = levelButtonXInitial;
		}

		NSDictionary* levelData = [_levelsDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelName = [levelData objectForKey:LEVELPACKMANAGER_KEY_NAME];
		NSString* levelPath = [levelData objectForKey:LEVELPACKMANAGER_KEY_PATH];
		
		//create the sprite
		LHSprite* levelButton = [_levelLoader createSpriteWithName:@"Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[levelButton prepareAnimationNamed:@"Menu_Level_Select_Button" fromSHScene:@"Spritesheet"];

		bool isLocked = false;
		
		if([_completedLevels containsObject:levelPath]) {
			NSLog(@"Level %@ is completed!", levelPath);

			//add a checkmark on top
			LHSprite* completedMark = [_levelLoader createSpriteWithName:@"Level_Completed" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelButton];
			[completedMark transformPosition:ccp(levelButtonSize.width - completedMark.contentSize.width/2 - 20*SCALING_FACTOR_H,completedMark.contentSize.height/2 + 10*SCALING_FACTOR_V)];
			
			
		}else if([_availableLevels containsObject:levelPath]) {
			NSLog(@"Level %@ is available!", levelPath);

					
		}else {
			NSLog(@"Level %@ is NOT available!", levelPath);

			isLocked = true;

			//add a lock on top
			LHSprite* lockIcon = [_levelLoader createSpriteWithName:@"Level_Locked" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelButton];
			[lockIcon transformPosition:ccp(levelButtonSize.width - lockIcon.contentSize.width/2 - 20*SCALING_FACTOR_H,
											lockIcon.contentSize.height/2 + 10*SCALING_FACTOR_V)];

		}
		
		//display the level name
		CCLabelTTF* levelNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", levelName] fontName:@"Helvetica" fontSize:20*SCALING_FACTOR_FONTS dimensions:CGSizeMake(levelButtonSize.width-20*SCALING_FACTOR_H, levelButtonSize.height - 20*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentCenter vAlignment:kCCVerticalTextAlignmentCenter lineBreakMode:kCCLineBreakModeWordWrap];
		levelNameLabel.color = ccBLACK;
		levelNameLabel.position = ccp(levelButtonSize.width/2,levelButtonSize.height/2);
		[levelButton addChild:levelNameLabel];
		
		
		if(!isLocked) {
			//used when clicking the sprite
			[_spriteNameToLevelPath setObject:levelPath forKey:levelButton.uniqueName];
			[levelButton registerTouchBeganObserver:self selector:@selector(onTouchAnyButton:)];
			[levelButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelSelect:)];
		}
		
		
		
		//positioning
		[levelButton transformPosition: ccp(levelButtonX, levelButtonY)];
		levelButtonX+= levelButtonSize.width + levelButtonMargin;
	}

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
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:_levelPackPath levelPath:[_spriteNameToLevelPath objectForKey:info.sprite.uniqueName]] ]];
}


-(void)onTouchEndedBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelPackSelectLayer scene] ]];
}


-(void) onEnter
{
	[super onEnter];

}


-(void) dealloc
{
	NSLog(@"LevelSelectLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	delete _world;
	_world = NULL;
	
	[super dealloc];
}

@end
