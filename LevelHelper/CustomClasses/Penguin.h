//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Penguin : NSObject
{


	BOOL isDead;
	float speed;
	BOOL isInvisible;
	float alertRadius;
	BOOL isSafe;
	float detectionRadius;
	BOOL hasSpottedShark;
	BOOL isStuck;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

	NSString* hatName;

#endif // __has_feature(objc_arc)

}
@property BOOL isDead;
@property float speed;
@property BOOL isInvisible;
@property float alertRadius;
@property BOOL isSafe;
@property float detectionRadius;
@property BOOL hasSpottedShark;
@property (nonatomic, retain) NSString* hatName;
@property BOOL isStuck;

+(Penguin*) customClassInstance;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
