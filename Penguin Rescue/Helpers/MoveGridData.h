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


	bool _isBusy;
	bool _isMoveGridValid;
	bool _foundRoute;
	int _bestFoundRouteWeight;
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

- (instancetype)initWithGrid:(short**)grid height:(int)height width:(int)width moveHistorySize:(int)moveHistorySize tag:(NSString*)tag NS_DESIGNATED_INITIALIZER;

- (void)updateBaseGrid:(short**)baseGrid;

- (void)logMove:(CGPoint)pos;
- (CGPoint)moveHistoryAt:(int)indexOffset;
- (void)clearMoveLog;
@property (NS_NONATOMIC_IOSONLY, readonly) double distanceTraveled;
@property (NS_NONATOMIC_IOSONLY, readonly) double distanceTraveledStraightline;

@property (NS_NONATOMIC_IOSONLY, readonly) short **baseGrid;
@property (NS_NONATOMIC_IOSONLY, readonly) short **moveGrid;
@property (NS_NONATOMIC_IOSONLY, readonly) const CGPoint lastTargetTile;

- (void)updateMoveGridToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile;
- (CGPoint)getBestMoveToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile;
- (void)forceUpdateToMoveGrid;
- (void)invalidateMoveGrid;
@property (NS_NONATOMIC_IOSONLY, readonly) bool busy;
@property (NS_NONATOMIC_IOSONLY, readonly) int bestFoundRouteWeight;
- (void)scheduleUpdateToMoveGridIn:(NSTimeInterval)timeInterval;


@end

#define MOVEGRID_INITIAL_SEARCH_ATTEMPTS 4
#define MOVEGRID_INITIAL_MIN_SEARCH_FACTOR 0.5
#define MOVEGRID_MAX_SEARCH_FACTOR 6


#define PENGUIN_MOVE_HISTORY_SIZE 15
#define SHARK_MOVE_HISTORY_SIZE 15


#define INITIAL_GRID_WEIGHT 0
#define HARD_BORDER_WEIGHT 10000


