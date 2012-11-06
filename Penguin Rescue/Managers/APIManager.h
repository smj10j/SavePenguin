//
//  APIManager.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/31/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface APIManager : NSObject

+(void)addUserWithUUID:(NSString*)UUID onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError;

+(void)savePlayForUserWithUUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError;

+(void)saveScoreForUserWithUUID:(NSString*)UUID score:(int)score levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath onSuccess:(void(^)(NSDictionary*))onSuccess onError:(void(^)(NSError*))onError;




+(void)getWorldScoresAndOnSuccess:(void(^)(NSMutableDictionary*))onSuccess onError:(void(^)(NSError*))onError;



+(void)createUser;
@end






#define SERVER_HOST @"www.conquerllc.com"
#define SERVER_PATH @"/webservice/games/PenguinRescue.php"
#define SERVER_URL [NSString stringWithFormat:@"http://%@%@", SERVER_HOST, SERVER_PATH]


