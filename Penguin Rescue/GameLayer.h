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
	PAUSE,
	RUNNING,
	GAME_OVER
};



// HelloWorldLayer
@interface GameLayer : CCLayer
{
	CCTexture2D* _spriteTexture_;	// weak ref
	b2World* _world;					// strong ref
	GLESDebugDraw *_debugDraw;		// strong ref
	
	
	LevelHelperLoader* _levelLoader;
	
	GAME_STATE _state;
	double _gameStartCountdownTimer;
	
	int** _sharkMoveGrid;
	int** _featuresGrid;
	int _gridWidth;
	int _gridHeight;
}

// returns a CCScene that contains the HelloWorldLayer as the only child
+(CCScene *) scene;

#define SCALING_FACTOR (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone ? 0.5 : 1.0)
#define TARGET_FPS 60

#define GRID_SIZE 25

#define SHARKS_COUNTDOWN_TIMER_INITIAL 1




@end
