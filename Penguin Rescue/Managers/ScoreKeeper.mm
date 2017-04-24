//
//  ScoreKeeper.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "ScoreKeeper.h"
#import "Utilities.h"
#import "APIManager.h"
#import "LevelPackManager.h"

@implementation ScoreKeeper


-(instancetype)init {

	if(self = [super init]) {
	
		_scores = [[NSMutableDictionary alloc] init];
		
		[ScoreKeeper updateWorldScoresFromServer:false];
		
		//now send any queued up scores from when we may have been offline
		[ScoreKeeper emptyLocalSendQueue];
		
	}

	return self;
}




-(int)numberOfScoresInCategory:(NSString*)category {
	int count = 0;
	for(NSString* scoreTag in _scores) {
		if([scoreTag hasPrefix:category]) {
			Score* score = _scores[scoreTag];
			count+= score.count;
		}
	}
	return count;
}

-(bool)addScore:(int)value category:(NSString*)category tag:(NSString*)tag group:(bool)group {
	return [self addScore:value category:category tag:tag group:group unique:NO];
}

-(bool)addScore:(int)value category:(NSString*)category tag:(NSString*)tag group:(bool)group unique:(bool)unique {

	NSString* scoresKey = [NSString stringWithFormat:@"%@-%@-%@", (category != nil ? category : @""), tag, (group ? @"" : [NSString stringWithFormat:@"%d", arc4random()%100000])];
	Score* score = _scores[scoresKey];
	if(score == nil) {
		score = [[Score alloc] initWithScore:value];
		_scores[scoresKey] = score;
		if(DEBUG_SCORING) DebugLog(@"Adding score %d for scoreKey: %@", value, scoresKey);
		[score release];
		return true;
	}else {
		if(unique) {
			if(DEBUG_SCORING) DebugLog(@"Adding to unique score %d +%d for scoreKey: %@", score.score, value, scoresKey);
			score.score+= value;
			return false;
		}else {
			score.count++;
			if(DEBUG_SCORING) DebugLog(@"Incrementing count to %d for score %d for scoreKey: %@", score.count, score.score, scoresKey);
			return true;
		}
	}
}

-(int)totalScore {
	int total = 0;
	for(NSString* scoreTag in _scores) {
		Score* score = _scores[scoreTag];
		total+= score.count * score.score;
	}
	return total;
}








/*
	Response Format
	{
		levels: {
			"<levelPackPath as string>:<levelPath as string>": {
				uniquePlays: <int>,
				uniqueWins: <int>,
				scoreMean: <int>,
				scoreMedian: <int>,
				scoreStdDev: <int>
			}
		
		}
	}
	
	PList Format
	{
		timestamp = <seconds as double>;
		levels = {
			"<levelPackPath as string>:<levelPath as string>" = {
				uniquePlays = <int>;
				uniqueWins = <int>;
				scoreMean = <int>;
				scoreMedian = <int>;
				scoreStdDev = <int>;
			};
		};
	
		...
		
	}

*/

+(void)updateWorldScoresFromServer:(bool)force {

	NSDictionary* worldScoresDictionary = [self getWorldScoresDictionary:false];
		
	//if we have no world scores data or the last time it was updated was over 12 hours ago, request form the server
	if(	isServerAvailable() && (
				force ||
				//DEBUG_SCORING ||
				worldScoresDictionary == nil ||
				([NSDate date].timeIntervalSince1970 - ((NSNumber*)worldScoresDictionary[@"timestamp"]).doubleValue > SCORE_KEEPER_UPDATE_INTERVAL)))
	{
			
		[APIManager getWorldScoresAndOnSuccess:^(NSMutableDictionary* worldScoresDictionary) {
				worldScoresDictionary[@"timestamp"] = @([NSDate date].timeIntervalSince1970);
			
				if(DEBUG_SCORING) DebugLog(@"Loaded world scores data from server: %@", worldScoresDictionary);
			
				[self saveWorldScoresLocally:worldScoresDictionary];			
			}
			onError:^(NSError* error) {
				if(DEBUG_SCORING) DebugLog(@"Error retrieving world scores from server: %@", error.localizedDescription);
			}
		];			
		
	}else {
		if(DEBUG_SCORING) DebugLog(@"Using world scores data from local plist: %@", worldScoresDictionary);
	}
}


+(NSDictionary*)worldScoresForLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	NSDictionary* worldScores = [self getWorldScores];
	NSDictionary* worldScoresForLevel = worldScores[[NSString stringWithFormat:@"%@:%@", levelPackPath, levelPath]];
	if(worldScoresForLevel == nil) {
		//we need an update - this shouldn't really happen in production
		if(DEBUG_SCORING) DebugLog(@"Forcing a sWorldScoresDictionary update from the server because we couldn't find an entry for levelPackPath=%@, levelPath=%@", levelPackPath,levelPath);
		[self updateWorldScoresFromServer:true];
	}
	return worldScoresForLevel;
}

+(NSDictionary*)getWorldScoresDictionary:(bool)forceReloadFromDisk {
	static NSDictionary* sWorldScoresDictionary = nil;
	if(sWorldScoresDictionary == nil || forceReloadFromDisk) {
		NSString* rootPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
		NSString* worldScoresPropertyListPath = [rootPath stringByAppendingPathComponent:@"WorldScores.plist"];
		sWorldScoresDictionary = [[NSDictionary alloc] initWithContentsOfFile:worldScoresPropertyListPath];
		if(DEBUG_SCORING) DebugLog(@"Loaded worldScoresDictionary from local plist");
	}
	return sWorldScoresDictionary;
}

+(NSDictionary*)getWorldScores {
	NSDictionary* worldScoresDictionary = [self getWorldScoresDictionary:false];
	return worldScoresDictionary[@"levels"];
}

+(void)saveWorldScoresLocally:(NSDictionary*)worldScoresDictionary {
	NSString* rootPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
	NSString* worldScoresPropertyListPath = [rootPath stringByAppendingPathComponent:@"WorldScores.plist"];
	
	//write to file!
	if(![worldScoresDictionary writeToFile:worldScoresPropertyListPath atomically: YES]) {
        DebugLog(@"---- Failed to save world scores in local plist!! - %@: %@ -----", worldScoresPropertyListPath, worldScoresDictionary);
        return;
    }
	if(DEBUG_SCORING) DebugLog(@"Saved world scores in local plist");
	[self getWorldScoresDictionary:true];
}

+(void)savePlayForUUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	
	if(isServerAvailable()) {
					
		//send score to server
		[APIManager savePlayForUserWithUUID:UUID levelPackPath:levelPackPath levelPath:levelPath
			onSuccess:^(NSDictionary* response) {
				if(DEBUG_SCORING) DebugLog(@"Sent play data to server. response = %@", response);
				
				//now send any queued up scores from when we may have been offline
				[self emptyLocalSendQueue];	
			}
			onError:^(NSError* error) {
				if(DEBUG_SCORING) DebugLog(@"Error posting play data to server: %@", error.localizedDescription);
				
				//save local queue for sending to server later
				NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
				scoreData[@"score"] = @SCORE_KEEPER_NO_SCORE;
				scoreData[@"UUID"] = UUID;
				scoreData[@"levelPackPath"] = levelPackPath;
				scoreData[@"levelPath"] = levelPath;
					
				[self addScoreDataToLocalSendQueue:scoreData];
				
				[scoreData release];				
			}
		];	
		
	}else {
		//save local queue for sending to server if we're offline
		NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
		scoreData[@"score"] = @SCORE_KEEPER_NO_SCORE;
		scoreData[@"UUID"] = UUID;
		scoreData[@"levelPackPath"] = levelPackPath;
		scoreData[@"levelPath"] = levelPath;
			
		[self addScoreDataToLocalSendQueue:scoreData];
		
		[scoreData release];
	}
}

+(void)saveScore:(int)score UUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	
	if(isServerAvailable()) {
					
		//send score to server
		[APIManager saveScoreForUserWithUUID:UUID score:score levelPackPath:levelPackPath levelPath:levelPath
			onSuccess:^(NSDictionary* response) {
				if(DEBUG_SCORING) DebugLog(@"Sent score data to server. response = %@", response);
				
				//now send any queued up scores from when we may have been offline
				[self emptyLocalSendQueue];			
			}
			onError:^(NSError* error) {
				if(DEBUG_SCORING) DebugLog(@"Error posting score data to server: %@", error.localizedDescription);
				
				//save local queue for sending to server later
				NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
				scoreData[@"score"] = @(score);
				scoreData[@"UUID"] = UUID;
				scoreData[@"levelPackPath"] = levelPackPath;
				scoreData[@"levelPath"] = levelPath;
					
				[self addScoreDataToLocalSendQueue:scoreData];
				
				[scoreData release];				
			}
		];	
		
	}else {
		//save local queue for sending to server if we're offline
		NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
		scoreData[@"score"] = @(score);
		scoreData[@"UUID"] = UUID;
		scoreData[@"levelPackPath"] = levelPackPath;
		scoreData[@"levelPath"] = levelPath;
			
		[self addScoreDataToLocalSendQueue:scoreData];
		
		[scoreData release];
	}	
}

+(void)emptyLocalSendQueue {

	if(isServerAvailable()) {
		NSString* rootPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
		NSString* localScoreSendQueuePropertyListPath = [rootPath stringByAppendingPathComponent:@"LocalScoreSendQueue.plist"];

		NSMutableArray* localScoreSendQueue = [NSMutableArray arrayWithContentsOfFile:localScoreSendQueuePropertyListPath];
		if(localScoreSendQueue == nil || localScoreSendQueue.count == 0) {
			return;
		}

		//write an empty array to file!
		if(![@[] writeToFile:localScoreSendQueuePropertyListPath atomically: YES]) {
			DebugLog(@"---- Failed to save emptied score queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
			return;
		}
		if(DEBUG_SCORING) DebugLog(@"Saved emptied send queue plist");
		
		//now iterate to empty
		if(DEBUG_SCORING) DebugLog(@"Sending %d queued scores/plays to server", localScoreSendQueue.count);
		for(NSDictionary* scoreData in localScoreSendQueue) {
			int score = ((NSNumber*)scoreData[@"score"]).intValue;
			if(score == SCORE_KEEPER_NO_SCORE) {
				[self savePlayForUUID:scoreData[@"UUID"]
					levelPackPath:scoreData[@"levelPackPath"]
					levelPath:scoreData[@"levelPath"]
				];
			}else {
				[self saveScore:score
					UUID:scoreData[@"UUID"]
					levelPackPath:scoreData[@"levelPackPath"]
					levelPath:scoreData[@"levelPath"]
				];
			}
		}		
	}
}


+(void)addScoreDataToLocalSendQueue:(NSDictionary*)scoreData {
	NSString* rootPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
	NSString* localScoreSendQueuePropertyListPath = [rootPath stringByAppendingPathComponent:@"LocalScoreSendQueue.plist"];

	NSMutableArray* localScoreSendQueue = [[NSMutableArray alloc] initWithContentsOfFile:localScoreSendQueuePropertyListPath];
	if(localScoreSendQueue == nil) {
		localScoreSendQueue = [[NSMutableArray alloc] init];
	}
	[localScoreSendQueue addObject:scoreData];
	
	//write to file!
	if(![localScoreSendQueue writeToFile:localScoreSendQueuePropertyListPath atomically: YES]) {
        DebugLog(@"---- Failed to save local score to send queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
		[localScoreSendQueue release];
        return;
    }
	[localScoreSendQueue release];
	if(DEBUG_SCORING) DebugLog(@"Added local score (score=%d) to send queue plist", [(NSNumber*)[scoreData objectForKey:@"score"] intValue]);
}










+(NSString*)gradeFromZScore:(double)zScore {

	int percentile = [self percentileFromZScore:zScore];


	if(percentile < 10) {
		return @"C";
	}else if(percentile < 15) {
		return @"C";
	}else if(percentile < 20) {
		return @"C";
		
		
	}else if(percentile < 25) {
		return @"C";
	}else if(percentile < 30) {
		return @"C";
	}else if(percentile < 36) {
		return @"C";
		
		
	}else if(percentile < 42) {
		return @"C";
	}else if(percentile < 47) {
		return @"C";
	}else if(percentile < 52) {
		return @"C+";
		
		
	}else if(percentile < 58) {
		return @"B-";
	}else if(percentile < 65) {
		return @"B";
	}else if(percentile < 74) {
		return @"B+";
		
		
	}else if(percentile < 84) {
		return @"A-";
	}else if(percentile < 89) {
		return @"A";
	}else if(percentile < 94) {
		return @"A+";
	}else if(percentile < 97) {
		return @"A++";
		
		
	}else {
		return @"A+++";
	}

}


+(int)coinsForZScore:(double)zScore {

	int percentile = [self percentileFromZScore:zScore];

	if(percentile < 36) {
		return 1;
		
		
	}else if(percentile < 55) {
		return 2;

		
	}else if(percentile < 74) {
		return 3;
		
		
	}else if(percentile < 89) {
		return 4;
	

	}else {
		return SCORING_MAX_COINS_PER_LEVEL;
	}	
}



+(int)percentileFromZScore:(double)zScore {
	
	if(zScore < -2.2) {
		if(DEBUG_SCORING) DebugLog(@"With zScore=%f we found percentile=%d", zScore, 0);
		return 0;
	}else if(zScore > 2.2) {
		if(DEBUG_SCORING) DebugLog(@"With zScore=%f we found percentile=%d", zScore, 100);
		return 100;
	}	
	
	NSMutableDictionary* zTable = [[NSMutableDictionary alloc] init];
	zTable[@-2.2f] = @1.5f;
	zTable[@-1.6f] = @6.0f;
	zTable[@-1.2f] = @12.0f;
	zTable[@-1.0f] = @16.0f;
	zTable[@-0.9f] = @18.0f;
	zTable[@-0.8f] = @21.0f;
	zTable[@-0.7f] = @24.0f;
	zTable[@-0.6f] = @27.0f;
	zTable[@-0.5f] = @31.0f;
	zTable[@-0.4f] = @35.0f;
	zTable[@-0.3f] = @38.0f;
	zTable[@-0.2f] = @42.0f;
	zTable[@-0.1f] = @46.0f;
	zTable[@0.0f] = @50.0f;
				
	zTable[@0.1f] = @54.0f;
	zTable[@0.2f] = @58.0f;
	zTable[@0.3f] = @62.0f;
	zTable[@0.4f] = @65.0f;
	zTable[@0.5f] = @69.0f;
	zTable[@0.6f] = @72.0f;
	zTable[@0.7f] = @76.0f;
	zTable[@0.8f] = @79.0f;
	zTable[@0.9f] = @82.0f;
	zTable[@1.0f] = @84.0f;
	zTable[@1.1f] = @86.0f;
	zTable[@1.2f] = @88.0f;
	zTable[@1.3f] = @90.0f;
	zTable[@1.4f] = @92.0f;
	zTable[@1.5f] = @93.0f;
	zTable[@1.6f] = @94.0f;
	zTable[@1.7f] = @95.0f;
	zTable[@1.8f] = @96.0f;
	zTable[@1.9f] = @97.0f;
	zTable[@2.0f] = @97.5f;
	zTable[@2.1f] = @98.0f;
	zTable[@2.2f] = @99.0f;
	
	
	float cumulScore = 0;
	float totalScalars = 0;
	for(NSNumber* zScoreKey in zTable) {
		float aZScore = zScoreKey.floatValue;
		float percentile = ((NSNumber*)zTable[zScoreKey]).floatValue;
		
		float scalar = zScore == aZScore ? 1000 : fmin(1.0/fabs(zScore-aZScore), 1000);
		cumulScore+= (scalar * percentile);
		totalScalars+= scalar;
	}
	cumulScore/= totalScalars;
	
	if(DEBUG_SCORING) DebugLog(@"With zScore=%f we found percentile=%d", zScore, (int)cumulScore);
	
	[zTable release];
	
	return (int)cumulScore;
}

+(double)zScoreFromScore:(double)score withLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	//get the world numbers from the server
	NSDictionary* worldScores = [ScoreKeeper worldScoresForLevelPackPath:levelPackPath levelPath:levelPath];
	if(worldScores != nil) {
		int worldScoreMean = ((NSNumber*)worldScores[@"scoreMean"]).intValue;
		int worldScoreStdDev = ((NSNumber*)worldScores[@"scoreStdDev"]).intValue;
		double zScore = ((score - worldScoreMean) / (1.0f*(worldScoreStdDev > 0 ? worldScoreStdDev : 1)));
		return zScore;
	}else {
		return 0.35;	//feel good score until data comes in
	}
}











-(void)dealloc {
	[_scores release];
	[super dealloc];
}


@end
