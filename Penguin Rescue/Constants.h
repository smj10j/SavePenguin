//
//  Constants.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/24/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#ifndef Penguin_Rescue_Constants_h
#define Penguin_Rescue_Constants_h

//true to disable all output and send analytics data
#define DISTRIBUTION_MODE false



#define TEST_MODE false
#define TEST_LEVEL_PACK @"APenguinInNeed"
#define TEST_LEVEL @"WayWayUpThere"

 


#define DEBUG_ALL_THE_THINGS	( false							 && !DISTRIBUTION_MODE)
#define DEBUG_SCORING			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_SETTINGS			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_REVIEWS			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_LEVELS			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_MEMORY			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_MOVEGRID			((false	|| DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)
#define DEBUG_PENGUIN			((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)	//can be overridden in game
#define DEBUG_SHARK				((false || DEBUG_ALL_THE_THINGS) && !DISTRIBUTION_MODE)		//can be overridden in game

#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
#define SCALING_FACTOR_H (IS_IPHONE ? 480.0/1024.0 : 1.0)
#define SCALING_FACTOR_V (IS_IPHONE ? 320.0/768.0 : 1.0)
#define SCALING_FACTOR_GENERIC SCALING_FACTOR_V
#define SCALING_FACTOR_FONTS (IS_IPHONE ? 0.6 : 1.0)
#define TARGET_FPS 60
#define MIN_GRID_SIZE 8

#define SHARK_DIES_WHEN_STUCK false
#define PENGUIN_MOVE_HISTORY_SIZE 20
#define SHARK_MOVE_HISTORY_SIZE 50


#define HAND_OF_GOD_INITIAL_POWER 0
#define HAND_OF_GOD_POWER_REGENERATION_RATE .25


#define HUD_BUTTON_MARGIN_V 14*SCALING_FACTOR_V
#define HUD_BUTTON_MARGIN_H 16*SCALING_FACTOR_H

#define TOOLBOX_MARGIN_BOTTOM 10*SCALING_FACTOR_V
#define TOOLBOX_MARGIN_LEFT 20*SCALING_FACTOR_H
#define TOOLBOX_ITEM_CONTAINER_PADDING_H 20*SCALING_FACTOR_H
#define TOOLBOX_ITEM_CONTAINER_PADDING_V 20*SCALING_FACTOR_V
#define TOOLBOX_ITEM_CONTAINER_COUNT_FONT_SIZE 14
#define TOOLBOX_ITEM_STATS_FONT_SIZE (14*SCALING_FACTOR_FONTS)




#define SCORING_FONT_SIZE1 24*SCALING_FACTOR_FONTS
#define SCORING_FONT_SIZE2 30*SCALING_FACTOR_FONTS
#define SCORING_FONT_SIZE3 16*SCALING_FACTOR_FONTS
#define SCORING_FONT_COLOR1 ccRED
#define SCORING_FONT_COLOR2 ccBLACK
#define SCORING_FONT_COLOR3 ccWHITE

#define SCORING_MAX_SCORE_POSSIBLE 10000
#define SCORING_PLACE_SECOND_COST 40
#define SCORING_RUNNING_SECOND_COST 25
#define SCORING_HAND_OF_GOD_COST_PER_SECOND 2000




#define COMPANY_IDENTIFIER @"com.conquerllc"



#define SERVER_HOST @"www.conquerllc.com"
#define SERVER_PATH @"/webservice/games/PenguinRescue.php"
#define SERVER_URL [NSString stringWithFormat:@"http://%@%@", SERVER_HOST, SERVER_PATH]




#if !DISTRIBUTION_MODE
#define DebugLog( s, ... ) NSLog( @"<%@:(%d)> %@", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__, [NSString stringWithFormat:(s), ##__VA_ARGS__] )
#else
#define DebugLog( s, ... )
#endif

#endif

