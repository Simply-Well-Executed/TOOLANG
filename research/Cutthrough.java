/** VERTEX HCL 1.0 → GraalVM GFTC. CPU table, no OpenGL.
 * Hexa fabric. Lookups, not divides. Oracle GraalVM 25 LTS, GFTC.
 */
public final class Cutthrough {
  public static final int HT = 32, ICQ = 8, OEP = 4, LIMB = 4;
  public static final byte[] LIMB_LUT = new byte[] {0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3};
  public static final byte[] VALID_QUAD = new byte[] {1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0};
  public static final byte[] VALID_OCTO = new byte[] {1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0};
  public static final byte[] VALID_HEXA = new byte[] {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
  private Cutthrough() {}
  public static int exec(float[] icq, float[] oep, int limbs, float union) {
    byte[] valid = limbs <= 2 ? VALID_QUAD : limbs == 3 ? VALID_OCTO : VALID_HEXA;
    java.util.Arrays.fill(oep, 0f);
    int w = 0; double acc = 0;
    for (int h = 0; h < HT; h++) {
      int v = valid[h];
      float payload = icq[h * ICQ * 4];
      if (v == 1) { acc += icq[h * ICQ * 4 + 1]; w++; }
      for (int p = 0; p < OEP; p++) {
        int oq = (h * OEP + p) * 4;
        if (v == 1) {
          oep[oq] = payload;
          oep[oq + 1] = LIMB_LUT[h];
          oep[oq + 2] = 1f;
          oep[oq + 3] = union;
        }
      }
    }
    return w > 0 ? (int) Math.round(acc / w) : (int) union;
  }
}
