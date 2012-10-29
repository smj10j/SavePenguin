#import "Box2D.h"
 
class WindmillRaycastCallback : public b2RayCastCallback
{
public:
    WindmillRaycastCallback() : _fixture(NULL) {
    }
 
    float32 ReportFixture(b2Fixture* fixture, const b2Vec2& point, const b2Vec2& normal, float32 fraction) {        
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