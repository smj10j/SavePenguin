//
//  Analytics.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/29/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#include "Constants.h"
#include "Analytics.h"
#include "Flurry.h"

@implementation Analytics


+(void)startAnalytics {
#if DISTRIBUTION_MODE
	//[Flurry setDebugLogEnabled:true];
	//[Flurry setShowErrorInLogEnabled:true];
	[Flurry setEventLoggingEnabled:true];
	[Flurry startSession:@"6DDZY62RXJWGMWHGYVQ3"];
#endif
}

+(void)setUserId:(NSString*)userId {
#if DISTRIBUTION_MODE
	[Flurry setUserID:userId];
#endif
}

+(void)logEvent:(NSString*)eventName {
#if DISTRIBUTION_MODE
	[Flurry logEvent:eventName];
#endif
}

+(void)logEvent:(NSString*)eventName withParameters:(NSDictionary*)parameters timed:(bool)timed {
#if DISTRIBUTION_MODE
	[Flurry logEvent:eventName withParameters:parameters timed:timed];
#endif
}

+(void)logEvent:(NSString*)eventName withParameters:(NSDictionary*)parameters {
#if DISTRIBUTION_MODE
	[Flurry logEvent:eventName withParameters:parameters];
#endif
}

+(void)logError:(NSString*)error message:(NSString*)message exception:(NSException*)exception {
#if DISTRIBUTION_MODE
	[Flurry logError:error message:message exception:exception];
#endif
}

+(void)endTimedEvent:(NSString*)eventName withParameters:(NSDictionary*)parameters {
#if DISTRIBUTION_MODE
	[Flurry endTimedEvent:eventName withParameters:parameters];
#endif
}


@end
