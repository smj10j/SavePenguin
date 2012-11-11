//
//  ScoreKeeper.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "Score.h"
#import "JSONKit.h"

@interface ScoreKeeper : NSObject {

	NSMutableDictionary* _scores;

}

-(id)init;

-(int)numberOfScoresInCategory:(NSString*)category;
-(bool)addScore:(int)value category:(NSString*)category tag:(NSString*)tag group:(bool)group;
-(bool)addScore:(int)value category:(NSString*)category tag:(NSString*)tag group:(bool)group unique:(bool)unique;

-(int)totalScore;



+(NSDictionary*)worldScoresForLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;
+(void)saveScore:(int)score UUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;
+(void)savePlayForUUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;



+(void)emptyLocalSendQueue;



+(NSString*)gradeFromZScore:(double)zScore;
+(int)coinsForZScore:(double)zScore;
+(double)zScoreFromScore:(double)score withLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;

@end




#define SCORE_KEEPER_NO_SCORE 1000000