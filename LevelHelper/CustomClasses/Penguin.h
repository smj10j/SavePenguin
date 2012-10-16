//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface Penguin : NSObject
{


	BOOL hasSpottedShark;
	float speed;
	BOOL isSafe;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property BOOL hasSpottedShark;
@property float speed;
@property BOOL isSafe;

+(Penguin*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
