//
//  APIManager.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/31/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "APIManager.h"
#import "Constants.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSONKit.h"

@implementation APIManager


+(void)addUserWithUUID:(NSString*)UUID
	onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
	ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
	[request setTimeOutSeconds:20];

	[request addPostValue:@"saveUser" forKey:@"action"];
	[request addPostValue:UUID forKey:@"UUID"];

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
		if(onSuccess) {
			NSData* data = [request responseData];
			NSDictionary* response = [data objectFromJSONData];
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError([request error]);
		}
	}];

	[request startAsynchronous];
	[url release];

}

+(void)savePlayForUserWithUUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath
	onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
	ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
	[request setTimeOutSeconds:20];

	[request addPostValue:@"savePlay" forKey:@"action"];
	[request addPostValue:UUID forKey:@"UUID"];
	[request addPostValue:levelPackPath forKey:@"levelPackPath"];
	[request addPostValue:levelPath forKey:@"levelPath"];

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
		if(onSuccess) {
			NSData* data = [request responseData];
			NSDictionary* response = [data objectFromJSONData];
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError([request error]);
		}
	}];

	[request startAsynchronous];
	[url release];

}

+(void)saveScoreForUserWithUUID:(NSString*)UUID score:(int)score levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
	ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
	[request setTimeOutSeconds:20];

	[request addPostValue:@"saveScore" forKey:@"action"];
	[request addPostValue:[NSNumber numberWithInt:score] forKey:@"score"];
	[request addPostValue:UUID forKey:@"UUID"];
	[request addPostValue:levelPackPath forKey:@"levelPackPath"];
	[request addPostValue:levelPath forKey:@"levelPath"];

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
		if(onSuccess) {
			NSData* data = [request responseData];
			NSDictionary* response = [data objectFromJSONData];
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError([request error]);
		}
	}];

	[request startAsynchronous];
	[url release];
}





+(void)getWorldScoresAndOnSuccess:(void(^)(NSMutableDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	NSURL* url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?action=%@", SERVER_URL, @"getWorldScores"]];
	ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL:url];
	[request setTimeOutSeconds:20];


	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
		if(onSuccess) {
			NSData* data = [request responseData];
			NSMutableDictionary* response = [data mutableObjectFromJSONData];
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError([request error]);
		}
	}];

	[request startAsynchronous];
	[url release];

}


@end
