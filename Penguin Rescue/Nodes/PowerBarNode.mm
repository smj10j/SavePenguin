//
//  PowerBarNode.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 11/2/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "PowerBarNode.h"

@implementation PowerBarNode


-(id)initWithSize:(CGSize)contentSize position:(CGPoint)position color:(ccColor4F)barColor label:(NSString *)label textColor:(ccColor3B)textColor fontSize:(int)fontSize {
	if(self = [super init]) {
		contentSize_ = contentSize;
		_position = position;
		_barColor = barColor;
		_percentFill = 1.0;
		_label = [CCLabelTTF labelWithString:label fontName:@"Helvetica" fontSize:fontSize];
		_label.position = _position;
		_label.color = textColor;
		[self addChild:_label];
	}
	return self;
}

-(void)setPercentFill:(double)percentFill {
	_percentFill = percentFill;
}

-(void)setLabel:(NSString*)label {
	_label.string = label;
}

-(void)draw {
	[super draw];

	ccDrawSolidRect(ccp(_position.x - contentSize_.width/2, _position.y - contentSize_.height/2),
					ccp(_position.x - contentSize_.width/2 + contentSize_.width*(_percentFill), _position.y + contentSize_.height/2),
					_barColor);
}

-(void) dealloc {
	[super dealloc];
}

@end
