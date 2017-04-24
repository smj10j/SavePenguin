//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "MovingDoodad.h"

@implementation MovingDoodad


@synthesize timeToCompletePath;
@synthesize isCyclic;
@synthesize followXAxis;
@synthesize pathName;
@synthesize restartAtOtherEnd;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

if(pathName) [pathName release];

[super dealloc];

#endif // __has_feature(objc_arc)
}

+(MovingDoodad*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[MovingDoodad alloc] init];
#else
return [[[MovingDoodad alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if(dictionary[@"timeToCompletePath"])
		self.timeToCompletePath = [dictionary[@"timeToCompletePath"] floatValue];

	if(dictionary[@"isCyclic"])
		self.isCyclic = [dictionary[@"isCyclic"] boolValue];

	if(dictionary[@"followXAxis"])
		self.followXAxis = [dictionary[@"followXAxis"] boolValue];

	if(dictionary[@"pathName"])
		self.pathName = dictionary[@"pathName"];

	if(dictionary[@"restartAtOtherEnd"])
		self.restartAtOtherEnd = [dictionary[@"restartAtOtherEnd"] boolValue];

}

@end
