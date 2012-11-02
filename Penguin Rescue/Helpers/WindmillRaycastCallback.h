#import "Box2D.h"
#import "LHSprite.h"
 
class WindmillRaycastCallback : public b2RayCastCallback
{
public:
    WindmillRaycastCallback() : _fixture(NULL) {
    }
 
    float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {
			
		if([LHSprite tagForBody:fixture->GetBody()] == WINDMILL) {
			//allow windmills to pass through eachother
			return _fraction > 0 ? _fraction : 1;
		}
		
        _fixture = fixture;        
        _point = point;
        _normal = normal;
        _fraction = fraction;
        return fraction;     
    }    
 
    b2Fixture* _fixture;
    b2Vec2 _point;
    b2Vec2 _normal;
    float32 _fraction;
 
};