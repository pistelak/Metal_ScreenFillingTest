//
//  Shaders.metal
//  Metal_ScreenFillingTest
//
//  Created by Radek Pistelak on 09.04.16.
//  Copyright © 2016 ran. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex
{
    float4 position [[position]];
};

struct ModelViewMatrix
{
    float4x4 modelViewMatrix;
};

struct ProjectionMatrix
{
    float4x4 projectionMatrix;
};

vertex Vertex vertexFunction(device Vertex *vertices [[buffer(0)]],
                             constant ProjectionMatrix * projection [[buffer(1)]],
                             constant ModelViewMatrix * modelView [[buffer(2)]],
                             uint vid [[vertex_id]])
{
    Vertex vertexOut;
    vertexOut.position = projection->projectionMatrix * modelView->modelViewMatrix * vertices[vid].position;
    
    return vertexOut;
}

fragment half4 fragmentFunction(Vertex vertexIn [[stage_in]])
{
    return half4(1.0, 1.0, 1.0, 1.0);
}


