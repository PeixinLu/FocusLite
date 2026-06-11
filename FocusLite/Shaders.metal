#include <metal_stdlib>
using namespace metal;

// Sun-glasses fade:
//   topSolid pt  (cap: 10% h)  → solid black
//   topFade pt   (cap: 40% h)  → 1.0 → midTopAlpha
//   middle       (auto-height) → midTopAlpha → midBottomAlpha
//   bottomFade pt (cap: 10% h) → midBottomAlpha → 0.0
// Corner curvature follows rounded rect; middle zone never collapses.

[[stitchable]] half4 sunglassesFade(
    float2 position,
    half4 color,
    float4 boundingRect,
    float cornerRadius,
    float topSolid,
    float topFade,
    float midTopAlpha,
    float midBottomAlpha,
    float bottomFade,
    float cornerInfluence
) {
    float x = position.x;
    float y = position.y;
    float w = boundingRect.z;
    float h = boundingRect.w;
    float r = cornerRadius;

    // ---- top / bottom boundary Y at this x ----
    float rawTopY = 0.0;
    if (x < r) {
        float dx = r - x;
        rawTopY = r - sqrt(max(0.0f, r * r - dx * dx));
    } else if (x > w - r) {
        float dx = x - (w - r);
        rawTopY = r - sqrt(max(0.0f, r * r - dx * dx));
    }

    float rawBottomY = h;
    if (x < r) {
        float dx = r - x;
        rawBottomY = h - (r - sqrt(max(0.0f, r * r - dx * dx)));
    } else if (x > w - r) {
        float dx = x - (w - r);
        rawBottomY = h - (r - sqrt(max(0.0f, r * r - dx * dx)));
    }

    // blend between straight edge and curved corner
    float ci = clamp(cornerInfluence, 0.0f, 1.0f);
    float topY    = mix(0.0f, rawTopY, ci);
    float bottomY = mix(h,     rawBottomY, ci);

    // ---- apply percentage caps ----
    float cappedTopSolid   = min(topSolid,   h * 0.10f);
    float cappedTopFade    = min(topFade,    h * 0.10f);
    float cappedBottomFade = min(bottomFade, h * 0.10f);

    // ---- zone boundaries ----
    float solidEnd   = topY + cappedTopSolid;
    float topFadeEnd = solidEnd + cappedTopFade;
    float botFadeStart = bottomY - cappedBottomFade;

    // ---- prevent middle-zone collapse (corner intrusion guard) ----
    if (topFadeEnd >= botFadeStart) {
        float midPt = (topFadeEnd + botFadeStart) * 0.5f;
        topFadeEnd  = midPt - 0.5f;
        botFadeStart = midPt + 0.5f;
    }

    // ---- opacity ----
    float alpha;
    if (y <= solidEnd) {
        alpha = 1.0;
    } else if (y <= topFadeEnd) {
        float t = (y - solidEnd) / max(topFadeEnd - solidEnd, 1.0f);
        alpha = mix(1.0f, midTopAlpha, clamp(t, 0.0f, 1.0f));
    } else if (y <= botFadeStart) {
        float midH = max(botFadeStart - topFadeEnd, 1.0f);
        float t = (y - topFadeEnd) / midH;
        alpha = mix(midTopAlpha, midBottomAlpha, clamp(t, 0.0f, 1.0f));
    } else if (y < bottomY) {
        float t = (y - botFadeStart) / max(bottomY - botFadeStart, 1.0f);
        alpha = mix(midBottomAlpha, 0.0f, clamp(t, 0.0f, 1.0f));
    } else {
        alpha = 0.0;
    }

    return half4(0.0, 0.0, 0.0, color.a * half(alpha));
}
