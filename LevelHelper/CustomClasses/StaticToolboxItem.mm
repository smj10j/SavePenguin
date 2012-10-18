//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "StaticToolboxItem.h"

@implementation StaticToolboxItem




-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(StaticToolboxItem*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[StaticToolboxItem alloc] init];
#else
return [[[StaticToolboxItem alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

}

@end
