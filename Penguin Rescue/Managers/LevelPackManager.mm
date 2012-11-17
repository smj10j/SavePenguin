//
//  LevelPackManager.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/24/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "Constants.h"
#import "LevelPackManager.h"
#import "SettingsManager.h"

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

static NSDictionary* sCompletedLevelPacksDictionary = nil;
static NSMutableDictionary* sCompletedLevelsInPackDictionary = nil;


@implementation LevelPackManager


//fetch all available level packs
+(NSDictionary*)allLevelPacks {
	static NSDictionary* sLevelPacksDictionary = nil;
	if(sLevelPacksDictionary == nil) {
		NSString* levelPacksPropertyListPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Levels/Packs.plist"];
		sLevelPacksDictionary = [[NSDictionary alloc] initWithContentsOfFile:levelPacksPropertyListPath];
		if(DEBUG_LEVELS) DebugLog(@"Loading all level packs");
	}
	return sLevelPacksDictionary;
}

//load all available levels for a given pack
+(NSDictionary*)allLevelsInPack:(NSString*)packPath {
	static NSMutableDictionary* sLevelsDictionary = nil;
	if(sLevelsDictionary == nil) {
		sLevelsDictionary = [[NSMutableDictionary alloc] init];
	}
	
	NSDictionary* levelDictionary = [sLevelsDictionary objectForKey:packPath];
	if(levelDictionary == nil) {
		NSString* levelPropertyListPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"Levels/%@/Levels.plist", packPath]];
		levelDictionary = [NSDictionary dictionaryWithContentsOfFile:levelPropertyListPath];
		[sLevelsDictionary setObject:levelDictionary forKey:packPath];
		if(DEBUG_LEVELS) DebugLog(@"Loading all levels in pack %@", packPath);
	}
	return levelDictionary;
}


//gets all the completed packs by the user
+(NSArray*)completedPacks {
	if(sCompletedLevelPacksDictionary == nil) {
		NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString* completedLevelPacksPropertyListPath = [rootPath stringByAppendingPathComponent:@"CompletedPacks.plist"];
		if(DEBUG_LEVELS) DebugLog(@"Loading completed level packs");
		sCompletedLevelPacksDictionary = [[NSDictionary alloc] initWithContentsOfFile:completedLevelPacksPropertyListPath];
		if(sCompletedLevelPacksDictionary == nil) {
			sCompletedLevelPacksDictionary = [[NSDictionary alloc] init];
		}
	}
	return [sCompletedLevelPacksDictionary objectForKey:LEVELPACKMANAGER_KEY_USER_COMPLETED_PACKS];
}

//gets all the levels completed by the user
+(NSDictionary*)completedLevelsInPack:(NSString*)packPath {
	if(sCompletedLevelsInPackDictionary == nil) {
		sCompletedLevelsInPackDictionary = [[NSMutableDictionary alloc] init];
	}
	
	NSDictionary* completedLevelsDictionary = [sCompletedLevelsInPackDictionary objectForKey:packPath];
	if(completedLevelsDictionary == nil) {
		NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString* completedLevelsPropertyListPath = [rootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-CompletedLevels.plist", packPath]];
		completedLevelsDictionary = [NSDictionary dictionaryWithContentsOfFile:completedLevelsPropertyListPath];
		if(completedLevelsDictionary == nil) {
			completedLevelsDictionary = [NSDictionary dictionaryWithDictionary:nil];//could use alloc but this is used for consistency with other parts of the code have elements within static dictionaries auto-managed
		}
		[sCompletedLevelsInPackDictionary setObject:completedLevelsDictionary forKey:packPath];
		if(DEBUG_LEVELS) DebugLog(@"Loading completed levels in pack %@", packPath);
	}
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
+(void)completeLevel:(NSString*)levelPath inPack:(NSString*)packPath withScore:(int)score {
	
	int numLevelsCompleted = [SettingsManager incrementIntBy:1 forKey:SETTING_NUM_LEVELS_COMPLETED];
	
	//create the completed levels array
	NSMutableDictionary* completedLevelsDictionary = [NSMutableDictionary dictionaryWithDictionary:[LevelPackManager completedLevelsInPack:packPath]];
	if([completedLevelsDictionary valueForKey:levelPath] != nil) {
		int prevScore = [(NSNumber*)[completedLevelsDictionary valueForKey:levelPath] intValue];
		if(prevScore > score) {
			if(DEBUG_LEVELS) DebugLog(@"Level %@ in pack %@ already completed with higher score %d > %d", levelPath, packPath, prevScore, score);
			return;
		}
	}
	[completedLevelsDictionary setObject:[NSNumber numberWithDouble:score] forKey:levelPath];
				
	//put it into the dictionary
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* completedLevelsPropertyListPath = [rootPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-CompletedLevels.plist", packPath]];
	
	//write to file!
	if(![completedLevelsDictionary writeToFile:completedLevelsPropertyListPath atomically: YES]) {
        DebugLog(@"---- Failed to save level completion!! - %@ -----", completedLevelsPropertyListPath);
        return;
    }
	if(DEBUG_LEVELS) DebugLog(@"Marked level %@ in pack %@ as completed", levelPath, packPath);
	sCompletedLevelsInPackDictionary = nil;
	
	//save the pack as being completed if necessary
	NSDictionary* allLevelsInPack = [LevelPackManager allLevelsInPack:packPath];
	if(completedLevelsDictionary.count == allLevelsInPack.count) {
		[LevelPackManager completePack:packPath];
		
	}else {
		//see if we should prompt for a review
		if(![[SettingsManager stringForKey:SETTING_LEFT_REVIEW_VERSION] isEqualToString:[SettingsManager stringForKey:SETTING_CURRENT_VERSION]]) {
			//hasn't reviewed this version
			if(numLevelsCompleted % LEVELPACKMAANGER_LEVELS_COMPLETED_REVIEW_PROMPT_INTERVAL == 0) {
				if(DEBUG_REVIEWS) DebugLog(@"PROMPTING FOR AN LEVEL COMPLETED REVIEW!!!");
				[SettingsManager promptForAppReview];
			}
		}
	}
}

//private - completes a pack
+(void)completePack:(NSString*)packPath {

	//create the completed levels array
	NSMutableArray* completedPacks = [NSMutableArray arrayWithArray:[LevelPackManager completedPacks]];
	if([completedPacks containsObject:packPath]) {
		if(DEBUG_LEVELS) DebugLog(@"Pack %@ already completed", packPath);
		return;
	}
	[completedPacks addObject:packPath];
	
	//put it into the dictionary
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* completedLevelPacksPropertyListPath = [rootPath stringByAppendingPathComponent:@"CompletedPacks.plist"];
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
	if(DEBUG_LEVELS) DebugLog(@"Marked pack %@ as completed", packPath);
	sCompletedLevelPacksDictionary = nil;
	
	
	if([SettingsManager intForKey:SETTING_NUM_REVIEW_PROMPTS] == 0) {
		//hasn't left a review and just completed a pack - prompt!
		if(DEBUG_REVIEWS) DebugLog(@"PROMPTING FOR A FIRST-TIME REVIEW!!!");
		[SettingsManager promptForAppReview];
	}else if(![[SettingsManager stringForKey:SETTING_LEFT_REVIEW_VERSION] isEqualToString:[SettingsManager stringForKey:SETTING_CURRENT_VERSION]]) {
		//hasn't reviewed this version
		if(DEBUG_REVIEWS) DebugLog(@"PROMPTING FOR AN UPDATE REVIEW!!!");
		[SettingsManager promptForAppReview];
	}
}


+(NSNumber*)scoreForLevel:(NSString*)levelPath inPack:(NSString*)packPath {
	NSMutableDictionary* completedLevelsDictionary = [NSMutableDictionary dictionaryWithDictionary:[LevelPackManager completedLevelsInPack:packPath]];
	return [completedLevelsDictionary valueForKey:levelPath];
}


//returns the level after the given one. if no next leve, returns nil
+(NSString*)levelAfter:(NSString*)levelPath inPack:(NSString*)packPath {
	NSDictionary* levelsDictionary = [LevelPackManager allLevelsInPack:packPath];
	bool returnNextLevel = levelPath == nil;
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
