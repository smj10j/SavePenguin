//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "MovingLand.h"

@implementation MovingLand


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

+(MovingLand*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[MovingLand alloc] init];
#else
return [[[MovingLand alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if(dictionary[@"restartAtOtherEnd"])
		self.restartAtOtherEnd = [dictionary[@"restartAtOtherEnd"] boolValue];

	if(dictionary[@"timeToCompletePath"])
		self.timeToCompletePath = [dictionary[@"timeToCompletePath"] floatValue];

	if(dictionary[@"followXAxis"])
		self.followXAxis = [dictionary[@"followXAxis"] boolValue];

	if(dictionary[@"isCyclic"])
		self.isCyclic = [dictionary[@"isCyclic"] boolValue];

	if(dictionary[@"followYAxis"])
		self.followYAxis = [dictionary[@"followYAxis"] boolValue];

	if(dictionary[@"pathName"])
		self.pathName = dictionary[@"pathName"];

}

@end
