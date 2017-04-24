//
//  APIManager.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/31/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "APIManager.h"
#import "Constants.h"
#import "Utilities.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSONKit.h"
#import "SettingsManager.h"

@implementation APIManager


+(void)addUserWithUUID:(NSString*)UUID
	onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	if(!isServerAvailable()) {
		if(onError) {
			NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - The server is not available" code:500 userInfo:nil];
			onError(error);
		}
		return;
	}

	NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
	__block ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
	request.timeOutSeconds = 20;

	[request addPostValue:@"saveUser" forKey:@"action"];
	[request addPostValue:UUID forKey:@"UUID"];

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
	
		NSData* data = [request responseData];
		NSDictionary* response = [data objectFromJSONData];
		if(response == nil) {
			if(onError) {
				NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - Empty response from server" code:500 userInfo:nil];
				onError(error);
			}
			return;
		}
	
		if(onSuccess) {
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError(request.error);
		}
	}];

	[request startAsynchronous];
	[url release];

}

+(void)savePlayForUserWithUUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath
	onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	if(!isServerAvailable()) {
		if(onError) {
			NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - The server is not available" code:500 userInfo:nil];
			onError(error);
		}
		return;
	}
	
	NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
	__block ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
	request.timeOutSeconds = 20;

	[request addPostValue:@"savePlay" forKey:@"action"];
	[request addPostValue:UUID forKey:@"UUID"];
	[request addPostValue:levelPackPath forKey:@"levelPackPath"];
	[request addPostValue:levelPath forKey:@"levelPath"];

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{

		NSData* data = [request responseData];
		NSDictionary* response = [data objectFromJSONData];
		if(response == nil) {
			if(onError) {
				NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - Empty response from server" code:500 userInfo:nil];
				onError(error);
			}
			return;
		}	
	
		if(onSuccess) {
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError(request.error);
		}
	}];

	[request startAsynchronous];
	[url release];

}

+(void)saveScoreForUserWithUUID:(NSString*)UUID score:(int)score levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	if(!isServerAvailable()) {
		if(onError) {
			NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - The server is not available" code:500 userInfo:nil];
			onError(error);
		}
		return;
	}

	NSURL* url = [[NSURL alloc] initWithString:SERVER_URL];
	__block ASIFormDataRequest* request = [ASIFormDataRequest requestWithURL:url];
	request.timeOutSeconds = 20;

	[request addPostValue:@"saveScore" forKey:@"action"];
	[request addPostValue:@(score) forKey:@"score"];
	[request addPostValue:UUID forKey:@"UUID"];
	[request addPostValue:levelPackPath forKey:@"levelPackPath"];
	[request addPostValue:levelPath forKey:@"levelPath"];

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
	
		NSData* data = [request responseData];
		NSDictionary* response = [data objectFromJSONData];
		if(response == nil) {
			if(onError) {
				NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - Empty response from server" code:500 userInfo:nil];
				onError(error);
			}
			return;
		}
		
		if(onSuccess) {
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError(request.error);
		}
	}];

	[request startAsynchronous];
	[url release];
}





+(void)getWorldScoresAndOnSuccess:(void(^)(NSMutableDictionary*))onSuccess onError:(void(^)(NSError*))onError {

	if(!isServerAvailable()) {
		if(onError) {
			NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - The server is not available" code:500 userInfo:nil];
			onError(error);
		}
		return;
	}
	
	NSURL* url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@?action=%@", SERVER_URL, @"getWorldScores"]];
	__block ASIHTTPRequest* request = [ASIHTTPRequest requestWithURL:url];
	request.timeOutSeconds = 20;

	// Ah, success, parse the returned JSON data into a NSDictionary
	[request setCompletionBlock:^{
	
		NSData* data = [request responseData];
		NSMutableDictionary* response = [data mutableObjectFromJSONData];
		if(response == nil) {
			if(onError) {
				NSError* error = [NSError errorWithDomain:@"com.conquerllc.games - Empty response from server" code:500 userInfo:nil];
				onError(error);
			}
			return;
		}	
	
		if(onSuccess) {
			onSuccess(response);
		}
	}];

	// Oops, failed, let's see why
	[request setFailedBlock:^{
		if(onError) {
			onError(request.error);
		}
	}];

	[request startAsynchronous];
	[url release];

}



+(void)createUser {

	NSString* UUID = [SettingsManager getUUID];

	//create the user on the server
	if(![SettingsManager boolForKey:SETTING_HAS_CREATED_UUID_ON_SERVER]) {
		[APIManager addUserWithUUID:UUID 
			onSuccess:^(NSDictionary* response) {
				if(DEBUG_SCORING) DebugLog(@"Added new user to server. response = %@", response);
				[SettingsManager setBool:true forKey:SETTING_HAS_CREATED_UUID_ON_SERVER];
			}
			onError:^(NSError* error) {
				if(DEBUG_SCORING) DebugLog(@"Error sending new user data to server: %@", error.localizedDescription);
				[SettingsManager setBool:false forKey:SETTING_HAS_CREATED_UUID_ON_SERVER];
			}
		];
	}
}

@end
