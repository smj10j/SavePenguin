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

-(instancetype)initWithScore:(int)score NS_DESIGNATED_INITIALIZER;
@property (NS_NONATOMIC_IOSONLY) int score;
@property (NS_NONATOMIC_IOSONLY) int count;


@end
