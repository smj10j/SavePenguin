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


#import "ToolSelectLayer.h"
#import "MoveGridData.h"

#pragma mark - GameLayer

@interface GameLayer()

//initialization
-(void) initPhysics;
-(void) loadLevel:(NSString*)levelName inLevelPack:(NSString*)levelPack;
-(void) drawHUD;

//turn-by-turn control
-(void) moveSharks:(ccTime)dt;
-(void) movePenguins:(ccTime)dt;

//different screens/layers/dialogs
-(void) showTutorial;
-(void) goToNextLevel;
-(void) showToolSelectLayer;

//game control
-(void) resume;
-(void) pause;
-(void) showInGameMenu;
-(void) restart;
-(void) levelLostWithShark:(LHSprite*)shark andPenguin:(LHSprite*)penguin;
-(void) levelWon;


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
		
		_isUpdatingSharkMovementGrids = false;
		_nextMovementGridSharkIndexToUpdate = 0;
		_shouldRegenerateFeatureMaps = false;
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = false;
		_penguinsToPutOnLand =[[NSMutableDictionary alloc] init];
		__DEBUG_SHARKS = DEBUG_SHARK;
		__DEBUG_PENGUINS = DEBUG_PENGUIN;
		if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {
			self.color = ccBLACK;
		}
		__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
		
		// init physics
		[self initPhysics];
		
		//TODO: store and load the level from prefs using JSON files for next/prev
		NSString* levelName = @"Introduction";
		NSString* levelPack = @"Beach";
		[self loadLevel:levelName inLevelPack:levelPack];
		
		//place the HUD items (pause, restart, etc.)
		[self drawHUD];		
		
		//set the grid size and create various arrays
		[self initializeMapGrid];
		
		//place the toolbox items
		[self updateToolbox];
		
		//various handlers
		[self setupCollisionHandling];
		
		//get some move grids goinz on
		[self schedule:@selector(updateSharkMoveGrids) interval:0.5f];

		//start the game
		_state = PLACE;
		CCDirectorIOS* director = (CCDirectorIOS*) [CCDirector sharedDirector];
		[director setAnimationInterval:1.0/TARGET_FPS];
		[self scheduleUpdate];
		
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
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
			
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

	_penguinMoveGrid = new int*[_gridWidth];
	_sharkMapfeaturesGrid = new int*[_gridWidth];
	_penguinMapfeaturesGrid = new int*[_gridWidth];
	for(int i = 0; i < _gridWidth; i++) {
		_penguinMoveGrid[i] = new int[_gridHeight];
		_sharkMapfeaturesGrid[i] = new int[_gridHeight];
		_penguinMapfeaturesGrid[i] = new int[_gridHeight];
		for(int j = 0; j < _gridHeight; j++) {
			_penguinMoveGrid[i][j] = 0;
			_sharkMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
			_penguinMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
		}
	}
	
	_penguinMoveGridDatas = [[NSMutableDictionary alloc] init];
	for(LHSprite* penguin in penguins) {
		[_penguinMoveGridDatas setObject:[[MoveGridData alloc] initWithGrid:nil height:0 width:0 moveHistorySize:PENGUIN_MOVE_HISTORY_SIZE tag:@"PENGUIN"] forKey:penguin.uniqueName];
	}
	
	//shark is filled in generateFeatureMaps
	_sharkMoveGridDatas = [[NSMutableDictionary alloc] init];
	
	[self generateFeatureMaps];
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

	//checks if the level has physics boundaries
	if([_levelLoader hasPhysicBoundaries])
	{
		//if it does, it will create the physic boundaries
		[_levelLoader createPhysicBoundaries:_world];
	}
		
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
			

		//NSLog(@"Land from %d,%d to %d,%d", minX, minY, maxX, maxY);
	}



	//create a static map detailing where penguins can move (ignoring shark data)
	for(int x = 0; x < _gridWidth; x++) {
		for(int y = 0; y < _gridHeight; y++) {
			_penguinMoveGrid[x][y] = _penguinMapfeaturesGrid[x][y];
		}
	}	
	for(LHSprite* land in lands) {
		_penguinMoveGrid[(int)land.position.x/_gridSize][(int)land.position.y/_gridSize] = 0;
		[self propagatePenguinGridCostToX:land.position.x/_gridSize y:land.position.y/_gridSize];
	}
	
	//create a set of maps for each shark
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	for(LHSprite* shark in sharks) {
		Shark* sharkData = ((Shark*)shark.userInfo);
		int sharkX = (int)shark.position.x/_gridSize;
		int sharkY = (int)shark.position.y/_gridSize;
		
		//first create a copy of the feature map
		int** sharkMoveGrid = new int*[_gridWidth];
		for(int x = 0; x < _gridWidth; x++) {
			sharkMoveGrid[x] = new int[_gridHeight];
			for(int y = 0; y < _gridHeight; y++) {
				sharkMoveGrid[x][y] = _sharkMapfeaturesGrid[x][y];
			}
		}

		//then add in the sharks endpoint data
		int x = (int)sharkData.endpointX/_gridSize;
		int y = (int)sharkData.endpointY/_gridSize;
		x = max(min(x, _gridWidth-1), 0);
		y = max(min(y, _gridHeight-1), 0);

		bool foundRoute = false;
		sharkMoveGrid[x][y] = INITIAL_ENDPOINT_GRID_WEIGHT;
		[self propagateSharkGridCostToX:x
									y:y
									onSharkMoveGrid:sharkMoveGrid
									withSharkPosition:ccp(sharkX,sharkY)
									withBranches:-1
									andWeightDelta:1
									foundRoute:&foundRoute];

		if(!foundRoute) {
			NSLog(@"ERROR!!! Oh no! Failed to create movegrid template for shark %@ to %d,%d because no route was found", shark.uniqueName, x, y);
		}else {
			NSLog(@"Successfully created movegrid template for shark %@ to %d,%d", shark.uniqueName, x, y);
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
		_state = RUNNING;
		[_playPauseButton setFrame:2];	//pause inactive
		
	}else if(_state == PAUSE) {
		[self resume];
		[_playPauseButton setFrame:2];	//pause inactive

	}else if(_state == RUNNING) {
		[self pause];
		[_playPauseButton setFrame:3];	//pause active
		[_playPauseButton setFrame:0];	//play inactive

	}

	//TODO: the in-game menu will actually resume and toggling will not be necessary

	
	double elapsed = ([[NSDate date] timeIntervalSince1970] - __DEBUG_TOUCH_SECONDS);
	if(elapsed < 2) {
		/*self.color = __DEBUG_ORIG_BACKGROUND_COLOR;
		__DEBUG_PENGUINS = DEBUG_PENGUIN;
		__DEBUG_SHARKS = DEBUG_SHARK;*/
	}else if(elapsed < 5) {
		NSLog(@"Enabling debug sharks");
		__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
		self.color = ccBLACK;
		__DEBUG_PENGUINS = false;
		__DEBUG_SHARKS = true;
	}else {
		NSLog(@"Enabling debug penguins");
		__DEBUG_ORIG_BACKGROUND_COLOR = self.color;
		self.color = ccBLACK;
		__DEBUG_PENGUINS = true;
		__DEBUG_SHARKS = false;
	}
}

-(void)onTouchBeganRestart:(LHTouchInfo*)info {
	[_restartButton setFrame:_restartButton.currentFrame+1];
}

-(void)onTouchEndedRestart:(LHTouchInfo*)info {
	[_restartButton setFrame:_restartButton.currentFrame-1];
	[self restart];
}

-(void) pause {
	if(_state == RUNNING) {
		NSLog(@"Pausing game");
		_state = PAUSE;
	}
	[self showInGameMenu];
}

-(void) showInGameMenu {
	NSLog(@"Showing in-game menu");
	//TODO: show an in-game menu
	// - show levels, go to main menu, resume
}

-(void) resume {
	if(_state == PAUSE) {
		NSLog(@"Resuming game");
		_state = RUNNING;
	}else if(_state == PLACE) {
		NSLog(@"Starting game");
		_state = RUNNING;
	}
}

-(void) levelWon {

	if(_state == GAME_OVER) {
		return;
	}
	
	NSLog(@"Showing level won animations");
	//TODO: show some happy penguins (sharks offscreen)
	
	_state = GAME_OVER;

	//TODO: go to next level
	//[self goToNextLevel];
}

-(void) levelLostWithShark:(LHSprite*)shark andPenguin:(LHSprite*)penguin {

	if(_state == GAME_OVER) {
		return;
	}

	NSLog(@"Showing level lost animations");
	
	_state = GAME_OVER;
	
	
	if(shark != nil) {
		//a shark got a penguin!
		[penguin removeSelf];
		penguin = nil;

		//TODO: show some happy sharks and sad penguins (if any are left!)
		//eg. [shark startAnimationNamed:@"attackPenguin"];
		
	}else {
		//penguin must have drowned or gone of screen!
		//TODO: show a drowning penguin animation... what to do for offscreen?
	}
	
	//TODO: restart after animations are done
	//[self restart];
}

-(void) restart {
	NSLog(@"Restarting");
	_state = GAME_OVER;
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer scene] ]];
}







-(void) goToNextLevel {
	//TODO: determine next level by examining JSON file
	NSLog(@"Going to next level");

}

-(void) showToolSelectLayer {
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1.0 scene:[ToolSelectLayer scene] ]];
	
}

-(void) showTutorial {
	NSLog(@"Showing tutorial");
	_state = PAUSE;
	
	//TODO: show a tutorial
	
	[self showToolSelectLayer];
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

	
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		_shouldUpdateToolbox = true;
		for(id key in _sharkMoveGridDatas) {
			[[_sharkMoveGridDatas objectForKey:key] forceLatestGridUpdate];
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

-(void) propagateSharkGridCostToX:(int)x y:(int)y onSharkMoveGrid:(int**)sharkMoveGrid withSharkPosition:(CGPoint)sharkPos withBranches:(int)branches andWeightDelta:(int)weightDelta foundRoute:(bool*)foundRoute{

	if(x < 0 || x >= _gridWidth) {
		return;
	}
	if(y < 0 || y >= _gridHeight) {
		return;
	}

	if(sharkPos.x >= 0 && sharkPos.y >= 0 && sharkPos.x == x && sharkPos.y == y) {
		//find the fastest route - not necessarily the best
		if(foundRoute != nil) {
			*foundRoute = true;
		}
	}

	if(branches == 0) {
		//note that starting with a -1 will allow unlimited branching
		return;
	}
	
	double w = sharkMoveGrid[x][y];
	if(weightDelta > 0 && w > _gridWidth*3) {
		//this is an approximation to increase speed - it can cause failures to find any path at all (very complex ones)
		return;
	}
	double wN = y+1 >= _gridHeight ? -10000 : sharkMoveGrid[x][y+1];
	double wS = y-1 < 0 ? -10000 : sharkMoveGrid[x][y-1];
	double wE = x+1 >= _gridWidth ? -10000 : sharkMoveGrid[x+1][y];
	double wW = x-1 < 0 ? -10000 : sharkMoveGrid[x-1][y];

	/*if(w != 0 && w != 1) {
		NSLog(@"%d,%d = %f", x, y, w);
	}*/

	
	bool changedN = false;
	bool changedS = false;
	bool changedE = false;
	bool changedW = false;
	

	if(y < _gridHeight-1 && _sharkMapfeaturesGrid[x][y+1] < HARD_BORDER_WEIGHT && (wN == _sharkMapfeaturesGrid[x][y+1] || wN > w+weightDelta)) {
		sharkMoveGrid[x][y+1] = w+weightDelta + (_sharkMapfeaturesGrid[x][y+1] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x][y+1]);
		changedN = true;
	}
	if(y > 0 && _sharkMapfeaturesGrid[x][y-1] < HARD_BORDER_WEIGHT && (wS == _sharkMapfeaturesGrid[x][y-1] || wS > w+weightDelta)) {
		sharkMoveGrid[x][y-1] = w+weightDelta  + (_sharkMapfeaturesGrid[x][y-1] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x][y-1]);
		changedS = true;
	}
	if(x < _gridWidth-1 && _sharkMapfeaturesGrid[x+1][y] < HARD_BORDER_WEIGHT && (wE == _sharkMapfeaturesGrid[x+1][y] || wE > w+weightDelta)) {
		sharkMoveGrid[x+1][y] = w+weightDelta + (_sharkMapfeaturesGrid[x+1][y] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x+1][y]);
		changedE = true;
	}
	if(x > 0 && _sharkMapfeaturesGrid[x-1][y] < HARD_BORDER_WEIGHT && (wW == _sharkMapfeaturesGrid[x-1][y] || wW > w+weightDelta)) {
		sharkMoveGrid[x-1][y] = w+weightDelta  + (_sharkMapfeaturesGrid[x-1][y] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x-1][y]);
		changedW = true;
	}
	
	if(changedN) {
		[self propagateSharkGridCostToX:x y:y+1 onSharkMoveGrid:sharkMoveGrid withSharkPosition:sharkPos withBranches:branches-1 andWeightDelta:(weightDelta > 0 ? weightDelta : weightDelta-1) foundRoute:foundRoute];
	}
	if(changedS) {
		[self propagateSharkGridCostToX:x y:y-1 onSharkMoveGrid:sharkMoveGrid withSharkPosition:sharkPos withBranches:branches-1 andWeightDelta:(weightDelta > 0 ? weightDelta : weightDelta-1) foundRoute:foundRoute];
	}
	if(changedE) {
		[self propagateSharkGridCostToX:x+1 y:y onSharkMoveGrid:sharkMoveGrid withSharkPosition:sharkPos withBranches:branches-1 andWeightDelta:(weightDelta > 0 ? weightDelta : weightDelta-1) foundRoute:foundRoute];
	}
	if(changedW) {
		[self propagateSharkGridCostToX:x-1 y:y onSharkMoveGrid:sharkMoveGrid withSharkPosition:sharkPos withBranches:branches-1 andWeightDelta:(weightDelta > 0 ? weightDelta : weightDelta-1) foundRoute:foundRoute];
	}
	
}

-(void) propagatePenguinGridCostToX:(int)x y:(int)y {
	
	if(x < 0 || x >= _gridWidth) {
		return;
	}
	if(y < 0 || y >= _gridHeight) {
		return;
	}

	
	double w = _penguinMoveGrid[x][y];
	double wN = y+1 >= _gridHeight ? -10000 : _penguinMoveGrid[x][y+1];
	double wS = y-1 < 0 ? -10000 : _penguinMoveGrid[x][y-1];
	double wE = x+1 >= _gridWidth ? -10000 : _penguinMoveGrid[x+1][y];
	double wW = x-1 < 0 ? -10000 : _penguinMoveGrid[x-1][y];

	if(w != 0 && w != 1) {
		//NSLog(@"%d,%d = %f", x, y, w);
	}
	
	bool changedN = false;
	bool changedS = false;
	bool changedE = false;
	bool changedW = false;
	

	if(y < _gridHeight-1 && _penguinMapfeaturesGrid[x][y+1] < HARD_BORDER_WEIGHT && (wN == _penguinMapfeaturesGrid[x][y+1] || wN > w+1)) {
		_penguinMoveGrid[x][y+1] = w+1 + (_penguinMapfeaturesGrid[x][y+1] == INITIAL_GRID_WEIGHT ? 0 : _penguinMapfeaturesGrid[x][y+1]);
		changedN = true;
	}
	if(y > 0 && _penguinMapfeaturesGrid[x][y-1] < HARD_BORDER_WEIGHT && (wS == _penguinMapfeaturesGrid[x][y-1] || wS > w+1)) {
		_penguinMoveGrid[x][y-1] = w+1  + (_penguinMapfeaturesGrid[x][y-1] == INITIAL_GRID_WEIGHT ? 0 : _penguinMapfeaturesGrid[x][y-1]);
		changedS = true;
	}
	if(x < _gridWidth-1 && _penguinMapfeaturesGrid[x+1][y] < HARD_BORDER_WEIGHT && (wE == _penguinMapfeaturesGrid[x+1][y] || wE > w+1)) {
		_penguinMoveGrid[x+1][y] = w+1 + (_penguinMapfeaturesGrid[x+1][y] == INITIAL_GRID_WEIGHT ? 0 : _penguinMapfeaturesGrid[x+1][y]);
		changedE = true;
	}
	if(x > 0 && _penguinMapfeaturesGrid[x-1][y] < HARD_BORDER_WEIGHT && (wW == _penguinMapfeaturesGrid[x-1][y] || wW > w+1)) {
		_penguinMoveGrid[x-1][y] = w+1  + (_penguinMapfeaturesGrid[x-1][y] == INITIAL_GRID_WEIGHT ? 0 : _penguinMapfeaturesGrid[x-1][y]);
		changedW = true;
	}
	
	if(changedN) {
		[self propagatePenguinGridCostToX:x y:y+1];
	}
	if(changedS) {
		[self propagatePenguinGridCostToX:x y:y-1];
	}
	if(changedE) {
		[self propagatePenguinGridCostToX:x+1 y:y];
	}
	if(changedW) {
		[self propagatePenguinGridCostToX:x-1 y:y];
	}
	
}

-(void) updateSharkMoveGrids {
	
	if(_isUpdatingSharkMovementGrids || (_state != RUNNING && _state != PLACE)) {
		return;
	}
	_isUpdatingSharkMovementGrids = true;
	
	//can set this to stop updating for this iteration
	__block bool continueUpdatingSharkMoveGrids = true;
	
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Updating %d sharks movement grids...", [sharks count]);
		
	int sharkIndex = 0;
	for(LHSprite* shark in sharks) {
	
		if(sharkIndex++ < _nextMovementGridSharkIndexToUpdate) {
			continue;
		}
		
		if(!continueUpdatingSharkMoveGrids) break;
		
		Shark* sharkData = ((Shark*)shark.userInfo);
		double minDistance = 10000000;
		int sharkX = (int)shark.position.x/_gridSize;
		int sharkY = (int)shark.position.y/_gridSize;
		LHSprite* targetPenguin = nil;
		
		if(sharkX >= _gridWidth || sharkX < 0 || sharkY >= _gridHeight || sharkY < 0) {
			//will be handled in moveSharks()
			continue;
		}

		
		//find the nearest penguin
		for(LHSprite* penguin in penguins) {
			Penguin* penguinData = ((Penguin*)penguin.userInfo);
			if(penguinData.isSafe || penguinData.isStuck) {
				continue;
			}

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
		
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];
					
		if(targetPenguin != nil) {

			//NSLog(@"Closest penguin %@: %f", targetPenguin.uniqueName, minDistance);
		
			int x = (int)targetPenguin.position.x/_gridSize;
			int y = (int)targetPenguin.position.y/_gridSize;
			x = max(min(x, _gridWidth-1), 0);
			y = max(min(y, _gridHeight-1), 0);
			CGPoint tile = {x,y};

			[sharkMoveGridData gridToTile:tile withPropagationCallback:^(int** aGrid, CGPoint tile) {
				
				NSLog(@"Shark %@ propagating full grid update to penguin %@ at %f,%f", shark.uniqueName, targetPenguin.uniqueName, tile.x, tile.y);

				aGrid[(int)tile.x][(int)tile.y] = 0;
				bool foundRoute = false;
				[self propagateSharkGridCostToX:tile.x
											y:tile.y
											onSharkMoveGrid:aGrid
											withSharkPosition:ccp(sharkX, sharkY)
											withBranches:-1
											andWeightDelta:1
											foundRoute:&foundRoute];

				//let's only update one shark per iteration
				continueUpdatingSharkMoveGrids = false;
			}];
		
		}
		_nextMovementGridSharkIndexToUpdate = (_nextMovementGridSharkIndexToUpdate+1)%[sharks count];
	}
	
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done updating %d sharks movement grids...", [sharks count]);
	_isUpdatingSharkMovementGrids = false;
}

//TODO: eventually, make the penguins also use the MoveGridData

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
		int sharkX = (int)shark.position.x/_gridSize;
		int sharkY = (int)shark.position.y/_gridSize;
		CGPoint bestOptionPos;
		
		if(sharkX >= _gridWidth || sharkX < 0 || sharkY >= _gridHeight || sharkY < 0) {
			NSLog(@"Shark %@ has moved offscreen to %d,%d - removing him", shark.uniqueName, sharkX, sharkY);
			[shark removeSelf];
			shark = nil;
			continue;
		}
		
		
		//use the best route algorithm
		MoveGridData* sharkMoveGridData = (MoveGridData*)[_sharkMoveGridDatas objectForKey:shark.uniqueName];
		_sharkMoveGrid = sharkMoveGridData.latestGrid;
		
		_sharkMoveGrid[sharkX][sharkY]++;	//burn that bridge, baby!
		
		double wN = _sharkMoveGrid[sharkX][sharkY+1 >= _gridHeight ? sharkY : sharkY+1];
		double wS = _sharkMoveGrid[sharkX][sharkY-1 < 0 ? sharkY : sharkY-1];
		double wE = _sharkMoveGrid[sharkX+1 >= _gridWidth ? sharkX : sharkX+1][sharkY];
		double wW = _sharkMoveGrid[sharkX-1 < 0 ? sharkX : sharkX-1][sharkY];
	
	
		//NSLog(@"w=%f e=%f n=%f s=%f", wW, wE, wN, wS);
	
		if(wW == wE && wE == wN && wN == wS) {
		
			double w = _sharkMoveGrid[sharkX][sharkY];
			if(wW == w && w == INITIAL_GRID_WEIGHT) {
				sharkData.isStuck = true;
				if(SHARK_DIES_WHEN_STUCK) {
					//we're stuck
					NSLog(@"Shark %@ is stuck (no where to go) - we're removing him", shark.uniqueName);
					//TODO: make the shark spin around in circles and explode in frustration!
					[shark removeSelf];
				}else {
					NSLog(@"Shark %@ is stuck (no where to go) - we're ignoring him", shark.uniqueName);
					//TODO: do a confused/arms up in air animation
				}
				continue;
			}
		
			//TODO: some kind of random determination?
			bestOptionPos = ccp(shark.position.x+((arc4random()%10)-5)/10.0,shark.position.y+((arc4random()%10)-5)/10.0);
		
		}else {
			double vE = 0;
			double vN = 0;
			
			//situation: West and East are equal and North and South are equal - we'll get stuck forever
			if(wE == wW && wN != wS) {
				if(arc4random()%100 < 50) {
					wE++;
				}else {
					wW++;
				}
			}else if(wN == wS && wE != wW) {
				if(arc4random()%100 < 50) {
					wN++;
				}else {
					wS++;
				}
			}
			
			double absWE = fabs(wE);
			double absWW = fabs(wW);
			double absWS = fabs(wS);
			double absWN = fabs(wN);
			double absMin = fmin(fmin(fmin(absWE,absWW),absWN),absWS);
			if(absWE == absMin) {
				vE = (wW-wE)/(wW==0?1:wW);
			}else if(absWW == absMin) {
				vE = (wW-wE)/(wE==0?1:wE);
			}
			
			if(absWN == absMin) {
				vN = (wS-wN)/(wS==0?1:wS);
			}else if(absWS == absMin) {
				vN = (wS-wN)/(wN==0?1:wN);
			}
		
			bestOptionPos = ccp(
				shark.position.x+vE,
				shark.position.y+vN
			);
			
			/*bestOptionPos = ccp(shark.position.x + (fabs(wE) > fabs(wW) ? wE : wW),
								shark.position.y + (fabs(wN) > fabs(wS) ? wN : wS)
							);*/
			//NSLog(@"best: %f,%f", bestOptionPos.x,bestOptionPos.y);
		}
				
		double dx = bestOptionPos.x - shark.position.x;
		double dy = bestOptionPos.y - shark.position.y;
		double dSum = fabs(dx) + fabs(dy);
								
		if(dSum == 0) {
			//no best option?
			//NSLog(@"No best option for shark %@ max(dx,dy) was 0", shark.uniqueName);
			dSum = 1;
		}

		double sharkSpeed = sharkData.restingSpeed;
		if(sharkData.targetAcquired) {
			sharkSpeed = sharkData.activeSpeed;
		}
		double normalizedX = (sharkSpeed*dx)/dSum;
		double normalizedY = (sharkSpeed*dy)/dSum;
	
		[sharkMoveGridData logMove:bestOptionPos];
		
		if([sharkMoveGridData distanceTraveledStraightline] < 1*SCALING_FACTOR_GENERIC) {
			sharkData.isStuck = true;
			if(SHARK_DIES_WHEN_STUCK) {
				//we're stuck
				NSLog(@"Shark %@ is stuck (trying to move, but not making progress) - we're removing him", shark.uniqueName);
				//TODO: make the shark spin around in circles and explode in frustration!
				[shark removeSelf];
			}else {
				NSLog(@"Shark %@ is stuck (trying to move, but not making progress) - we're ignoring him", shark.uniqueName);
				//TODO: do a confused/arms up in air animation
			}
		}
	

		b2Vec2 prevVel = shark.body->GetLinearVelocity();
		double targetVelX = dt * normalizedX;
		double targetVelY = dt * normalizedY;
		double weightedVelX = (prevVel.x * 4.0 + targetVelX)/5.0;
		double weightedVelY = (prevVel.y * 4.0 + targetVelY)/5.0;
		
		//we're using an impulse for the shark so they interact with things like Debris (physics)
		//shark.body->SetLinearVelocity(b2Vec2(weightedVelX,weightedVelY));
		shark.body->ApplyLinearImpulse(b2Vec2(targetVelX*.1,targetVelY*.1), shark.body->GetWorldCenter());
		
		//rotate shark
		double radians = atan2(weightedVelX, weightedVelY); //this grabs the radians for us
		double degrees = CC_RADIANS_TO_DEGREES(radians) - 90; //90 is because the sprit is facing right
		[shark transformRotation:degrees];
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
		
		int penguinX = (int)penguin.position.x/_gridSize;
		int penguinY = (int)penguin.position.y/_gridSize;
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
		MoveGridData* penguinMoveGridData = (MoveGridData*)[_penguinMoveGridDatas objectForKey:penguin.uniqueName];
		
		if(penguinData.isSafe || penguinData.isStuck) {
			continue;
		}
		
		if(penguinX >= _gridWidth || penguinX < 0 || penguinY >= _gridHeight || penguinY < 0) {
			NSLog(@"Penguin %@ is offscreen at %d,%d - showing level lost", penguin.uniqueName, penguinX, penguinY);
			[self levelLostWithShark:nil andPenguin:penguin];
			return;
		}
		
		
		//TODO: enable this if each penguin has its own grid... otherwise we're contaminating the best path
		//_penguinMoveGrid[penguinX][penguinY]++;	//burn that bridge, baby!

		
		
		if(!penguinData.hasSpottedShark) {
			NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
			for(LHSprite* shark in sharks) {
				double dist = ccpDistance(shark.position, penguin.position);
				if(dist < penguinData.detectionRadius*SCALING_FACTOR_GENERIC) {
					penguinData.hasSpottedShark = true;
					break;
				}
			}
		}
		
		if(penguinData.hasSpottedShark) {
		
			//AHHH!!!
			CGPoint bestOptionPos;
			CGPoint bestOptionGridPos;
			
			//alert nearby penguins
			for(LHSprite* penguin2 in penguins) {
				if(![penguin2.uniqueName isEqualToString:penguin.uniqueName]) {
					if(ccpDistance(penguin.position, penguin2.position) <= penguinData.alertRadius*SCALING_FACTOR_GENERIC) {
						//TODO: show some kind of AH!!! speech bubble alert animation for the penguins communicating
						((Penguin*)penguin2.userInfo).hasSpottedShark = true;
					}
				}
			}

			//use the best route algorithm
			double wN = _penguinMoveGrid[penguinX][penguinY+1 >= _gridHeight-1 ? penguinY : penguinY+1];
			double wS = _penguinMoveGrid[penguinX][penguinY-1 < 0 ? penguinY : penguinY-1];
			double wE = _penguinMoveGrid[penguinX+1 >= _gridWidth-1 ? penguinX : penguinX+1][penguinY];
			double wW = _penguinMoveGrid[penguinX-1 < 0 ? penguinX : penguinX-1][penguinY];
		
		
			//NSLog(@"Penguins %@ direction weights: w=%f e=%f n=%f s=%f", penguin.uniqueName, wW, wE, wN, wS);
		
			if(wW == wE && wE == wN && wN == wS) {
			
				double w = _penguinMoveGrid[penguinX][penguinY];
				if(w == wW && w == INITIAL_GRID_WEIGHT) {
					NSLog(@"Penguin %@ is stuck (nowhere to go)!", penguin.uniqueName);
					penguinData.isStuck = true;
					//TODO: show a confused expression. possibly raising wings into the air in a "oh well" gesture
					
					//halt!
					penguin.body->SetLinearVelocity(b2Vec2(0,0));
					penguin.body->SetAngularVelocity(0);
					
					continue;
				}
			
				//TODO: some kind of random determination?
				bestOptionPos = ccp(penguin.position.x+((arc4random()%2)-1),penguin.position.y+((arc4random()%2)-1));
				bestOptionGridPos = ccp(bestOptionPos.x/_gridSize, bestOptionPos.y/_gridSize);
				
			}else {
				
				double vE = 0;
				double vN = 0;

				//situation: West and East are equal and North and South are equal - we'll get stuck forever
				if(wE == wW && wN != wS) {
					if(arc4random()%100 < 50) {
						wE++;
					}else {
						wW++;
					}
				}else if(wN == wS && wE != wW) {
					if(arc4random()%100 < 50) {
						wN++;
					}else {
						wS++;
					}
				}
					
				double absWE = fabs(wE);
				double absWW = fabs(wW);
				double absWS = fabs(wS);
				double absWN = fabs(wN);
				double absMin = fmin(fmin(fmin(absWE,absWW),absWN),absWS);
				if(absWE == absMin) {
					vE = (wW-wE)/(wW==0?1:wW);
				}else if(absWW == absMin) {
					vE = (wW-wE)/(wE==0?1:wE);
				}
				
				if(absWN == absMin) {
					vN = (wS-wN)/(wS==0?1:wS);
				}else if(absWS == absMin) {
					vN = (wS-wN)/(wN==0?1:wN);
				}
							
				//pixel level
				bestOptionPos = ccp(
					penguin.position.x+vE,
					penguin.position.y+vN
				);
				
				//a full step in the grid direction
				bestOptionGridPos = ccp(
						(penguinX + (vE > 0 ? 1 : vE < 0 ? -1 : 0)),
						(penguinY + (vN > 0 ? 1 : vN < 0 ? -1 : 0))
				);

				//NSLog(@"Penguin %@ best position: %f,%f", penguin.uniqueName, bestOptionPos.x,bestOptionPos.y);
			}
					
			double dx = bestOptionPos.x - penguin.position.x;
			double dy = bestOptionPos.y - penguin.position.y;
			double penguinSpeed = penguinData.speed;

			[penguinMoveGridData logMove:bestOptionPos];
			if([penguinMoveGridData distanceTraveledStraightline] < 2*SCALING_FACTOR_GENERIC) {
				//we're stuck... but we'll let sharks report us as being stuck.
				//we'll just try and get ourselves out of this sticky situation
				
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
		}
	}

	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done moving %d penguins...", [penguins count]);

}

//TODO: make all assets sized for HD iPad!

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

		if(DEBUG_ALL_THE_THINGS || DEBUG_PENGUIN || DEBUG_SHARK ) {
			if(_sharkMoveGrid != nil) NSLog(@"_sharkMoveGrid[%d][%d] = %d", (int)location.x, (int)location.y, _sharkMoveGrid[(int)location.x/_gridSize][(int)location.y/_gridSize]);
			if(_sharkMapfeaturesGrid != nil) NSLog(@"_sharkMapfeaturesGrid[%d][%d] = %d", (int)location.x, (int)location.y, _sharkMapfeaturesGrid[(int)location.x/_gridSize][(int)location.y/_gridSize]);
			if(_penguinMoveGrid != nil)NSLog(@"_penguinMoveGrid[%d][%d] = %d", (int)location.x, (int)location.y, _penguinMoveGrid[(int)location.x/_gridSize][(int)location.y/_gridSize]);
			if(_penguinMapfeaturesGrid != nil)NSLog(@"_penguinMapfeaturesGrid[%d][%d] = %d", (int)location.x, (int)location.y, _penguinMapfeaturesGrid[(int)location.x/_gridSize][(int)location.y/_gridSize]);
		}
	}
}








-(void) drawDebugMovementGrid {
		
	if(__DEBUG_SHARKS || __DEBUG_PENGUINS) {
	
		double max = _gridWidth*4;
		ccPointSize(_gridSize-1);
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				if(__DEBUG_PENGUINS && _penguinMoveGrid != nil) {
					int pv = (_penguinMoveGrid[x][y]);
					ccDrawColor4B(0,0,(pv/max)*255,50);
					ccDrawPoint( ccp(x*_gridSize+_gridSize/2, y*_gridSize+_gridSize/2) );
				}
				if(__DEBUG_SHARKS && _sharkMoveGrid != nil) {
					int sv = (_sharkMoveGrid[x][y]);
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
	[self pause];
	[self unscheduleAllSelectors];
	[self unscheduleUpdate];

	[_sharkMoveGridDatas removeAllObjects];
	[_penguinMoveGridDatas removeAllObjects];
	free(_penguinMoveGrid);
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
