//This header file was generated automatically by LevelHelper
//based on the class template defined by the user.
//For more info please visit: www.levelhelper.org


@interface ToolboxItem_Windmill : NSObject
{


	float scale;
	float power;
	float runningCost;
	float reach;
	float placeCost;


#if __has_feature(objc_arc) && __clang_major__ >= 3

#else


#endif // __has_feature(objc_arc)

}
@property float scale;
@property float power;
@property float runningCost;
@property float reach;
@property float placeCost;

+(ToolboxItem_Windmill*) customClassInstance;

-(NSString*) className;

-(void) setPropertiesFromDictionary:(NSDictionary*)dictionary;

@end
