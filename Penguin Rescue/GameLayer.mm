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
#import "SharkMoveGridData.h"

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
	if( (self=[super init])) {
		
		CGSize winSize = [[CCDirector sharedDirector] winSize];

		// enable events
		self.isTouchEnabled = YES;
		
		//sharks start in N seconds
		_gameStartCountdownTimer = SHARKS_COUNTDOWN_TIMER_INITIAL;
		
		_gridWidth = winSize.width/GRID_SIZE + 1;
		_gridHeight = winSize.height/GRID_SIZE + 1;
		_sharkMoveGrids = [[NSMutableDictionary alloc] init];
		_sharkMoveGrid = new int*[_gridWidth];
		_penguinMoveGrid = new int*[_gridWidth];
		_sharkMapfeaturesGrid = new int*[_gridWidth];
		_penguinMapfeaturesGrid = new int*[_gridWidth];
		for(int i = 0; i < _gridWidth; i++) {
			_penguinMoveGrid[i] = new int[_gridHeight];
			_sharkMoveGrid[i] = new int[_gridHeight];
			_sharkMapfeaturesGrid[i] = new int[_gridHeight];
			_penguinMapfeaturesGrid[i] = new int[_gridHeight];
			for(int j = 0; j < _gridHeight; j++) {
				_penguinMoveGrid[i][j] = 0;
				_sharkMoveGrid[i][j] = 0;
				_sharkMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
				_penguinMapfeaturesGrid[i][j] = INITIAL_GRID_WEIGHT;
			}
		}
		
		_shouldRegenerateFeatureMaps = true;
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
		
		_penguinsToPutOnLand =[[NSMutableDictionary alloc] init];
		
		// init physics
		[self initPhysics];
		
		//TODO: store and load the level from prefs using JSON files for next/prev
		NSString* levelName = @"Introduction";
		NSString* levelPack = @"Beach";
		[self loadLevel:levelName inLevelPack:levelPack];
		
		//place the HUD items (pause, restart, etc.)
		[self drawHUD];

		//place the toolbox items
		[self drawToolbox];
		
		//various handlers
		[self setupCollisionHandling];
		
		
		//start the game
		_state = RUNNING;
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



-(void) setupCollisionHandling
{
    [_levelLoader useLevelHelperCollisionHandling];
	[_levelLoader registerBeginOrEndCollisionCallbackBetweenTagA:LAND andTagB:PENGUIN idListener:self selListener:@selector(landPenguinCollision:)];
    [_levelLoader registerBeginOrEndCollisionCallbackBetweenTagA:SHARK andTagB:PENGUIN idListener:self selListener:@selector(sharkPenguinCollision:)];
}

-(void) drawHUD {
	NSLog(@"Drawing HUD");

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	_pauseButton = [_levelLoader createSpriteWithName:@"Pause_inactive" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:self];
	[_pauseButton prepareAnimationNamed:@"Pause_hover" fromSHScene:@"Spritesheet"];
	[_pauseButton transformPosition: ccp(_pauseButton.contentSize.width/2+30*SCALING_FACTOR,_pauseButton.contentSize.height/2+20*SCALING_FACTOR)];
	[_pauseButton registerTouchBeganObserver:self selector:@selector(onTouchBeganPause:)];
	[_pauseButton registerTouchEndedObserver:self selector:@selector(onTouchEndedPause:)];
	
	
	_restartButton = [_levelLoader createSpriteWithName:@"Restart_inactive" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:self];
	[_restartButton prepareAnimationNamed:@"Restart_hover" fromSHScene:@"Spritesheet"];
	[_restartButton transformPosition: ccp(winSize.width - (_restartButton.contentSize.width/2+30*SCALING_FACTOR),_restartButton.contentSize.height/2+20*SCALING_FACTOR) ];
	[_restartButton registerTouchBeganObserver:self selector:@selector(onTouchBeganRestart:)];
	[_restartButton registerTouchEndedObserver:self selector:@selector(onTouchEndedRestart:)];
}

-(void) drawToolbox {
	NSLog(@"Drawing Toolbox");

	//TODO: load the available tools from the JSON level file and stack them on top of eachother. they should include the TAG and any other info needed at creation
	
	//TODO: draw a pretty box around the tools

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	NSArray* toolboxItems = [_levelLoader spritesWithTag:TOOLBOX_ITEM];
	for(LHSprite* toolboxItem in toolboxItems) {
		[toolboxItem registerTouchBeganObserver:self selector:@selector(onTouchBeganToolboxItem:)];
		[toolboxItem registerTouchEndedObserver:self selector:@selector(onTouchEndedToolboxItem:)];
	}
	

}


-(void) loadLevel:(NSString*)levelName inLevelPack:(NSString*)levelPack {
		
	//create a LevelHelperLoader object that has the data of the specified level
	if(_levelLoader != nil) {
		[_levelLoader release];
	}
	_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", levelPack, levelName]];

	//create all objects from the level file and adds them to the cocos2d layer (self)
	[_levelLoader addObjectsToWorld:_world cocos2dLayer:self];

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

	NSLog(@"Generating feature maps...");

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	//fresh start
	for(int x = 0; x < _gridWidth; x++) {
		for(int y = 0; y < _gridHeight; y++) {
			_sharkMapfeaturesGrid[x][y] = 0;
			_penguinMapfeaturesGrid[x][y] = 0;
		}
	}

	//fill in the feature grid detailing map movement info
	NSArray* lands = [_levelLoader spritesWithTag:LAND];
	NSArray* borders = [_levelLoader spritesWithTag:BORDER];
	
	NSMutableArray* unpassableAreas = [NSMutableArray arrayWithArray:lands];
	[unpassableAreas addObjectsFromArray:borders];
	
	NSLog(@"Num safe lands: %d, Num borders: %d", [lands count], [borders count]);
	
	for(LHSprite* land in unpassableAreas) {

		int minX = max(land.position.x, 0);
		int maxX = min(land.position.x+land.contentSize.width, winSize.width-1);
		int minY = max(land.position.y, 0);
		int maxY = min(land.position.y+land.contentSize.height, winSize.height-1);
		
		//create the areas that both sharks and penguins can't go
		for(int x = minX; x < maxX; x++) {
			for(int y = minY; y < maxY; y++) {
				_sharkMapfeaturesGrid[x/GRID_SIZE][y/GRID_SIZE] = HARD_BORDER_WEIGHT;
				if(land.tag == BORDER) {
					_penguinMapfeaturesGrid[x/GRID_SIZE][y/GRID_SIZE] = HARD_BORDER_WEIGHT;
				}
			}
		}
			

		/*NSLog(@"Land from %f,%f to %f,%f",
			land.position.x-land.contentSize.width/2, land.position.y-land.contentSize.height/2,
			land.position.x+land.contentSize.width/2, land.position.y+land.contentSize.height/2);*/
	}



	//create a static map detailing where penguins can move (ignoring shark data)
	for(int x = 0; x < _gridWidth; x++) {
		for(int y = 0; y < _gridHeight; y++) {
			_penguinMoveGrid[x][y] = _penguinMapfeaturesGrid[x][y];
		}
	}	
	for(LHSprite* land in lands) {
		_penguinMoveGrid[(int)land.position.x/GRID_SIZE][(int)land.position.y/GRID_SIZE] = 0;
		[self propagatePenguinGridCostToX:land.position.x/GRID_SIZE y:land.position.y/GRID_SIZE];
	}
	
	
	[_sharkMoveGrids removeAllObjects];
	
	//create a set of maps for each shark
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	for(LHSprite* shark in sharks) {
		Shark* sharkData = ((Shark*)shark.userInfo);
		
		//first create a copy of the feature map
		int** sharkMoveGrid = new int*[_gridWidth];
		for(int x = 0; x < _gridWidth; x++) {
			sharkMoveGrid[x] = new int[_gridHeight];
			for(int y = 0; y < _gridHeight; y++) {
				sharkMoveGrid[x][y] = _sharkMapfeaturesGrid[x][y];
			}
		}

		//then add in the sharks endpoint data
		int x = (int)sharkData.endpointX/GRID_SIZE;
		int y = (int)sharkData.endpointY/GRID_SIZE;
		x = max(min(x, _gridWidth-1), 0);
		y = max(min(y, _gridHeight-1), 0);

		sharkMoveGrid[x][y] = INITIAL_GRID_WEIGHT/2;
		[self propagateSharkGridCostToX:x
									y:y
									onSharkMoveGrid:sharkMoveGrid
									withSharkX:shark.position.x/GRID_SIZE
									sharkY:shark.position.y/GRID_SIZE];

		
		//and add it to the map
		SharkMoveGridData* wrapper = [[SharkMoveGridData alloc] initWithGrid:sharkMoveGrid];
		[_sharkMoveGrids setObject:wrapper forKey:shark.uniqueName];
		
		NSLog(@"Created movegrid template for shark %@", shark.uniqueName);
	}
	
	NSLog(@"Done generating feature maps");
}





-(void)onTouchBeganToolboxItem:(LHTouchInfo*)info {

	if(_activeToolboxItem != nil) {
		//only handle one touch at a time
		return;
	}

	LHSprite* toolboxItem = info.sprite;
	
	if(toolboxItem.tag != TOOLBOX_ITEM) {
		//already placed
		return;
	}
	
	_activeToolboxItem = toolboxItem;
	[toolboxItem transformScale:1];	
}

-(void)onTouchEndedToolboxItem:(LHTouchInfo*)info {
	_moveActiveToolboxItemIntoWorld = true;
}












-(void)onTouchBeganPause:(LHTouchInfo*)info {
	[_pauseButton setFrame:1];
	
}

-(void)onTouchEndedPause:(LHTouchInfo*)info {
	[_pauseButton setFrame:0];

	//TODO: the in-game menu will actually resume and toggling will not be necessary
	if(_state == PAUSE) {
		[self resume];
	}else {
		[self pause];
	}
}

-(void)onTouchBeganRestart:(LHTouchInfo*)info {
	[_restartButton setFrame:1];
}

-(void)onTouchEndedRestart:(LHTouchInfo*)info {
	[_restartButton setFrame:0];
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
	
	//TODO: show some happy sharks and sad penguins (if any are left!)
	//eg. [shark startAnimationNamed:@"attackPenguin"];
	[penguin removeSelf];
	penguin = nil;
	
	//TODO: restart after animations are done
	//[self restart];
}

-(void) restart {
	NSLog(@"Restarting");
	_state = GAME_OVER;
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:1.0 scene:[GameLayer scene] ]];
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
	if(_state != RUNNING) {
		return;
	}

	if(_gameStartCountdownTimer <= 0) {
	
		[self moveSharks:dt];
		[self movePenguins:dt];
	
	}else {
		_gameStartCountdownTimer-= dt;
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
	
	if(_shouldRegenerateFeatureMaps) {
		//the delay is so this potentially-intensive operation doesn't make the game skip
		_shouldRegenerateFeatureMaps = false;
		[self scheduleOnce:@selector(generateFeatureMaps) delay:0.05];
	}
	
	//drop any toolbox items if need be
	if(_activeToolboxItem != nil && _moveActiveToolboxItemIntoWorld) {
	
		NSLog(@"Adding toolbox item to world");
	
		//StaticToolboxItem are things penguins and sharks can't move through
		if([_activeToolboxItem.userInfoClassName isEqualToString:@"StaticToolboxItem"]) {
			_activeToolboxItem.tag = BORDER;
			[_activeToolboxItem makeStatic];
			_shouldRegenerateFeatureMaps = true;
		}
		
		_activeToolboxItem = nil;
		_moveActiveToolboxItemIntoWorld = false;
	}
	
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

-(void) propagateSharkGridCostToX:(int)x y:(int)y onSharkMoveGrid:(int**)sharkMoveGrid withSharkX:(int)sharkX sharkY:(int)sharkY {
	
	if(_state != RUNNING) {
		//stops propagation faster on a pause
		return;
	}
	if(x < 0 || x >= _gridWidth) {
		return;
	}
	if(y < 0 || y >= _gridHeight) {
		return;
	}
	
	/*
	if(sqrt(pow(sharkX-x,2)+pow(sharkY-y,2)) <3) {
		//we're there!
		return;
	}
	*/
	
	double w = sharkMoveGrid[x][y];
	double wN = y+1 >= _gridHeight ? -10000 : sharkMoveGrid[x][y+1];
	double wS = y-1 < 0 ? -10000 : sharkMoveGrid[x][y-1];
	double wE = x+1 >= _gridWidth ? -10000 : sharkMoveGrid[x+1][y];
	double wW = x-1 < 0 ? -10000 : sharkMoveGrid[x-1][y];

	if(w != 0 && w != 1) {
		//NSLog(@"%d,%d = %f", x, y, w);
	}

	
	bool changedN = false;
	bool changedS = false;
	bool changedE = false;
	bool changedW = false;
	

	if(y < _gridHeight-1 && _sharkMapfeaturesGrid[x][y+1] < HARD_BORDER_WEIGHT && (wN == _sharkMapfeaturesGrid[x][y+1] || wN > w+1)) {
		sharkMoveGrid[x][y+1] = w+1 + (_sharkMapfeaturesGrid[x][y+1] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x][y+1]);
		changedN = true;
	}
	if(y > 0 && _sharkMapfeaturesGrid[x][y-1] < HARD_BORDER_WEIGHT && (wS == _sharkMapfeaturesGrid[x][y-1] || wS > w+1)) {
		sharkMoveGrid[x][y-1] = w+1  + (_sharkMapfeaturesGrid[x][y-1] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x][y-1]);
		changedS = true;
	}
	if(x < _gridWidth-1 && _sharkMapfeaturesGrid[x+1][y] < HARD_BORDER_WEIGHT && (wE == _sharkMapfeaturesGrid[x+1][y] || wE > w+1)) {
		sharkMoveGrid[x+1][y] = w+1 + (_sharkMapfeaturesGrid[x+1][y] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x+1][y]);
		changedE = true;
	}
	if(x > 0 && _sharkMapfeaturesGrid[x-1][y] < HARD_BORDER_WEIGHT && (wW == _sharkMapfeaturesGrid[x-1][y] || wW > w+1)) {
		sharkMoveGrid[x-1][y] = w+1  + (_sharkMapfeaturesGrid[x-1][y] == INITIAL_GRID_WEIGHT ? 0 : _sharkMapfeaturesGrid[x-1][y]);
		changedW = true;
	}
	
	if(changedN) {
		[self propagateSharkGridCostToX:x y:y+1 onSharkMoveGrid:sharkMoveGrid withSharkX:sharkX sharkY:sharkY];
	}
	if(changedS) {
		[self propagateSharkGridCostToX:x y:y-1 onSharkMoveGrid:sharkMoveGrid withSharkX:sharkX sharkY:sharkY];
	}
	if(changedE) {
		[self propagateSharkGridCostToX:x+1 y:y onSharkMoveGrid:sharkMoveGrid withSharkX:sharkX sharkY:sharkY];
	}
	if(changedW) {
		[self propagateSharkGridCostToX:x-1 y:y onSharkMoveGrid:sharkMoveGrid withSharkX:sharkX sharkY:sharkY];
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


-(void) moveSharks:(ccTime)dt {
		
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Moving %d sharks...", [sharks count]);
	
	if([sharks count] == 0) {
		//winna winna chicken dinna!
		[self levelWon];
		return;
	}	
		
	for(LHSprite* shark in sharks) {
		
		Shark* sharkData = ((Shark*)shark.userInfo);
		double minDistance = 10000000;
		int gridX = (int)shark.position.x/GRID_SIZE;
		int gridY = (int)shark.position.y/GRID_SIZE;
		
		if(gridX >= _gridWidth || gridX < 0 || gridY >= _gridHeight || gridY < 0) {
			[shark removeSelf];
			shark = nil;
			continue;
		}
				
		CGPoint bestOptionPos = ccp(shark.position.x+1,shark.position.y);
		CGPoint actualTargetPosition = bestOptionPos;
		
		//find the nearest penguin
		for(LHSprite* penguin in penguins) {
			Penguin* penguinData = ((Penguin*)penguin.userInfo);
			if(penguinData.isSafe) {
				continue;
			}

			if(sharkData.targetAcquired) {
				//any ol' penguin will do
				minDistance = 1000000;
			}else if(penguin.body->IsAwake()) {
				//we smell blood...
				minDistance = fmin(minDistance, sharkData.activeDetectionRadius * SCALING_FACTOR);
			}else {
				minDistance = fmin(minDistance, sharkData.restingDetectionRadius * SCALING_FACTOR);
			}		
			
			double dist = ccpDistance(shark.position, penguin.position);
			if(dist < minDistance) {
				minDistance = dist;
				sharkData.targetAcquired = true;
				actualTargetPosition = penguin.position;
			}
		}
		
		//NSLog(@"Closest penguin: %f", minDistance);
		
		SharkMoveGridData* sharkMoveGridData = (SharkMoveGridData*)[_sharkMoveGrids objectForKey:shark.uniqueName];
		int** thisSharksMoveGrid = [sharkMoveGridData grid];
		if(thisSharksMoveGrid == nil) {
			NSLog(@"Waiting for movegrid to be generated for shark %@", shark.uniqueName);
			continue;
		}
		
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				_sharkMoveGrid[x][y] = thisSharksMoveGrid[x][y];
			}
		}
					
		if(sharkData.targetAcquired) {
		
			//NSLog(@"creating grid for %f,%f", actualTargetPosition.x, actualTargetPosition.y);
			//update the best route using penguin data
			int x = (int)actualTargetPosition.x/GRID_SIZE;
			int y = (int)actualTargetPosition.y/GRID_SIZE;
			x = max(min(x, _gridWidth-1), 0);
			y = max(min(y, _gridHeight-1), 0);
			
			_sharkMoveGrid[x][y] = 0;
			[self propagateSharkGridCostToX:x
										y:y
										onSharkMoveGrid:_sharkMoveGrid
										withSharkX:shark.position.x/GRID_SIZE
										sharkY:shark.position.y/GRID_SIZE];
		}
		
		
		//use the best route algorithm
		double wN = _sharkMoveGrid[gridX][gridY+1 >= _gridHeight ? gridY : gridY+1];
		double wS = _sharkMoveGrid[gridX][gridY-1 < 0 ? gridY : gridY-1];
		double wE = _sharkMoveGrid[gridX+1 >= _gridWidth ? gridX : gridX+1][gridY];
		double wW = _sharkMoveGrid[gridX-1 < 0 ? gridX : gridX-1][gridY];
	
	
		//NSLog(@"w=%f e=%f n=%f s=%f", wW, wE, wN, wS);
	
		if(wW == wE && wE == wN && wN == wS) {
		
			//TODO: some kind of random determination?
			bestOptionPos = ccp(shark.position.x+((arc4random()%10)-5)/10.0,shark.position.y+((arc4random()%10)-5)/10.0);
		
		}else {
			double vE = 0;
			double vN = 0;
			
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
			
			//TODO: fix the situation where the shark can get "stuck" in a position
			//add some kind of random jitter to bump him out of it
			//do the same for the penguin
			

		
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
		double max = fmax(fabs(dx), fabs(dy));

								
		if(max == 0) {
			//no best option?
			NSLog(@"No best option for shark max(dx,dy) was 0");
			return;
		}
		
		double normalizedX = dx/max;
		double normalizedY = dy/max;
	
		[sharkMoveGridData logMove:bestOptionPos];
		if([sharkMoveGridData distanceMoved] < sharkData.restingSpeed/10) {
			//we're stuck
			NSLog(@"Shark %@ is stuck - we're removing him", shark.uniqueName);
			[shark removeSelf];
		}
	
		double sharkSpeed = sharkData.restingSpeed;
		if(sharkData.targetAcquired) {
			sharkSpeed = sharkData.activeSpeed;
		}
		b2Vec2 prevVel = shark.body->GetLinearVelocity();
		double targetVelX = dt * sharkSpeed * normalizedX;
		double targetVelY = dt * sharkSpeed * normalizedY;
		double weightedVelX = (prevVel.x * 4.0 + targetVelX)/5.0;
		double weightedVelY = (prevVel.y * 4.0 + targetVelY)/5.0;
		shark.body->SetLinearVelocity(b2Vec2(weightedVelX,weightedVelY));
		
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
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	if(DEBUG_ALL_THE_THINGS) NSLog(@"Moving %d penguins...", [penguins count]);

	for(LHSprite* penguin in penguins) {
		
		int gridX = (int)penguin.position.x/GRID_SIZE;
		int gridY = (int)penguin.position.y/GRID_SIZE;
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
		
		if(penguinData.isSafe) {
			continue;
		}
		
		CGPoint bestOptionPos = penguin.position;
		
		for(LHSprite* shark in sharks) {
			double dist = ccpDistance(shark.position, penguin.position);
			if(dist < penguinData.detectionRadius*SCALING_FACTOR) {
				penguinData.hasSpottedShark = true;
				break;
			}
		}
		
		if(penguinData.hasSpottedShark) {
		
			//AHHH!!!

			//use the best route algorithm
			double wN = _penguinMoveGrid[gridX][gridY+1 >= _gridHeight ? gridY : gridY+1];
			double wS = _penguinMoveGrid[gridX][gridY-1 < 0 ? gridY : gridY-1];
			double wE = _penguinMoveGrid[gridX+1 >= _gridWidth ? gridX : gridX+1][gridY];
			double wW = _penguinMoveGrid[gridX-1 < 0 ? gridX : gridX-1][gridY];
		
		
			//NSLog(@"w=%f e=%f n=%f s=%f", wW, wE, wN, wS);
		
			if(wW == wE && wE == wN && wN == wS) {
			
				//TODO: some kind of random determination?
				bestOptionPos = ccp(penguin.position.x+((arc4random()%2)-1),penguin.position.y+((arc4random()%2)-1));
			
			}else {
				
				double vE = 0;
				double vN = 0;
				
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
					penguin.position.x+vE,
					penguin.position.y+vN
				);
				/*bestOptionPos = ccp(shark.position.x + (fabs(wE) > fabs(wW) ? wE : wW),
									shark.position.y + (fabs(wN) > fabs(wS) ? wN : wS)
								);*/
				//NSLog(@"best: %f,%f", bestOptionPos.x,bestOptionPos.y);
			}
					
			double dx = bestOptionPos.x - penguin.position.x;
			double dy = bestOptionPos.y - penguin.position.y;
			double max = fmax(fabs(dx), fabs(dy));

									
			if(max == 0) {
				//no best option?
				NSLog(@"No best option for penguin max(dx,dy) was 0");
				return;
			}
			
			double normalizedX = dx/max;
			double normalizedY = dy/max;
		
			double penguinSpeed = penguinData.speed;
			b2Vec2 prevVel = penguin.body->GetLinearVelocity();
			double targetVelX = dt * penguinSpeed * normalizedX;
			double targetVelY = dt * penguinSpeed * normalizedY;
			double weightedVelX = (prevVel.x * 4.0 + targetVelX)/5.0;
			double weightedVelY = (prevVel.y * 4.0 + targetVelY)/5.0;
			penguin.body->SetLinearVelocity(b2Vec2(weightedVelX,weightedVelY));
			
			//rotate penguin
			double radians = atan2(weightedVelX, weightedVelY); //this grabs the radians for us
			double degrees = CC_RADIANS_TO_DEGREES(radians) - 90; //90 is because the sprit is facing right
			[penguin transformRotation:degrees];

		}
	}

	if(DEBUG_ALL_THE_THINGS) NSLog(@"Done moving %d penguins...", [penguins count]);

}

//TODO: add a collission detector for the sharks/penguins
//if it ever gets trigger then the penguins lost
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
	
		if(_activeToolboxItem != nil) {
			[_activeToolboxItem transformPosition:location];
		}
		
	}
}


- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];


		if(DEBUG_ALL_THE_THINGS || DEBUG_PENGUIN || DEBUG_SHARK ) {
			NSLog(@"Shark1 sharkMoveGrid[%d][%d] = %d", (int)location.x, (int)location.y, _sharkMoveGrid[(int)location.x/GRID_SIZE][(int)location.y/GRID_SIZE]);
			NSLog(@"_sharkMapfeaturesGrid[%d][%d] = %d", (int)location.x, (int)location.y, _sharkMapfeaturesGrid[(int)location.x/GRID_SIZE][(int)location.y/GRID_SIZE]);
			NSLog(@"_penguinMoveGrid[%d][%d] = %d", (int)location.x, (int)location.y, _penguinMoveGrid[(int)location.x/GRID_SIZE][(int)location.y/GRID_SIZE]);
			NSLog(@"_penguinMapfeaturesGrid[%d][%d] = %d", (int)location.x, (int)location.y, _penguinMapfeaturesGrid[(int)location.x/GRID_SIZE][(int)location.y/GRID_SIZE]);
		}
	}
}








-(void) drawDebugMovementGrid {
		
	if(DEBUG_SHARK ) {
		ccPointSize(GRID_SIZE-2);
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				int sv = (_sharkMoveGrid[x][y]);
				ccDrawColor4B(sv,0,0,50);
				ccDrawPoint( ccp(x*GRID_SIZE, y*GRID_SIZE) );
			}
		}
	}
	
	if(DEBUG_PENGUIN) {
		ccPointSize(GRID_SIZE-2);
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				int pv = (_penguinMapfeaturesGrid[x][y]);
				ccDrawColor4B(0,0,pv,50);
				ccDrawPoint( ccp(x*GRID_SIZE, y*GRID_SIZE) );
			}
		}
	}
	
	if(DEBUG_SHARK || DEBUG_PENGUIN) {
		NSArray* lands = [_levelLoader spritesWithTag:LAND];
		NSArray* borders = [_levelLoader spritesWithTag:BORDER];
		NSMutableArray* unpassableAreas = [NSMutableArray arrayWithArray:lands];
		[unpassableAreas addObjectsFromArray:borders];
		
		ccDrawColor4B(0,100,0,50);
		for(LHSprite* land in unpassableAreas) {
			ccPointSize(land.contentSize.width+10);
			ccDrawPoint(land.position);
		}
	}
}



-(void) draw
{
	if(DEBUG_ALL_THE_THINGS || DEBUG_PENGUIN || DEBUG_SHARK) {
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
	[_sharkMoveGrids removeAllObjects];
	free(_sharkMoveGrid);
	free(_penguinMoveGrid);
	free(_penguinMapfeaturesGrid);
	free(_sharkMapfeaturesGrid);
	
	delete _world;
	_world = NULL;
	
	if(DEBUG_ALL_THE_THINGS) {
		delete _debugDraw;
		_debugDraw = NULL;
	}
	
	[super dealloc];
}	

@end
