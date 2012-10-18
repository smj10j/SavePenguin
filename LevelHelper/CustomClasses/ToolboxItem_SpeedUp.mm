//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "ToolboxItem_SpeedUp.h"

@implementation ToolboxItem_SpeedUp


@synthesize amount;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(ToolboxItem_SpeedUp*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[ToolboxItem_SpeedUp alloc] init];
#else
return [[[ToolboxItem_SpeedUp alloc] init] autorelease];
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
