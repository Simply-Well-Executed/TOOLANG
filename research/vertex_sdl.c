/* VERTEX — SDL2 software renderer, single thread, no OpenGL.
 * cc vertex_sdl.c -lSDL2 -lm -o vertex-sdl
 * Exclusive kernel language remains Tcl. This is the display wrap.
 * 70-point lattice in IEEE-754 binary64.
 * ArtMoneyTable: 32 HT × 8 ICQ + 4 OEP, HCL CPU cut-through (no GL).
 * Hexa fabric. Static LUT, no h%4. Quad=2 limbs, octo=3, hexa=4.
 */
#include <SDL.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define W 1280
#define H 800
#define POWER_N 9
#define ANGLE_N 24
#define ORDINAL_N 37
#define NVERT (POWER_N + ANGLE_N + ORDINAL_N)
#define HT_N 32
#define ICQ_N 8
#define OEP_N 4
#define LIMB_N 4
static const unsigned char HCL_LIMB[32] = {
  0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3
};
static const unsigned char HCL_VALID[3][32] = {
  {1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0},
  {1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0},
  {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
};
#define PI 3.141592653589793

static void vertex(double n, double sp, double sa, double so, double *out) {
  double n1 = n, n2 = n * n, h = n2 * 0.48;
  double rp = n2 * 0.7, ra = n2 * 0.92, ro = n1 * 1.45;
  double twoPi9 = 2.0 * PI / 9.0, twoPi24 = 2.0 * PI / 24.0, twoPi37 = 2.0 * PI / 37.0;
  int k, i = 0;
  for (k = 0; k < POWER_N; k++) {
    double a = sp + k * twoPi9;
    out[i++] = rp * cos(a);
    out[i++] = h;
    out[i++] = rp * sin(a);
  }
  for (k = 0; k < ANGLE_N; k++) {
    double a = sa + (k + 0.5) * twoPi24;
    out[i++] = ra * cos(a);
    out[i++] = 0.0;
    out[i++] = ra * sin(a);
  }
  for (k = 0; k < ORDINAL_N; k++) {
    double a = so + (k + 0.5) * twoPi37;
    out[i++] = ro * cos(a);
    out[i++] = -h;
    out[i++] = ro * sin(a);
  }
}

static int union_index(double roll) {
  if (roll < 0) roll = 0;
  if (roll > 1) roll = 1;
  return (int)floor(roll * 23.0 + 0.5);
}

static int cut_through(const double *verts, int nvert, int limbs, double union_roll,
                       float *icq, float *oep) {
  int vote = union_index(union_roll);
  int h, q, p, w = 0;
  int pi = limbs <= 2 ? 0 : limbs == 3 ? 1 : 2;
  double acc = 0;
  memset(icq, 0, (size_t)HT_N * ICQ_N * 4 * sizeof(float));
  memset(oep, 0, (size_t)HT_N * OEP_N * 4 * sizeof(float));
  if (nvert < 1) nvert = 1;
  for (h = 0; h < HT_N; h++) {
    int role = h / LIMB_N;
    int limb = HCL_LIMB[h];
    int vi = (h % nvert) * 3;
    int axis = h % 3;
    float payload = (float)verts[vi + axis];
    int valid = HCL_VALID[pi][h];
    int o = h * ICQ_N * 4;
    icq[o] = payload;
    icq[o + 1] = (float)vote;
    icq[o + 2] = (float)valid;
    icq[o + 3] = (float)role;
    for (q = 1; q < ICQ_N; q++) {
      int pp = o + q * 4;
      icq[pp] = (float)valid;
      icq[pp + 1] = (float)limb;
      icq[pp + 2] = (float)vote;
      icq[pp + 3] = (float)h;
    }
    if (valid) {
      acc += vote;
      w += 1;
    }
    for (p = 0; p < OEP_N; p++) {
      int oq = (h * OEP_N + p) * 4;
      if (valid) {
        oep[oq] = payload;
        oep[oq + 1] = (float)limb;
        oep[oq + 2] = 1.f;
        oep[oq + 3] = (float)vote;
      }
    }
  }
  return w ? (int)floor(acc / w + 0.5) : vote;
}

static void rot_xyz(float *x, float *y, float *z, float ax, float ay, float az) {
  float cx = cosf(ax), sx = sinf(ax), cy = cosf(ay), sy = sinf(ay), cz = cosf(az),
        sz = sinf(az);
  float X = *x, Y = *y, Z = *z;
  float x1 = X, y1 = Y * cx - Z * sx, z1 = Y * sx + Z * cx;
  float x2 = x1 * cy + z1 * sy, y2 = y1, z2 = -x1 * sy + z1 * cy;
  *x = x2 * cz - y2 * sz;
  *y = x2 * sz + y2 * cz;
  *z = z2;
}

static int project(float x, float y, float z, float yaw, float pitch, float dist,
                   int *sx, int *sy, float *depth) {
  float cy = cosf(-yaw), syv = sinf(-yaw), cp = cosf(-pitch), sp = sinf(-pitch);
  float x1 = x * cy + z * syv, z1 = -x * syv + z * cy;
  float y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp + dist;
  if (z2 < 0.4f) return 0;
  float f = 720.0f / z2;
  *sx = (int)(W * 0.5f + x1 * f);
  *sy = (int)(H * 0.5f - y2 * f);
  *depth = z2;
  return 1;
}

static void draw_cycle(SDL_Renderer *ren, const double *pts, int start, int count,
                       float yaw, float pitch, float dist, Uint8 r, Uint8 g, Uint8 b) {
  int k;
  SDL_SetRenderDrawColor(ren, r, g, b, 255);
  for (k = 0; k < count; k++) {
    int a = start + k, b = start + ((k + 1) % count);
    float ax = (float)pts[a * 3], ay = (float)pts[a * 3 + 1], az = (float)pts[a * 3 + 2];
    float bx = (float)pts[b * 3], by = (float)pts[b * 3 + 1], bz = (float)pts[b * 3 + 2];
    rot_xyz(&ax, &ay, &az, 0.0f, 0.0f, 0.0f);
    int sx1, sy1, sx2, sy2;
    float d1, d2;
    if (!project(ax, ay, az, yaw, pitch, dist, &sx1, &sy1, &d1)) continue;
    if (!project(bx, by, bz, yaw, pitch, dist, &sx2, &sy2, &d2)) continue;
    SDL_RenderDrawLine(ren, sx1, sy1, sx2, sy2);
  }
}

int main(int argc, char **argv) {
  int limbs = LIMB_N;
  if (argc > 1) {
    limbs = atoi(argv[1]);
    if (limbs < 2) limbs = 2;
    if (limbs > 4) limbs = 4;
  }
  if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
  SDL_Window *win = SDL_CreateWindow("VERTEX SDL", SDL_WINDOWPOS_CENTERED,
                                     SDL_WINDOWPOS_CENTERED, W, H, 0);
  SDL_Surface *surf = SDL_GetWindowSurface(win);
  SDL_Renderer *ren = SDL_CreateSoftwareRenderer(surf);
  if (!win || !surf || !ren) return 1;

  double pts[NVERT * 3];
  float icq[HT_N * ICQ_N * 4];
  float oep[HT_N * OEP_N * 4];
  double n = 1.618033988749895, sp = 0, sa = 0, so = 0, omega = 0;
  float yaw = 0.7f, pitch = 0.38f, dist = 22.0f;
  int running = 1;
  Uint32 last = SDL_GetTicks();

  while (running) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
      if (e.type == SDL_QUIT) running = 0;
    }
    Uint32 now = SDL_GetTicks();
    float dt = (now - last) / 1000.0f;
    if (dt > 0.1f) dt = 0.1f;
    last = now;
    sp += 0.20 * dt;
    sa += 0.33 * dt;
    so += 0.55 * dt;
    omega += 0.07 * dt;
    if (omega > 1.0) omega -= 1.0;
    vertex(n, sp, sa, so, pts);
    cut_through(pts, NVERT, limbs, omega, icq, oep);

    SDL_SetRenderDrawColor(ren, 9, 9, 11, 255);
    SDL_RenderClear(ren);

    draw_cycle(ren, pts, 0, POWER_N, yaw, pitch, dist, 216, 196, 160);
    draw_cycle(ren, pts, POWER_N, ANGLE_N, yaw, pitch, dist, 158, 196, 208);
    draw_cycle(ren, pts, POWER_N + ANGLE_N, ORDINAL_N, yaw, pitch, dist, 200, 196, 188);

    {
      int i;
      for (i = 0; i < NVERT; i++) {
        float x = (float)pts[i * 3], y = (float)pts[i * 3 + 1], z = (float)pts[i * 3 + 2];
        int sx, sy;
        float d;
        if (!project(x, y, z, yaw, pitch, dist, &sx, &sy, &d)) continue;
        SDL_Rect rc = {sx - 3, sy - 3, 6, 6};
        SDL_SetRenderDrawColor(ren, 236, 232, 223, 255);
        SDL_RenderFillRect(ren, &rc);
      }
    }
    SDL_RenderPresent(ren);
    SDL_UpdateWindowSurface(win);
    SDL_Delay(16);
  }
  SDL_DestroyRenderer(ren);
  SDL_DestroyWindow(win);
  SDL_Quit();
  return 0;
}
