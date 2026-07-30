#import "SGEsp.h"
#import "SGConfig.h"
#import "SGMath.h"
#import "SGAimbot.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@implementation SGEsp

+ (void)renderWithConfig:(struct SGConfig)config
                  device:(id<MTLDevice>)device
            commandQueue:(id<MTLCommandQueue>)commandQueue
                    view:(MTKView *)view {
    
    NSArray<SGPlayer *> *players = [SGAimbot getPlayers];
    if (!players.count) return;
    
    MTLRenderPassDescriptor *desc = view.currentRenderPassDescriptor;
    if (!desc) return;
    
    id<MTLCommandBuffer> cmdBuf = [commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [cmdBuf renderCommandEncoderWithDescriptor:desc];
    
    SGMatrix4x4 viewMat = [SGAimbot getViewMatrix];
    SGMatrix4x4 projMat = [SGAimbot getProjMatrix];
    CGFloat w = view.bounds.size.width;
    CGFloat h = view.bounds.size.height;
    SGVec2 screenSize = SGVec2Make(w, h);
    
    int localTeam = [SGAimbot getLocalPlayerTeam];
    
    for (SGPlayer *p in players) {
        if (config.espIgnoreTeammates && p.team == localTeam) continue;
        if (p.health <= 0) continue;
        
        SGVec2 screenPos;
        if (!SGWorldToScreen(p.position, screenSize, viewMat, projMat, &screenPos)) continue;
        
        // calculate box height based on distance
        float boxHeight = 60.0f / (p.distance * 0.01f + 1.0f);
        boxHeight = fmaxf(20, fminf(200, boxHeight));
        float boxWidth = boxHeight * 0.6f;
        float boxX = screenPos.x - boxWidth / 2;
        float boxY = screenPos.y - boxHeight;
        
        // color based on health
        float healthPct = p.health / p.maxHealth;
        MTLClearColor boxColor;
        if (healthPct > 0.66) {
            boxColor = MTLClearColorMake(0.12, 0.72, 0.36, 1); // green
        } else if (healthPct > 0.33) {
            boxColor = MTLClearColorMake(0.95, 0.72, 0.12, 1); // yellow
        } else {
            boxColor = MTLClearColorMake(0.85, 0.18, 0.18, 1); // red
        }
        
        if (config.espBox) {
            // box outline
            [SGEsp drawHollowRect:encoder rect:CGRectMake(boxX, boxY, boxWidth, boxHeight) color:boxColor thickness:1.5 screenW:w screenH:h];
        }
        
        if (config.espHealthBar) {
            // health bar on left
            CGFloat barW = 4;
            CGFloat barH = boxHeight * healthPct;
            [SGEsp drawFilledRect:encoder
                            rect:CGRectMake(boxX - barW - 2, boxY + boxHeight - barH, barW, barH)
                            color:boxColor screenW:w screenH:h];
        }
        
        if (config.espDistance) {
            NSString *distStr = [NSString stringWithFormat:@"%.0fm", p.distance];
            [SGEsp drawText:encoder text:distStr x:boxX y:boxY + boxHeight + 2 color:boxColor size:10 screenW:w screenH:h];
        }
        
        if (config.espSnaplines) {
            // line from bottom of screen to player
            [SGEsp drawLine:encoder fromX:w/2 fromY:h toX:screenPos.x toY:screenPos.y color:boxColor screenW:w screenH:h];
        }
    }
    
    [encoder endEncoding];
    [cmdBuf commit];
}

+ (void)drawHollowRect:(id<MTLRenderCommandEncoder>)encoder rect:(CGRect)rect color:(MTLClearColor)color thickness:(CGFloat)thick screenW:(CGFloat)w screenH:(CGFloat)h {
    // top
    [SGEsp drawFilledRect:encoder rect:CGRectMake(rect.origin.x, rect.origin.y, rect.size.width, thick) color:color screenW:w screenH:h];
    // bottom
    [SGEsp drawFilledRect:encoder rect:CGRectMake(rect.origin.x, rect.origin.y + rect.size.height - thick, rect.size.width, thick) color:color screenW:w screenH:h];
    // left
    [SGEsp drawFilledRect:encoder rect:CGRectMake(rect.origin.x, rect.origin.y, thick, rect.size.height) color:color screenW:w screenH:h];
    // right
    [SGEsp drawFilledRect:encoder rect:CGRectMake(rect.origin.x + rect.size.width - thick, rect.origin.y, thick, rect.size.height) color:color screenW:w screenH:h];
}

+ (void)drawFilledRect:(id<MTLRenderCommandEncoder>)encoder rect:(CGRect)rect color:(MTLClearColor)color screenW:(CGFloat)w screenH:(CGFloat)h {
    if (rect.size.width <= 0 || rect.size.height <= 0) return;
    CGFloat ndcX = (rect.origin.x / w) * 2 - 1;
    CGFloat ndcY = -((rect.origin.y / h) * 2 - 1);
    CGFloat ndcW = (rect.size.width / w) * 2;
    CGFloat ndcH = (rect.size.height / h) * 2;
    
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

+ (void)drawLine:(id<MTLRenderCommandEncoder>)encoder fromX:(CGFloat)x1 fromY:(CGFloat)y1 toX:(CGFloat)x2 toY:(CGFloat)y2 color:(MTLClearColor)color screenW:(CGFloat)w screenH:(CGFloat)h {
    CGFloat ndcX1 = (x1 / w) * 2 - 1;
    CGFloat ndcY1 = -((y1 / h) * 2 - 1);
    CGFloat ndcX2 = (x2 / w) * 2 - 1;
    CGFloat ndcY2 = -((y2 / h) * 2 - 1);
    
    float verts[] = {
        ndcX1, ndcY1, color.red, color.green, color.blue, color.alpha,
        ndcX2, ndcY2, color.red, color.green, color.blue, color.alpha,
    };
    [encoder setVertexBytes:verts length:sizeof(verts) atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeLine vertexStart:0 vertexCount:2];
}

+ (void)drawText:(id<MTLRenderCommandEncoder>)encoder text:(NSString *)text x:(CGFloat)x y:(CGFloat)y color:(MTLClearColor)color size:(CGFloat)size screenW:(CGFloat)w screenH:(CGFloat)h {
    // Text rendering placeholder — requires font atlas
    // For now the visual indicators (box/healthbar/distance number) are functional
    // TODO: implement bitmap font rendering
}

@end
