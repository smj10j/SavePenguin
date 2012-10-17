//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "Penguin.h"

@implementation Penguin


@synthesize hasSpottedShark;
@synthesize speed;
@synthesize detectionRadius;
@synthesize isSafe;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(Penguin*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[Penguin alloc] init];
#else
return [[[Penguin alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if([dictionary objectForKey:@"hasSpottedShark"])
		[self setHasSpottedShark:[[dictionary objectForKey:@"hasSpottedShark"] boolValue]];

	if([dictionary objectForKey:@"speed"])
		[self setSpeed:[[dictionary objectForKey:@"speed"] floatValue]];

	if([dictionary objectForKey:@"detectionRadius"])
		[self setDetectionRadius:[[dictionary objectForKey:@"detectionRadius"] floatValue]];

	if([dictionary objectForKey:@"isSafe"])
		[self setIsSafe:[[dictionary objectForKey:@"isSafe"] boolValue]];

}

@end
