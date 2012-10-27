//
//  MainMenuLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "MainMenuLayer.h"
#import "LevelPackSelectLayer.h"
#import "GameLayer.h"


#pragma mark - MainMenuLayer

@implementation MainMenuLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	MainMenuLayer *layer = [MainMenuLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		
		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"MainMenu"]];

		b2Vec2 gravity;
		gravity.Set(0.0f, 0.0f);
		_world = new b2World(gravity);

		//create all objects from the level file and adds them to the cocos2d layer (self)
		[_levelLoader addObjectsToWorld:_world cocos2dLayer:self];

		
		_playButton = [_levelLoader createSpriteWithName:@"Play_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[_playButton prepareAnimationNamed:@"Menu_Play_Button" fromSHScene:@"Spritesheet"];
		[_playButton transformPosition: ccp(winSize.width/2, winSize.height/2)];
		[_playButton registerTouchBeganObserver:self selector:@selector(onTouchBeganPlay:)];
		[_playButton registerTouchEndedObserver:self selector:@selector(onTouchEndedPlay:)];
		
	}
	
	NSLog(@"Initialized MainMenuLayer");	
	
	return self;
}

-(void)onTouchBeganPlay:(LHTouchInfo*)info {
	[_playButton setFrame:_playButton.currentFrame+1];	//active state
}

-(void)onTouchEndedPlay:(LHTouchInfo*)info {

	[_playButton setFrame:_playButton.currentFrame-1];	//inactive state

	if(TEST_MODE) {
		//TESTING CODE
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:TEST_LEVEL_PACK levelPath:TEST_LEVEL]]];

	}else {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelPackSelectLayer scene] ]];
	}
}


-(void) onEnter
{
	[super onEnter];
}

-(void) dealloc
{
	NSLog(@"MainMenuLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	delete _world;
	_world = NULL;
	
	[super dealloc];
}	
@end
