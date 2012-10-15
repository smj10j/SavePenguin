//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Shark : NSObject
{


	float speed;
	float activeDetectionRadius;
	float restingDetectionRadius;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property float speed;
@property float activeDetectionRadius;
@property float restingDetectionRadius;

+(Shark*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
