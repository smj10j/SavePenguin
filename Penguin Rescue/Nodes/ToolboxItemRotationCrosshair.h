//
//  ToolboxItemRotationCrosshair.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 11/2/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "CCNode.h"
#import "LHSprite.h"

@interface ToolboxItemRotationCrosshair : CCNode {
	LHSprite* _toolboxItem;
}

-(instancetype)initWithToolboxItem:(LHSprite*)toolboxItem NS_DESIGNATED_INITIALIZER;

@end
