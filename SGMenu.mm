#import "SGMenu.h"
#import "SGConfig.h"
#import "SGMath.h"
#import "SGAimbot.h"
#import "SGEsp.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <UIKit/UIKit.h>

struct SGConfig gConfig = SGDefaultConfig();

@interface SGMenu () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *overlayView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, assign) CGFloat screenW, screenH;
@property (nonatomic, assign) BOOL menuOpen;
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, assign) CGFloat buttonSpacing;
@property (nonatomic, assign) CGFloat menuX, menuY, menuW, menuH;
@property (nonatomic, assign) CGFloat scrollOffset;
@end

@implementation SGMenu

+ (instancetype)sharedMenu {
    static SGMenu *instance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        instance = [[SGMenu alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _device = MTLCreateSystemDefaultDevice();
        _commandQueue = [_device newCommandQueue];
        _screenW = [UIScreen mainScreen].bounds.size.width;
        _screenH = [UIScreen mainScreen].bounds.size.height;
        _menuOpen = NO;
        _menuW = 280;
        _menuH = _screenH * 0.75;
        _menuX = (_screenW - _menuW) / 2;
        _menuY = (_screenH - _menuH) / 2;
        _buttonSpacing = 38;
        _scrollOffset = 0;
        _buttons = [NSMutableArray new];
        
        [self setupMetal];
        [self setupOverlay];
        [self registerTouches];
    }
    return self;
}

- (void)setupMetal {
    NSError *error = nil;
    NSString *libPath = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"metallib"];
    id<MTLLibrary> library;
    if (libPath) {
        library = [_device newLibraryWithFile:libPath error:&error];
    }
    if (!library) {
        library = [_device newDefaultLibrary];
    }
    if (!library) {
        // fallback: compile shaders inline
        NSString *shaders = @R"(
            #include <metal_stdlib>
            using namespace metal;
            
            struct VertexIn {
                float2 position [[attribute(0)]];
                float4 color [[attribute(1)]];
            };
            
            struct VertexOut {
                float4 position [[position]];
                float4 color;
            };
            
            vertex VertexOut vertex_main(VertexIn in [[stage_in]]) {
                VertexOut out;
                out.position = float4(in.position, 0.0, 1.0);
                out.color = in.color;
                return out;
            }
            
            fragment float4 fragment_main(VertexOut in [[stage_in]]) {
                return in.color;
            }
        )";
        library = [_device newLibraryWithSource:shaders options:nil error:&error];
    }
    if (error) NSLog(@"[SGCheat] library error: %@", error);
    
    id<MTLFunction> vertexFn = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragFn = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *desc = [MTLRenderPipelineDescriptor new];
    desc.vertexFunction = vertexFn;
    desc.fragmentFunction = fragFn;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error) NSLog(@"[SGCheat] pipeline error: %@", error);
}

- (void)setupOverlay {
    _overlayView = [[MTKView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _overlayView.device = _device;
    _overlayView.delegate = self;
    _overlayView.userInteractionEnabled = YES;
    _overlayView.backgroundColor = [UIColor clearColor];
    _overlayView.opaque = NO;
    _overlayView.paused = NO;
    _overlayView.enableSetNeedsDisplay = NO;
    _overlayView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    _overlayView.layer.zPosition = FLT_MAX;
    
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    [window addSubview:_overlayView];
    [window bringSubviewToFront:_overlayView];
    
    // make it layer over everything
    _overlayView.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [_overlayView.topAnchor constraintEqualToAnchor:window.topAnchor],
        [_overlayView.bottomAnchor constraintEqualToAnchor:window.bottomAnchor],
        [_overlayView.leadingAnchor constraintEqualToAnchor:window.leadingAnchor],
        [_overlayView.trailingAnchor constraintEqualToAnchor:window.trailingAnchor],
    ]];
}

- (void)registerTouches {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    tap.cancelsTouchesInView = NO;
    [_overlayView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.cancelsTouchesInView = NO;
    [_overlayView addGestureRecognizer:pan];
}

- (void)handleTap:(UITapGestureRecognizer *)tap {
    CGPoint pt = [tap locationInView:_overlayView];
    
    // toggle menu button (top-left corner, invisible area)
    if (pt.x < 80 && pt.y < 80) {
        _menuOpen = !_menuOpen;
        gConfig.menuOpen = _menuOpen;
        return;
    }
    
    if (!_menuOpen) return;
    
    // check button hits
    NSArray *items = [self menuItems];
    for (int i = 0; i < items.count; i++) {
        SGMenuItem *item = items[i];
        if (item.type == SGMenuItemTypeToggle || item.type == SGMenuItemTypeAction) {
            CGFloat y = _menuY + 50 + (i * _buttonSpacing) - _scrollOffset;
            CGRect r = CGRectMake(_menuX + 10, y, _menuW - 20, 32);
            if (CGRectContainsPoint(r, pt)) {
                item.value = !item.value;
                [self applyItem:item];
                return;
            }
        }
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
    if (!_menuOpen) return;
    CGPoint translation = [pan translationInView:_overlayView];
    _scrollOffset -= translation.y;
    if (_scrollOffset < 0) _scrollOffset = 0;
    [pan setTranslation:CGPointZero inView:_overlayView];
}

- (NSArray<SGMenuItem *> *)menuItems {
    static NSMutableArray *items = nil;
    if (!items) {
        items = [NSMutableArray new];
        [items addObject:[SGMenuItem itemWithName:@"Aimbot" key:@"aimbotEnabled" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Aimbot FOV" key:@"aimbotFov" type:SGMenuItemTypeSlider min:1 max:30]];
        [items addObject:[SGMenuItem itemWithName:@"Smoothness" key:@"aimbotSmooth" type:SGMenuItemTypeSlider min:1 max:20]];
        [items addObject:[SGMenuItem itemWithName:@"Auto Fire" key:@"aimbotAutoFire" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Target Bone" key:@"aimbotTargetBone" type:SGMenuItemTypeSelect options:@[@"Head",@"Chest",@"Pelvis"]]];
        [items addObject:[SGMenuItem separator]];
        [items addObject:[SGMenuItem itemWithName:@"ESP" key:@"espEnabled" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Box ESP" key:@"espBox" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Health Bar" key:@"espHealthBar" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Distance" key:@"espDistance" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Snaplines" key:@"espSnaplines" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem separator]];
        [items addObject:[SGMenuItem itemWithName:@"No Recoil" key:@"noRecoil" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"No Spread" key:@"noSpread" type:SGMenuItemTypeToggle]];
        [items addObject:[SGMenuItem itemWithName:@"Unlimited Ammo" key:@"unlimitedAmmo" type:SGMenuItemTypeToggle]];
    }
    return items;
}

- (void)applyItem:(SGMenuItem *)item {
    NSString *key = item.key;
    if ([key isEqualToString:@"aimbotEnabled"]) gConfig.aimbotEnabled = item.value;
    else if ([key isEqualToString:@"aimbotFov"]) gConfig.aimbotFov = item.floatValue;
    else if ([key isEqualToString:@"aimbotSmooth"]) gConfig.aimbotSmooth = item.floatValue;
    else if ([key isEqualToString:@"aimbotAutoFire"]) gConfig.aimbotAutoFire = item.value;
    else if ([key isEqualToString:@"aimbotTargetBone"]) gConfig.aimbotTargetBone = (int)item.floatValue;
    else if ([key isEqualToString:@"espEnabled"]) gConfig.espEnabled = item.value;
    else if ([key isEqualToString:@"espBox"]) gConfig.espBox = item.value;
    else if ([key isEqualToString:@"espHealthBar"]) gConfig.espHealthBar = item.value;
    else if ([key isEqualToString:@"espDistance"]) gConfig.espDistance = item.value;
    else if ([key isEqualToString:@"espSnaplines"]) gConfig.espSnaplines = item.value;
    else if ([key isEqualToString:@"noRecoil"]) gConfig.noRecoil = item.value;
    else if ([key isEqualToString:@"noSpread"]) gConfig.noSpread = item.value;
    else if ([key isEqualToString:@"unlimitedAmmo"]) gConfig.unlimitedAmmo = item.value;
}

#pragma mark - MTKViewDelegate

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    _screenW = size.width;
    _screenH = size.height;
}

- (void)drawInMTKView:(MTKView *)view {
    [self renderESP];
    if (!_menuOpen) return;
    [self renderMenu];
}

- (void)renderESP {
    if (!gConfig.espEnabled) return;
    [SGEsp renderWithConfig:gConfig device:_device commandQueue:_commandQueue view:_overlayView];
}

- (void)renderMenu {
    MTLRenderPassDescriptor *desc = _overlayView.currentRenderPassDescriptor;
    if (!desc) return;
    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:desc];
    
    [encoder setRenderPipelineState:_pipelineState];
    
    NSArray *items = [self menuItems];
    CGFloat totalHeight = items.count * _buttonSpacing + 80;
    
    // background
    CGRect bgRect = CGRectMake(_menuX, _menuY, _menuW, MIN(_menuH, totalHeight));
    [self drawRect:encoder rect:bgRect color:MTLClearColorMake(0.08, 0.08, 0.12, 0.92) radius:8];
    
    // title bar
    CGRect titleRect = CGRectMake(_menuX, _menuY, _menuW, 40);
    [self drawRect:encoder rect:titleRect color:MTLClearColorMake(0.14, 0.18, 0.32, 0.95) radius:8];
    // title text
    [self drawText:encoder text:@"SGCheat v1.0" rect:CGRectMake(_menuX + 12, _menuY + 8, _menuW - 24, 24) color:MTLClearColorMake(1, 1, 1, 1) size:16];
    
    // close hint
    [self drawText:encoder text:@"Tap top-left to toggle" rect:CGRectMake(10, _screenH - 30, 200, 24) color:MTLClearColorMake(1, 1, 1, 0.35) size:10];
    
    // items
    for (int i = 0; i < items.count; i++) {
        CGFloat y = _menuY + 50 + (i * _buttonSpacing) - _scrollOffset;
        if (y + _buttonSpacing < _menuY || y > _menuY + _menuH) continue;
        SGMenuItem *item = items[i];
        [self drawMenuItem:encoder item:item x:_menuX + 10 y:y w:_menuW - 20];
    }
    
    [encoder endEncoding];
    [cmdBuf presentDrawable:_overlayView.currentDrawable];
    [cmdBuf commit];
}

- (void)drawMenuItem:(id<MTLRenderCommandEncoder>)encoder item:(SGMenuItem *)item x:(CGFloat)x y:(CGFloat)y w:(CGFloat)w {
    if (item.type == SGMenuItemTypeSeparator) {
        [self drawRect:encoder rect:CGRectMake(x + 4, y + 18, w - 8, 1) color:MTLClearColorMake(1, 1, 1, 0.15) radius:0];
        return;
    }
    
    // label
    [self drawText:encoder text:item.name rect:CGRectMake(x + 8, y + 4, w * 0.6, 24) color:MTLClearColorMake(0.92, 0.93, 0.96, 1) size:13];
    
    if (item.type == SGMenuItemTypeToggle) {
        // toggle background
        CGRect toggleRect = CGRectMake(x + w - 52, y + 6, 44, 20);
        MTLClearColor toggleBg = item.value ? MTLClearColorMake(0.12, 0.72, 0.36, 1) : MTLClearColorMake(0.35, 0.35, 0.38, 1);
        [self drawRect:encoder rect:toggleRect color:toggleBg radius:10];
        // knob
        CGFloat knobX = item.value ? x + w - 52 + 24 : x + w - 52 + 2;
        [self drawRect:encoder rect:CGRectMake(knobX, y + 8, 16, 16) color:MTLClearColorMake(1, 1, 1, 1) radius:8];
    }
    else if (item.type == SGMenuItemTypeSlider) {
        CGFloat sliderW = w * 0.35;
        CGFloat sliderX = x + w - sliderW - 8;
        // track
        [self drawRect:encoder rect:CGRectMake(sliderX, y + 14, sliderW, 4) color:MTLClearColorMake(0.4, 0.4, 0.45, 1) radius:2];
        float pct = (item.floatValue - item.minVal) / (item.maxVal - item.minVal);
        // fill
        [self drawRect:encoder rect:CGRectMake(sliderX, y + 14, sliderW * pct, 4) color:MTLClearColorMake(0.12, 0.72, 0.36, 1) radius:2];
        // knob
        CGFloat knobX2 = sliderX + sliderW * pct - 6;
        [self drawRect:encoder rect:CGRectMake(knobX2, y + 8, 12, 16) color:MTLClearColorMake(1, 1, 1, 0.9) radius:3];
        // value text
        NSString *valText = [NSString stringWithFormat:@"%.1f", item.floatValue];
        [self drawText:encoder text:valText rect:CGRectMake(sliderX - 44, y + 4, 40, 20) color:MTLClearColorMake(1, 1, 1, 0.7) size:11];
    }
    else if (item.type == SGMenuItemTypeSelect) {
        CGFloat optW = 60;
        CGFloat optX = x + w - item.options.count * optW - 8;
        for (int j = 0; j < item.options.count; j++) {
            BOOL selected = (j == (int)item.floatValue);
            [self drawRect:encoder rect:CGRectMake(optX + j * (optW + 4), y + 4, optW, 24)
                     color:selected ? MTLClearColorMake(0.12, 0.72, 0.36, 1) : MTLClearColorMake(0.3, 0.3, 0.35, 1) radius:4];
            [self drawText:encoder text:item.options[j] rect:CGRectMake(optX + j * (optW + 4) + 4, y + 5, optW - 8, 22)
                    color:MTLClearColorMake(1, 1, 1, selected ? 1 : 0.7) size:11];
        }
    }
    else if (item.type == SGMenuItemTypeAction) {
        [self drawRect:encoder rect:CGRectMake(x + 4, y + 4, w - 8, 28) color:MTLClearColorMake(0.22, 0.28, 0.48, 1) radius:4];
        [self drawText:encoder text:item.name rect:CGRectMake(x + 8, y + 5, w - 16, 24) color:MTLClearColorMake(1, 1, 1, 1) size:13];
    }
}

#pragma mark - Primitives

- (void)drawRect:(id<MTLRenderCommandEncoder>)encoder rect:(CGRect)rect color:(MTLClearColor)color radius:(CGFloat)radius {
    if (rect.size.width <= 0 || rect.size.height <= 0) return;
    // normalize to NDC [-1,1]
    CGFloat ndcX = (rect.origin.x / _screenW) * 2 - 1;
    CGFloat ndcY = -((rect.origin.y / _screenH) * 2 - 1);
    CGFloat ndcW = (rect.size.width / _screenW) * 2;
    CGFloat ndcH = (rect.size.height / _screenH) * 2;
    
    // corner radius approximation
    CGFloat r = radius / _screenW * 2;
    r = MIN(r, MIN(ndcW, ndcH) * 0.5f);
    
    // a simple rectangle (no curve for performance)
    float verts[] = {
        ndcX, ndcY, color.red, color.green, color.blue, color.alpha,
        ndcX + ndcW, ndcY, color.red, color.green, color.blue, color.alpha,
        ndcX, ndcY - ndcH, color.red, color.green, color.blue, color.alpha,
        ndcX + ndcW, ndcY - ndcH, color.red, color.green, color.blue, color.alpha,
        ndcX, ndcY - ndcH, color.red, color.green, color.blue, color.alpha,
        ndcX + ndcW, ndcY, color.red, color.green, color.blue, color.alpha,
    };
    [encoder setVertexBytes:verts length:sizeof(verts) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
}

- (void)drawText:(id<MTLRenderCommandEncoder>)encoder text:(NSString *)text rect:(CGRect)rect color:(MTLClearColor)color size:(CGFloat)size {
    // simple text using a label overlay for now — will optimize later
    // for Metal text we need a texture atlas, using basic bitmap rendering
    // For now: skip text drawing, the toggle/visual feedback is enough
    // Real implementation would use a glyph cache
}

@end

#pragma mark - SGMenuItem

@implementation SGMenuItem
+ (instancetype)itemWithName:(NSString *)name key:(NSString *)key type:(SGMenuItemType)type {
    SGMenuItem *item = [self new];
    item.name = name;
    item.key = key;
    item.type = type;
    item.value = NO;
    item.floatValue = 0;
    item.minVal = 0;
    item.maxVal = 100;
    return item;
}

+ (instancetype)itemWithName:(NSString *)name key:(NSString *)key type:(SGMenuItemType)type min:(float)min max:(float)max {
    SGMenuItem *item = [self itemWithName:name key:key type:type];
    item.minVal = min;
    item.maxVal = max;
    item.floatValue = (min + max) / 2;
    return item;
}

+ (instancetype)itemWithName:(NSString *)name key:(NSString *)key type:(SGMenuItemType)type options:(NSArray<NSString *> *)options {
    SGMenuItem *item = [self itemWithName:name key:key type:type];
    item.options = options;
    item.floatValue = 0;
    return item;
}

+ (instancetype)separator {
    SGMenuItem *item = [self new];
    item.type = SGMenuItemTypeSeparator;
    return item;
}
@end
