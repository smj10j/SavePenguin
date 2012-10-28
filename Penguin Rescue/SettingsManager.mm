//
//  SettingsManager.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "SettingsManager.h"

static NSMutableDictionary* sSettings = nil;

@implementation SettingsManager

+(void)loadSettings {
	//if(sSettings == nil) {
		NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
		NSString* settingsPlistPath = [rootPath stringByAppendingPathComponent:@"UserSettings.plist"];
		sSettings = [NSMutableDictionary dictionaryWithContentsOfFile:settingsPlistPath];
		if(sSettings == nil) {
			sSettings = [[NSMutableDictionary alloc] init];
		}
		//NSLog(@"Loaded user settings");
	//}
}

+(void)saveSettings {
	//write to file!
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* settingsPlistPath = [rootPath stringByAppendingPathComponent:@"UserSettings.plist"];

	if(![sSettings writeToFile:settingsPlistPath atomically: YES]) {
        NSLog(@"---- Failed to save user settings!! - %@ -----", settingsPlistPath);
        return;
    }
}




+(id)objectForKey:(NSString*)key {
	[SettingsManager loadSettings];
	NSLog(@"Loading settings value for key %@", key);
	return [sSettings objectForKey:key];
}
+(NSString*)stringForKey:(NSString*)key {
	return [SettingsManager objectForKey:key];
}
+(bool)boolForKey:(NSString*)key {
	id value = [SettingsManager objectForKey:key];
	return value == nil ? nil : [((NSNumber*)value) boolValue];
}
+(int)intForKey:(NSString*)key {
	id value = [SettingsManager objectForKey:key];
	return value == nil ? nil :  [((NSNumber*)value) intValue];
}
+(double)doubleForKey:(NSString*)key {
	id value = [SettingsManager objectForKey:key];
	return value == nil ? nil :  [((NSNumber*)value) doubleValue];
}




+(void)setObject:(id)value forKey:(NSString*)key {
	[SettingsManager loadSettings];
	if(value != nil) {
		[sSettings setObject:value forKey:key];
	}else {
		[sSettings removeObjectForKey:key];
	}
	[SettingsManager saveSettings];
}

+(void)remove:(NSString*)key {
	[SettingsManager setObject:nil forKey:key];
}
+(void)setString:(NSString*)value forKey:(NSString*)key {
	[SettingsManager setObject:value forKey:key];
}
+(void)setBool:(bool)value forKey:(NSString*)key {
	[SettingsManager setObject:[NSNumber numberWithBool:value] forKey:key];
}
+(void)setInt:(int)value forKey:(NSString*)key {
	[SettingsManager setObject:[NSNumber numberWithInt:value] forKey:key];
}
+(void)setDouble:(double)value forKey:(NSString*)key {
	[SettingsManager setObject:[NSNumber numberWithDouble:value] forKey:key];
}

@end

