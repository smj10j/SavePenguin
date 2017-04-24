//  This file was generated by LevelHelper
//  http://www.levelhelper.org
//
//  LevelHelperLoader.h
//  Created by Bogdan Vladu
//  Copyright 2011 Bogdan Vladu. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//  The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//  Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//  This notice may not be removed or altered from any source distribution.
//  By "software" the author refers to this code file and not the application 
//  that was used to generate this file.
//
////////////////////////////////////////////////////////////////////////////////

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import "lhConfig.h"
#ifdef LH_USE_BOX2D
#include "Box2D.h"
#endif

@class LHSprite;
@class LevelHelperLoader;
@interface LHParallaxNode : CCNode//CCParallaxNode 
{
	bool isContinuous;
	int direction;
	float speed;
	
	CGPoint lastPosition;
    
    NSString* uniqueName;
	
    id movedEndListenerObj;
    SEL movedEndListenerSEL;
    
	CGSize winSize;
	
	bool paused;
    
	float screenNumberOnTheRight;
	float screenNumberOnTheLeft;
	float screenNumberOnTheTop;
	float screenNumberOnTheBottom;
	
	//NSMutableArray* sprites;
    CCArray* sprites;//better performance
    
    __unsafe_unretained LevelHelperLoader* lhLoader;
    bool removeSpritesOnDelete;
    
    LHSprite* followedSprite;
    CGPoint lastFollowedSpritePosition;
    bool followChangeX;
    bool followChangeY;
    
//    double time;
}
@property (readonly) bool isContinuous;
@property (readonly) int direction;
@property (readwrite) float speed;
@property (readwrite) bool paused;

-(instancetype) initWithDictionary:(NSDictionary*)properties loader:(LevelHelperLoader*)loader NS_DESIGNATED_INITIALIZER;
+(instancetype) nodeWithDictionary:(NSDictionary*)properties loader:(LevelHelperLoader*)loader;

-(void) addSprite:(LHSprite*)sprite parallaxRatio:(CGPoint)ratio;

-(void) addNode:(CCNode*)node parallaxRatio:(CGPoint)ratio; 

-(void) removeChild:(LHSprite*)sprite;
//method needs to be like this -(void)spriteMovedToEnd:(LHSprite*)spr;
-(void) registerSpriteHasMovedToEndListener:(id)object selector:(SEL)method;

//will make the parallax move based on the sprite position (e.g player)
//pass NULL to this function to unfollow the sprite
//DO NOT USE THIS METHOD If your parallax is continuos scrolling
-(void) followSprite:(LHSprite*)sprite changePositionOnX:(bool)xChange changePositionOnY:(bool)yChange;


@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *uniqueName;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *spritesInNode;
@end	
