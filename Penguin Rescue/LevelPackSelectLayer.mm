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
#import "LevelPackManager.h"

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
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"LevelPackSelect"]];

		b2Vec2 gravity;
		gravity.Set(0.0f, 0.0f);
		_world = new b2World(gravity);

		//create all objects from the level file and adds them to the cocos2d layer (self)
		[_levelLoader addObjectsToWorld:_world cocos2dLayer:self];
		
		
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
	_levelPacksDictionary = [LevelPackManager allLevelPacks];

	//load ones the user has completed
	_completedLevelPacks = [LevelPackManager completedPacks];
	_availableLevelPacks = [LevelPackManager availablePacks];
	_spriteNameToLevelPackPath = [[NSMutableDictionary alloc] init];


	CGSize winSize = [[CCDirector sharedDirector] winSize];

	LHSprite* levelPackButton = [_levelLoader createSpriteWithName:@"Level_Pack_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
	CGSize levelPackSize = levelPackButton.boundingBox.size;
	int levelPackX = levelPackSize.width/2 + 50*SCALING_FACTOR_H;
	int levelPackY = winSize.height/2;
	[levelPackButton removeSelf];
	
		
	for(int i = 0; i < _levelPacksDictionary.count; i++) {

		NSDictionary* levelPackData = [_levelPacksDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelPackName = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_NAME];
		NSString* levelPackPath = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_PATH];
		NSArray* completedLevels = [LevelPackManager completedLevelsInPack:levelPackPath];
		NSDictionary* allLevels = [LevelPackManager allLevelsInPack:levelPackPath];

		//create the sprite
		LHSprite* levelPackButton = [_levelLoader createSpriteWithName:@"Level_Pack_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[levelPackButton prepareAnimationNamed:@"Menu_Level_Pack_Select_Button" fromSHScene:@"Spritesheet"];

		//display the pack background
		CCSprite* packBackground = [CCSprite spriteWithFile:[NSString stringWithFormat:@"Levels/%@/%@", levelPackPath, @"IconBackground.png"]];
		packBackground.scale = levelPackButton.contentSize.width/1001.0;
		packBackground.position = ccp(levelPackSize.width/2,levelPackSize.height/2);
		packBackground.opacity = 200;
		[levelPackButton addChild:packBackground];						

		if([_completedLevelPacks containsObject:levelPackPath]) {
			NSLog(@"Pack %@ is completed!", levelPackPath);

			//add a checkmark on top
			LHSprite* completedMark = [_levelLoader createSpriteWithName:@"Completed_Level" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelPackButton];
			[completedMark transformPosition:ccp(levelPackSize.width/2,levelPackSize.height/2)];
	
			//used when clicking the sprite
			[_spriteNameToLevelPackPath setObject:levelPackPath forKey:levelPackButton.uniqueName];
			[levelPackButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelSelect:)];
			[levelPackButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelSelect:)];
					
		}else if([_availableLevelPacks containsObject:levelPackPath]) {
			NSLog(@"Pack %@ is available!", levelPackPath);

			//used when clicking the sprite
			[_spriteNameToLevelPackPath setObject:levelPackPath forKey:levelPackButton.uniqueName];
			[levelPackButton registerTouchBeganObserver:self selector:@selector(onTouchBeganLevelSelect:)];
			[levelPackButton registerTouchEndedObserver:self selector:@selector(onTouchEndedLevelSelect:)];
					
		}else {
			NSLog(@"Pack %@ is NOT available!", levelPackPath);

			//add a lock on top
			LHSprite* lockIcon = [_levelLoader createSpriteWithName:@"Locked_Level" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:levelPackButton];
			[lockIcon transformPosition:ccp(levelPackSize.width/2,levelPackSize.height/2)];
				
		}
		
		
		//display the pack name
		CCLabelTTF* packNameLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%@", levelPackName] fontName:@"Helvetica" fontSize:36*SCALING_FACTOR_FONTS];
		packNameLabel.color = ccWHITE;
		packNameLabel.position = ccp(levelPackSize.width/2,levelPackSize.height - levelPackSize.width/10);
		[levelPackButton addChild:packNameLabel];
		
		
		//display the % completion
		double percentComplete = (double)completedLevels.count/(allLevels.count > 0 ? allLevels.count : 1) * 100.0;
		CCLabelTTF* percentCompleteLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"%d%% complete", (int)percentComplete] fontName:@"Helvetica" fontSize:36*SCALING_FACTOR_FONTS];
		percentCompleteLabel.color = ccWHITE;
		percentCompleteLabel.position = ccp(levelPackSize.width/2,levelPackSize.width/10);
		[levelPackButton addChild:percentCompleteLabel];

		
		
		//positioning
		[levelPackButton transformPosition: ccp(levelPackX, levelPackY)];
		levelPackX+= levelPackSize.width + 50*SCALING_FACTOR_H;
	}

}





/************* Touch handlers ***************/

-(void)onTouchBeganLevelSelect:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedLevelSelect:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//inactive state
	
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.5 scene:[LevelSelectLayer sceneWithLevelPackPath:[_spriteNameToLevelPackPath objectForKey:info.sprite.uniqueName]] ]];
}



-(void)onTouchBeganBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onTouchEndedBack:(LHTouchInfo*)info {
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
	NSLog(@"LevelPackSelectLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	delete _world;
	_world = NULL;
	
	[super dealloc];
}	


@end
