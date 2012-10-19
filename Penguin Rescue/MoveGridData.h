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
	bool _forceLatestGridUpdate;
	
	NSString* _tag;
}

- (id)initWithGrid:(int**)grid height:(int)height width:(int)width tag:(NSString*)tag;

- (int**)baseGrid;		//returns the initial grid (usually feature data)
- (int**)latestGrid;	//returns the grid with movement data
- (int**)gridToTile:(CGPoint)pos withPropagationCallback:(void(^)(int**,CGPoint))propagationMethod;	//calculates a new grid or returns one that would have een calculated (if already calculated)
- (void)forceLatestGridUpdate;


- (void)logMove:(CGPoint)pos;
- (double)distanceTraveled;
- (double)distanceTraveledStraightline;

@end


static NSMutableDictionary* tagToMoveGridData = [[NSMutableDictionary alloc] init];




#define MOVE_HISTORY_SIZE 50
