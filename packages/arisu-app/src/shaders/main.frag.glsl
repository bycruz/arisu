#version 450

#ifdef VULKAN
#define BINDING(s, b) layout(set = s, binding = b)
#define BUFFER_BINDING(s, b) layout(set = s, binding = b, std430)
#else
#define BINDING(s, b) layout(binding = b)
#define BUFFER_BINDING(s, b) layout(binding = b, std430)
#endif

#ifdef VULKAN
// Must separate them for Vulkan (and other future targets)
BINDING(0, 0)uniform texture2DArray uTextureArray;
BINDING(0, 1)uniform sampler uSampler;
#else
// Can't separate them for OpenGL..
BINDING(0, 0)uniform sampler2DArray uTextureArray;
#endif

BUFFER_BINDING(0, 2)readonly buffer TextureUVs {
    vec2 textureUVScale[];
};

layout(location = 0) in vec4 vertexColor;
layout(location = 1) in vec2 texCoord;
layout(location = 2) flat in int texIndex;

layout(location = 0) out vec4 fragColor;

void main() {
    #ifdef VULKAN
    vec4 texColor = texture(sampler2DArray(uTextureArray, uSampler), vec3(texCoord * textureUVScale[texIndex], texIndex));
    #else
    vec4 texColor = texture(uTextureArray, vec3(texCoord * textureUVScale[texIndex], texIndex));
    #endif

    fragColor = texColor * vertexColor;
}
