//This source file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


#import "Shark.h"

@implementation Shark


@synthesize isInvisible;
@synthesize endpointX;
@synthesize activeSpeed;
@synthesize hatName;
@synthesize restingDetectionRadius;
@synthesize activeDetectionRadius;
@synthesize endpointY;
@synthesize isStuck;
@synthesize restingSpeed;
@synthesize targetAcquired;


-(void) dealloc{
#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

if(hatName) [hatName release];

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

	if(dictionary[@"isInvisible"])
		self.isInvisible = [dictionary[@"isInvisible"] boolValue];

	if(dictionary[@"endpointX"])
		self.endpointX = [dictionary[@"endpointX"] floatValue];

	if(dictionary[@"activeSpeed"])
		self.activeSpeed = [dictionary[@"activeSpeed"] floatValue];

	if(dictionary[@"hatName"])
		self.hatName = dictionary[@"hatName"];

	if(dictionary[@"restingDetectionRadius"])
		self.restingDetectionRadius = [dictionary[@"restingDetectionRadius"] floatValue];

	if(dictionary[@"activeDetectionRadius"])
		self.activeDetectionRadius = [dictionary[@"activeDetectionRadius"] floatValue];

	if(dictionary[@"endpointY"])
		self.endpointY = [dictionary[@"endpointY"] floatValue];

	if(dictionary[@"isStuck"])
		self.isStuck = [dictionary[@"isStuck"] boolValue];

	if(dictionary[@"restingSpeed"])
		self.restingSpeed = [dictionary[@"restingSpeed"] floatValue];

	if(dictionary[@"targetAcquired"])
		self.targetAcquired = [dictionary[@"targetAcquired"] boolValue];

}

@end
