//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "ToolboxItem_Whirlpool.h"

@implementation ToolboxItem_Whirlpool


@synthesize scale;
@synthesize power;
@synthesize runningCost;
@synthesize placeCost;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(ToolboxItem_Whirlpool*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[ToolboxItem_Whirlpool alloc] init];
#else
return [[[ToolboxItem_Whirlpool alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if([dictionary objectForKey:@"scale"])
		[self setScale:[[dictionary objectForKey:@"scale"] floatValue]];

	if([dictionary objectForKey:@"power"])
		[self setPower:[[dictionary objectForKey:@"power"] floatValue]];

	if([dictionary objectForKey:@"runningCost"])
		[self setRunningCost:[[dictionary objectForKey:@"runningCost"] floatValue]];

	if([dictionary objectForKey:@"placeCost"])
		[self setPlaceCost:[[dictionary objectForKey:@"placeCost"] floatValue]];

}

@end
