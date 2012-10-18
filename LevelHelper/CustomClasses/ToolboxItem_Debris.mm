//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "ToolboxItem_Debris.h"

@implementation ToolboxItem_Debris




-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(ToolboxItem_Debris*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[ToolboxItem_Debris alloc] init];
#else
return [[[ToolboxItem_Debris alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

}

@end
