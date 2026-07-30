#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

@class MTKView;

typedef NS_ENUM(NSInteger, SGMenuItemType) {
    SGMenuItemTypeToggle,
    SGMenuItemTypeSlider,
    SGMenuItemTypeSelect,
    SGMenuItemTypeAction,
    SGMenuItemTypeSeparator,
};

@interface SGMenuItem : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) SGMenuItemType type;
@property (nonatomic, assign) BOOL value;
@property (nonatomic, assign) float floatValue;
@property (nonatomic, assign) float minVal;
@property (nonatomic, assign) float maxVal;
@property (nonatomic, strong) NSArray<NSString *> *options;

+ (instancetype)itemWithName:(NSString *)name key:(NSString *)key type:(SGMenuItemType)type;
+ (instancetype)itemWithName:(NSString *)name key:(NSString *)key type:(SGMenuItemType)type min:(float)min max:(float)max;
+ (instancetype)itemWithName:(NSString *)name key:(NSString *)key type:(SGMenuItemType)type options:(NSArray<NSString *> *)options;
+ (instancetype)separator;
@end

@interface SGMenu : NSObject
@property (nonatomic, readonly) MTKView *overlayView;
+ (instancetype)sharedMenu;
@end
