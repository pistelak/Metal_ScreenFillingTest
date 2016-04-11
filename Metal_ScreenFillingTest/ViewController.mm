//
//  ViewController.m
//  Metal_ScreenFillingTest
//
//  Created by Radek Pistelak on 09.04.16.
//  Copyright © 2016 ran. All rights reserved.
//

#import "ViewController.h"

#import <Metal/Metal.h>
#import <Simd/Simd.h>

#import "AAPLTransforms.h"

#import <vector>

@implementation ViewController
{
    id<MTLDevice> _device;
    id<MTLLibrary> _library;
    id<MTLCommandQueue> _commandQueue;
    
    id<MTLRenderPipelineState> _renderPipelineState;
    
    id<MTLBuffer> _vertexBuffer;
    id<MTLBuffer> _indexBuffer;
    id<MTLBuffer> _projectionMatrixBuffer;
    id<MTLBuffer> _modelMatricesBuffer;
    
    dispatch_semaphore_t _displaySemaphore;
    
    CAMetalLayer * _metalLayer;
    CADisplayLink * _timer;
}

@dynamic view;

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [self setupMetal];
    [self prepareAssetsForTestType:1];
    
    _timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(render)];
    [_timer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    
    _metalLayer = (CAMetalLayer *) [self.view layer];
}


- (void) setupMetal
{
    _device = MTLCreateSystemDefaultDevice();
    _metalLayer.device = _device;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    if (!_device) {
        NSLog(@"Error occurred when creating device");
    }
    
    _commandQueue = [_device newCommandQueue];
    
    if (!_commandQueue) {
        NSLog(@"Error occurred when creating command queue");
    }
    
    _library = [_device newDefaultLibrary];
    
    if (!_library) {
        NSLog(@"Error occurred when creating library");
    }
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = [_library newFunctionWithName:@"vertexFunction"];
    pipelineDescriptor.fragmentFunction = [_library newFunctionWithName:@"fragmentFunction"];
    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    
    NSError *error = nil;
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    
    if (!_renderPipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
}

- (void) prepareAssetsForTestType:(NSUInteger) testType
{
    static const vector_float4 vertices[] = {
        { 0.0, 1.0, 0.0, 1.0 },
        { 1.0, 1.0, 0.0, 1.0 },
        { 1.0, 0.0, 0.0, 1.0 },
        { 0.0, 0.0, 0.0, 1.0 },
    };
    
    _vertexBuffer = [_device newBufferWithBytes:vertices
                                         length:sizeof(vertices)
                                        options:MTLResourceOptionCPUCacheModeDefault];
    
    [_vertexBuffer setLabel:@"vertices"];
    
    //
    
    static const uint16_t indices[] = {
        0, 1, 3, 1, 2, 3
    };
    
    _indexBuffer = [_device newBufferWithBytes:indices
                                        length:sizeof(indices)
                                       options:MTLResourceOptionCPUCacheModeDefault];
    
    [_indexBuffer setLabel:@"indices"];
    
    //
    
    std::vector<matrix_float4x4> modelMatrices = [self modelMatricesForTestType:testType];
    
    _modelMatricesBuffer = [_device newBufferWithBytes:&modelMatrices.front()
                                                length:sizeof(matrix_float4x4) * modelMatrices.size()
                                               options:MTLResourceOptionCPUCacheModeDefault];
    
    [_modelMatricesBuffer setLabel:@"modelMatrices"];
    
    //
    
    const matrix_float4x4 projectionMatrix = [self projectionMatrix];
    
    _projectionMatrixBuffer = [_device newBufferWithBytes:&projectionMatrix
                                          length:sizeof(matrix_float4x4)
                                         options:MTLResourceOptionCPUCacheModeDefault];
    
    [_projectionMatrixBuffer setLabel:@"projectionMatrix"];
}

- (void) render
{
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    
    id<CAMetalDrawable> drawable = [_metalLayer nextDrawable];
    
    __block CFTimeInterval previousTimestamp = CFAbsoluteTimeGetCurrent();
    
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 104.f/255.f, 55.f/255.f, 1.f);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    CGSize sizeOfScreen = [self sizeOfScreen];
    
    [commandEncoder setRenderPipelineState:_renderPipelineState];
    [commandEncoder setViewport: { 0, 0, sizeOfScreen.width, sizeOfScreen.height, 0, 1 }];
    
    [commandEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:_projectionMatrixBuffer offset:0 atIndex:1];
    
    [commandEncoder pushDebugGroup:@"Render Meshes"];
    
    const NSUInteger numberOfItems = [_modelMatricesBuffer length] / sizeof(matrix_float4x4);
    
    for (NSUInteger i = 0; i < numberOfItems; ++i) {
        
        [commandEncoder setVertexBuffer:_modelMatricesBuffer offset:i*sizeof(matrix_float4x4) atIndex:2];
        
        [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                   indexCount:[_indexBuffer length] / sizeof(uint16_t)
                                    indexType:MTLIndexTypeUInt16
                                  indexBuffer:_indexBuffer
                            indexBufferOffset:0];
    }

    [commandEncoder pushDebugGroup:@"Render Meshes"];
    
    [commandEncoder endEncoding];
    
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull buffer) {
        CFTimeInterval frameDuration = CFAbsoluteTimeGetCurrent() - previousTimestamp;
        NSLog(@"Frame duration: %f ms", frameDuration * 1000.0);
    }];
    
    
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

#pragma mark -
#pragma mark Helper methods

- (matrix_float4x4) projectionMatrix
{
    const CGSize screenSize = [self sizeOfScreen];
    return AAPL::ortho2d_oc(0, screenSize.width, 0, screenSize.height, 0, 1);
}

- (std::vector<matrix_float4x4>) modelMatricesForTestType:(NSUInteger) type
{
    const CGSize screenSize = [self sizeOfScreen];
    const CGSize particleSize = [self sizeOfQuadsForTestType:type];
    const NSUInteger numberOfItems = [self numberOfQuadsForScreenSize:screenSize andTestType:type];
    
    std::vector<matrix_float4x4> modelMatrices;
    
    NSUInteger xCoord = 0;
    NSUInteger yCoord = screenSize.height - particleSize.height;
    
    for (NSUInteger i = 0; i < numberOfItems; ++i) {
        
        matrix_float4x4 modelMatrix = matrix_identity_float4x4;
        modelMatrix = modelMatrix * AAPL::translate(xCoord, yCoord, 0);
        modelMatrix = modelMatrix * AAPL::scale(particleSize.width, particleSize.height, 0);
        
        modelMatrices.push_back(modelMatrix);
        
        xCoord += particleSize.width;
        if ((xCoord + particleSize.width) > screenSize.width) {
            xCoord = 0;
            yCoord -= particleSize.height;
        }
    }

    return modelMatrices;
}

- (NSUInteger) numberOfQuadsForScreenSize:(CGSize) screenSize andTestType:(NSUInteger) type
{
    NSUInteger numberOfRows = screenSize.width / [self sizeOfQuadsForTestType:type].width;
    NSUInteger numberOfColumns = screenSize.height / [self sizeOfQuadsForTestType:type].height;
    
    return (numberOfRows * numberOfColumns);
}

- (CGSize) sizeOfQuadsForTestType:(NSUInteger) type
{
    switch (type) {
        case 1:
            return CGSizeMake(2, 2);
        case 2:
            return CGSizeMake(4, 1);
        default:
            return CGSizeMake(1, 1); // points
    }
}

- (CGSize) sizeOfScreen
{
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat screenScale = [[UIScreen mainScreen] scale];
    
    return CGSizeMake(screenBounds.size.width * screenScale, screenBounds.size.height * screenScale);
}

@end
