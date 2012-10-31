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

-(void)addScore:(int)value description:(NSString*)tag sprite:(LHSprite*)sprite group:(bool)group {

	NSString* scoresKey = [NSString stringWithFormat:@"%@-%@-%@", tag, (sprite != nil ? sprite.userInfoClassName : @""), (group ? @"" : [NSString stringWithFormat:@"%d", arc4random()%100000])];
	Score* score = [_scores objectForKey:scoresKey];
	if(score == nil) {
		score = [[Score alloc] initWithScore:value sprite:sprite];
		[_scores setObject:score forKey:scoresKey];
		[score release];
	}else {
		score.count++;
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
				([[NSDate date] timeIntervalSince1970] - [((NSNumber*)[worldScoresDictionary objectForKey:@"timestamp"]) doubleValue] > 43200)))
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
        DebugLog(@"---- Failed to save world scores in local plist!! - %@ -----", worldScoresPropertyListPath);
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
	}else if(percentile < 50) {
		return @"C";
	}else if(percentile < 55) {
		return @"C+";
		
		
	}else if(percentile < 60) {
		return @"B-";
	}else if(percentile < 65) {
		return @"B";
	}else if(percentile < 74) {
		return @"B+";
		
		
	}else if(percentile < 86) {
		return @"A-";
	}else if(percentile < 89) {
		return @"A";
	}else if(percentile < 93) {
		return @"A+";
	}else if(percentile < 97) {
		return @"A++";
		
		
	}else {
		return @"A+++";
	}

}


+(int)percentileFromZScore:(double)zScore {
	
	NSMutableDictionary* zTable = [[NSMutableDictionary alloc] init];
	[zTable setObject:[NSNumber numberWithDouble:1.5] forKey:[NSNumber numberWithDouble:-2.2]];
	[zTable setObject:[NSNumber numberWithDouble:6] forKey:[NSNumber numberWithDouble:-1.6]];
	[zTable setObject:[NSNumber numberWithDouble:12] forKey:[NSNumber numberWithDouble:-1.2]];
	[zTable setObject:[NSNumber numberWithDouble:16] forKey:[NSNumber numberWithDouble:-1.0]];
	[zTable setObject:[NSNumber numberWithDouble:18] forKey:[NSNumber numberWithDouble:-0.9]];
	[zTable setObject:[NSNumber numberWithDouble:21] forKey:[NSNumber numberWithDouble:-0.8]];
	[zTable setObject:[NSNumber numberWithDouble:24] forKey:[NSNumber numberWithDouble:-0.7]];
	[zTable setObject:[NSNumber numberWithDouble:27] forKey:[NSNumber numberWithDouble:-0.6]];
	[zTable setObject:[NSNumber numberWithDouble:31] forKey:[NSNumber numberWithDouble:-0.5]];
	[zTable setObject:[NSNumber numberWithDouble:35] forKey:[NSNumber numberWithDouble:-0.4]];
	[zTable setObject:[NSNumber numberWithDouble:38] forKey:[NSNumber numberWithDouble:-0.3]];
	[zTable setObject:[NSNumber numberWithDouble:42] forKey:[NSNumber numberWithDouble:-0.2]];
	[zTable setObject:[NSNumber numberWithDouble:46] forKey:[NSNumber numberWithDouble:-0.1]];
	[zTable setObject:[NSNumber numberWithDouble:50] forKey:[NSNumber numberWithDouble:0.0]];
				
	[zTable setObject:[NSNumber numberWithDouble:54] forKey:[NSNumber numberWithDouble:0.1]];
	[zTable setObject:[NSNumber numberWithDouble:58] forKey:[NSNumber numberWithDouble:0.2]];
	[zTable setObject:[NSNumber numberWithDouble:62] forKey:[NSNumber numberWithDouble:0.3]];
	[zTable setObject:[NSNumber numberWithDouble:65] forKey:[NSNumber numberWithDouble:0.4]];
	[zTable setObject:[NSNumber numberWithDouble:69] forKey:[NSNumber numberWithDouble:0.5]];
	[zTable setObject:[NSNumber numberWithDouble:72] forKey:[NSNumber numberWithDouble:0.6]];
	[zTable setObject:[NSNumber numberWithDouble:76] forKey:[NSNumber numberWithDouble:0.7]];
	[zTable setObject:[NSNumber numberWithDouble:79] forKey:[NSNumber numberWithDouble:0.8]];
	[zTable setObject:[NSNumber numberWithDouble:82] forKey:[NSNumber numberWithDouble:0.9]];
	[zTable setObject:[NSNumber numberWithDouble:84] forKey:[NSNumber numberWithDouble:1.0]];
	[zTable setObject:[NSNumber numberWithDouble:86] forKey:[NSNumber numberWithDouble:1.1]];
	[zTable setObject:[NSNumber numberWithDouble:88] forKey:[NSNumber numberWithDouble:1.2]];
	[zTable setObject:[NSNumber numberWithDouble:90] forKey:[NSNumber numberWithDouble:1.3]];
	[zTable setObject:[NSNumber numberWithDouble:92] forKey:[NSNumber numberWithDouble:1.4]];
	[zTable setObject:[NSNumber numberWithDouble:93] forKey:[NSNumber numberWithDouble:1.5]];
	[zTable setObject:[NSNumber numberWithDouble:94] forKey:[NSNumber numberWithDouble:1.6]];
	[zTable setObject:[NSNumber numberWithDouble:95] forKey:[NSNumber numberWithDouble:1.7]];
	[zTable setObject:[NSNumber numberWithDouble:96] forKey:[NSNumber numberWithDouble:1.8]];
	[zTable setObject:[NSNumber numberWithDouble:97] forKey:[NSNumber numberWithDouble:1.9]];
	[zTable setObject:[NSNumber numberWithDouble:97.5] forKey:[NSNumber numberWithDouble:2.0]];
	[zTable setObject:[NSNumber numberWithDouble:98] forKey:[NSNumber numberWithDouble:2.1]];
	[zTable setObject:[NSNumber numberWithDouble:99] forKey:[NSNumber numberWithDouble:2.2]];
	
	
	double cumulScore = 0;
	double totalScalars = 0;
	for(NSNumber* zScoreKey in zTable) {
		double aZScore = [zScoreKey doubleValue];
		double percentile = [(NSNumber*)[zTable objectForKey:zScoreKey] doubleValue];
		
		double scalar = zScore == aZScore ? 1000 : fmin(1.0/fabs(zScore-aZScore), 1000);
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
	int worldScoreMean = [(NSNumber*)[worldScores objectForKey:@"scoreMean"] intValue];
	int worldScoreStdDev = [(NSNumber*)[worldScores objectForKey:@"scoreStdDev"] intValue];
	double zScore = ((score - worldScoreMean) / (1.0f*worldScoreStdDev));
	return zScore;
}











-(void)dealloc {
	[_scores release];
	[super dealloc];
}


@end
