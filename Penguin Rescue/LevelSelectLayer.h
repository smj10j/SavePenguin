//
//  LevelSelectLayer.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"
#import "LevelHelperLoader.h"
#import "Constants.h"
#import "CCScrollLayer.h"

// IntroLayer
@interface LevelSelectLayer : CCLayer
{
	LevelHelperLoader* _levelLoader;

	NSString* _levelPackPath;
	CCScrollLayer* _scrollLayer;
		
	NSMutableDictionary* _spriteNameToLevelPath;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) sceneWithLevelPackPath:(NSString*)levelPackPath;


@end
