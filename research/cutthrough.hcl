; VERTEX HCL 1.0 — Hardware Cut-through Language
; Transcoded BACK from WebGL2 GLSL (ArtMoneyTable fragment shader).
; Do not wait for unused higher limbs. Hexa occupies the whole fabric.
; Disk is cheap. Compute is expensive. Every limb/valid/role is a LUT.

FABRIC ArtMoneyTable
  HT     32
  ICQ    8
  OEP    4
  LIMB   4
  ROLE   8
  CELL   payload limb valid union

PREC
  quad   2          ; 16 threads, pair = double-double
  octo   3          ; 24 threads, tri  = triple-double
  hexa   4          ; 32 threads, quad = quad-double — DEFAULT, full fabric

LUT route
  limb[h]           := baked (h & 3)
  role[h]           := baked (h >> 2)
  valid[quad][h]    := baked (limb[h] < 2)
  valid[octo][h]    := baked (limb[h] < 3)
  valid[hexa][h]    := baked 1           ; all 32 HT live

SWITCH cutthrough
  FOR h IN 0 .. 31
    WHEN LUT.valid[uLimbs][h]
      CUT  ICQ[h][0].payload -> OEP[h][0 .. 3]
      TAG  uUnion
    ELSE
      HOLD 0

UNION mean(valid tags)
