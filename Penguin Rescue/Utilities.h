//
//  Utilities.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/30/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <mach/mach.h>

@interface Utilities : NSObject {

}

+ (NSString*)UUID;

@end

void report_memory(void);

bool isServerAvailable(void);
void setServerAvailable(bool isServerAvailable);