//
//  SettingsManager.h
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SettingsManager : NSObject


+(bool)boolForKey:(NSString*)key;
+(NSString*)stringForKey:(NSString*)key;
+(int)intForKey:(NSString*)key;
+(double)doubleForKey:(NSString*)key;


+(void)setString:(NSString*)value forKey:(NSString*)key;
+(void)setBool:(bool)value forKey:(NSString*)key;
+(void)setInt:(int)value forKey:(NSString*)key;
+(void)setDouble:(double)value forKey:(NSString*)key;


+(void)remove:(NSString*)key;

@end
