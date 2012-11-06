//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "Shark.h"

@implementation Shark


@synthesize isInvisible;
@synthesize endpointX;
@synthesize activeSpeed;
@synthesize restingDetectionRadius;
@synthesize activeDetectionRadius;
@synthesize endpointY;
@synthesize isStuck;
@synthesize restingSpeed;
@synthesize targetAcquired;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(Shark*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[Shark alloc] init];
#else
return [[[Shark alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if([dictionary objectForKey:@"isInvisible"])
		[self setIsInvisible:[[dictionary objectForKey:@"isInvisible"] boolValue]];

	if([dictionary objectForKey:@"endpointX"])
		[self setEndpointX:[[dictionary objectForKey:@"endpointX"] floatValue]];

	if([dictionary objectForKey:@"activeSpeed"])
		[self setActiveSpeed:[[dictionary objectForKey:@"activeSpeed"] floatValue]];

	if([dictionary objectForKey:@"restingDetectionRadius"])
		[self setRestingDetectionRadius:[[dictionary objectForKey:@"restingDetectionRadius"] floatValue]];

	if([dictionary objectForKey:@"activeDetectionRadius"])
		[self setActiveDetectionRadius:[[dictionary objectForKey:@"activeDetectionRadius"] floatValue]];

	if([dictionary objectForKey:@"endpointY"])
		[self setEndpointY:[[dictionary objectForKey:@"endpointY"] floatValue]];

	if([dictionary objectForKey:@"isStuck"])
		[self setIsStuck:[[dictionary objectForKey:@"isStuck"] boolValue]];

	if([dictionary objectForKey:@"restingSpeed"])
		[self setRestingSpeed:[[dictionary objectForKey:@"restingSpeed"] floatValue]];

	if([dictionary objectForKey:@"targetAcquired"])
		[self setTargetAcquired:[[dictionary objectForKey:@"targetAcquired"] boolValue]];

}

@end
