//
//  MoveGridData.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/18/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "cocos2d.h"
#import "MoveGridData.h"

@implementation MoveGridData


- (id)initWithGrid:(int**)grid height:(int)height width:(int)width {
	if(self = [super init]) {
		_baseGrid = grid;
		_gridWidth = width;
		_gridHeight = height;
		
		if(_gridWidth > 0 && _gridHeight > 0 && _baseGrid != nil) {
			_latestGrid = new int*[_gridWidth];
			for(int x = 0; x < _gridWidth; x++) {
				_latestGrid[x] = new int[_gridHeight];
				for(int y = 0; y < _gridHeight; y++) {
					_latestGrid[x][y] = _baseGrid[x][y];
				}
			}
		}
		
		_moveHistory = new CGPoint[MOVE_HISTORY_SIZE];
		_moveHistoryIndex = 0;
	}
	return self;
}

- (void)logMove:(CGPoint)pos {
	_moveHistory[_moveHistoryIndex] = pos;
	_moveHistoryIndex = (++_moveHistoryIndex%MOVE_HISTORY_SIZE);
}


- (int**)gridToTile:(CGPoint)pos withPropagationCallback:(void(^)(int**))propagationMethod {

	if(pos.x != _lastTileExamined.x || pos.y != _lastTileExamined.y) {
	
		_lastTileExamined = pos;
	
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				_latestGrid[x][y] = _baseGrid[x][y];
			}
		}
		
		//propagate!
		if(propagationMethod) {
			propagationMethod(_latestGrid);
		}
		NSLog(@"Generated new latestGrid...");
	}else {
	}
		
	return _latestGrid;
}

- (int**)baseGrid {
	return _baseGrid;
}

- (double)distanceMoved {
	CGPoint start = _moveHistory[_moveHistoryIndex];
	CGPoint end = _moveHistory[(_moveHistoryIndex+MOVE_HISTORY_SIZE-1)%MOVE_HISTORY_SIZE];
	
	return ccpDistance(start, end);
}


-(void)dealloc {
	if(_baseGrid != nil) {
		free(_baseGrid);
	}
	if(_latestGrid != nil) {
		free(_latestGrid);
	}
	free(_moveHistory);
	_baseGrid = nil;
	_latestGrid = nil;
	
	[super dealloc];
}

@end
