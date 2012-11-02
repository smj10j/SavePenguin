//
//  InAppPurchaseLayer.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"
#import "Constants.h"
#import "LevelHelperLoader.h"

// IntroLayer
@interface InAppPurchaseLayer : CCLayer
{
	LevelHelperLoader* _levelLoader;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

@end
