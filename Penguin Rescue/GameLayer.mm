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
		
		_gridWidth = winSize.width/GRID_SIZE;
		_gridHeight = winSize.height/GRID_SIZE;
		_sharkMoveGrid = new int*[_gridWidth];
		_featuresGrid = new int*[_gridWidth];
		for(int i = 0; i < _gridWidth; i++) {
			_sharkMoveGrid[i] = new int[_gridHeight];
			_featuresGrid[i] = new int[_gridHeight];
			for(int j = 0; j < _gridHeight; j++) {
				_sharkMoveGrid[i][j] = 0;
				_featuresGrid[i][j] = 0;
			}
		}
		
		// init physics
		[self initPhysics];
		
		//TODO: store and load the level from prefs using JSON files for next/prev
		NSString* levelName = @"Introduction";
		NSString* levelPack = @"Beach";
		[self loadLevel:levelName inLevelPack:levelPack];
		
		//place the HUD items (pause, restart, etc.)
		[self drawHUD];
		
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
	
	if(DEBUG_MODE) {
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

	//TODO: add touchBegan observer to handle showing an enlarged button
	LHSprite* pauseButton = [_levelLoader createSpriteWithName:@"Pause" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:self];	
	pauseButton.position = ccp(pauseButton.contentSize.width/2+30*SCALING_FACTOR,pauseButton.contentSize.height/2+20*SCALING_FACTOR);
	[pauseButton registerTouchBeganObserver:self selector:@selector(togglePause)];
	
	
	//TODO: add touchBegan observer to handle showing an enlarged button
	LHSprite* restartButton = [_levelLoader createSpriteWithName:@"Restart" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:self];
	restartButton.position = ccp(winSize.width - (restartButton.contentSize.width/2+30*SCALING_FACTOR),restartButton.contentSize.height/2+20*SCALING_FACTOR);
	[restartButton registerTouchBeganObserver:self selector:@selector(restart)];
	
}

-(void) loadLevel:(NSString*)levelName inLevelPack:(NSString*)levelPack {
		
	CGSize winSize = [[CCDirector sharedDirector] winSize];

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
	
	//fill in the feature grid detailing map movement info
	NSArray* lands = [_levelLoader spritesWithTag:LAND];
	for(LHSprite* land in lands) {
	
		int minX = land.position.x;
		int maxX = land.position.x+land.contentSize.width;
		int minY = land.position.y;
		int maxY = land.position.y+land.contentSize.height;
		
		int coastalMinX = max(0, minX-10);
		int coastalMaxX = min(winSize.width-1, maxX+10);
		int coastalMinY = max(0, minY-10);
		int coastalMaxY = min(winSize.height-1, maxY+10);
	
	
		NSLog(@"coasts: %d,%d to %d,%d", coastalMinX,coastalMinY, coastalMaxX, coastalMaxY);
	
		for(int x = coastalMinX; x < coastalMaxX; x++) {
			for(int y = coastalMinY; y < coastalMaxY; y++) {
				if(x >= minX && x <= maxX && y >= minY && y <= maxY) {
					//land
					_featuresGrid[x/GRID_SIZE][y/GRID_SIZE] = 100;
				}else {
					//coastal reef!
					_featuresGrid[x/GRID_SIZE][y/GRID_SIZE]+= max(min(abs(coastalMinX-x), abs(coastalMaxX-x)), min(abs(coastalMinY-y), abs(coastalMaxY-y)))/2;
				}
			}
		}
		/*NSLog(@"Land from %f,%f to %f,%f",
			land.position.x-land.contentSize.width/2, land.position.y-land.contentSize.height/2,
			land.position.x+land.contentSize.width/2, land.position.y+land.contentSize.height/2);*/
	}
	
	
	//TODO: load if we should show the tutorial from user prefs
	if(true) {
		[self showTutorial];
	}
}




-(void) togglePause {
	if(_state == PAUSE) {
		[self resume];
	}else {
		[self pause];
	}
}

-(void) pause {
	NSLog(@"Pausing game");
	_state = PAUSE;
	
	[self showInGameMenu];
}

-(void) showInGameMenu {
	NSLog(@"Showing in-game menu");
	//TODO: show an in-game menu
	// - show levels, go to main menu, resume
}

-(void) resume {
	NSLog(@"Resuming game");
	_state = RUNNING;
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


	//It is recommended that a fixed time step is used with Box2D for stability
	//of the simulation, however, we are using a variable time step here.
	//You need to make an informed choice, the following URL is useful
	//http://gafferongames.com/game-physics/fix-your-timestep/
	
	int32 velocityIterations = 8;
	int32 positionIterations = 1;
	
	// Instruct the world to perform a single step of simulation. It is
	// generally best to keep the time step and iterations fixed.
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

-(void) propagateSharkGridCostToX:(int)x y:(int)y {
	
	if(x < 0 || x >= _gridWidth) {
		return;
	}
	if(y < 0 || y >= _gridHeight) {
		return;
	}
	
	double w = _sharkMoveGrid[x][y];
	double wN = y+1 >= _gridHeight ? -10000 : _sharkMoveGrid[x][y+1];
	double wS = y-1 < 0 ? -10000 : _sharkMoveGrid[x][y-1];
	double wE = x+1 >= _gridWidth ? -10000 : _sharkMoveGrid[x+1][y];
	double wW = x-1 < 0 ? -10000 : _sharkMoveGrid[x-1][y];

	if(w != 0 && w != 1) {
		//NSLog(@"%d,%d = %f", x, y, w);
	}
	
	bool changedN = false;
	bool changedS = false;
	bool changedE = false;
	bool changedW = false;
	

	if(wN == 0 || wN > w+1) {
		_sharkMoveGrid[x][y+1] = w+1 + _featuresGrid[x][y+1];
		changedN = true;
	}
	if(wS == 0 || wS > w+1) {
		_sharkMoveGrid[x][y-1] = w+1 + _featuresGrid[x][y-1];
		changedS = true;
	}
	if(wE == 0 || wE > w+1) {
		_sharkMoveGrid[x+1][y] = w+1 + _featuresGrid[x+1][y];
		changedE = true;
	}
	if(wW == 0 || wW > w+1) {
		_sharkMoveGrid[x-1][y] = w+1 + _featuresGrid[x-1][y];
		changedW = true;
	}
	
	if(changedN) {
		[self propagateSharkGridCostToX:x y:y+1];
	}
	if(changedS) {
		[self propagateSharkGridCostToX:x y:y-1];
	}
	if(changedE) {
		[self propagateSharkGridCostToX:x+1 y:y];
	}
	if(changedW) {
		[self propagateSharkGridCostToX:x-1 y:y];
	}
	
}


-(void) moveSharks:(ccTime)dt {
	//NSLog(@"Moving %d sharks...", [sharks count]);
	
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];
	
	if([sharks count] == 0) {
		//winna winna chicken dinna!
		[self levelWon];
		return;
	}

	bool haveCreatedGrid = false;
	
	for(int x = 0; x < _gridWidth; x++) {
		for(int y = 0; y < _gridHeight; y++) {
			_sharkMoveGrid[x][y] = _featuresGrid[x][y];
		}
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
		
		//set our endpoint path data
		//NSLog(@"%f, %f - %d, %d", ((Shark*)shark.userInfo).endpointX/GRID_SIZE, ((Shark*)shark.userInfo).endpointY/GRID_SIZE, _gridWidth, _gridHeight);
		CGPoint endpoint = ccp(min(sharkData.endpointX/GRID_SIZE, _gridWidth-1),
								min(sharkData.endpointY/GRID_SIZE,_gridHeight-1)
							);
		
		if(ccpDistance(shark.position, ccp(sharkData.endpointX, sharkData.endpointY)) > 50) {
			[self propagateSharkGridCostToX:endpoint.x y:endpoint.y];
		}

		
		CGPoint bestOptionPos = ccp(shark.position.x+1,shark.position.y);
		CGPoint actualTargetPosition = bestOptionPos;
		((Shark*)shark.userInfo).targetAcquired = false;
		
		for(LHSprite* penguin in penguins) {
			if([self isPenguinSafe:penguin]) {
				continue;
			}

			if(penguin.body->IsAwake()) {
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
		
		if(sharkData.targetAcquired && !haveCreatedGrid) {
		
			//NSLog(@"target acquired");

			//update the best route using penguin data
		
			for(LHSprite* penguin in penguins) {
				if([self isPenguinSafe:penguin]) {
					continue;
				}
			
				_sharkMoveGrid[(int)penguin.position.x/GRID_SIZE][(int)penguin.position.y/GRID_SIZE] = 0;
				[self propagateSharkGridCostToX:(int)penguin.position.x/GRID_SIZE
												y:(int)penguin.position.y/GRID_SIZE];
			}
			
			haveCreatedGrid = true;

		}
		
		
		
		//use the best route algorithm
		double wN = _sharkMoveGrid[gridX][gridY+1 >= _gridHeight ? gridY : gridY+1];
		double wS = _sharkMoveGrid[gridX][gridY-1 <= 0 ? gridY : gridY-1];
		double wE = _sharkMoveGrid[gridX+1 >= _gridWidth ? gridX : gridX+1][gridY];
		double wW = _sharkMoveGrid[gridX-1 <= 0 ? gridX : gridX-1][gridY];
	
		if(wW == wE == wS == wN) {
		
			//TODO: some kind of random determination?
		
		}else {
			bestOptionPos = ccp(
				shark.position.x+(
					1/(wE == 0 ? 10 : wE) - 1/(wW == 0 ? 10 : wW)),
				shark.position.y+(
					1/(wN == 0 ? 10 : wN) - 1/(wS == 0 ? 10 : wS))
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
			NSLog(@"No best option shark max(dx,dy) was 0");
			return;
		}
		
		double normalizedX = dx/max;
		double normalizedY = dy/max;
	
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
		double radians = atan2(actualTargetPosition.x-shark.position.x, actualTargetPosition.y-shark.position.y); //this grabs the radians for us
		double degrees = CC_RADIANS_TO_DEGREES(radians) - 90; //90 is because the sprit is facing right
		[shark transformRotation:degrees];
	}
	
}

-(void) movePenguins:(ccTime)dt {

	//CGSize winSize = [[CCDirector sharedDirector] winSize];

	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	NSArray* lands = [_levelLoader spritesWithTag:LAND];
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];

	for(LHSprite* penguin in penguins) {
		
		Penguin* penguinData = ((Penguin*)penguin.userInfo);
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

			double minDistance = 1000000;
		
			for(LHSprite* land in lands) {
				if(![self isPenguinSafe:penguin]) {
					double dist = ccpDistance(land.position, penguin.position);
					if(dist < minDistance) {
						minDistance = dist;
						bestOptionPos = land.position;
					}
				}else {
					penguin.position = land.position;
				}
			}

			if([self isPenguinSafe:penguin]) {
				[penguin body]->SetLinearVelocity(b2Vec2(0,0));
			}else {
				double dx = bestOptionPos.x - penguin.position.x;
				double dy = bestOptionPos.y - penguin.position.y;
				double max = fmax(fabs(dx), fabs(dy));
				
				if(max == 0) {
					//no best option?
					NSLog(@"No best option penguin max(dx,dy) was 0");
					return;
				}
				
				double normalizedX = dx/max;
				double normalizedY = dy/max;
			
				[penguin body]->SetLinearVelocity(b2Vec2(
					dt * penguinData.speed * normalizedX,
					dt * penguinData.speed * normalizedY
				));
			}
		}
	}

	//NSLog(@"Moving %d penguins...", [penguins count]);

}

-(void) checkForWinCondition {
	NSLog(@"Checking for win condition.");
	
	//TODO: win condition is when all sharks are offscreen (a loss condition will be triggered automatically)

}

//TODO: add a collission detector for the sharks/penguins
//if it ever gets trigger then the penguins lost
-(void) sharkPenguinCollision:(LHContactInfo*)contact
{        
	LHSprite* shark = [contact spriteA];
    LHSprite* penguin = [contact spriteB];

    if(nil != penguin && nil != shark)
    {
		NSLog(@"Shark %@ has collided with penguin %@!", shark.uniqueName, penguin.uniqueName);
		[self levelLostWithShark:shark andPenguin:penguin];
    }
}

-(void) landPenguinCollision:(LHContactInfo*)contact
{
    LHSprite* land = [contact spriteA];
    LHSprite* penguin = [contact spriteB];

    if(nil != penguin && nil != land)
    {
		NSLog(@"Penguin %@ has collided with some land!", penguin.uniqueName);
		if(![self isPenguinSafe:penguin]) {
			((Penguin*)penguin.userInfo).isSafe = true;
			
			//TODO: replace with a happy animation
			[penguin removeSelf];
			penguin = nil;
		}
    }
}

-(bool) isPenguinSafe:(LHSprite*)penguin {
	Penguin* info = (Penguin*)penguin.userInfo;
	return info.isSafe;
}










- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	//Add a new body/atlas sprite at the touched location
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];
		
	}
}








-(void) drawDebugMovementGrid {
	for(int x = 0; x < _gridWidth; x++) {
		for(int y = 0; y < _gridHeight; y++) {

			// draw big point in the center
			ccPointSize(50);
			ccDrawColor4B(_sharkMoveGrid[x][y],0,0,50);
			ccDrawPoint( ccp(x*GRID_SIZE, y*GRID_SIZE) );

		}
	}
}



-(void) draw
{
	//
	// IMPORTANT:
	// This is only for debug purposes
	// It is recommend to disable it
	//
	[super draw];
	
	ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
	
	kmGLPushMatrix();
	
	if(DEBUG_MODE) {
		_world->DrawDebugData();
		[self drawDebugMovementGrid];
	}
	
	kmGLPopMatrix();
}

-(void) dealloc
{
	delete _world;
	_world = NULL;
	
	if(DEBUG_MODE) {
		delete _debugDraw;
		_debugDraw = NULL;
	}
	
	[super dealloc];
}	

@end
