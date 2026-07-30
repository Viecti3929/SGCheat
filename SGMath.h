#import <simd/simd.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>

typedef struct SGMatrix4x4 {
    float m[16];
} SGMatrix4x4;

typedef struct SGVec3 {
    float x, y, z;
} SGVec3;

typedef struct SGVec2 {
    float x, y;
} SGVec2;

static inline SGVec3 SGVec3Make(float x, float y, float z) {
    return (SGVec3){x, y, z};
}

static inline SGVec2 SGVec2Make(float x, float y) {
    return (SGVec2){x, y};
}

static inline SGVec3 SGVec3Subtract(SGVec3 a, SGVec3 b) {
    return SGVec3Make(a.x - b.x, a.y - b.y, a.z - b.z);
}

static inline float SGVec3Dot(SGVec3 a, SGVec3 b) {
    return a.x*b.x + a.y*b.y + a.z*b.z;
}

static inline float SGVec3Length(SGVec3 v) {
    return sqrtf(v.x*v.x + v.y*v.y + v.z*v.z);
}

static inline SGVec3 SGVec3Normalize(SGVec3 v) {
    float len = SGVec3Length(v);
    if (len < 0.0001f) return SGVec3Make(0,0,0);
    return SGVec3Make(v.x/len, v.y/len, v.z/len);
}

static inline float SGVec3Distance(SGVec3 a, SGVec3 b) {
    return SGVec3Length(SGVec3Subtract(a, b));
}

static inline float SGVec3AngleBetween(SGVec3 a, SGVec3 b) {
    float dot = SGVec3Dot(a, b);
    float lenA = SGVec3Length(a);
    float lenB = SGVec3Length(b);
    if (lenA < 0.0001f || lenB < 0.0001f) return 0;
    return acosf(dot / (lenA * lenB));
}

BOOL SGWorldToScreen(SGVec3 worldPos, SGVec2 screenSize, SGMatrix4x4 viewMatrix, SGMatrix4x4 projMatrix, SGVec2 *outScreen);
