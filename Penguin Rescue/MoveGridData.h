//
//  MoveGridData.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/18/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MoveGridData : NSObject {

	int** _baseGrid;
	int** _latestGrid;
	int _gridWidth;
	int _gridHeight;
	
	CGPoint* _moveHistory;
	int _moveHistoryIndex;
	bool _moveHistoryIsFull;
	
	CGPoint _lastTileExamined;
}

- (id)initWithGrid:(int**)grid height:(int)height width:(int)width;

- (int**)baseGrid;
- (int**)gridToTile:(CGPoint)pos withPropagationCallback:(void(^)(int**))propagationMethod;

- (void)logMove:(CGPoint)pos;
- (double)distanceTraveled;
- (double)distanceTraveledStraightline;

@end



#define MOVE_HISTORY_SIZE 30
