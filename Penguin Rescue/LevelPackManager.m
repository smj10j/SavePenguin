//
//  LevelPackManager.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/24/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "LevelPackManager.h"

@implementation LevelPackManager

//fetch all available level packs
+(NSDictionary*)allLevelPacks {
	NSString* mainBundlePath = [[NSBundle mainBundle] bundlePath];
	NSString* levelPacksPropertyListPath = [mainBundlePath stringByAppendingPathComponent:@"Levels/Packs.plist"];
	NSLog(@"Loading all level packs from %@", levelPacksPropertyListPath);
	return [NSDictionary dictionaryWithContentsOfFile:levelPacksPropertyListPath];
}

//load all available levels for a given pack
+(NSDictionary*)allLevelsInPack:(NSString*)packPath {
	NSString* mainBundlePath = [[NSBundle mainBundle] bundlePath];
	NSString* levelsPropertyListPath = [mainBundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Levels/%@/Levels.plist", packPath]];
	NSLog(@"Loading all levels from %@", levelsPropertyListPath);
	return [NSDictionary dictionaryWithContentsOfFile:levelsPropertyListPath];
}


//gets all the completed packs by the user
+(NSArray*)completedPacks {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* completedLevelPacksPropertyListPath = [rootPath stringByAppendingPathComponent:@"CompletedPacks.plist"];
	NSLog(@"Loading completed level packs from %@", completedLevelPacksPropertyListPath);
	NSDictionary* completedLevelPacksDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:completedLevelPacksPropertyListPath];
	if(completedLevelPacksPropertyListPath == nil) {
		completedLevelPacksDictionary = [[NSDictionary alloc] init];
	}
	return [completedLevelPacksDictionary objectForKey:@"CompletedPacks"];
}

//gets all the levels completed by the user
+(NSArray*)completedLevelsInPack:(NSString*)packPath {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* completedLevelsPropertyListPath = [rootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-CompletedLevels.plist", packPath]];
	NSLog(@"Loading levels the user has completed from %@", completedLevelsPropertyListPath);
	NSDictionary* completedLevelsDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:completedLevelsPropertyListPath];
	if(completedLevelsDictionary == nil) {
		completedLevelsDictionary = [[NSMutableDictionary alloc] init];
	}
	return [completedLevelsDictionary objectForKey:@"CompletedLevels"];
}



//get the list of available packs	
+(NSArray*)availablePacks {

	NSDictionary* levelPacksDictionary = [LevelPackManager allLevelPacks];
	NSArray* completedLevelPacks = [LevelPackManager completedPacks];
	NSMutableArray* availableLevelPacks = [[NSMutableArray alloc] init];

	for(int i = 0; i < levelPacksDictionary.count; i++) {

		NSDictionary* levelPackData = [levelPacksDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelPackName = [levelPackData objectForKey:@"Name"];
		NSString* requiresPack = [levelPackData objectForKey:@"RequiresPack"];
		NSNumber* requiresNumPackLevelsCompleted = [levelPackData objectForKey:@"RequiresNumPackLevelsCompleted"];

		if([completedLevelPacks containsObject:levelPackName]) {
		
			//if it's completed it's definitely available!
			[availableLevelPacks addObject:levelPackName];
			
		}else if(requiresPack == nil || [requiresPack isEqualToString:@""]) {
			//no prequisies
			[availableLevelPacks addObject:levelPackName];
			
		}else if([completedLevelPacks containsObject: requiresPack]) {
			//full required pack is completed
			[availableLevelPacks addObject:levelPackName];
			
		}else {
			//requires a completed pack - let's see if it meets the number of levels within the pack
			if(requiresNumPackLevelsCompleted == 0) {
				//no completed levels required
				[availableLevelPacks addObject:levelPackName];
				
			}else {
				NSArray* completedLevels = [LevelPackManager completedLevelsInPack:requiresPack];
				if(completedLevels.count >= [requiresNumPackLevelsCompleted intValue]) {
					[availableLevelPacks addObject:levelPackName];
				}else {
					NSLog(@"Pack %@ is not available because %d/%d levels are completed in required pack %@", levelPackName, completedLevels.count, [requiresNumPackLevelsCompleted intValue], requiresPack);
				}
			}		
		}
	}
	
	return availableLevelPacks;
}

//gets all the levels the user can play for the packs
+(NSArray*)availableLevelsInPack:(NSString*)packPath {
	
	NSDictionary* levelsDictionary = [LevelPackManager allLevelsInPack:packPath];
	NSArray* completedLevels = [LevelPackManager completedLevelsInPack:packPath];
	NSMutableArray* availableLevels = [[NSMutableArray alloc] init];
	

	int maxLevelIndex = 2;
	//find the highest completd level
	for(NSString* levelName in completedLevels) {
		maxLevelIndex++;
	}
	
	//add the 3 levels after levelsDictionary last completed level
	for(int i = 0; i < levelsDictionary.count && i <= maxLevelIndex; i++) {
		NSDictionary* levelData = [levelsDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelName = [levelData objectForKey:@"Name"];
		[availableLevels addObject:levelName];
	}
	
	return availableLevels;
}

@end
