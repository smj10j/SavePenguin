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

-(instancetype)initWithSprite:(LHSprite*)sprite maxRange:(float)maxRange NS_DESIGNATED_INITIALIZER;

-(void)setPowerPercentage:(float)power;

@property (NS_NONATOMIC_IOSONLY, readonly) float maxRange;
@property (NS_NONATOMIC_IOSONLY, readonly) float maxRangeCorner;
@property (NS_NONATOMIC_IOSONLY, readonly) float step;

@end
