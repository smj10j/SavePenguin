//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface MovingBorder : NSObject
{


	BOOL restartAtOtherEnd;
	float timeToCompletePath;
	BOOL followXAxis;
	BOOL isCyclic;
	BOOL followYAxis;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else

	NSString* pathName;

#endif // __has_feature(objc_arc)

}
@property BOOL restartAtOtherEnd;
@property float timeToCompletePath;
@property BOOL followXAxis;
@property BOOL isCyclic;
@property BOOL followYAxis;
@property (nonatomic, retain) NSString* pathName;

+(MovingBorder*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
