#version 450

layout(location = 0) in vec4 vertexColor;
layout(location = 1) in vec2 texCoord;

layout(location = 0) out vec4 fragColor;

layout(set = 0, binding = 0, std430) readonly buffer OverlayUniforms {
    float time;
    int patternType;
};

#define PATTERN_SOLID 0
#define PATTERN_DASHED 1
#define PATTERN_MARCHING_ANTS 2

void main() {
    if (patternType == PATTERN_SOLID) {
        fragColor = vertexColor;
    } else if (patternType == PATTERN_DASHED) {
        float dash = mod(texCoord.x * 10.0, 2.0);
        if (dash > 1.0) discard;
        fragColor = vertexColor;
    }
    else if (patternType == PATTERN_MARCHING_ANTS) {
        float pattern = mod(texCoord.x - time * 2.0, 1.0);
        if (pattern > 0.5) discard;
        fragColor = vertexColor;
    }
}
