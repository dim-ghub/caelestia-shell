#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fadeMargin;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 uv = qt_TexCoord0;
    float fade = 1.0;

    // Top fade
    if (uv.y < fadeMargin) {
        fade = smoothstep(0.0, fadeMargin, uv.y);
    }
    // Bottom fade
    else if (uv.y > 1.0 - fadeMargin) {
        fade = smoothstep(1.0, 1.0 - fadeMargin, uv.y);
    }

    fragColor = texture(source, uv) * fade * qt_Opacity;
}
