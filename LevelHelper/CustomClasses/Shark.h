//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Shark : NSObject
{


	float endpointX;
	float activeSpeed;
	float restingDetectionRadius;
	float activeDetectionRadius;
	float endpointY;
	BOOL targetAcquired;
	float restingSpeed;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property float endpointX;
@property float activeSpeed;
@property float restingDetectionRadius;
@property float activeDetectionRadius;
@property float endpointY;
@property BOOL targetAcquired;
@property float restingSpeed;

+(Shark*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
