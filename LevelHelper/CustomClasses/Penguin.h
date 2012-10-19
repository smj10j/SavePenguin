//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Penguin : NSObject
{


	BOOL isDead;
	float speed;
	float detectionRadius;
	BOOL hasSpottedShark;
	BOOL isSafe;
	float alertRadius;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property BOOL isDead;
@property float speed;
@property float detectionRadius;
@property BOOL hasSpottedShark;
@property BOOL isSafe;
@property float alertRadius;

+(Penguin*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
