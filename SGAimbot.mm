#import "SGAimbot.h"
#import "SGConfig.h"
#import "SGMath.h"
#import "SGOffsets.h"
#import <mach-o/dyld.h>

// ============================================================
// OFFSETS — Standoff 2 (from dump.cs — update per game version)
// Class type info addresses are in SGOffsets.h (relative to
// il2cpp base).  Singleton instances are resolved at runtime
// via Il2CppClass.static_fields.
// ============================================================

static uint64_t g_il2cppBase = 0;

// --- PlayerController offsets ---
#define OFFSET_PC_MAIN_CAM_HOLDER   0x28
#define OFFSET_PC_PLAYER_MAIN_CAM   0xE8
#define OFFSET_PC_PLAYER_FPS_CAM    0xF0
#define OFFSET_PC_CC                0x118

// --- PlayerMarkerView offsets ---
#define OFFSET_PMV_NAME             0x60
#define OFFSET_PMV_HP               0x68
#define OFFSET_PMV_OWNER            0xE0
#define OFFSET_PMV_VISIBLE_1        0xEC

// --- PlayerMainCamera offsets ---
#define OFFSET_PMC_CAMERA           0x20
#define OFFSET_PMC_TRANSFORM        0x38

// --- GunController / AccuracyData offsets ---
#define OFFSET_GC_ACCURACY_DATA     0x228
#define OFFSET_AD_ACCURACY_ANGLE    0x10
#define OFFSET_AD_RECOIL_ANGLE      0x14

// --- AimController offsets ---
#define OFFSET_AC_SENSITIVITY_X     0x58
#define OFFSET_AC_SENSITIVITY_Y     0x5C
#define OFFSET_AC_CAM_TRANSFORM     0x80

// --- RecoilParameters offsets ---
#define OFFSET_RP_HORIZONTAL_RANGE  0x10
#define OFFSET_RP_VERTICAL_RANGE    0x14

// --- Transform / String structs ---
#define OFFSET_TRANSFORM_POS        0x00
#define OFFSET_TRANSFORM_ROT        0x0C
#define OFFSET_STRING_LENGTH        0x08
#define OFFSET_STRING_CHARS         0x0C

// --- BipedMap ---
#define OFFSET_BIPED_HEAD           0x20
#define OFFSET_BIPED_NECK           0x28
#define OFFSET_BIPED_SPINE          0x30
#define OFFSET_BIPED_HIP            0x88

// --- GameController marker list (CEFCGFGGCDCACAA) ---
#define GC_MARKER_LIST_OFFSET       0x240

@implementation SGAimbot

#pragma mark - Class Resolution

+ (uint64_t)il2cppBase {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        for (uint32_t i = 0; i < _dyld_image_count(); i++) {
            const char *name = _dyld_get_image_name(i);
            if (name) {
                const char *last = strrchr(name, '/');
                if (last && (strstr(last, "Standoff") || strstr(last, "standoff"))) {
                    g_il2cppBase = (uint64_t)_dyld_get_image_vmaddr_slide(i);
                    break;
                }
            }
        }
        if (g_il2cppBase == 0)
            g_il2cppBase = (uint64_t)_dyld_get_image_vmaddr_slide(0);
        NSLog(@"[SGCheat] il2cpp base: 0x%llX", g_il2cppBase);
    });
    return g_il2cppBase;
}

+ (uint64_t)resolveStatic:(uintptr_t)classOffset fieldIndex:(int)idx {
    uint64_t base = [self il2cppBase];
    if (!base) return 0;
    uint64_t *classPtr = (uint64_t *)(base + classOffset);
    uint64_t staticFields = classPtr[OFFSET_CLASS_STATIC_FIELDS / 8];
    if (!staticFields) return 0;
    return ((uint64_t *)staticFields)[idx];
}

#pragma mark - Player Data

+ (SGVec3)getLocalPlayerPos {
    uint64_t localPV = [self findLocalPlayerView];
    if (!localPV) return SGVec3Make(0,0,0);
    uint64_t transformPtr = readPtr(localPV + OFFSET_PC_MAIN_CAM_HOLDER);
    if (!transformPtr) return SGVec3Make(0,0,0);
    return readVec3(transformPtr + OFFSET_TRANSFORM_POS);
}

+ (SGVec3)getLocalPlayerAngle {
    uint64_t localPV = [self findLocalPlayerView];
    if (!localPV) return SGVec3Make(0,0,0);
    uint64_t aimCtrl = readPtr(localPV + 0x40);
    if (!aimCtrl) return SGVec3Make(0,0,0);
    uint64_t camT = readPtr(aimCtrl + OFFSET_AC_CAM_TRANSFORM);
    if (!camT) return SGVec3Make(0,0,0);
    return readVec3(camT + OFFSET_TRANSFORM_ROT);
}

+ (SGMatrix4x4)getViewMatrix {
    SGMatrix4x4 mat;
    uint64_t camInst = [self resolveStatic:ClassAddr::PlayerMainCamera fieldIndex:0];
    if (!camInst) { memset(&mat, 0, sizeof(mat)); return mat; }
    uint64_t camera = readPtr(camInst + OFFSET_PMC_CAMERA);
    if (!camera) { memset(&mat, 0, sizeof(mat)); return mat; }
    readBytes(camera + 0x90, &mat, sizeof(mat));
    return mat;
}

+ (SGMatrix4x4)getProjMatrix {
    SGMatrix4x4 mat;
    uint64_t camInst = [self resolveStatic:ClassAddr::PlayerMainCamera fieldIndex:0];
    if (!camInst) { memset(&mat, 0, sizeof(mat)); return mat; }
    uint64_t camera = readPtr(camInst + OFFSET_PMC_CAMERA);
    if (!camera) { memset(&mat, 0, sizeof(mat)); return mat; }
    readBytes(camera + 0xD0, &mat, sizeof(mat));
    return mat;
}

+ (NSArray<SGPlayer *> *)getPlayers {
    NSMutableArray *players = [NSMutableArray new];
    uint64_t gc = [self resolveStatic:ClassAddr::GameController fieldIndex:0];
    if (!gc) return players;

    uint64_t markerListPtr = readPtr(gc + GC_MARKER_LIST_OFFSET);
    int count = readInt(gc + GC_MARKER_LIST_OFFSET + 4);
    if (!markerListPtr || count <= 0 || count > 64) return players;

    for (int i = 0; i < count; i++) {
        uint64_t markerPtr = readPtr(markerListPtr + (i * 8));
        if (!markerPtr) continue;

        SGPlayer *p = [SGPlayer new];
        p.address = markerPtr;

        uint64_t ownerPc = readPtr(markerPtr + OFFSET_PMV_OWNER);
        if (!ownerPc) continue;

        uint64_t transformPtr = readPtr(ownerPc + OFFSET_PC_MAIN_CAM_HOLDER);
        if (transformPtr) p.position = readVec3(transformPtr + OFFSET_TRANSFORM_POS);

        uint64_t nameTmp = readPtr(markerPtr + OFFSET_PMV_NAME);
        if (nameTmp) {
            uint64_t strPtr = readPtr(nameTmp + 0x38);
            if (strPtr) {
                int strLen = readInt(strPtr + OFFSET_STRING_LENGTH);
                if (strLen > 0 && strLen < 64) {
                    uint16_t buf[64] = {0};
                    readBytes(strPtr + OFFSET_STRING_CHARS, buf, strLen * 2);
                    p.name = [[NSString alloc] initWithBytes:buf length:strLen * 2 encoding:NSUTF16LittleEndianStringEncoding];
                }
            }
        }

        uint64_t hpTmp = readPtr(markerPtr + OFFSET_PMV_HP);
        if (hpTmp) {
            uint64_t hpStrPtr = readPtr(hpTmp + 0x38);
            if (hpStrPtr) {
                int hpLen = readInt(hpStrPtr + OFFSET_STRING_LENGTH);
                if (hpLen > 0 && hpLen < 8) {
                    char hpBuf[16] = {0};
                    readBytes(hpStrPtr + OFFSET_STRING_CHARS, hpBuf, hpLen);
                    p.health = atoi(hpBuf);
                    p.maxHealth = 100;
                }
            }
        }

        p.isVisible = readBool(markerPtr + OFFSET_PMV_VISIBLE_1);
        p.team = 0;
        p.distance = SGVec3Distance(p.position, [self getLocalPlayerPos]);

        uint64_t charView = readPtr(ownerPc + 0x48);
        if (charView) {
            uint64_t bipedMap = readPtr(charView + 0x28);
            if (bipedMap) {
                uint64_t headT = readPtr(bipedMap + OFFSET_BIPED_HEAD);
                if (headT) p.bones[0] = readVec3(headT + OFFSET_TRANSFORM_POS);
                uint64_t neckT = readPtr(bipedMap + OFFSET_BIPED_NECK);
                if (neckT) p.bones[1] = readVec3(neckT + OFFSET_TRANSFORM_POS);
                uint64_t spineT = readPtr(bipedMap + OFFSET_BIPED_SPINE);
                if (spineT) p.bones[2] = readVec3(spineT + OFFSET_TRANSFORM_POS);
                uint64_t hipT = readPtr(bipedMap + OFFSET_BIPED_HIP);
                if (hipT) p.bones[3] = readVec3(hipT + OFFSET_TRANSFORM_POS);
            }
        }

        [players addObject:p];
    }
    return players;
}

+ (int)getLocalPlayerTeam {
    uint64_t gc = [self resolveStatic:ClassAddr::GameController fieldIndex:0];
    if (!gc) return 0;
    uint64_t markerListPtr = readPtr(gc + GC_MARKER_LIST_OFFSET);
    int count = readInt(gc + GC_MARKER_LIST_OFFSET + 4);
    if (!markerListPtr || count <= 0) return 0;
    for (int i = 0; i < count; i++) {
        uint64_t marker = readPtr(markerListPtr + (i * 8));
        if (!marker) continue;
        uint64_t owner = readPtr(marker + OFFSET_PMV_OWNER);
        if (!owner) continue;
        uint64_t mainCam = readPtr(owner + OFFSET_PC_PLAYER_MAIN_CAM);
        if (!mainCam) continue;
        return 0;
    }
    return 0;
}

+ (uint64_t)findLocalPlayerView {
    uint64_t gc = [self resolveStatic:ClassAddr::GameController fieldIndex:0];
    if (!gc) return 0;
    uint64_t markerListPtr = readPtr(gc + GC_MARKER_LIST_OFFSET);
    int count = readInt(gc + GC_MARKER_LIST_OFFSET + 4);
    if (!markerListPtr || count <= 0 || count > 64) return 0;
    for (int i = 0; i < count; i++) {
        uint64_t marker = readPtr(markerListPtr + (i * 8));
        if (!marker) continue;
        uint64_t owner = readPtr(marker + OFFSET_PMV_OWNER);
        if (!owner) continue;
        uint64_t mainCam = readPtr(owner + OFFSET_PC_PLAYER_MAIN_CAM);
        if (mainCam) return owner;
    }
    return 0;
}

+ (SGPlayer *)getBestTarget:(NSArray<SGPlayer *> *)players {
    if (!players.count) return nil;
    SGVec3 localPos = [self getLocalPlayerPos];
    SGVec3 localAngle = [self getLocalPlayerAngle];
    SGVec3 forward = [self angleToVector:localAngle];
    
    SGPlayer *best = nil;
    float bestScore = FLT_MAX;
    int localTeam = 0; // TODO: read from local player
    
    for (SGPlayer *p in players) {
        if (gConfig.espIgnoreTeammates && p.team == localTeam) continue;
        if (p.health <= 0 || p.health > 200) continue;
        
        SGVec3 dirToEnemy = SGVec3Normalize(SGVec3Subtract(p.position, localPos));
        float dot = SGVec3Dot(forward, dirToEnemy);
        float angleRad = acosf(fmaxf(-1, fminf(1, dot)));
        float angleDeg = angleRad * (180.0 / M_PI);
        
        if (angleDeg > gConfig.aimbotFov * 2) continue;
        
        float score = angleDeg * 10 + p.distance * 0.1f;
        if (!p.isVisible) score *= 2;
        
        if (score < bestScore) {
            bestScore = score;
            best = p;
        }
    }
    
    return best;
}

+ (SGVec3)getTargetPosition:(SGPlayer *)player {
    switch (gConfig.aimbotTargetBone) {
        case 0: return player.bones[0];
        case 1: return player.bones[2];
        case 2: return player.bones[3];
        default: return player.position;
    }
}

+ (void)aimAt:(SGVec3)targetPos {
    SGVec3 localPos = [self getLocalPlayerPos];
    SGVec3 localAngle = [self getLocalPlayerAngle];
    SGVec3 delta = SGVec3Subtract(targetPos, localPos);
    
    float targetYaw = atan2f(delta.x, delta.z) * (180.0 / M_PI);
    float targetPitch = -atan2f(delta.y, sqrtf(delta.x*delta.x + delta.z*delta.z)) * (180.0 / M_PI);
    
    float smoothFactor = 1.0f / fmaxf(1.0f, gConfig.aimbotSmooth);
    
    SGVec3 currentAngle = localAngle;
    float newYaw = currentAngle.x + (targetYaw - currentAngle.x) * smoothFactor;
    float newPitch = currentAngle.y + (targetPitch - currentAngle.y) * smoothFactor;
    
    uint64_t localPV = [self findLocalPlayerView];
    if (!localPV) return;
    uint64_t aimCtrl = readPtr(localPV + 0x40);
    if (!aimCtrl) return;
    uint64_t camT = readPtr(aimCtrl + OFFSET_AC_CAM_TRANSFORM);
    if (!camT) return;
    writeFloat(camT + OFFSET_TRANSFORM_ROT, newYaw);
    writeFloat(camT + OFFSET_TRANSFORM_ROT + 4, newPitch);
}

#pragma mark - Feature Toggles

+ (void)applyNoRecoil {
    // Zero out RecoilParameters on the current GunController
    // Access chain: PlayerController -> WeaponryController -> GunController -> GunParameters -> RecoilParameters
    // GunParameters has RecoilParameters at +0x158
    uint64_t localPV = [self findLocalPlayerView];
    if (!localPV) return;
    // TODO: full chain resolve
    // uint64_t weaponry = readPtr(localPV + OFFSET_PC_WEAPONRY);
    // uint64_t gunCtrl = readPtr(weaponry + activeGunOffset);
    // uint64_t gunParams = readPtr(gunCtrl + gunParamsOffset);
    // writeFloat(gunParams + 0x158 + OFFSET_RP_HORIZONTAL_RANGE, 0);
    // writeFloat(gunParams + 0x158 + OFFSET_RP_VERTICAL_RANGE, 0);
}

+ (void)applyNoSpread {
    // Zero out AccuracyData on the current GunController
    uint64_t localPV = [self findLocalPlayerView];
    if (!localPV) return;
    // TODO: resolve GunController instance
    // uint64_t gunCtrl = ...;
    // writeFloat(gunCtrl + OFFSET_GC_ACCURACY_DATA + OFFSET_AD_ACCURACY_ANGLE, 0);
    // writeFloat(gunCtrl + OFFSET_GC_ACCURACY_DATA + OFFSET_AD_RECOIL_ANGLE, 0);
}

+ (void)applyUnlimitedAmmo {
    // Search for WeaponDropController ammo fields and set to max
    uint64_t localPV = [self findLocalPlayerView];
    if (!localPV) return;
    // TODO: resolve current weapon's ammo field
    // WeaponDropController.EFFCAEEHDCEEEHD (ammo int) at +0x68
    // writeInt(dropCtrl + 0x68, 999);
}

#pragma mark - In-Process Memory Access

// Direct pointer dereference — works because we're injected into the same process.
static inline uint64_t readPtr(uint64_t addr) {
    return *(volatile uint64_t *)addr;
}

static inline int readInt(uint64_t addr) {
    return *(volatile int *)addr;
}

static inline float readFloat(uint64_t addr) {
    return *(volatile float *)addr;
}

static inline BOOL readBool(uint64_t addr) {
    return *(volatile uint8_t *)addr != 0;
}

static inline SGVec3 readVec3(uint64_t addr) {
    return *(volatile SGVec3 *)addr;
}

static inline void readBytes(uint64_t addr, void *buffer, size_t length) {
    memcpy(buffer, (void *)addr, length);
}

static inline void writeFloat(uint64_t addr, float val) {
    *(volatile float *)addr = val;
}

+ (SGVec3)angleToVector:(SGVec3)angle {
    float yaw = angle.x * (M_PI / 180.0);
    float pitch = angle.y * (M_PI / 180.0);
    return SGVec3Make(
        -sinf(yaw) * cosf(pitch),
        sinf(pitch),
        cosf(yaw) * cosf(pitch)
    );
}

@end

#pragma mark - SGPlayer

@implementation SGPlayer
@end
