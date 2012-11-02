//
//  PowerBarNode.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 11/2/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "CCNode.h"
#import "cocos2d.h"

@interface PowerBarNode : CCSprite {
	ccColor4F _barColor;
	float _percentFill;
	CCLabelTTF* _label;
	CGPoint _position;
}

-(id)initWithSize:(CGSize)contentSize position:(CGPoint)position color:(ccColor4F)barColor label:(NSString *)label textColor:(ccColor3B)textColor fontSize:(int)fontSize;

-(void)setPercentFill:(float)percentFill;
-(void)setLabel:(NSString*)label;

@end
