//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "Penguin.h"

@implementation Penguin


@synthesize isDead;
@synthesize speed;
@synthesize isInvisible;
@synthesize alertRadius;
@synthesize isSafe;
@synthesize detectionRadius;
@synthesize hasSpottedShark;
@synthesize hatName;
@synthesize isStuck;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

if(hatName) [hatName release];

[super dealloc];

#endif // __has_feature(objc_arc)
}

+(Penguin*) customClassInstance{
#if __has_feature(objc_arc) && __clang_major__ >= 3
return [[Penguin alloc] init];
#else
return [[[Penguin alloc] init] autorelease];
#endif
}

-(NSString*) className{
return NSStringFromClass([self class]);
}
-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary
{

	if(dictionary[@"isDead"])
		self.isDead = [dictionary[@"isDead"] boolValue];

	if(dictionary[@"speed"])
		self.speed = [dictionary[@"speed"] floatValue];

	if(dictionary[@"isInvisible"])
		self.isInvisible = [dictionary[@"isInvisible"] boolValue];

	if(dictionary[@"alertRadius"])
		self.alertRadius = [dictionary[@"alertRadius"] floatValue];

	if(dictionary[@"isSafe"])
		self.isSafe = [dictionary[@"isSafe"] boolValue];

	if(dictionary[@"detectionRadius"])
		self.detectionRadius = [dictionary[@"detectionRadius"] floatValue];

	if(dictionary[@"hasSpottedShark"])
		self.hasSpottedShark = [dictionary[@"hasSpottedShark"] boolValue];

	if(dictionary[@"hatName"])
		self.hatName = dictionary[@"hatName"];

	if(dictionary[@"isStuck"])
		self.isStuck = [dictionary[@"isStuck"] boolValue];

}

@end
