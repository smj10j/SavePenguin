//
//  ScoreKeeper.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "ScoreKeeper.h"
#import "Utilities.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"


@implementation ScoreKeeper


-(id)init {

	if(self = [super init]) {
	
		_scores = [[NSMutableDictionary alloc] init];
	
		DebugLog(@"SERVER AVAILALBE? %d", isServerAvailable());
	
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
			
		NSURL* url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?action=%@", SERVER_URL, @"getWorldScores"]];
		ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL:url];
		[request setTimeOutSeconds:20];

		// Ah, success, parse the returned JSON data into a NSDictionary
		[request setCompletionBlock:^{
			NSData* data = [request responseData];
			
			NSMutableDictionary* worldScores = [data mutableObjectFromJSONData];
			[worldScores setObject:[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]] forKey:@"timestamp"];
			
			if(DEBUG_SCORING) DebugLog(@"Loaded world scores data from server: %@", worldScores);
			
			[self saveWorldScoresLocally:worldScores];			
		}];

		// Oops, failed, let's see why
		[request setFailedBlock:^{
			NSError* error = [request error];
			if(DEBUG_SCORING) DebugLog(@"Error retrieving world scores from server: %@", error.localizedDescription);
		}];

		[request startAsynchronous];
		[url release];
	
	}else {
		if(DEBUG_SCORING) DebugLog(@"Using world scores data from local plist: %@", worldScores);
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
        DebugLog(@"---- Failed to save world scores in local plist!! - %@ -----", worldScoresPropertyListPath);
        return;
    }
	if(DEBUG_SCORING) DebugLog(@"Saved world scores in local plist");
}

-(void)saveScore:(int)score userId:(NSString*)userId levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath {
	
	NSMutableDictionary* scoreData = [[NSMutableDictionary alloc] init];
	[scoreData setObject:[NSNumber numberWithInt:score] forKey:@"score"];
	[scoreData setObject:userId forKey:@"userId"];
	[scoreData setObject:levelPackPath forKey:@"levelPackPath"];
	[scoreData setObject:levelPath forKey:@"levelPath"];
	

	if(isServerAvailable()) {
			
		//send score to server
		
		NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
		ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
		[request setTimeOutSeconds:20];
		
		for(NSString* key in scoreData) {
			[request addPostValue:[scoreData objectForKey:key] forKey:key];
		}

		// Ah, success, parse the returned JSON data into a NSDictionary
		[request setCompletionBlock:^{
			NSData* data = [request responseData];
			
			NSDictionary* response = [data objectFromJSONData];			
			if(DEBUG_SCORING) DebugLog(@"Sent score data to server. response = %@", response);
			
			//now send any queued up scores from when we may have been offline
			[self emptyLocalSendQueue];
		}];

		// Oops, failed, let's see why
		[request setFailedBlock:^{
			NSError* error = [request error];
			if(DEBUG_SCORING) DebugLog(@"Error posting score data to server: %@", error.localizedDescription);
		}];

		[request startAsynchronous];
		[url release];
		
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
			DebugLog(@"---- Failed to save emptied score queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
			return;
		}
		if(DEBUG_SCORING) DebugLog(@"Saved emptied send queue plist");
		
		//now iterate to empty
		if(DEBUG_SCORING) DebugLog(@"Sending %d queued scores to server", localScoreSendQueue.count);
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
        DebugLog(@"---- Failed to save local score to send queue plist!! - %@ -----", localScoreSendQueuePropertyListPath);
		[localScoreSendQueue release];
        return;
    }
	[localScoreSendQueue release];
	if(DEBUG_SCORING) DebugLog(@"Added local score to send queue plist");
}


-(void)dealloc {
	[_scores release];
	[super dealloc];
}


@end
