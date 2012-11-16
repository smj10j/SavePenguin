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


-(id)init {

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
			Score* score = [_scores objectForKey:scoreTag];
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
	Score* score = [_scores objectForKey:scoresKey];
	if(score == nil) {
		score = [[Score alloc] initWithScore:value];
		[_scores setObject:score forKey:scoresKey];
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
		Score* score = [_scores objectForKey:scoreTag];
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
				([[NSDate date] timeIntervalSince1970] - [((NSNumber*)[worldScoresDictionary objectForKey:@"timestamp"]) doubleValue] > SCORE_KEEPER_UPDATE_INTERVAL)))
	{
			
		[APIManager getWorldScoresAndOnSuccess:^(NSMutableDictionary* worldScoresDictionary) {
				[worldScoresDictionary setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
			
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
	NSDictionary* worldScoresForLevel = [worldScores objectForKey:[NSString stringWithFormat:@"%@:%@", levelPackPath, levelPath]];
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
		NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString* worldScoresPropertyListPath = [rootPath stringByAppendingPathComponent:@"WorldScores.plist"];
		sWorldScoresDictionary = [[NSDictionary alloc] initWithContentsOfFile:worldScoresPropertyListPath];
		if(DEBUG_SCORING) DebugLog(@"Loaded worldScoresDictionary from local plist");
	}
	return sWorldScoresDictionary;
}

+(NSDictionary*)getWorldScores {
	NSDictionary* worldScoresDictionary = [self getWorldScoresDictionary:false];
	return [worldScoresDictionary objectForKey:@"levels"];
}

+(void)saveWorldScoresLocally:(NSDictionary*)worldScoresDictionary {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
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
				[scoreData setObject:[NSNumber numberWithInt:SCORE_KEEPER_NO_SCORE] forKey:@"score"];
				[scoreData setObject:UUID forKey:@"UUID"];
				[scoreData setObject:levelPackPath forKey:@"levelPackPath"];
				[scoreData setObject:levelPath forKey:@"levelPath"];
					
				[self addScoreDataToLocalSendQueue:scoreData];
				
				[scoreData release];				
			}
		];	
		
	}else {
		//save local queue for sending to server if we're offline
		NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
		[scoreData setObject:[NSNumber numberWithInt:SCORE_KEEPER_NO_SCORE] forKey:@"score"];
		[scoreData setObject:UUID forKey:@"UUID"];
		[scoreData setObject:levelPackPath forKey:@"levelPackPath"];
		[scoreData setObject:levelPath forKey:@"levelPath"];
			
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
				[scoreData setObject:[NSNumber numberWithInt:score] forKey:@"score"];
				[scoreData setObject:UUID forKey:@"UUID"];
				[scoreData setObject:levelPackPath forKey:@"levelPackPath"];
				[scoreData setObject:levelPath forKey:@"levelPath"];
					
				[self addScoreDataToLocalSendQueue:scoreData];
				
				[scoreData release];				
			}
		];	
		
	}else {
		//save local queue for sending to server if we're offline
		NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
		[scoreData setObject:[NSNumber numberWithInt:score] forKey:@"score"];
		[scoreData setObject:UUID forKey:@"UUID"];
		[scoreData setObject:levelPackPath forKey:@"levelPackPath"];
		[scoreData setObject:levelPath forKey:@"levelPath"];
			
		[self addScoreDataToLocalSendQueue:scoreData];
		
		[scoreData release];
	}	
}

+(void)emptyLocalSendQueue {

	if(isServerAvailable()) {
		NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString* localScoreSendQueuePropertyListPath = [rootPath stringByAppendingPathComponent:@"LocalScoreSendQueue.plist"];

		NSMutableArray* localScoreSendQueue = [NSMutableArray arrayWithContentsOfFile:localScoreSendQueuePropertyListPath];
		if(localScoreSendQueue == nil || localScoreSendQueue.count == 0) {
			return;
		}

		//write an empty array to file!
		if(![[NSArray arrayWithObjects:nil] writeToFile:localScoreSendQueuePropertyListPath atomically: YES]) {
			DebugLog(@"---- Failed to save emptied score queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
			return;
		}
		if(DEBUG_SCORING) DebugLog(@"Saved emptied send queue plist");
		
		//now iterate to empty
		if(DEBUG_SCORING) DebugLog(@"Sending %d queued scores/plays to server", localScoreSendQueue.count);
		for(NSDictionary* scoreData in localScoreSendQueue) {
			int score = [(NSNumber*)[scoreData objectForKey:@"score"] intValue];
			if(score == SCORE_KEEPER_NO_SCORE) {
				[self savePlayForUUID:[scoreData objectForKey:@"UUID"]
					levelPackPath:[scoreData objectForKey:@"levelPackPath"]
					levelPath:[scoreData objectForKey:@"levelPath"]
				];
			}else {
				[self saveScore:score
					UUID:[scoreData objectForKey:@"UUID"]
					levelPackPath:[scoreData objectForKey:@"levelPackPath"]
					levelPath:[scoreData objectForKey:@"levelPath"]
				];
			}
		}		
	}
}


+(void)addScoreDataToLocalSendQueue:(NSDictionary*)scoreData {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
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
		return @"F-";
	}else if(percentile < 15) {
		return @"F";
	}else if(percentile < 20) {
		return @"F+";
		
		
	}else if(percentile < 25) {
		return @"D-";
	}else if(percentile < 30) {
		return @"D";
	}else if(percentile < 36) {
		return @"D+";
		
		
	}else if(percentile < 42) {
		return @"C-";
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
	[zTable setObject:[NSNumber numberWithFloat:1.5] forKey:[NSNumber numberWithFloat:-2.2]];
	[zTable setObject:[NSNumber numberWithFloat:6] forKey:[NSNumber numberWithFloat:-1.6]];
	[zTable setObject:[NSNumber numberWithFloat:12] forKey:[NSNumber numberWithFloat:-1.2]];
	[zTable setObject:[NSNumber numberWithFloat:16] forKey:[NSNumber numberWithFloat:-1.0]];
	[zTable setObject:[NSNumber numberWithFloat:18] forKey:[NSNumber numberWithFloat:-0.9]];
	[zTable setObject:[NSNumber numberWithFloat:21] forKey:[NSNumber numberWithFloat:-0.8]];
	[zTable setObject:[NSNumber numberWithFloat:24] forKey:[NSNumber numberWithFloat:-0.7]];
	[zTable setObject:[NSNumber numberWithFloat:27] forKey:[NSNumber numberWithFloat:-0.6]];
	[zTable setObject:[NSNumber numberWithFloat:31] forKey:[NSNumber numberWithFloat:-0.5]];
	[zTable setObject:[NSNumber numberWithFloat:35] forKey:[NSNumber numberWithFloat:-0.4]];
	[zTable setObject:[NSNumber numberWithFloat:38] forKey:[NSNumber numberWithFloat:-0.3]];
	[zTable setObject:[NSNumber numberWithFloat:42] forKey:[NSNumber numberWithFloat:-0.2]];
	[zTable setObject:[NSNumber numberWithFloat:46] forKey:[NSNumber numberWithFloat:-0.1]];
	[zTable setObject:[NSNumber numberWithFloat:50] forKey:[NSNumber numberWithFloat:0.0]];
				
	[zTable setObject:[NSNumber numberWithFloat:54] forKey:[NSNumber numberWithFloat:0.1]];
	[zTable setObject:[NSNumber numberWithFloat:58] forKey:[NSNumber numberWithFloat:0.2]];
	[zTable setObject:[NSNumber numberWithFloat:62] forKey:[NSNumber numberWithFloat:0.3]];
	[zTable setObject:[NSNumber numberWithFloat:65] forKey:[NSNumber numberWithFloat:0.4]];
	[zTable setObject:[NSNumber numberWithFloat:69] forKey:[NSNumber numberWithFloat:0.5]];
	[zTable setObject:[NSNumber numberWithFloat:72] forKey:[NSNumber numberWithFloat:0.6]];
	[zTable setObject:[NSNumber numberWithFloat:76] forKey:[NSNumber numberWithFloat:0.7]];
	[zTable setObject:[NSNumber numberWithFloat:79] forKey:[NSNumber numberWithFloat:0.8]];
	[zTable setObject:[NSNumber numberWithFloat:82] forKey:[NSNumber numberWithFloat:0.9]];
	[zTable setObject:[NSNumber numberWithFloat:84] forKey:[NSNumber numberWithFloat:1.0]];
	[zTable setObject:[NSNumber numberWithFloat:86] forKey:[NSNumber numberWithFloat:1.1]];
	[zTable setObject:[NSNumber numberWithFloat:88] forKey:[NSNumber numberWithFloat:1.2]];
	[zTable setObject:[NSNumber numberWithFloat:90] forKey:[NSNumber numberWithFloat:1.3]];
	[zTable setObject:[NSNumber numberWithFloat:92] forKey:[NSNumber numberWithFloat:1.4]];
	[zTable setObject:[NSNumber numberWithFloat:93] forKey:[NSNumber numberWithFloat:1.5]];
	[zTable setObject:[NSNumber numberWithFloat:94] forKey:[NSNumber numberWithFloat:1.6]];
	[zTable setObject:[NSNumber numberWithFloat:95] forKey:[NSNumber numberWithFloat:1.7]];
	[zTable setObject:[NSNumber numberWithFloat:96] forKey:[NSNumber numberWithFloat:1.8]];
	[zTable setObject:[NSNumber numberWithFloat:97] forKey:[NSNumber numberWithFloat:1.9]];
	[zTable setObject:[NSNumber numberWithFloat:97.5] forKey:[NSNumber numberWithFloat:2.0]];
	[zTable setObject:[NSNumber numberWithFloat:98] forKey:[NSNumber numberWithFloat:2.1]];
	[zTable setObject:[NSNumber numberWithFloat:99] forKey:[NSNumber numberWithFloat:2.2]];
	
	
	float cumulScore = 0;
	float totalScalars = 0;
	for(NSNumber* zScoreKey in zTable) {
		float aZScore = [zScoreKey floatValue];
		float percentile = [(NSNumber*)[zTable objectForKey:zScoreKey] floatValue];
		
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
		int worldScoreMean = [(NSNumber*)[worldScores objectForKey:@"scoreMean"] intValue];
		int worldScoreStdDev = [(NSNumber*)[worldScores objectForKey:@"scoreStdDev"] intValue];
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
