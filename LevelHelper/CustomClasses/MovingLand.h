//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface MovingLand : NSObject
{


	BOOL followYAxis;
	float timeToCompletePath;
	BOOL isCyclic;
	BOOL followXAxis;
	BOOL restartAtOtherEnd;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

	NSString* pathName;

#endif // __has_feature(objc_arc)

}
@property BOOL followYAxis;
@property float timeToCompletePath;
@property BOOL isCyclic;
@property BOOL followXAxis;
@property (nonatomic, retain) NSString* pathName;
@property BOOL restartAtOtherEnd;

+(MovingLand*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
