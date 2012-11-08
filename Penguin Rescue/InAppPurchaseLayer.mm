//
//  InAppPurchaseLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "InAppPurchaseLayer.h"
#import "MainMenuLayer.h"
#import "GameLayer.h"
#import "AppDelegate.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"
#import "Utilities.h"
#import "Analytics.h"

#pragma mark - InAppPurchaseLayer

@implementation InAppPurchaseLayer

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	InAppPurchaseLayer *layer = [InAppPurchaseLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {
		
		self.isTouchEnabled = YES;

		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];

		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"InAppPurchase"]];
		[_levelLoader addObjectsToWorld:nil cocos2dLayer:self];

			
				
		LHSprite* inAppPurchaseInfoContainer = [_levelLoader createSpriteWithName:@"IAP_Info_Panel" fromSheet:@"MenuBackgrounds1" fromSHFile:@"Spritesheet" parent:self];
		[inAppPurchaseInfoContainer transformPosition: ccp(winSize.width
															- inAppPurchaseInfoContainer.boundingBox.size.width/2
															+ 40*SCALING_FACTOR_H,
															winSize.height/2)];

		//item information

		_iapItemImageContainer = [_levelLoader createSpriteWithName:@"IAP_Item_Container" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:inAppPurchaseInfoContainer];
		[_iapItemImageContainer transformPosition: ccp(inAppPurchaseInfoContainer.boundingBox.size.width/2,
													inAppPurchaseInfoContainer.boundingBox.size.height - _iapItemImageContainer.boundingBox.size.height/2 - 40*SCALING_FACTOR_V)];
					
		_iapItemNameLabel = [CCLabelTTF labelWithString:@" " fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS dimensions:CGSizeMake(inAppPurchaseInfoContainer.boundingBox.size.width-80*SCALING_FACTOR_H,
																	40*SCALING_FACTOR_V)
																	hAlignment:kCCTextAlignmentCenter];
		_iapItemNameLabel.color = ccBLACK;
		_iapItemNameLabel.position = ccp(_iapItemImageContainer.position.x,
											_iapItemImageContainer.position.y
											- _iapItemImageContainer.boundingBox.size.height/2
											- _iapItemNameLabel.boundingBox.size.height/2
											- 15*SCALING_FACTOR_V
											- (IS_IPHONE ? 3 : 0)
										);
		[inAppPurchaseInfoContainer addChild:_iapItemNameLabel];
								

		_iapItemCostLabel = [CCLabelTTF labelWithString:@" " fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS];
		_iapItemCostLabel.color = ccBLACK;
		_iapItemCostLabel.position = ccp(_iapItemNameLabel.position.x,
											_iapItemNameLabel.position.y
											- _iapItemNameLabel.boundingBox.size.height/2
											- _iapItemCostLabel.boundingBox.size.height/2
											- 10*SCALING_FACTOR_V
											- (IS_IPHONE ? 5 : 0)
										);
		[inAppPurchaseInfoContainer addChild:_iapItemCostLabel];

		_iapItemCostCoinsIcon = [_levelLoader createSpriteWithName:@"Coins_Icon" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:inAppPurchaseInfoContainer];
		_iapItemCostCoinsIcon.visible = false;
		[_iapItemCostCoinsIcon transformPosition: ccp(_iapItemCostLabel.position.x
														+ _iapItemCostLabel.boundingBox.size.width/2
														+ 30*SCALING_FACTOR_H,
													_iapItemCostLabel.position.y)];
								


		_iapItemDescriptionLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"Select an item to learn more about it"] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS dimensions:CGSizeMake(
																				inAppPurchaseInfoContainer.boundingBox.size.width
																					-80*SCALING_FACTOR_H,
																				400*SCALING_FACTOR_V)
																		hAlignment:kCCTextAlignmentCenter];
		_iapItemDescriptionLabel.color = ccBLACK;
		_iapItemDescriptionLabel.position = ccp(_iapItemCostLabel.position.x,
											_iapItemCostLabel.position.y
											- _iapItemCostLabel.boundingBox.size.height/2
											- _iapItemDescriptionLabel.boundingBox.size.height/2
											- 40*SCALING_FACTOR_V
										);

		[inAppPurchaseInfoContainer addChild:_iapItemDescriptionLabel];
								
								
		// Buy button and coins available
		
		int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
		_availableCoinsLabel = [CCLabelTTF labelWithString:[NSString stringWithFormat:@"You have %d", availableCoins] fontName:@"Helvetica" fontSize:24*SCALING_FACTOR_FONTS dimensions:CGSizeMake(220*SCALING_FACTOR_H +(IS_IPHONE ? 5: 0), 40*SCALING_FACTOR_V) hAlignment:kCCTextAlignmentCenter];
		_availableCoinsLabel.color = ccBLACK;
		_availableCoinsLabel.position = ccp(inAppPurchaseInfoContainer.boundingBox.size.width/2,
											75*SCALING_FACTOR_V);
		[inAppPurchaseInfoContainer addChild:_availableCoinsLabel];

		LHSprite* availableCoinsIcon = [_levelLoader createSpriteWithName:@"Coins_Icon" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:inAppPurchaseInfoContainer];
		[availableCoinsIcon transformPosition: ccp(inAppPurchaseInfoContainer.boundingBox.size.width/2 + _availableCoinsLabel.boundingBox.size.width/2 +  10*SCALING_FACTOR_H,
										80*SCALING_FACTOR_V)];
									

		LHSprite* buyButton = [_levelLoader createSpriteWithName:@"Buy_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[buyButton prepareAnimationNamed:@"Menu_Buy_Button" fromSHScene:@"Spritesheet"];
		[buyButton transformPosition: ccp(inAppPurchaseInfoContainer.boundingBox.origin.x + inAppPurchaseInfoContainer.boundingBox.size.width/2,
											inAppPurchaseInfoContainer.boundingBox.origin.y + buyButton.boundingBox.size.height/2 + 110*SCALING_FACTOR_V)];
		[buyButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[buyButton registerTouchEndedObserver:self selector:@selector(onBuy:)];
		
		
		
				
		LHSprite* backButton = [_levelLoader createSpriteWithName:@"Back_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[backButton prepareAnimationNamed:@"Menu_Back_Button" fromSHScene:@"Spritesheet"];
		[backButton transformPosition: ccp(20*SCALING_FACTOR_H + backButton.boundingBox.size.width/2,
											20*SCALING_FACTOR_V + backButton.boundingBox.size.height/2)];
		[backButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[backButton registerTouchEndedObserver:self selector:@selector(onBack:)];



		[self addIAPItemsToSand];



		[Analytics logEvent:@"View_IAP"];
	}
	
	if(DEBUG_MEMORY) DebugLog(@"Initialized InAppPurchaseLayer");
	if(DEBUG_MEMORY) report_memory();
	
	return self;
}


-(void)addIAPItemsToSand {

	LHSprite* santaHat = [_levelLoader createSpriteWithName:@"Santa_Hat_Big" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[santaHat transformPosition: ccp(80*SCALING_FACTOR_H + santaHat.boundingBox.size.width/2,
										140*SCALING_FACTOR_V + santaHat.boundingBox.size.height/2)];
	[santaHat registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[santaHat registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[santaHat runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCFadeTo actionWithDuration:0.5f opacity:140],
								[CCFadeTo actionWithDuration:0.5f opacity:225],
							nil]
						]
	];


}


-(void)onSelectItem:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	LHSprite* iapItem = info.sprite;


	[_iapItemImageContainer removeAllChildrenWithCleanup:YES];
	LHSprite* itemImage = [_levelLoader createSpriteWithName:iapItem.shSpriteName fromSheet:iapItem.shSheetName fromSHFile:iapItem.shSceneName parent:_iapItemImageContainer];
	[itemImage transformPosition:ccp(_iapItemImageContainer.boundingBox.size.width/2,
									 _iapItemImageContainer.boundingBox.size.height/2)];
	
	
	//TODO: add in the item info from some kind of class object
	_iapItemNameLabel.string = [NSString stringWithFormat:@"%@", @"Santa Hat (15)"];
	
	
	_iapItemCostLabel.string = [NSString stringWithFormat:@"%d", 40];
	[_iapItemCostCoinsIcon transformPosition: ccp(_iapItemCostLabel.position.x
													+ _iapItemCostLabel.boundingBox.size.width/2
													+ 30*SCALING_FACTOR_H,
												_iapItemCostLabel.position.y)];
	_iapItemCostCoinsIcon.visible = true;
	
	
	
	
	_iapItemDescriptionLabel.string = [NSString stringWithFormat:@"%@", @"This magical item somehow makes the wearer invisible"];


}




-(void)onTouchBeganAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}



-(void)onBuy:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	
	//[SettingsManager decrementIntBy:cost forKey:SETTING_TOTAL_AVAILABLE_COINS];
	_availableCoinsLabel.string = [NSString stringWithFormat:@"You have %d", [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS]];
}

-(void)onBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	NSString* lastLevelPackPath = [SettingsManager stringForKey:SETTING_LAST_LEVEL_PACK_PATH];
	NSString* lastLevelPath = [SettingsManager stringForKey:SETTING_LAST_LEVEL_PATH];
	
	if(lastLevelPackPath != nil) {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[GameLayer sceneWithLevelPackPath:lastLevelPackPath levelPath:lastLevelPath] ]];
	}else {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[MainMenuLayer scene] ]];
	}
}





-(void) onEnter
{
	[super onEnter];
}


-(void) onExit {
	if(DEBUG_MEMORY) DebugLog(@"InAppPurchaseLayer onExit");

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}			
	
	[super onExit];
}

-(void) dealloc
{
	if(DEBUG_MEMORY) DebugLog(@"InAppPurchaseLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();
}	

@end
