//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "ToolboxItem_SlowDown.h"

@implementation ToolboxItem_SlowDown


@synthesize amount;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(ToolboxItem_SlowDown*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[ToolboxItem_SlowDown alloc] init];
#else
return [[[ToolboxItem_SlowDown alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if([dictionary objectForKey:@"amount"])
		[self setAmount:[[dictionary objectForKey:@"amount"] floatValue]];

}

@end
