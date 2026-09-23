#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

#ifdef VULKAN
#define BINDING(s, b) layout(set = s, binding = b)
#define BUFFER_BINDING(s, b) layout(set = s, binding = b, std430)
#define IMAGE_BINDING(s, b) layout(set = s, binding = b, rgba8)
#else
#define BINDING(s, b) layout(binding = b)
#define BUFFER_BINDING(s, b) layout(binding = b, std430)
#define IMAGE_BINDING(s, b) layout(binding = b, rgba8)
#endif

IMAGE_BINDING(0, 0)writeonly uniform image2D canvas;
BUFFER_BINDING(0, 1)readonly buffer ComputeInputs {
    vec4 color;
    vec2 selectTopLeft;
    vec2 selectBottomRight;
    ivec2 center;
    ivec2 lineEnd;
    float radius;
    int tool;
};

float colorDistance(vec3 color1, vec3 color2) {
    vec3 diff = color1 - color2;
    return length(diff); // Euclidean distance
}

void main() {
    ivec2 pixelCoords;
    if (tool == 2 || tool == 3 || tool == 4 || tool == 5) {
        pixelCoords = ivec2(gl_GlobalInvocationID.xy);
    } else {
        // Brush/eraser use radius-based coords
        ivec2 localCoords = ivec2(gl_GlobalInvocationID.xy);
        pixelCoords = center + localCoords - ivec2(radius);

        float dist = distance(vec2(localCoords), vec2(radius));
        if (dist > radius) return;
    }

    // Check if pixel is within selected area
    if (selectTopLeft.x != -1 && (pixelCoords.x < selectTopLeft.x || pixelCoords.x > selectBottomRight.x ||
                pixelCoords.y < selectTopLeft.y || pixelCoords.y > selectBottomRight.y)) {
        return;
    }

    if (tool == 0) {
        imageStore(canvas, pixelCoords, color);
    } else if (tool == 1) {
        imageStore(canvas, pixelCoords, vec4(0.0, 0.0, 0.0, 0.0));
    } else if (tool == 3) {
        // Line drawing using Bresenham-like distance check
        vec2 lineStart = vec2(center);
        vec2 lineEndPos = vec2(lineEnd);
        vec2 pixelPos = vec2(pixelCoords);

        vec2 lineVec = lineEndPos - lineStart;
        float lineLen = length(lineVec);

        if (lineLen < 0.001) return;

        vec2 lineDir = lineVec / lineLen;
        vec2 toPixel = pixelPos - lineStart;

        float proj = dot(toPixel, lineDir);
        proj = clamp(proj, 0.0, lineLen);

        vec2 closest = lineStart + lineDir * proj;
        float dist = distance(pixelPos, closest);

        if (dist <= radius) {
            imageStore(canvas, pixelCoords, color);
        }
    } else if (tool == 4) {
        // Rectangle drawing
        vec2 topLeft = vec2(min(center.x, lineEnd.x), min(center.y, lineEnd.y));
        vec2 bottomRight = vec2(max(center.x, lineEnd.x), max(center.y, lineEnd.y));
        vec2 pixelPos = vec2(pixelCoords);

        float distLeft = abs(pixelPos.x - topLeft.x);
        float distRight = abs(pixelPos.x - bottomRight.x);
        float distTop = abs(pixelPos.y - topLeft.y);
        float distBottom = abs(pixelPos.y - bottomRight.y);

        bool onLeft = (pixelPos.y >= topLeft.y && pixelPos.y <= bottomRight.y) && distLeft <= radius;
        bool onRight = (pixelPos.y >= topLeft.y && pixelPos.y <= bottomRight.y) && distRight <= radius;
        bool onTop = (pixelPos.x >= topLeft.x && pixelPos.x <= bottomRight.x) && distTop <= radius;
        bool onBottom = (pixelPos.x >= topLeft.x && pixelPos.x <= bottomRight.x) && distBottom <= radius;

        if (onLeft || onRight || onTop || onBottom) {
            imageStore(canvas, pixelCoords, color);
        }
    } else if (tool == 5) {
        // Ellipse drawing with corner-to-corner bounding box
        vec2 corner1 = vec2(center);
        vec2 corner2 = vec2(lineEnd);
        vec2 pixelPos = vec2(pixelCoords);

        vec2 centerPos = (corner1 + corner2) / 2.0;
        vec2 radii = abs(corner2 - corner1) / 2.0;

        if (radii.x < 0.001 || radii.y < 0.001) return;

        vec2 normalized = (pixelPos - centerPos) / radii;
        float distFromEllipse = length(normalized);

        float innerDist = 1.0 - (radius / max(radii.x, radii.y));
        float outerDist = 1.0 + (radius / max(radii.x, radii.y));

        if (distFromEllipse >= innerDist && distFromEllipse <= outerDist) {
            imageStore(canvas, pixelCoords, color);
        }
        // } else if (tool == 2) {
        // At the origin - mark as filled
        // if (center == pixelCoords) {
        //     vec4 fillColor = color;
        //     fillColor.a = 1.0; // Mark as filled
        //     imageStore(canvas, pixelCoords, fillColor);
        // } else {
        //     vec4 targetColor = imageLoad(canvas, center);
        //     vec4 currentColor = imageLoad(canvas, pixelCoords);

        //     // Check if any neighbor is filled (alpha == 1)
        //     vec4 north = imageLoad(canvas, pixelCoords + ivec2(0, 1));
        //     vec4 south = imageLoad(canvas, pixelCoords + ivec2(0, -1));
        //     vec4 east = imageLoad(canvas, pixelCoords + ivec2(1, 0));
        //     vec4 west = imageLoad(canvas, pixelCoords + ivec2(-1, 0));

        //     bool neighborFilled = (north.a == 1.0) || (south.a == 1.0) ||
        //             (east.a == 1.0) || (west.a == 1.0);

        //     if (neighborFilled && colorDistance(currentColor.rgb, targetColor.rgb) < 0.9) {
        //         vec4 fillColor = color;
        //         fillColor.a = 1.0;
        //         imageStore(canvas, pixelCoords, fillColor);
        //     }
        // }
    }
}
