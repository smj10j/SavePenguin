//
//  AboutLayer.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//


// Import the interfaces
#import "AboutLayer.h"
#import "MainMenuLayer.h"
#import "AppDelegate.h"
#import "SettingsManager.h"
#import "SimpleAudioEngine.h"
#import "Utilities.h"
#import "Analytics.h"

#import "AppDelegate.h"


#pragma mark - AboutLayer

@implementation AboutLayer

+(CCScene *) scene
{
	// 'scene' is an autorelease object.
	CCScene *scene = [CCScene node];
	
	// 'layer' is an autorelease object.
	AboutLayer *layer = [AboutLayer node];
	
	// add layer as a child to scene
	[scene addChild: layer];
	
	// return the scene
	return scene;
}

//
-(id) init
{
	if( (self=[super init])) {

		NSMutableDictionary* credits = [[NSMutableDictionary alloc] init];
		[credits setObject:@"Programming and Design" forKey:@"Stephen Johnson"];
		[credits setObject:@"Sound Designer" forKey:@"Geran Pele"];
		[credits setObject:@"Composer" forKey:@"Nick Alonzo"];
		
		NSMutableArray* creditsOrder = [[NSMutableArray alloc] init];
		[creditsOrder addObject:@"Stephen Johnson"];
		[creditsOrder addObject:@"Geran Pele"];
		[creditsOrder addObject:@"Nick Alonzo"];
	

		
		self.isTouchEnabled = YES;

		// ask director for the window size
		CGSize winSize = [[CCDirector sharedDirector] winSize];

		[LevelHelperLoader dontStretchArt];

		//create a LevelHelperLoader object - we use an empty level
		_levelLoader = [[LevelHelperLoader alloc] initWithContentOfFile:[NSString stringWithFormat:@"Levels/%@/%@", @"Menu", @"About"]];
		[_levelLoader addObjectsToWorld:nil cocos2dLayer:self];
		

				
		//draw the background water tiles
		LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND];
		for(int x = -waterTile.boundingBox.size.width/2; x < winSize.width + waterTile.boundingBox.size.width/2; ) {
			for(int y = -waterTile.boundingBox.size.height/2; y < winSize.height + waterTile.boundingBox.size.width/2; ) {
				LHSprite* waterTile = [_levelLoader createSpriteWithName:@"Water1" fromSheet:@"Map" fromSHFile:@"Spritesheet" tag:BACKGROUND parent:[_levelLoader layerWithUniqueName:@"MAIN_LAYER"]];
				waterTile.zOrder = -1;
				[waterTile transformPosition:ccp(x,y)];
				y+= waterTile.boundingBox.size.height;
			}
			x+= waterTile.boundingBox.size.width;
		}
		[waterTile removeSelf];		


		//add a nice dark tint to the background
		LHSprite* shadowBox = [_levelLoader createSpriteWithName:@"Shadow_Box" fromSheet:@"Menu" fromSHFile:@"Spritesheet"];
		shadowBox.scaleY = winSize.height/shadowBox.contentSize.height;
		shadowBox.scaleX = winSize.width/shadowBox.contentSize.width;
		[shadowBox transformPosition:ccp(winSize.width/2, winSize.height/2)];

		//add app title
		LHSprite* titleSprite = [_levelLoader createSpriteWithName:@"Menu_Title" fromSheet:@"MenuBackgrounds1" fromSHFile:@"Spritesheet"];
		[titleSprite transformPosition:ccp(winSize.width/2, winSize.height - titleSprite.boundingBox.size.height/2 - 15*SCALING_FACTOR_V)];



			
		CCLabelTTF* aboutConquerLabel = [CCLabelTTF labelWithString:
			[NSString stringWithFormat:
@"Made by Conquer LLC, a group of guys who like making awesome strategy and puzzle games.\n%@\
Save Penguin is our first game - we hope you enjoy it and please let us know what you think!", (IS_IPHONE ? @"" : @"\n")]
			fontName:@"Helvetica" fontSize:(IS_IPHONE ? 13 : 26)
			dimensions:CGSizeMake(winSize.width-150*SCALING_FACTOR_H, 150*SCALING_FACTOR_V + (IS_IPHONE ? 10 : 0))
			hAlignment:kCCTextAlignmentLeft
			vAlignment:kCCVerticalTextAlignmentCenter
		];
		aboutConquerLabel.color = ccWHITE;
		aboutConquerLabel.position = ccp(winSize.width/2, titleSprite.position.y - titleSprite.boundingBox.size.height/2 - aboutConquerLabel.boundingBox.size.height/2 - 15*SCALING_FACTOR_V);
		[self addChild:aboutConquerLabel];
						

		
		const int creditsLineHeight = 40*SCALING_FACTOR_V;
		int creditsYOffset = aboutConquerLabel.position.y - aboutConquerLabel.boundingBox.size.height/2 - creditsLineHeight/2 - (IS_IPHONE ? 0 : 30*SCALING_FACTOR_V);
		
		
		for(NSString* name in creditsOrder) {
			NSString* job = [credits objectForKey:name];
			
			NSString* creditLine = [NSString stringWithFormat:@"%@ - %@", name, job];
		
			CCLabelTTF* creditsLineLabel = [CCLabelTTF labelWithString:creditLine
				fontName:@"Helvetica" fontSize:22*SCALING_FACTOR_FONTS
				dimensions:CGSizeMake(450*SCALING_FACTOR_H, creditsLineHeight)
				hAlignment:kCCTextAlignmentCenter
				vAlignment:kCCVerticalTextAlignmentCenter
			];
			creditsLineLabel.color = ccWHITE;
			creditsLineLabel.position = ccp(winSize.width/2, creditsYOffset);
			[self addChild:creditsLineLabel];

			creditsYOffset-= creditsLineHeight;
		}
		[credits release];
			

		CCLabelTTF* giveUsFeedbackLabel = [CCLabelTTF labelWithString:
			[NSString stringWithFormat:
@"We're working on new level packs at this very moment.\n\
Drop us an email or leave a review in the App Store and tell us your ideas!"]
			fontName:@"Helvetica" fontSize:20*SCALING_FACTOR_FONTS
			dimensions:CGSizeMake(winSize.width-150*SCALING_FACTOR_H, 200*SCALING_FACTOR_V)
			hAlignment:kCCTextAlignmentCenter
			vAlignment:kCCVerticalTextAlignmentCenter
		];
		giveUsFeedbackLabel.color = ccWHITE;
		giveUsFeedbackLabel.position = ccp(winSize.width/2, 150*SCALING_FACTOR_V + (IS_IPHONE ? 10 : 0));
		[self addChild:giveUsFeedbackLabel];		
		
		
		
		
		
		LHSprite* rateTheAppButton = [_levelLoader createSpriteWithName:@"Rate_the_App_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[rateTheAppButton prepareAnimationNamed:@"Menu_Rate_the_App_Button" fromSHScene:@"Spritesheet"];
		[rateTheAppButton transformPosition: ccp(winSize.width/2 - rateTheAppButton.boundingBox.size.width/2 - 20*SCALING_FACTOR_H,
											30*SCALING_FACTOR_V + rateTheAppButton.boundingBox.size.height/2)];
		[rateTheAppButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[rateTheAppButton registerTouchEndedObserver:self selector:@selector(onRateTheApp:)];
		

		if ([MFMailComposeViewController canSendMail]) {
			LHSprite* emailUsButton = [_levelLoader createSpriteWithName:@"Email_Us_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
			[emailUsButton prepareAnimationNamed:@"Menu_Email_Us_Button" fromSHScene:@"Spritesheet"];
			[emailUsButton transformPosition: ccp(winSize.width/2 + emailUsButton.boundingBox.size.width/2 + 20*SCALING_FACTOR_H,
												30*SCALING_FACTOR_V + emailUsButton.boundingBox.size.height/2)];
			[emailUsButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
			[emailUsButton registerTouchEndedObserver:self selector:@selector(onEmailUs:)];
		}


		
				
		LHSprite* backButton = [_levelLoader createSpriteWithName:@"Back_inactive" fromSheet:@"Menu" fromSHFile:@"Spritesheet" parent:self];
		[backButton prepareAnimationNamed:@"Menu_Back_Button" fromSHScene:@"Spritesheet"];
		[backButton transformPosition: ccp(20*SCALING_FACTOR_H + backButton.boundingBox.size.width/2,
											20*SCALING_FACTOR_V + backButton.boundingBox.size.height/2)];
		[backButton registerTouchBeganObserver:self selector:@selector(onTouchBeganAnyButton:)];
		[backButton registerTouchEndedObserver:self selector:@selector(onBack:)];

		if([SettingsManager boolForKey:SETTING_MUSIC_ENABLED] && ![[SimpleAudioEngine sharedEngine] isBackgroundMusicPlaying]) {
			[[SimpleAudioEngine sharedEngine] playBackgroundMusic:@"sounds/menu/ambient/theme.mp3" loop:YES];
		}

		[Analytics logEvent:@"View_About"];

	}
	
	if(DEBUG_MEMORY) DebugLog(@"Initialized AboutLayer");
	if(DEBUG_MEMORY) report_memory();
	
	return self;
}


-(void)onTouchBeganAnyButton:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame+1];	//active state
}



-(void)onEmailUs:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}


	//analytics logging
	[Analytics logEvent:@"About_Email_Us_Click"];


	MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
	UIViewController *rootViewController = (UIViewController*)[(AppController*)[[UIApplication sharedApplication] delegate] navController];
  	controller.mailComposeDelegate = self;
	// Recipient.
    NSString *recipient = @"feedback@conquerllc.com";
    NSArray *recipientsArray = [NSArray arrayWithObject:recipient];
    [controller setToRecipients:recipientsArray];
	
	[controller setSubject:@"Save Penguin Feedback"];
	
	[controller setMessageBody:@"" isHTML:NO];
	
	[rootViewController presentModalViewController:controller animated:YES];
	[controller release];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	UIViewController* rootViewController = (UIViewController*)[(AppController*)[[UIApplication sharedApplication] delegate] navController];
	[rootViewController becomeFirstResponder];
	[rootViewController dismissModalViewControllerAnimated:YES];
}

-(void)onRateTheApp:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	//analytics logging
	[Analytics logEvent:@"About_Rate_the_App_Click"];

	[SettingsManager sendToAppReviewPage];
}


-(void)onBack:(LHTouchInfo*)info {
	if(info.sprite == nil) return;
	[info.sprite setFrame:info.sprite.currentFrame-1];	//active state
	
	if([SettingsManager boolForKey:SETTING_SOUND_ENABLED]) {
		[[SimpleAudioEngine sharedEngine] playEffect:@"sounds/menu/button.wav"];
	}
	
	//[[SimpleAudioEngine sharedEngine] stopBackgroundMusic];
	
	[[CCDirector sharedDirector] replaceScene:[CCTransitionFade transitionWithDuration:0.25 scene:[MainMenuLayer scene] ]];
}






-(void) onEnter
{
	[super onEnter];
}


-(void) onExit {
	if(DEBUG_MEMORY) DebugLog(@"AboutLayer onExit");

	for(LHSprite* sprite in _levelLoader.allSprites) {
		[sprite stopAnimation];
	}			
	
	[super onExit];
}

-(void) dealloc
{
	if(DEBUG_MEMORY) DebugLog(@"AboutLayer dealloc");

	[_levelLoader release];
	_levelLoader = nil;	
	
	[super dealloc];
	
	if(DEBUG_MEMORY) report_memory();
}	

@end
