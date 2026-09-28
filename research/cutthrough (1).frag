#version 300 es
/* VERTEX GPU driver — transcoded from HCL 1.0.
 * Source: Hardware Cut-through Language (public/gpu/cutthrough.hcl).
 * Hexa (LIMB=4) is the fabric width. Quad/octo cut through via uLimbs.
 * ICQ: 32 HT × 8 ingress queues (RGBA32F)
 * OEP: 32 HT × 4 outbound egress ports (RGBA32F FBO)
 * Disk LUTs on the CPU twin; this shader is the HA image of the same SWITCH.
 */
precision highp float;
uniform sampler2D uIcq;
uniform float uLimbs;
uniform float uUnion;
out vec4 oFrag;
void main() {
  int h = int(gl_FragCoord.y);
  int port = int(gl_FragCoord.x);
  int role = h / 4;
  int limb = h - role * 4;
  if (limb >= int(uLimbs + 0.5) || port >= 4) {
    oFrag = vec4(0.0);
    return;
  }
  vec4 cell = texelFetch(uIcq, ivec2(0, h), 0);
  float valid = 1.0;
  oFrag = vec4(cell.r, float(limb), valid, uUnion);
}
