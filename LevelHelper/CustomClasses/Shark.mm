//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "Shark.h"

@implementation Shark


@synthesize speed;
@synthesize activeDetectionRadius;
@synthesize restingDetectionRadius;


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

	if([dictionary objectForKey:@"speed"])
		[self setSpeed:[[dictionary objectForKey:@"speed"] floatValue]];

	if([dictionary objectForKey:@"activeDetectionRadius"])
		[self setActiveDetectionRadius:[[dictionary objectForKey:@"activeDetectionRadius"] floatValue]];

	if([dictionary objectForKey:@"restingDetectionRadius"])
		[self setRestingDetectionRadius:[[dictionary objectForKey:@"restingDetectionRadius"] floatValue]];

}

@end
