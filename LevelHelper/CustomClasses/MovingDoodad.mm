//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "MovingDoodad.h"

@implementation MovingDoodad


@synthesize restartAtOtherEnd;
@synthesize timeToCompletePath;
@synthesize pathName;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

if(pathName) [pathName release];

[super dealloc];

#endif // __has_feature(objc_arc)
}

+(MovingDoodad*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[MovingDoodad alloc] init];
#else
return [[[MovingDoodad alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if([dictionary objectForKey:@"restartAtOtherEnd"])
		[self setRestartAtOtherEnd:[[dictionary objectForKey:@"restartAtOtherEnd"] boolValue]];

	if([dictionary objectForKey:@"timeToCompletePath"])
		[self setTimeToCompletePath:[[dictionary objectForKey:@"timeToCompletePath"] floatValue]];

	if([dictionary objectForKey:@"pathName"])
		[self setPathName:[dictionary objectForKey:@"pathName"]];

}

@end
