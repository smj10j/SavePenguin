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
									

		_buyButton = [_levelLoader createSpriteWithName:@"Buy_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[_buyButton prepareAnimationNamed:@"Menu_Buy_Button" fromSHScene:@"Spritesheet"];
		_buyButton.opacity = 150;
		[_buyButton transformPosition: ccp(inAppPurchaseInfoContainer.boundingBox.origin.x + inAppPurchaseInfoContainer.boundingBox.size.width/2,
											inAppPurchaseInfoContainer.boundingBox.origin.y + _buyButton.boundingBox.size.height/2 + 110*SCALING_FACTOR_V)];
		[_buyButton registerTouchBeganObserver:self selector:@selector(onTouchBeganBuy:)];
		[_buyButton registerTouchEndedObserver:self selector:@selector(onBuy:)];
		
		
		
				
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

	//filled and attached to each IAP item
	NSMutableDictionary* itemData = nil;


	LHSprite* santaHat = [_levelLoader createSpriteWithName:@"Santa_Hat_Big" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[santaHat transformPosition: ccp(80*SCALING_FACTOR_H + santaHat.boundingBox.size.width/2,
										140*SCALING_FACTOR_V + santaHat.boundingBox.size.height/2)];
	[santaHat registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[santaHat registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[santaHat runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCFadeTo actionWithDuration:0.5f opacity:170],
								[CCFadeTo actionWithDuration:0.5f opacity:225],
							nil]
						]
	];
	itemData = [[NSMutableDictionary alloc] init];
	[itemData setObject:@"Strange Hat" forKey:@"Name"];
	[itemData setObject:[NSNumber numberWithInt:40]	forKey:@"Cost"];
	[itemData setObject:[NSNumber numberWithInt:10]	forKey:@"Amount"];
	[itemData setObject:@"\"Found\" by a group of penguin adventures in the North, these magical hats appear to make the wearer invisible..." forKey:@"Description"];
	santaHat.userData = itemData;
	
	
	LHSprite* bagOfFish = [_levelLoader createSpriteWithName:@"Bag_of_Fish_Big" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[bagOfFish transformPosition: ccp(260*SCALING_FACTOR_H + bagOfFish.boundingBox.size.width/2,
										240*SCALING_FACTOR_V + bagOfFish.boundingBox.size.height/2)];
	[bagOfFish registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[bagOfFish registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[bagOfFish runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCFadeTo actionWithDuration:0.5f opacity:170],
								[CCFadeTo actionWithDuration:0.5f opacity:225],
							nil]
						]
	];
	itemData = [[NSMutableDictionary alloc] init];
	[itemData setObject:@"Bag of Fish" forKey:@"Name"];
	[itemData setObject:[NSNumber numberWithInt:30]	forKey:@"Cost"];
	[itemData setObject:[NSNumber numberWithInt:10]	forKey:@"Amount"];
	[itemData setObject:@"If there's one thing that sharks and penguins can agree on it's that a ready-made bag full of fish is hard to turn down." forKey:@"Description"];	
	bagOfFish.userData = itemData;


	
	LHSprite* antiShark272 = [_levelLoader createSpriteWithName:@"Anti_Shark_272_1" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[antiShark272 prepareAnimationNamed:@"Toolbox_Anti_Shark_272" fromSHScene:@"Spritesheet"];
	[antiShark272 transformPosition: ccp(400*SCALING_FACTOR_H + antiShark272.boundingBox.size.width/2,
										160*SCALING_FACTOR_V + antiShark272.boundingBox.size.height/2)];
	[antiShark272 registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[antiShark272 registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[antiShark272 playAnimation];
	[antiShark272 runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCFadeTo actionWithDuration:0.5f opacity:170],
								[CCFadeTo actionWithDuration:0.5f opacity:225],
							nil]
						]
	];
	itemData = [[NSMutableDictionary alloc] init];
	[itemData setObject:@"Anti Shark 272™" forKey:@"Name"];
	[itemData setObject:[NSNumber numberWithInt:25]	forKey:@"Cost"];
	[itemData setObject:[NSNumber numberWithInt:15]	forKey:@"Amount"];
	[itemData setObject:@"These older-model anti-shark devices were recovered near destroyed shark cages. Surely it has no bearing on their effectiveness." forKey:@"Description"];	
	antiShark272.userData = itemData;

}


-(void)onSelectItem:(LHTouchInfo*)info {
	if(info.sprite == nil) return;

	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}

	_selectedIAPItem = info.sprite;


	[_iapItemImageContainer removeAllChildrenWithCleanup:YES];
	LHSprite* itemImage = [_levelLoader createSpriteWithName:_selectedIAPItem.shSpriteName fromSheet:_selectedIAPItem.shSheetName fromSHFile:_selectedIAPItem.shSceneName parent:_iapItemImageContainer];
	[itemImage transformPosition:ccp(_iapItemImageContainer.boundingBox.size.width/2,
									 _iapItemImageContainer.boundingBox.size.height/2)];
	if(![_selectedIAPItem.animationName isEqualToString:@""]) {
		[itemImage prepareAnimationNamed:_selectedIAPItem.animationName fromSHScene:_selectedIAPItem.animationSHScene];
		[itemImage playAnimation];
	}
	


	//add in the object info
	NSMutableDictionary* iapItemData = (NSMutableDictionary*)_selectedIAPItem.userData;
	NSString* name = [iapItemData objectForKey:@"Name"];
	NSString* description = [iapItemData objectForKey:@"Description"];
	int cost = [(NSNumber*)[iapItemData objectForKey:@"Cost"] intValue];
	int amount = [(NSNumber*)[iapItemData objectForKey:@"Amount"] intValue];
	
	
	_iapItemNameLabel.string = [NSString stringWithFormat:@"%@ (%d)", name, amount];
	_iapItemCostLabel.string = [NSString stringWithFormat:@"%d", cost];
	[_iapItemCostCoinsIcon transformPosition: ccp(_iapItemCostLabel.position.x
													+ _iapItemCostLabel.boundingBox.size.width/2
													+ 30*SCALING_FACTOR_H,
												_iapItemCostLabel.position.y)];
	_iapItemCostCoinsIcon.visible = true;
	_iapItemDescriptionLabel.string = [NSString stringWithFormat:@"%@", description];


	int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
	if(cost > availableCoins) {
		_buyButton.opacity = 150;
	}else {
		_buyButton.opacity = 255;
	}
}




-(void)onTouchBeganAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}


-(void)onTouchBeganBuy:(LHTouchInfo*)info {

	if(!DISTRIBUTION_MODE && _selectedIAPItem == nil) {
		[SettingsManager incrementIntBy:100 forKey:SETTING_TOTAL_AVAILABLE_COINS];
		[SettingsManager incrementIntBy:100 forKey:SETTING_TOTAL_EARNED_COINS];
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[InAppPurchaseLayer scene] ]];
		return;
	}

	if(info.sprite == nil || _selectedIAPItem == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}

-(void)onBuy:(LHTouchInfo*)info {
	if(info.sprite == nil || _selectedIAPItem == nil) return;
	
	int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
	NSMutableDictionary* iapItemData = (NSMutableDictionary*)_selectedIAPItem.userData;
	NSString* name = [iapItemData objectForKey:@"Name"];
	int cost = [(NSNumber*)[iapItemData objectForKey:@"Cost"] intValue];
	int amount = [(NSNumber*)[iapItemData objectForKey:@"Amount"] intValue];
	
	if(cost > availableCoins) {
		if(DEBUG_IAP) DebugLog(@"Not enough coins - item is %d and we have %d", cost, availableCoins);
		return;
	}	
	
	//visual feedback
	[info.sprite setFrame:info.sprite.currentFrame-1];	//active state
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	NSString* spriteName = [_selectedIAPItem.shSpriteName stringByReplacingOccurrencesOfString:@"_Big" withString:@""];
	if(DEBUG_IAP) DebugLog(@"Purchasing %d units of item %@ for %d - logging as sprite name %@", amount, name, cost, spriteName);

	//credit
	NSString* itemSettingKey = [NSString stringWithFormat:@"%@%@", SETTING_IAP_TOOLBOX_ITEM_COUNT, spriteName];
	int ownedAmount = [SettingsManager incrementIntBy:amount forKey:itemSettingKey];

	//charge!
	availableCoins = [SettingsManager decrementIntBy:cost forKey:SETTING_TOTAL_AVAILABLE_COINS];
	
	//update UI
	[_availableCoinsLabel runAction:[CCSequence actions:
			[CCFadeOut actionWithDuration:0.25f],
			[CCCallBlock actionWithBlock:^{
				_availableCoinsLabel.string = [NSString stringWithFormat:@"You have %d", availableCoins];
			}],
			[CCFadeIn actionWithDuration:0.50f],
		nil]
	];

	if(DEBUG_IAP) DebugLog(@"We now have %d units of %@ and %d coins", ownedAmount, name, availableCoins);
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

	for(LHSprite* sprite in [_levelLoader allSprites]) {
		if(sprite.userData != nil) {
			[(NSMutableDictionary*)sprite.userData release];
		}
	}

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();
}	

@end
