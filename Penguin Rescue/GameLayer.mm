//
//  GameLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//

// Import the interfaces
#import "GameLayer.h"

// Not included in "cocos2d.h"
#import "CCPhysicsSprite.h"

// Needed to obtain the Navigation Controller
#import "AppDelegate.h"

#import "LevelSelectLayer.h"
#import "LevelPackSelectLayer.h"
#import "InAppPurchaseLayer.h"
#import "MainMenuLayer.h"
#import "MoveGridData.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"
#import "APIManager.h"

#import "WindmillRaycastCallback.h"
#import "Utilities.h"
#import "Analytics.h"

#pragma mark - GameLayer

@implementation GameLayer

+(CCScene *) sceneWithLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [GameLayer node];
	
	[layer startLevelWithLevelPackPath:levelPackPath levelPath:levelPath];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

-(id) init
{
	if( (self=[super initWithColor:ccc4(100, 100, 255, 50)])) {
						
		// enable events
		self.isTouchEnabled = YES;
		
		_state = SETUP;
		_instanceId = [[NSDate date] timeIntervalSince1970];
		_box2dStepAccumulator = 0;
		DebugLog(@"Initializing GameLayer %f", _instanceId);
		_inGameMenuItems = [[NSMutableArray alloc] init];
		//_moveGridSharkUpdateQueue = dispatch_queue_create("com.conquerllc.games.Penguin-Rescue.moveGridSharkUpdateQueue", 0);	//serial
		//_moveGridPenguinUpdateQueue = dispatch_queue_create("com.conquerllc.games.Penguin-Rescue.moveGridPenguinUpdateQueue", 0);	//serial
		_moveGridSharkUpdateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);	//concurrent
		_moveGridPenguinUpdateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);	//concurrent
		_isGeneratingFeatureGrid = false;
		_isInvalidatingSharkFeatureGrids = false;
		_isInvalidatingPenguinFeatureGrids = false;
		_sharksThatNeedToUpdateFeatureGrids = [[NSMutableArray alloc] init];
		_penguinsThatNeedToUpdateFeatureGrids = [[NSMutableArray alloc] init];
		_numSharksUpdatingMoveGrids = 0;
		_numPenguinsUpdatingMoveGrids = 0;
		_activeToolboxItem = nil;
		_activeToolboxItemSelectionTimestamp = 0;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = false;
		_penguinsToPutOnLand =[[NSMutableDictionary alloc] init];
		_placedToolboxItems = [[NSMutableArray alloc] init];
		_scoreKeeper = [[ScoreKeeper alloc] init];
		_handOfGodPowerSecondsRemaining = HAND_OF_GOD_INITIAL_POWER;
		_handOfGodPowerSecondsUsed = 0;
		_isNudgingPenguin = false;
		_levelHasMovingBorders = false;
		_levelHasMovingLands = false;
		__DEBUG_SHARKS = DEBUG_SHARK;
		__DEBUG_PENGUINS = DEBUG_PENGUIN;
		__DEBUG_TOUCH_SECONDS = 0;
		if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {
			self.color = ccBLACK;
		}
		__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
		
		// init physics
		[self initPhysics];
		
		[self preloadSounds];

		if(DEBUG_MEMORY) DebugLog(@"GameLayer %f initialized", _instanceId);
		if(DEBUG_MEMORY) report_memory();
	}
	
	
	return self;
}

-(void) startLevelWithLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {

	_levelPath = [levelPath retain];
	_levelPackPath = [levelPackPath retain];
	_levelData =  [LevelPackManager level:_levelPath inPack:_levelPackPath];
	[self loadLevel:_levelPath inLevelPack:_levelPackPath];
		
	//set the grid size and create various arrays
	[self initializeMapGrid];
	
	//create any items that have been purchased and prepare anything that updateToolbox will use
	[self setupToolbox];
	
	//place the toolbox items
	[self updateToolbox];
	
	//various handlers
	[self setupCollisionHandling];

	//place the HUD items (pause, restart, etc.)
	[self drawHUD];		

	//place any moving doodads
	[self setupDoodads];
	
	//start any moving borders
	[self setupMovingBorders];
	
	//record the play
	//post the score to the server or queue for online processing
	[ScoreKeeper savePlayForUUID:[SettingsManager getUUID] levelPackPath:_levelPackPath levelPath:_levelPath];

	//enable any debugging requested
	if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {
		self.color = ccBLACK;
		NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
		for(LHSprite* background in backgrounds) {
			[background setVisible:false];
		}		
	}

	//start the game
	_state = PLACE;
	_levelStartPlaceTime  = [[NSDate date] timeIntervalSince1970];
	_levelPlaceTimeDuration = 0;
	_levelRunningTimeDuration = 0;

	[self scheduleUpdate];
	
	
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Begin_Level" withParameters:flurryParams timed:YES];

	if(DEBUG_MEMORY) DebugLog(@"GameLayer %f level loaded", _instanceId);
	if(DEBUG_MEMORY) report_memory();

}

-(void) preloadSounds {

	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/button.wav"];
	
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/pickup.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/return.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/rotate.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-obstruction.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-debris.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-windmill.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-whirlpool.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-sandboar.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-bag-of-fish.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-invisibility-hat.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-loud-noise.wav"];

	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/levelLost/hoot.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/levelWon/reward.mp3"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/levelWon/thud.wav"];

}

-(void) initPhysics
{
	DebugLog(@"Initializing physics...");
	b2Vec2 gravity;
	gravity.Set(0.0f, 0.0f);
	_world = new b2World(gravity);
	
	// Do we want to let bodies sleep?
	_world->SetAllowSleeping(true);
	
	_world->SetContinuousPhysics(true);
	
	if(DEBUG_ALL_THE_THINGS) {
		_debugDraw = new GLESDebugDraw( PTM_RATIO );
		_world->SetDebugDraw(_debugDraw);
		
		uint32 flags = 0;
		flags += b2Draw::e_shapeBit;
		//		flags += b2Draw::e_jointBit;
		//		flags += b2Draw::e_aabbBit;
		//		flags += b2Draw::e_pairBit;
		//		flags += b2Draw::e_centerOfMassBit;
		_debugDraw->SetFlags(flags);
	}
}

-(void) initializeMapGrid {
	
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	CGSize winSizeInPixels = [[CCDirector sharedDirector] winSizeInPixels];
			
	//device adjustments
	if(winSize.width == 480) {
		//iPhone
		if(winSizeInPixels.width == 480) {
			//low-res - probably a slower processor
			_gridSize = 16;
			DebugLog(@"Using a grid size for an older iPhone");
		}else {
			//high-res 4+
			_gridSize = 8;
			DebugLog(@"Using a grid size for a newer iPhone");
		}
	}else {
		//iPad
		if(winSizeInPixels.width == 1024) {
			//low-res - probably a slower processor
			_gridSize = 20;
			DebugLog(@"Using a grid size for an older iPad");
		}else {
			//high-res 4+
			_gridSize = 12;
			DebugLog(@"Using a grid size for a newer iPad");
		}
	}
	
	double minScale = 1;
	NSMutableArray* actors = [[NSMutableArray alloc] initWithArray:[_levelLoader spritesWithTag:SHARK]];
	[actors addObjectsFromArray:[_levelLoader spritesWithTag:PENGUIN]];
	for(LHSprite* actor in actors) {
		if(actor.scale < minScale) {
			minScale = actor.scale;
		}
	}
	[actors release];
	
	if(minScale < 1 && _gridSize > MIN_GRID_SIZE) {
		_gridSize*= minScale;
		DebugLog(@"Scaling down gridSize by %f to %d to account for scaled down actors", minScale, _gridSize);
	}

		
	_gridWidth = ceil(_levelSize.width/_gridSize);
	_gridHeight = ceil(_levelSize.height/_gridSize);

	DebugLog(@"Setting up grid with size=%d, width=%d, height=%d", _gridSize, _gridWidth, _gridHeight);

	_sharkMapfeaturesGrid = new short*[_gridWidth];
	_penguinMapfeaturesGrid = new short*[_gridWidth];
	for(int i = 0; i < _gridWidth; i++) {
		_sharkMapfeaturesGrid[i] = new short[_gridHeight];
		_penguinMapfeaturesGrid[i] = new short[_gridHeight];
		for(int j = 0; j < _gridHeight; j++) {
			_sharkMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
			_penguinMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
		}
	}
	
	//filled in generateFeatureGrids
	_sharkMoveGridDatas = [[NSMutableDictionary alloc] init];
	_penguinMoveGridDatas = [[NSMutableDictionary alloc] init];
	
	//forces an update to all grids
	[self invalidateFeatureGridsNear:nil];
}

-(CGPoint) toGrid:(CGPoint)pos {
	return ccp((int)pos.x/_gridSize,(int)pos.y/_gridSize);
}

-(CGPoint) fromGrid:(CGPoint)pos {
	return ccp((int)(pos.x*_gridSize),(int)(pos.y*_gridSize));
}

-(void) setupCollisionHandling
{
    [_levelLoader useLevelHelperCollisionHandling];
	[_levelLoader registerBeginOrEndCollisionCallbackBetweenTagA:LAND andTagB:PENGUIN idListener:self selListener:@selector(landPenguinCollision:)];
    [_levelLoader registerBeginOrEndCollisionCallbackBetweenTagA:SHARK andTagB:PENGUIN idListener:self selListener:@selector(sharkPenguinCollision:)];
}

-(void) drawHUD {
	DebugLog(@"Drawing HUD");

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	_playPauseButton = [_levelLoader createSpriteWithName:@"Play_inactive" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
	[_playPauseButton prepareAnimationNamed:@"Play_Pause_Button" fromSHScene:@"Spritesheet"];
	[_playPauseButton transformPosition: ccp(_playPauseButton.boundingBox.size.width/2+HUD_BUTTON_MARGIN_H,_playPauseButton.boundingBox.size.height/2+HUD_BUTTON_MARGIN_V)];
	[_playPauseButton registerTouchBeganObserver:self selector:@selector(onTouchBeganPlayPause:)];
	[_playPauseButton registerTouchEndedObserver:self selector:@selector(onTouchEndedPlayPause:)];
				
	_restartButton = [_levelLoader createSpriteWithName:@"Restart_inactive" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
	[_restartButton prepareAnimationNamed:@"Restart_Button" fromSHScene:@"Spritesheet"];
	[_restartButton transformPosition: ccp(winSize.width - (_restartButton.boundingBox.size.width/2+HUD_BUTTON_MARGIN_H),_restartButton.boundingBox.size.height/2+HUD_BUTTON_MARGIN_V) ];
	[_restartButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[_restartButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];
		
	
	LHSprite* levelsMenuButton = [_levelLoader createSpriteWithName:@"Levels_In_Game_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	[levelsMenuButton prepareAnimationNamed:@"Menu_Levels_Menu_In_Game_Button" fromSHScene:@"Spritesheet"];
	[levelsMenuButton transformPosition: ccp(-levelsMenuButton.contentSize.width/2, -levelsMenuButton.contentSize.height/2) ];
	levelsMenuButton.opacity = 0;
	[levelsMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelsMenu:)];
	[levelsMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelsMenu:)];
	[_inGameMenuItems addObject:levelsMenuButton];
		
	LHSprite* mainMenuButton = [_levelLoader createSpriteWithName:@"Main_Menu_In_Game_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	[mainMenuButton prepareAnimationNamed:@"Menu_Main_Menu_In_Game_Button" fromSHScene:@"Spritesheet"];
	[mainMenuButton transformPosition: ccp(-mainMenuButton.contentSize.width/2, -mainMenuButton.contentSize.height/2) ];
	mainMenuButton.opacity = 0;
	[mainMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganMainMenu:)];
	[mainMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedMainMenu:)];
	[_inGameMenuItems addObject:mainMenuButton];

	LHSprite* IAPMenuButton = [_levelLoader createSpriteWithName:@"IAP_In_Game_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	[IAPMenuButton prepareAnimationNamed:@"Menu_IAP_In_Game_Button" fromSHScene:@"Spritesheet"];
	[IAPMenuButton transformPosition: ccp(-IAPMenuButton.contentSize.width/2, -IAPMenuButton.contentSize.height/2) ];
	IAPMenuButton.opacity = 0;
	[IAPMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganIAPMenu:)];
	[IAPMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedIAPMenu:)];
	[_inGameMenuItems addObject:IAPMenuButton];
		
		
		
	//show the level name at the top
	LHSprite* timeAndLevelPopup = [_levelLoader createSpriteWithName:@"Time_and_Level_Popup" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
	[timeAndLevelPopup transformPosition: ccp(winSize.width/2,winSize.height+timeAndLevelPopup.boundingBox.size.height/2)];
	CCLabelTTF* levelNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"Level: %@", [_levelData objectForKey:LEVELPACKMANAGER_KEY_NAME]] fontName:@"Helvetica" fontSize:18*SCALING_FACTOR_FONTS];
	levelNameLabel.color = ccBLACK;
	levelNameLabel.position = ccp(timeAndLevelPopup.boundingBox.size.width/2, timeAndLevelPopup.boundingBox.size.height - timeAndLevelPopup.boundingBox.size.height/4);
	[timeAndLevelPopup addChild:levelNameLabel];
	_timeElapsedLabel = [CCLabelTTF labelWithString:@"" fontName:@"Helvetica" fontSize:18*SCALING_FACTOR_FONTS];
	_timeElapsedLabel.color = ccBLACK;
	_timeElapsedLabel.position = ccp(timeAndLevelPopup.boundingBox.size.width/2, timeAndLevelPopup.boundingBox.size.height/4 + 2*SCALING_FACTOR_V);
	[timeAndLevelPopup addChild:_timeElapsedLabel];
		
	[timeAndLevelPopup runAction:[CCSequence actions:
		[CCDelayTime actionWithDuration:1.5f],
		[CCMoveBy actionWithDuration:0.5f position:ccp(0,-timeAndLevelPopup.boundingBox.size.height)],
		[CCDelayTime actionWithDuration:2.5f],
		[CCMoveBy actionWithDuration:0.5f position:ccp(0,timeAndLevelPopup.boundingBox.size.height/2 + 4*SCALING_FACTOR_V)],
		nil]];	
}

-(void) setupDoodads {

	NSArray* doodads = [_levelLoader spritesWithTag:DOODAD];
	for(LHSprite* doodad in doodads) {
		if([doodad.userInfoClassName isEqualToString:@"MovingDoodad"]) {
		
			//move it into the main layer so it's under the HUD but above actors
			if(doodad.parent == _mapBatchNode) {
				[_mapBatchNode removeChild:doodad cleanup:NO];
			}
			[_mainLayer addChild:doodad];
			doodad.zOrder = _actorsBatchNode.zOrder+1;
		
						
			MovingDoodad* doodadData = ((MovingDoodad*)doodad.userInfo);
		
			[doodad prepareMovementOnPathWithUniqueName:doodadData.pathName];
			
			
			if(doodadData.followXAxis) {
				[doodad setPathMovementOrientation:LH_X_AXIT_ORIENTATION];
			}else {
				[doodad setPathMovementOrientation:LH_Y_AXIS_ORIENTATION];
			}
			[doodad setPathMovementRestartsAtOtherEnd:doodadData.restartAtOtherEnd];
			[doodad setPathMovementIsCyclic:doodadData.isCyclic];
			[doodad setPathMovementSpeed:doodadData.timeToCompletePath]; //moving from start to end in X seconds
			
			[doodad startPathMovement];
		}
	}
}

-(void) setupMovingBorders {

	NSArray* borders = [_levelLoader spritesWithTag:BORDER];
	NSMutableArray* bordersAndLands = [NSMutableArray arrayWithArray:[_levelLoader spritesWithTag:LAND]];
	[bordersAndLands addObjectsFromArray:borders];
	
	for(LHSprite* sprite in bordersAndLands) {
		if([sprite.userInfoClassName isEqualToString:@"MovingBorder"] || [sprite.userInfoClassName isEqualToString:@"MovingLand"]) {
		
			//MovingBorder and MovingLand classes are identical as of now
			MovingBorder* borderData = ((MovingBorder*)sprite.userInfo);
		
			[sprite prepareMovementOnPathWithUniqueName:borderData.pathName];
			
			if(borderData.followXAxis) {
				[sprite setPathMovementOrientation:LH_X_AXIT_ORIENTATION];
			}else if(borderData.followYAxis) {
				[sprite setPathMovementOrientation:LH_Y_AXIS_ORIENTATION];
			}else {
				[sprite setPathMovementOrientation:LH_NO_ORIENTATION];			
			}
			[sprite setPathMovementRestartsAtOtherEnd:borderData.restartAtOtherEnd];
			[sprite setPathMovementIsCyclic:borderData.isCyclic];
			[sprite setPathMovementSpeed:borderData.timeToCompletePath]; //moving from start to end in X seconds
			
			[sprite startPathMovement];
			
			if([sprite.userInfoClassName isEqualToString:@"MovingBorder"]) {
				_levelHasMovingBorders = true;
			}else {
				_levelHasMovingLands = true;
			}
		}
	}
	
	if(_levelHasMovingBorders) {
		[self schedule:@selector(invalidateFeatureGridsNearMovingBorders) interval:0.4f];
	}
	if(!_levelHasMovingBorders && _levelHasMovingLands) {
		[self schedule:@selector(invalidateFeatureGridsNearMovingLands) interval:0.4f];
	}
}

-(void) setupToolbox {
	
	//placeholder for now

	[self createIAPToolboxItems];
}

-(void) createIAPToolboxItems {
	//get info about all the IAP items we need to place
	
	NSArray* keys = [SettingsManager keysWithPrefix:SETTING_IAP_TOOLBOX_ITEM_COUNT];
	
	for(NSString* key in keys) {
		NSString* spriteName = [key stringByReplacingOccurrencesOfString:SETTING_IAP_TOOLBOX_ITEM_COUNT withString:@""];
		int count = [SettingsManager intForKey:key];
		if(DEBUG_IAP || DEBUG_TOOLBOX) DebugLog(@"Adding %d instances of IAP item %@ to world", count, spriteName);

		//create the sprites and userdata which is NOT LOADED FROM LEVELHELPER
		for(int i = 0; i < count; i++) {
			LHSprite* iapSprite = [_levelLoader createSpriteWithName:spriteName fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" tag:TOOLBOX_ITEM parent:_toolboxBatchNode];
			if([spriteName isEqualToString:@"Bag_of_Fish"]) {
				ToolboxItem_Bag_of_Fish* userData = [[ToolboxItem_Bag_of_Fish alloc] init];
				userData.scale = 1;
				userData.runningCost = 750;
				userData.placeCost = 500;
				[iapSprite setUserData:userData];
				
			}else if([spriteName isEqualToString:@"Anti_Shark_272_1"]) {
				ToolboxItem_Loud_Noise* userData = [[ToolboxItem_Loud_Noise alloc] init];
				userData.scale = 0.50;
				userData.runningCost = 750;
				userData.placeCost = 500;
				[iapSprite setUserData:userData];
				
			}else if([spriteName isEqualToString:@"Santa_Hat"]) {
				ToolboxItem_Invisibility_Hat* userData = [[ToolboxItem_Invisibility_Hat alloc] init];
				userData.scale = 1;
				userData.runningCost = 750;
				userData.placeCost = 500;
				[iapSprite setUserData:userData];
				
			}
		}
	}
}

-(void) updateToolbox {

	if(_toolboxItemSize.width == 0) {
		//get the toolbox item size for scaling purposes
		LHSprite* toolboxContainer = [_levelLoader createBatchSpriteWithName:@"Toolbox-Item-Container" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
		[toolboxContainer removeSelf];
		_toolboxItemSize = toolboxContainer.boundingBox.size;
	}
	
	for(LHSprite* toolboxItemContainer in [_levelLoader spritesWithTag:TOOLBOX_ITEM_CONTAINER]) {
		[toolboxItemContainer removeSelf];
	}
	
	CGSize winSize = [[CCDirector sharedDirector] winSize];

	NSArray* toolboxItems = [_levelLoader spritesWithTag:TOOLBOX_ITEM];
	
	if(_toolGroups != nil) {
		for(id key in _toolGroups) {
			NSMutableDictionary* toolGroup = [_toolGroups objectForKey:key];
			[toolGroup release];
		}
		[_toolGroups release];	
	}
	if(_iapToolGroups != nil) {
		for(id key in _iapToolGroups) {
			NSMutableDictionary* _iapToolGroup = [_iapToolGroups objectForKey:key];
			[_iapToolGroup release];
		}
		[_iapToolGroups release];	
	}
	_toolGroups = [[NSMutableDictionary alloc] init];
	_iapToolGroups = [[NSMutableDictionary alloc] init];

	//get all the tools put on the level - they can be anywhere!
	for(LHSprite* toolboxItem in toolboxItems) {
	
		[toolboxItem stopAllActions];
	
		bool iapToolGroup = false;
	
		//generate the grouping key for toolbox items
		NSString* toolgroupKey = [NSString stringWithFormat:@"%@",[(id)toolboxItem.userData class]];
		if([toolgroupKey isEqualToString:@"ToolboxItem_Windmill"]) {
			ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)toolboxItem.userData);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Power", toolboxItemData.power]];
		}else if([toolgroupKey isEqualToString:@"ToolboxItem_Debris"]) {
			ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)toolboxItem.userData);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Mass", toolboxItemData.mass]];
		}else if([toolgroupKey isEqualToString:@"ToolboxItem_Whirlpool"]) {
			ToolboxItem_Whirlpool* toolboxItemData = ((ToolboxItem_Whirlpool*)toolboxItem.userData);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Power", toolboxItemData.power]];
		}
		
		if([(id)toolboxItem.userData class] == [ToolboxItem_Bag_of_Fish class]) {
			iapToolGroup = true;
		}else if([(id)toolboxItem.userData class] == [ToolboxItem_Invisibility_Hat class]) {
			iapToolGroup = true;
		}else if([(id)toolboxItem.userData class] == [ToolboxItem_Loud_Noise class]) {
			iapToolGroup = true;
		}
		
		NSMutableSet* toolGroup = [_toolGroups objectForKey:toolgroupKey];
		if(toolGroup == nil) {
			toolGroup = [[NSMutableSet alloc] init];
			[_toolGroups setObject:toolGroup forKey:toolgroupKey];
		}
		[toolGroup addObject:toolboxItem];

		if(iapToolGroup) {
			NSMutableSet* iapToolGroup = [_iapToolGroups objectForKey:toolgroupKey];
			if(iapToolGroup == nil) {
				iapToolGroup = [[NSMutableSet alloc] init];
				[_iapToolGroups setObject:iapToolGroup forKey:toolgroupKey];
			}
			[iapToolGroup addObject:toolboxItem];		
		}
	}
		
	
	int mainToolGroupX = winSize.width/2 - ((_toolboxItemSize.width + TOOLBOX_MARGIN_LEFT)*((_toolGroups.count-1.0)/2.0));
	int mainToolGroupY = _toolboxItemSize.height/2 + TOOLBOX_MARGIN_BOTTOM;

	int iapToolGroupX = _toolboxItemSize.width/2 + TOOLBOX_MARGIN_BOTTOM;
	int iapToolGroupY = winSize.height/2 - ((_toolboxItemSize.height + TOOLBOX_MARGIN_LEFT)*((_iapToolGroups.count-1.0)/2.0));
		
	for(id key in _toolGroups) {

		NSMutableSet* toolGroup = [_toolGroups objectForKey:key];
		bool isIAPToolGroup = [_iapToolGroups objectForKey:key] != nil;

		//draw a box to hold it
		LHSprite* toolboxContainer = [_levelLoader createSpriteWithName:@"Toolbox-Item-Container" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
		toolboxContainer.zOrder = _actorsBatchNode.zOrder+1;
		toolboxContainer.tag = TOOLBOX_ITEM_CONTAINER;
		[toolboxContainer transformPosition: ccp(isIAPToolGroup ? iapToolGroupX : mainToolGroupX, isIAPToolGroup ? iapToolGroupY : mainToolGroupY)];

		LHSprite* toolboxContainerCountContainer = [_levelLoader createSpriteWithName:@"Toolbox-Item-Container-Count" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:toolboxContainer];
		[toolboxContainerCountContainer transformPosition: ccp(toolboxContainer.boundingBox.size.width, toolboxContainer.boundingBox.size.height)];

		//display # of items in the stack
		CCLabelTTF* numToolsLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", toolGroup.count] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE];
		numToolsLabel.color = ccWHITE;
		numToolsLabel.position = ccp(toolboxContainerCountContainer.boundingBox.size.width/2, toolboxContainerCountContainer.boundingBox.size.height/2);
		[toolboxContainerCountContainer addChild:numToolsLabel];
		
		LHSprite* topToolboxItem = nil;
		for(LHSprite* toolboxItem in toolGroup) {
			if(topToolboxItem == nil) {
				topToolboxItem = toolboxItem;
				//move the tool into the box

				int scaleMarginAdjust = 0;
				if([(id)toolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
					scaleMarginAdjust = 25;
				}else {
					[topToolboxItem transformRotation:0];
			
				}
				
				
				double scale = fmin((_toolboxItemSize.width-TOOLBOX_ITEM_CONTAINER_PADDING_H-(scaleMarginAdjust*SCALING_FACTOR_H))/topToolboxItem.contentSize.width,
									(_toolboxItemSize.height-TOOLBOX_ITEM_CONTAINER_PADDING_V-(scaleMarginAdjust*SCALING_FACTOR_V))/topToolboxItem.contentSize.height);
				[topToolboxItem transformScale: scale];
				[topToolboxItem transformPosition: ccp(isIAPToolGroup ? iapToolGroupX : mainToolGroupX, isIAPToolGroup ? iapToolGroupY : mainToolGroupY)];
				topToolboxItem.visible = true;
				//DebugLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", toolboxItem.uniqueName, (int)(100*scale));
			}else {
				toolboxItem.visible = false;
			}
		}
		
		//helpful tidbits
		if([(id)topToolboxItem.userData class] == [ToolboxItem_Windmill class]) {
			//display item power
			ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)topToolboxItem.userData);
			CCLabelTTF* powerLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%%", (int)toolboxItemData.power] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_STATS_FONT_SIZE dimensions:CGSizeMake(_toolboxItemSize.width, 20*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentRight];
			powerLabel.color = ccWHITE;
			powerLabel.position = ccp(toolboxContainer.boundingBox.size.width - 60*SCALING_FACTOR_H - (IS_IPHONE ? 2 : 0),
										14*SCALING_FACTOR_V + (IS_IPHONE ? 3 : 0));
			[toolboxContainer addChild:powerLabel];
		}else if([(id)topToolboxItem.userData class] == [ToolboxItem_Debris class]) {
			//display item mass
			ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)topToolboxItem.userData);
			CCLabelTTF* powerLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%dlbs", (int)(toolboxItemData.mass*10)] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_STATS_FONT_SIZE dimensions:CGSizeMake(_toolboxItemSize.width, 20*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentRight];
			powerLabel.color = ccWHITE;
			powerLabel.position = ccp(toolboxContainer.boundingBox.size.width - 60*SCALING_FACTOR_H - (IS_IPHONE ? 2 : 0),
										14*SCALING_FACTOR_V + (IS_IPHONE ? 3 : 0));
			[toolboxContainer addChild:powerLabel];
		}else if([(id)topToolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
			//display item power
			ToolboxItem_Whirlpool* toolboxItemData = ((ToolboxItem_Whirlpool*)topToolboxItem.userData);
			CCLabelTTF* powerLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%%", (int)toolboxItemData.power] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_STATS_FONT_SIZE dimensions:CGSizeMake(_toolboxItemSize.width, 20*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentRight];
			powerLabel.color = ccWHITE;
			powerLabel.position = ccp(toolboxContainer.boundingBox.size.width - 60*SCALING_FACTOR_H - (IS_IPHONE ? 2 : 0),
										14*SCALING_FACTOR_V + (IS_IPHONE ? 3 : 0));
			[toolboxContainer addChild:powerLabel];
		}

		
		[toolboxContainer setUserData:(void*)topToolboxItem.uniqueName];
		[toolboxContainer registerTouchBeganObserver:self selector:@selector(onTouchBeganToolboxItem:)];
		[toolboxContainer registerTouchEndedObserver:self selector:@selector(onTouchEndedToolboxItem:)];

	
		if(isIAPToolGroup) {
			iapToolGroupY+= _toolboxItemSize.height + TOOLBOX_MARGIN_LEFT;
		}else {
			mainToolGroupX+= _toolboxItemSize.width + TOOLBOX_MARGIN_LEFT;
		}
	}
}


-(void) loadLevel:(NSString*)levelName inLevelPack:(NSString*)levelPack {
		
	CGSize winSize = [[CCDirector sharedDirector] winSize];		
		
	[LevelHelperLoader dontStretchArt];

	//create a LevelHelperLoader object that has the data of the specified level
	_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", levelPack, levelName]];
	
	//create all objects from the level file and adds them to the cocos2d layer (self)
	[_levelLoader addObjectsToWorld:_world cocos2dLayer:self];

	_levelSize = winSize.width < _levelLoader.gameWorldSize.size.width ? _levelLoader.gameWorldSize.size : winSize;
	DebugLog(@"Level size: %f x %f", _levelSize.width, _levelSize.height);

	_mainLayer = [_levelLoader layerWithUniqueName:@"MAIN_LAYER"];
	_toolboxBatchNode = [_levelLoader batchWithUniqueName:@"Toolbox"];
	_mapBatchNode = [_levelLoader batchWithUniqueName:@"Map"];
	_actorsBatchNode = [_levelLoader batchWithUniqueName:@"Actors"];

	//checks if the level has physics boundaries
	if([_levelLoader hasPhysicBoundaries])
	{
		//if it does, it will create the physic boundaries
		[_levelLoader createPhysicBoundaries:_world];
	}
		
	//draw the background water tiles
	LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND parent:_mainLayer];
	for(int x = -waterTile.boundingBox.size.width/2; x < winSize.width + waterTile.boundingBox.size.width/2; ) {
		for(int y = -waterTile.boundingBox.size.height/2; y < winSize.height + waterTile.boundingBox.size.width/2; ) {
			LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND parent:_mapBatchNode];
			[waterTile setZOrder:0];
			[waterTile transformPosition:ccp(x,y)];
			y+= waterTile.boundingBox.size.height;
		}
		x+= waterTile.boundingBox.size.width;
	}
	[waterTile removeSelf];
	
	//add the HAND OF GOD (penguin nodge)
	if(HAND_OF_GOD_INITIAL_POWER > 0) {
		_handOfGodPowerNode = [[PowerBarNode alloc] initWithSize:CGSizeMake(400*SCALING_FACTOR_H, 35*SCALING_FACTOR_V)
													position:ccp(winSize.width - (200+5)*SCALING_FACTOR_H,
																winSize.height - (20+5)*SCALING_FACTOR_V)
													color:ccc4f(0.8,0.8,0.3,1.0)
													label:[NSString stringWithFormat:@"Nudge Power (costs %d per second)", SCORING_HAND_OF_GOD_COST_PER_SECOND]
													textColor:ccBLACK 
													fontSize:18*SCALING_FACTOR_FONTS];
		_handOfGodPowerNode.opacity = 0;
		[self addChild:_handOfGodPowerNode];
	}
		
	
	//apply the Shark animation to all sharks
	for(LHSprite* shark in [_levelLoader spritesWithTag:SHARK]) {
		[shark prepareAnimationNamed:@"Shark" fromSHScene:@"Spritesheet"];
	}
	
		
				
	//standardize masses of sharks and penguins
	for(LHSprite* shark in [_levelLoader spritesWithTag:SHARK]) {
		b2MassData massData;
		shark.body->GetMassData(&massData);
		massData.mass = ACTOR_MASS;
		shark.body->SetMassData(&massData);
	}
	
	for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
		b2MassData massData;
		penguin.body->GetMassData(&massData);
		massData.mass = ACTOR_MASS;
		penguin.body->SetMassData(&massData);
	}
	
	//update any toolbox items so we don't have to do everything manually in LevelHelper
	for(LHSprite* sprite in [_levelLoader allSprites]) {
		
		sprite.userData = sprite.userInfo;
		
		if([(id)sprite.userData class] == [ToolboxItem_Debris class]) {
			b2MassData massData;
			ToolboxItem_Debris* toolboxItemData = (ToolboxItem_Debris*)sprite.userInfo;
			sprite.body->GetMassData(&massData);
			massData.mass*= toolboxItemData.mass;
			sprite.body->SetMassData(&massData);
		}else if([(id)sprite.userData class] == [ToolboxItem_Whirlpool class]) {
			//sets those in the toolbox too
			[sprite makeDynamic];
			[sprite setSensor:true];
			sprite.body->SetAngularVelocity(0);
		}
		
		if(sprite.tag == DEBRIS) {
			//already placed - set it's physics data
			[sprite makeDynamic];
			[sprite setSensor:false];
			
			ToolboxItem_Debris* toolboxItemData = (ToolboxItem_Debris*)sprite.userData;
			[sprite setScale:toolboxItemData.scale];
			
		}else if(sprite.tag == OBSTRUCTION) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
		}else if(sprite.tag == WINDMILL) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
			
			ToolboxItem_Windmill* toolboxItemData = (ToolboxItem_Windmill*)sprite.userData;
			[sprite setScale:toolboxItemData.scale];
			
		}else if(sprite.tag == WHIRLPOOL) {
		
			//already placed - set it's physics data
			sprite.body->ApplyTorque(sprite.rotation < 180 ? -15 : 15);
			
			ToolboxItem_Whirlpool* toolboxItemData = (ToolboxItem_Whirlpool*)sprite.userData;
			[sprite setScale:toolboxItemData.scale];

		}else if(sprite.tag == SANDBAR) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
		}else if(sprite.tag == BAG_OF_FISH) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
		}else if(sprite.tag == INVISIBILITY_HAT) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
		}else if(sprite.tag == LOUD_NOISE) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
		}else if(sprite.tag == BORDER || sprite.tag == LAND) {
			//all land items are set as sensors to give a more natural movement feel around edges
			[sprite setSensor:true];
			
			/*This can create collision detection issues where sharks don't know they're touching a border because their middle point (gridPos) is not touching the land border
			//..except for moving ones!
			if([sprite.userInfoClassName isEqualToString:@"MovingBorder"]) {
				[sprite setSensor:false];
				[sprite makeDynamic];
				sprite.body->GetFixtureList()->SetRestitution(1.0);
				sprite.body->GetFixtureList()->SetFriction(0);
			}
			*/
		}
	}
			
		
	[self showTutorial];
}


-(void) generateFeatureGrids {

	if(_isGeneratingFeatureGrid) {
		return;
	}
	_isGeneratingFeatureGrid = true;

	if(DEBUG_MOVEGRID) DebugLog(@"Generating feature maps...");
	

	//fresh start
	for(int x = 0; x < _gridWidth; x++) {
		for(int y = 0; y < _gridHeight; y++) {
			_sharkMapfeaturesGrid[x][y] = INITIAL_GRID_WEIGHT;
			_penguinMapfeaturesGrid[x][y] = INITIAL_GRID_WEIGHT;
		}
	}
		
	//fill in the feature grid detailing map movement info
	NSArray* lands = [_levelLoader spritesWithTag:LAND];
	NSArray* borders = [_levelLoader spritesWithTag:BORDER];
	NSArray* obstructions = [_levelLoader spritesWithTag:OBSTRUCTION];
	NSArray* sandbars = [_levelLoader spritesWithTag:SANDBAR];
	
	NSMutableArray* unpassableAreas = [NSMutableArray arrayWithArray:lands];
	[unpassableAreas addObjectsFromArray:borders];
	[unpassableAreas addObjectsFromArray:obstructions];
	[unpassableAreas addObjectsFromArray:sandbars];
	
	//if(DEBUG_MOVEGRID) DebugLog(@"Num safe lands: %d, Num borders: %d", [lands count], [borders count]);
	
	
	for(LHSprite* land in unpassableAreas) {
			
		b2AABB aabb;
		aabb.lowerBound = b2Vec2(FLT_MAX,FLT_MAX);
		aabb.upperBound = b2Vec2(-FLT_MAX,-FLT_MAX); 
		b2Fixture* fixture = land.body->GetFixtureList();
		while (fixture != NULL) {
			aabb.Combine(aabb, fixture->GetAABB(0));
			fixture = fixture->GetNext();
		}
		
		//convert to worldspace (Figure out why the conversion is needed at all later)
		int minX = max(aabb.lowerBound.x*PTM_RATIO, 0);
		int maxX = min(aabb.upperBound.x*PTM_RATIO, _levelSize.width-1);
		int minY = max(aabb.lowerBound.y*PTM_RATIO, 0);
		int maxY = min(aabb.upperBound.y*PTM_RATIO, _levelSize.height-1);

/*
		DebugLog(@"Land %@ AABB bounds from %f,%f to %f,%f", land.uniqueName, aabb.lowerBound.x, aabb.lowerBound.y, aabb.upperBound.x, aabb.upperBound.y);
		DebugLog(@"Land %@ position %f,%f", land.uniqueName, land.position.x, land.position.y);
		DebugLog(@"Land %@ AABB bounding box from %f,%f to %f,%f", land.uniqueName, land.boundingBox.origin.x, land.boundingBox.origin.y, land.boundingBox.origin.x+land.boundingBox.size.width, land.boundingBox.origin.y+land.boundingBox.size.height);
		DebugLog(@"Land %@ bounds from %d,%d to %d,%d", land.uniqueName, minX, minY, maxX, maxY);
*/

		//create the areas that both sharks and penguins can't go
		
		//cross-patch fill (+=2 step)
		//double startTime = [[NSDate date] timeIntervalSince1970];
		for(int x = minX; x < maxX; x+= 2) {
			for(int y = minY; y < maxY; y+= 2) {
				int gridX = (x/_gridSize);
				int gridY = (y/_gridSize);
				_sharkMapfeaturesGrid[gridX][gridY] = HARD_BORDER_WEIGHT;
				if(land.tag == BORDER || land.tag == OBSTRUCTION) {
					//penguins can pass through SANDBAR and want to target LAND
					_penguinMapfeaturesGrid[gridX][gridY] = HARD_BORDER_WEIGHT;
				}
			}
		}
		//NSLog(@"Fill time: %f", [[NSDate date] timeIntervalSince1970] - startTime);

	}
	
	//add the map boundaries as borders
	for(int x = 0; x < _gridWidth; x++) {
		_sharkMapfeaturesGrid[x][0] = HARD_BORDER_WEIGHT;
		_penguinMapfeaturesGrid[x][0] = HARD_BORDER_WEIGHT;
		_sharkMapfeaturesGrid[x][_gridHeight-1] = HARD_BORDER_WEIGHT;
		_penguinMapfeaturesGrid[x][_gridHeight-1] = HARD_BORDER_WEIGHT;
	}
	for(int y = 0; y < _gridHeight; y++) {
		_sharkMapfeaturesGrid[0][y] = HARD_BORDER_WEIGHT;
		_penguinMapfeaturesGrid[0][y] = HARD_BORDER_WEIGHT;
		_sharkMapfeaturesGrid[_gridWidth-1][y] = HARD_BORDER_WEIGHT;
		_penguinMapfeaturesGrid[_gridWidth-1][y] = HARD_BORDER_WEIGHT;
	}
	
	
	if(_state == SETUP) {

		NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
		for(LHSprite* penguin in penguins) {
			//if on some land, move him off it!
			//we only do this during PLACE because it makes "weird" behavior when placing obstructions near actors
			CGPoint penguinGridPos = [self toGrid:penguin.position];
			while(_penguinMapfeaturesGrid[(int)penguinGridPos.x][(int)penguinGridPos.y] == HARD_BORDER_WEIGHT) {
				//move back onto land
				short wN = penguinGridPos.y+1 > _gridHeight-1 ? 10000 : _penguinMapfeaturesGrid[(int)penguinGridPos.x][(int)penguinGridPos.y+1];
				short wS = penguinGridPos.y-1 < 0 ? 10000 : _penguinMapfeaturesGrid[(int)penguinGridPos.x][(int)penguinGridPos.y-1];
				short wE = penguinGridPos.x+1 > _gridWidth-1 ? 10000 : _penguinMapfeaturesGrid[(int)penguinGridPos.x+1][(int)penguinGridPos.y];
				short wW = penguinGridPos.x-1 < 0 ? 10000 : _penguinMapfeaturesGrid[(int)penguinGridPos.x-1][(int)penguinGridPos.y];
				short wMin = min(min(min(wN,wS),wE),wW);
				if(wN == wMin) {
					penguinGridPos.y++;
				}else if(wS == wMin) {
					penguinGridPos.y--;
				}else if(wE == wMin) {
					penguinGridPos.x++;
				}else if(wW == wMin) {
					penguinGridPos.x--;
				}
				[penguin transformPosition:ccp(penguinGridPos.x*_gridSize + _gridSize/2, penguinGridPos.y*_gridSize + _gridSize/2)];
			}
		}		
	
		NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
		for(LHSprite* shark in sharks) {
			//if on some land, move him off it!
			//we only do this during PLACE because it makes "weird" behavior when placing obstructions near actors
			CGPoint sharkGridPos = [self toGrid:shark.position];
			while(_sharkMapfeaturesGrid[(int)sharkGridPos.x][(int)sharkGridPos.y] == HARD_BORDER_WEIGHT) {
				//move back onto land
				short wN = sharkGridPos.y+1 > _gridHeight-1 ? 10000 : _sharkMapfeaturesGrid[(int)sharkGridPos.x][(int)sharkGridPos.y+1];
				short wS = sharkGridPos.y-1 < 0 ? 10000 : _sharkMapfeaturesGrid[(int)sharkGridPos.x][(int)sharkGridPos.y-1];
				short wE = sharkGridPos.x+1 > _gridWidth-1 ? 10000 : _sharkMapfeaturesGrid[(int)sharkGridPos.x+1][(int)sharkGridPos.y];
				short wW = sharkGridPos.x-1 < 0 ? 10000 : _sharkMapfeaturesGrid[(int)sharkGridPos.x-1][(int)sharkGridPos.y];
				short wMin = min(min(min(wN,wS),wE),wW);
				if(wN == wMin) {
					sharkGridPos.y++;
				}else if(wS == wMin) {
					sharkGridPos.y--;
				}else if(wE == wMin) {
					sharkGridPos.x++;
				}else if(wW == wMin) {
					sharkGridPos.x--;
				}
				[shark transformPosition:ccp(sharkGridPos.x*_gridSize + _gridSize/2, sharkGridPos.y*_gridSize + _gridSize/2)];
			}
		}
	}
	
	if(DEBUG_MOVEGRID) DebugLog(@"Done generating feature maps");
	_isGeneratingFeatureGrid = false;
}

-(void)updateFeatureMapForShark:(LHSprite*)shark {

	if(DEBUG_MOVEGRID) DebugLog(@"Updating shark %@ feature grid", shark.uniqueName);

	short** sharkBaseGrid;
	int rowSize = _gridHeight * sizeof(short);
	
	MoveGridData* moveGridData = [_sharkMoveGridDatas objectForKey:shark.uniqueName];
	if(moveGridData == nil) {
		sharkBaseGrid = new short*[_gridWidth];
		for(int x = 0; x < _gridWidth; x++) {
			sharkBaseGrid[x] = new short[_gridHeight];
			memcpy(sharkBaseGrid[x], (void*)_sharkMapfeaturesGrid[x], rowSize);
		}
		
		moveGridData = [[MoveGridData alloc] initWithGrid: sharkBaseGrid height:_gridHeight width:_gridWidth moveHistorySize:SHARK_MOVE_HISTORY_SIZE tag:shark.uniqueName];
		[_sharkMoveGridDatas setObject:moveGridData forKey:shark.uniqueName];
					
	}else {
		sharkBaseGrid = moveGridData.baseGrid;
		for(int x = 0; x < _gridWidth; x++) {
			memcpy(sharkBaseGrid[x], (void*)_sharkMapfeaturesGrid[x], rowSize);
		}
		[moveGridData forceUpdateToMoveGrid];
	}
	
	Shark* sharkData = (Shark*)shark.userInfo;
	sharkData.isStuck = false;
}

-(void)updateFeatureMapForPenguin:(LHSprite*)penguin {

	if(DEBUG_MOVEGRID) DebugLog(@"Updating penguin %@ feature grid", penguin.uniqueName);

	short** penguinBaseGrid;
	int rowSize = _gridHeight * sizeof(short);
	
	MoveGridData* moveGridData = [_penguinMoveGridDatas objectForKey:penguin.uniqueName];
	if(moveGridData == nil) {
		penguinBaseGrid = new short*[_gridWidth];
		for(int x = 0; x < _gridWidth; x++) {
			penguinBaseGrid[x] = new short[_gridHeight];
			memcpy(penguinBaseGrid[x], (void*)_penguinMapfeaturesGrid[x], rowSize);
		}
		
		moveGridData = [[MoveGridData alloc] initWithGrid: penguinBaseGrid height:_gridHeight width:_gridWidth moveHistorySize:PENGUIN_MOVE_HISTORY_SIZE tag:penguin.uniqueName];
		[_penguinMoveGridDatas setObject:moveGridData forKey:penguin.uniqueName];				
					
	}else {
		penguinBaseGrid = moveGridData.baseGrid;
		for(int x = 0; x < _gridWidth; x++) {
			memcpy(penguinBaseGrid[x], (void*)_penguinMapfeaturesGrid[x], rowSize);
		}
		[moveGridData forceUpdateToMoveGrid];
	}
	
	Penguin* penguinData = (Penguin*)penguin.userInfo;
	penguinData.isStuck = false;
}


-(void)setActiveToolboxItem:(LHSprite*)toolboxItem {

	double timestamp = [[NSDate date] timeIntervalSince1970];
	if(_activeToolboxItem != nil && (timestamp - _activeToolboxItemSelectionTimestamp > 0.100)) {
		//only handle one touch at a time with touches right next to eachother preferring the later one
		return;
	}
	_activeToolboxItemSelectionTimestamp = timestamp;
	
	if(DEBUG_TOOLBOX) DebugLog(@"Set activeToolboxItem to %@", toolboxItem.uniqueName);
	
	
	/*
	if(toolboxItem.tag != TOOLBOX_ITEM) {
		//already placed
		return;
	}
	*/
	
	if(_activeToolboxItem == nil) {
		//fresh touch
	
		//hide any tutorials
		[self fadeOutAllTutorials];
		
		if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
			[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/toolbox/pickup.wav"];
		}
	}

	_activeToolboxItem = toolboxItem;
	
	//slide down the toolbox items
	for(LHSprite* aToolboxItemContainer in [_levelLoader spritesWithTag:TOOLBOX_ITEM_CONTAINER]) {

		//a hack... but UntitledSprite name only occurs when we create the sprite programmatically
		bool isIAPToolboxItem = [(NSString*)aToolboxItemContainer.userData hasPrefix:@"UntitledSprite"];

		[aToolboxItemContainer runAction:[CCMoveTo actionWithDuration:0.20f position: ccp(
							isIAPToolboxItem ? -aToolboxItemContainer.boundingBox.size.width : aToolboxItemContainer.position.x,
							isIAPToolboxItem ? aToolboxItemContainer.position.y : -aToolboxItemContainer.boundingBox.size.height)
										]
		];
	}
	for(LHSprite* aToolboxItem in [_levelLoader spritesWithTag:TOOLBOX_ITEM]) {
		if(aToolboxItem == _activeToolboxItem) {
			continue;
		}

		bool isIAPToolboxItem = false;
		if([(id)aToolboxItem.userData class] == [ToolboxItem_Bag_of_Fish class]) {
			isIAPToolboxItem = true;
		}else if([(id)aToolboxItem.userData class] == [ToolboxItem_Invisibility_Hat class]) {
			isIAPToolboxItem = true;
		}else if([(id)aToolboxItem.userData class] == [ToolboxItem_Loud_Noise class]) {
			isIAPToolboxItem = true;
		}
	
		aToolboxItem.visible = true;//allows us to get a size
		[aToolboxItem runAction:[CCMoveTo actionWithDuration:0.20f position: ccp(
												isIAPToolboxItem ? -aToolboxItem.boundingBox.size.width : aToolboxItem.position.x,
												isIAPToolboxItem ? aToolboxItem.position.y : -aToolboxItem.boundingBox.size.height)
								]
		];
		aToolboxItem.visible = false;
	}
	
	[self scheduleOnce:@selector(initializeSelectedActiveToolboxItem) delay:0.050];
}

-(void)initializeSelectedActiveToolboxItem {
	
	//stop any interaction with the world
	_activeToolboxItem.tag = TOOLBOX_ITEM;
	
	//establish crosshairs
	if(_activeToolboxItemRotationCrosshair != nil) {
		[self removeChild:_activeToolboxItemRotationCrosshair cleanup:YES];
		[_activeToolboxItemRotationCrosshair release];
	}
	_activeToolboxItemRotationCrosshair = [[ToolboxItemRotationCrosshair alloc] initWithToolboxItem:_activeToolboxItem];
	[self addChild:_activeToolboxItemRotationCrosshair];
			
	_activeToolboxItemOriginalPosition = _activeToolboxItem.position;
	ToolboxItem_Obstruction* toolboxItemData = ((ToolboxItem_Obstruction*)_activeToolboxItem.userData);	//ToolboxItem_Obstruction is used because all ToolboxItem classes have a "scale" property
	[_activeToolboxItem transformScale: toolboxItemData.scale];
	if(DEBUG_TOOLBOX) DebugLog(@"Scaling up toolboxitem %@ to full-size", _activeToolboxItem.uniqueName);
	
	if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
		//set previously in level load
		double angularVelocity = _activeToolboxItem.body->GetAngularVelocity();
		if(angularVelocity == 0) {
			_activeToolboxItem.body->ApplyTorque(-15);
		}
	}
}


-(void)onTouchBeganToolboxItem:(LHTouchInfo*)info {

	//[[LHTouchMgr sharedInstance] setPriority:1 forTouchesOfTag:OBSTRUCTION];

	if(_state != RUNNING && _state != PLACE) {
		return;
	}

	LHSprite* toolboxItemContainer = info.sprite;
	LHSprite* toolboxItem = toolboxItemContainer.tag == TOOLBOX_ITEM_CONTAINER ? [_levelLoader spriteWithUniqueName:((NSString*)toolboxItemContainer.userData)] : toolboxItemContainer;

	if(DEBUG_TOOLBOX) DebugLog(@"Touch began on toolboxItem %@", toolboxItem.uniqueName);

	[self setActiveToolboxItem:toolboxItem];
}

-(void)onTouchEndedToolboxItem:(LHTouchInfo*)info {
	
	if(_activeToolboxItem != nil) {
			
		//remove the toolbox item crosshair
		if(_activeToolboxItemRotationCrosshair != nil) {
			[self removeChild:_activeToolboxItemRotationCrosshair cleanup:YES];
			[_activeToolboxItemRotationCrosshair release];
			_activeToolboxItemRotationCrosshair = nil;
		}
			
			
		if((_state != RUNNING && _state != PLACE)
				|| (info.glPoint.y <= 0)
				|| (info.glPoint.y >= _levelSize.height)
				|| (info.glPoint.x <= 0)
				|| (info.glPoint.x >= _levelSize.width)
			) {
			//placed back into the HUD

			if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
				_activeToolboxItem.body->SetAngularVelocity(0);
				_activeToolboxItem.body->ApplyTorque(-15);
			}else {
				[_activeToolboxItem transformRotation:0];
			}
			
			[_activeToolboxItem transformPosition:_activeToolboxItemOriginalPosition];
			double scale = fmin((_toolboxItemSize.width-TOOLBOX_ITEM_CONTAINER_PADDING_H)/_activeToolboxItem.contentSize.width, (_toolboxItemSize.height-TOOLBOX_ITEM_CONTAINER_PADDING_V)/_activeToolboxItem.contentSize.height);
			[_activeToolboxItem transformScale: scale];
			//DebugLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", _activeToolboxItem.uniqueName, (int)(100*scale));
			if(DEBUG_TOOLBOX) DebugLog(@"Placing toolbox item back into the HUD");
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
				_levelPackPath, @"Level_Pack",
				[NSString stringWithFormat:@"%@",[(id)_activeToolboxItem.userData class]], @"Toolbox_Item_Class",
				_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
				[NSNumber numberWithInt:_state], @"Game_State",
			nil];
			[Analytics logEvent:@"Undo_Place_Toolbox_Item" withParameters:flurryParams];
			
			_activeToolboxItem = nil;
			
			if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
				[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/toolbox/return.wav"];
			}
			
		}else {
			_moveActiveToolboxItemIntoWorld = true;
		}
	}
}












-(void)onTouchBeganPlayPause:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	if(_activeToolboxItem != nil) return;
	if(_state != PLACE && _state != RUNNING && _state != PAUSE) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
		
	__DEBUG_TOUCH_SECONDS = [[NSDate date] timeIntervalSince1970];
}

-(void)onTouchEndedPlayPause:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	if(_activeToolboxItem != nil) return;
	if(_state != PLACE && _state != RUNNING && _state != PAUSE) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
		
	//DebugLog(@"Touch ended play/pause on GameLayer instance %f with _state=%d", _instanceId, _state);
	
	if(_state == PLACE) {
		[self resume];
		[info.sprite setFrame:2];	//pause inactive
		
	}else if(_state == PAUSE) {
		[self resume];
		[info.sprite setFrame:2];	//pause inactive
		
	}else if(_state == RUNNING) {
		[self pause];
		[info.sprite setFrame:3];	//pause active
		[info.sprite setFrame:0];	//play inactive
	}

	__DEBUG_TOUCH_SECONDS = 0;
}

-(void)onTouchBeganRestart:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	if(_activeToolboxItem != nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//DebugLog(@"Touch began restart on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedRestart:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	if(_activeToolboxItem != nil) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Click_Restart" withParameters:flurryParams];

	[self restart];
}

-(void)onTouchBeganMainMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;	
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//DebugLog(@"Touch began mainmenu on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedMainMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Click_Main_Menu" withParameters:flurryParams];
	
	[self showMainMenuLayer];
}

-(void)onTouchBeganIAPMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;	
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedIAPMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Click_IAP_Menu" withParameters:flurryParams];
	
	[self showInAppPurchaseLayer];
}

-(void)onTouchBeganLevelsMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//DebugLog(@"Touch began levels menu on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedLevelsMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	//DebugLog(@"Touch ended levels menu on GameLayer instance %f with _state=%d", _instanceId, _state);

	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Click_Levels_Menu" withParameters:flurryParams];

	
	[self showLevelsMenuLayer];
}

-(void)onTouchBeganNextLevel:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//DebugLog(@"Touch began next level on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedNextLevel:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Click_Next_Level" withParameters:flurryParams];

	
	[self goToNextLevel];
}

-(void)onTouchBeganTutorial:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	DebugLog(@"Touch began tutorial on GameLayer instance %f with _state=%d", _instanceId, _state);
	[self fadeOutAllTutorials];
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
		_levelPackPath, @"Level_Pack",
	nil];
	[Analytics logEvent:@"Click_Tutorial" withParameters:flurryParams];

}





-(void) pause {
	if(_state == RUNNING) {
		DebugLog(@"Pausing game");
		_state = PAUSE;
		
		for(LHSprite* sprite in _levelLoader.allSprites) {
			if(![sprite.userInfoClassName isEqualToString:@"MovingDoodad"]) {
				[sprite pauseAnimation];
				[sprite pausePathMovement];
			}
		}
		
		//analytics logging
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
			_levelPackPath, @"Level_Pack",
		nil];
		[Analytics logEvent:@"Pause_level" withParameters:flurryParams];
	}
	[self showInGameMenu];
}

-(void) showInGameMenu {
	DebugLog(@"Showing in-game menu");

	[_playPauseButton runAction:[CCFadeTo actionWithDuration:0.5f opacity:150.0f]];
		
	double angle = 160;
		
	for(LHSprite* menuItem in _inGameMenuItems) {
	
		[menuItem setAnchorPoint:ccp(3.25,3.25)];
		[menuItem runAction:[CCFadeIn actionWithDuration:0.15f]];
		[menuItem runAction:[CCRotateBy actionWithDuration:0.25f angle:angle]];
		
		angle+= 22.5;
	}
	
}

-(void) hideInGameMenu {

	[_playPauseButton runAction:[CCFadeTo actionWithDuration:0.5f opacity:255.0f]];

	for(LHSprite* menuItem in _inGameMenuItems) {
		[menuItem runAction:[CCFadeOut actionWithDuration:0.35f]];
		[menuItem runAction:[CCSequence actions:
			[CCRotateBy actionWithDuration:0.35f angle:-180.0f],	//take offscreen
			[CCRotateTo actionWithDuration:0.15f angle:0.0f],	//reliable positioning
			[CCScaleTo actionWithDuration:0.15f scaleX:1.0f scaleY:1.0f],	//reliable scale
			nil
		]];
	}
}

-(void) resume {

	if(_state == PAUSE) {
		DebugLog(@"Resuming game");
		_state = RUNNING;
		
		for(LHSprite* sprite in _levelLoader.allSprites) {
			if(sprite.numberOfFrames > 1) {
				if(![sprite.animationName hasSuffix:@"_Button"]) {
					[sprite playAnimation];
				}
			}
			[sprite startPathMovement];
		}
		
		//analytics loggin
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
			_levelPackPath, @"Level_Pack",
		nil];
		[Analytics logEvent:@"Resume_level" withParameters:flurryParams];

		[self hideInGameMenu];
			
	}else if(_state == PLACE) {
		DebugLog(@"Running game");
		_state = RUNNING;
		_levelStartRunningTime  = [[NSDate date] timeIntervalSince1970];

		[self fadeOutAllTutorials];
		
		for(LHSprite* sprite in _levelLoader.allSprites) {
			if(sprite.numberOfFrames > 1) {
				if(![sprite.animationName hasSuffix:@"_Button"]) {
					[sprite playAnimation];
				}
			}
		}
		
		//charge for placed IAP items
		for(LHSprite* placedItem in _placedToolboxItems) {
			[self debitForToolboxItemUsage:placedItem];
		}
		
		//analytics logging
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
			_levelPackPath, @"Level_Pack",
		nil];
		[Analytics logEvent:@"Play_level" withParameters:flurryParams];

	}
	
}

-(void) setStateGameOver {

	_state = GAME_OVER;

	[self unscheduleAllSelectors];
	[self unscheduleUpdate];
	
	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
		[sprite stopPathMovement];
	}
	
	//remove the toolbox item crosshair
	if(_activeToolboxItemRotationCrosshair != nil) {
		[self removeChild:_activeToolboxItemRotationCrosshair cleanup:YES];
		[_activeToolboxItemRotationCrosshair release];
		_activeToolboxItemRotationCrosshair = nil;
	}
	_activeToolboxItem = nil;
}


-(void) levelWon {

	if(_state == GAME_OVER) {
		return;
	}
	[self setStateGameOver];
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/levelWon/reward.mp3"];
	}
		
	DebugLog(@"Showing level won animations");
	
	
	int scoreDeductions = 0;
	
	
	int toolsScoreDeduction = _scoreKeeper.totalScore;
	//hand of god power
	toolsScoreDeduction+= _handOfGodPowerSecondsUsed*SCORING_HAND_OF_GOD_COST_PER_SECOND;
	scoreDeductions+= toolsScoreDeduction;
	
	const double placeTimeScore = _levelPlaceTimeDuration * SCORING_PLACE_SECOND_COST;
	const double runningTimeScore = _levelRunningTimeDuration * SCORING_RUNNING_SECOND_COST;
	const int timeScoreDeduction = placeTimeScore + runningTimeScore;
	scoreDeductions+= timeScoreDeduction;
	
	const int finalScore = scoreDeductions > SCORING_MAX_SCORE_POSSIBLE ? 0 : SCORING_MAX_SCORE_POSSIBLE - scoreDeductions;
	
	//post the score to the server or queue for online processing
	[ScoreKeeper saveScore:finalScore UUID:[SettingsManager getUUID] levelPackPath:_levelPackPath levelPath:_levelPath];
					
	//get the world numbers from the server
	NSDictionary* worldScores = [ScoreKeeper worldScoresForLevelPackPath:_levelPackPath levelPath:_levelPath];
	int worldScoreMean = [(NSNumber*)[worldScores objectForKey:@"scoreMean"] intValue];
	double zScore = [ScoreKeeper zScoreFromScore:finalScore withLevelPackPath:_levelPackPath levelPath:_levelPath];
	NSString* grade = [ScoreKeeper gradeFromZScore:zScore];
	
	int coinsEarned = 0;
	int prevScore = [[LevelPackManager scoreForLevel:_levelPath inPack:_levelPackPath] intValue];
	if(INITIAL_FREE_COINS == [SettingsManager intForKey:SETTING_TOTAL_EARNED_COINS]) {
		prevScore = 0;
	}
	if(DEBUG_SCORING) DebugLog(@"Previous score on level: %d", prevScore);
	NSString* coinsEarnedForLevelKey = [NSString stringWithFormat:@"%@%@:%@", SETTING_TOTAL_EARNED_COINS_FOR_LEVEL, _levelPackPath, _levelPath];
	int totalCoinsEarnedForLevel = [SettingsManager intForKey:coinsEarnedForLevelKey];
	if(DEBUG_SCORING) DebugLog(@"Previous total coins earned on level: %d", totalCoinsEarnedForLevel);
	
	if(prevScore < finalScore && totalCoinsEarnedForLevel < SCORING_MAX_COINS_PER_LEVEL) {
		int prevCoinsEarned = [ScoreKeeper coinsForZScore:[ScoreKeeper zScoreFromScore:prevScore withLevelPackPath:_levelPackPath levelPath:_levelPath]];
		if(DEBUG_SCORING) DebugLog(@"Coins earned for previous score on level: %d", prevCoinsEarned);
		coinsEarned = [ScoreKeeper coinsForZScore:zScore] - prevCoinsEarned;
		if(coinsEarned <= 0) {
			coinsEarned = 1;
		}
	}
	totalCoinsEarnedForLevel+= coinsEarned;
	if(totalCoinsEarnedForLevel > SCORING_MAX_COINS_PER_LEVEL) {
		coinsEarned = totalCoinsEarnedForLevel - SCORING_MAX_COINS_PER_LEVEL;
		totalCoinsEarnedForLevel = SCORING_MAX_COINS_PER_LEVEL;
	}
	if(DEBUG_SCORING) DebugLog(@"Coins earned for level: %d, new total coins earned for level: %d", coinsEarned, totalCoinsEarnedForLevel);
	
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Won", @"Level_Status",
		[NSNumber numberWithInt:finalScore], @"Score",
		[NSNumber numberWithInt:coinsEarned], @"CoinsEarned",
		[NSNumber numberWithInt:totalCoinsEarnedForLevel], @"TotalCoinsEarnedForLevel",
		grade, @"Grade",
	nil];
	[Analytics endTimedEvent:@"Begin_Level" withParameters:flurryParams];
	
	//store our earned coins
	[SettingsManager incrementIntBy:coinsEarned forKey:coinsEarnedForLevelKey];
	[SettingsManager incrementIntBy:coinsEarned forKey:SETTING_TOTAL_EARNED_COINS];
	[SettingsManager incrementIntBy:coinsEarned forKey:SETTING_TOTAL_AVAILABLE_COINS];
	
	//store the level as being completed
	[LevelPackManager completeLevel:_levelPath inPack:_levelPackPath withScore:finalScore];
			
			
			
			
			
			
	
	//show a level won screen
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	
	//render a transparent overlay
	CCLayerColor* popupLayer = [[CCLayerColor alloc] initWithColor:ccc4(255, 255, 255, 140) width:winSize.width height:winSize.height];
	CCRenderTexture *popupLayerTexture = [CCRenderTexture renderTextureWithWidth:popupLayer.contentSize.width height:popupLayer.contentSize.height];
	popupLayerTexture.sprite.anchorPoint= ccp(0.5f,0.5f);
	popupLayerTexture.position = ccp(popupLayer.contentSize.width/2, popupLayer.contentSize.height/2);
	popupLayerTexture.anchorPoint = ccp(0.5f,0.5f);
	popupLayerTexture.zOrder = 10000;
	
	[popupLayerTexture begin];
	[popupLayer visit];
	[popupLayerTexture end];	
	[popupLayer release];

	ccBlendFunc blendFunc = {GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA}; // we are going to blend via alpha
	[popupLayerTexture.sprite setBlendFunc:blendFunc];
	[_mainLayer addChild:popupLayerTexture];
	
	LHSprite* levelWonPopup = [_levelLoader createSpriteWithName:@"Level_Won_Popup" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:popupLayerTexture];
	levelWonPopup.opacity = 0;
	[levelWonPopup transformPosition: ccp(0,0)];

	/***** action butons ******/
	
	
	const int buttonYOffset = 120*SCALING_FACTOR_V + (IS_IPHONE ? -21 : 0);

	LHSprite* levelsMenuButton = [_levelLoader createSpriteWithName:@"Levels_Menu_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	levelsMenuButton.opacity = 0;
	levelsMenuButton.zOrder = _mainLayer.zOrder+1;
	[levelsMenuButton prepareAnimationNamed:@"Menu_Levels_Menu_Button" fromSHScene:@"Spritesheet"];
	[levelsMenuButton transformPosition: ccp(winSize.width/2 - levelsMenuButton.boundingBox.size.width*2,
											levelsMenuButton.boundingBox.size.height/2 + buttonYOffset) ];
	[levelsMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelsMenu:)];
	[levelsMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelsMenu:)];

	LHSprite* restartMenuButton = [_levelLoader createSpriteWithName:@"Restart_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	restartMenuButton.opacity = 0;
	restartMenuButton.zOrder = _mainLayer.zOrder+1;
	[restartMenuButton prepareAnimationNamed:@"Menu_Restart_Button" fromSHScene:@"Spritesheet"];
	[restartMenuButton transformPosition: ccp(winSize.width/2,
											restartMenuButton.boundingBox.size.height/2 + buttonYOffset) ];
	[restartMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[restartMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];

	LHSprite* nextLevelMenuButton = [_levelLoader createSpriteWithName:@"Next_Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	nextLevelMenuButton.opacity = 0;
	nextLevelMenuButton.zOrder = _mainLayer.zOrder+1;
	[nextLevelMenuButton prepareAnimationNamed:@"Menu_Next_Level_Button" fromSHScene:@"Spritesheet"];
	[nextLevelMenuButton transformPosition: ccp(winSize.width/2 + restartMenuButton.boundingBox.size.width*2,
											nextLevelMenuButton.boundingBox.size.height/2 + buttonYOffset) ];
	[nextLevelMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganNextLevel:)];
	[nextLevelMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedNextLevel:)];

	
	
	/***** scoring items ******/

	const int scoringYOffset = (IS_IPHONE ? 500 : 480)*SCALING_FACTOR_V;
	
	CCLabelTTF* maxScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", SCORING_MAX_SCORE_POSSIBLE] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1 ];
	maxScoreLabel.color = SCORING_FONT_COLOR2;
	maxScoreLabel.position = ccp(winSize.width/2 - (190*SCALING_FACTOR_H) - (IS_IPHONE ? 15*SCALING_FACTOR_H : 0),
								 scoringYOffset);
	[self addChild:maxScoreLabel];
		
	
	CCLabelTTF* elapsedPlaceTimeLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", timeScoreDeduction] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	elapsedPlaceTimeLabel.color = SCORING_FONT_COLOR1;
	elapsedPlaceTimeLabel.position = ccp(winSize.width/2 - (80*SCALING_FACTOR_H) - (IS_IPHONE ? 5*SCALING_FACTOR_H : 0),
									  	scoringYOffset);
	[self addChild:elapsedPlaceTimeLabel];


	CCLabelTTF* toolsScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", toolsScoreDeduction] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	toolsScoreLabel.color = SCORING_FONT_COLOR1;
	toolsScoreLabel.position = ccp(winSize.width/2 + (32*SCALING_FACTOR_H),
									scoringYOffset);
	[self addChild:toolsScoreLabel];


	CCLabelTTF* totalScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", finalScore] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	totalScoreLabel.color = SCORING_FONT_COLOR2;
	totalScoreLabel.position = ccp(winSize.width/2 + (165*SCALING_FACTOR_H) + (IS_IPHONE ? 12*SCALING_FACTOR_H : 0),
									scoringYOffset);
	[self addChild:totalScoreLabel];





	/***** competitive items ******/

	const int competitiveTextXOffset = (165 + (IS_IPHONE ? 13 : 0))*SCALING_FACTOR_H;
	const int competitiveTextYOffset = 135*SCALING_FACTOR_V;
	
	
	if(worldScores != nil) {

		CCLabelTTF* worldAverageScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", worldScoreMean] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
		worldAverageScoreLabel.color = SCORING_FONT_COLOR3;
		worldAverageScoreLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
											242*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? 1: 0));
		[self addChild:worldAverageScoreLabel];

		CCLabelTTF* gradeLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", grade] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE2];
		gradeLabel.color = SCORING_FONT_COLOR3;
		gradeLabel.opacity = 0;
		gradeLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
									170*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -5 : 0));
		[self addChild:gradeLabel];
		
		//grade fades in with a thump
		[gradeLabel runAction:[CCSequence actions:
			[CCDelayTime actionWithDuration:1.25f],
			[CCCallFunc actionWithTarget:self selector:@selector(playGameWonGradeStamp)],
			[CCFadeIn actionWithDuration:0.25f],
			nil]
		];
		
	
		CCLabelTTF* coinsEarnedLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", coinsEarned] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE2];
		coinsEarnedLabel.color = SCORING_FONT_COLOR2;
		coinsEarnedLabel.opacity = 0;
		coinsEarnedLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
									105*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -12 : 0));
		[self addChild:coinsEarnedLabel];
			
		[coinsEarnedLabel runAction:[CCSequence actions:
			[CCDelayTime actionWithDuration:1.50f],
			[CCFadeIn actionWithDuration:0.25f],
			nil]
		];
		
		NSString* highScoresLabelText = nil;
		if(coinsEarned > 0 && totalCoinsEarnedForLevel == SCORING_MAX_COINS_PER_LEVEL) {
			highScoresLabelText = @"Awesome! A new personal high score earns you the MAX coins for this level!";
		}else if(coinsEarned > 0 && totalCoinsEarnedForLevel < SCORING_MAX_COINS_PER_LEVEL) {
			highScoresLabelText = @"Nice! A new personal high score earns you some more coins!";
		}else if(coinsEarned == 0 && totalCoinsEarnedForLevel == SCORING_MAX_COINS_PER_LEVEL) {
			highScoresLabelText = @"You've already earned all the coins possible for this level!";
		}else {
			highScoresLabelText = @"Beat your high score to earn more coins!";
		}
		
		
		CCLabelTTF* highScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", highScoresLabelText] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE3 dimensions:CGSizeMake(250*SCALING_FACTOR_H,150*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentCenter vAlignment:kCCVerticalTextAlignmentCenter lineBreakMode:kCCLineBreakModeWordWrap];
		highScoreLabel.color = SCORING_FONT_COLOR1;
		highScoreLabel.opacity = 0;
		highScoreLabel.position = ccp(winSize.width/2 + competitiveTextXOffset - 200*SCALING_FACTOR_H,
									110*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -12 : 0));
		[self addChild:highScoreLabel];
		
		[highScoreLabel runAction:[CCSequence actions:
			[CCDelayTime actionWithDuration:1.50f],
			[CCFadeIn actionWithDuration:0.25f],
			nil]
		];
				
	}else {

		CCLabelTTF* coinsEarnedLabel = [CCLabelTTF labelWithString:@"?" fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE2];
		coinsEarnedLabel.color = SCORING_FONT_COLOR2;
		coinsEarnedLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
									105*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -12 : 0));
		[self addChild:coinsEarnedLabel];		
	
		//show info about needed to connect
		CCLabelTTF* goOnlineForScoresLabel = [CCLabelTTF labelWithString:@"Connect to the Internet to earn coins and see how your score compares with other players!" fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE3 dimensions:CGSizeMake(200*SCALING_FACTOR_H,200*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentCenter vAlignment:kCCVerticalTextAlignmentCenter lineBreakMode:kCCLineBreakModeWordWrap];
		goOnlineForScoresLabel.color = SCORING_FONT_COLOR2;
		goOnlineForScoresLabel.position = ccp(winSize.width/2 - competitiveTextXOffset,
									150*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -12 : 0));
		[self addChild:goOnlineForScoresLabel];	
	}

	[levelWonPopup runAction:[CCFadeIn actionWithDuration:0.25f]];
	[restartMenuButton runAction:[CCFadeIn actionWithDuration:0.35f]];
	[levelsMenuButton runAction:[CCFadeIn actionWithDuration:0.35f]];
	[nextLevelMenuButton runAction:[CCFadeIn actionWithDuration:0.35f]];
}

-(void) playGameWonGradeStamp {
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/levelWon/thud.wav"];
	}
}

-(void) levelLostWithShark:(LHSprite*)shark andPenguin:(LHSprite*)penguin {

	if(_state == GAME_OVER) {
		return;
	}
	[self setStateGameOver];

	//[self runAction:[CCShaky3D actionWithRange:1.5 shakeZ:false grid:ccg(12,8) duration:0.15f]];

	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/levelLost/hoot.wav"];
	}
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Shark Collision", @"Level_Lost_Reason",
	nil];
	[Analytics endTimedEvent:@"Begin_Level" withParameters:flurryParams];

	DebugLog(@"Showing level lost animations for penguin/shark collision");
	
	[self showLevelLostPopup];
}

-(void)showLevelLostPopup {
	//show a level won screen
	CGSize winSize = [[CCDirector sharedDirector] winSize];

	//render a transparent overlay
	CCLayerColor* popupLayer = [[CCLayerColor alloc] initWithColor:ccc4(255, 255, 255, 140) width:winSize.width height:winSize.height];
	CCRenderTexture *popupLayerTexture = [CCRenderTexture renderTextureWithWidth:popupLayer.contentSize.width height:popupLayer.contentSize.height];
	popupLayerTexture.sprite.anchorPoint= ccp(0.5f,0.5f);
	popupLayerTexture.position = ccp(popupLayer.contentSize.width/2, popupLayer.contentSize.height/2);
	popupLayerTexture.anchorPoint = ccp(0.5f,0.5f);
	popupLayerTexture.zOrder = 10000;
	
	[popupLayerTexture begin];
	[popupLayer visit];
	[popupLayerTexture end];	
	[popupLayer release];

	ccBlendFunc blendFunc = {GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA}; // we are going to blend via alpha
	[popupLayerTexture.sprite setBlendFunc:blendFunc];
	[_mainLayer addChild:popupLayerTexture];
	
	LHSprite* levelLostPopup = [_levelLoader createSpriteWithName:@"Level_Lost_Popup" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:popupLayerTexture];
	[levelLostPopup transformPosition: ccp(0,0)];

	/***** action butons ******/

	LHSprite* levelsMenuButton = [_levelLoader createSpriteWithName:@"Levels_Menu_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	levelsMenuButton.zOrder = _mainLayer.zOrder+1;
	[levelsMenuButton prepareAnimationNamed:@"Menu_Levels_Menu_Button" fromSHScene:@"Spritesheet"];
	[levelsMenuButton transformPosition: ccp(winSize.width/2 - levelsMenuButton.boundingBox.size.width,
											 winSize.height/2 - 58*SCALING_FACTOR_V + (IS_IPHONE ? -5 : 0))];
	[levelsMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelsMenu:)];
	[levelsMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelsMenu:)];
	
	LHSprite* restartMenuButton = [_levelLoader createSpriteWithName:@"Restart_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	restartMenuButton.zOrder = _mainLayer.zOrder+1;
	[restartMenuButton prepareAnimationNamed:@"Menu_Restart_Button" fromSHScene:@"Spritesheet"];
	[restartMenuButton transformPosition: ccp(winSize.width/2 + restartMenuButton.boundingBox.size.width,
											 winSize.height/2 - 58*SCALING_FACTOR_V + (IS_IPHONE ? -5 : 0))];
	[restartMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[restartMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];
	
}

-(void) restart {

	DebugLog(@"Restarting");

	[self setStateGameOver];

	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Restart", @"Level_Lost_Reason",
	nil];
	[Analytics endTimedEvent:@"Begin_Level" withParameters:flurryParams];

	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[GameLayer sceneWithLevelPackPath:_levelPackPath levelPath:_levelPath]]];
}







-(void) goToNextLevel {
	NSString* nextLevelPath = [LevelPackManager levelAfter:_levelPath inPack:_levelPackPath];
	DebugLog(@"Going to next level %@", nextLevelPath);
	
	if(nextLevelPath == nil) {
		//TODO: show some kind of pack completed notification
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelPackSelectLayer scene] ]];
	
	}else {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:_levelPackPath levelPath:nextLevelPath]]];
	}
}

-(void) showMainMenuLayer {
	DebugLog(@"Showing MainMenuLayer in GameLayer instance %f", _instanceId);
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[MainMenuLayer scene] ]];
}

-(void) showInAppPurchaseLayer {
	DebugLog(@"Showing InAppPurchaseLayer in GameLayer instance %f", _instanceId);
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[InAppPurchaseLayer scene] ]];
}

-(void) showLevelsMenuLayer {
	DebugLog(@"Showing LevelSelectLayer in GameLayer instance %f", _instanceId);
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelSelectLayer sceneWithLevelPackPath:[NSString stringWithFormat:@"%@", _levelPackPath]] ]];
}

-(void) showTutorial {

	LHSprite* tutorial = nil;

	//NOTE: maybe we always show tutorials for these levels?

	//have we shown this tutorial yet?
	if(![SettingsManager boolForKey:SETTING_HAS_SEEN_TUTORIAL_1]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial1"];
		if(tutorial != nil) {
			DebugLog(@"Showing tutorial 1");
			//[SettingsManager setBool:true forKey:SETTING_HAS_SEEN_TUTORIAL_1];
		}
	}
	if(tutorial == nil && ![SettingsManager boolForKey:SETTING_HAS_SEEN_TUTORIAL_2]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial2"];
		if(tutorial != nil) {
			DebugLog(@"Showing tutorial 2");
			//[SettingsManager setBool:true forKey:SETTING_HAS_SEEN_TUTORIAL_2];
		}
	}
	if(tutorial == nil && ![SettingsManager boolForKey:SETTING_HAS_SEEN_TUTORIAL_3]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial3"];
		if(tutorial != nil) {
			DebugLog(@"Showing tutorial 3");
			//[SettingsManager setBool:true forKey:SETTING_HAS_SEEN_TUTORIAL_3];
		}
	}
	if(tutorial == nil && ![SettingsManager boolForKey:SETTING_HAS_SEEN_TUTORIAL_3]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial4"];
		if(tutorial != nil) {
			DebugLog(@"Showing tutorial 4");
			//[SettingsManager setBool:true forKey:SETTING_HAS_SEEN_TUTORIAL_4];
		}
	}

	
	
	//generic for all tutorials
	if(tutorial != nil) {		
		//fade in all tutorial items
		for(LHSprite* tutorial in [_levelLoader spritesWithTag:TUTORIAL]) {
			[tutorial runAction: [CCSequence actions:
				[CCRepeatForever actionWithAction:
					[CCSequence actions:
						[CCFadeTo actionWithDuration:0.5f opacity:150],
						[CCFadeTo actionWithDuration:0.5f opacity:30],
					nil]
				],
				nil]
			];
		}
		[tutorial stopAllActions];
		[tutorial runAction:[CCSequence actions: 
				[CCDelayTime actionWithDuration:1.0f],
				[CCFadeIn actionWithDuration:1.5f],
			nil]
		];
		[tutorial registerTouchBeganObserver:self selector:@selector(onTouchBeganTutorial:)];
	}else {
		[self removeAllTutorials];
	}
}

-(void)fadeOutAllTutorials {
	for(LHSprite* tutorial in [_levelLoader spritesWithTag:TUTORIAL]) {
		[tutorial stopAllActions];
		[tutorial runAction:[CCFadeOut actionWithDuration:0.5f]];
	}
	[self scheduleOnce:@selector(removeAllTutorials) delay:0.5f];
}

-(void)removeAllTutorials {
	for(LHSprite* tutorial in [_levelLoader spritesWithTag:TUTORIAL]) {
		[tutorial removeSelf];
	}
}


-(void) updateMoveGrids {
	[self updateMoveGrids:false];
}
	
-(void) updateMoveGrids:(bool)force {

	if(!force && (_state != RUNNING && _state != PLACE && _state != SETUP)) {
		return;
	}
	
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
		
	if(_numPenguinsUpdatingMoveGrids == 0) {
	
		for(LHSprite* penguin in penguins) {

			_numPenguinsUpdatingMoveGrids++;
			MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:penguin.uniqueName];
			if(penguinMoveGridData.busy) {
				_numPenguinsUpdatingMoveGrids--;
				continue;
			}
			
			CGPoint penguinGridPos = [self toGrid:penguin.position];
			Penguin* penguinData = ((Penguin*)penguin.userInfo);
			
			if(penguinData.isSafe) {
				_numPenguinsUpdatingMoveGrids--;
				continue;
			}
			
			if(penguinData.isStuck) {
				//only update occasionally
				if(arc4random()%100 > 10) {
					_numPenguinsUpdatingMoveGrids--;
					continue;
				}
			}
							
			if(penguinGridPos.x > _gridWidth-1 || penguinGridPos.x < 0 || penguinGridPos.y > _gridHeight-1 || penguinGridPos.y < 0) {
				//ignore and let movePenguins handle it
				_numPenguinsUpdatingMoveGrids--;
				continue;
			}
			
			if(!penguinData.hasSpottedShark) {
				NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
				for(LHSprite* shark in sharks) {
					double dist = ccpDistance(shark.position, penguin.position);
					if(dist < penguinData.detectionRadius*SCALING_FACTOR_GENERIC) {
					
						penguinData.hasSpottedShark = true;
						
						[penguin prepareAnimationNamed:@"Penguin_Waddle" fromSHScene:@"Spritesheet"];
						if(_state == RUNNING) {
							[penguin playAnimation];
						}
						
						break;
					}
				}
			}
			
			if(penguinData.hasSpottedShark) {
			
				//AHHH!!!
				
				LHSprite* targetLand = nil;
				double minDistance = 10000;
				NSArray* lands = [_levelLoader spritesWithTag:LAND];
				for(LHSprite* land in lands) {
					double dist = ccpDistance(land.position, penguin.position);
					if(dist < minDistance) {
						minDistance = dist;
						targetLand = land;
					}
				}
				CGPoint targetLandGridPos = [self toGrid:targetLand.position];

				void(^updateBlock)(void) = [[^(void) {
					[penguinMoveGridData updateMoveGridToTile:targetLandGridPos fromTile:penguinGridPos];
					_numPenguinsUpdatingMoveGrids--;
				} copy] autorelease];
				dispatch_async(_moveGridPenguinUpdateQueue, updateBlock);
			}
		}
	}
			
	if(_numSharksUpdatingMoveGrids == 0) {

		LHSprite* targetPenguin = nil;
			
		for(LHSprite* shark in sharks) {

			_numSharksUpdatingMoveGrids++;
			MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];
			if(sharkMoveGridData.busy) {
				_numSharksUpdatingMoveGrids--;
				continue;
			}
			
			Shark* sharkData = ((Shark*)shark.userInfo);
			CGPoint sharkGridPos = [self toGrid:shark.position];
			
			if(sharkData.isStuck) {
				//only update occasionally
				if(arc4random()%100 > 10) {
					_numSharksUpdatingMoveGrids--;
					continue;
				}
			}

			if(sharkGridPos.x > _gridWidth-1 || sharkGridPos.x < 0 || sharkGridPos.y > _gridHeight-1 || sharkGridPos.y < 0) {
				//offscreen - ignore and let moveSharks handle it
				_numSharksUpdatingMoveGrids--;
				continue;
			}

			//set our search distance
			double minDistance = 100000000;
			if(!sharkData.targetAcquired) {
				for(LHSprite* penguin in penguins) {
					Penguin* penguinData = ((Penguin*)penguin.userInfo);
					if(penguinData.isSafe) {
						continue;
					}

					if(penguin.body->IsAwake()) {
						//we smell blood...
						minDistance = fmin(minDistance, sharkData.activeDetectionRadius * SCALING_FACTOR_GENERIC);
						break;
					}else {
						minDistance = fmin(minDistance, sharkData.restingDetectionRadius * SCALING_FACTOR_GENERIC);
					}
				}
			}

			//find the nearest penguin
			for(LHSprite* penguin in penguins) {
				Penguin* penguinData = ((Penguin*)penguin.userInfo);
				if(penguinData.isSafe) {
					continue;
				}	
				
				double dist = ccpDistance(shark.position, penguin.position);
				if(dist < minDistance) {
					//DebugLog(@"Shark %@'s closest penguin is %@ at %f", shark.uniqueName, penguin.uniqueName, dist);
					minDistance = dist;
					targetPenguin = penguin;
					sharkData.targetAcquired = true;
				}
			}
			
			if(targetPenguin != nil) {
				CGPoint targetPenguinGridPos = [self toGrid:targetPenguin.position];
				if(targetPenguinGridPos.x >= _gridWidth || targetPenguinGridPos.x < 0 || targetPenguinGridPos.y >= _gridHeight || targetPenguinGridPos.y < 0) {
					//offscreen - let him come back before we deal with him
					_numSharksUpdatingMoveGrids--;
					continue;
				}

				void(^updateBlock)(void) = [[^(void) {
					[sharkMoveGridData updateMoveGridToTile:targetPenguinGridPos fromTile:sharkGridPos];
					_numSharksUpdatingMoveGrids--;
				} copy] autorelease];
				dispatch_async(_moveGridSharkUpdateQueue, updateBlock);
			}
		}
	}
}

-(void)debitForToolboxItemUsage:(LHSprite*)toolboxItem {
	NSString* key = [NSString stringWithFormat:@"%@%@", SETTING_IAP_TOOLBOX_ITEM_COUNT, toolboxItem.shSpriteName];
	int count = [SettingsManager intForKey:key];
	if(count > 0) {
		count = [SettingsManager decrementIntBy:1 forKey:key];
		if(DEBUG_IAP) DebugLog(@"Deducting 1 for the use of IAP item %@ - new balance is %d", toolboxItem.shSpriteName, count);
	}else {
		if(DEBUG_IAP) DebugLog(@"Item %@ is not an IAP item", toolboxItem.shSpriteName);
	}
}

-(void)scoreToolboxItemPlacement:(LHSprite*)toolboxItem replaced:(bool)replaced {

	//accounting
	ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)toolboxItem.userData);
	int score = _state == PLACE ? (toolboxItemData.placeCost * (replaced ? 0 : 1)) :
								  (toolboxItemData.runningCost * (replaced ? 0.25 : 1));
				
	if(score == 0) {
		return;
	}
	
	//adjust score by the mass/power/etc.
	if([(id)toolboxItem.userData class] == [ToolboxItem_Debris class]) {
		ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)toolboxItem.userData);
		score*= 1+log(toolboxItemData.mass/1);
	}else if([(id)toolboxItem.userData class] == [ToolboxItem_Windmill class]) {
		ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)toolboxItem.userData);
		score*= 1+log(toolboxItemData.power/50);
	}else if([(id)toolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
		ToolboxItem_Whirlpool* toolboxItemData = ((ToolboxItem_Whirlpool*)toolboxItem.userData);
		score*= 1+log(toolboxItemData.power/200);
	}
	
	//round to 25s
	score = (score/25)*25;
	
				
	[_scoreKeeper addScore:score description:(_state == PLACE ? @"PLACE" : @"RUNNING") sprite:toolboxItem group:true];
	
	//show a notification about the cost of the item
	CCLabelTTF* toolboxItemCostNotification = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"-%d", score] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS];
	toolboxItemCostNotification.color = ccRED;
	toolboxItemCostNotification.position = toolboxItem.position;
	[self addChild:toolboxItemCostNotification];
	
	[toolboxItemCostNotification runAction:[CCSequence actions:
		[CCMoveBy actionWithDuration:1.5f position:ccp(0, 200*SCALING_FACTOR_V)],
		nil]
	];
	[toolboxItemCostNotification runAction:[CCSequence actions:
		[CCDelayTime actionWithDuration:0.50f],
		[CCFadeOut actionWithDuration:1.0f],
		nil]
	];
}


-(void)physicsStep:(ccTime)dt {
			
	/* Update the physics - we do this even during PAUSE because */
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	
	/*
	this SERIOUSLY slows things down
	
	_box2dStepAccumulator+= dt;
	while(_box2dStepAccumulator > TARGET_PHYSICS_STEP) {
	
		_box2dStepAccumulator-= TARGET_PHYSICS_STEP;
	
		_world->Step(TARGET_PHYSICS_STEP, velocityIterations, positionIterations);
			
	
		
		if(DEBUG_ALL_THE_THINGS) DebugLog(@"Done with world step");
	}*/
	_world->Step(dt, velocityIterations, positionIterations);

	
	//Iterate over the bodies in the physics world
	for (b2Body* b = _world->GetBodyList(); b; b = b->GetNext())
	{
		if (b->GetUserData() != NULL)
		{
			//Synchronize the AtlasSprites position and rotation with the corresponding body
			CCSprite *myActor = (CCSprite*)b->GetUserData();
			
			if(myActor != 0)
			{
				//THIS IS VERY IMPORTANT - GETTING THE POSITION FROM BOX2D TO COCOS2D
				myActor.position = [LevelHelperLoader metersToPoints:b->GetPosition()];
				myActor.rotation = -1 * CC_RADIANS_TO_DEGREES(b->GetAngle());
			}
			
		}
	}
}

-(void) update: (ccTime) dt
{

	/* !lways keep the physics going.
	Linear Damping will stop actors
	Whirlpools will keep spinning
	Logs will be stopped by Linear damping but get a nice little spin out effect when paused
	*/
	if(_state != GAME_OVER) {
		[self physicsStep:dt];
	}

	if(_state != RUNNING && _state != PLACE) {
		return;
	}
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Update tick");
		

	/* Things that can occur while placing toolbox items or while running */
	
	if(_state == RUNNING) {
		_levelRunningTimeDuration+= dt;
	}else {
		_levelPlaceTimeDuration+= dt;
	}
	
	double elapsedTime = _levelRunningTimeDuration+_levelPlaceTimeDuration;
	_timeElapsedLabel.string = [NSString stringWithFormat:@"%d", (int)elapsedTime];
	
	
	if(_shouldUpdateToolbox) {
		_shouldUpdateToolbox = false;
		[self updateToolbox];
	}	
	
	//drop any toolbox items if need be
	if(_activeToolboxItem != nil && _moveActiveToolboxItemIntoWorld) {
	
		if(DEBUG_TOOLBOX) DebugLog(@"Adding toolbox item %@ to world", [(id)_activeToolboxItem.userData class]);
		
		NSString* soundFileName = @"place.wav";
	
		//StaticToolboxItem are things penguins and sharks can't move through
		if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Debris class]) {
			_activeToolboxItem.tag = DEBRIS;
			[_activeToolboxItem makeDynamic];
			[_activeToolboxItem setSensor:false];
			soundFileName = @"place-debris.wav";
			
		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Obstruction class]) {
			_activeToolboxItem.tag = OBSTRUCTION;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			[self invalidateFeatureGridsNear:nil];
			[self invalidateMoveGridsNear:_activeToolboxItem];
			soundFileName = @"place-obstruction.wav";

		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Windmill class]) {
			_activeToolboxItem.tag = WINDMILL;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-windmill.wav";
		
		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
			_activeToolboxItem.tag = WHIRLPOOL;
			[_activeToolboxItem makeDynamic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-whirlpool.wav";
		
		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Sandbar class]) {
			_activeToolboxItem.tag = SANDBAR;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			[self invalidateSharkFeatureGridsNear:nil];
			[self invalidateSharkMoveGridsNear:_activeToolboxItem];
			soundFileName = @"place-sandbar.wav";
		
		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Bag_of_Fish class]) {
			_activeToolboxItem.tag = BAG_OF_FISH;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-bag-of-fish.wav";
		
		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Invisibility_Hat class]) {
			_activeToolboxItem.tag = INVISIBILITY_HAT;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-invisibility-hat.wav";
		
		}else if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Loud_Noise class]) {
			_activeToolboxItem.tag = LOUD_NOISE;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-loud-noise.wav";
		
		}

		
		//move it into the main layer so it's under the HUD
		if(_activeToolboxItem.parent == _toolboxBatchNode) {
			//make sure we only do all of these things once
			[_toolboxBatchNode removeChild:_activeToolboxItem cleanup:NO];
			[_mainLayer addChild:_activeToolboxItem];
			[_placedToolboxItems addObject:_activeToolboxItem];
			[self scoreToolboxItemPlacement:_activeToolboxItem replaced:false];

			//analytics logging
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
				_levelPackPath, @"Level_Pack",
				[NSString stringWithFormat:@"%@",[(id)_activeToolboxItem.userData class]], @"Toolbox_Item_Class",
				_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
				[NSNumber numberWithInt:_state], @"Game_State",
				NSStringFromCGPoint(_activeToolboxItem.position), @"Location",
			nil];
			[Analytics logEvent:@"Place_Toolbox_Item" withParameters:flurryParams];
			
		}else {

			[self scoreToolboxItemPlacement:_activeToolboxItem replaced:true];

			//analytics logging
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
				_levelPackPath, @"Level_Pack",
				[NSString stringWithFormat:@"%@",[(id)_activeToolboxItem.userData class]], @"Toolbox_Item_Class",
				_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
				[NSNumber numberWithInt:_state], @"Game_State",
				NSStringFromCGPoint(_activeToolboxItem.position), @"Location",
			nil];
			[Analytics logEvent:@"Move_Placed_Toolbox_Item" withParameters:flurryParams];		
		
		}


		if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
			[[SimpleAudioEngine sharedEngine] playEffect:[NSString stringWithFormat:@"sounds/game/toolbox/%@", soundFileName ]];
		}
		
		[_activeToolboxItem removeTouchObserver];
		[_activeToolboxItem registerTouchBeganObserver:self selector:@selector(onTouchBeganToolboxItem:)];
		[_activeToolboxItem registerTouchEndedObserver:self selector:@selector(onTouchEndedToolboxItem:)];
	
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = true;
	}
	
	//do any grid updates as requested
	bool hasUpdateFeatureGrid = false;
	if(!_isInvalidatingSharkFeatureGrids && _sharksThatNeedToUpdateFeatureGrids.count > 0) {
		_isInvalidatingSharkFeatureGrids = true;
		[self generateFeatureGrids];
		hasUpdateFeatureGrid = true;
		for(LHSprite* shark in _sharksThatNeedToUpdateFeatureGrids) {
			[self updateFeatureMapForShark:shark];
		}
		
		//this can remove some objects that were added during this time... but we'll take our chances for now
		[_sharksThatNeedToUpdateFeatureGrids removeAllObjects];
		_isInvalidatingSharkFeatureGrids = false;
	}
	
	//do any grid updates as requested
	if(!_isInvalidatingPenguinFeatureGrids && _penguinsThatNeedToUpdateFeatureGrids.count > 0) {
		_isInvalidatingPenguinFeatureGrids = true;
		if(!hasUpdateFeatureGrid) {
			[self generateFeatureGrids];
		}
		for(LHSprite* penguin in _penguinsThatNeedToUpdateFeatureGrids) {
			[self updateFeatureMapForPenguin:penguin];
		}
		//this can remove some objects that were added during this time... but we'll take our chances for now
		[_penguinsThatNeedToUpdateFeatureGrids removeAllObjects];
		_isInvalidatingPenguinFeatureGrids = false;
	}
	
	//spin the whirlpools at a constant rate
	for(LHSprite* whirlpool in [_levelLoader spritesWithTag:WHIRLPOOL]) {
		ToolboxItem_Whirlpool* whirlpoolData = (ToolboxItem_Whirlpool*)whirlpool.userData;
		double angVel = whirlpool.body->GetAngularVelocity();
		double targetAngVel = whirlpoolData.power/100;
		if(fabs(angVel) != targetAngVel) {
			whirlpool.body->ApplyAngularImpulse(.1*(angVel < 0 ? (-targetAngVel-angVel) : (targetAngVel-angVel)));
		}
		whirlpool.flipX = angVel > 0;
	}

	
	if(!DISTRIBUTION_MODE && __DEBUG_TOUCH_SECONDS != 0) {
		double elapsed = ([[NSDate date] timeIntervalSince1970] - __DEBUG_TOUCH_SECONDS);
		if(elapsed >= 1 && !__DEBUG_SHARKS) {
			DebugLog(@"Enabling debug sharks");
			__DEBUG_SHARKS = true;
			__DEBUG_PENGUINS = false;
			__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
			self.color = ccBLACK;
			NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
			for(LHSprite* background in backgrounds) {
				[background setVisible:false];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
				_levelPackPath, @"Level_Pack",
			nil];
			[Analytics logEvent:@"Debug_Sharks_Enabled" withParameters:flurryParams];
			
		}
		if(elapsed >= 2 && !__DEBUG_PENGUINS) {
			DebugLog(@"Enabling debug penguins");
			__DEBUG_PENGUINS = true;
			__DEBUG_SHARKS = false;
			__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
			self.color = ccBLACK;
			NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
			for(LHSprite* background in backgrounds) {
				[background setVisible:false];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
				_levelPackPath, @"Level_Pack",
			nil];
			[Analytics logEvent:@"Debug_Penguins_Enabled" withParameters:flurryParams];
		}
		if(elapsed >= 5 && (__DEBUG_PENGUINS || __DEBUG_SHARKS)) {
			DebugLog(@"Disable debug penguins and sharks");
			__DEBUG_PENGUINS = false;
			__DEBUG_SHARKS = false;
			self.color = __DEBUG_ORIG_BACKGROUND_COLOR;
			self.color = ccBLACK;
			NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
			for(LHSprite* background in backgrounds) {
				[background setVisible:true];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
				_levelPackPath, @"Level_Pack",
			nil];
			[Analytics logEvent:@"Disable_Debug_Penguins_and_Sharks" withParameters:flurryParams];
		}
	}
	
	[self updateMoveGrids];
	
	/*************************************/

	if(_state != RUNNING) {
		return;
	}
	

	//place penguins on land for visual appeal
	for(id penguinName in _penguinsToPutOnLand) {
		LHSprite* penguin = [_levelLoader spriteWithUniqueName:penguinName];
		LHSprite* land = [_penguinsToPutOnLand objectForKey:penguinName];
		[penguin makeNoPhysics];
		[penguin transformPosition:land.position];
	}
	[_penguinsToPutOnLand removeAllObjects];
	
	if(HAND_OF_GOD_INITIAL_POWER > 0) {
		if(_isNudgingPenguin) {
			_handOfGodPowerSecondsRemaining-= dt;
			_handOfGodPowerSecondsUsed+= dt;
			
			if(_handOfGodPowerSecondsRemaining < 0) {
				_handOfGodPowerSecondsRemaining = 0;
			}
			
		}else if(_handOfGodPowerSecondsRemaining < HAND_OF_GOD_INITIAL_POWER) {
			_handOfGodPowerSecondsRemaining+= dt*HAND_OF_GOD_POWER_REGENERATION_RATE;
		}
		[_handOfGodPowerNode setPercentFill:(_handOfGodPowerSecondsRemaining/HAND_OF_GOD_INITIAL_POWER)];
	}
	
	[self moveSharks:dt];
	[self movePenguins:dt];
	

	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Done with update tick");

}

-(void)invalidateFeatureGridsNearMovingLands {
	/*
	NSArray* lands = [_levelLoader spritesWithTag:LAND];
	for(LHSprite* land in lands) {
		if([land.userInfoClassName isEqualToString:@"MovingLand"]) {
			[self invalidateFeatureGridsNear:land];
		}
	}*/
	
	[self invalidateFeatureGridsNear:nil];
}

-(void)invalidateFeatureGridsNearMovingBorders {
	/*
	- this doesn't work on a level like Pack2/PerfectFit
	NSArray* borders = [_levelLoader spritesWithTag:BORDER];
	for(LHSprite* border in borders) {
		if([border.userInfoClassName isEqualToString:@"MovingBorder"]) {
			[self invalidateFeatureGridsNear:border];
		}
	}*/
	
	[self invalidateFeatureGridsNear:nil];
}

-(void) invalidateFeatureGridsNear:(LHSprite*)sprite {
	[self invalidatePenguinFeatureGridsNear:sprite];
	[self invalidateSharkFeatureGridsNear:sprite];
}

-(void) invalidateSharkFeatureGridsNear:(LHSprite*)sprite {	
	for(LHSprite* shark in [_levelLoader spritesWithTag:SHARK]) {
		if(sprite == nil || ccpDistance(sprite.position, shark.position) < max(sprite.boundingBox.size.width/2,sprite.boundingBox.size.height/2)+50*SCALING_FACTOR_GENERIC) {
			if(![_sharksThatNeedToUpdateFeatureGrids containsObject:shark]) {
				[_sharksThatNeedToUpdateFeatureGrids addObject:shark];
			}
		}else {
			/* if this is enabled, add some bounds checking and verification that the moveGrid has been created
			MoveGridData* sharkMoveGridData = [_sharkMoveGridDatas objectForKey:shark.uniqueName];
			CGPoint sharkGridPos = [self toGrid:shark.position];
			if(sharkMoveGridData.moveGrid[(int)sharkGridPos.x][(int)sharkGridPos.y] == HARD_BORDER_WEIGHT) {
				[sharksToUpdate addObject:shark];
			}
			*/
		}
	}
}

-(void) invalidatePenguinFeatureGridsNear:(LHSprite*)sprite {
	for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
		if(sprite == nil || ccpDistance(sprite.position, penguin.position) < max(sprite.boundingBox.size.width/2,sprite.boundingBox.size.height/2)+50*SCALING_FACTOR_GENERIC) {
			if(![_penguinsThatNeedToUpdateFeatureGrids containsObject:penguin]) {
				[_penguinsThatNeedToUpdateFeatureGrids addObject:penguin];
			}
		}else {
			/* if this is enabled, add some bounds checking and verification that the moveGrid has been created
			MoveGridData* penguinMoveGridData = [_sharkMoveGridDatas objectForKey:penguin.uniqueName];
			CGPoint penguinGridPos = [self toGrid:penguin.position];
			if(penguinMoveGridData.moveGrid[(int)penguinGridPos.x][(int)penguinGridPos.y] == HARD_BORDER_WEIGHT) {
				[penguinsToUpdate addObject:penguin];
			}*/			
		}
	}
}

-(void) invalidateMoveGridsNear:(LHSprite*)sprite {
	[self invalidatePenguinMoveGridsNear:sprite];
	[self invalidateSharkMoveGridsNear:sprite];
}

-(void) invalidateSharkMoveGridsNear:(LHSprite*)sprite {
	for(LHSprite* shark in [_levelLoader spritesWithTag:SHARK]) {
		if(sprite == nil || ccpDistance(sprite.position, shark.position) < 150*SCALING_FACTOR_GENERIC) {
			[(MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName] invalidateMoveGrid];
		}
	}
}

-(void) invalidatePenguinMoveGridsNear:(LHSprite*)sprite {
	for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
		if(sprite == nil || ccpDistance(sprite.position, penguin.position) < 150*SCALING_FACTOR_GENERIC) {
			[(MoveGridData*)[_penguinMoveGridDatas objectForKey:penguin.uniqueName] invalidateMoveGrid];
		}
	}
}

-(CGPoint)getMovementModEffects:(LHSprite*)sprite {

	//used for each effect
	double dxMod = 0;
	double dyMod = 0;
	
	//aggregate
	CGPoint dMod = ccp(dxMod, dyMod);

	//TODO: this is inefficient because it casts much more often than it needs to. optimize if need be
	//adjust the shark speed by any movement altering affects in play (such as windmills)
	float32 minWindmillFraction = 1;
	NSArray* windmills = [_levelLoader spritesWithTag:WINDMILL];
	for(LHSprite* windmill in windmills) {
		ToolboxItem_Windmill* windmillData = ((ToolboxItem_Windmill*)windmill.userData);
		//facing east by default
		int rotation = ((int)(windmill.rotation+90))%360;
		double xDir = sin(CC_DEGREES_TO_RADIANS(rotation));
		double yDir = cos(CC_DEGREES_TO_RADIANS(rotation));
		b2Vec2 windmillPos = windmill.body->GetPosition();
		b2Vec2 directionVector = b2Vec2(windmillPos.x + windmillData.reach*xDir,
										windmillPos.y + windmillData.reach*yDir);
								
		//returns if the shark is in front of the windmill
		WindmillRaycastCallback callback;
		_world->RayCast(&callback, windmillPos, directionVector);
		 
		if (callback._fixture) {
			if (callback._fixture->GetBody() == sprite.body && callback._fraction < minWindmillFraction) {
			
				minWindmillFraction = callback._fraction;
			
				//shark is in the way!!
				//DebugLog(@"Sprite %@ is in the way of a windmill %@! Applying effects...", sprite.uniqueName, windmill.uniqueName);
				
				double dModSum = fabs(xDir) + fabs(yDir);
				if(dModSum == 0) {
					dModSum = 1;
				}					
				
				dxMod = (xDir/dModSum)*(windmillData.power);
				dyMod = (yDir/dModSum)*(windmillData.power);				
			}
		}
	}
	dMod = ccp(dMod.x+dxMod, dMod.y+dyMod);


	/// whirlpools!
	dxMod = 0;
	dyMod = 0;
	NSArray* whirlpools = [_levelLoader spritesWithTag:WHIRLPOOL];
	for(LHSprite* whirlpool in whirlpools) {
		ToolboxItem_Whirlpool* whirlpoolData = ((ToolboxItem_Whirlpool*)whirlpool.userData);
		
			double dist = ccpDistance(sprite.position, whirlpool.position);
			if(dist < whirlpoolData.power*SCALING_FACTOR_GENERIC) {
				
				b2Vec2 vortexVelocity = whirlpool.body->GetLinearVelocityFromWorldPoint( sprite.body->GetPosition() );
				b2Vec2 vortexVelocityN = vortexVelocity;
				vortexVelocityN.Normalize();
				
				//this will provide a slight pull to the center
				b2Vec2 d = whirlpool.body->GetPosition() - sprite.body->GetPosition();
				b2Vec2 dN = d;
				dN.Normalize();
				
				double power = whirlpoolData.power - dist;
				power = power < 1 ? 1 : power;
				double rotationalPower = 2*log(power);
				double suckingPower = power*.025;
				
				dxMod = vortexVelocity.x*rotationalPower + dN.x*suckingPower;
				dyMod = vortexVelocity.y*rotationalPower + dN.y*suckingPower;
				
				/*DebugLog(@"Applying Whirlpool effect to %@ with dxMod=%f, dyMod=%f, dist=%f, angularVelocity=%f, vortexVelocity=%@, dN=%@",
						sprite.uniqueName, dxMod, dyMod, dist, whirlpool.body->GetAngularVelocity(),
						NSStringFromCGPoint(ccp(vortexVelocity.x,vortexVelocity.y)),
						NSStringFromCGPoint(ccp(dN.x,dN.y)));
				*/
			}
	}
	dMod = ccp(dMod.x+dxMod, dMod.y+dyMod);	
	
	
	
	
	return dMod;
}

-(void) moveSharks:(ccTime)dt {
		
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Moving %d sharks...", [sharks count]);
	
	
	if(SHARK_DIES_WHEN_STUCK && [sharks count] == 0) {
		//winna winna chicken dinna!
		[self levelWon];
		return;
	}
		
	for(LHSprite* shark in sharks) {
		
		bool needsToJitter = false;
		Shark* sharkData = ((Shark*)shark.userInfo);
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];		
		CGPoint sharkGridPos = [self toGrid:shark.position];

		//using a gridPos of 1 inside the actual border because of a programmatically-added HARD BORDER around the grid
		if(sharkGridPos.x > _gridWidth-2 || sharkGridPos.x < 1 || sharkGridPos.y > _gridHeight-2 || sharkGridPos.y < 1) {
			if(DEBUG_MOVEGRID) DebugLog(@"Shark %@ is off-grid at %f,%f - moving him back on", shark.uniqueName, sharkGridPos.x, sharkGridPos.y);
			
			if(sharkGridPos.x > _gridWidth-2) {
				sharkGridPos.x = _gridWidth-2;
				[shark transformPosition:ccp(sharkGridPos.x*_gridSize,shark.position.y)];
			}
			if(sharkGridPos.x < 1) {
				sharkGridPos.x = 1;
				[shark transformPosition:ccp(sharkGridPos.x*_gridSize,shark.position.y)];
			}
			if(sharkGridPos.y > _gridHeight-2) {
				sharkGridPos.y = _gridHeight-2;
				[shark transformPosition:ccp(shark.position.x,sharkGridPos.y*_gridSize)];
			}
			if(sharkGridPos.y < 1) {
				sharkGridPos.y = 1;
				[shark transformPosition:ccp(shark.position.x,sharkGridPos.y*_gridSize)];
			}

			needsToJitter = true;
		}
		
		
		//readjust if we are somehow on top of land - this can happen when fans blow an actor on land or a moving border touches an actor, for example
		int bumpIterations = 0;
		double lastFoundStuckBorderDist = 0;
		while(sharkMoveGridData.moveGrid[(int)sharkGridPos.x][(int)sharkGridPos.y] == HARD_BORDER_WEIGHT
				&& bumpIterations < MAX_BUMP_ITERATIONS_TO_UNSTICK_FROM_LAND) {
			//move back off of land
			bumpIterations++;
			
			//we are now stuck - trace the land and find the closet point to hop off at
			
			double minDist = 10000;
			LHSprite* touchedBoder = nil;
			NSMutableArray* borders = [NSMutableArray arrayWithArray:[_levelLoader spritesWithTag:BORDER]];
			[borders addObjectsFromArray:[_levelLoader spritesWithTag:OBSTRUCTION]];
			[borders addObjectsFromArray:[_levelLoader spritesWithTag:LAND]];
			[borders addObjectsFromArray:[_levelLoader spritesWithTag:SANDBAR]];

			for(LHSprite* border in borders) {
				double dist = ccpDistance(border.position, shark.position);
				if(dist > lastFoundStuckBorderDist && dist < minDist) {
					minDist = dist;
					touchedBoder = border;
				}
			}
			
			if(touchedBoder != nil) {
			
				//this makes the search ever-expanding
				lastFoundStuckBorderDist = bumpIterations%(MAX_BUMP_ITERATIONS_TO_UNSTICK_FROM_LAND/3) == 0 ? minDist : lastFoundStuckBorderDist;
			
				CGPoint borderN = ccp(touchedBoder.position.x, touchedBoder.position.y+touchedBoder.boundingBox.size.height/2 + _gridSize/2);
				double distN = ccpDistance(shark.position, borderN);
				CGPoint borderS = ccp(touchedBoder.position.x, touchedBoder.position.y-touchedBoder.boundingBox.size.height/2 - _gridSize/2);
				double distS = ccpDistance(shark.position, borderS);
				CGPoint borderE =  ccp(touchedBoder.position.x+touchedBoder.boundingBox.size.width/2 + _gridSize/2, touchedBoder.position.y);
				double distE = ccpDistance(shark.position, borderE);
				CGPoint borderW = ccp(touchedBoder.position.x-touchedBoder.boundingBox.size.width/2 - _gridSize/2, touchedBoder.position.y);
				double distW = ccpDistance(shark.position, borderW);
				double absMin = fmin(fmin(fmin(distE, distW), distN), distS);
				
				if(distN == absMin) {
					[shark transformPosition:ccp(shark.position.x, (shark.position.y*2+borderN.y)/3)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the north of border %@ he is in contact with", shark.uniqueName, touchedBoder.uniqueName);
				}else if(distS == absMin) {
					[shark transformPosition:ccp(shark.position.x, (shark.position.y*2+borderS.y)/3)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the south of border %@ he is in contact with", shark.uniqueName, touchedBoder.uniqueName);
				}else if(distE == absMin) {
					[shark transformPosition:ccp((shark.position.x*2+borderE.x)/3, shark.position.y)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the east of border %@ he is in contact with", shark.uniqueName, touchedBoder.uniqueName);
				}else if(distW == absMin) {
					[shark transformPosition:ccp((shark.position.x*2+borderW.x)/3, shark.position.y)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the west of border %@ he is in contact with", shark.uniqueName, touchedBoder.uniqueName);
				}
			}
						
			sharkGridPos = [self toGrid:shark.position];			
		}
		
		//use the best route algorithm
		CGPoint bestOptionPos = [sharkMoveGridData getBestMoveToTile:sharkMoveGridData.lastTargetTile fromTile:sharkGridPos];
	
		//DebugLog(@"Best Option Pos: %f,%f", bestOptionPos.x,bestOptionPos.y);
		if(bestOptionPos.x == -10000 && bestOptionPos.y == -10000) {
			//this occurs when the shark has no route to the penguin - he literally has no idea which way to go
			
			if(!sharkData.isStuck) {
				if(DEBUG_MOVEGRID) DebugLog(@"Shark %@ is stuck (no where to go) - we're making him stop", shark.uniqueName);
			}

			//reject any moves
			bestOptionPos = shark.position;
				
			//frustrated
			[shark setFrame:1];
			sharkData.isStuck= true;
								
		}else {
					
			//convert returned velocities to position..
			bestOptionPos = ccp(shark.position.x+bestOptionPos.x, shark.position.y+bestOptionPos.y);
			sharkData.isStuck = false;
			
		}
		
		double dx = bestOptionPos.x - shark.position.x;
		double dy = bestOptionPos.y - shark.position.y;

		double sharkSpeed = sharkData.restingSpeed;
		if(sharkData.targetAcquired) {
			sharkSpeed = sharkData.activeSpeed;
		}
				
		[sharkMoveGridData logMove:bestOptionPos];
		//DebugLog(@"shark dist traveled: %f, bestOptionPos: %@", [sharkMoveGridData distanceTraveledStraightline], NSStringFromCGPoint(bestOptionPos));
		if(needsToJitter || [sharkMoveGridData distanceTraveledStraightline] < 5*SCALING_FACTOR_GENERIC) {
			if(SHARK_DIES_WHEN_STUCK) {
				//we're stuck
				if(DEBUG_MOVEGRID) DebugLog(@"Shark %@ is stuck (trying to move, but not making progress) - we're removing him", shark.uniqueName);
				[shark removeSelf];
			}

			//frustrated
			[shark setFrame:1];
			//sharkData.isStuck = true;

		}else {
			//normal
			[shark setFrame:0];
			//sharkData.isStuck = false;
		}

		CGPoint dMod = [self getMovementModEffects:shark];
				
		if(dMod.x != 0 || dMod.y != 0) {

			[sharkMoveGridData scheduleUpdateToMoveGridIn:0.25f];
		
			//prevents futile attempts to fight against a windmill by making opposing wind forces less and less attractive
			CGPoint targetGridPos = ccp(sharkGridPos.x + (dMod.x*dx < 0 ? (dMod.x < 0 ? 1 : -1) : 0),
										sharkGridPos.y + (dMod.y*dy < 0 ? (dMod.y < 0 ? 1 : -1) : 0));
			//DebugLog(@"sharkGridPos: %@ - Target Grid Pos: %@ ---- dxMod: %f, dyMod=%f, dx=%f, dy=%f", NSStringFromCGPoint(sharkGridPos), NSStringFromCGPoint(targetGridPos), dxMod, dyMod, dx, dy);
			if(targetGridPos.x >= 0 && targetGridPos.x < _gridWidth && targetGridPos.y >= 0 && targetGridPos.y < _gridHeight
					&& (targetGridPos.x != sharkGridPos.x || targetGridPos.y != sharkGridPos.y)) {
				short w = sharkMoveGridData.moveGrid[(int)targetGridPos.x][(int)targetGridPos.y];
				//DebugLog(@"sharkGridPos: %@ - INCREMENTING %@ at weight %d", NSStringFromCGPoint(sharkGridPos), NSStringFromCGPoint(targetGridPos), w);
				if(w != HARD_BORDER_WEIGHT) {
					sharkMoveGridData.moveGrid[(int)targetGridPos.x][(int)targetGridPos.y]++;
					sharkMoveGridData.baseGrid[(int)targetGridPos.x][(int)targetGridPos.y]++;
				}
			}
		}
				
		double dSum = fabs(dx) + fabs(dy);
		if(dSum == 0) {
			//no best option?
			//DebugLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
			dSum = 1;
		}
		double normalizedX = dx/dSum;
		double normalizedY = dy/dSum;

		double impulseX = (((sharkSpeed*normalizedX)+dMod.x)*dt)*IMPULSE_SCALAR/**pow(shark.scale,2)*/;
		double impulseY = (((sharkSpeed*normalizedY)+dMod.y)*dt)*IMPULSE_SCALAR/**pow(shark.scale,2)*/;
		
		//DebugLog(@"Shark %@'s normalized x,y = %f,%f. dx=%f, dy=%f dxMod=%f, dyMod=%f. impulse = %f,%f, dt=%f, impulseScalar=%f", shark.uniqueName, normalizedX, normalizedY, dx, dy, dMod.x, dMod.y, impulseX, impulseY, dt, IMPULSE_SCALAR);
			
		//we're using an impulse for the shark so they interact with things like Debris (physics)
		shark.body->ApplyLinearImpulse(b2Vec2(impulseX, impulseY), shark.body->GetWorldCenter());
		
		
		double rotationRadians = 0;
		if(normalizedX != 0 || normalizedY != 0) {
			//rotate shark in the direction he's moving
			rotationRadians = atan2(normalizedX, normalizedY); //this grabs the radians for us
		}else {
			//rotate shark to watch that dastardly penguin
			LHSprite* nearestPenguin = nil;
			float minDist = 100000;
			for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
				float dist = ccpDistance(shark.position, penguin.position);
				if(dist < minDist) {
					nearestPenguin = penguin;
					minDist = dist;
				}
			}
			rotationRadians = atan2(nearestPenguin.position.x - shark.position.x,
									nearestPenguin.position.y - shark.position.y); //this grabs the radians for us
		}
		int targetRotation = (CC_RADIANS_TO_DEGREES(rotationRadians) - 90); //90 is because the sprite is facing right
		double smoothedRotation = targetRotation*shark.rotation < 0 || abs(shark.rotation-targetRotation) > 180 ? targetRotation : (double)(targetRotation+(int)shark.rotation*4)/5;
		//DebugLog(@"ROTATING SHARK TO %f with targetRotation of %d", smoothedRotation, targetRotation);
		[shark transformRotation:smoothedRotation];
	}
	
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Done moving %d sharks...", [sharks count]);
}

-(void) movePenguins:(ccTime)dt {

	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Moving %d penguins...", [penguins count]);

	bool hasWon = true;
	for(LHSprite* penguin in penguins) {
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
		if(!penguinData.isSafe) {
			hasWon = false;
			break;
		}
	}
	if(hasWon) {
		DebugLog(@"All penguins have made it to safety!");
		[self levelWon];
		return;
	}

	for(LHSprite* penguin in penguins) {
		
		bool needsToJitter = false;
		CGPoint penguinGridPos = [self toGrid:penguin.position];
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
		MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:penguin.uniqueName];
		
		if(penguinData.isSafe) {
			continue;
		}
		
		if(penguinGridPos.x > _gridWidth-2 || penguinGridPos.x < 1 || penguinGridPos.y > _gridHeight-2 || penguinGridPos.y < 1) {
			if(DEBUG_MOVEGRID) DebugLog(@"Penguin %@ is off-grid at %f,%f - moving him back on", penguin.uniqueName, penguinGridPos.x, penguinGridPos.y);
			
			//using a gridPos of 1 inside the actual border because of a programmatically-added HARD BORDER around the grid
			
			if(penguinGridPos.x > _gridWidth-2) {
				penguinGridPos.x = _gridWidth-2;
				[penguin transformPosition:ccp(penguinGridPos.x*_gridSize,penguin.position.y)];
			}
			if(penguinGridPos.x < 1) {
				penguinGridPos.x = 1;
				[penguin transformPosition:ccp(penguinGridPos.x*_gridSize,penguin.position.y)];
			}
			if(penguinGridPos.y > _gridHeight-2) {
				penguinGridPos.y = _gridHeight-2;
				[penguin transformPosition:ccp(penguin.position.x,penguinGridPos.y*_gridSize)];
			}
			if(penguinGridPos.y < 1) {
				penguinGridPos.y = 1;
				[penguin transformPosition:ccp(penguin.position.x,penguinGridPos.y*_gridSize)];
			}

			needsToJitter = true;
		}
		
		if(penguinData.hasSpottedShark) {
		
			//AHHH!!!
						
			//alert nearby penguins
			for(LHSprite* penguin2 in penguins) {
				if(![penguin2.uniqueName isEqualToString:penguin.uniqueName]) {
					if(ccpDistance(penguin.position, penguin2.position) <= penguinData.alertRadius*SCALING_FACTOR_GENERIC) {

						Penguin* penguin2UserData = ((Penguin*)penguin2.userInfo);
						if(!penguin2UserData.hasSpottedShark) {
							penguin2UserData.hasSpottedShark = true;
							
							[penguin2 prepareAnimationNamed:@"Penguin_Waddle" fromSHScene:@"Spritesheet"];
							if(_state == RUNNING) {
								[penguin2 playAnimation];
							}
						}
					}
				}
			}
			
			//readjust if we are somehow on top of land - this can happen when fans blow an actor on land, for example
			int bumpIterations = 0;
			double lastFoundStuckBorderDist = 0;
			while(penguinMoveGridData.moveGrid[(int)penguinGridPos.x][(int)penguinGridPos.y] == HARD_BORDER_WEIGHT
					&& bumpIterations < MAX_BUMP_ITERATIONS_TO_UNSTICK_FROM_LAND) {
				//move back onto land
				bumpIterations++;

				//we are now stuck - trace the land and find the closet point to hop off at
				
				double minDist = 10000;
				LHSprite* touchedBoder = nil;
				NSMutableArray* borders = [NSMutableArray arrayWithArray:[_levelLoader spritesWithTag:BORDER]];
				[borders addObjectsFromArray:[_levelLoader spritesWithTag:OBSTRUCTION]];

				for(LHSprite* border in borders) {
					double dist = ccpDistance(border.position, penguin.position);
					if(dist > lastFoundStuckBorderDist && dist < minDist) {
						minDist = dist;
						touchedBoder = border;
					}
				}
				
				if(touchedBoder != nil) {
				
					//this makes the search ever-expanding
					lastFoundStuckBorderDist = bumpIterations%(MAX_BUMP_ITERATIONS_TO_UNSTICK_FROM_LAND/3) == 0 ? minDist : lastFoundStuckBorderDist;
				
					CGPoint borderN = ccp(touchedBoder.position.x, touchedBoder.position.y+touchedBoder.boundingBox.size.height/2 + _gridSize/2);
					double distN = ccpDistance(penguin.position, borderN);
					CGPoint borderS = ccp(touchedBoder.position.x, touchedBoder.position.y-touchedBoder.boundingBox.size.height/2 - _gridSize/2);
					double distS = ccpDistance(penguin.position, borderS);
					CGPoint borderE =  ccp(touchedBoder.position.x+touchedBoder.boundingBox.size.width/2 + _gridSize/2, touchedBoder.position.y);
					double distE = ccpDistance(penguin.position, borderE);
					CGPoint borderW = ccp(touchedBoder.position.x-touchedBoder.boundingBox.size.width/2 - _gridSize/2, touchedBoder.position.y);
					double distW = ccpDistance(penguin.position, borderW);
					double absMin = fmin(fmin(fmin(distE, distW), distN), distS);
					
					if(distN == absMin) {
						[penguin transformPosition:ccp(penguin.position.x, (penguin.position.y*2+borderN.y)/3)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the north off border %@ he is in contact with", penguin.uniqueName, touchedBoder.uniqueName);
					}else if(distS == absMin) {
						[penguin transformPosition:ccp(penguin.position.x, (penguin.position.y*2+borderS.y)/3)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the south off border %@ he is in contact with", penguin.uniqueName, touchedBoder.uniqueName);
					}else if(distE == absMin) {
						[penguin transformPosition:ccp((penguin.position.x*2+borderE.x)/3, penguin.position.y)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the east off border %@ he is in contact with", penguin.uniqueName, touchedBoder.uniqueName);
					}else if(distW == absMin) {
						[penguin transformPosition:ccp((penguin.position.x*2+borderW.x)/3, penguin.position.y)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the west off border %@ he is in contact with", penguin.uniqueName, touchedBoder.uniqueName);
					}
				}
				
				penguinGridPos = [self toGrid:penguin.position];
				//needsToJitter = true;
			}
		

			//use the best route algorithm
			CGPoint bestOptionPos = [penguinMoveGridData getBestMoveToTile:penguinMoveGridData.lastTargetTile fromTile:penguinGridPos];
					
			if(bestOptionPos.x == -10000 && bestOptionPos.y == -10000) {
				if(!penguinData.isStuck) {
					if(DEBUG_MOVEGRID) DebugLog(@"Penguin %@ is stuck (nowhere to go)!", penguin.uniqueName);
				}
				
				//reject any moves
				bestOptionPos = penguin.position;

				penguinData.isStuck = true;
				
			}else {
				//convert returned velocities to position..
				penguinData.isStuck = false;
				bestOptionPos = ccp(penguin.position.x+bestOptionPos.x, penguin.position.y+bestOptionPos.y);
			}
					
			double dx = bestOptionPos.x - penguin.position.x;
			double dy = bestOptionPos.y - penguin.position.y;
			double penguinSpeed = penguinData.speed;

			[penguinMoveGridData logMove:bestOptionPos];
			if(needsToJitter || [penguinMoveGridData distanceTraveledStraightline] < 5*SCALING_FACTOR_GENERIC) {
				//we're stuck... but we'll let sharks report us as being stuck.
				//we'll just try and get ourselves out of this sticky situation
				
				double jitterX = 0;//((arc4random()%200)-100.0)/100;
				double jitterY = 0;//((arc4random()%200)-100.0)/100;
				
				dx+= jitterX;
				dy+= jitterY;
				penguinSpeed*= 10;
				//if(DEBUG_MOVEGRID) DebugLog(@"Penguin %@ is stuck (trying to move but can't) - giving him a bit of jitter %f,%f", penguin.uniqueName, jitterX, jitterY);
			}else {
				//penguinData.isStuck = false;
			}
			
			CGPoint dMod = [self getMovementModEffects:penguin];
					
			if(dMod.x != 0 || dMod.y != 0) {

				[penguinMoveGridData scheduleUpdateToMoveGridIn:0.25f];
			
				//prevents futile attempts to fight against a windmill by making opposing wind forces less and less attractive
				CGPoint targetGridPos = ccp(penguinGridPos.x + (dMod.x*dx < 0 ? (dMod.x < 0 ? 1 : -1) : 0),
											penguinGridPos.y + (dMod.y*dy < 0 ? (dMod.y < 0 ? 1 : -1) : 0));
				//DebugLog(@"penguinGridPos: %@ - Target Grid Pos: %@ ---- dxMod: %f, dyMod=%f, dx=%f, dy=%f", NSStringFromCGPoint(penguinGridPos), NSStringFromCGPoint(targetGridPos), dxMod, dyMod, dx, dy);
				if(targetGridPos.x >= 0 && targetGridPos.x < _gridWidth && targetGridPos.y >= 0 && targetGridPos.y < _gridHeight
						&& (targetGridPos.x != penguinGridPos.x || targetGridPos.y != penguinGridPos.y)) {
					short w = penguinMoveGridData.moveGrid[(int)targetGridPos.x][(int)targetGridPos.y];
					//DebugLog(@"penguinGridPos: %@ - INCREMENTING %@ at weight %d", NSStringFromCGPoint(penguinGridPos), NSStringFromCGPoint(targetGridPos), w);
					if(w != HARD_BORDER_WEIGHT) {
						penguinMoveGridData.moveGrid[(int)targetGridPos.x][(int)targetGridPos.y]++;
						penguinMoveGridData.baseGrid[(int)targetGridPos.x][(int)targetGridPos.y]++;
					}
				}
			}
				
			double dSum = fabs(dx) + fabs(dy);
			if(dSum == 0) {
				//no best option?
				//DebugLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
				dSum = 1;
			}
			double normalizedX = dx/dSum;
			double normalizedY = dy/dSum;
			
			double impulseX = (((penguinSpeed*normalizedX)+dMod.x)*dt)*IMPULSE_SCALAR/**pow(penguin.scale,2)*/;
			double impulseY = (((penguinSpeed*normalizedY)+dMod.y)*dt)*IMPULSE_SCALAR/**pow(penguin.scale,2)*/;
			
			//DebugLog(@"Penguin %@'s normalized x,y = %f,%f. dx=%f, dy=%f dMod.x=%f, dMod.y=%f. impulse = %f,%f", penguin.uniqueName, normalizedX, normalizedY, dx, dy, dMod.x, dMod.y, impulseX, impulseY);
				
			//we're using an impulse for the penguin so they interact with things like Debris (physics)
			penguin.body->ApplyLinearImpulse(b2Vec2(impulseX, impulseY), penguin.body->GetWorldCenter());			
		}
	}

	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Done moving %d penguins...", [penguins count]);

}

//if this ever gets trigger then the penguins lost
-(void) sharkPenguinCollision:(LHContactInfo*)contact
{        
	LHSprite* shark = [contact spriteA];
    LHSprite* penguin = [contact spriteB];
	Penguin* penguinData = ((Penguin*)penguin.userInfo);

    if(nil != penguin && nil != shark)
    {
		if(!penguinData.isDead) {
			penguinData.isDead = true;
			DebugLog(@"Shark %@ has collided with penguin %@!", shark.uniqueName, penguin.uniqueName);
			[self levelLostWithShark:shark andPenguin:penguin];
		}
    }
}

-(void) landPenguinCollision:(LHContactInfo*)contact
{
    LHSprite* land = [contact spriteA];
    LHSprite* penguin = [contact spriteB];
	Penguin* penguinData = ((Penguin*)penguin.userInfo);

    if(nil != penguin && nil != land)
    {
		if(!penguinData.isSafe) {
			penguinData.isSafe = true;
			[_penguinsToPutOnLand setObject:land forKey:penguin.uniqueName];
			DebugLog(@"Penguin %@ has collided with some land!", penguin.uniqueName);
		
			[penguin prepareAnimationNamed:@"Penguin_Happy" fromSHScene:@"Spritesheet"];
			[penguin playAnimation];			
			
			//tell all sharks they should update
			for(LHSprite* shark in [_levelLoader spritesWithTag:SHARK]) {
				[[_sharkMoveGridDatas objectForKey:shark.uniqueName] forceUpdateToMoveGrid];
			}
		}
    }
}








- (void)ccTouchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];
	
		if([touches count] == 1) {
			if(_activeToolboxItem != nil) {
				//toolbox item drag
				[_activeToolboxItem transformPosition:location];

			}else if(_state == PLACE && _startTouch.x != 0 && _startTouch.y != 0) {
				
				/* HANDLE WITH TOUCH OBSERVERS 
				//see if we can move an existing toolbox item
				LHSprite* touchedToolboxItem = nil;
				int minDistance = 50;
				for(LHSprite* sprite in [_levelLoader allSprites]) {
					if([sprite.userInfoClassName hasPrefix:@"ToolboxItem_" ]) {
						int dist = ccpDistance(sprite.position, _startTouch);
						if(dist < minDistance) {
							minDistance = dist;
							touchedToolboxItem = sprite;
						}
					}
				}
				if(touchedToolboxItem != nil) {
					_activeToolboxItem = touchedToolboxItem;
				
				}
				*/
			
			}else if(_state == RUNNING && _startTouch.x != 0 && _startTouch.y != 0) {
				
				if(_handOfGodPowerSecondsRemaining > 0) {
					//nudge the nearest penguin!
					
					if(!_isNudgingPenguin) {
						[_handOfGodPowerNode runAction:[CCFadeIn actionWithDuration:0.25f]];
					}
					_isNudgingPenguin = true;
					
					LHSprite* nearestPenguin = nil;
					int minDistance = 100000;
					for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
						int dist = ccpDistance(penguin.position, _startTouch);
						if(dist < minDistance) {
							minDistance = dist;
							nearestPenguin = penguin;
						}
					}
					if(nearestPenguin != nil) {
						//[nearestPenguin transformPosition:ccp(nearestPenguin.position.x+location.x-_lastTouch.x, nearestPenguin.position.y+location.y-_lastTouch.y)];
						if(nearestPenguin.body) {
							nearestPenguin.body->ApplyLinearImpulse(
								b2Vec2((location.x-_lastTouch.x)*(IMPULSE_SCALAR/10)/**pow(nearestPenguin.scale,2)*/,
										(location.y-_lastTouch.y)*(IMPULSE_SCALAR/10)/**pow(nearestPenguin.scale,2)*/),
								nearestPenguin.body->GetWorldCenter()
							);
						}
					}
				}

				_lastTouch = location;
			}
		}
	}
}


- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];

		if(_state == RUNNING || _state == PLACE) {
			if(_activeToolboxItem) {
			
				if(ccpDistance(location, _activeToolboxItem.position) > 50*SCALING_FACTOR_GENERIC) {
					//tapping a second finger on the screen when moving a toolbox item rotates the item
					
					if([(id)_activeToolboxItem.userData class] == [ToolboxItem_Whirlpool class]) {
						double angularVelocity = _activeToolboxItem.body->GetAngularVelocity();
						_activeToolboxItem.body->SetAngularVelocity(0);
						_activeToolboxItem.body->ApplyTorque(angularVelocity>0 ? -15 : 15);
						_activeToolboxItem.flipX = angularVelocity < 0;
					}else {
						[_activeToolboxItem transformRotation:((int)_activeToolboxItem.rotation+90)%360];
					}
					
					//scale up and down for visual effect
					ToolboxItem_Obstruction* toolboxItemData = ((ToolboxItem_Obstruction*)_activeToolboxItem.userData);	//ToolboxItem_Obstruction is used because all ToolboxItem classes have a "scale" property
					
					[_activeToolboxItem runAction:[CCSequence actions:
						[CCScaleTo actionWithDuration:0.05f scale:toolboxItemData.scale*2.5],
						[CCDelayTime actionWithDuration:0.20f],
						[CCScaleTo actionWithDuration:0.10f scale:toolboxItemData.scale],
						nil]
					];

					
					if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
						[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/toolbox/rotate.wav"];
					}
				}
				
			}else {
				if(_isNudgingPenguin) {
					_isNudgingPenguin = false;
					for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
						[[_penguinMoveGridDatas objectForKey:penguin.uniqueName] scheduleUpdateToMoveGridIn:.50f];
					}
					[_handOfGodPowerNode runAction:[CCFadeOut actionWithDuration:1.5f]];
					
					//analytics logging
					NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
						[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
						_levelPackPath, @"Level_Pack",
						[NSNumber numberWithDouble:_handOfGodPowerSecondsRemaining], @"Power_Remaining",
					nil];
					[Analytics logEvent:@"Nudged_Penguin" withParameters:flurryParams];					
					
				}
			}
		}
	}
}

- (void)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {

	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];

		_startTouch = location;
		_lastTouch = location;
		
		
		if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {

			CGPoint gridPos = [self toGrid:location];

			MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:@"Penguin"];
			const short** penguinMoveGrid = nil;
			MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:@"Shark"];
			const short** sharkMoveGrid = nil;
			if(penguinMoveGridData != nil) {
				penguinMoveGrid = (const short** )[penguinMoveGridData moveGrid];
				DebugLog(@"Penguin moveGrid at location %@ = %d", NSStringFromCGPoint(gridPos), penguinMoveGrid[(int)gridPos.x][(int)gridPos.y]);
			}
			if(sharkMoveGridData != nil) {
				sharkMoveGrid = (const short** )[sharkMoveGridData moveGrid];
				DebugLog(@"Shark moveGrid at location %@ = %d", NSStringFromCGPoint(gridPos), sharkMoveGrid[(int)gridPos.x][(int)gridPos.y]);
			}
			
		}
	}
}






-(void) drawDebugMovementGrid {

	if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {

		MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:@"Penguin"];
		const short** penguinMoveGrid = nil;
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:@"Shark"];
		const short** sharkMoveGrid = nil;
		if(penguinMoveGridData != nil) {
			penguinMoveGrid = (const short** )[penguinMoveGridData moveGrid];
		}
		if(sharkMoveGridData != nil) {
			sharkMoveGrid = (const short** )[sharkMoveGridData moveGrid];
		}
		
		ccPointSize(_gridSize-1);
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				if(__DEBUG_PENGUINS && penguinMoveGrid != nil) {
					int pv = (penguinMoveGrid[x][y]);
					ccDrawColor4B(55,55,(pv/max(penguinMoveGridData.bestFoundRouteWeight,1))*200+55,50);
					ccDrawPoint( ccp(x*_gridSize+_gridSize/2, y*_gridSize+_gridSize/2) );
				}
				if(__DEBUG_SHARKS && sharkMoveGrid != nil) {
					int sv = (sharkMoveGrid[x][y]);
					ccDrawColor4B((sv/max(sharkMoveGridData.bestFoundRouteWeight,1))*200+55,55,55,50);
					ccDrawPoint( ccp(x*_gridSize + _gridSize/2.0, y*_gridSize + _gridSize/2) );
				}
			}
		}	

/*
		NSArray* lands = [_levelLoader spritesWithTag:LAND];
		NSArray* borders = [_levelLoader spritesWithTag:BORDER];
		NSArray* obstructions = [_levelLoader spritesWithTag:OBSTRUCTION];
		NSArray* sandbars = [_levelLoader spritesWithTag:SANDBAR];

		ccColor4F landColor = ccc4f(0,.3,0,.25);
		for(LHSprite* land in lands) {
			ccDrawSolidRect(ccp(land.boundingBox.origin.x - 8*SCALING_FACTOR_H,
								land.boundingBox.origin.y - 8*SCALING_FACTOR_V),
			ccp(land.boundingBox.origin.x+land.boundingBox.size.width + 8*SCALING_FACTOR_H,
				land.boundingBox.origin.y+land.boundingBox.size.height + 8*SCALING_FACTOR_V),
			landColor);
		}
		ccColor4F borderColor = ccc4f(0,.8,.8,.25);
		for(LHSprite* border in borders) {
			ccDrawSolidRect(ccp(border.boundingBox.origin.x - 8*SCALING_FACTOR_H,
								border.boundingBox.origin.y - 8*SCALING_FACTOR_V),
							ccp(border.boundingBox.origin.x+border.boundingBox.size.width + 8*SCALING_FACTOR_H,
								border.boundingBox.origin.y+border.boundingBox.size.height + 8*SCALING_FACTOR_V),
							borderColor);
		}
		ccColor4F obstructionsColor = ccc4f(.2,.3,.3,.25);
		for(LHSprite* obstruction in obstructions) {
			ccDrawSolidRect(ccp(obstruction.boundingBox.origin.x - 8*SCALING_FACTOR_H,
								obstruction.boundingBox.origin.y - 8*SCALING_FACTOR_V),
							ccp(obstruction.boundingBox.origin.x+obstruction.boundingBox.size.width + 8*SCALING_FACTOR_H,
								obstruction.boundingBox.origin.y+obstruction.boundingBox.size.height + 8*SCALING_FACTOR_V),
							obstructionsColor);
		}
		ccColor4F sandbarColor = ccc4f(.2,.3,.3,.25);
		for(LHSprite* sandbar in sandbars) {
			ccDrawSolidRect(ccp(sandbar.boundingBox.origin.x - 8*SCALING_FACTOR_H,
								sandbar.boundingBox.origin.y - 8*SCALING_FACTOR_V),
							ccp(sandbar.boundingBox.origin.x+sandbar.boundingBox.size.width + 8*SCALING_FACTOR_H,
								sandbar.boundingBox.origin.y+sandbar.boundingBox.size.height + 8*SCALING_FACTOR_V),
							sandbarColor);
		}
*/
	}
}



-(void) draw
{
	if(DEBUG_ALL_THE_THINGS || __DEBUG_SHARKS || __DEBUG_PENGUINS) {
		//
		// IMPORTANT:
		// This is only for debug purposes
		// It is recommend to disable it
		//
		[super draw];
		
		ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
		
		kmGLPushMatrix();
		
		if(DEBUG_ALL_THE_THINGS) {
			_world->DrawDebugData();
		}
		
		[self drawDebugMovementGrid];
		
		kmGLPopMatrix();
	}else {
		[super draw];	
	}
	
}



-(void) onExit{
	if(DEBUG_MEMORY) DebugLog(@"Begin GameLayer %f onExit", _instanceId);
	if(DEBUG_MEMORY) report_memory();

	[self setStateGameOver];
		
    [super onExit];
	
	if(DEBUG_MEMORY) DebugLog(@"End GameLayer %f onExit", _instanceId);
	if(DEBUG_MEMORY) report_memory();
}

-(void) dealloc
{
	if(DEBUG_MEMORY) DebugLog(@"Begin GameLayer %f dealloc", _instanceId);
	if(DEBUG_MEMORY) report_memory();
	
	[_levelLoader removeAllPhysics];

	[_levelPath release];
	[_levelPackPath release];

	[_inGameMenuItems release];
	
	if(_activeToolboxItemRotationCrosshair != nil) {
		[_activeToolboxItemRotationCrosshair release];
	}
	
	if(_toolGroups != nil) {
		for(id key in _toolGroups) {
			NSMutableDictionary* toolGroup = [_toolGroups objectForKey:key];
			[toolGroup release];
		}
		[_toolGroups release];
	}
	
	if(_iapToolGroups != nil) {
		for(id key in _iapToolGroups) {
			NSMutableDictionary* _iapToolGroup = [_iapToolGroups objectForKey:key];
			[_iapToolGroup release];
		}
		[_iapToolGroups release];	
	}
	
	[_placedToolboxItems release];
	[_scoreKeeper release];
	
	if(_handOfGodPowerNode != nil) {
		[_handOfGodPowerNode release];
	}
	
	[_penguinsToPutOnLand release];
	for(id key in _sharkMoveGridDatas) {
		MoveGridData* moveGriData = [_sharkMoveGridDatas objectForKey:key];
		[moveGriData release];
	}
	[_sharkMoveGridDatas release];
	for(id key in _penguinMoveGridDatas) {
		MoveGridData* moveGriData = [_penguinMoveGridDatas objectForKey:key];
		[moveGriData release];
	}
	[_penguinMoveGridDatas release];
	
	[_penguinsThatNeedToUpdateFeatureGrids release];
	[_sharksThatNeedToUpdateFeatureGrids release];
		
	for(int i = 0; i < _gridWidth; i++) {
		free(_penguinMapfeaturesGrid[i]);
		free(_sharkMapfeaturesGrid[i]);
	}
	free(_penguinMapfeaturesGrid);
	free(_sharkMapfeaturesGrid);
	
	[_levelLoader release];
	_levelLoader = nil;
	
	if(DEBUG_ALL_THE_THINGS) {
		delete _debugDraw;
		_debugDraw = nil;
	}

	delete _world;
	_world = nil;
	
	[super dealloc];
	
	if(DEBUG_MEMORY) DebugLog(@"End GameLayer %f dealloc", _instanceId);
	if(DEBUG_MEMORY) report_memory();
}	

@end
