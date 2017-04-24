//
//  ToolboxItemRotationCrosshair.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 11/2/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "ToolboxItemRotationCrosshair.h"
#import "LHSprite.h"

@implementation ToolboxItemRotationCrosshair


-(instancetype)initWithToolboxItem:(LHSprite*)toolboxItem {
	if(self = [super init]) {
		_toolboxItem = [toolboxItem retain];
	}
	return self;
}

-(void)draw {
	[super draw];

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	//draw a crosshair around the toolbox item with a special color indicating rotation
	ccColor4F toolboxItemCrosshairCOlor = ccc4f(200,50,50,50);
	ccDrawSolidRect(ccp(0, _toolboxItem.position.y-1),
					ccp(winSize.width, _toolboxItem.position.y+1),
					toolboxItemCrosshairCOlor);
	ccDrawSolidRect(ccp(_toolboxItem.position.x-1, 0),
					ccp(_toolboxItem.position.x+1, winSize.height),
					toolboxItemCrosshairCOlor);
			
	/*
	float rad = CC_DEGREES_TO_RADIANS(_toolboxItem.rotation);
	ccDrawColor4B(200,0,0,200);
	glLineWidth(20.0);
	ccDrawLine(ccp(_toolboxItem.position.x, _toolboxItem.position.y),
				ccp(_toolboxItem.position.x + sinf(rad)*winSize.width, _toolboxItem.position.y + cosf(rad)*winSize.width));
	*/
}

-(void) dealloc {
	[_toolboxItem release];
	[super dealloc];
}

@end
