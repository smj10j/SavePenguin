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


- (id)initWithGrid:(int**)grid height:(int)height width:(int)width moveHistorySize:(int)moveHistorySize tag:(NSString*)tag {
	if(self = [super init]) {
		_baseGrid = grid;
		_gridWidth = width;
		_gridHeight = height;
		_tag = tag;
	
		if(_gridWidth > 0 && _gridHeight > 0 && _baseGrid != nil) {
			_moveGrid = new int*[_gridWidth];
			for(int x = 0; x < _gridWidth; x++) {
				_moveGrid[x] = new int[_gridHeight];
				for(int y = 0; y < _gridHeight; y++) {
					_moveGrid[x][y] = _baseGrid[x][y];
				}
			}
		}
		_forceUpdateToMoveGrid = false;
				
		_moveHistorySize = moveHistorySize;
		_moveHistory = new CGPoint[_moveHistorySize];
		_moveHistoryIndex = 0;
		_moveHistoryIsFull = false;
	}
	
	//create a grouping of the objects by tags so we can share grids between them
	NSMutableSet* moveGridDatas = [tagToMoveGridData objectForKey:_tag];
	if(moveGridDatas == nil) {
		moveGridDatas = [[NSMutableSet alloc] init];
		[tagToMoveGridData setObject:moveGridDatas forKey:_tag];
	}
	[moveGridDatas addObject:self];
	
	return self;
}

- (void)copyBaseGridToMoveGrid {
	if(_gridWidth > 0 && _gridHeight > 0 && _baseGrid != nil && _moveGrid != nil) {
		for(int x = 0; x < _gridWidth; x++) {
			for(int y = 0; y < _gridHeight; y++) {
				_moveGrid[x][y] = _baseGrid[x][y];
			}
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
	_forceUpdateToMoveGrid = true;
}

- (void)updateBaseGrid:(int**)baseGrid {
	if(_baseGrid != nil) {
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

- (const int**)moveGrid {
	return (const int**)_moveGrid;
}

- (CGPoint)getBestMoveToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile {
	CGPoint bestMove = ccp(-10000,-10000);
	
	double wN = _moveGrid[(int)fromTile.x][fromTile.y < _gridHeight-1 ? (int)fromTile.y+1 : 10000];
	double wS = _moveGrid[(int)fromTile.x][fromTile.y > 0 ? (int)fromTile.y-1 : 10000];
	double wE = _moveGrid[fromTile.x < _gridWidth-1 ? (int)fromTile.x+1 : 10000][(int)fromTile.y];
	double wW = _moveGrid[fromTile.x > 0 ? (int)fromTile.x-1 : 10000][(int)fromTile.y];
	
	//makes backtracking less attractive
	_moveGrid[(int)fromTile.x][(int)fromTile.y]++;
	
	//NSLog(@"weights: %f, %f, %f, %f", wN, wS, wE, wW);
	
	if(wW == wE && wE == wN && wN == wS) {
				
		double w = _moveGrid[(int)fromTile.x][(int)fromTile.y];
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
		
		double absWE = fabs(wE);
		double absWW = fabs(wW);
		double absWS = fabs(wS);
		double absWN = fabs(wN);
		double absMin = fmin(fmin(fmin(absWE,absWW),absWN),absWS);
		if(absWE == absMin) {
			vE = (wW-wE)/(wW==0?1:wW);
		}else if(absWW == absMin) {
			vE = (wW-wE)/(wE==0?1:wE);
		}
				
		if(absWN == absMin) {
			vN = (wS-wN)/(wS==0?1:wS);
		}else if(absWS == absMin) {
			vN = (wS-wN)/(wN==0?1:wN);
		}
		
		bestMove = ccp(vE,vN);
				
		/*bestOptionPos = ccp(shark.position.x + (fabs(wE) > fabs(wW) ? wE : wW),
							shark.position.y + (fabs(wN) > fabs(wS) ? wN : wS)
						);*/
		//NSLog(@"best: %f,%f", bestOptionPos.x,bestOptionPos.y);
	}
	
	//NSLog(@"Returning best move: %f,%f fromTile: %f,%f", bestMove.x,bestMove.y,fromTile.x,fromTile.y);
	
	return bestMove;
}


- (void)updateMoveGridToTile:(CGPoint)toTile fromTile:(CGPoint)fromTile {

	if(_forceUpdateToMoveGrid || (_lastToTile.x != toTile.x || _lastToTile.y != toTile.y)) {

		NSLog(@"Updating a %@ move grid", _tag);

		_lastToTile = toTile;
		_forceUpdateToMoveGrid = false;

		[self copyBaseGridToMoveGrid];

		_moveGrid[(int)toTile.x][(int)toTile.y] = 0;
		bool foundRoute = false;
		[self propagateGridCostToX:toTile.x y:toTile.y fromTile:fromTile foundRoute:&foundRoute];
	}
}


-(void) propagateGridCostToX:(int)x y:(int)y fromTile:(CGPoint)fromTile foundRoute:(bool*)foundRoute{

	if(x < 0 || x >= _gridWidth) {
		return;
	}
	if(y < 0 || y >= _gridHeight) {
		return;
	}

	if(fromTile.x >= 0 && fromTile.y >= 0 && fromTile.x == x && fromTile.y == y) {
		//find the fastest route - not necessarily the best
		if(foundRoute != nil) {
			*foundRoute = true;
		}
	}
	
	double w = _moveGrid[x][y];
	if(w > _gridWidth*4) {
		//this is an approximation to increase speed - it can cause failures to find any path at all (very complex ones)
		return;
	}
	double wN = y+1 > _gridHeight-1 ? -10000 : _moveGrid[x][y+1];
	double wS = y-1 < 0 ? -10000 : _moveGrid[x][y-1];
	double wE = x+1 > _gridWidth-1 ? -10000 : _moveGrid[x+1][y];
	double wW = x-1 < 0 ? -10000 : _moveGrid[x-1][y];

	/*if(w != 0 && w != 1) {
		NSLog(@"%d,%d = %f", x, y, w);
	}*/

	
	bool changedN = false;
	bool changedS = false;
	bool changedE = false;
	bool changedW = false;
	

	if(y < _gridHeight-1 && _baseGrid[x][y+1] < HARD_BORDER_WEIGHT && (wN == _baseGrid[x][y+1] || wN > w+1)) {
		_moveGrid[x][y+1] = w+1 + (_baseGrid[x][y+1] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x][y+1]);
		changedN = true;
	}
	if(y > 0 && _baseGrid[x][y-1] < HARD_BORDER_WEIGHT && (wS == _baseGrid[x][y-1] || wS > w+1)) {
		_moveGrid[x][y-1] = w+1  + (_baseGrid[x][y-1] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x][y-1]);
		changedS = true;
	}
	if(x < _gridWidth-1 && _baseGrid[x+1][y] < HARD_BORDER_WEIGHT && (wE == _baseGrid[x+1][y] || wE > w+1)) {
		_moveGrid[x+1][y] = w+1 + (_baseGrid[x+1][y] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x+1][y]);
		changedE = true;
	}
	if(x > 0 && _baseGrid[x-1][y] < HARD_BORDER_WEIGHT && (wW == _baseGrid[x-1][y] || wW > w+1)) {
		_moveGrid[x-1][y] = w+1  + (_baseGrid[x-1][y] == INITIAL_GRID_WEIGHT ? 0 : _baseGrid[x-1][y]);
		changedW = true;
	}
	
	if(changedN) {
		[self propagateGridCostToX:x y:y+1 fromTile:fromTile foundRoute:foundRoute];
	}
	if(changedS) {
		[self propagateGridCostToX:x y:y-1 fromTile:fromTile foundRoute:foundRoute];
	}
	if(changedE) {
		[self propagateGridCostToX:x+1 y:y fromTile:fromTile foundRoute:foundRoute];
	}
	if(changedW) {
		[self propagateGridCostToX:x-1 y:y fromTile:fromTile foundRoute:foundRoute];
	}
	
}


@end
