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

struct Uniforms
{
    float4x4 projectionMatrix;
};

vertex Vertex vertexFunction(device Vertex *vertices [[buffer(0)]],
                             constant Uniforms * uniforms [[buffer(1)]],
                             uint vid [[vertex_id]])
{
    Vertex vertexOut;
    vertexOut.position = uniforms->projectionMatrix * vertices[vid].position;
    
    return vertexOut;
}

fragment half4 fragmentFunction(Vertex vertexIn [[stage_in]])
{
    return half4(1.0, 1.0, 1.0, 1.0);
}


