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


