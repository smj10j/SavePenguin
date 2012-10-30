//
//  ScoreKeeper.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "ScoreKeeper.h"
#import "Utilities.h"

@implementation ScoreKeeper


-(id)init {

	if(self = [super init]) {
	
		_scores = [[NSMutableDictionary alloc] init];
	
		NSLog(@"SERVER AVAILALBE? %d", isServerAvailable());
	
		[self updateWorldScoresFromServer];
		
		//now send any queued up scores from when we may have been offline
		[self emptyLocalSendQueue];
		
	}

	return self;
}

-(void)addScore:(int)value description:(NSString*)tag sprite:(LHSprite*)sprite group:(bool)group {

	NSString* scoresKey = [NSString stringWithFormat:@"%@-%@-%@", tag, (sprite != nil ? sprite.userInfoClassName : @""), (group ? @"" : [NSString stringWithFormat:@"%d", arc4random()%100000])];
	Score* score = [_scores objectForKey:scoresKey];
	if(score == nil) {
		score = [[Score alloc] initWithScore:value sprite:sprite];
		[_scores setObject:score forKey:scoresKey];
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




-(NSDictionary*)worldScoresForLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	NSDictionary* worldScores = [self getWorldScores];
	return [worldScores objectForKey:[NSString stringWithFormat:@"%@:%@", levelPackPath, levelPath]];
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

-(void)updateWorldScoresFromServer {
	NSDictionary* worldScores = [self getWorldScores];
	
	//if we have no world scores data or the last time it was updated was over 12 hours ago, request form the server
	if(	isServerAvailable() && (
				DEBUG_SCORING ||
				worldScores == nil ||
				([[NSDate date] timeIntervalSince1970] - [((NSNumber*)[worldScores objectForKey:@"timestamp"]) doubleValue] > 43200)))
	{
		//TODO: load from server use NSData objects as they're faster
		
		//emulate for now
		NSString* response = @"{\"levels\": {\"Arctic1:DangerDanger\": {\"uniquePlays\": 4000,\"uniqueWins\": 3000,\"scoreMean\": 7500,\"scoreMedian\": 7650,\"scoreStdDev\": 500}}}";
		
		NSMutableDictionary* worldScores = [response mutableObjectFromJSONString];
		[worldScores setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
		if(DEBUG_SCORING) NSLog(@"Loaded world scores data from server: %@", worldScores);
		
		[self saveWorldScoresLocally:worldScores];
		
	}else {
		if(DEBUG_SCORING) NSLog(@"Using world scores data from local plist: %@", worldScores);
	}
}

-(NSDictionary*)getWorldScores {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* worldScoresPropertyListPath = [rootPath stringByAppendingPathComponent:@"WorldScores.plist"];
	NSMutableDictionary* worldScoresDictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:worldScoresPropertyListPath];
	return [worldScoresDictionary autorelease];
}

-(void)saveWorldScoresLocally:(NSDictionary*)worldScoresDictionary {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* worldScoresPropertyListPath = [rootPath stringByAppendingPathComponent:@"WorldScores.plist"];
	
	//write to file!
	if(![worldScoresDictionary writeToFile:worldScoresPropertyListPath atomically: YES]) {
        NSLog(@"---- Failed to save world scores in local plist!! - %@ -----", worldScoresPropertyListPath);
        return;
    }
	if(DEBUG_SCORING) NSLog(@"Saved world scores in local plist");
}

-(void)saveScore:(int)score userId:(NSString*)userId levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	
	NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
	[scoreData setObject:[NSNumber numberWithInt:score] forKey:@"score"];
	[scoreData setObject:userId forKey:@"userId"];
	[scoreData setObject:levelPackPath forKey:@"levelPackPath"];
	[scoreData setObject:levelPath forKey:@"levelPath"];
	

	if(isServerAvailable()) {
		
		//TODO: send score to server
		NSData* jsonData = [scoreData JSONData];
		
		
		
		
		if(DEBUG_SCORING) NSLog(@"Sent score data to server");
		
		//now send any queued up scores from when we may have been offline
		[self emptyLocalSendQueue];
		
	}else {
		//save local queue for sending to server if we're offline
		[self addScoreDataToLocalSendQueue:scoreData];
	}
	
	[scoreData release];
}

-(void)emptyLocalSendQueue {

	if(isServerAvailable()) {
		NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString* localScoreSendQueuePropertyListPath = [rootPath stringByAppendingPathComponent:@"LocalScoreSendQueue.plist"];

		NSMutableArray* localScoreSendQueue = [NSMutableArray arrayWithContentsOfFile:localScoreSendQueuePropertyListPath];
		if(localScoreSendQueue == nil || localScoreSendQueue.count == 0) {
			return;
		}

		//write an empty array to file!
		if(![[NSArray arrayWithObjects:nil] writeToFile:localScoreSendQueuePropertyListPath atomically: YES]) {
			NSLog(@"---- Failed to save emptied score queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
			return;
		}
		if(DEBUG_SCORING) NSLog(@"Saved emptied send queue plist");
		
		//now iterate to empty
		if(DEBUG_SCORING) NSLog(@"Sending %d queued scores to server", localScoreSendQueue.count);
		for(NSDictionary* scoreData in localScoreSendQueue) {
			[self saveScore:[(NSNumber*)[scoreData objectForKey:@"score"] intValue]
					userId:[scoreData objectForKey:@"userId"]
					levelPackPath:[scoreData objectForKey:@"levelPackPath"]
					levelPath:[scoreData objectForKey:@"levelPath"]
			];
		}		
	}
}


-(void)addScoreDataToLocalSendQueue:(NSDictionary*)scoreData {
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* localScoreSendQueuePropertyListPath = [rootPath stringByAppendingPathComponent:@"LocalScoreSendQueue.plist"];

	NSMutableArray* localScoreSendQueue = [[NSMutableArray alloc] initWithContentsOfFile:localScoreSendQueuePropertyListPath];
	if(localScoreSendQueue == nil) {
		localScoreSendQueue = [[NSMutableArray alloc] init];
	}
	[localScoreSendQueue addObject:scoreData];
	
	//write to file!
	if(![localScoreSendQueue writeToFile:localScoreSendQueuePropertyListPath atomically: YES]) {
        NSLog(@"---- Failed to save local score to send queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
		[localScoreSendQueue release];
        return;
    }
	[localScoreSendQueue release];
	if(DEBUG_SCORING) NSLog(@"Added local score to send queue plist");
}


-(void)dealloc {
	[_scores release];
	[super dealloc];
}


@end
