//
//  Score.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "Score.h"

@implementation Score

-(id)initWithScore:(int)score sprite:(LHSprite*)sprite {
	
	if(self = [super init]) {
		_score = score;
		_sprite = sprite;
		_count = 1;
	}
	return self;
}

-(int)score {
	return _score;
}

-(int)count {
	return _count;
}

-(LHSprite*)sprite {
	return _sprite;
}

-(void)setScore:(int)score {
	_score = score;
}

-(void)setCount:(int)count {
	_count = count;
}

-(void)setSprite:(LHSprite*)sprite {
	_sprite = sprite;
}

@end
