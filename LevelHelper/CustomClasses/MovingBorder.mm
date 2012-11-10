//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "MovingBorder.h"

@implementation MovingBorder


@synthesize restartAtOtherEnd;
@synthesize timeToCompletePath;
@synthesize followXAxis;
@synthesize isCyclic;
@synthesize followYAxis;
@synthesize pathName;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

if(pathName) [pathName release];

[super dealloc];

#endif // __has_feature(objc_arc)
}

+(MovingBorder*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[MovingBorder alloc] init];
#else
return [[[MovingBorder alloc] init] autorelease];
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

	if([dictionary objectForKey:@"followXAxis"])
		[self setFollowXAxis:[[dictionary objectForKey:@"followXAxis"] boolValue]];

	if([dictionary objectForKey:@"isCyclic"])
		[self setIsCyclic:[[dictionary objectForKey:@"isCyclic"] boolValue]];

	if([dictionary objectForKey:@"followYAxis"])
		[self setFollowYAxis:[[dictionary objectForKey:@"followYAxis"] boolValue]];

	if([dictionary objectForKey:@"pathName"])
		[self setPathName:[dictionary objectForKey:@"pathName"]];

}

@end
