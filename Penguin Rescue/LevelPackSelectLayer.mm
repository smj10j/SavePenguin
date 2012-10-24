//
//  LevelPackSelectLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "LevelPackSelectLayer.h"
#import "MainMenuLayer.h"
#import "LevelSelectLayer.h"


#pragma mark - LevelPackSelectLayer

@implementation LevelPackSelectLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	LevelPackSelectLayer *layer = [LevelPackSelectLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"Blank"]];
		
		
		LHSprite* backButton = [_levelLoader createSpriteWithName:@"Back_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[backButton prepareAnimationNamed:@"Menu_Back_Button" fromSHScene:@"Spritesheet"];
		[backButton transformPosition: ccp(20*SCALING_FACTOR_H + backButton.boundingBox.size.width/2,
											20*SCALING_FACTOR_V + backButton.boundingBox.size.height/2)];
		[backButton registerTouchBeganObserver:self selector:@selector(onTouchBeganBack:)];
		[backButton registerTouchEndedObserver:self selector:@selector(onTouchEndedBack:)];


		//TODO: implement loading/saving the file to iCloud: http://www.raywenderlich.com/6015/beginning-icloud-in-ios-5-tutorial-part-1
		/*
		NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		if (ubiq) {
			NSLog(@"iCloud access at %@", ubiq);
			_iCloudPath = ubiq;
		}else {
			NSLog(@"No iCloud access");
			_iCloudPath = nil;
		}
		*/
		
		[self loadLevelPacks];
	}
	
	NSLog(@"Initialized LevelPackSelectLayer");
	
	return self;
}




-(void) loadLevelPacks {

	//load all available level packs
	NSString* mainBundlePath = [[NSBundle mainBundle] bundlePath];
	NSString* levelPacksPropertyListPath = [mainBundlePath stringByAppendingPathComponent:@"Levels/Packs.plist"];
	NSLog(@"Loading all level packs from %@", levelPacksPropertyListPath);
	_levelPacksDictionary = [NSDictionary dictionaryWithContentsOfFile:levelPacksPropertyListPath];

	//load ones the user has access to
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* availableLevelPacksPropertyListPath = [rootPath stringByAppendingPathComponent:@"Packs.plist"];
	NSLog(@"Loading user-accessible level packs from %@", availableLevelPacksPropertyListPath);
	_availableLevelPacksDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:availableLevelPacksPropertyListPath];
	if(_availableLevelPacksDictionary == nil) {
		
		//add the first level pack as available
		_availableLevelPacksDictionary = [[NSMutableDictionary alloc] init];
		for(NSString* levelPackName in _levelPacksDictionary) {
			[_availableLevelPacksDictionary setObject:[NSArray arrayWithObject:levelPackName] forKey:@"AvailablePacks"];
			break;
		}
		
		if(![_availableLevelPacksDictionary writeToFile:availableLevelPacksPropertyListPath atomically: YES]) {
			NSLog(@"FAILED TO STORE _availableLevelPacksDictionary - %@", availableLevelPacksPropertyListPath);
		}
	}
	NSArray* availableLevelPacks = [_availableLevelPacksDictionary objectForKey:@"AvailablePacks"];


	_spriteNameToLevelPackPath = [[NSMutableDictionary alloc] init];
	
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	int levelPackX = 200*SCALING_FACTOR_H;
	int levelPackY = winSize.height - 150*SCALING_FACTOR_V;


	for(NSString* levelPackName in _levelPacksDictionary) {
		NSDictionary* levelPackData = [_levelPacksDictionary objectForKey:levelPackName];
		
		//create the sprite
		LHSprite* levelPackButton;
		
		if([availableLevelPacks containsObject:levelPackName]) {
			NSLog(@"Pack %@ is available!", levelPackName);

			levelPackButton = [_levelLoader createSpriteWithName:@"Available_Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
			[levelPackButton prepareAnimationNamed:@"Menu_Available_Level_Select_Button" fromSHScene:@"Spritesheet"];
						
			//used when clicking the sprite
			[_spriteNameToLevelPackPath setObject:[levelPackData objectForKey:@"Path"] forKey:levelPackButton.uniqueName];
			[levelPackButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelSelect:)];
			[levelPackButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelSelect:)];
					
		}else {
			NSLog(@"Pack %@ is NOT available!", levelPackName);

			levelPackButton = [_levelLoader createSpriteWithName:@"Unavailable_Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
				
		}
		
		//display the pack name
		CCLabelTTF* packNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", levelPackName] fontName:@"Helvetica" fontSize:24];
		packNameLabel.color = ccBLACK;
		packNameLabel.position = ccp(levelPackButton.contentSize.width/2,levelPackButton.contentSize.height/2);
		[levelPackButton addChild:packNameLabel];
		
		//positioning
		[levelPackButton transformPosition: ccp(levelPackX, levelPackY)];
		levelPackX+= levelPackButton.boundingBox.size.width + 30*SCALING_FACTOR_H;
	}

}





/************* Touch handlers ***************/

-(void)onTouchBeganLevelSelect:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedLevelSelect:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[LevelSelectLayer setLevelPackPath:[_spriteNameToLevelPackPath objectForKey:info.sprite.uniqueName]];
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelSelectLayer scene] ]];
}



-(void)onTouchBeganBack:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedBack:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[MainMenuLayer scene] ]];
}


-(void) onEnter
{
	[super onEnter];

}
@end
