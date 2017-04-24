//  This file was generated by LevelHelper
//  http://www.levelhelper.org
//
//  LevelHelperLoader.mm
//  Created by Bogdan Vladu
//  Copyright 2011 Bogdan Vladu. All rights reserved.
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

#import "LHCustomSpriteMgr.h"
#import "cocos2d.h"
#import "LHSprite.h"
#import "LevelHelperLoader.h"
@implementation LHCustomSpriteMgr
////////////////////////////////////////////////////////////////////////////////

//------------------------------------------------------------------------------
+ (LHCustomSpriteMgr*)sharedInstance{
	static id sharedInstance = nil;
	if (sharedInstance == nil){
		sharedInstance = [[LHCustomSpriteMgr alloc] init];
	}
    return sharedInstance;
}
//------------------------------------------------------------------------------
-(void)dealloc
{
    baseSpritesClass = nil;
#ifndef LH_ARC_ENABLED
	[classesDictionary release];
	[super dealloc];
#endif
}
//------------------------------------------------------------------------------
- (instancetype)init
{
	self = [super init];
	if (self != nil) {
        classesDictionary = [[NSMutableDictionary alloc] init];
        baseSpritesClass = nil;
	}
	return self;
}
//------------------------------------------------------------------------------
-(void) registerBaseSpriteClass:(Class)base{
    baseSpritesClass = base;
}
-(Class) baseClass{
    
    if(baseSpritesClass == nil){
        return [LHSprite class];
    }
    
    return baseSpritesClass;
}

-(void) registerCustomSpriteClass:(Class)customSpriteClass forTag:(int)tag{
    classesDictionary[@(tag)] = customSpriteClass;
}
//------------------------------------------------------------------------------
-(Class) customSpriteClassForTag:(int)tag{
 
    id customSpriteClass = classesDictionary[@(tag)];
    
    if(customSpriteClass == nil)
    {
        return [self baseClass];
    }
    
    return customSpriteClass;
}
//------------------------------------------------------------------------------
@end
