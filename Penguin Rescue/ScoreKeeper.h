//
//  ScoreKeeper.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Constants.h"
#import "LHSprite.h"
#import "Score.h"
#import "JSONKit.h"

@interface ScoreKeeper : NSObject {

	NSMutableDictionary* _scores;

}

-(id)init;

-(void)addScore:(int)score description:(NSString*)tag sprite:(LHSprite*)sprite group:(bool)group;

-(int)totalScore;

-(NSDictionary*)worldScoresForLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;
-(void)saveScore:(int)score UUID:(NSString*)UUID levelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;

@end
