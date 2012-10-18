//
//  SharkMoveGridData.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/18/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "cocos2d.h"
#import "SharkMoveGridData.h"

@implementation SharkMoveGridData


-(id)initWithGrid:(int**)grid {
	if(self = [super init]) {
		_grid = grid;
		_moveHistory = new CGPoint[MOVE_HISTORY_SIZE];
		_moveHistoryIndex = 0;
	}
	return self;
}

-(int**)grid {
	return _grid;
}


- (void)logMove:(CGPoint)pos {
	_moveHistory[_moveHistoryIndex] = pos;
	_moveHistoryIndex = (++_moveHistoryIndex%MOVE_HISTORY_SIZE);
}

- (double)distanceMoved {
	CGPoint start = _moveHistory[_moveHistoryIndex];
	CGPoint end = _moveHistory[(_moveHistoryIndex+MOVE_HISTORY_SIZE-1)%MOVE_HISTORY_SIZE];
	
	return ccpDistance(start, end);
}


-(void)dealloc {
	free(_grid);
	free(_moveHistory);
	_grid = nil;
	
	[super dealloc];
}

@end
