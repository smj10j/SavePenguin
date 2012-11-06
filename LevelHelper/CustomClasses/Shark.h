//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Shark : NSObject
{


	BOOL isInvisible;
	float endpointX;
	float activeSpeed;
	float restingDetectionRadius;
	float activeDetectionRadius;
	float endpointY;
	BOOL isStuck;
	float restingSpeed;
	BOOL targetAcquired;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property BOOL isInvisible;
@property float endpointX;
@property float activeSpeed;
@property float restingDetectionRadius;
@property float activeDetectionRadius;
@property float endpointY;
@property BOOL isStuck;
@property float restingSpeed;
@property BOOL targetAcquired;

+(Shark*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
