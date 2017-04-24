//
//  LHLayer.h
//  ParallaxTimeBased
//
//  Created by Bogdan Vladu on 4/2/12.
//  Copyright (c) 2012 Bogdan Vladu. All rights reserved.
//

#import "CCLayer.h"

@class LHSprite;
@class LHBatch;
@class LHBezier;
@class LevelHelperLoader;
@interface LHLayer : CCLayer
{
    bool isMainLayer;
    NSString* uniqueName;
    __unsafe_unretained LevelHelperLoader* parentLoader;
    
    id  userCustomInfo;
}
@property (readonly) NSString* uniqueName;
@property bool isMainLayer;

+(instancetype)layerWithDictionary:(NSDictionary*)dict;

-(void) removeSelf; //will also remove all children

@property (NS_NONATOMIC_IOSONLY, strong) LevelHelperLoader *parentLoader;

-(LHLayer*)layerWithUniqueName:(NSString*)name; //does not return self
-(LHBatch*)batchWithUniqueName:(NSString*)name;
-(LHSprite*)spriteWithUniqueName:(NSString*)name;
-(LHBezier*)bezierWithUniqueName:(NSString*)name;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *allLayers; //does not return self
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *allBatches;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *allSprites;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *allBeziers;

-(NSArray*)layersWithTag:(int)tag; //does not return self
-(NSArray*)batchesWithTag:(int)tag;
-(NSArray*)spritesWithTag:(int)tag;
-(NSArray*)beziersWithTag:(int)tag;
//------------------------------------------------------------------------------
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *userInfoClassName;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) id userInfo;

@end
