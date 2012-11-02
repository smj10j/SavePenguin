//
//  MoveGridData.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/18/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "cocos2d.h"
#import "MoveGridData.h"
#import "Constants.h"

@implementation MoveGridData


- (id)initWithGrid:(short**)grid height:(int)height width:(int)width moveHistorySize:(int)moveHistorySize tag:(NSString*)tag {
	if(self = [super init]) {
		_baseGrid = grid;
		_gridWidth = width;
		_gridHeight = height;
		_tag = tag;
	
		if(_gridWidth > 0 && _gridHeight > 0 && _baseGrid != nil) {
			_moveGrid = new short*[_gridWidth];
			_moveGridBuffer = new short*[_gridWidth];
			for(int x = 0; x < _gridWidth; x++) {
				_moveGrid[x] = new short[_gridHeight];
				_moveGridBuffer[x] = new short[_gridHeight];
				for(int y = 0; y < _gridHeight; y++) {
					_moveGrid[x][y] = _baseGrid[x][y];
					_moveGridBuffer[x][y] = _baseGrid[x][y];
				}
			}
		}
		_foundRoute = false;
		_scheduledUpdateMoveGridTimer = nil;
		[self forceUpdateToMoveGrid];
						
		_moveHistorySize = moveHistorySize;
		_moveHistory = new CGPoint[_moveHistorySize];
		_moveHistoryIndex = 0;
		_moveHistoryIsFull = false;
	}
		
	return self;
}

- (void)copyBaseGridToMoveGridBuffer {
	if(_gridWidth > 0 && _gridHeight > 0 && _baseGrid != nil && _moveGridBuffer != nil) {
		int rowSize = sizeof(short) * _gridHeight;
		for(int i = 0; i < _gridWidth; i++) {
			//DebugLog(@"memcpy: %d bytes from _baseGrid[%d] to _moveGridBuffer[%d]", rowSize, i, i);
			memcpy(_moveGridBuffer[i], (void*)_baseGrid[i], rowSize);
		}
	}
}

- (void)copyMoveGridBufferToMoveGrid {
	if(_gridWidth > 0 && _gridHeight > 0 && _moveGrid != nil && _moveGridBuffer != nil) {
		int rowSize = sizeof(short) * _gridHeight;
		for(int i = 0; i < _gridWidth; i++) {
			//DebugLog(@"memcpy: %d bytes from _moveGridBufferp[%d] to _moveGrid[%d]", rowSize, i, i);
			memcpy(_moveGrid[i], (void*)_moveGridBuffer[i], rowSize);
		}
	}
}

- (void)logMove:(CGPoint)pos {
	_moveHistory[_moveHistoryIndex] = pos;
	_moveHistoryIndex = (++_moveHistoryIndex%_moveHistorySize);
	if(_moveHistoryIndex == 0) {
		_moveHistoryIsFull = true;
	}
}

- (void)forceUpdateToMoveGrid {
	if(_scheduledUpdateMoveGridTimer != nil) {
		[_scheduledUpdateMoveGridTimer invalidate];
		_scheduledUpdateMoveGridTimer = nil;
	}
	_forceUpdateToMoveGrid = true;
	_minSearchPathFactor = MOVEGRID_INITIAL_MIN_SEARCH_FACTOR;
}

- (void)scheduleUpdateToMoveGridIn:(NSTimeInterval)timeInterval {
	
	if(_scheduledUpdateMoveGridTimer != nil) {
		//only allow one at a time
		return;
	}
	
	_scheduledUpdateMoveGridTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
		target:self
		selector:@selector(forceUpdateToMoveGrid)
		userInfo:nil
		repeats:NO];	
}

- (void)updateBaseGrid:(short**)baseGrid {
	if(_baseGrid != nil) {
		for(int i = 0; i < _gridWidth; i++) {
			free(_baseGrid[i]);
		}
		free(_baseGrid);
	}
	_baseGrid = baseGrid;
	[self forceUpdateToMoveGrid];
}

- (double)distanceTraveledStraightline {
	CGPoint start = _moveHistory[_moveHistoryIndex];
	CGPoint end = _moveHistory[(_moveHistoryIndex+_moveHistorySize-1)%_moveHistorySize];
	return ccpDistance(start, end);
}

- (double)distanceTraveled {
	double sum = 0;
	if(_moveHistoryIsFull) {
		for(int i = 1; i < _moveHistorySize; i++) {
			sum+= ccpDistance(_moveHistory[i], _moveHistory[i-1]);
		}
	}else {
		sum = 10000;
	}
	return sum;
}

- (const short**)moveGrid {
	return (const short**)_moveGrid;
}

- (short**)baseGrid {
	return _baseGrid;
}

- (const CGPoint)lastTargetTile {
	return (const CGPoint)_lastToTile;
}

- (CGPoint)getBestMoveToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile {
	CGPoint bestMove = ccp(-10000,-10000);
	
	short wN = fromTile.y < _gridHeight-1 ? _moveGrid[(int)fromTile.x][(int)fromTile.y+1] : 10000;
	short wS = fromTile.y > 0 ? _moveGrid[(int)fromTile.x][(int)fromTile.y-1] : 10000;
	short wE = fromTile.x < _gridWidth-1 ? _moveGrid[(int)fromTile.x+1][(int)fromTile.y] : 10000;
	short wW = fromTile.x > 0 ? _moveGrid[(int)fromTile.x-1][(int)fromTile.y] : 10000;
	
	//makes backtracking less attractive
	_moveGrid[(int)fromTile.x][(int)fromTile.y]++;
	
	//if(DEBUG_MOVEGRID) DebugLog(@"%@ weights: %d, %d, %d, %d", _tag, wN, wS, wE, wW);
	
	if(wW == wE && wE == wN && wN == wS) {
				
		short w = _moveGrid[(int)fromTile.x][(int)fromTile.y];
		if(wW == w && w == INITIAL_GRID_WEIGHT) {
			//this occurs when the shark has no route to the penguin - he literally has no idea which way to go
			return bestMove;
		}else {
			//pick a random one!
			bestMove = ccp(fromTile.x+((arc4random()%10)-5)/5.0,fromTile.y+((arc4random()%10)-5)/5.0);
		}
		
	}else {
		double vE = 0;
		double vN = 0;
		
		//COMMENTED OUT BECAUSE THIS SEEMS LIKE FAULTY LOGIC
		//situation: West and East are equal and North and South are not equal - we'll get stuck forever
		/*if(wE == wW && wN != wS) {
			if(arc4random()%100 < 50) {
				wE++;
			}else {
				wW++;
			}
		}else if(wN == wS && wE != wW) {
			if(arc4random()%100 < 50) {
				wN++;
			}else {
				wS++;
			}
		}*/
		
		short absWE = abs(wE);
		short absWW = abs(wW);
		short absWS = abs(wS);
		short absWN = abs(wN);
		short absMinEW = min(absWE, absWW);
		short absMinNS = min(absWN, absWS);
		short absMin = min(absMinNS, absMinEW);
		
		if(absWE == absMin) {
			vE = (wW-wE)/(wW==0?1.0:(float)wW);
		}else if(absWW == absMin) {
			vE = (wW-wE)/(wE==0?1.0:(float)wE);
		}
				
		if(absWN == absMin) {
			vN = (wS-wN)/(wS==0?1.0:(float)wS);
		}else if(absWS == absMin) {
			vN = (wS-wN)/(wN==0?1.0:(float)wN);
		}
		
		bestMove = ccp(vE,vN);				
	}
	
	//if(DEBUG_MOVEGRID) DebugLog(@"Returning %@ best move: %f,%f fromTile: %f,%f", _tag, bestMove.x,bestMove.y,fromTile.x,fromTile.y);
	
	return bestMove;
}

- (void)updateMoveGridToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile {
	[self updateMoveGridToTile:toTile fromTile:fromTile attemptsRemaining:MOVEGRID_INITIAL_SEARCH_ATTEMPTS];
}

- (void)updateMoveGridToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile attemptsRemaining:(int)attemptsRemaining {

	if(!_foundRoute || _forceUpdateToMoveGrid || (attemptsRemaining != MOVEGRID_INITIAL_SEARCH_ATTEMPTS) || (_lastToTile.x != toTile.x || _lastToTile.y != toTile.y)) {

		if(DEBUG_MOVEGRID) DebugLog(@"Updating a %@ move grid", _tag);

		_lastToTile = toTile;
		_forceUpdateToMoveGrid = false;
		
		double startTime = [[NSDate date] timeIntervalSince1970];

		short bestFoundRouteWeight = -1;
		[self copyBaseGridToMoveGridBuffer];
		_moveGridBuffer[(int)toTile.x][(int)toTile.y] = 0;
		[self propagateGridCostToX:toTile.x y:toTile.y fromTile:fromTile bestFoundRouteWeight:&bestFoundRouteWeight];
		
		if(bestFoundRouteWeight >= 0) {
			[self copyMoveGridBufferToMoveGrid];
			_foundRoute = true;
			_minSearchPathFactor-= .25;
			if(_minSearchPathFactor < .5) {
				_minSearchPathFactor = .5;
			}
		}else {
			if(_foundRoute) {
				//don't copy - use the old route
			}else {
				//we have no idea what's going on - go ahead and use what we found while we're searching
				[self copyMoveGridBufferToMoveGrid];
			}
			_minSearchPathFactor*= 2;
			if(_minSearchPathFactor > 6) {
				_minSearchPathFactor = 6;
			}
			
			//go try again!
			if(attemptsRemaining > 0) {
				[self updateMoveGridToTile:toTile fromTile:fromTile attemptsRemaining:attemptsRemaining-1];
				return;
			}
		}
		
		if(DEBUG_MOVEGRID) DebugLog(@"bestFoundRouteWeight=%d,_minSearchPathFactor=%f,attemptsRemaining=%d for a %@ move grid in %f seconds", bestFoundRouteWeight, _minSearchPathFactor, attemptsRemaining, _tag, [[NSDate date] timeIntervalSince1970] - startTime);

	}
}


-(void) propagateGridCostToX:(int)x y:(int)y fromTile:(CGPoint)fromTile bestFoundRouteWeight:(short*)bestFoundRouteWeight {

	if(x < 0 || x >= _gridWidth) {
		return;
	}
	if(y < 0 || y >= _gridHeight) {
		return;
	}

	short w = _moveGridBuffer[x][y];

	if(fromTile.x >= 0 && fromTile.y >= 0 && fromTile.x == x && fromTile.y == y) {
		//find the fastest route - not necessarily the best
		*bestFoundRouteWeight = w;
	}
	
	if((*bestFoundRouteWeight >= 0 && w > *bestFoundRouteWeight) || w > (_gridWidth*_minSearchPathFactor)) {
		//this is an approximation to increase speed - it can cause failures to find any path at all (very complex ones)
		//if(DEBUG_MOVEGRID) DebugLog(@"Aboring propagation for %@ because we're over the search limit. w=%d, bestFoundRouteWeight=%d, _gridWidth*_minSearchPathFactor=%f", _tag, w, *bestFoundRouteWeight, _gridWidth*_minSearchPathFactor);
		return;
	}
	
	short wN = y+1 > _gridHeight-1 ? -10000 : _moveGridBuffer[x][y+1];
	short wS = y-1 < 0 ? -10000 : _moveGridBuffer[x][y-1];
	short wE = x+1 > _gridWidth-1 ? -10000 : _moveGridBuffer[x+1][y];
	short wW = x-1 < 0 ? -10000 : _moveGridBuffer[x-1][y];

	//if(DEBUG_MOVEGRID) DebugLog(@"Propagating %@ %d,%d = %d", _tag, x, y, w);
	
	bool changedN = false;
	bool changedS = false;
	bool changedE = false;
	bool changedW = false;
	

	if(y < _gridHeight-1 && _baseGrid[x][y+1] < HARD_BORDER_WEIGHT && (wN == _baseGrid[x][y+1] || wN > w+1)) {
		_moveGridBuffer[x][y+1] = w+1 + (_baseGrid[x][y+1] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x][y+1]);
		changedN = true;
	}
	if(y > 0 && _baseGrid[x][y-1] < HARD_BORDER_WEIGHT && (wS == _baseGrid[x][y-1] || wS > w+1)) {
		_moveGridBuffer[x][y-1] = w+1  + (_baseGrid[x][y-1] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x][y-1]);
		changedS = true;
	}
	if(x < _gridWidth-1 && _baseGrid[x+1][y] < HARD_BORDER_WEIGHT && (wE == _baseGrid[x+1][y] || wE > w+1)) {
		_moveGridBuffer[x+1][y] = w+1 + (_baseGrid[x+1][y] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x+1][y]);
		changedE = true;
	}
	if(x > 0 && _baseGrid[x-1][y] < HARD_BORDER_WEIGHT && (wW == _baseGrid[x-1][y] || wW > w+1)) {
		_moveGridBuffer[x-1][y] = w+1  + (_baseGrid[x-1][y] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x-1][y]);
		changedW = true;
	}
	
	//if(DEBUG_MOVEGRID) DebugLog(@"changedE=%d, changedW=%d, changedN=%d, changedS=%d", changedE, changedW, changedN, changedS);
	
	if(changedN) {
		[self propagateGridCostToX:x y:y+1 fromTile:fromTile bestFoundRouteWeight:bestFoundRouteWeight];
	}
	if(changedS) {
		[self propagateGridCostToX:x y:y-1 fromTile:fromTile bestFoundRouteWeight:bestFoundRouteWeight];
	}
	if(changedE) {
		[self propagateGridCostToX:x+1 y:y fromTile:fromTile bestFoundRouteWeight:bestFoundRouteWeight];
	}
	if(changedW) {
		[self propagateGridCostToX:x-1 y:y fromTile:fromTile bestFoundRouteWeight:bestFoundRouteWeight];
	}

}

-(void)dealloc {

	//DebugLog(@"Deallocating MoveGrid");

	if(_baseGrid != nil) {
		for(int i = 0; i < _gridWidth; i++) {
			free(_baseGrid[i]);
		}
		free(_baseGrid);
		_baseGrid = nil;
	}
	if(_moveGrid != nil) {
		for(int i = 0; i < _gridWidth; i++) {
			free(_moveGrid[i]);
		}
		free(_moveGrid);
		_moveGrid = nil;
	}
	if(_moveGridBuffer != nil) {
		for(int i = 0; i < _gridWidth; i++) {
			free(_moveGridBuffer[i]);
		}
		free(_moveGridBuffer);
		_moveGridBuffer = nil;
	}

	free(_moveHistory);
	_moveHistory = nil;
	
	[super dealloc];
}


@end
