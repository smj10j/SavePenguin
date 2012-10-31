//
//  LevelPackManager.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/24/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "Constants.h"
#import "LevelPackManager.h"

static NSString* sMainBundlePath;
static NSString* sRootPath;


		//TODO: implement loading/saving the level and pack completion state files to iCloud: http://www.raywenderlich.com/6015/beginning-icloud-in-ios-5-tutorial-part-1
		/*
		NSURL *ubiq = [[NSFileManager defaultManager] URLForUbiquityContainerIdentifier:nil];
		if (ubiq) {
			DebugLog(@"iCloud access at %@", ubiq);
			_iCloudPath = ubiq;
		}else {
			DebugLog(@"No iCloud access");
			_iCloudPath = nil;
		}
		*/


@implementation LevelPackManager

+(void)setupPaths {
	sMainBundlePath = [[NSBundle mainBundle] bundlePath];
	sRootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

//fetch all available level packs
+(NSDictionary*)allLevelPacks {
	[LevelPackManager setupPaths];
	NSString* levelPacksPropertyListPath = [sMainBundlePath stringByAppendingPathComponent:@"Levels/Packs.plist"];
	//DebugLog(@"Loading all level packs");
	return [NSDictionary dictionaryWithContentsOfFile:levelPacksPropertyListPath];
}

//load all available levels for a given pack
+(NSDictionary*)allLevelsInPack:(NSString*)packPath {
	[LevelPackManager setupPaths];
	NSString* levelsPropertyListPath = [sMainBundlePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Levels/%@/Levels.plist", packPath]];
	//DebugLog(@"Loading all levels in pack %@", packPath);
	return [NSDictionary dictionaryWithContentsOfFile:levelsPropertyListPath];
}


//gets all the completed packs by the user
+(NSArray*)completedPacks {
	[LevelPackManager setupPaths];
	NSString* completedLevelPacksPropertyListPath = [sRootPath stringByAppendingPathComponent:@"CompletedPacks.plist"];
	//DebugLog(@"Loading completed level packs");
	NSDictionary* completedLevelPacksDictionary = [NSDictionary dictionaryWithContentsOfFile:completedLevelPacksPropertyListPath];
	if(completedLevelPacksPropertyListPath == nil) {
		return nil;
	}
	return [completedLevelPacksDictionary objectForKey:LEVELPACKMANAGER_KEY_USER_COMPLETED_PACKS];
}

//gets all the levels completed by the user
+(NSDictionary*)completedLevelsInPack:(NSString*)packPath {
	[LevelPackManager setupPaths];
	NSString* completedLevelsPropertyListPath = [sRootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-CompletedLevels.plist", packPath]];
	//DebugLog(@"Loading completed levels in pack %@", packPath);
	NSDictionary* completedLevelsDictionary = [NSDictionary dictionaryWithContentsOfFile:completedLevelsPropertyListPath];
	return completedLevelsDictionary;
}



//get the list of available packs	
+(NSArray*)availablePacks {

	NSDictionary* levelPacksDictionary = [LevelPackManager allLevelPacks];
	NSArray* completedLevelPacks = [LevelPackManager completedPacks];
	NSMutableArray* availableLevelPacks = [[NSMutableArray alloc] init];

	for(int i = 0; i < levelPacksDictionary.count; i++) {

		NSDictionary* levelPackData = [levelPacksDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelPackPath = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_PATH];
		NSString* requiresPack = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_REQUIRES_PACK];
		NSNumber* requiresNumPackLevelsCompleted = [levelPackData objectForKey:LEVELPACKMANAGER_KEY_REQUIRES_NUM_PACK_LEVELS_COMPLETED];

		if([completedLevelPacks containsObject:levelPackPath]) {
		
			//if it's completed it's definitely available!
			[availableLevelPacks addObject:levelPackPath];
			
		}else if(requiresPack == nil || [requiresPack isEqualToString:@""]) {
			//no prequisites
			[availableLevelPacks addObject:levelPackPath];
			
		}else if([completedLevelPacks containsObject: requiresPack]) {
			//required pack is 100% completed
			[availableLevelPacks addObject:levelPackPath];
			
		}else {
			//requires a a fully or partially completed pack - let's see if we meet the number of levels required within the required pack
			if(requiresNumPackLevelsCompleted == 0) {
				//0 means 100% required, so let's not add it
				//DebugLog(@"Pack %@ is not available because not 100%% of levels are completed in required pack %@", levelPackPath, requiresPack);
				
			}else {
				NSDictionary* completedLevelsDictionary = [LevelPackManager completedLevelsInPack:requiresPack];
				if(completedLevelsDictionary.count >= [requiresNumPackLevelsCompleted intValue]) {
					[availableLevelPacks addObject:levelPackPath];
				}else {
					//DebugLog(@"Pack %@ is not available because %d/%d levels are completed in required pack %@", levelPackPath, completedLevels.count, [requiresNumPackLevelsCompleted intValue], requiresPack);
				}
			}		
		}
	}
	
	return availableLevelPacks;
}

//gets all the levels the user can play for the packs
+(NSArray*)availableLevelsInPack:(NSString*)packPath {
	
	NSDictionary* levelsDictionary = [LevelPackManager allLevelsInPack:packPath];
	NSDictionary* completedLevelsDictionary = [LevelPackManager completedLevelsInPack:packPath];
	NSMutableArray* availableLevels = [[NSMutableArray alloc] init];
	

	int maxLevelIndex = 2;
	//find the highest completd level
	for(NSString* levelPath in completedLevelsDictionary) {
		maxLevelIndex++;
	}
	
	//DebugLog(@"Making available up to level %d in pack %@", maxLevelIndex, packPath);
	//add the 3 levels after levelsDictionary last completed level
	for(int i = 0; i < levelsDictionary.count && i <= maxLevelIndex; i++) {
		NSDictionary* levelData = [levelsDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		NSString* levelPath = [levelData objectForKey:LEVELPACKMANAGER_KEY_PATH];
		[availableLevels addObject:levelPath];
	}
	
	return availableLevels;
}


//returns level information
+(NSDictionary*)level:(NSString*)levelPath inPack:(NSString*)packPath {
	[LevelPackManager setupPaths];

	NSDictionary* levelsDictionary = [LevelPackManager allLevelsInPack:packPath];
	for(int i = 0; i < levelsDictionary.count; i++) {
		NSDictionary* levelData = [levelsDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		
		if([levelPath isEqualToString:[levelData objectForKey:LEVELPACKMANAGER_KEY_PATH]]) {
			return levelData;
		}
	}
	return nil;
}





//completes a level and, if necessary, the pack
+(void)completeLevel:(NSString*)levelPath inPack:(NSString*)packPath withZScore:(double)zScore {
	
	[LevelPackManager setupPaths];

	//create the completed levels array
	NSMutableDictionary* completedLevelsDictionary = [NSMutableDictionary dictionaryWithDictionary:[LevelPackManager completedLevelsInPack:packPath]];
	if([completedLevelsDictionary valueForKey:levelPath] != nil) {
		double prevZScore = [(NSNumber*)[completedLevelsDictionary valueForKey:levelPath] doubleValue];
		if(prevZScore > zScore) {
			DebugLog(@"Level %@ in pack %@ already completed with higher zScore %f > %f", levelPath, packPath, prevZScore, zScore);
			return;
		}
	}
	[completedLevelsDictionary setObject:[NSNumber numberWithDouble:zScore] forKey:levelPath];
				
	//put it into the dictionary
	NSString* completedLevelsPropertyListPath = [sRootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-CompletedLevels.plist", packPath]];
	
	//write to file!
	if(![completedLevelsDictionary writeToFile:completedLevelsPropertyListPath atomically: YES]) {
        DebugLog(@"---- Failed to save level completion!! - %@ -----", completedLevelsPropertyListPath);
        return;
    }
	DebugLog(@"Marked level %@ in pack %@ as completed", levelPath, packPath);
	
	//save the pack as being completed if necessary
	NSDictionary* allLevelsInPack = [LevelPackManager allLevelsInPack:packPath];
	if(completedLevelsDictionary.count == allLevelsInPack.count) {
		[LevelPackManager completePack:packPath];
	}
}

//private - completes a pack
+(void)completePack:(NSString*)packPath {

	[LevelPackManager setupPaths];

	//create the completed levels array
	NSMutableArray* completedPacks = [NSMutableArray arrayWithArray:[LevelPackManager completedPacks]];
	if([completedPacks containsObject:packPath]) {
		DebugLog(@"Pack %@ already completed", packPath);
		return;
	}
	[completedPacks addObject:packPath];
	
	//put it into the dictionary
	NSString* completedLevelPacksPropertyListPath = [sRootPath stringByAppendingPathComponent:@"CompletedPacks.plist"];
	NSMutableDictionary* completedLevelPacksDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:completedLevelPacksPropertyListPath];
	if(completedLevelPacksDictionary == nil) {
		completedLevelPacksDictionary = [[NSMutableDictionary alloc] init];
	}
	[completedLevelPacksDictionary setObject:completedPacks forKey:LEVELPACKMANAGER_KEY_USER_COMPLETED_PACKS];
	
	//write to file!
	if(![completedLevelPacksDictionary writeToFile:completedLevelPacksPropertyListPath atomically: YES]) {
        DebugLog(@"---- Failed to save level pack completion!! - %@ -----", completedLevelPacksPropertyListPath);
        return;
    }
	DebugLog(@"Marked pack %@ as completed", packPath);
}



//returns the level after the given one. if no next leve, returns nil
+(NSString*)levelAfter:(NSString*)levelPath inPack:(NSString*)packPath {
	NSDictionary* levelsDictionary = [LevelPackManager allLevelsInPack:packPath];
	bool returnNextLevel = false;
	for(int i = 0; i < levelsDictionary.count; i++) {
		NSDictionary* levelData = [levelsDictionary objectForKey:[NSString stringWithFormat:@"%d", i]];
		
		if(returnNextLevel) {
			NSString* levelPath = [levelData objectForKey:LEVELPACKMANAGER_KEY_PATH];
			return levelPath;
		}
		
		if([levelPath isEqualToString:[levelData objectForKey:LEVELPACKMANAGER_KEY_PATH]]) {
			returnNextLevel = true;
		}
	}
	return nil;
}

@end
