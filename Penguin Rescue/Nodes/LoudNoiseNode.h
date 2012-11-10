//
//  PowerBarNode.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 11/10/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "CCNode.h"
#import "cocos2d.h"
#import "LHSprite.h"

@interface LoudNoiseNode : CCSprite {
	float _maxRange;
	float _maxRangeCorner;
	float _step;
	float _power;
	
	LHSprite* _sprite;
}

-(id)initWithSprite:(LHSprite*)sprite maxRange:(float)maxRange;

-(void)setPowerPercentage:(float)power;

-(float)maxRange;
-(float)maxRangeCorner;
-(float)step;

@end
