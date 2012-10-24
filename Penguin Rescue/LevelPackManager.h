//
//  LevelPackManager.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/24/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LevelPackManager : NSObject


+(NSDictionary*)allLevelPacks;
+(NSDictionary*)allLevelsInPack:(NSString*)packPath;

+(NSArray*)completedPacks;
+(NSArray*)completedLevelsInPack:(NSString*)packPath;

+(NSArray*)availablePacks;
+(NSArray*)availableLevelsInPack:(NSString*)packPath;



@end
