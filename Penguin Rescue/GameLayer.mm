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
		
		[self initPhysics];
		
		//TODO: store and load the level from prefs using JSON files for next/prev
		NSString* levelName = @"Introduction";
		NSString* levelPack = @"Beach";
		[self loadLevel:levelName inLevelPack:levelPack];
		
		//place the HUD items (pause, restart, etc.)
		[self drawHUD];
		
		// init physics
		[self setupCollisionHandling];
		
		//sharks start in N seconds
		_gameStartCountdownTimer = SHARKS_COUNTDOWN_TIMER_INITIAL;
		_safePenguins = [[NSMutableArray alloc] init];
		
		//start the game
		_state = RUNNING;
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

-(void) setupCollisionHandling
{
    [_levelLoader useLevelHelperCollisionHandling];
	[_levelLoader registerBeginOrEndCollisionCallbackBetweenTagA:LAND andTagB:PENGUIN idListener:self selListener:@selector(landPenguinCollision:)];
    [_levelLoader registerBeginOrEndCollisionCallbackBetweenTagA:SHARK andTagB:PENGUIN idListener:self selListener:@selector(sharkPenguinCollision:)];
}

-(void) drawHUD {
	NSLog(@"Drawing HUD");

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	LHSprite* pauseButton = [_levelLoader createSpriteWithName:@"Pause" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:self];
	LHSprite* restartButton = [_levelLoader createSpriteWithName:@"Restart" fromSheet:@"HUD" fromSHFile:@"Spritesheet" parent:self];

	
	pauseButton.position = ccp(pauseButton.contentSize.width/2+30,pauseButton.contentSize.height/2+20);
	restartButton.position = ccp(winSize.width - (restartButton.contentSize.width/2+30),restartButton.contentSize.height/2+20);
	
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
	
	//TODO: load if we should show the tutorial from user prefs
	if(true) {
		[self showTutorial];
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
	penguin.visible = false;
	
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


-(void) moveSharks:(ccTime)dt {
	//NSLog(@"Moving %d sharks...", [sharks count]);

	CGSize winSize = [[CCDirector sharedDirector] winSize];
	
	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	NSArray* lands = [_levelLoader spritesWithTag:LAND];
	NSArray* sharks = [_levelLoader spritesWithTag:SHARK];

	bool targetAcquired = false;

	for(LHSprite* shark in sharks) {
		
		double minDistance = 1000000;
		CGPoint bestOptionPos = ccp(shark.position.x+1, shark.position.y);
		
		for(LHSprite* penguin in penguins) {
			if([self isPenguinSafe:penguin]) {
				continue;
			}
			
			if(penguin.body->IsAwake()) {
				//we smell blood...
				minDistance = fmin(minDistance, 500/*((Shark*)shark).activeDetectionRadius * SCALING_FACTOR*/);
			}else {
				minDistance = fmin(minDistance, 300/*((Shark*)shark).restingDetectionRadius * SCALING_FACTOR*/);
			}
			
			double dist = ccpDistance(shark.position, penguin.position);
			if(dist < minDistance) {
				minDistance = dist;
				bestOptionPos = penguin.position;
				targetAcquired = true;
			}
		}
		
		double dx = bestOptionPos.x - shark.position.x;
		double dy = bestOptionPos.y - shark.position.y;
		double max = fmax(dx, dy);
				
		if(max == 0) {
			//no best option?
			NSLog(@"No best option shark max(dx,dy) was 0");
			return;
		}
		
		double normalizedX = dx/max;
		double normalizedY = dy/max;
	
		if(targetAcquired) {
			[shark body]->SetLinearVelocity(b2Vec2(
				dt * 100/*((Shark*)shark).restingSpeed*SCALING_FACTOR*/ * normalizedX,
				dt * 100/*((Shark*)shark).restingSpeed*SCALING_FACTOR*/ * normalizedY
			));
		}else {
			[shark body]->SetLinearVelocity(b2Vec2(
				dt * 50/*((Shark*)shark).activeSpeed*SCALING_FACTOR*/ * normalizedX,
				dt * 50/*((Shark*)shark).activeSpeed*SCALING_FACTOR*/ * normalizedY
			));		
		}
	}
	
}

-(void) movePenguins:(ccTime)dt {

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	NSArray* penguins = [_levelLoader spritesWithTag:PENGUIN];
	NSArray* lands = [_levelLoader spritesWithTag:LAND];

	for(LHSprite* penguin in penguins) {
		
		double minDistance = 1000000;
		CGPoint bestOptionPos = penguin.position;
		
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
			double max = fmax(dx, dy);
			
			if(max == 0) {
				//no best option?
				NSLog(@"No best option penguin max(dx,dy) was 0");
				return;
			}
			
			double normalizedX = dx/max;
			double normalizedY = dy/max;
		
			[penguin body]->SetLinearVelocity(b2Vec2(
				dt * 50/*((Penguin*)penguin).speed*SCALING_FACTOR*/ * normalizedX,
				dt * 50/*((Penguin*)penguin).speed*SCALING_FACTOR*/ * normalizedY
			));
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
			[_safePenguins addObject:penguin.uniqueName];
			
			//TODO: replace with a happy animation
			[penguin removeSelf];
		}
    }
}

-(bool) isPenguinSafe:(LHSprite*)penguin {
	for(NSString* name in _safePenguins) {
		if([name isEqualToString:penguin.uniqueName]) {
			return true;
		}
	}
	return false;
}










- (void)ccTouchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	//Add a new body/atlas sprite at the touched location
	for( UITouch *touch in touches ) {
		CGPoint location = [touch locationInView: [touch view]];
		location = [[CCDirector sharedDirector] convertToGL: location];
		
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
	
	_world->DrawDebugData();
	
	kmGLPopMatrix();
}

-(void) dealloc
{
	delete _world;
	_world = NULL;
	
	delete _debugDraw;
	_debugDraw = NULL;
	
	[super dealloc];
}	

@end
