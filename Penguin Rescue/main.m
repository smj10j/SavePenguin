//
//  main.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/15/12.
//  Copyright Conquer LLC 2012. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Flurry.h"

int main(int argc, char *argv[]) {
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

    int retVal;
    @try {
        retVal = UIApplicationMain(argc, argv, nil, @"AppController");
    }
    @catch (NSException *exception) {
        NSLog(@"CRASH: %@", exception);
        NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
		[Flurry logError:@"Uncaught" message:@"Crash!" exception:exception];
    }
    @finally {
        [pool release];
    }	
	
    return retVal;
}