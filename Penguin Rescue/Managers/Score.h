//
//  Score.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Score : NSObject {

	int _score;
	int _count;
}

-(id)initWithScore:(int)score;
-(int)score;
-(int)count;

-(void)setScore:(int)score;
-(void)setCount:(int)count;

@end
