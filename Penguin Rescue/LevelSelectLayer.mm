//
//  LevelSelectLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "LevelSelectLayer.h"
#import "LevelPackSelectLayer.h"
#import "GameLayer.h"
#import "LevelPackManager.h"


#pragma mark - LevelSelectLayer

static NSString* sLevelPackPath;

@implementation LevelSelectLayer

// Helper class method that creates a Scene with the HelloWorldLayer as the only child.
+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	LevelSelectLayer *layer = [LevelSelectLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

+(void)setLevelPackPath:(NSString*)levelPackPath {
	sLevelPackPath = levelPackPath;
	NSLog(@"Set LevelSelectLayer.sLevelPackPath=%@", sLevelPackPath);
}

//
-(id) init
{
	if( (self=[super init])) {
		
		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];
		
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
	}
	
	[self loadLevels];
	
	NSLog(@"Initialized LevelSelectLayer");	
	
	return self;
}



-(void) loadLevels {

	//load all available levels for this pack
	_levelsDictionary = [LevelPackManager allLevelsInPack:sLevelPackPath];
	
	//load all levels for this pack that the user has completed
	_completedLevels = [LevelPackManager completedLevelsInPack:sLevelPackPath];
	_availableLevels = [LevelPackManager availableLevelsInPack:sLevelPackPath];
	_spriteNameToLevelPath = [[NSMutableDictionary alloc] init];
	
	
	CGSize winSize = [[CCDirector sharedDirector] winSize];
	int levelX = 200*SCALING_FACTOR_H;
	int levelY = winSize.height - 150*SCALING_FACTOR_V;


	for(int i = 0; i < _levelsDictionary.count; i++) {

		NSDictionary* levelData = [_levelsDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelName = [levelData objectForKey:@"Name"];
		
		//create the sprite
		LHSprite* levelButton;
		
		if([_availableLevels containsObject:levelName]) {
			NSLog(@"Level %@ is available!", levelName);

			levelButton = [_levelLoader createSpriteWithName:@"Available_Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
			[levelButton prepareAnimationNamed:@"Menu_Available_Level_Select_Button" fromSHScene:@"Spritesheet"];
			
			//used when clicking the sprite
			[_spriteNameToLevelPath setObject:[levelData objectForKey:@"Path"] forKey:levelButton.uniqueName];
			[levelButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelSelect:)];
			[levelButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelSelect:)];
					
		}else {
			NSLog(@"Level %@ is NOT available!", levelName);

			levelButton = [_levelLoader createSpriteWithName:@"Unavailable_Level_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
				
		}
		
		//display the level name
		CCLabelTTF* levelNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", levelName] fontName:@"Helvetica" fontSize:20];
		levelNameLabel.color = ccBLACK;
		levelNameLabel.position = ccp(levelButton.contentSize.width/2,levelButton.contentSize.height/2);
		[levelButton addChild:levelNameLabel];
		
		//positioning
		[levelButton transformPosition: ccp(levelX, levelY)];
		levelX+= levelButton.boundingBox.size.width + 30*SCALING_FACTOR_H;
	}

}






/************* Touch handlers ***************/

-(void)onTouchBeganLevelSelect:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedLevelSelect:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[GameLayer setLevelPackPath:sLevelPackPath];
	[GameLayer setLevelPath:[_spriteNameToLevelPath objectForKey:info.sprite.uniqueName]];
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[GameLayer scene] ]];
}



-(void)onTouchBeganBack:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedBack:(LHTouchInfo*)info {
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelPackSelectLayer scene] ]];
}


-(void) onEnter
{
	[super onEnter];

}
@end
