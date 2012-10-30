//
//  Utilities.mm
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/29/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#include "Constants.h"
#include "Utilities.h"
#include "Flurry.h"

@implementation Utilities


+(int)percentileFromZScore:(double)zScore {
	
	NSMutableDictionary* zTable = [[NSMutableDictionary alloc] init];
	[zTable setObject:[NSNumber numberWithDouble:1.5] forKey:[NSNumber numberWithDouble:-2.2]];
	[zTable setObject:[NSNumber numberWithDouble:6] forKey:[NSNumber numberWithDouble:-1.6]];
	[zTable setObject:[NSNumber numberWithDouble:12] forKey:[NSNumber numberWithDouble:-1.2]];
	[zTable setObject:[NSNumber numberWithDouble:16] forKey:[NSNumber numberWithDouble:-1.0]];
	[zTable setObject:[NSNumber numberWithDouble:18] forKey:[NSNumber numberWithDouble:-0.9]];
	[zTable setObject:[NSNumber numberWithDouble:21] forKey:[NSNumber numberWithDouble:-0.8]];
	[zTable setObject:[NSNumber numberWithDouble:24] forKey:[NSNumber numberWithDouble:-0.7]];
	[zTable setObject:[NSNumber numberWithDouble:27] forKey:[NSNumber numberWithDouble:-0.6]];
	[zTable setObject:[NSNumber numberWithDouble:31] forKey:[NSNumber numberWithDouble:-0.5]];
	[zTable setObject:[NSNumber numberWithDouble:35] forKey:[NSNumber numberWithDouble:-0.4]];
	[zTable setObject:[NSNumber numberWithDouble:38] forKey:[NSNumber numberWithDouble:-0.3]];
	[zTable setObject:[NSNumber numberWithDouble:42] forKey:[NSNumber numberWithDouble:-0.2]];
	[zTable setObject:[NSNumber numberWithDouble:46] forKey:[NSNumber numberWithDouble:-0.1]];
	[zTable setObject:[NSNumber numberWithDouble:50] forKey:[NSNumber numberWithDouble:0.0]];
				
	[zTable setObject:[NSNumber numberWithDouble:54] forKey:[NSNumber numberWithDouble:0.1]];
	[zTable setObject:[NSNumber numberWithDouble:58] forKey:[NSNumber numberWithDouble:0.2]];
	[zTable setObject:[NSNumber numberWithDouble:62] forKey:[NSNumber numberWithDouble:0.3]];
	[zTable setObject:[NSNumber numberWithDouble:65] forKey:[NSNumber numberWithDouble:0.4]];
	[zTable setObject:[NSNumber numberWithDouble:69] forKey:[NSNumber numberWithDouble:0.5]];
	[zTable setObject:[NSNumber numberWithDouble:72] forKey:[NSNumber numberWithDouble:0.6]];
	[zTable setObject:[NSNumber numberWithDouble:76] forKey:[NSNumber numberWithDouble:0.7]];
	[zTable setObject:[NSNumber numberWithDouble:79] forKey:[NSNumber numberWithDouble:0.8]];
	[zTable setObject:[NSNumber numberWithDouble:82] forKey:[NSNumber numberWithDouble:0.9]];
	[zTable setObject:[NSNumber numberWithDouble:84] forKey:[NSNumber numberWithDouble:1.0]];
	[zTable setObject:[NSNumber numberWithDouble:86] forKey:[NSNumber numberWithDouble:1.1]];
	[zTable setObject:[NSNumber numberWithDouble:88] forKey:[NSNumber numberWithDouble:1.2]];
	[zTable setObject:[NSNumber numberWithDouble:90] forKey:[NSNumber numberWithDouble:1.3]];
	[zTable setObject:[NSNumber numberWithDouble:92] forKey:[NSNumber numberWithDouble:1.4]];
	[zTable setObject:[NSNumber numberWithDouble:93] forKey:[NSNumber numberWithDouble:1.5]];
	[zTable setObject:[NSNumber numberWithDouble:94] forKey:[NSNumber numberWithDouble:1.6]];
	[zTable setObject:[NSNumber numberWithDouble:95] forKey:[NSNumber numberWithDouble:1.7]];
	[zTable setObject:[NSNumber numberWithDouble:96] forKey:[NSNumber numberWithDouble:1.8]];
	[zTable setObject:[NSNumber numberWithDouble:97] forKey:[NSNumber numberWithDouble:1.9]];
	[zTable setObject:[NSNumber numberWithDouble:97.5] forKey:[NSNumber numberWithDouble:2.0]];
	[zTable setObject:[NSNumber numberWithDouble:98] forKey:[NSNumber numberWithDouble:2.1]];
	[zTable setObject:[NSNumber numberWithDouble:99] forKey:[NSNumber numberWithDouble:2.2]];
	
	
	double cumulScore = 0;
	double totalScalars = 0;
	for(NSNumber* zScoreKey in zTable) {
		double aZScore = [zScoreKey doubleValue];
		double percentile = [(NSNumber*)[zTable objectForKey:zScoreKey] doubleValue];
		
		double scalar = zScore == aZScore ? 1000 : fmin(1.0/fabs(zScore-aZScore), 1000);
		cumulScore+= (scalar * percentile);
		totalScalars+= scalar;
	}
	cumulScore/= totalScalars;
	
	if(DEBUG_SCORING) DebugLog(@"With zScore=%f we found percentile=%d", zScore, (int)cumulScore);
	
	[zTable release];
	
	return (int)cumulScore;
}







+ (NSString *)UUID {
  CFUUIDRef theUUID = CFUUIDCreate(NULL);
  CFStringRef string = CFUUIDCreateString(NULL, theUUID);
  CFRelease(theUUID);
  return [(NSString *)string autorelease];
}

+(void)startAnalytics {
#if DISTRIBUTION_MODE
	//[Flurry setDebugLogEnabled:true];
	//[Flurry setShowErrorInLogEnabled:true];
	[Flurry setEventLoggingEnabled:true];
	[Flurry startSession:@"6DDZY62RXJWGMWHGYVQ3"];
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



vm_size_t usedMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0; // size in bytes
}

vm_size_t freeMemory(void) {
    mach_port_t host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t pagesize;
    vm_statistics_data_t vm_stat;

    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
    return vm_stat.free_count * pagesize;
}

void report_memory(void) {
    // compute memory usage and log if different by >= 100k
    static long prevMemUsage = 0;
    long curMemUsage = usedMemory();
    long memUsageDiff = curMemUsage - prevMemUsage;

    if (true || memUsageDiff > 100000 || memUsageDiff < -100000) {
        prevMemUsage = curMemUsage;
        DebugLog(@"Memory used %7.1f (%+5.0f), free %7.1f kb", curMemUsage/1000.0f, memUsageDiff/1000.0f, freeMemory()/1000.0f);
    }
}




static bool __isServerAvailable = false;
bool isServerAvailable(void) {
	return __isServerAvailable;
}
void setServerAvailable(bool isServerAvailable) {
	__isServerAvailable = isServerAvailable;
}


