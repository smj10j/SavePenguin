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
	[Analytics logEvent:@"Play_Level" withParameters:flurryParams timed:YES];

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
	for(LHSprite* border in borders) {
		if([border.userInfoClassName isEqualToString:@"MovingBorder"]) {
		
			MovingBorder* borderData = ((MovingBorder*)border.userInfo);
		
			[border prepareMovementOnPathWithUniqueName:borderData.pathName];
			
			if(borderData.followXAxis) {
				[border setPathMovementOrientation:LH_X_AXIT_ORIENTATION];
			}else {
				[border setPathMovementOrientation:LH_Y_AXIS_ORIENTATION];
			}
			[border setPathMovementRestartsAtOtherEnd:borderData.restartAtOtherEnd];
			[border setPathMovementIsCyclic:borderData.isCyclic];
			[border setPathMovementSpeed:borderData.timeToCompletePath]; //moving from start to end in X seconds
			
			[border startPathMovement];
			
			_levelHasMovingBorders = true;
		}
	}
	
	if(_levelHasMovingBorders) {
		[self schedule:@selector(invalidateFeatureGridsNearMovingBorders) interval:0.4f];
	}
}

-(void) updateToolbox {
	if(DEBUG_TOOLBOX) DebugLog(@"Updating Toolbox");
	
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
	
	//get all the tools put on the level - they can be anywhere!
	_toolGroups = [[NSMutableDictionary alloc] init];
	for(LHSprite* toolboxItem in toolboxItems) {
	
		[toolboxItem stopAllActions];
	
		//generate the grouping key for toolbox items
		NSString* toolgroupKey = toolboxItem.userInfoClassName;
		if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Windmill"]) {
			ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)toolboxItem.userInfo);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Power", toolboxItemData.power]];
		}else if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)toolboxItem.userInfo);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Mass", toolboxItemData.mass]];
		}else if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
			ToolboxItem_Whirlpool* toolboxItemData = ((ToolboxItem_Whirlpool*)toolboxItem.userInfo);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Power", toolboxItemData.power]];
		}
	
		NSMutableSet* toolGroup = [_toolGroups objectForKey:toolgroupKey];
		if(toolGroup == nil) {
			toolGroup = [[NSMutableSet alloc] init];
			[_toolGroups setObject:toolGroup forKey:toolgroupKey];
		}
		[toolGroup addObject:toolboxItem];
	}
	
	
	int toolGroupX = winSize.width/2 - ((_toolboxItemSize.width + TOOLBOX_MARGIN_LEFT)*((_toolGroups.count-1.0)/2.0));
	int toolGroupY = _toolboxItemSize.height/2 + TOOLBOX_MARGIN_BOTTOM;
		
	for(id key in _toolGroups) {

		NSMutableSet* toolGroup = [_toolGroups objectForKey:key];

		//draw a box to hold it
		LHSprite* toolboxContainer = [_levelLoader createSpriteWithName:@"Toolbox-Item-Container" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
		toolboxContainer.zOrder = _actorsBatchNode.zOrder+1;
		toolboxContainer.tag = TOOLBOX_ITEM_CONTAINER;
		[toolboxContainer transformPosition: ccp(toolGroupX, toolGroupY)];

		LHSprite* toolboxContainerCountContainer = [_levelLoader createSpriteWithName:@"Toolbox-Item-Container-Count" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:toolboxContainer];
		[toolboxContainerCountContainer transformPosition: ccp(toolboxContainer.boundingBox.size.width, toolboxContainer.boundingBox.size.height)];

		//display # of items in the stack
		CCLabelTTF* numToolsLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", toolGroup.count] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE];
		numToolsLabel.color = ccWHITE;
		numToolsLabel.position = ccp(toolboxContainerCountContainer.boundingBox.size.width/2, toolboxContainerCountContainer.boundingBox.size.height/2);
		[toolboxContainerCountContainer addChild:numToolsLabel];

		LHSprite* topToolboxItem = nil;
		for(LHSprite* toolboxItem in toolGroup) {
			if(topToolboxItem == nil) topToolboxItem = toolboxItem;
			//move the tool into the box
			if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
				//set previously in level load
				
			}else {
				[toolboxItem transformRotation:0];
			}			
			[toolboxItem transformPosition: ccp(toolGroupX, toolGroupY)];
			double scale = fmin((_toolboxItemSize.width-TOOLBOX_ITEM_CONTAINER_PADDING_H)/toolboxItem.contentSize.width, (_toolboxItemSize.height-TOOLBOX_ITEM_CONTAINER_PADDING_V)/toolboxItem.contentSize.height);
			[toolboxItem transformScale: scale];
			//DebugLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", toolboxItem.uniqueName, (int)(100*scale));
		}
		
		//helpful tidbits
		if([topToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Windmill"]) {
			//display item power
			ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)topToolboxItem.userInfo);
			CCLabelTTF* powerLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"+%d%%", (int)toolboxItemData.power] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_STATS_FONT_SIZE];
			powerLabel.color = ccWHITE;
			powerLabel.position = ccp(toolboxContainer.boundingBox.size.width - 30*SCALING_FACTOR_H, 15*SCALING_FACTOR_V);
			[toolboxContainer addChild:powerLabel];
		}else if([topToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			//display item mass
			ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)topToolboxItem.userInfo);
			CCLabelTTF* powerLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%dlbs", (int)(toolboxItemData.mass*100)] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_STATS_FONT_SIZE];
			powerLabel.color = ccWHITE;
			powerLabel.position = ccp(toolboxContainer.boundingBox.size.width - 30*SCALING_FACTOR_H, 15*SCALING_FACTOR_V);
			[toolboxContainer addChild:powerLabel];
		}

		
		[toolboxContainer setUserData:(void*)topToolboxItem.uniqueName];
		[toolboxContainer registerTouchBeganObserver:self selector:@selector(onTouchBeganToolboxItem:)];
		[toolboxContainer registerTouchEndedObserver:self selector:@selector(onTouchEndedToolboxItem:)];

				
		toolGroupX+= _toolboxItemSize.width + TOOLBOX_MARGIN_LEFT;
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
		
		if([sprite.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			b2MassData massData;
			ToolboxItem_Debris* toolboxItemData = (ToolboxItem_Debris*)sprite.userInfo;
			sprite.body->GetMassData(&massData);
			massData.mass*= toolboxItemData.mass;
			sprite.body->SetMassData(&massData);
		}else if([sprite.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
			//sets those in the toolbox too
			[sprite makeDynamic];
			[sprite setSensor:true];
			sprite.body->SetAngularVelocity(0);
		}
		
		if(sprite.tag == DEBRIS) {
			//already placed - set it's physics data
			[sprite makeDynamic];
			[sprite setSensor:false];
			
			ToolboxItem_Debris* toolboxItemData = (ToolboxItem_Debris*)sprite.userInfo;
			[sprite setScale:toolboxItemData.scale];
			
		}else if(sprite.tag == OBSTRUCTION) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
		}else if(sprite.tag == WINDMILL) {
			//already placed - set it's physics data
			[sprite makeStatic];
			[sprite setSensor:true];
			
			ToolboxItem_Windmill* toolboxItemData = (ToolboxItem_Windmill*)sprite.userInfo;
			[sprite setScale:toolboxItemData.scale];
			
		}else if(sprite.tag == WHIRLPOOL) {
		
			//already placed - set it's physics data
			sprite.body->ApplyTorque(sprite.rotation < 180 ? -15 : 15);
			sprite.flipX = sprite.rotation > 180;
			
			ToolboxItem_Whirlpool* toolboxItemData = (ToolboxItem_Whirlpool*)sprite.userInfo;
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
	
	//double startTime = [[NSDate date] timeIntervalSince1970];

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
					
		int minX = max(land.boundingBox.origin.x, 0);
		int maxX = min(land.boundingBox.origin.x+land.boundingBox.size.width, _levelSize.width-1);
		int minY = max(land.boundingBox.origin.y, 0);
		int maxY = min(land.boundingBox.origin.y+land.boundingBox.size.height, _levelSize.height-1);
		
		//create the areas that both sharks and penguins can't go
		
		//full fill
		for(int x = minX; x < maxX; x++) {
			for(int y = minY; y < maxY; y++) {
				_sharkMapfeaturesGrid[(int)(x/_gridSize)][(int)(y/_gridSize)] = HARD_BORDER_WEIGHT;
				if(land.tag == BORDER || land.tag == OBSTRUCTION) {
					//penguins can pass through SANDBAR and want to target LAND
					_penguinMapfeaturesGrid[(int)(x/_gridSize)][(int)(y/_gridSize)] = HARD_BORDER_WEIGHT;
				}
			}
		}

		//DebugLog(@"Land from %d,%d to %d,%d computed in %f", minX, minY, maxX, maxY,  ([[NSDate date] timeIntervalSince1970] - startTime));
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
	
	//create a set of maps for each penguin
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	for(LHSprite* penguin in penguins) {
	
		if(_state == SETUP) {
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
	}
	
	//create a set of maps for each shark
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	for(LHSprite* shark in sharks) {

		if(_state == SETUP) {
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
	
	[self scheduleOnce:@selector(initializeSelectedActiveToolboxItem) delay:0.100];
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
	ToolboxItem_Obstruction* toolboxItemData = ((ToolboxItem_Obstruction*)_activeToolboxItem.userInfo);	//ToolboxItem_Obstruction is used because all ToolboxItem classes have a "scale" property
	[_activeToolboxItem transformScale: toolboxItemData.scale];
	if(DEBUG_TOOLBOX) DebugLog(@"Scaling up toolboxitem %@ to full-size", _activeToolboxItem.uniqueName);
	
	if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
		//set previously in level load
		double angularVelocity = _activeToolboxItem.body->GetAngularVelocity();
		if(angularVelocity == 0) {
			_activeToolboxItem.body->ApplyTorque(-15);
			_activeToolboxItem.flipX = false;
		}
	}
	
	
	//slide down the toolbox items
	for(LHSprite* aToolboxItemContainer in [_levelLoader spritesWithTag:TOOLBOX_ITEM_CONTAINER]) {
		[aToolboxItemContainer runAction:[CCMoveTo actionWithDuration:0.20f position:ccp(aToolboxItemContainer.position.x, -aToolboxItemContainer.boundingBox.size.height)]];
	}
	for(LHSprite* aToolboxItem in [_levelLoader spritesWithTag:TOOLBOX_ITEM]) {
		if(aToolboxItem == _activeToolboxItem) {
			continue;
		}
		[aToolboxItem runAction:[CCMoveTo actionWithDuration:0.20f position:ccp(aToolboxItem.position.x, -aToolboxItem.boundingBox.size.height)]];
	}
}


-(void)onTouchBeganToolboxItem:(LHTouchInfo*)info {

	//[[LHTouchMgr sharedInstance] setPriority:1 forTouchesOfTag:OBSTRUCTION];

	if(DEBUG_TOOLBOX) DebugLog(@"Touch began on toolboxItem %@", info.sprite.uniqueName);

	if(_state != RUNNING && _state != PLACE) {
		return;
	}

	LHSprite* toolboxItemContainer = info.sprite;
	LHSprite* toolboxItem = toolboxItemContainer.tag == TOOLBOX_ITEM_CONTAINER ? [_levelLoader spriteWithUniqueName:((NSString*)toolboxItemContainer.userData)] : toolboxItemContainer;

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

			if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
				_activeToolboxItem.body->SetAngularVelocity(0);
				_activeToolboxItem.body->ApplyTorque(-15);
				_activeToolboxItem.flipX = false;
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
				_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
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
		
		//analytics logging
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSString stringWithFormat:@"%@:%@", _levelPackPath, _levelPath], @"Level_Pack_and_Name",
			_levelPackPath, @"Level_Pack",
		nil];
		[Analytics logEvent:@"Start_level" withParameters:flurryParams];

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
		
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Won", @"Level_Status",
	nil];
	[Analytics endTimedEvent:@"Play_Level" withParameters:flurryParams];
	
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
		
		
		CCLabelTTF* highScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", highScoresLabelText] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE3 dimensions:CGSizeMake(200*SCALING_FACTOR_H,150*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentCenter vAlignment:kCCVerticalTextAlignmentCenter lineBreakMode:kCCLineBreakModeWordWrap];
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
	[Analytics endTimedEvent:@"Play_Level" withParameters:flurryParams];

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
	[Analytics endTimedEvent:@"Play_Level" withParameters:flurryParams];

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

-(void)scoreToolboxItemPlacement:(LHSprite*)toolboxItem replaced:(bool)replaced {

	//accounting
	ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)toolboxItem.userInfo);
	int score = _state == PLACE ? (toolboxItemData.placeCost * (replaced ? 0 : 1)) :
								  (toolboxItemData.runningCost * (replaced ? 0.25 : 1));
				
	if(score == 0) {
		return;
	}
	
	//adjust score by the mass/power/etc.
	if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
		ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)toolboxItem.userInfo);
		score*= 1+log(toolboxItemData.mass/1);
	}else if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Windmill"]) {
		ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)toolboxItem.userInfo);
		score*= 1+log(toolboxItemData.power/50);
	}else if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
		ToolboxItem_Whirlpool* toolboxItemData = ((ToolboxItem_Whirlpool*)toolboxItem.userInfo);
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


-(void) update: (ccTime) dt
{
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Update tick");
	if(_state != RUNNING && _state != PLACE) {
		return;
	}

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
	
		if(DEBUG_TOOLBOX) DebugLog(@"Adding toolbox item %@ to world", _activeToolboxItem.userInfoClassName);
		
		NSString* soundFileName = @"place.wav";
	
		//StaticToolboxItem are things penguins and sharks can't move through
		if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			_activeToolboxItem.tag = DEBRIS;
			[_activeToolboxItem makeDynamic];
			[_activeToolboxItem setSensor:false];
			soundFileName = @"place-debris.wav";
			
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Obstruction"]) {
			_activeToolboxItem.tag = OBSTRUCTION;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			[self invalidateFeatureGridsNear:nil];
			[self invalidateMoveGridsNear:_activeToolboxItem];
			soundFileName = @"place-obstruction.wav";

		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Windmill"]) {
			_activeToolboxItem.tag = WINDMILL;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-windmill.wav";
		
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
			_activeToolboxItem.tag = WHIRLPOOL;
			[_activeToolboxItem makeDynamic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-whirlpool.wav";
		
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Sandbar"]) {
			_activeToolboxItem.tag = SANDBAR;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			[self invalidateSharkFeatureGridsNear:nil];
			[self invalidateSharkMoveGridsNear:_activeToolboxItem];
			soundFileName = @"place-sandbar.wav";
		
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Bag_of_Fish"]) {
			_activeToolboxItem.tag = BAG_OF_FISH;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-bag-of-fish.wav";
		
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Invisibility_Hat"]) {
			_activeToolboxItem.tag = INVISIBILITY_HAT;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-invisibility-hat.wav";
		
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Loud_Noise"]) {
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
				_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
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
				_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
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
	
	//spin the whirlpools at a constant rate
	for(LHSprite* whirlpool in [_levelLoader spritesWithTag:WHIRLPOOL]) {
		ToolboxItem_Whirlpool* whirlpoolData = (ToolboxItem_Whirlpool*)whirlpool.userInfo;
		double angVel = whirlpool.body->GetAngularVelocity();
		double targetAngVel = whirlpoolData.power/100;
		if(fabs(angVel) != targetAngVel) {
			whirlpool.body->ApplyAngularImpulse(.1*(angVel < 0 ? (-targetAngVel-angVel) : (targetAngVel-angVel)));
		}
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
	
	
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Done with game state update");

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
	
	if(DEBUG_ALL_THE_THINGS) DebugLog(@"Done with update tick");
}

-(void)invalidateFeatureGridsNearMovingBorders {
	NSArray* borders = [_levelLoader spritesWithTag:BORDER];
	for(LHSprite* border in borders) {
		if([border.userInfoClassName isEqualToString:@"MovingBorder"]) {
			[self invalidateFeatureGridsNear:border];
		}
	}
}

-(void) invalidateFeatureGridsNear:(LHSprite*)sprite {
	[self invalidatePenguinFeatureGridsNear:sprite];
	[self invalidateSharkFeatureGridsNear:sprite];
}

-(void) invalidateSharkFeatureGridsNear:(LHSprite*)sprite {
	if(_isInvalidatingSharkFeatureGrids) {
		return;
	}
	_isInvalidatingSharkFeatureGrids = true;
	
	NSMutableArray* sharksToUpdate = [[NSMutableArray alloc] init];
	for(LHSprite* shark in [_levelLoader spritesWithTag:SHARK]) {
		if(sprite == nil || ccpDistance(sprite.position, shark.position) < 150*SCALING_FACTOR_GENERIC) {
			[sharksToUpdate addObject:shark];
		}
	}
	if(sharksToUpdate.count > 0) {
		[self generateFeatureGrids];
		for(LHSprite* shark in sharksToUpdate) {
			[self updateFeatureMapForShark:shark];
		}
	}
	[sharksToUpdate release];
	_isInvalidatingSharkFeatureGrids = false;
}

-(void) invalidatePenguinFeatureGridsNear:(LHSprite*)sprite {
	if(_isInvalidatingPenguinFeatureGrids) {
		return;
	}
	_isInvalidatingPenguinFeatureGrids = true;
	
	NSMutableArray* penguinsToUpdate = [[NSMutableArray alloc] init];
	for(LHSprite* penguin in [_levelLoader spritesWithTag:PENGUIN]) {
		if(sprite == nil || ccpDistance(sprite.position, penguin.position) < 150*SCALING_FACTOR_GENERIC) {
			[penguinsToUpdate addObject:penguin];
		}
	}
	if(penguinsToUpdate.count > 0) {
		[self generateFeatureGrids];
		for(LHSprite* penguin in penguinsToUpdate) {
			[self updateFeatureMapForPenguin:penguin];
		}
	}
	[penguinsToUpdate release];
	_isInvalidatingPenguinFeatureGrids = false;
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
		ToolboxItem_Windmill* windmillData = ((ToolboxItem_Windmill*)windmill.userInfo);
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
		ToolboxItem_Whirlpool* whirlpoolData = ((ToolboxItem_Whirlpool*)whirlpool.userInfo);
		
			double dist = ccpDistance(sprite.position, whirlpool.position);
			if(dist < whirlpoolData.power*SCALING_FACTOR_GENERIC) {
				
				b2Vec2 vortexVelocity = whirlpool.body->GetLinearVelocityFromWorldPoint( sprite.body->GetPosition() );
				b2Vec2 vortexVelocityN = vortexVelocity;
				vortexVelocityN.Normalize();
				
				//this will provide a slight pull to the center
				b2Vec2 d = whirlpool.body->GetPosition() - sprite.body->GetPosition();
				b2Vec2 dN = d;
				dN.Normalize();
				
				double power = (pow(log(whirlpoolData.power - dist),2));
				dxMod = vortexVelocity.x*power + dN.x*(whirlpoolData.power - dist)*.125;
				dyMod = vortexVelocity.y*power + dN.y*(whirlpoolData.power - dist)*.125;
				
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
				if(dist < minDist) {
					minDist = dist;
					touchedBoder = border;
				}
			}
			
			if(touchedBoder != nil) {
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
					[shark transformPosition:ccp(shark.position.x, (shark.position.y+borderN.y)/2)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the north of a border he is in contact with", shark.uniqueName);
				}else if(distS == absMin) {
					[shark transformPosition:ccp(shark.position.x, (shark.position.y+borderS.y)/2)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the south of a border he is in contact with", shark.uniqueName);
				}else if(distE == absMin) {
					[shark transformPosition:ccp((shark.position.x+borderE.x)/2, shark.position.y)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the east of a border he is in contact with", shark.uniqueName);
				}else if(distW == absMin) {
					[shark transformPosition:ccp((shark.position.x+borderW.x)/2, shark.position.y)];
					if(DEBUG_MOVEGRID) DebugLog(@"Moving shark %@ to the west of a border he is in contact with", shark.uniqueName);
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
			sharkData.isStuck = true;

		}else {
			//normal
			[shark setFrame:0];
			sharkData.isStuck = false;
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
					if(dist < minDist) {
						minDist = dist;
						touchedBoder = border;
					}
				}
				
				if(touchedBoder != nil) {
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
						[penguin transformPosition:ccp(penguin.position.x, (penguin.position.y+borderN.y)/2)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the north of a border he is in contact with", penguin.uniqueName);
					}else if(distS == absMin) {
						[penguin transformPosition:ccp(penguin.position.x, (penguin.position.y+borderS.y)/2)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the south of a border he is in contact with", penguin.uniqueName);
					}else if(distE == absMin) {
						[penguin transformPosition:ccp((penguin.position.x+borderE.x)/2, penguin.position.y)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the east of a border he is in contact with", penguin.uniqueName);
					}else if(distW == absMin) {
						[penguin transformPosition:ccp((penguin.position.x+borderW.x)/2, penguin.position.y)];
						if(DEBUG_MOVEGRID) DebugLog(@"Moving penguin %@ to the west of a border he is in contact with", penguin.uniqueName);
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
				penguinData.isStuck = false;			
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
					
					if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Whirlpool"]) {
						double angularVelocity = _activeToolboxItem.body->GetAngularVelocity();
						_activeToolboxItem.body->SetAngularVelocity(0);
						_activeToolboxItem.body->ApplyTorque(angularVelocity>0 ? -15 : 15);
						_activeToolboxItem.flipX = angularVelocity>0;
					}else {
						[_activeToolboxItem transformRotation:((int)_activeToolboxItem.rotation+90)%360];
					}
					
					//scale up and down for visual effect
					ToolboxItem_Obstruction* toolboxItemData = ((ToolboxItem_Obstruction*)_activeToolboxItem.userInfo);	//ToolboxItem_Obstruction is used because all ToolboxItem classes have a "scale" property
					
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
					ccDrawColor4B(55,55,(pv/penguinMoveGridData.bestFoundRouteWeight)*200+55,50);
					ccDrawPoint( ccp(x*_gridSize+_gridSize/2, y*_gridSize+_gridSize/2) );
				}
				if(__DEBUG_SHARKS && sharkMoveGrid != nil) {
					int sv = (sharkMoveGrid[x][y]);
					ccDrawColor4B((sv/sharkMoveGridData.bestFoundRouteWeight)*200+55,55,55,50);
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
	
	for(id key in _toolGroups) {
		NSMutableDictionary* toolGroup = [_toolGroups objectForKey:key];
		[toolGroup release];
	}
	[_toolGroups release];
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
