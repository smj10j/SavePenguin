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
-(instancetype) init
{
	if( (self=[super init])) {
		
		self.isTouchEnabled = YES;

		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];


		//in app purchase setup
		_iapManager = [[IAPManager alloc] init];

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


		_itemDatas = [[NSMutableDictionary alloc] init];

		[self addIAPItemsToSand];

		if([SettingsManager boolForKey:SETTING_MUSIC_ENABLED] && ![[SimpleAudioEngine sharedEngine] isBackgroundMusicPlaying]) {
			[self fadeInBackgroundMusic:@"sounds/menu/ambient/theme.mp3"];
		}

		[Analytics logEvent:@"View_IAP"];
	}
	
	if(DEBUG_MEMORY) DebugLog(@"Initialized InAppPurchaseLayer");
	if(DEBUG_MEMORY) report_memory();
	
	return self;
}


-(void)addIAPItemsToSand {

	CGSize winSize = [[CCDirector sharedDirector] winSize];

	LHSprite* santaHat = [_levelLoader createSpriteWithName:@"Santa_Hat_Big" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[santaHat transformPosition: ccp(winSize.width/2 - 390*SCALING_FACTOR_H + santaHat.boundingBox.size.width/2,
										winSize.height/2 - 150*SCALING_FACTOR_V - (IS_IPHONE ? 10 : 0) + santaHat.boundingBox.size.height/2)];
	[santaHat registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[santaHat registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[santaHat runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCTintTo actionWithDuration:0.5f red:220 green:220 blue:255],
								[CCTintTo actionWithDuration:0.5f red:255 green:255 blue:255],
							nil]
						]
	];
	NSMutableDictionary* itemData = [[NSMutableDictionary alloc] init];
	itemData[@"Name"] = @"Strange Hat";
	itemData[@"Cost"] = @30;
	itemData[@"Amount"] = @5;
	itemData[@"Description"] = @"\"Found\" by a group of penguin adventures in the North, these magical hats appear to make the wearer invisible...";
	_itemDatas[santaHat.uniqueName] = itemData;
	[itemData release];
	
	
	LHSprite* bagOfFish = [_levelLoader createSpriteWithName:@"Bag_of_Fish_Big" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[bagOfFish transformPosition: ccp(winSize.width/2 - 280*SCALING_FACTOR_H + bagOfFish.boundingBox.size.width/2,
										winSize.height/2 - 240*SCALING_FACTOR_V - (IS_IPHONE ? 10 : 0) + bagOfFish.boundingBox.size.height/2)];
	[bagOfFish registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[bagOfFish registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[bagOfFish runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCTintTo actionWithDuration:0.5f red:220 green:220 blue:255],
								[CCTintTo actionWithDuration:0.5f red:255 green:255 blue:255],
							nil]
						]
	];
	itemData = [[NSMutableDictionary alloc] init];
	itemData[@"Name"] = @"Bag of Fish";
	itemData[@"Cost"] = @25;
	itemData[@"Amount"] = @5;
	itemData[@"Description"] = @"If there's one thing that sharks and penguins can agree on it's that a ready-made bag of tasty fish is hard to turn down.";	
	_itemDatas[bagOfFish.uniqueName] = itemData;
	[itemData release];


	
	LHSprite* antiShark272 = [_levelLoader createSpriteWithName:@"Anti_Shark_272_1" fromSheet:@"Toolbox" fromSHFile:@"Spritesheet" parent:self];
	[antiShark272 prepareAnimationNamed:@"Toolbox_Anti_Shark_272" fromSHScene:@"Spritesheet"];
	[antiShark272 transformPosition: ccp(winSize.width/2 - 180*SCALING_FACTOR_H + antiShark272.boundingBox.size.width/2,
										winSize.height/2 - 145*SCALING_FACTOR_V - (IS_IPHONE ? 10 : 0) + antiShark272.boundingBox.size.height/2)];
	[antiShark272 registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
	[antiShark272 registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

	[antiShark272 playAnimation];
	[antiShark272 runAction:[CCRepeatForever actionWithAction:
							[CCSequence actions:
								[CCTintTo actionWithDuration:0.5f red:220 green:220 blue:255],
								[CCTintTo actionWithDuration:0.5f red:255 green:255 blue:255],
							nil]
						]
	];
	itemData = [[NSMutableDictionary alloc] init];
	itemData[@"Name"] = @"Anti Shark 272™";
	itemData[@"Cost"] = @25;
	itemData[@"Amount"] = @10;
	itemData[@"Description"] = @"These older-model anti-shark devices were recovered near the remains of ruined shark cages.";	
	_itemDatas[antiShark272.uniqueName] = itemData;
	[itemData release];




	//100 coins
    [_iapManager requestProduct:IAP_PACKAGE_ID_1 successCallback:^(NSString* productPrice){

		if(DEBUG_IAP) DebugLog(@"Requested IAP product successfully!");
		
		LHSprite* buyCoinsIcon = [_levelLoader createSpriteWithName:@"Coins_Icon" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[buyCoinsIcon transformPosition: ccp(winSize.width/2 - 100*SCALING_FACTOR_H + buyCoinsIcon.boundingBox.size.width/2,
											winSize.height/2 - 240*SCALING_FACTOR_V - (IS_IPHONE ? 10 : 0) + buyCoinsIcon.boundingBox.size.height/2)];
		[buyCoinsIcon registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[buyCoinsIcon registerTouchEndedObserver:self selector:@selector(onSelectItem:)];

		[buyCoinsIcon runAction:[CCRepeatForever actionWithAction:
								[CCSequence actions:
									[CCTintTo actionWithDuration:0.5f red:220 green:220 blue:255],
									[CCTintTo actionWithDuration:0.5f red:255 green:255 blue:255],
								nil]
							]
		];
		NSMutableDictionary* itemData = [[NSMutableDictionary alloc] init];
		itemData[@"Name"] = @"100 Coins";
		itemData[@"IS_IAP"] = @true;
		itemData[@"IAP_PRICE"] = productPrice;
		itemData[@"Description"] = @"Use coins to upgrade your toolbox and unlock level packs!";	
		_itemDatas[buyCoinsIcon.uniqueName] = itemData;
		[itemData release];
	
	}];
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
	NSMutableDictionary* iapItemData = (NSMutableDictionary*)_itemDatas[_selectedIAPItem.uniqueName];
	NSString* name = iapItemData[@"Name"];
	NSString* description = iapItemData[@"Description"];
	bool isIAP = ((NSNumber*)iapItemData[@"IS_IAP"]).boolValue;
	NSString* iapPrice = iapItemData[@"IAP_PRICE"];
	int cost = ((NSNumber*)iapItemData[@"Cost"]).intValue;
	int amount = ((NSNumber*)iapItemData[@"Amount"]).intValue;
	
	int availableCoins = [SettingsManager intForKey:SETTING_TOTAL_AVAILABLE_COINS];
	
	if(!isIAP) {
	
		_iapItemNameLabel.string = [NSString stringWithFormat:@"%@ (%d)", name, amount];
		_iapItemDescriptionLabel.string = [NSString stringWithFormat:@"%@", description];

		_iapItemCostLabel.string = [NSString stringWithFormat:@"%d", cost];
		[_iapItemCostCoinsIcon transformPosition: ccp(_iapItemCostLabel.position.x
														+ _iapItemCostLabel.boundingBox.size.width/2
														+ 30*SCALING_FACTOR_H,
													_iapItemCostLabel.position.y)];
		_iapItemCostCoinsIcon.visible = true;


		if(cost > availableCoins) {
			_buyButton.opacity = 150;
		}else {
			_buyButton.opacity = 255;
		}
	}else {
	
		_iapItemNameLabel.string = name;
		_iapItemDescriptionLabel.string = description;
		_iapItemCostLabel.string = iapPrice;
	
		_buyButton.opacity = 255;
		_iapItemCostCoinsIcon.visible = false;
	}
	
	
	
	//analytics logging
	NSDictionary* flurryParams = @{@"Name": name,
		@"AvailableCoins": @(availableCoins)};
	[Analytics logEvent:@"View_IAP_Item" withParameters:flurryParams];
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
	NSMutableDictionary* iapItemData = (NSMutableDictionary*)_itemDatas[_selectedIAPItem.uniqueName];
	NSString* name = iapItemData[@"Name"];
	bool isIAP = ((NSNumber*)iapItemData[@"IS_IAP"]).boolValue;
	int cost = ((NSNumber*)iapItemData[@"Cost"]).intValue;
	int amount = ((NSNumber*)iapItemData[@"Amount"]).intValue;
	
	
	//IAP?
    if (isIAP) {
        // Then, call the purchase method.
        if (![_iapManager purchase:_iapManager.selectedProduct
						successCallback:^(bool isRestore){
						
							int availableCoins = [SettingsManager incrementIntBy:100 forKey:SETTING_TOTAL_AVAILABLE_COINS];
							
							//update UI
							[_availableCoinsLabel runAction:[CCSequence actions:
									[CCFadeOut actionWithDuration:0.25f],
									[CCCallBlock actionWithBlock:^{
										_availableCoinsLabel.string = [NSString stringWithFormat:@"You have %d", availableCoins];
									}],
									[CCFadeIn actionWithDuration:0.50f],
								nil]
							];						
						
							NSString *alertMessage = [NSString stringWithFormat:@"Your purchase for %@ was %@. Enjoy!", _iapManager.selectedProduct.localizedTitle, (isRestore ? @"restored" : @"successful")];
							UIAlertView *updatedAlert = [[UIAlertView alloc] initWithTitle:@"Thank You!" message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
							[updatedAlert show];
							[updatedAlert release];
							

							//analytics logging
							NSDictionary* flurryParams = @{@"Name": name,
								@"AvailableCoins": @(availableCoins)};
							[Analytics logEvent:@"Buy_IAP_Item" withParameters:flurryParams];
						
						}]) {
            // Returned NO, so notify user that In-App Purchase is Disabled in their Settings.
            UIAlertView *settingsAlert = [[UIAlertView alloc] initWithTitle:@"Allow Purchases" message:@"You must first enable In-App Purchase in your iOS Settings before making this purchase." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [settingsAlert show];
            [settingsAlert release];
        }
		
		return;
    }		
	
	
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
	
	//analytics logging
	NSDictionary* flurryParams = @{@"Name": name,
		@"NewAvailableCoins": @(availableCoins),
		@"OwnedAmount": @(ownedAmount)};
	[Analytics logEvent:@"Buy_IAP_Item" withParameters:flurryParams];

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
	
		[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
	
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[GameLayer sceneWithLevelPackPath:lastLevelPackPath levelPath:lastLevelPath] ]];
	}else {
		[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[MainMenuLayer scene] ]];
	}
}


-(void)fadeInBackgroundMusic:(NSString*)path {
	
	float prevVolume = [SimpleAudioEngine sharedEngine].backgroundMusicVolume;
	float fadeInTimeOffset = 0;
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, fadeInTimeOffset * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
		[SimpleAudioEngine sharedEngine].backgroundMusicVolume = .1;
		[[SimpleAudioEngine sharedEngine] playBackgroundMusic:path loop:YES];
	});
	
	for(float volume = .1; volume <= prevVolume; volume+= .1) {
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, fadeInTimeOffset + volume * NSEC_PER_SEC), dispatch_get_current_queue(), ^{
			[SimpleAudioEngine sharedEngine].backgroundMusicVolume = volume;
		});
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

	[_iapManager release];

	[_itemDatas release];

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();
}	

@end
