//
//  GameLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//

// Import the interfaces
#import "GameLayer.h"

#import "Flurry.h"

// Not included in "cocos2d.h"
#import "CCPhysicsSprite.h"

// Needed to obtain the Navigation Controller
#import "AppDelegate.h"

#import "LevelSelectLayer.h"
#import "LevelPackSelectLayer.h"
#import "MainMenuLayer.h"
#import "MoveGridData.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"

#import "WindmillRaycastCallback.h"

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
		
		_instanceId = [[NSDate date] timeIntervalSince1970];
		NSLog(@"Initializing GameLayer %f", _instanceId);
		_inGameMenuItems = [[NSMutableArray alloc] init];
		_moveGridSharkUpdateQueue = dispatch_queue_create("com.conquerllc.games.Penguin-Rescue.moveGridSharkUpdateQueue", 0);	//serial
		_moveGridPenguinUpdateQueue = dispatch_queue_create("com.conquerllc.games.Penguin-Rescue.moveGridPenguinUpdateQueue", 0);	//serial
		//_moveGridSharkUpdateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);	//concurrent
		//_moveGridPenguinUpdateQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);	//concurrent
		_isUpdatingSharkMoveGrids = false;
		_isUpdatingPenguinMoveGrids = false;
		_shouldRegenerateFeatureMaps = false;
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = false;
		_penguinsToPutOnLand =[[NSMutableDictionary alloc] init];
		_placedToolboxItems = [[NSMutableArray alloc] init];
		_scoreKeeper = [[ScoreKeeper alloc] init];
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

		if(DEBUG_MEMORY) NSLog(@"GameLayer %f initialized", _instanceId);
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

	//start the game
	_state = PLACE;
	_levelStartPlaceTime  = [[NSDate date] timeIntervalSince1970];
	_levelPlaceTimeDuration = 0;
	_levelRunningTimeDuration = 0;

	CCDirectorIOS* director = (CCDirectorIOS*) [CCDirector sharedDirector];
	[director setAnimationInterval:1.0/TARGET_FPS];
	[self scheduleUpdate];
	

	
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		_levelPath, @"Level_Name",
		_levelPackPath, @"Level_Pack",
	nil];

	[Flurry logEvent:@"Play_Level" withParameters:flurryParams timed:YES];

	if(DEBUG_MEMORY) NSLog(@"GameLayer %f level loaded", _instanceId);
	if(DEBUG_MEMORY) report_memory();

}

-(void) preloadSounds {

	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/button.wav"];
	
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/pickup.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/return.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/rotate.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-border.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-debris.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/toolbox/place-windmill.wav"];

	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/levelLost/hoot.wav"];
	[[SimpleAudioEngine sharedEngine] preloadEffect:@"sounds/game/levelWon/reward.mp3"];

}

-(void) initPhysics
{
	NSLog(@"Initializing physics...");
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
			NSLog(@"Using a grid size for an older iPhone");
		}else {
			//high-res 4+
			_gridSize = 8;
			NSLog(@"Using a grid size for a newer iPhone");
		}
	}else {
		//iPad
		if(winSizeInPixels.width == 1024) {
			//low-res - probably a slower processor
			_gridSize = 20;
			NSLog(@"Using a grid size for an older iPad");
		}else {
			//high-res 4+
			_gridSize = 12;
			NSLog(@"Using a grid size for a newer iPad");
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
		NSLog(@"Scaling down gridSize by %f to %d to account for scaled down actors", minScale, _gridSize);
	}

		
	_gridWidth = ceil(_levelSize.width/_gridSize);
	_gridHeight = ceil(_levelSize.height/_gridSize);

	NSLog(@"Setting up grid with size=%d, width=%d, height=%d", _gridSize, _gridWidth, _gridHeight);

	_sharkMapfeaturesGrid = new int*[_gridWidth];
	_penguinMapfeaturesGrid = new int*[_gridWidth];
	for(int i = 0; i < _gridWidth; i++) {
		_sharkMapfeaturesGrid[i] = new int[_gridHeight];
		_penguinMapfeaturesGrid[i] = new int[_gridHeight];
		for(int j = 0; j < _gridHeight; j++) {
			_sharkMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
			_penguinMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
		}
	}
	
	//filled in generateFeatureMaps
	_sharkMoveGridDatas = [[NSMutableDictionary alloc] init];
	_penguinMoveGridDatas = [[NSMutableDictionary alloc] init];
	
	[self generateFeatureMaps];
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
	NSLog(@"Drawing HUD");

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
		[CCMoveBy actionWithDuration:0.5f position:ccp(0,timeAndLevelPopup.boundingBox.size.height/2 + 2*SCALING_FACTOR_V)],
		nil]];	
}

//TODO: random crash still occasionally occurs after prolonged use - remember to look into it!

-(void) updateToolbox {
	NSLog(@"Updating Toolbox");
	
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
	
		//generate the grouping key for toolbox items
		NSString* toolgroupKey = toolboxItem.userInfoClassName;
		if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Windmill"]) {
			ToolboxItem_Windmill* toolboxItemData = ((ToolboxItem_Windmill*)toolboxItem.userInfo);
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Power", toolboxItemData.power]];
		}else if([toolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			toolgroupKey = [toolgroupKey stringByAppendingString:[NSString stringWithFormat:@"-%@:%f", @"Density", toolboxItem.body->GetFixtureList()->GetDensity()]];
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
			[toolboxItem transformPosition: ccp(toolGroupX, toolGroupY)];
			double scale = fmin((_toolboxItemSize.width-TOOLBOX_ITEM_CONTAINER_PADDING_H)/toolboxItem.contentSize.width, (_toolboxItemSize.height-TOOLBOX_ITEM_CONTAINER_PADDING_V)/toolboxItem.contentSize.height);
			[toolboxItem transformScale: scale];
			//NSLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", toolboxItem.uniqueName, (int)(100*scale));
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
			//display item density
			CCLabelTTF* powerLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%dlbs", (int)(topToolboxItem.body->GetFixtureList()->GetDensity()*100)] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_STATS_FONT_SIZE];
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
	NSLog(@"Level size: %f x %f", _levelSize.width, _levelSize.height);

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
		
	[self showTutorial];
}


-(void) generateFeatureMaps {

	//TODO: consider if we should "unStuck" all penguins/sharks whenever we regenerate the feature map

	NSLog(@"Generating feature maps...");

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
	
	NSMutableArray* unpassableAreas = [NSMutableArray arrayWithArray:lands];
	[unpassableAreas addObjectsFromArray:borders];
	
	NSLog(@"Num safe lands: %d, Num borders: %d", [lands count], [borders count]);
	
	for(LHSprite* land in unpassableAreas) {
					
		int minX = max(land.boundingBox.origin.x, 0);
		int maxX = min(land.boundingBox.origin.x+land.boundingBox.size.width, _levelSize.width-1);
		int minY = max(land.boundingBox.origin.y, 0);
		int maxY = min(land.boundingBox.origin.y+land.boundingBox.size.height, _levelSize.height-1);
		
		//create the areas that both sharks and penguins can't go
		for(int x = minX; x < maxX; x++) {
			for(int y = minY; y < maxY; y++) {
				_sharkMapfeaturesGrid[(int)(x/_gridSize)][(int)(y/_gridSize)] = HARD_BORDER_WEIGHT;
				if(land.tag == BORDER) {
					_penguinMapfeaturesGrid[(int)(x/_gridSize)][(int)(y/_gridSize)] = HARD_BORDER_WEIGHT;
				}
			}
		}
			

		//NSLog(@"Land from %d,%d to %d,%d", minX, minY, maxX, maxY);
	}


	//create a set of maps for each penguin
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	for(LHSprite* penguin in penguins) {

		//first create a copy of the feature map
		int** penguinMoveGrid = new int*[_gridWidth];
		int rowSize = _gridHeight * sizeof(int);
		for(int x = 0; x < _gridWidth; x++) {
			penguinMoveGrid[x] = new int[_gridHeight];
			memcpy(penguinMoveGrid[x], (void*)_penguinMapfeaturesGrid[x], rowSize);
		}
		
		//and add it to the map
		MoveGridData* moveGridData = [_penguinMoveGridDatas objectForKey:penguin.uniqueName];
		if(moveGridData == nil) {
			moveGridData = [[MoveGridData alloc] initWithGrid: penguinMoveGrid height:_gridHeight width:_gridWidth moveHistorySize:PENGUIN_MOVE_HISTORY_SIZE tag:@"PENGUIN"];
			[_penguinMoveGridDatas setObject:moveGridData forKey:penguin.uniqueName];
		}else {
			[moveGridData updateBaseGrid:penguinMoveGrid];
		}
		
	}
	
	//create a set of maps for each shark
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	for(LHSprite* shark in sharks) {
		
		//first create a copy of the feature map
		int** sharkMoveGrid = new int*[_gridWidth];
		int rowSize = _gridHeight * sizeof(int);
		for(int x = 0; x < _gridWidth; x++) {
			sharkMoveGrid[x] = new int[_gridHeight];
			memcpy(sharkMoveGrid[x], (void*)_sharkMapfeaturesGrid[x], rowSize);
		}
		
		//and add it to the map
		MoveGridData* moveGridData = [_sharkMoveGridDatas objectForKey:shark.uniqueName];
		if(moveGridData == nil) {
			moveGridData = [[MoveGridData alloc] initWithGrid: sharkMoveGrid height:_gridHeight width:_gridWidth moveHistorySize:SHARK_MOVE_HISTORY_SIZE tag:@"SHARK"];
			[_sharkMoveGridDatas setObject:moveGridData forKey:shark.uniqueName];
		}else {
			[moveGridData updateBaseGrid:sharkMoveGrid];
		}
	}
	
	NSLog(@"Done generating feature maps");
	
	//force a move grid update early
	[self updateMoveGrids:true];
}





-(void)onTouchBeganToolboxItem:(LHTouchInfo*)info {

	if(_state != RUNNING && _state != PLACE) {
		return;
	}

	if(_activeToolboxItem != nil) {
		//only handle one touch at a time
		return;
	}

	LHSprite* toolboxItemContainer = info.sprite;
	LHSprite* toolboxItem = [_levelLoader spriteWithUniqueName:((NSString*)toolboxItemContainer.userData)];
	
	if(toolboxItem.tag != TOOLBOX_ITEM) {
		//already placed
		return;
	}
	
	//hide any tutorials
	[self fadeOutAllTutorials];
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/toolbox/pickup.wav"];
	}

	_activeToolboxItem = toolboxItem;
			
	_activeToolboxItemOriginalPosition = _activeToolboxItem.position;
	ToolboxItem_Border* toolboxItemData = ((ToolboxItem_Border*)_activeToolboxItem.userInfo);	//ToolboxItem_Border is used because all ToolboxItem classes have a "scale" property
	[_activeToolboxItem transformScale: toolboxItemData.scale];
	NSLog(@"Scaling up toolboxitem %@ to full-size", _activeToolboxItem.uniqueName);
}

-(void)onTouchEndedToolboxItem:(LHTouchInfo*)info {
	
	if(_activeToolboxItem != nil) {
			
		if((_state != RUNNING && _state != PLACE)
				|| (info.glPoint.y < _toolboxItemSize.height)
				|| (info.glPoint.y >= _levelSize.height)
				|| (info.glPoint.x <= 0)
				|| (info.glPoint.x >= _levelSize.width)
			) {
			//placed back into the HUD

			[_activeToolboxItem transformRotation:0];
			[_activeToolboxItem transformPosition:_activeToolboxItemOriginalPosition];
			double scale = fmin((_toolboxItemSize.width-TOOLBOX_ITEM_CONTAINER_PADDING_H)/_activeToolboxItem.contentSize.width, (_toolboxItemSize.height-TOOLBOX_ITEM_CONTAINER_PADDING_V)/_activeToolboxItem.contentSize.height);
			[_activeToolboxItem transformScale: scale];
			//NSLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", _activeToolboxItem.uniqueName, (int)(100*scale));
			NSLog(@"Placing toolbox item back into the HUD");
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelPath, @"Level_Name", 
				_levelPackPath, @"Level_Pack",
				_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
				_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
			nil];
			[Flurry logEvent:@"Undo_Place_Toolbox_Item" withParameters:flurryParams];		
			
			_activeToolboxItem = nil;
			
			if([SettingsManager boolForKey:@"SoundEnabled"]) {
				[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/toolbox/return.wav"];
			}
			
		}else {
			_moveActiveToolboxItemIntoWorld = true;
		}
	}
}












-(void)onTouchBeganPlayPause:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
		
	__DEBUG_TOUCH_SECONDS = [[NSDate date] timeIntervalSince1970];
}

-(void)onTouchEndedPlayPause:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
		
	//NSLog(@"Touch ended play/pause on GameLayer instance %f with _state=%d", _instanceId, _state);
	
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
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//NSLog(@"Touch began restart on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedRestart:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	[self restart];
}

-(void)onTouchBeganMainMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;	
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//NSLog(@"Touch began mainmenu on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedMainMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	[self showMainMenuLayer];
}

-(void)onTouchBeganLevelsMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//NSLog(@"Touch began levels menu on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedLevelsMenu:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	//NSLog(@"Touch ended levels menu on GameLayer instance %f with _state=%d", _instanceId, _state);
	
	[self showLevelsMenuLayer];
}

-(void)onTouchBeganNextLevel:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	//NSLog(@"Touch began next level on GameLayer instance %f with _state=%d", _instanceId, _state);
}

-(void)onTouchEndedNextLevel:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/button.wav"];
	}
	
	[self goToNextLevel];
}

-(void)onTouchBeganTutorial:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	NSLog(@"Touch began tutorial on GameLayer instance %f with _state=%d", _instanceId, _state);
	[self fadeOutAllTutorials];
}





-(void) pause {
	if(_state == RUNNING) {
		NSLog(@"Pausing game");
		_state = PAUSE;
		
		for(LHSprite* sprite in _levelLoader.allSprites) {
			[sprite pauseAnimation];
		}
		
		//analytics logging
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelPath, @"Level_Name", 
			_levelPackPath, @"Level_Pack",
		nil];
		[Flurry logEvent:@"Pause_level" withParameters:flurryParams];		
	}
	[self showInGameMenu];
}

-(void) showInGameMenu {
	NSLog(@"Showing in-game menu");

	[_playPauseButton runAction:[CCFadeTo actionWithDuration:0.5f opacity:150.0f]];
		
	double angle = 165;
		
	for(LHSprite* menuItem in _inGameMenuItems) {
	
		[menuItem setAnchorPoint:ccp(3.0,3.0)];
		[menuItem runAction:[CCFadeIn actionWithDuration:0.15f]];
		[menuItem runAction:[CCRotateBy actionWithDuration:0.25f angle:angle]];
		
		angle+= 30;
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
		NSLog(@"Resuming game");
		_state = RUNNING;
		
		for(LHSprite* sprite in _levelLoader.allSprites) {
			if(sprite.numberOfFrames > 1) {
				[sprite playAnimation];
			}
		}
		
		//analytics loggin
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelPath, @"Level_Name", 
			_levelPackPath, @"Level_Pack",
		nil];
		[Flurry logEvent:@"Resume_level" withParameters:flurryParams];		

		[self hideInGameMenu];
			
	}else if(_state == PLACE) {
		NSLog(@"Running game");
		_state = RUNNING;
		_levelStartRunningTime  = [[NSDate date] timeIntervalSince1970];

		[self fadeOutAllTutorials];
		
		for(LHSprite* sprite in _levelLoader.allSprites) {
			if(sprite.numberOfFrames > 1) {
				[sprite playAnimation];
			}
		}
		
		//analytics logging
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelPath, @"Level_Name", 
			_levelPackPath, @"Level_Pack",
		nil];
		[Flurry logEvent:@"Start_level" withParameters:flurryParams];

	}
	
}


//TODO: should all penguins need to make it to safety OR just have all sharks gone or all penguins safe
-(void) levelWon {

	if(_state == GAME_OVER) {
		return;
	}
	_state = GAME_OVER;
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/levelWon/reward.mp3"];
	}
	
	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}
	
	//store the level as being completed
	[LevelPackManager completeLevel:_levelPath inPack:_levelPackPath];
	
	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Won", @"Level_Status",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];
	
	NSLog(@"Showing level won animations");
	
	
	//TODO: show some happy penguins and sad sharks
	
	
	
	int scoreDeductions = 0;
	
	const int toolsScoreDeduction = _scoreKeeper.totalScore;
	scoreDeductions+= toolsScoreDeduction;
	
	const double placeTimeScore = _levelPlaceTimeDuration * SCORING_PLACE_SECOND_COST;
	const double runningTimeScore = _levelRunningTimeDuration * SCORING_RUNNING_SECOND_COST;
	const int timeScoreDeduction = placeTimeScore + runningTimeScore;
	scoreDeductions+= timeScoreDeduction;
	
	const int finalScore = SCORING_MAX_SCORE_POSSIBLE - scoreDeductions;
	//TODO: post the score to the server or queue for online processing

			
	
	//show a level won screen
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	LHSprite* levelWonPopup = [_levelLoader createSpriteWithName:@"Level_Won_Popup" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:_mainLayer];
	levelWonPopup.zOrder = 10000;
	[levelWonPopup transformPosition: ccp(winSize.width/2,winSize.height/2)];
	
	const CGSize levelWonPopupSize = levelWonPopup.boundingBox.size;


	/***** action butons ******/
	
	const int buttonYOffset = (120 - (levelWonPopupSize.height - winSize.height)*.9)*SCALING_FACTOR_V;
	
	LHSprite* levelsMenuButton = [_levelLoader createSpriteWithName:@"Levels_Menu_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	[levelsMenuButton prepareAnimationNamed:@"Menu_Levels_Menu_Button" fromSHScene:@"Spritesheet"];
	[levelsMenuButton transformPosition: ccp(winSize.width/2 - levelsMenuButton.boundingBox.size.width*2,
											levelsMenuButton.boundingBox.size.height/2 + buttonYOffset) ];
	[levelsMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelsMenu:)];
	[levelsMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelsMenu:)];
	
	LHSprite* restartMenuButton = [_levelLoader createSpriteWithName:@"Restart_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	[restartMenuButton prepareAnimationNamed:@"Menu_Restart_Button" fromSHScene:@"Spritesheet"];
	[restartMenuButton transformPosition: ccp(winSize.width/2,
											restartMenuButton.boundingBox.size.height/2 + buttonYOffset) ];
	[restartMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[restartMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];
	
	LHSprite* nextLevelMenuButton = [_levelLoader createSpriteWithName:@"Next_Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	[nextLevelMenuButton prepareAnimationNamed:@"Menu_Next_Level_Button" fromSHScene:@"Spritesheet"];
	[nextLevelMenuButton transformPosition: ccp(winSize.width/2 + restartMenuButton.boundingBox.size.width*2,
											nextLevelMenuButton.boundingBox.size.height/2 + buttonYOffset) ];
	[nextLevelMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganNextLevel:)];
	[nextLevelMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedNextLevel:)];
	
	
	/***** scoring items ******/

	const int scoringYOffset = (IS_IPHONE ? 495 : 475)*SCALING_FACTOR_V;
	
	CCLabelTTF* maxScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", SCORING_MAX_SCORE_POSSIBLE] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1 ];
	maxScoreLabel.color = SCORING_FONT_COLOR2;
	maxScoreLabel.position = ccp(winSize.width/2 - (185*SCALING_FACTOR_H) - (IS_IPHONE ? 15*SCALING_FACTOR_H : 0),
								 scoringYOffset);
	[self addChild:maxScoreLabel];
		
	
	CCLabelTTF* elapsedPlaceTimeLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", timeScoreDeduction] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	elapsedPlaceTimeLabel.color = SCORING_FONT_COLOR1;
	elapsedPlaceTimeLabel.position = ccp(winSize.width/2 - (75*SCALING_FACTOR_H) - (IS_IPHONE ? 5*SCALING_FACTOR_H : 0),
									  	scoringYOffset);
	[self addChild:elapsedPlaceTimeLabel];


	CCLabelTTF* toolsScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", toolsScoreDeduction] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	toolsScoreLabel.color = SCORING_FONT_COLOR1;
	toolsScoreLabel.position = ccp(winSize.width/2 + (35*SCALING_FACTOR_H),
									scoringYOffset);
	[self addChild:toolsScoreLabel];

	CCLabelTTF* totalScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", finalScore] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE2];
	totalScoreLabel.color = SCORING_FONT_COLOR2;
	totalScoreLabel.position = ccp(winSize.width/2 + (170*SCALING_FACTOR_H) + (IS_IPHONE ? 15*SCALING_FACTOR_H : 0),
									scoringYOffset);
	[self addChild:totalScoreLabel];





	/***** competitive items ******/

	const int competitiveTextXOffset = (172 + (IS_IPHONE ? 15 : 0))*SCALING_FACTOR_H;
	const int competitiveTextYOffset = 130*SCALING_FACTOR_V;

	//TODO: get the numbers from the server (or cached copy!)

	CCLabelTTF* worldPercentCompleteLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%%", 45] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	worldPercentCompleteLabel.color = SCORING_FONT_COLOR3;
	worldPercentCompleteLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
											240*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? 0 : 0));
	[self addChild:worldPercentCompleteLabel];

	CCLabelTTF* worldAverageScoreLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", 8000] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE1];
	worldAverageScoreLabel.color = SCORING_FONT_COLOR3;
	worldAverageScoreLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
										170*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -7 : 0));
	[self addChild:worldAverageScoreLabel];

	CCLabelTTF* worldPercentileLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%%", 10] fontName:@"Helvetica" fontSize:SCORING_FONT_SIZE2];
	worldPercentileLabel.color = SCORING_FONT_COLOR2;
	worldPercentileLabel.position = ccp(winSize.width/2 + competitiveTextXOffset,
										95*SCALING_FACTOR_V + competitiveTextYOffset + (IS_IPHONE ? -12 : 0));
	[self addChild:worldPercentileLabel];


}

//TODO: can this even happen anymore
-(void) levelLostWithOffscreenPenguin:(LHSprite*)penguin {

	if(_state == GAME_OVER) {
		return;
	}
	_state = GAME_OVER;

	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/levelLost/hoot.wav"];
	}
	
	
	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}


	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Offscreen Penguin", @"Level_Lost_Reason",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];

	NSLog(@"Showing level lost animations for offscreen penguin");
	

	//TODO: show some kind of information about how penguins have to reach the safety point
	
	[self showLevelLostPopup];
}

-(void) levelLostWithShark:(LHSprite*)shark andPenguin:(LHSprite*)penguin {

	if(_state == GAME_OVER) {
		return;
	}
	_state = GAME_OVER;

	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/levelLost/hoot.wav"];
	}

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}

	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Shark Collision", @"Level_Lost_Reason",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];

	NSLog(@"Showing level lost animations for penguin/shark collision");
	

	//TODO: show some happy sharks and sad penguins (if any are left!)
	//eg. [shark startAnimationNamed:@"attackPenguin"];
	
	[self showLevelLostPopup];
}

-(void)showLevelLostPopup {
	//show a level won screen
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	LHSprite* levelLostPopup = [_levelLoader createSpriteWithName:@"Level_Lost_Popup" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	levelLostPopup.opacity = 0;
	levelLostPopup.zOrder = 10000;
	[levelLostPopup transformPosition: ccp(winSize.width/2,winSize.height/2)];



	/***** action butons ******/
	
	const int buttonYOffset = (-25 - (levelLostPopup.contentSize.height - winSize.height)*.9)*SCALING_FACTOR_V;

	LHSprite* levelsMenuButton = [_levelLoader createSpriteWithName:@"Levels_Menu_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	levelsMenuButton.opacity = 0;
	levelsMenuButton.zOrder = levelLostPopup.zOrder+1;
	[levelsMenuButton prepareAnimationNamed:@"Menu_Levels_Menu_Button" fromSHScene:@"Spritesheet"];
	[levelsMenuButton transformPosition: ccp(winSize.width/2 - levelsMenuButton.boundingBox.size.width,
										buttonYOffset + levelLostPopup.boundingBox.size.height/2 - levelsMenuButton.boundingBox.size.height/2 + (IS_IPHONE ? -25 : 0)*SCALING_FACTOR_V) ];
	[levelsMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelsMenu:)];
	[levelsMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelsMenu:)];
	
	LHSprite* restartMenuButton = [_levelLoader createSpriteWithName:@"Restart_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	restartMenuButton.opacity = 0;
	restartMenuButton.zOrder = levelLostPopup.zOrder+1;
	[restartMenuButton prepareAnimationNamed:@"Menu_Restart_Button" fromSHScene:@"Spritesheet"];
	[restartMenuButton transformPosition: ccp(winSize.width/2 + restartMenuButton.boundingBox.size.width, buttonYOffset + levelLostPopup.boundingBox.size.height/2 - restartMenuButton.boundingBox.size.height/2 + (IS_IPHONE ? -25 : 0)*SCALING_FACTOR_V) ];
	[restartMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[restartMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];


	//show!!
	[levelLostPopup runAction:[CCFadeIn actionWithDuration:0.5f]];
	[levelsMenuButton runAction:[CCFadeIn actionWithDuration:0.5f]];
	[restartMenuButton runAction:[CCFadeIn actionWithDuration:0.5f]];
}

-(void) restart {

	NSLog(@"Restarting");
	_state = GAME_OVER;

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}

	//analytics logging
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Restart", @"Level_Lost_Reason",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];

	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:_levelPackPath levelPath:_levelPath]]];
}







-(void) goToNextLevel {
	NSString* nextLevelPath = [LevelPackManager levelAfter:_levelPath inPack:_levelPackPath];
	NSLog(@"Going to next level %@", nextLevelPath);
	
	if(nextLevelPath == nil) {
		//TODO: show some kind of pack completed notification
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelPackSelectLayer scene] ]];
	
	}else {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:_levelPackPath levelPath:nextLevelPath]]];
	}
}

-(void) showMainMenuLayer {
	NSLog(@"Showing MainMenuLayer in GameLayer instance %f", _instanceId);
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1.0 scene:[MainMenuLayer scene] ]];
}

-(void) showLevelsMenuLayer {
	NSLog(@"Showing LevelSelectLayer in GameLayer instance %f", _instanceId);
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1.0 scene:[LevelSelectLayer sceneWithLevelPackPath:[NSString stringWithFormat:@"%@", _levelPackPath]] ]];
}

-(void) showTutorial {

	LHSprite* tutorial = nil;

	//NOTE: maybe we always show tutorials for these levels?

	//have we shown this tutorial yet?
	if(![SettingsManager boolForKey:@"HasSeenTutorial1"]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial1"];
		if(tutorial != nil) {
			NSLog(@"Showing tutorial 1");
			//[SettingsManager setBool:true forKey:@"HasSeenTutorial1"];
		}
	}
	if(tutorial == nil && ![SettingsManager boolForKey:@"HasSeenTutorial2"]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial2"];
		if(tutorial != nil) {
			NSLog(@"Showing tutorial 2");
			//[SettingsManager setBool:true forKey:@"HasSeenTutorial2"];
		}
	}
	if(tutorial == nil && ![SettingsManager boolForKey:@"HasSeenTutorial3"]) {
		//is this tutorial available on this level?
		tutorial = [_levelLoader spriteWithUniqueName:@"Tutorial3"];
		if(tutorial != nil) {
			NSLog(@"Showing tutorial 3");
			//[SettingsManager setBool:true forKey:@"HasSeenTutorial3"];
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

	if((!force && _state != RUNNING)) {
		return;
	}
	
	if(!_isUpdatingPenguinMoveGrids) {
		_isUpdatingPenguinMoveGrids = true;
		dispatch_async(_moveGridPenguinUpdateQueue, ^(void) {
	
			NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
			for(LHSprite* penguin in penguins) {
				
				CGPoint penguinGridPos = [self toGrid:penguin.position];
				Penguin* penguinData = ((Penguin*)penguin.userInfo);
				
				if(penguinData.isSafe || penguinData.isStuck) {
					continue;
				}
				
				if(penguinGridPos.x > _gridWidth-1 || penguinGridPos.x < 0 || penguinGridPos.y > _gridHeight-1 || penguinGridPos.y < 0) {
					NSLog(@"Penguin %@ is offscreen at %f,%f - showing level lost", penguin.uniqueName, penguinGridPos.x, penguinGridPos.y);
					[self levelLostWithOffscreenPenguin:penguin];
					return;
				}
				
				if(!penguinData.hasSpottedShark) {
					NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
					for(LHSprite* shark in sharks) {
						double dist = ccpDistance(shark.position, penguin.position);
						if(dist < penguinData.detectionRadius*SCALING_FACTOR_GENERIC) {
						
							penguinData.hasSpottedShark = true;
							
							//TODOO: play some kind of penguin animation with an alert dialog and a squawk sound
							
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

					MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:penguin.uniqueName];
					[penguinMoveGridData updateMoveGridToTile:targetLandGridPos fromTile:penguinGridPos];
				}
			}
			_isUpdatingPenguinMoveGrids = false;
		});
	}
			
	if(!_isUpdatingSharkMoveGrids) {
		_isUpdatingSharkMoveGrids = true;
		dispatch_async(_moveGridSharkUpdateQueue, ^(void) {

			NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
			NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
			LHSprite* targetPenguin = nil;
				
			for(LHSprite* shark in sharks) {
				
				Shark* sharkData = ((Shark*)shark.userInfo);
				CGPoint sharkGridPos = [self toGrid:shark.position];

				if(sharkGridPos.x >= _gridWidth || sharkGridPos.x < 0 || sharkGridPos.y >= _gridHeight || sharkGridPos.y < 0) {
					NSLog(@"Shark %@ has moved offscreen to %f,%f - removing him", shark.uniqueName, sharkGridPos.x, sharkGridPos.y);
					[shark removeSelf];
					continue;
				}

				//set our search distance
				double minDistance = 100000000;
				if(!sharkData.targetAcquired) {
					for(LHSprite* penguin in penguins) {
						Penguin* penguinData = ((Penguin*)penguin.userInfo);
						if(penguinData.isSafe || penguinData.isStuck) {
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
					if(penguinData.isSafe || penguinData.isStuck) {
						continue;
					}	
					
					double dist = ccpDistance(shark.position, penguin.position);
					if(dist < minDistance) {
						//NSLog(@"Shark %@'s closest penguin is %@ at %f", shark.uniqueName, penguin.uniqueName, dist);
						minDistance = dist;
						targetPenguin = penguin;
						sharkData.targetAcquired = true;
					}
				}
				
				if(targetPenguin != nil) {
					CGPoint targetPenguinGridPos = [self toGrid:targetPenguin.position];

					MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];
					[sharkMoveGridData updateMoveGridToTile:targetPenguinGridPos fromTile:sharkGridPos];
				}
			}
			
			_isUpdatingSharkMoveGrids = false;
		});
	}
}

-(void)scoreToolboxItemPlacement:(LHSprite*)toolboxItem {

	//accounting
	ToolboxItem_Debris* toolboxItemData = ((ToolboxItem_Debris*)_activeToolboxItem.userInfo);
	int score = _state == PLACE ? toolboxItemData.placeCost : toolboxItemData.runningCost;
	[_scoreKeeper addScore:score description:(_state == PLACE ? @"PLACE" : @"RUNNING") sprite:_activeToolboxItem group:true];
	
	//show a notification about the cost of the item
	CCLabelTTF* toolboxItemCostNotification = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"-%d", score] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS];
	toolboxItemCostNotification.color = ccRED;
	toolboxItemCostNotification.position = _activeToolboxItem.position;
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
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Update tick");
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
	
	//regenerate base feature maps if need be
	if(_shouldRegenerateFeatureMaps) {
  		_shouldRegenerateFeatureMaps = false;
		[self generateFeatureMaps];
	}	
	
	if(_shouldUpdateToolbox) {
		_shouldUpdateToolbox = false;
		[self updateToolbox];
	}
	
	//drop any toolbox items if need be
	if(_activeToolboxItem != nil && _moveActiveToolboxItemIntoWorld) {
	
		NSLog(@"Adding toolbox item %@ to world", _activeToolboxItem.userInfoClassName);
		
		NSString* soundFileName = @"place.wav";
	
		//StaticToolboxItem are things penguins and sharks can't move through
		if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			_activeToolboxItem.tag = DEBRIS;
			[_activeToolboxItem makeDynamic];
			[_activeToolboxItem setSensor:false];
			soundFileName = @"place-debris.wav";
			
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Border"]) {
			_activeToolboxItem.tag = BORDER;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:false];
			_shouldRegenerateFeatureMaps = true;
			soundFileName = @"place-border.wav";

		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Windmill"]) {
			_activeToolboxItem.tag = WINDMILL;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:true];
			soundFileName = @"place-windmill.wav";
		
		}

		[self scoreToolboxItemPlacement:_activeToolboxItem];
		
		//move it into the main layer so it's under the HUD
		if(_activeToolboxItem.parent == _toolboxBatchNode) {
			[_toolboxBatchNode removeChild:_activeToolboxItem cleanup:NO];
		}
		[_mainLayer addChild:_activeToolboxItem];
		[_placedToolboxItems addObject:_activeToolboxItem];

		//analytics logging
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelPath, @"Level_Name", 
			_levelPackPath, @"Level_Pack",
			_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
			_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
			NSStringFromCGPoint(_activeToolboxItem.position), @"Location",
		nil];
		[Flurry logEvent:@"Place_Toolbox_Item" withParameters:flurryParams];				

		if([SettingsManager boolForKey:@"SoundEnabled"]) {
			[[SimpleAudioEngine sharedEngine] playEffect:[NSString stringWithFormat:@"sounds/game/toolbox/%@", soundFileName ]];
		}
	
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = true;
	}
	
	if(__DEBUG_TOUCH_SECONDS != 0) {
		double elapsed = ([[NSDate date] timeIntervalSince1970] - __DEBUG_TOUCH_SECONDS);
		if(elapsed >= 1 && !__DEBUG_SHARKS) {
			NSLog(@"Enabling debug sharks");
			__DEBUG_SHARKS = true;
			__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
			self.color = ccBLACK;
			NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
			for(LHSprite* background in backgrounds) {
				[background setVisible:false];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelPath, @"Level_Name", 
				_levelPackPath, @"Level_Pack",
			nil];
			[Flurry logEvent:@"Debug_Sharks_Enabled" withParameters:flurryParams];		
			
		}
		if(elapsed >= 2 && !__DEBUG_PENGUINS) {
			NSLog(@"Enabling debug penguins");
			__DEBUG_PENGUINS = true;
			__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
			self.color = ccBLACK;
			NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
			for(LHSprite* background in backgrounds) {
				[background setVisible:false];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelPath, @"Level_Name", 
				_levelPackPath, @"Level_Pack",
			nil];
			[Flurry logEvent:@"Debug_Penguins_Enabled" withParameters:flurryParams];		
		}
		if(elapsed >= 5 && (__DEBUG_PENGUINS || __DEBUG_SHARKS)) {
			NSLog(@"Disable debug penguins and sharks");
			__DEBUG_PENGUINS = false;
			__DEBUG_SHARKS = false;
			self.color = __DEBUG_ORIG_BACKGROUND_COLOR;
			self.color = ccBLACK;
			NSArray* backgrounds = [_levelLoader spritesWithTag:BACKGROUND];
			for(LHSprite* background in backgrounds) {
				[background setVisible:true];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelPath, @"Level_Name", 
				_levelPackPath, @"Level_Pack",
			nil];
			[Flurry logEvent:@"Disable_Debug_Penguins_and_Sharks" withParameters:flurryParams];		
		}
	}
	
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
	
	
	
	[self moveSharks:dt];
	[self movePenguins:dt];
	[self updateMoveGrids];
	
	
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done with game state update");




	//It is recommended that a fixed time step is used with Box2D for stability
	//of the simulation, however, we are using a variable time step here.
	//You need to make an informed choice, the following URL is useful
	//http://gafferongames.com/game-physics/fix-your-timestep/
	
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	
	// Instruct the world to perform a single step of simulation. It is
	// generally best to keep the time step and iterations fixed.
	_world->Step(dt, velocityIterations, positionIterations);
	
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done with world step");
	
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

	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done with update tick");
}

//TODO: add a shark *thrashing* animation when it slows down to indicate a struggle. make it look mad!


-(void) moveSharks:(ccTime)dt {
		
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Moving %d sharks...", [sharks count]);
	
	if([sharks count] == 0) {
		//winna winna chicken dinna!
		[self levelWon];
		return;
	}	
		
	for(LHSprite* shark in sharks) {
		
		Shark* sharkData = ((Shark*)shark.userInfo);
		CGPoint sharkGridPos = [self toGrid:shark.position];

		if(sharkGridPos.x >= _gridWidth || sharkGridPos.x < 0 || sharkGridPos.y >= _gridHeight || sharkGridPos.y < 0) {
			NSLog(@"Shark %@ has moved offscreen to %f,%f - removing him", shark.uniqueName, sharkGridPos.x, sharkGridPos.y);
			[shark removeSelf];
			continue;
		}
		
		//use the best route algorithm
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];
		CGPoint bestOptionPos = [sharkMoveGridData getBestMoveToTile:sharkMoveGridData.lastTargetTile fromTile:sharkGridPos];
		
		//NSLog(@"Best Option Pos: %f,%f", bestOptionPos.x,bestOptionPos.y);
		if(bestOptionPos.x == -10000 && bestOptionPos.y == -10000) {
			//this occurs when the shark has no route to the penguin - he literally has no idea which way to go
			if(SHARK_DIES_WHEN_STUCK) {
				//we're stuck
				sharkData.isStuck = true;
				NSLog(@"Shark %@ is stuck (no where to go) - we're removing him", shark.uniqueName);
				//TODO: make the shark spin around in circles and explode in frustration!
				[shark removeSelf];
				continue;
			}else {
				NSLog(@"Shark %@ is stuck (no where to go) - we're letting him keep at it", shark.uniqueName);
				bestOptionPos = ccp(shark.position.x+((arc4random()%10)-5)/10.0,shark.position.y+((arc4random()%10)-5)/10.0);
				//TODO: make the shark show some kind of frustration (perhaps smoke in nostrils/grimac)
			}
		
		}else {
			//convert returned velocities to position..
			bestOptionPos = ccp(shark.position.x+bestOptionPos.x, shark.position.y+bestOptionPos.y);
		}
		
		double dx = bestOptionPos.x - shark.position.x;
		double dy = bestOptionPos.y - shark.position.y;

		double sharkSpeed = sharkData.restingSpeed;
		if(sharkData.targetAcquired) {
			sharkSpeed = sharkData.activeSpeed;
		}
				
		[sharkMoveGridData logMove:bestOptionPos];
		if([sharkMoveGridData distanceTraveledStraightline] < 2*SCALING_FACTOR_GENERIC) {
			if(SHARK_DIES_WHEN_STUCK) {
				//we're stuck
				sharkData.isStuck = true;
				NSLog(@"Shark %@ is stuck (trying to move, but not making progress) - we're removing him", shark.uniqueName);
				//TODO: make the shark spin around in circles and explode in frustration!
				[shark removeSelf];
			}else {
				//TODO: do a confused/arms up in air animation
				
				dx+= ((arc4random()%200)-100)/1000;
				dy+= ((arc4random()%200)-100)/1000;
				sharkSpeed*= 5;
				NSLog(@"Shark %@ is stuck (trying to move but can't) - giving him a bit of jitter", shark.uniqueName);

			}
		}

		double dxMod = 0;
		double dyMod = 0;

		//TODO: this is inefficient because it casts much more often than it needs to. optimize if need be
		//adjust the shark speed by any movement altering affects in play (such as windmills)
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
				if (callback._fixture->GetBody() == shark.body) {
					//shark is in the way!!
					//NSLog(@"Shark %@ is in the way of a windmill %@! Applying effects...", shark.uniqueName, windmill.uniqueName);
					
					double dModSum = fabs(xDir) + fabs(yDir);
					if(dModSum == 0) {
						dModSum = 1;
					}					
					
					dxMod = (xDir/dModSum)*(windmillData.power);
					dyMod = (yDir/dModSum)*(windmillData.power);
					
				}
			}
		}
				
		double dSum = fabs(dx) + fabs(dy);
		if(dSum == 0) {
			//no best option?
			//NSLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
			dSum = 1;
		}
		double normalizedX = (sharkSpeed*dx)/dSum;
		double normalizedY = (sharkSpeed*dy)/dSum;

		double impulseX = ((normalizedX+dxMod)*dt)*.1*pow(shark.scale,2);
		double impulseY = ((normalizedY+dyMod)*dt)*.1*pow(shark.scale,2);
		
		//NSLog(@"Shark %@'s normalized x,y = %f,%f. dx=%f, dy=%f dxMod=%f, dyMod=%f. impulse = %f,%f", shark.uniqueName, normalizedX, normalizedY, dx, dy, dxMod, dyMod, impulseX, impulseY);
				
		//we're using an impulse for the shark so they interact with things like Debris (physics)
		//shark.body->SetLinearVelocity(b2Vec2(weightedVelX,weightedVelY));
		shark.body->ApplyLinearImpulse(b2Vec2(impulseX, impulseY), shark.body->GetWorldCenter());
		
		//rotate shark
		double targetVelX = dt * normalizedX;
		double targetVelY = dt * normalizedY;
		b2Vec2 prevVel = shark.body->GetLinearVelocity();
		double weightedVelX = (prevVel.x * 9.0 + targetVelX)/10.0;
		double weightedVelY = (prevVel.y * 9.0 + targetVelY)/10.0;

		double radians = atan2(weightedVelX, weightedVelY); //this grabs the radians for us
		double degrees = CC_RADIANS_TO_DEGREES(radians) - 90; //90 is because the sprit is facing right
		[shark transformRotation:degrees];
		
		//TODO: add a waddle animation
	}
	
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done moving %d sharks...", [sharks count]);
}

-(void) movePenguins:(ccTime)dt {

	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Moving %d penguins...", [penguins count]);

	bool hasWon = true;
	for(LHSprite* penguin in penguins) {
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
		if(!penguinData.isSafe) {
			hasWon = false;
			break;
		}
	}
	if(hasWon) {
		NSLog(@"All penguins have made it to safety!");
		[self levelWon];
		return;
	}

	for(LHSprite* penguin in penguins) {
		
		CGPoint penguinGridPos = [self toGrid:penguin.position];
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
		MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:penguin.uniqueName];
		
		if(penguinData.isSafe || penguinData.isStuck) {
			continue;
		}
		
		if(penguinGridPos.x > _gridWidth-1 || penguinGridPos.x < 0 || penguinGridPos.y > _gridHeight-1 || penguinGridPos.y < 0) {
			NSLog(@"Penguin %@ is offscreen at %f,%f - showing level lost", penguin.uniqueName, penguinGridPos.x, penguinGridPos.y);
			[self levelLostWithOffscreenPenguin:penguin];
			return;
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

							//TODO: show some kind of AH!!! speech bubble alert animation for the penguins communicating
							
							[penguin2 prepareAnimationNamed:@"Penguin_Waddle" fromSHScene:@"Spritesheet"];
							if(_state == RUNNING) {
								[penguin2 playAnimation];
							}
						}
					}
				}
			}

			//use the best route algorithm
			CGPoint bestOptionPos = [penguinMoveGridData getBestMoveToTile:penguinMoveGridData.lastTargetTile fromTile:penguinGridPos];
					
			if(bestOptionPos.x == -10000 && bestOptionPos.y == -10000) {
				NSLog(@"Penguin %@ is stuck (nowhere to go)!", penguin.uniqueName);
				penguinData.isStuck = true;
				//TODO: show a confused expression. possibly raising wings into the air in a "oh well" gesture
				
				//halt!
				penguin.body->SetLinearVelocity(b2Vec2(0,0));
				penguin.body->SetAngularVelocity(0);
				
				continue;

			}else {
				//convert returned velocities to position..
				bestOptionPos = ccp(penguin.position.x+bestOptionPos.x, penguin.position.y+bestOptionPos.y);
			}
					
			double dx = bestOptionPos.x - penguin.position.x;
			double dy = bestOptionPos.y - penguin.position.y;
			double penguinSpeed = penguinData.speed;

			[penguinMoveGridData logMove:bestOptionPos];
			if([penguinMoveGridData distanceTraveledStraightline] < 2*SCALING_FACTOR_GENERIC) {
				//we're stuck... but we'll let sharks report us as being stuck.
				//we'll just try and get ourselves out of this sticky situation
				
				//TODO: do a flustered/feathers flying everywhere animation
				
				dx+= ((arc4random()%200)-100)/1000;
				dy+= ((arc4random()%200)-100)/1000;
				penguinSpeed*= 5;
				NSLog(@"Penguin %@ is stuck (trying to move but can't) - giving him a bit of jitter", penguin.uniqueName);
			}
			

			double dxMod = 0;
			double dyMod = 0;

			//TODO: this is inefficient because it casts much more often than it needs to. optimize if need be
			//adjust the penguin speed by any movement altering affects in play (such as windmills)
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
					if (callback._fixture->GetBody() == penguin.body) {
						//shark is in the way!!
						//NSLog(@"Penguin %@ is in the way of a windmill %@! Applying effects...", penguin.uniqueName, windmill.uniqueName);
						
						double dModSum = fabs(xDir) + fabs(yDir);
						if(dModSum == 0) {
							dModSum = 1;
						}					
						
						dxMod = (xDir/dModSum)*(windmillData.power);
						dyMod = (yDir/dModSum)*(windmillData.power);
						
					}
				}
			}

				
			double dSum = fabs(dx) + fabs(dy);
			if(dSum == 0) {
				//no best option?
				//NSLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
				dSum = 1;
			}
			double normalizedX = (penguinSpeed*dx)/dSum;
			double normalizedY = (penguinSpeed*dy)/dSum;
			
			double impulseX = ((normalizedX+dxMod)*dt)*.1*pow(penguin.scale,2);
			double impulseY = ((normalizedY+dyMod)*dt)*.1*pow(penguin.scale,2);
			
			//NSLog(@"Penguin %@'s normalized x,y = %f,%f. dx=%f, dy=%f dxMod=%f, dyMod=%f. impulse = %f,%f", penguin.uniqueName, normalizedX, normalizedY, dx, dy, dxMod, dyMod, impulseX, impulseY);
		
			//TODO:! look into why on iPad Retina simulator the Penguin and Shark can't move at all????
		
			//we're using an impulse for the penguin so they interact with things like Debris (physics)
			penguin.body->ApplyLinearImpulse(b2Vec2(impulseX, impulseY), penguin.body->GetWorldCenter());			
		}
	}

	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done moving %d penguins...", [penguins count]);

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
			NSLog(@"Shark %@ has collided with penguin %@!", shark.uniqueName, penguin.uniqueName);
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
			NSLog(@"Penguin %@ has collided with some land!", penguin.uniqueName);
		}
		
		//TODO: replace penguin a happy animation
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
				//TODO: add some kind of crosshair so you know where the item is if it's tiny and under your finger
				[_activeToolboxItem transformPosition:location];
			}/*else if(_startTouch.x != 0 && _startTouch.y != 0) {
				//slide the main layer
				_mapBatchNode.position = ccp(_mapBatchNode.position.x+location.x-_lastTouch.x, _mapBatchNode.position.y+location.y-_lastTouch.y);
				_actorsBatchNode.position = ccp(_mapBatchNode.position.x+location.x-_lastTouch.x, _mapBatchNode.position.y+location.y-_lastTouch.y);
				for(LHSprite* toolboxItem in _placedToolboxItems) {
					[toolboxItem transformPosition:ccp(toolboxItem.position.x+location.x-_lastTouch.x, toolboxItem.position.y+location.y-_lastTouch.y)];
				}				
				_lastTouch = location;
			}*/
		}
	}
}


- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];

		if(_state == RUNNING || _state == PLACE) {
			if(_activeToolboxItem && ccpDistance(location, _activeToolboxItem.position) > 50*SCALING_FACTOR_GENERIC) {
				//tapping a second finger on the screen when moving a toolbox item rotates the item
				[_activeToolboxItem transformRotation:((int)_activeToolboxItem.rotation+90)%360];
				
				if([SettingsManager boolForKey:@"SoundEnabled"]) {
					[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/game/toolbox/rotate.wav"];
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
	}
}






-(void) drawDebugMovementGrid {

	if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {

		MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:@"Penguin"];
		const int** penguinMoveGrid = nil;
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:@"Shark"];
		const int** sharkMoveGrid = nil;
		if(penguinMoveGridData != nil) {
			penguinMoveGrid = [penguinMoveGridData moveGrid];
		}
		if(sharkMoveGridData != nil) {
			sharkMoveGrid = [sharkMoveGridData moveGrid];
		}
		
		double max = _gridWidth*4;
		ccPointSize(_gridSize-1);
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				if(__DEBUG_PENGUINS && penguinMoveGrid != nil) {
					int pv = (penguinMoveGrid[x][y]);
					ccDrawColor4B(55,55,(log(pv/max * 100)/2)*200+55,50);
					ccDrawPoint( ccp(x*_gridSize+_gridSize/2, y*_gridSize+_gridSize/2) );
				}
				if(__DEBUG_SHARKS && sharkMoveGrid != nil) {
					int sv = (sharkMoveGrid[x][y]);
					ccDrawColor4B((log(sv/max * 100)/2)*200+55,55,55,50);
					ccDrawPoint( ccp(x*_gridSize + _gridSize/2, y*_gridSize + _gridSize/2) );
				}
			}
		}	

		NSArray* lands = [_levelLoader spritesWithTag:LAND];
		NSArray* borders = [_levelLoader spritesWithTag:BORDER];

		ccColor4F landColor = ccc4f(0,100,0,50);
		for(LHSprite* land in lands) {
			ccDrawSolidRect(ccp(land.boundingBox.origin.x - 8*SCALING_FACTOR_H,
								land.boundingBox.origin.y - 8*SCALING_FACTOR_V),
			ccp(land.boundingBox.origin.x+land.boundingBox.size.width + 8*SCALING_FACTOR_H,
				land.boundingBox.origin.y+land.boundingBox.size.height + 8*SCALING_FACTOR_V),
			landColor);
		}
		ccColor4F borderColor = ccc4f(0,200,200,50);
		for(LHSprite* border in borders) {
			ccDrawSolidRect(ccp(border.boundingBox.origin.x - 8*SCALING_FACTOR_H,
								border.boundingBox.origin.y - 8*SCALING_FACTOR_V),
							ccp(border.boundingBox.origin.x+border.boundingBox.size.width + 8*SCALING_FACTOR_H,
								border.boundingBox.origin.y+border.boundingBox.size.height + 8*SCALING_FACTOR_V),
							borderColor);
		}
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
	if(DEBUG_MEMORY) NSLog(@"Begin GameLayer %f onExit", _instanceId);
	if(DEBUG_MEMORY) report_memory();

	_state = GAME_OVER;

    [self unscheduleAllSelectors];
    [self unscheduleUpdate];

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}
		
    [super onExit];
	
	if(DEBUG_MEMORY) NSLog(@"End GameLayer %f onExit", _instanceId);
	if(DEBUG_MEMORY) report_memory();
}

-(void) dealloc
{
	if(DEBUG_MEMORY) NSLog(@"Begin GameLayer %f dealloc", _instanceId);
	if(DEBUG_MEMORY) report_memory();
	
	[_levelLoader removeAllPhysics];

	[_levelPath release];
	[_levelPackPath release];

	[_inGameMenuItems release];
	
	for(id key in _toolGroups) {
		NSMutableDictionary* toolGroup = [_toolGroups objectForKey:key];
		[toolGroup release];
	}
	[_toolGroups release];
	[_placedToolboxItems release];
	[_scoreKeeper release];
	
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
	
	if(DEBUG_MEMORY) NSLog(@"End GameLayer %f dealloc", _instanceId);
	if(DEBUG_MEMORY) report_memory();
}	

@end
