/* VERTEX HCL 1.0 → SDL2 software wrap. No OpenGL.
 * Hexa fabric. Static LUT. CreateSoftwareRenderer stays the raster.
 */
#include <string.h>
#define HCL_HT 32
#define HCL_ICQ 8
#define HCL_OEP 4
static const unsigned char HCL_LIMB[32] = {0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3};
static const unsigned char HCL_VALID[3][32] = {
  {1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0},
  {1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
};
static int hcl_cutthrough(const float *icq, float *oep, int limbs, float uunion) {
  int pi = limbs <= 2 ? 0 : limbs == 3 ? 1 : 2;
  int h, p, w = 0;
  double acc = 0;
  memset(oep, 0, (size_t)HCL_HT * HCL_OEP * 4 * sizeof(float));
  for (h = 0; h < HCL_HT; h++) {
    int valid = HCL_VALID[pi][h];
    int limb = HCL_LIMB[h];
    float payload = icq[h * HCL_ICQ * 4];
    if (valid) { acc += icq[h * HCL_ICQ * 4 + 1]; w++; }
    for (p = 0; p < HCL_OEP; p++) {
      int oq = (h * HCL_OEP + p) * 4;
      if (valid) {
        oep[oq] = payload;
        oep[oq + 1] = (float)limb;
        oep[oq + 2] = 1.f;
        oep[oq + 3] = uunion;
      }
    }
  }
  return w ? (int)(acc / w + 0.5) : (int)uunion;
}
