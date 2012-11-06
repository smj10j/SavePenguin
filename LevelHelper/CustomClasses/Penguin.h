//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Penguin : NSObject
{


	BOOL isDead;
	float speed;
	BOOL isSafe;
	float alertRadius;
	BOOL isInvisible;
	float detectionRadius;
	BOOL hasSpottedShark;
	BOOL isStuck;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property BOOL isDead;
@property float speed;
@property BOOL isSafe;
@property float alertRadius;
@property BOOL isInvisible;
@property float detectionRadius;
@property BOOL hasSpottedShark;
@property BOOL isStuck;

+(Penguin*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
