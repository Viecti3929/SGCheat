#import <Foundation/Foundation.h>
#import "SGMath.h"

@interface SGPlayer : NSObject
@property (nonatomic, assign) uint64_t address;
@property (nonatomic, assign) SGVec3 position;
@property (nonatomic, assign) float health;
@property (nonatomic, assign) float maxHealth;
@property (nonatomic, assign) int team;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) float distance;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) SGVec3 boneHead;
@property (nonatomic, assign) SGVec3 boneNeck;
@property (nonatomic, assign) SGVec3 boneSpine;
@property (nonatomic, assign) SGVec3 boneHip;
@end

@interface SGAimbot : NSObject
+ (SGVec3)getLocalPlayerPos;
+ (SGVec3)getLocalPlayerAngle;
+ (SGMatrix4x4)getViewMatrix;
+ (SGMatrix4x4)getProjMatrix;
+ (NSArray<SGPlayer *> *)getPlayers;
+ (SGPlayer *)getBestTarget:(NSArray<SGPlayer *> *)players;
+ (SGVec3)getTargetPosition:(SGPlayer *)player;
+ (void)aimAt:(SGVec3)targetPos;

// Feature toggles
+ (void)applyNoRecoil;           // zero out RecoilParameters
+ (void)applyNoSpread;           // zero out AccuracyData
+ (void)applyUnlimitedAmmo;      // set ammo to max

// Utility
+ (int)getLocalPlayerTeam;
+ (uint64_t)findLocalPlayerView;
@end
