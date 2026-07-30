#import "SGMath.h"

bool SGWorldToScreen(SGVec3 worldPos, SGVec2 screenSize, SGMatrix4x4 viewMatrix, SGMatrix4x4 projMatrix, SGVec2 *outScreen) {
    // combine view & projection
    float mvp[16];
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            mvp[i*4 + j] = 0;
            for (int k = 0; k < 4; k++) {
                mvp[i*4 + j] += projMatrix.m[i*4 + k] * viewMatrix.m[k*4 + j];
            }
        }
    }
    
    // transform point
    float x = worldPos.x * mvp[0] + worldPos.y * mvp[4] + worldPos.z * mvp[8] + mvp[12];
    float y = worldPos.x * mvp[1] + worldPos.y * mvp[5] + worldPos.z * mvp[9] + mvp[13];
    float w = worldPos.x * mvp[3] + worldPos.y * mvp[7] + worldPos.z * mvp[11] + mvp[15];
    
    if (w < 0.01f) return false;
    
    float invW = 1.0f / w;
    x *= invW;
    y *= invW;
    
    // NDC to screen
    outScreen->x = (x + 1.0f) * 0.5f * screenSize.x;
    outScreen->y = (1.0f - y) * 0.5f * screenSize.y;
    
    return true;
}
