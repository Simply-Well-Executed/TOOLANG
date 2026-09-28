/**
 * VERTEX GFTC wrap — Oracle GraalVM 25 LTS.
 *
 * License target: GraalVM Free Terms and Conditions (GFTC) Including License
 * for Early Adopter Versions. Production and commercial use allowed. Do not
 * redistribute for a fee under GFTC.
 *
 * Exclusive kernel language: Tcl (vertex.tcl). This host is Java 17 bytecode
 * ready for `native-image` on Oracle GraalVM 25. No TypeScript, JavaScript,
 * PHP, Ruby, or Go in the wrap.
 *
 * 70-point lattice (N^{-4}..N^4, ο→πʹ, 0–CM) in IEEE-754 binary64.
 * ArtMoneyTable: 32 HT × 8 ICQ + 4 OEP. HCL CPU cut-through (no OpenGL here).
 * Hexa is the fabric. Limb/valid from disk LUT — no h%4 at runtime.
 * Quad = 2 limbs / 16 threads, octo = 3 / 24, hexa = 4 / 32.
 */
public final class VertexGftc {
  private static final double PI = 3.141592653589793;
  private static final double TWO_PI_9 = 2.0 * PI / 9.0;
  private static final double TWO_PI_24 = 2.0 * PI / 24.0;
  private static final double TWO_PI_37 = 2.0 * PI / 37.0;
  public static final int POWER_N = 9;
  public static final int ANGLE_N = 24;
  public static final int ORDINAL_N = 37;
  public static final int VERTEX_N = POWER_N + ANGLE_N + ORDINAL_N;
  public static final int HT_N = 32;
  public static final int ICQ_N = 8;
  public static final int OEP_N = 4;
  public static final int ROLE_N = 8;
  public static final int LIMB_N = 4;
  private static final byte[] HCL_LIMB = new byte[] {
    0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3
  };
  private static final byte[][] HCL_VALID = new byte[][] {
    {1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0},
    {1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0},
    {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
  };

  private VertexGftc() {}

  public static void vertex(double n, double sp, double sa, double so, double[] out) {
    double n1 = n;
    double n2 = n * n;
    double h = n2 * 0.48;
    double rp = n2 * 0.7;
    double ra = n2 * 0.92;
    double ro = n1 * 1.45;
    int i = 0;
    for (int k = 0; k < POWER_N; k++) {
      double a = sp + k * TWO_PI_9;
      out[i++] = rp * Math.cos(a);
      out[i++] = h;
      out[i++] = rp * Math.sin(a);
    }
    for (int k = 0; k < ANGLE_N; k++) {
      double a = sa + (k + 0.5) * TWO_PI_24;
      out[i++] = ra * Math.cos(a);
      out[i++] = 0.0;
      out[i++] = ra * Math.sin(a);
    }
    for (int k = 0; k < ORDINAL_N; k++) {
      double a = so + (k + 0.5) * TWO_PI_37;
      out[i++] = ro * Math.cos(a);
      out[i++] = -h;
      out[i++] = ro * Math.sin(a);
    }
  }

  public static int unionIndex(double roll) {
    double t = roll < 0 ? 0 : roll > 1 ? 1 : roll;
    return (int) Math.round(t * 23.0);
  }

  public static int cutThrough(
      double[] verts, int limbs, double unionRoll, float[] icq, float[] oep) {
    int vote = unionIndex(unionRoll);
    java.util.Arrays.fill(icq, 0f);
    java.util.Arrays.fill(oep, 0f);
    int n = verts.length / 3;
    if (n < 1) n = 1;
    double acc = 0;
    int w = 0;
    int pi = limbs <= 2 ? 0 : limbs == 3 ? 1 : 2;
    for (int h = 0; h < HT_N; h++) {
      int role = h / LIMB_N;
      int limb = HCL_LIMB[h];
      int vi = (h % n) * 3;
      int axis = h % 3;
      float payload = (float) verts[vi + axis];
      int valid = HCL_VALID[pi][h];
      int o = h * ICQ_N * 4;
      icq[o] = payload;
      icq[o + 1] = vote;
      icq[o + 2] = valid;
      icq[o + 3] = role;
      for (int q = 1; q < ICQ_N; q++) {
        int p = o + q * 4;
        icq[p] = valid;
        icq[p + 1] = limb;
        icq[p + 2] = vote;
        icq[p + 3] = h;
      }
      if (valid == 1) {
        acc += vote;
        w += 1;
      }
      for (int p = 0; p < OEP_N; p++) {
        int oq = (h * OEP_N + p) * 4;
        if (valid == 1) {
          oep[oq] = payload;
          oep[oq + 1] = limb;
          oep[oq + 2] = 1;
          oep[oq + 3] = vote;
        }
      }
    }
    return w > 0 ? (int) Math.round(acc / w) : vote;
  }

  public static void main(String[] args) {
    double n = args.length > 0 ? Double.parseDouble(args[0]) : 1.618033988749895;
    double sp = args.length > 1 ? Double.parseDouble(args[1]) : 0.0;
    double sa = args.length > 2 ? Double.parseDouble(args[2]) : 0.0;
    double so = args.length > 3 ? Double.parseDouble(args[3]) : 0.0;
    int limbs = args.length > 4 ? Integer.parseInt(args[4]) : LIMB_N;
    if (limbs < 2) limbs = 2;
    if (limbs > 4) limbs = 4;
    double[] out = new double[VERTEX_N * 3];
    vertex(n, sp, sa, so, out);
    float[] icq = new float[HT_N * ICQ_N * 4];
    float[] oep = new float[HT_N * OEP_N * 4];
    int union = cutThrough(out, limbs, 0.0, icq, oep);
    String prec = limbs == 2 ? "quad" : limbs == 3 ? "octo" : "hexa";
    System.out.println("VERTEX GFTC  Oracle GraalVM 25  Tcl kernel wrap");
    System.out.println(
        "70-pt double  HCL ArtMoneyTable 32x"
            + ICQ_N
            + " ICQ / 32x"
            + OEP_N
            + " OEP  "
            + prec
            + " limbs="
            + limbs
            + " union="
            + union);
    for (int i = 0; i < VERTEX_N; i++) {
      int o = i * 3;
      System.out.printf("%d  %.6f  %.6f  %.6f%n", i, out[o], out[o + 1], out[o + 2]);
    }
  }
}
