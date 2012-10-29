//
//  LoadGameLayer.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"
#import "Constants.h"

@interface LoadGameLayer : CCLayer
{
	NSString* _levelPath;
	NSString* _levelPackPath;

}

+(CCScene *) sceneWithLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;

@end
