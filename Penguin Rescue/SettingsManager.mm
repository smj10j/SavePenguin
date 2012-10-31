//
//  SettingsManager.m
//  Penguin Rescue
//
//  Created by Stephen Johnson on 10/25/12.
//  Copyright (c) 2012 Conquer LLC. All rights reserved.
//

#import "Constants.h"
#import "SettingsManager.h"
#import "SSKeychain.h"

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
		if(DEBUG_SETTINGS) DebugLog(@"Loaded user settings");
	//}
}

+(void)saveSettings {
	//write to file!
	NSString* rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	NSString* settingsPlistPath = [rootPath stringByAppendingPathComponent:@"UserSettings.plist"];

	if(![sSettings writeToFile:settingsPlistPath atomically: YES]) {
        DebugLog(@"---- Failed to save user settings!! - %@ -----", settingsPlistPath);
        return;
    }
}




+(id)objectForKey:(NSString*)key {
	[SettingsManager loadSettings];
	if(DEBUG_SETTINGS) DebugLog(@"Loading settings value for key %@", key);
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


+(NSString*)getUUID {

	NSString* UUID = [SettingsManager stringForKey:SETTING_UUID];
	
	if(UUID == nil) {
		//create a user id
	
		//first see if the userId is in the keychain
		NSError *error = nil;
		UUID = [SSKeychain passwordForService:COMPANY_IDENTIFIER account:@"user" error:&error];
		if (error != nil) {
			DebugLog(@"@@@@ ERROR SSKeychain passwordForService error code: %d", [error code]);
		}
		if(UUID == nil) {

			CFUUIDRef cfUUID = CFUUIDCreate(NULL);
			CFStringRef strUUUID = CFUUIDCreateString(NULL, cfUUID);
			CFRelease(cfUUID);
			UUID = (__bridge NSString*)strUUUID;
			DebugLog(@"Created a new uuid");
							
			//store the userId to the keychain
			error = nil;
			[SSKeychain setPassword:UUID forService:COMPANY_IDENTIFIER account:@"user" error:&error];
			if (error!= nil) {
				DebugLog(@"@@@@ ERROR SSKeychain setPassword error code: %d", [error code]);
			}
			
		}else {
			DebugLog(@"Retrieved uuid from the keychain!");
		}
		[SettingsManager setString:UUID forKey:SETTING_UUID];
					
		//TODO: also store this to iCloud: refer to: http://stackoverflow.com/questions/7273014/ios-unique-user-identifier
		/*
			To make sure ALL devices have the same UUID in the Keychain.

			Setup your app to use iCloud.
			Save the UUID that is in the Keychain to NSUserDefaults as well.
			Pass the UUID in NSUserDefaults to the Cloud with Key-Value Data Store.
			On App first run, Check if the Cloud Data is available and set the UUID in the Keychain on the New Device.
		*/
	}
	
	
	return UUID;
}


@end

