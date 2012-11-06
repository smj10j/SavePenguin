//
//  AppDelegate.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//

#import "cocos2d.h"

#import "AppDelegate.h"
#import "IntroLayer.h"
#import "LevelPackManager.h"
#import "Reachability.h"
#import "Utilities.h"
#import "ScoreKeeper.h"
#import "Analytics.h"
#import "APIManager.h"

@implementation AppController

@synthesize window=_window, navController=_navController, director=_director;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{

	//capture uncaught exceptions for logging
	NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
	
	//start analytics
	[Analytics startAnalytics];
	
	// Create the main window
	_window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	
	
	// Create an CCGLView with a RGB565 color buffer, and a depth buffer of 0-bits
	CCGLView *glView = [CCGLView viewWithFrame:[_window bounds]
								   pixelFormat:kEAGLColorFormatRGB565	//kEAGLColorFormatRGBA8
								   depthFormat:0	//GL_DEPTH_COMPONENT24_OES
							preserveBackbuffer:NO
									sharegroup:nil
								 multiSampling:NO
							   numberOfSamples:0];

	// Enable multiple touches
	[glView setMultipleTouchEnabled:YES];

	_director = (CCDirectorIOS*) [CCDirector sharedDirector];
	
	_director.wantsFullScreenLayout = YES;
	
	// Display FSP and SPF
	if(!DISTRIBUTION_MODE) {
		[_director setDisplayStats:YES];
	}
	
	// set FPS at 60
	[_director setAnimationInterval:1.0/TARGET_FPS];
	
	// attach the openglView to the director
	[_director setView:glView];
	
	// for rotation and other messages
	[_director setDelegate:self];
	
	// 2D projection
	[_director setProjection:kCCDirectorProjection2D];
	//	[director setProjection:kCCDirectorProjection3D];
	
	// Enables High Res mode (Retina Display) on iPhone 4 and maintains low res on all other devices
	if( ! [_director enableRetinaDisplay:YES] )
		CCLOG(@"Retina Display Not supported");
	
	// Default texture format for PNG/BMP/TIFF/JPEG/GIF images
	// It can be RGBA8888, RGBA4444, RGB5_A1, RGB565
	// You can change anytime.
	[CCTexture2D setDefaultAlphaPixelFormat:kCCTexture2DPixelFormat_RGBA8888];
	
	// If the 1st suffix is not found and if fallback is enabled then fallback suffixes are going to searched. If none is found, it will try with the name without suffix.
	// On iPad HD  : "-ipadhd", "-ipad",  "-hd"
	// On iPad     : "-ipad", "-hd"
	// On iPhone HD: "-hd"
	CCFileUtils *sharedFileUtils = [CCFileUtils sharedFileUtils];
	[sharedFileUtils setEnableFallbackSuffixes:NO];				// Default: NO. No fallback suffixes are going to be used
	[sharedFileUtils setiPhoneRetinaDisplaySuffix:@"-hd"];		// Default on iPhone RetinaDisplay is "-hd"
	[sharedFileUtils setiPadSuffix:@"-ipad"];					// Default on iPad is "ipad"
	[sharedFileUtils setiPadRetinaDisplaySuffix:@"-ipadhd"];	// Default on iPad RetinaDisplay is "-ipadhd"
	
	// Assume that PVR images have premultiplied alpha
	[CCTexture2D PVRImagesHavePremultipliedAlpha:YES];
	
	// Create a Navigation Controller with the Director
	_navController = [[UINavigationController alloc] initWithRootViewController:_director];
	_navController.navigationBarHidden = YES;
	
	// set the Navigation Controller as the root view controller
	[_window setRootViewController:_navController];
	
	// make main window visible
	[_window makeKeyAndVisible];
	
	// register for network status notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkNetworkStatus:) name:kReachabilityChangedNotification object:nil];

    // check if a pathway to conquerllc.com exists
    _hostReachable = [[Reachability reachabilityWithHostName: SERVER_HOST] retain];
    [_hostReachable startNotifier];
	
	return YES;
}

// This is needed for iOS4 and iOS5 in order to ensure
// that the 1st scene has the correct dimensions
// This is not needed on iOS6 and could be added to the application:didFinish...
-(void) directorDidReshapeProjection:(CCDirector*)director
{
	if(director.runningScene == nil) {
		// Add the first scene to the stack. The director will draw it immediately into the framebuffer. (Animation is started automatically when the view is displayed.)
		// and add the scene to the stack. The director will run it when it automatically when the view is displayed.
		[director runWithScene: [IntroLayer scene]];
	}
}

// Supported orientations: Landscape. Customize it for your own needs
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}


// getting a call, pause the game
-(void) applicationWillResignActive:(UIApplication *)application
{
	if( [_navController visibleViewController] == _director )
		[_director pause];
}

// call got rejected
-(void) applicationDidBecomeActive:(UIApplication *)application
{
	if( [_navController visibleViewController] == _director )
		[_director resume];
}

-(void) applicationDidEnterBackground:(UIApplication*)application
{
	if( [_navController visibleViewController] == _director )
		[_director stopAnimation];
}

-(void) applicationWillEnterForeground:(UIApplication*)application
{
	if( [_navController visibleViewController] == _director )
		[_director startAnimation];
}

// application will be killed
- (void)applicationWillTerminate:(UIApplication *)application
{
	CC_DIRECTOR_END();
}

// purge memory
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	DebugLog(@"@@@@@@@@@@@ Low memory warning @@@@@@@@@@@@");;
	DebugLog(@"@@@@@@@@@@@ Low memory warning @@@@@@@@@@@@");;
	report_memory();
	DebugLog(@"@@@@@@@@@@@ Low memory warning @@@@@@@@@@@@");;
	DebugLog(@"@@@@@@@@@@@ Low memory warning @@@@@@@@@@@@");;
	
	[[CCDirector sharedDirector] purgeCachedData];
}

// next delta time will be zero
-(void) applicationSignificantTimeChange:(UIApplication *)application
{
	[[CCDirector sharedDirector] setNextDeltaTimeZero:YES];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	[_window release];
	[_navController release];
	
	[super dealloc];
}








-(void) checkNetworkStatus:(NSNotification *)notice
{
    // called after network status changes
    NetworkStatus hostStatus = [_hostReachable currentReachabilityStatus];
    switch (hostStatus)
    {
        case NotReachable:
        {
            DebugLog(@"A gateway to the host server is down.");
			setServerAvailable(false);
            break;
        }
        case ReachableViaWiFi:
        {
            DebugLog(@"A gateway to the host server is working via WIFI.");
			setServerAvailable(true);
			[ScoreKeeper emptyLocalSendQueue];
            break;
        }
        case ReachableViaWWAN:
        {
            DebugLog(@"A gateway to the host server is working via WWAN.");
			setServerAvailable(true);
 			[ScoreKeeper emptyLocalSendQueue];
           break;
        }
    }
}









//send uncaught exceptions to Flurry
void uncaughtExceptionHandler(NSException *exception) {
	DebugLog(@"Uncaught exception: %@ - %@", exception.name, exception.reason);
	[Analytics logError:@"Uncaught" message:@"Crash!" exception:exception];
}


@end

