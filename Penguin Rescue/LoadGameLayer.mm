//
//  LoadGameLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "LoadGameLayer.h"
#import "GameLayer.h"
#pragma mark - LoadGameLayer

// LoadGameLayer implementation
@implementation LoadGameLayer

+(CCScene *) sceneWithLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	LoadGameLayer *layer = [LoadGameLayer node];
	
	[layer setLevelPackPath:levelPackPath levelPath:levelPath];
		
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		
	}
	
	if(DEBUG_MEMORY) NSLog(@"Initialized LoadGameLayer");	
	
	return self;
}

-(void) setLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	_levelPath = [levelPath retain];
	_levelPackPath = [levelPackPath retain];
}

-(void) onEnter
{
	[super onEnter];

	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer sceneWithLevelPackPath:[NSString stringWithFormat:@"%@", _levelPackPath] levelPath:[NSString stringWithFormat:@"%@", _levelPath]]]];
}

-(void) onExit {
	if(DEBUG_MEMORY) NSLog(@"LoadGameLayer onExit");

	[super onExit];
}

-(void) dealloc {
	if(DEBUG_MEMORY) NSLog(@"LoadGameLayer dealloc");

	[_levelPath release];
	[_levelPackPath release];

	[super dealloc];
}
@end
