//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface MovingDoodad : NSObject
{


	BOOL restartAtOtherEnd;
	float timeToCompletePath;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

	NSString* pathName;

#endif // __has_feature(objc_arc)

}
@property BOOL restartAtOtherEnd;
@property float timeToCompletePath;
@property (nonatomic, retain) NSString* pathName;

+(MovingDoodad*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
