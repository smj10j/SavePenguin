//
//  Constants.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/24/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#ifndef Penguin_Rescue_Constants_h
#define Penguin_Rescue_Constants_h



//prepares all settings for App Store
//NOTE: be sure to set the correct distribution provisioning profile!
#define APPSTORE_BUILD true

//enables TestFlight as well as sets this as a Distribution build
//NOTE: be sure to set the correct distribution provisioning profile!
#define TESTFLIGHT_BUILD (false && !APPSTORE_BUILD)




//true to disable all output and send analytics data (DON'T SET THIS DIRECTLY)
#define DISTRIBUTION_MODE (false || TESTFLIGHT_BUILD || APPSTORE_BUILD)



//used to go to a specific level during level development
#define TEST_MODE (false && !DISTRIBUTION_MODE)
#define TEST_LEVEL_PACK @"Pack1"
#define TEST_LEVEL @"DangerDanger"

 


#define DEBUG_ALL_THE_THINGS	( false							 && !DISTRIBUTION_MODE)
#define DEBUG_SCORING			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_SETTINGS			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_TOOLBOX			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_REVIEWS			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_IAP				((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_LEVELS			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_MEMORY			((false	|| DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_MOVEGRID			((false	|| DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_PENGUIN			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)		//can be overridden in game
#define DEBUG_SHARK				((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)		//can be overridden in game

#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define IS_STUPID_IPHONE_5 ( fabs( ( double )[ [ UIScreen mainScreen ] bounds ].size.height - ( double )568 ) < DBL_EPSILON )
#define SCALING_FACTOR_H (IS_IPHONE ? 480.0/1024.0 : 1.0)
#define SCALING_FACTOR_V (IS_IPHONE ? 320.0/768.0 : 1.0)
#define SCALING_FACTOR_GENERIC SCALING_FACTOR_V
#define SCALING_FACTOR_FONTS (IS_IPHONE ? 0.6 : 1.0)
#define TARGET_FPS 60
#define TARGET_PHYSICS_STEP .03
#define MIN_GRID_SIZE 8
//Pixel to metres ratio. Box2D uses metres as the unit for measurement.
//This ratio defines how many pixels correspond to 1 Box2D "metre"
//Box2D is optimized for objects of 1x1 metre therefore it makes sense
//to define the ratio so that your most common object type is 1x1 metre.
#define PTM_RATIO (IS_IPHONE ? 32 : 64)



#define SHARK_DIES_WHEN_STUCK false

#define MAX_BUMP_ITERATIONS_TO_UNSTICK_FROM_LAND 12

#define INITIAL_FREE_COINS 20

#define HAND_OF_GOD_INITIAL_POWER .50
#define HAND_OF_GOD_POWER_REGENERATION_RATE .15
#define HAND_OF_GOD_POWER_FACTOR .09

#define ACTOR_MASS .25
/*

	Nov/6/2012

	dt = .0167 on iPhone 4S
	dt = .16 on iPad Retina Simulator
	dt = .0167 on iPad 1

*/
#define IMPULSE_SCALAR .10



#define HUD_BUTTON_MARGIN_V 14*SCALING_FACTOR_V
#define HUD_BUTTON_MARGIN_H 16*SCALING_FACTOR_H

#define TOOLBOX_MARGIN_BOTTOM 10*SCALING_FACTOR_V
#define TOOLBOX_MARGIN_LEFT 10*SCALING_FACTOR_H
#define TOOLBOX_ITEM_CONTAINER_PADDING_H 20*SCALING_FACTOR_H
#define TOOLBOX_ITEM_CONTAINER_PADDING_V 20*SCALING_FACTOR_V
#define TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE 13
#define TOOLBOX_ITEM_STATS_FONT_SIZE (13*SCALING_FACTOR_FONTS)




#define SCORING_FONT_SIZE1 24*SCALING_FACTOR_FONTS
#define SCORING_FONT_SIZE2 30*SCALING_FACTOR_FONTS
#define SCORING_FONT_SIZE3 16*SCALING_FACTOR_FONTS
#define SCORING_FONT_COLOR_NEUTRAL ccBLACK
#define SCORING_FONT_COLOR_NEUTRAL_CONTRAST ccWHITE
#define SCORING_FONT_COLOR_NOTICE ccRED
#define SCORING_FONT_COLOR_BAD ccRED
#define SCORING_FONT_COLOR_GOOD ccc3(40,180,40)

#define SCORING_MAX_SCORE_POSSIBLE 15000
#define SCORING_PLACE_SECOND_COST 40
#define SCORING_RUNNING_SECOND_COST 25
#define SCORING_HAND_OF_GOD_COST_PER_SECOND 6000

#define SCORING_CLOSE_CALL_DISTANCE 150*SCALING_FACTOR_GENERIC
#define SCORING_CLOSE_CALL_EXTRA_CREDIT 250
#define SCORING_COMBO_BASE_EXTRA_CREDIT 100

#define SCORING_MAX_COINS_PER_LEVEL 5



#define IAP_PACKAGE_ID_1 @"100_Coins"



#if !DISTRIBUTION_MODE
#define DebugLog( s, ... ) NSLog( @"<%@:(%d)> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DebugLog( s, ... )
#endif

#endif

