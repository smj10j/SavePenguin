//
//  Score.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LHSprite.h"

@interface Score : NSObject {

	int _score;
	int _count;
	LHSprite* _sprite;
}

-(id)initWithScore:(int)score sprite:(LHSprite*)sprite;
-(int)score;
-(int)count;
-(LHSprite*)sprite;

-(void)setScore:(int)score;
-(void)setCount:(int)count;
-(void)setSprite:(LHSprite*)sprite;

@end
