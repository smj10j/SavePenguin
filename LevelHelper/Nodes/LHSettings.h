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
#import "lhConfig.h"
#ifdef LH_USE_BOX2D
#import "Box2D.h"
#endif
@class LHLayer;
@class LHSprite;
@class LHJoint;
@class LHBezier;

@interface LHSettings : NSObject
{
    NSMutableSet* markedSprites;
    NSMutableSet* markedJoints;
    NSMutableSet* markedBeziers;

    
	bool useHDOnIpad;
	float lhPtmRatio;
	float customAlpha; //used by SceneTester
	int newBodyId;
	CGPoint convertRatio;
    CGPoint realConvertRatio;
	bool convertLevel;
	
    bool stretchArt;
    CGPoint possitionOffset;
    bool levelPaused;
	//NSMutableString* imagesFolder;
    bool isCoronaUser;
    
    bool preloadBatchNodes;
#ifdef LH_USE_BOX2D
    b2World* activeBox2dWorld;
#endif
    int device;//0 iphone only; 1 ipad only; 2 universal; 3 mac - dont do any transformations
    NSMutableString* hdSuffix;
    NSMutableString* hd2xSuffix;
    
    NSMutableArray* allLHMainLayers;
    
    NSMutableString* activeFolder;
    CGSize saveFrame;//used by the touch handler to conver touches
}
@property bool useHDOnIpad;
@property float lhPtmRatio;
@property float customAlpha;
//@property CGPoint convertRatio;
@property bool convertLevel;
@property bool levelPaused;
@property bool isCoronaUser;
@property bool preloadBatchNodes;
@property int device;
@property CGSize safeFrame;

+(LHSettings*) sharedInstance;

-(void)setActiveFolder:(NSString*)folder;
-(NSString*)activeFolder;

-(void)addLHMainLayer:(LHLayer*)layer;
-(void)removeLHMainLayer:(LHLayer*)layer;
-(NSArray*)allLHMainLayers;

#ifdef LH_USE_BOX2D
-(b2World*)activeBox2dWorld;
-(void)setActiveBox2dWorld:(b2World*)world;
#endif

-(void)setHDSuffix:(NSString*)suffix;
-(NSString*)hdSuffix;

-(void)setHD2xSuffix:(NSString*)suffix;
-(NSString*)hd2xSuffix;

-(void) markSpriteForRemoval:(LHSprite*)sprite;
-(void) markBezierForRemoval:(LHBezier*) node; 
-(void) markJointForRemoval:(LHJoint*)jt;

-(void) removeMarkedSprites;
-(void) removeMarkedBeziers;
-(void) removeMarkedJoints;



-(int)newBodyId;

-(CGPoint)transformedScalePointToCocos2d:(CGPoint)point;
-(CGPoint)transformedPointToCocos2d:(CGPoint)point;
-(CGPoint)transformedPoint:(CGPoint)point forImage:(NSString*)image;
-(CGRect)transformedTextureRect:(CGRect)rect forImage:(NSString*)image;
-(CGSize)transformedSize:(CGSize)size forImage:(NSString*)image;

-(NSString*)imagePath:(NSString*)file;//will return -hd image when appropriate


-(bool)isHDImage:(NSString*)image;


//-(bool)shouldScaleImageOnRetina:(NSString*)image;
-(bool)isIpad;
-(bool)isIphone5;

-(void)setStretchArt:(bool)value;
-(bool)stretchArt;

-(CGPoint) possitionOffset;
-(void) setConvertRatio:(CGPoint)val;// usesCustomSize:(bool)usesCustomSize;
-(CGPoint) convertRatio;
-(CGPoint) realConvertRatio;
@end	
