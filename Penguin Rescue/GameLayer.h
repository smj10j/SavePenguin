//
//  GameLayer.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//

#import <Foundation/Foundation.h>
// When you import this file, you import all the cocos2d classes
#import "cocos2d.h"
#import "Box2D.h"
#import "GLES-Render.h"

#import "LevelHelperLoader.h"

//Pixel to metres ratio. Box2D uses metres as the unit for measurement.
//This ratio defines how many pixels correspond to 1 Box2D "metre"
//Box2D is optimized for objects of 1x1 metre therefore it makes sense
//to define the ratio so that your most common object type is 1x1 metre.
#define PTM_RATIO 32


enum GAME_STATE {
	PLACE,
	PAUSE,
	RUNNING,
	GAME_OVER
};

enum PROPAGATION_RESULT {
	FAILURE,
	SUCCESS,
	STOPPED
};


// HelloWorldLayer
@interface GameLayer : CCLayerColor
{
	CCTexture2D* _spriteTexture_;	// weak ref
	b2World* _world;					// strong ref
	GLESDebugDraw *_debugDraw;		// strong ref
	
	
	LevelHelperLoader* _levelLoader;
	LHLayer* _mainLayer;
	LHBatch* _toolboxBatchNode;
	
	GAME_STATE _state;
	
	int** _sharkMoveGrid;
	int** _penguinMoveGrid;
	int** _sharkMapfeaturesGrid;
	int** _penguinMapfeaturesGrid;
	NSMutableDictionary* _sharkMoveGridDatas;
	NSMutableDictionary* _penguinMoveGridDatas;
	bool _isUpdatingSharkMovementGrids;
	int _nextMovementGridSharkIndexToUpdate;
	
	int _gridSize;
	int _gridWidth;
	int _gridHeight;
	
	NSMutableDictionary* _penguinsToPutOnLand;
	
	LHSprite* _bottomBarContainer;
	LHSprite* _playPauseButton;
	LHSprite* _restartButton;
	
	bool _moveActiveToolboxItemIntoWorld;
	LHSprite* _activeToolboxItem;
	CGPoint _activeToolboxItemOriginalPosition;
	NSMutableDictionary* _toolGroups;
	bool _shouldUpdateToolbox;
	int _toolboxItemSize;


	bool _shouldRegenerateFeatureMaps;
	
	
	
	
	
	bool __DEBUG_SHARKS;
	bool __DEBUG_PENGUINS;
	double __DEBUG_TOUCH_SECONDS;
	ccColor3B __DEBUG_ORIG_BACKGROUND_COLOR;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

#define DEBUG_ALL_THE_THINGS false
#define DEBUG_PENGUIN false	//can be overridden in game
#define DEBUG_SHARK false	//can be overridden in game

#define SCALING_FACTOR (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 0.5 : 1.0)
#define TARGET_FPS 60

#define MAX_GRID_SIZE 48
#define MIN_GRID_SIZE 16
#define INITIAL_GRID_WEIGHT 25
#define INITIAL_ENDPOINT_GRID_WEIGHT INITIAL_GRID_WEIGHT-1
#define HARD_BORDER_WEIGHT 100

#define SHARK_DIES_WHEN_STUCK true
#define PENGUIN_MOVE_HISTORY_SIZE 20
#define SHARK_MOVE_HISTORY_SIZE 50



@end
