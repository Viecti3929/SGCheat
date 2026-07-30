#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Metal/Metal.h>
#import "SGConfig.h"

@class MTKView;

@interface SGEsp : NSObject
+ (void)renderWithConfig:(struct SGConfig)config
                  device:(id<MTLDevice>)device
            commandQueue:(id<MTLCommandQueue>)commandQueue
                    view:(MTKView *)view;
@end
