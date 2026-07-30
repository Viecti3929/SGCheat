#import <UIKit/UIKit.h>

struct SGConfig {
    BOOL menuOpen;
    BOOL aimbotEnabled;
    float aimbotFov;
    float aimbotSmooth;
    BOOL aimbotAutoFire;
    int aimbotTargetBone; // 0=head 1=chest 2=pelvis

    BOOL espEnabled;
    BOOL espBox;
    BOOL espHealthBar;
    BOOL espDistance;
    BOOL espSnaplines;
    BOOL espIgnoreTeammates;

    BOOL noRecoil;     // Zero GunParameters.RecoilParameters via memory writes
    BOOL noSpread;     // Zero GunController.AccuracyData via memory writes
    BOOL unlimitedAmmo; // Set WeaponDropController ammo to 999
};

static inline struct SGConfig SGDefaultConfig() {
    return (struct SGConfig){
        .menuOpen = NO,
        .aimbotEnabled = YES,
        .aimbotFov = 8.0f,
        .aimbotSmooth = 4.0f,
        .aimbotAutoFire = NO,
        .aimbotTargetBone = 0,
        .espEnabled = YES,
        .espBox = YES,
        .espHealthBar = YES,
        .espDistance = YES,
        .espSnaplines = NO,
        .espIgnoreTeammates = YES,
        .noRecoil = YES,
        .noSpread = NO,
        .unlimitedAmmo = NO,
    };
}

extern struct SGConfig gConfig;
