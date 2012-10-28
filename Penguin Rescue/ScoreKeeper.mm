//
//  ScoreKeeper.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "ScoreKeeper.h"

@implementation ScoreKeeper


-(id)init {

	if(self = [super init]) {
	
		_scores = [[NSMutableDictionary alloc] init];
	
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

-(void)dealloc {
	[_scores release];
	[super dealloc];
}

@end
