//
//  LoudNoiseNode.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 11/10/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "LoudNoiseNode.h"
#import "CCGL.h"

#define MAX_POWER 2
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define SCALING_FACTOR (IS_IPHONE ? 320.0/768.0 : 1.0)


@implementation LoudNoiseNode

//TODO: wrap with a pretty health-bar-style image


-(id)initWithSprite:(LHSprite*)sprite maxRange:(float)maxRange {
	if(self = [super init]) {
		_maxRange = maxRange;
		_maxRangeCorner = _maxRange * sqrt(2.0);
		[self setPowerPercentage:100];
		
		_sprite = [sprite retain];
		
	}
	
	return self;
}

-(void)setPowerPercentage:(float)power {
	_power = min(power/100.0*MAX_POWER, MAX_POWER);
	_step = _maxRangeCorner/_power;
}

-(float)maxRange {
	return _maxRange;
}

-(float)maxRangeCorner {
	return _maxRangeCorner;
}

-(float)step {
	return _step;
}

-(void)draw {

	if(!visible_) {
		return;
	}

	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glLineWidth(2.0);
	
	double maxRange = _maxRangeCorner*SCALING_FACTOR;
	double step = maxRange/8;
	for(int i = step; i < maxRange; i+= step) {
		ccDrawColor4B(255,
						0,
						((MAX_POWER-_power)/MAX_POWER) * 255,
						((maxRange-i)/maxRange)*(_power/MAX_POWER) * 255
					);
		ccDrawCircle(_sprite.position, i, 0, 60, NO);
	}

	[super draw];
}

-(void) dealloc {
	
	[_sprite release];

	[super dealloc];
}

@end
