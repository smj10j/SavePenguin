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
#import "ScoreKeeper.h"
#import "ToolboxItemRotationCrosshair.h"
#import "PowerBarNode.h"
#import "IAPManager.h"
#import "Constants.h"


enum GAME_STATE {
	SETUP,
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
	b2World* _world;
	float _box2dStepAccumulator;
	GLESDebugDraw *_debugDraw;
	LevelHelperLoader* _levelLoader;
	
	double _instanceId;
	
	NSString* _levelPath;
	NSString* _levelPackPath;
	NSDictionary* _levelData;
	
	CGSize _levelSize;
	LHLayer* _mainLayer;
	LHBatch* _toolboxBatchNode;
	LHBatch* _mapBatchNode;
	LHBatch* _actorsBatchNode;
	
	GAME_STATE _state;
	
	bool _isGeneratingFeatureGrid;
	bool _isInvalidatingSharkFeatureGrids;
	bool _isInvalidatingPenguinFeatureGrids;
	NSMutableArray* _sharksThatNeedToUpdateFeatureGrids;
	NSMutableArray* _penguinsThatNeedToUpdateFeatureGrids;
	short** _sharkMapfeaturesGrid;
	short** _penguinMapfeaturesGrid;
	NSMutableDictionary* _sharkMoveGridDatas;
	NSMutableDictionary* _penguinMoveGridDatas;
	bool _isUpdatingMoveGrids;
	dispatch_queue_t _moveGridUpdateQueue;
	
	bool _levelHasMovingBorders;
	bool _levelHasMovingLands;
	
	int _gridSize;
	int _gridWidth;
	int _gridHeight;
	
	IAPManager* _iapManager;
	
	NSMutableDictionary* _penguinsToPutOnLand;
	
	LHSprite* _playPauseButton;
	LHSprite* _restartButton;
	CCLabelTTF* _timeElapsedLabel;
	
	NSMutableArray* _inGameMenuItems;
	
	bool _moveActiveToolboxItemIntoWorld;
	LHSprite* _activeToolboxItem;
	double _activeToolboxItemSelectionTimestamp;
	ToolboxItemRotationCrosshair* _activeToolboxItemRotationCrosshair;
	CGPoint _activeToolboxItemOriginalPosition;
	NSMutableDictionary* _toolGroups;
	NSMutableDictionary* _iapToolGroups;
	bool _shouldUpdateToolbox;
	CGSize _toolboxItemSize;
	NSMutableArray* _placedToolboxItems;
	NSMutableArray* _newlyPlacedToolboxItems;
	ScoreKeeper* _toolsScoreKeeper;
	ScoreKeeper* _extraCreditScoreKeeper;
			
	NSMutableDictionary* _loudNoiseNodes;
	
	double _levelStartPlaceTime;
	double _levelStartRunningTime;
	double _levelPlaceTimeDuration;
	double _levelRunningTimeDuration;
	
	CGPoint _startTouch;
	CGPoint _lastTouch;
	
	PowerBarNode* _handOfGodPowerNode;
	double _handOfGodPowerSecondsUsed;
	double _handOfGodPowerSecondsRemaining;
	bool _isNudgingPenguin;
	
	
	CCParticleSystemQuad *_obstructionParticleSystem;
	
	
	bool __DEBUG_SHARKS;
	bool __DEBUG_PENGUINS;
	double __DEBUG_TOUCH_SECONDS;
	ccColor3B __DEBUG_ORIG_BACKGROUND_COLOR;
}

+(CCScene *) sceneWithLevelPackPath:(NSString*)levelPackPath levelPath:(NSString*)levelPath;

@end


#define ALERT_UPGRADE_TOOLBOX 1


