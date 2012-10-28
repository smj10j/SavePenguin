//
//  AboutLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "AboutLayer.h"
#import "MainMenuLayer.h"
#import "AppDelegate.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"

#pragma mark - AboutLayer

@implementation AboutLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	AboutLayer *layer = [AboutLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		self.isTouchEnabled = YES;

		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];

		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"About"]];
		
		
		
		
		//TODO: fill this bad boy out with:
			/*
			Rate App
			Email us
			About the App
			About Conquer
			Version
			*/
		CCLabelTTF* TODOLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"TODO: Add an about page"] fontName:@"Helvetica" fontSize:48*SCALING_FACTOR_FONTS];
		TODOLabel.color = ccWHITE;
		TODOLabel.position = ccp(winSize.width/2, winSize.height/2);
		[self addChild:TODOLabel];
			
			
		
		
		
		
		
				
		LHSprite* backButton = [_levelLoader createSpriteWithName:@"Back_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[backButton prepareAnimationNamed:@"Menu_Back_Button" fromSHScene:@"Spritesheet"];
		[backButton transformPosition: ccp(20*SCALING_FACTOR_H + backButton.boundingBox.size.width/2,
											20*SCALING_FACTOR_V + backButton.boundingBox.size.height/2)];
		[backButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[backButton registerTouchEndedObserver:self selector:@selector(onBack:)];

	}
	
	NSLog(@"Initialized AboutLayer");	
	
	return self;
}


-(void)onTouchBeganAnyButton:(LHTouchInfo*)info {
	if(info.sprite != nil)
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
	
	if([SettingsManager boolForKey:@"SoundEnabled"]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
}


-(void)onBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[MainMenuLayer scene] ]];
}






-(void) onEnter
{
	[super onEnter];
}



-(void) dealloc
{
	NSLog(@"AboutLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
}	

@end
