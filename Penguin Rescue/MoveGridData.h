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
	int** _moveGrid;
	int** _moveGridBuffer;
	int _gridWidth;
	int _gridHeight;

	CGPoint _lastToTile;
	bool _forceUpdateToMoveGrid;
	
	CGPoint* _moveHistory;
	int _moveHistoryIndex;
	bool _moveHistoryIsFull;
	int _moveHistorySize;
		
	NSString* _tag;
}

- (id)initWithGrid:(int**)grid height:(int)height width:(int)width moveHistorySize:(int)moveHistorySize tag:(NSString*)tag;

- (void)updateBaseGrid:(int**)baseGrid;

- (void)logMove:(CGPoint)pos;
- (double)distanceTraveled;
- (double)distanceTraveledStraightline;

- (const int**)baseGrid;
- (const int**)moveGrid;
- (const CGPoint)lastTargetTile;

- (void)updateMoveGridToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile;
- (CGPoint)getBestMoveToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile;


@end


static NSMutableDictionary* tagToMoveGridData = [[NSMutableDictionary alloc] init];





#define INITIAL_GRID_WEIGHT 500
#define HARD_BORDER_WEIGHT 10000


