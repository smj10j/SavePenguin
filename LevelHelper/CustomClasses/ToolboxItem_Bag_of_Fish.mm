//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "ToolboxItem_Bag_of_Fish.h"

@implementation ToolboxItem_Bag_of_Fish


@synthesize runningCost;
@synthesize scale;
@synthesize placeCost;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


[super dealloc];

#endif // __has_feature(objc_arc)
}

+(ToolboxItem_Bag_of_Fish*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[ToolboxItem_Bag_of_Fish alloc] init];
#else
return [[[ToolboxItem_Bag_of_Fish alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if(dictionary[@"runningCost"])
		self.runningCost = [dictionary[@"runningCost"] floatValue];

	if(dictionary[@"scale"])
		self.scale = [dictionary[@"scale"] floatValue];

	if(dictionary[@"placeCost"])
		self.placeCost = [dictionary[@"placeCost"] floatValue];

}

@end
