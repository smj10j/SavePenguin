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


#import "MainMenuLayer.h"
#import "MoveGridData.h"

#pragma mark - GameLayer

@interface GameLayer()

//initialization
-(void) initPhysics;
-(void) loadLevel:(NSString*)levelName inLevelPack:(NSString*)levelPack;
-(void) drawHUD;

//different screens/layers/dialogs
-(void) showTutorial;
-(void) goToNextLevel;

//game control
-(void) resume;
-(void) pause;
-(void) showInGameMenu;
-(void) restart;



@end

@implementation GameLayer

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	GameLayer *layer = [GameLayer node];
	
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
		
		_shouldRegenerateFeatureMaps = false;
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = false;
		_penguinsToPutOnLand =[[NSMutableDictionary alloc] init];
		__DEBUG_SHARKS = DEBUG_SHARK;
		__DEBUG_PENGUINS = DEBUG_PENGUIN;
		__DEBUG_TOUCH_SECONDS = 0;
		if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {
			self.color = ccBLACK;
		}
		__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
		
		// init physics
		[self initPhysics];
		
		//TODO: store and load the level from prefs using JSON files for next/prev
		NSString* levelName = @"Introduction";
		NSString* levelPack = @"Arctic";
		
		_levelName = levelName;
		_levelPack = levelPack;
		[self loadLevel:_levelName inLevelPack:_levelPack];
		
		//place the HUD items (pause, restart, etc.)
		[self drawHUD];		
		
		//set the grid size and create various arrays
		[self initializeMapGrid];
		
		//place the toolbox items
		[self updateToolbox];
		
		//various handlers
		[self setupCollisionHandling];
		
		//start the game
		_state = PLACE;
		CCDirectorIOS* director = (CCDirectorIOS*) [CCDirector sharedDirector];
		[director setAnimationInterval:1.0/TARGET_FPS];
		[self scheduleUpdate];
		
		
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelName, @"Level_Name",
			_levelPack, @"Level_Pack",
		nil];

		[Flurry logEvent:@"Play_Level" withParameters:flurryParams timed:YES];		
	}
	return self;
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
		
	_gridWidth = winSize.width/_gridSize + 1;
	_gridHeight = winSize.height/_gridSize + 1;

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

	_bottomBarContainer = [_levelLoader createBatchSpriteWithName:@"BottomBar" fromSheet:@"HUD" fromSHFile:@"Spritesheet" tag:BORDER];
	;
	[_bottomBarContainer transformPosition: ccp(winSize.width/2,_bottomBarContainer.boundingBox.size.height/2)];

	_playPauseButton = [_levelLoader createBatchSpriteWithName:@"Play_inactive" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
	[_playPauseButton prepareAnimationNamed:@"Play_Pause_Button" fromSHScene:@"Spritesheet"];
	[_playPauseButton transformPosition: ccp(_playPauseButton.boundingBox.size.width/2+HUD_BUTTON_MARGIN_H,_playPauseButton.boundingBox.size.height/2+HUD_BUTTON_MARGIN_V)];
	[_playPauseButton registerTouchBeganObserver:self selector:@selector(onTouchBeganPlayPause:)];
	[_playPauseButton registerTouchEndedObserver:self selector:@selector(onTouchEndedPlayPause:)];
		
	_restartButton = [_levelLoader createBatchSpriteWithName:@"Restart_inactive" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
	[_restartButton prepareAnimationNamed:@"Restart_Button" fromSHScene:@"Spritesheet"];
	[_restartButton transformPosition: ccp(winSize.width - (_restartButton.boundingBox.size.width/2+HUD_BUTTON_MARGIN_H),_restartButton.boundingBox.size.height/2+HUD_BUTTON_MARGIN_V) ];
	[_restartButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[_restartButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];
	
	
	_menuPopupContainer = [_levelLoader createBatchSpriteWithName:@"Menu_Popup" fromSheet:@"Menu" fromSHFile:@"Spritesheet"];
	[_menuPopupContainer transformPosition: ccp(5*SCALING_FACTOR_H + _menuPopupContainer.boundingBox.size.width/2,
												-_menuPopupContainer.boundingBox.size.height)];
	LHSprite* mainMenuButton = [_levelLoader createSpriteWithName:@"Resume_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:_menuPopupContainer];
	[mainMenuButton prepareAnimationNamed:@"Menu_Main_Menu_Button" fromSHScene:@"Spritesheet"];
	[mainMenuButton transformPosition: ccp(_menuPopupContainer.boundingBox.size.width/2,
										_menuPopupContainer.boundingBox.size.height/2) ];
	[mainMenuButton registerTouchBeganObserver:self selector:@selector(onTouchBeganMainMenu:)];
	[mainMenuButton registerTouchEndedObserver:self selector:@selector(onTouchEndedMainMenu:)];
	
	//get the toolbox item size for scaling purposes
	LHSprite* toolboxContainer = [_levelLoader createBatchSpriteWithName:@"Toolbox-Item-Container" fromSheet:@"HUD" fromSHFile:@"Spritesheet"];
	[toolboxContainer removeSelf];
	_toolboxItemSize = toolboxContainer.boundingBox.size.width;
}

-(void) updateToolbox {
	NSLog(@"Updating Toolbox");
	
	for(LHSprite* toolboxItemContainer in [_levelLoader spritesWithTag:TOOLBOX_ITEM_CONTAINER]) {
		[toolboxItemContainer removeSelf];
	}
	
	CGSize winSize = [[CCDirector sharedDirector] winSize];

	NSArray* toolboxItems = [_levelLoader spritesWithTag:TOOLBOX_ITEM];
	
	//get all the tools put on the level - they can be anywhere!
	_toolGroups = [[NSMutableDictionary alloc] init];
	for(LHSprite* toolboxItem in toolboxItems) {
		NSMutableSet* toolGroup = [_toolGroups objectForKey:toolboxItem.userInfoClassName];
		if(toolGroup == nil) {
			toolGroup = [[NSMutableSet alloc] init];
			[_toolGroups setObject:toolGroup forKey:toolboxItem.userInfoClassName];
		}
		[toolGroup addObject:toolboxItem];
	}
	
	
	int toolGroupX = winSize.width/2 - ((_toolboxItemSize)*((_toolGroups.count-1)/2)) - _toolboxItemSize/2;
	int toolGroupY = _bottomBarContainer.boundingBox.size.height/2 - TOOLBOX_MARGIN_TOP;
		
	for(id key in _toolGroups) {

		NSMutableSet* toolGroup = [_toolGroups objectForKey:key];
		for(LHSprite* toolboxItem in toolGroup) {

			//draw a box to hold it
			LHSprite* toolboxContainer = [_levelLoader createSpriteWithName:@"Toolbox-Item-Container" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:_mainLayer];
			toolboxContainer.zOrder = _bottomBarContainer.parent.zOrder;
			toolboxContainer.tag = TOOLBOX_ITEM_CONTAINER;
			[toolboxContainer transformPosition: ccp(toolGroupX, toolGroupY)];

			LHSprite* toolboxContainerCountContainer = [_levelLoader createSpriteWithName:@"Toolbox-Item-Container-Count" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:toolboxContainer];
			[toolboxContainerCountContainer transformPosition: ccp(toolboxContainer.boundingBox.size.width, toolboxContainer.boundingBox.size.height)];

			//move the tool into the box
			[toolboxItem transformPosition: ccp(toolGroupX, toolGroupY)];
			double scale = fmin((_toolboxItemSize-TOOLBOX_ITEM_CONTAINER_PADDING_H)/toolboxItem.contentSize.width, (_toolboxItemSize-TOOLBOX_ITEM_CONTAINER_PADDING_V)/toolboxItem.contentSize.height);
			[toolboxItem transformScale: scale];
			//NSLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", toolboxItem.uniqueName, (int)(100*scale));
		
			//display # of items in the stack
			CCLabelTTF* numToolsLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d", toolGroup.count] fontName:@"Helvetica" fontSize:TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE dimensions:CGSizeMake(TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE, TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE) hAlignment:kCCTextAlignmentCenter vAlignment:kCCVerticalTextAlignmentCenter];
			numToolsLabel.color = ccWHITE;
			numToolsLabel.position = ccp(toolboxContainerCountContainer.boundingBox.size.width/2, toolboxContainerCountContainer.boundingBox.size.height/2);
			[toolboxContainerCountContainer addChild:numToolsLabel];
				
			[toolboxContainer setUserData:toolboxItem.uniqueName];
			[toolboxContainer registerTouchBeganObserver:self selector:@selector(onTouchBeganToolboxItem:)];
			[toolboxContainer registerTouchEndedObserver:self selector:@selector(onTouchEndedToolboxItem:)];
		}
				
		toolGroupX+= _toolboxItemSize + TOOLBOX_MARGIN_LEFT; //16 is a margin
	}
	

}


-(void) loadLevel:(NSString*)levelName inLevelPack:(NSString*)levelPack {
		
	[LevelHelperLoader dontStretchArt];

	//create a LevelHelperLoader object that has the data of the specified level
	if(_levelLoader != nil) {
		[_levelLoader release];
	}
	_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", levelPack, levelName]];
	
	//create all objects from the level file and adds them to the cocos2d layer (self)
	[_levelLoader addObjectsToWorld:_world cocos2dLayer:self];

	_mainLayer = [_levelLoader layerWithUniqueName:@"MAIN_LAYER"];
	_toolboxBatchNode = [_levelLoader batchWithUniqueName:@"Toolbox"];
	_mapBatchNode = [_levelLoader batchWithUniqueName:@"Map"];

	//checks if the level has physics boundaries
	if([_levelLoader hasPhysicBoundaries])
	{
		//if it does, it will create the physic boundaries
		[_levelLoader createPhysicBoundaries:_world];
	}
	
	//draw the background water tiles
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water_1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND parent:_mainLayer];
	for(int x = -waterTile.boundingBox.size.width/2; x < winSize.width + waterTile.boundingBox.size.width/2; ) {
		for(int y = -waterTile.boundingBox.size.height/2; y < winSize.height + waterTile.boundingBox.size.width/2; ) {
			LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water_1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND parent:_mapBatchNode];
			[waterTile setZOrder:0];
			[waterTile transformPosition:ccp(x,y)];
			y+= waterTile.boundingBox.size.height;
		}
		x+= waterTile.boundingBox.size.width;
	}
	[waterTile removeSelf];
		
	//TODO: load if we should show the tutorial from user prefs
	if(true) {
		[self showTutorial];
	}
	
}


-(void) generateFeatureMaps {

	//TODO: consider if we should "unStuck" all penguins/sharks whenever we regenerate the feature map

	NSLog(@"Generating feature maps...");

	CGSize winSize = [[CCDirector sharedDirector] winSize];

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
		int maxX = min(land.boundingBox.origin.x+land.boundingBox.size.width, winSize.width-1);
		int minY = max(land.boundingBox.origin.y, 0);
		int maxY = min(land.boundingBox.origin.y+land.boundingBox.size.height, winSize.height-1);
		
		//create the areas that both sharks and penguins can't go
		for(int x = minX; x < maxX; x++) {
			for(int y = minY; y < maxY; y++) {
				_sharkMapfeaturesGrid[(int)(x/_gridSize)][(int)(y/_gridSize)] = HARD_BORDER_WEIGHT;
				if(land.tag == BORDER) {
					_penguinMapfeaturesGrid[(int)(x/_gridSize)][(int)(y/_gridSize)] = HARD_BORDER_WEIGHT;
				}
			}
		}
			

		NSLog(@"Land from %d,%d to %d,%d", minX, minY, maxX, maxY);
	}


	//create a set of maps for each penguin
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	for(LHSprite* penguin in penguins) {

		//first create a copy of the feature map
		int** penguinMoveGrid = new int*[_gridWidth];
		for(int x = 0; x < _gridWidth; x++) {
			penguinMoveGrid[x] = new int[_gridHeight];
			for(int y = 0; y < _gridHeight; y++) {
				penguinMoveGrid[x][y] = _penguinMapfeaturesGrid[x][y];
			}
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
		for(int x = 0; x < _gridWidth; x++) {
			sharkMoveGrid[x] = new int[_gridHeight];
			for(int y = 0; y < _gridHeight; y++) {
				sharkMoveGrid[x][y] = _sharkMapfeaturesGrid[x][y];
			}
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
	
	_activeToolboxItem = toolboxItem;
			
	_activeToolboxItemOriginalPosition = _activeToolboxItem.position;
	[_activeToolboxItem transformScaleX: 1];
	[_activeToolboxItem transformScaleY: 1];
	NSLog(@"Scaling up toolboxitem %@ to full-size", _activeToolboxItem.uniqueName);
}

-(void)onTouchEndedToolboxItem:(LHTouchInfo*)info {
	
	if(_activeToolboxItem != nil) {
	
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		
		if((_state != RUNNING && _state != PLACE)
				|| (info.glPoint.y < _bottomBarContainer.boundingBox.size.height)
				|| (info.glPoint.y >= winSize.height)
				|| (info.glPoint.x <= 0)
				|| (info.glPoint.x >= winSize.width)
			) {
			//placed back into the HUD

			[_activeToolboxItem transformRotation:0];
			[_activeToolboxItem transformPosition:_activeToolboxItemOriginalPosition];
			double scale = fmin((_toolboxItemSize-TOOLBOX_ITEM_CONTAINER_PADDING_H)/_activeToolboxItem.contentSize.width, (_toolboxItemSize-TOOLBOX_ITEM_CONTAINER_PADDING_V)/_activeToolboxItem.contentSize.height);
			[_activeToolboxItem transformScale: scale];
			//NSLog(@"Scaled down toolbox item %@ to %d%% so it fits in the toolbox", _activeToolboxItem.uniqueName, (int)(100*scale));
			NSLog(@"Placing toolbox item back into the HUD");
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelName, @"Level_Name", 
				_levelPack, @"Level_Pack",
				_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
				_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
			nil];
			[Flurry logEvent:@"Undo_Place_Toolbox_Item" withParameters:flurryParams];		
			
			_activeToolboxItem = nil;
			
		}else {
			_moveActiveToolboxItemIntoWorld = true;
		}
	}
}












-(void)onTouchBeganPlayPause:(LHTouchInfo*)info {
	[_playPauseButton setFrame:_playPauseButton.currentFrame+1];	//active state
	__DEBUG_TOUCH_SECONDS = [[NSDate date] timeIntervalSince1970];	
}

-(void)onTouchEndedPlayPause:(LHTouchInfo*)info {
	
	if(_state == PLACE) {
		[self resume];
		[_playPauseButton setFrame:2];	//pause inactive
		
	}else if(_state == PAUSE) {
		[self resume];
		[_playPauseButton setFrame:2];	//pause inactive
		
	}else if(_state == RUNNING) {
		[self pause];
		[_playPauseButton setFrame:3];	//pause active
		[_playPauseButton setFrame:0];	//play inactive
	}

	__DEBUG_TOUCH_SECONDS = 0;
}

-(void)onTouchBeganRestart:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame+1];
}

-(void)onTouchEndedRestart:(LHTouchInfo*)info {
	[self restart];
}

-(void)onTouchBeganMainMenu:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame+1];
}

-(void)onTouchEndedMainMenu:(LHTouchInfo*)info {
	[self showMainMenuLayer];
}

-(void) pause {
	if(_state == RUNNING) {
		NSLog(@"Pausing game");
		_state = PAUSE;
		
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelName, @"Level_Name", 
			_levelPack, @"Level_Pack",
		nil];
		[Flurry logEvent:@"Pause_level" withParameters:flurryParams];		


		[self showInGameMenu];
	}
}

-(void) showInGameMenu {
	NSLog(@"Showing in-game menu");

	[_menuPopupContainer runAction:[CCMoveTo actionWithDuration:0.75f position:
								ccp(5*SCALING_FACTOR_H + _menuPopupContainer.boundingBox.size.width/2,
									_menuPopupContainer.boundingBox.size.height/2 - 5)]];
}

-(void) hideInGameMenu {
	[_menuPopupContainer runAction:[CCMoveTo actionWithDuration:0.75f position:
								ccp(5*SCALING_FACTOR_H + _menuPopupContainer.boundingBox.size.width/2,
									-_menuPopupContainer.boundingBox.size.height)]];
}

-(void) resume {
	if(_state == PAUSE) {
		NSLog(@"Resuming game");
		_state = RUNNING;
		
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelName, @"Level_Name", 
			_levelPack, @"Level_Pack",
		nil];
		[Flurry logEvent:@"Resume_level" withParameters:flurryParams];		

		[self hideInGameMenu];
			
	}else if(_state == PLACE) {
		NSLog(@"Starting game");
		_state = RUNNING;
		
		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelName, @"Level_Name", 
			_levelPack, @"Level_Pack",
		nil];
		[Flurry logEvent:@"Start_level" withParameters:flurryParams];

	}
	
}


//TODO: should all penguins need to make it to safety OR just have all sharks gone or all penguins safe
-(void) levelWon {

	if(_state == GAME_OVER) {
		return;
	}
	
	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Won", @"Level_Status",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];
	
	NSLog(@"Showing level won animations");
	//TODO: show some happy penguins (sharks offscreen)
	
	_state = GAME_OVER;

	//TODO: go to next level
	//[self goToNextLevel];
}

-(void) levelLostWithOffscreenPenguin:(LHSprite*)penguin {

	if(_state == GAME_OVER) {
		return;
	}

	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Offscreen Penguin", @"Level_Lost_Reason",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];

	NSLog(@"Showing level lost animations for offscreen penguin");
	
	_state = GAME_OVER;

	//a penguin ran offscreen!
	[penguin removeSelf];
	penguin = nil;

	//TODO: show some kind of information about how penguins have to reach the safety point
	
			
	//TODO: restart after animations are done
	//[self restart];	
}

-(void) levelLostWithShark:(LHSprite*)shark andPenguin:(LHSprite*)penguin {

	if(_state == GAME_OVER) {
		return;
	}

	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Shark Collision", @"Level_Lost_Reason",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];

	NSLog(@"Showing level lost animations for penguin/shark collision");
	
	_state = GAME_OVER;
	
	//a shark got a penguin!
	[penguin removeSelf];
	penguin = nil;

	//TODO: show some happy sharks and sad penguins (if any are left!)
	//eg. [shark startAnimationNamed:@"attackPenguin"];
	
	//TODO: restart after animations are done
	//[self restart];
}

-(void) restart {

	NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
		@"Lost", @"Level_Status",
		@"Restart", @"Level_Lost_Reason",
	nil];
	[Flurry endTimedEvent:@"Play_Level" withParameters:flurryParams];

	NSLog(@"Restarting");
	_state = GAME_OVER;
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer scene] ]];
}







-(void) goToNextLevel {
	//TODO: determine next level by examining JSON file
	NSLog(@"Going to next level");

}

-(void) showMainMenuLayer {
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1.0 scene:[MainMenuLayer scene] ]];
	
}

-(void) showTutorial {
	NSLog(@"Showing tutorial");
	_state = PAUSE;
	
	//TODO: show a tutorial
	
}




	



-(void) update: (ccTime) dt
{
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Update tick");
	if(_state != RUNNING && _state != PLACE) {
		return;
	}

	/* Things that can occur while placing toolbox items or while running */
	
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
	
		//StaticToolboxItem are things penguins and sharks can't move through
		if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Debris"]) {
			_activeToolboxItem.tag = DEBRIS;
			[_activeToolboxItem makeDynamic];
			[_activeToolboxItem setSensor:false];
			
		}else if([_activeToolboxItem.userInfoClassName isEqualToString:@"ToolboxItem_Border"]) {
			_activeToolboxItem.tag = BORDER;
			[_activeToolboxItem makeStatic];
			[_activeToolboxItem setSensor:false];
			_shouldRegenerateFeatureMaps = true;
			
		}
		
		//move it into the main layer so it's under the HUD
		if(_activeToolboxItem.parent == _toolboxBatchNode) {
			[_toolboxBatchNode removeChild:_activeToolboxItem cleanup:NO];
		}
		[_mainLayer addChild:_activeToolboxItem];


		NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
			_levelName, @"Level_Name", 
			_levelPack, @"Level_Pack",
			_activeToolboxItem.userInfoClassName, @"Toolbox_Item_Class",
			_activeToolboxItem.uniqueName, @"Toolbox_Item_Name",
			NSStringFromCGPoint(_activeToolboxItem.position), @"Location",
		nil];
		[Flurry logEvent:@"Place_Toolbox_Item" withParameters:flurryParams];				

	
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
				[background removeSelf];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelName, @"Level_Name", 
				_levelPack, @"Level_Pack",
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
				[background removeSelf];
			}
			
			NSDictionary* flurryParams = [NSDictionary dictionaryWithObjectsAndKeys:
				_levelName, @"Level_Name", 
				_levelPack, @"Level_Pack",
			nil];
			[Flurry logEvent:@"Debug_Penguins_Enabled" withParameters:flurryParams];		
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
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Moving %d sharks...", [sharks count]);
	
	if([sharks count] == 0) {
		//winna winna chicken dinna!
		[self levelWon];
		return;
	}	
		
	for(LHSprite* shark in sharks) {
		
		Shark* sharkData = ((Shark*)shark.userInfo);
		CGPoint sharkGridPos = [self toGrid:shark.position];
		LHSprite* targetPenguin = nil;

		if(sharkGridPos.x >= _gridWidth || sharkGridPos.x < 0 || sharkGridPos.y >= _gridHeight || sharkGridPos.y < 0) {
			NSLog(@"Shark %@ has moved offscreen to %f,%f - removing him", shark.uniqueName, sharkGridPos.x, sharkGridPos.y);
			[shark removeSelf];
			shark = nil;
			continue;
		}
		
		//find the nearest penguin
		for(LHSprite* penguin in penguins) {
			Penguin* penguinData = ((Penguin*)penguin.userInfo);
			if(penguinData.isSafe || penguinData.isStuck) {
				continue;
			}

			double minDistance = 100000000;
			if(sharkData.targetAcquired) {
				//any ol' penguin will do
				minDistance = 1000000;
			}else if(penguin.body->IsAwake()) {
				//we smell blood...
				minDistance = fmin(minDistance, sharkData.activeDetectionRadius * SCALING_FACTOR_GENERIC);
			}else {
				minDistance = fmin(minDistance, sharkData.restingDetectionRadius * SCALING_FACTOR_GENERIC);
			}		
			
			double dist = ccpDistance(shark.position, penguin.position);
			if(dist < minDistance) {
				minDistance = dist;
				targetPenguin = penguin;
				sharkData.targetAcquired = true;
			}
		}
		
		//TOOD: account for no penguin targeted
		CGPoint targetPenguinGridPos = [self toGrid:targetPenguin.position];
		
		//use the best route algorithm
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];
		[sharkMoveGridData updateMoveGridToTile:targetPenguinGridPos fromTile:sharkGridPos];
		CGPoint bestOptionPos = [sharkMoveGridData getBestMoveToTile:targetPenguinGridPos fromTile:sharkGridPos];
				
		if(bestOptionPos.x < 0 && bestOptionPos.y < 0) {
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
		
		double dSum = fabs(dx) + fabs(dy);
		if(dSum == 0) {
			//no best option?
			//NSLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
			dSum = 1;
		}

		double normalizedX = (sharkSpeed*dx)/dSum;
		double normalizedY = (sharkSpeed*dy)/dSum;
	

		b2Vec2 prevVel = shark.body->GetLinearVelocity();
		double targetVelX = dt * normalizedX;
		double targetVelY = dt * normalizedY;
		double weightedVelX = (prevVel.x * 9.0 + targetVelX)/10.0;
		double weightedVelY = (prevVel.y * 9.0 + targetVelY)/10.0;
		
		//we're using an impulse for the shark so they interact with things like Debris (physics)
		//shark.body->SetLinearVelocity(b2Vec2(weightedVelX,weightedVelY));
		shark.body->ApplyLinearImpulse(b2Vec2(targetVelX*.1,targetVelY*.1), shark.body->GetWorldCenter());
		
		//rotate shark
		double radians = atan2(weightedVelX, weightedVelY); //this grabs the radians for us
		double degrees = CC_RADIANS_TO_DEGREES(radians) - 90; //90 is because the sprit is facing right
		[shark transformRotation:degrees];
		
		//TODO: add a waddle animation
	}
	
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done moving %d sharks...", [sharks count]);
}

-(void) movePenguins:(ccTime)dt {

	//CGSize winSize = [[CCDirector sharedDirector] winSize];

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
		
		if(!penguinData.hasSpottedShark) {
			NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
			for(LHSprite* shark in sharks) {
				double dist = ccpDistance(shark.position, penguin.position);
				if(dist < penguinData.detectionRadius*SCALING_FACTOR_GENERIC) {
					penguinData.hasSpottedShark = true;
					//TODOO: play some kind of penguin animation with an alert dialog and a squawk sound
					break;
				}
			}
		}
		
		if(penguinData.hasSpottedShark) {
		
			//AHHH!!!
						
			//alert nearby penguins
			for(LHSprite* penguin2 in penguins) {
				if(![penguin2.uniqueName isEqualToString:penguin.uniqueName]) {
					if(ccpDistance(penguin.position, penguin2.position) <= penguinData.alertRadius*SCALING_FACTOR_GENERIC) {
						//TODO: show some kind of AH!!! speech bubble alert animation for the penguins communicating
						((Penguin*)penguin2.userInfo).hasSpottedShark = true;
					}
				}
			}


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

			//use the best route algorithm
			[penguinMoveGridData updateMoveGridToTile:targetLandGridPos fromTile:penguinGridPos];
			CGPoint bestOptionPos = [penguinMoveGridData getBestMoveToTile:targetLandGridPos fromTile:penguinGridPos];
					
			if(bestOptionPos.x < 0 && bestOptionPos.y < 0) {
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
				penguinSpeed*= 25;
				NSLog(@"Penguin %@ is stuck (trying to move but can't) - giving him a bit of jitter", penguin.uniqueName);
			}
			
			double dSum = fabs(dx) + fabs(dy);									
			if(dSum == 0) {
				//no best option?
				//NSLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
				dSum = 1;
			}

			double normalizedX = (penguinSpeed*dx)/dSum;
			double normalizedY = (penguinSpeed*dy)/dSum;
		
			double targetVelX = dt * normalizedX;
			double targetVelY = dt * normalizedY;
		
			//we're using an impulse for the penguin so they interact with things like Debris (physics)
			penguin.body->ApplyLinearImpulse(b2Vec2(targetVelX*.1,targetVelY*.1), penguin.body->GetWorldCenter());
			
			//TODO: add a waddle animation
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
			if(_activeToolboxItem && ccpDistance(location, _activeToolboxItem.position) > 50*SCALING_FACTOR_GENERIC) {
				//tapping a second finger on the screen when moving a toolbox item rotates the item
				[_activeToolboxItem transformRotation:((int)_activeToolboxItem.rotation+90)%360];
			}
		}
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
					ccDrawColor4B(0,0,(pv/max)*255,50);
					ccDrawPoint( ccp(x*_gridSize+_gridSize/2, y*_gridSize+_gridSize/2) );
				}
				if(__DEBUG_SHARKS && sharkMoveGrid != nil) {
					int sv = (sharkMoveGrid[x][y]);
					ccDrawColor4B((sv/max)*255,0,0,50);
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

-(void) dealloc
{
	NSLog(@"GameLayer dealloc");

	[self pause];
	[self unscheduleAllSelectors];
	[self unscheduleUpdate];

	/*
	for(LHSprite* sprite in [_levelLoader allSprites]) {
		[sprite removeTouchObserver];
	}
	*/
	
	[_sharkMoveGridDatas removeAllObjects];
	[_penguinMoveGridDatas removeAllObjects];
	free(_penguinMapfeaturesGrid);
	free(_sharkMapfeaturesGrid);
	
	[_levelLoader release];
	_levelLoader = nil;	
	
	delete _world;
	_world = NULL;
	
	if(DEBUG_ALL_THE_THINGS) {
		delete _debugDraw;
		_debugDraw = NULL;
	}
	
	[super dealloc];
}	

@end
