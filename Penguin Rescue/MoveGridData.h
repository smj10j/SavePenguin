//
//  MoveGridData.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/18/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MoveGridData : NSObject {

	short** _baseGrid;
	short** _moveGrid;
	short** _moveGridBuffer;
	int _gridWidth;
	int _gridHeight;

	bool _foundRoute;
	double _minSearchPathFactor;

	CGPoint _lastToTile;
	bool _forceUpdateToMoveGrid;
	NSTimer* _scheduledUpdateMoveGridTimer;
	
	CGPoint* _moveHistory;
	int _moveHistoryIndex;
	bool _moveHistoryIsFull;
	int _moveHistorySize;
		
	NSString* _tag;
}

- (id)initWithGrid:(short**)grid height:(int)height width:(int)width moveHistorySize:(int)moveHistorySize tag:(NSString*)tag;

- (void)updateBaseGrid:(short**)baseGrid;

- (void)logMove:(CGPoint)pos;
- (double)distanceTraveled;
- (double)distanceTraveledStraightline;

- (short**)baseGrid;
- (const short**)moveGrid;
- (const CGPoint)lastTargetTile;

- (void)updateMoveGridToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile;
- (CGPoint)getBestMoveToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile;
- (void)forceUpdateToMoveGrid;
- (void)scheduleUpdateToMoveGridIn:(NSTimeInterval)timeInterval;


@end

#define MOVEGRID_INITIAL_SEARCH_ATTEMPTS 4
#define MOVEGRID_INITIAL_MIN_SEARCH_FACTOR 0.5

#define INITIAL_GRID_WEIGHT 500
#define HARD_BORDER_WEIGHT 10000


