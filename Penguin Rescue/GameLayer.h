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

#import "LevelPackManager.h"
#import "SettingsManager.h"
#import "Constants.h"

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
	
	NSString* _levelPath;
	NSString* _levelPackPath;
	NSDictionary* _levelData;
	
	LevelHelperLoader* _levelLoader;
	CGSize _levelSize;
	LHLayer* _mainLayer;
	LHBatch* _toolboxBatchNode;
	LHBatch* _mapBatchNode;
	LHBatch* _actorsBatchNode;
	
	GAME_STATE _state;
	
	int** _sharkMapfeaturesGrid;
	int** _penguinMapfeaturesGrid;
	NSMutableDictionary* _sharkMoveGridDatas;
	NSMutableDictionary* _penguinMoveGridDatas;
	bool _isUpdatingSharkMoveGrids;
	bool _isUpdatingPenguinMoveGrids;
	dispatch_queue_t _moveGridUpdateQueue;

	
	int _gridSize;
	int _gridWidth;
	int _gridHeight;
	
	NSMutableDictionary* _penguinsToPutOnLand;
	
	LHSprite* _bottomBarContainer;
	LHSprite* _playPauseButton;
	LHSprite* _restartButton;
	LHSprite* _menuPopupContainer;
	
	bool _moveActiveToolboxItemIntoWorld;
	LHSprite* _activeToolboxItem;
	CGPoint _activeToolboxItemOriginalPosition;
	NSMutableDictionary* _toolGroups;
	bool _shouldUpdateToolbox;
	int _toolboxItemSize;


	bool _shouldRegenerateFeatureMaps;
	
	
	CGPoint _startTouch;
	CGPoint _lastTouch;
	NSMutableArray* _placedToolboxItems;
	
	
	
	bool __DEBUG_SHARKS;
	bool __DEBUG_PENGUINS;
	double __DEBUG_TOUCH_SECONDS;
	ccColor3B __DEBUG_ORIG_BACKGROUND_COLOR;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

+(void)setLevelPackPath:(NSString*)levelPackPath;
+(void)setLevelPath:(NSString*)levelPath;

@end



