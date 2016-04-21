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
    
    _displaySemaphore = dispatch_semaphore_create(1);
    
#define TEST_TYPE 0
    
    [self setupMetal];
    [self prepareAssetsForTestType:TEST_TYPE];
    
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
    std::vector<vector_float4> vertices = [self verticesForTestType:testType];
   
    _vertexBuffer = [_device newBufferWithBytes:&vertices.front()
                                         length:sizeof(vector_float4) * vertices.size()
                                        options:MTLResourceOptionCPUCacheModeDefault];
    
    [_vertexBuffer setLabel:@"vertices"];
    
    //
    
    std::vector<uint32_t> indices = [self indicesForTestType:testType];
    
    _indexBuffer = [_device newBufferWithBytes:&indices.front()
                                        length:sizeof(uint32_t) * indices.size()
                                       options:MTLResourceOptionCPUCacheModeDefault];
    
    [_indexBuffer setLabel:@"indices"];
    
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
    
    [commandEncoder pushDebugGroup:@"Rendering"];
    
#if TEST_TYPE == 0
    
    [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypePoint
                               indexCount:[_indexBuffer length] / sizeof(uint32_t)
                                indexType:MTLIndexTypeUInt32
                              indexBuffer:_indexBuffer
                        indexBufferOffset:0];
    
#else 
     [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                               indexCount:[_indexBuffer length] / sizeof(uint32_t)
                                indexType:MTLIndexTypeUInt32
                              indexBuffer:_indexBuffer
                        indexBufferOffset:0];   
#endif

    [commandEncoder pushDebugGroup:@"Rendering"];
    
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


- (NSUInteger) numberOfVerticesForScreenSize:(CGSize) screenSize andTestType:(NSUInteger) type
{
    NSUInteger numberOfRows = screenSize.width / [self sizeOfQuadsForTestType:type].width;
    NSUInteger numberOfColumns = screenSize.height / [self sizeOfQuadsForTestType:type].height;
    
    return ++numberOfRows * ++numberOfColumns;
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
    
    return CGSizeMake(screenBounds.size.width * screenScale , screenBounds.size.height * screenScale);
}

#pragma mark -
#pragma mark Vertices 

- (std::vector<vector_float4>) verticesForTestType:(NSUInteger) type
{
    std::vector<vector_float4> vertices;
    
    const CGSize screenSize = [self sizeOfScreen];
    const NSUInteger numberOfVertices= [self numberOfVerticesForScreenSize:screenSize andTestType:type];
    const CGSize particleSize = [self sizeOfQuadsForTestType:type];
    
    // position coordinates
    float xCoord = 0;
    float yCoord = 0;
    
    for (NSUInteger i = 0; i < numberOfVertices; ++i) {
        
        vector_float4 newVertex = { xCoord, yCoord, 0.0, 1.0 };
        
        vertices.push_back(newVertex);
        
        xCoord += (float) particleSize.width;
        if (xCoord > screenSize.width) {
            xCoord = 0.f;
            yCoord += (float) particleSize.height;
        }
    }
    
    NSLog(@"Number of vertices %lu", vertices.size());
    
    return vertices;
}

#pragma mark -
#pragma mark Indices

- (std::vector<uint32_t>) indicesForTestType:(NSUInteger) type
{
    if (type == 1 || type == 2) {
        return [self triangleIndicesForTestType:type];
    } else {
        return [self pointIndices];
    }
}

- (std::vector<uint32_t>) pointIndices // indicesForTestType - 0
{
    std::vector<uint32_t> indices;
    
    const CGSize screenSize = [self sizeOfScreen];
    const uint32_t numberOfVertices = (uint32_t) [self numberOfVerticesForScreenSize:screenSize andTestType:0];
    
    for (NSUInteger i = 0; i < numberOfVertices; ++i) {
        indices.push_back((uint32_t) i);
    }
    
    NSLog(@"Number of indices %lu", indices.size());
    
    return indices;
}

- (std::vector<uint32_t>) triangleIndicesForTestType:(NSUInteger) type
{
    std::vector<uint32_t> indices;
    
    const CGSize screenSize = [self sizeOfScreen];
    const uint32_t numberOfVertices = (uint32_t) [self numberOfVerticesForScreenSize:screenSize andTestType:type];
    const CGSize particleSize = [self sizeOfQuadsForTestType:type];
    
    const uint32_t verticesPerRow = (screenSize.width / particleSize.width) + 1;
    
    for (NSUInteger i = 0; i < (numberOfVertices - verticesPerRow); ++i) {
        
        if (((i + 1) % verticesPerRow) == 0) {
            continue;
        }
        
        // first triangle
        indices.push_back((uint32_t) i + verticesPerRow);
        indices.push_back((uint32_t) i + 1 + verticesPerRow);
        indices.push_back((uint32_t) i);
        
        // second triangle
        indices.push_back((uint32_t) i+1+verticesPerRow);
        indices.push_back((uint32_t) i+1);
        indices.push_back((uint32_t) i);
    }
    
    NSLog(@"Number of indices %lu", indices.size());
    
    return indices;
}

@end
