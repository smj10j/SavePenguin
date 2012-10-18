//
//  SharkMoveGridData.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/18/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SharkMoveGridData : NSObject {

	int** _grid;
	CGPoint* _moveHistory;
	int _moveHistoryIndex;
}

- (id)initWithGrid:(int**)grid;
- (int**)grid;

- (void)logMove:(CGPoint)pos;
- (double)distanceMoved;

@end



#define MOVE_HISTORY_SIZE 50