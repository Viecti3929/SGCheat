#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "SGConfig.h"

@interface SGEsp : NSObject
+ (void)renderWithConfig:(struct SGConfig)config
                  device:(id<MTLDevice>)device
            commandQueue:(id<MTLCommandQueue>)commandQueue
                    view:(MTKView *)view;
@end
