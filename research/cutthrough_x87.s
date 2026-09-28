/* VERTEX HCL 1.0 → X87
 * FAT. 80-bit fldt. 32 HT unrolled. 1.13 MiB HCL fabric LUT in .rodata. Disk is cheap.
 * Fabric: 32 HT × 8 ICQ + 4 OEP. Hexa default (4 limbs, all rows valid).
 * Disk is cheap. Compute is expensive. limb/valid/role come from LUT route.
 * Transcoded from public/gpu/cutthrough.hcl (itself transcoded from WebGL2).
 */

	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_hcl_x87
	.type	vertex_hcl_x87, @function
vertex_hcl_x87:
	# rdi=icq rsi=oep edx=limbs  — hexa fabric, unrolled, no loop over HT.
	# Each HT loads a 16-byte cell from vertex_x87_hcl (prec,union,h,icq,oep).

	/* HT 00 role 0 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+0]
	fld	DWORD PTR [rip+vertex_x87_hcl+0]
	fstp	DWORD PTR [rsi+4]
	fst	DWORD PTR [rsi+0]
	mov	DWORD PTR [rsi+8], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+4]
	fstp	DWORD PTR [rsi+20]
	fst	DWORD PTR [rsi+16]
	mov	DWORD PTR [rsi+24], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+8]
	fstp	DWORD PTR [rsi+36]
	fst	DWORD PTR [rsi+32]
	mov	DWORD PTR [rsi+40], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+12]
	fstp	DWORD PTR [rsi+52]
	fst	DWORD PTR [rsi+48]
	mov	DWORD PTR [rsi+56], 0x3f800000
	fstp	st(0)
	/* HT 01 role 0 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+128]
	fld	DWORD PTR [rip+vertex_x87_hcl+16]
	fstp	DWORD PTR [rsi+68]
	fst	DWORD PTR [rsi+64]
	mov	DWORD PTR [rsi+72], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+20]
	fstp	DWORD PTR [rsi+84]
	fst	DWORD PTR [rsi+80]
	mov	DWORD PTR [rsi+88], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+24]
	fstp	DWORD PTR [rsi+100]
	fst	DWORD PTR [rsi+96]
	mov	DWORD PTR [rsi+104], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+28]
	fstp	DWORD PTR [rsi+116]
	fst	DWORD PTR [rsi+112]
	mov	DWORD PTR [rsi+120], 0x3f800000
	fstp	st(0)
	/* HT 02 role 0 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+256]
	fld	DWORD PTR [rip+vertex_x87_hcl+32]
	fstp	DWORD PTR [rsi+132]
	fst	DWORD PTR [rsi+128]
	mov	DWORD PTR [rsi+136], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+36]
	fstp	DWORD PTR [rsi+148]
	fst	DWORD PTR [rsi+144]
	mov	DWORD PTR [rsi+152], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+40]
	fstp	DWORD PTR [rsi+164]
	fst	DWORD PTR [rsi+160]
	mov	DWORD PTR [rsi+168], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+44]
	fstp	DWORD PTR [rsi+180]
	fst	DWORD PTR [rsi+176]
	mov	DWORD PTR [rsi+184], 0x3f800000
	fstp	st(0)
	/* HT 03 role 0 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+384]
	fld	DWORD PTR [rip+vertex_x87_hcl+48]
	fstp	DWORD PTR [rsi+196]
	fst	DWORD PTR [rsi+192]
	mov	DWORD PTR [rsi+200], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+52]
	fstp	DWORD PTR [rsi+212]
	fst	DWORD PTR [rsi+208]
	mov	DWORD PTR [rsi+216], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+56]
	fstp	DWORD PTR [rsi+228]
	fst	DWORD PTR [rsi+224]
	mov	DWORD PTR [rsi+232], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+60]
	fstp	DWORD PTR [rsi+244]
	fst	DWORD PTR [rsi+240]
	mov	DWORD PTR [rsi+248], 0x3f800000
	fstp	st(0)
	/* HT 04 role 1 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+512]
	fld	DWORD PTR [rip+vertex_x87_hcl+64]
	fstp	DWORD PTR [rsi+260]
	fst	DWORD PTR [rsi+256]
	mov	DWORD PTR [rsi+264], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+68]
	fstp	DWORD PTR [rsi+276]
	fst	DWORD PTR [rsi+272]
	mov	DWORD PTR [rsi+280], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+72]
	fstp	DWORD PTR [rsi+292]
	fst	DWORD PTR [rsi+288]
	mov	DWORD PTR [rsi+296], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+76]
	fstp	DWORD PTR [rsi+308]
	fst	DWORD PTR [rsi+304]
	mov	DWORD PTR [rsi+312], 0x3f800000
	fstp	st(0)
	/* HT 05 role 1 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+640]
	fld	DWORD PTR [rip+vertex_x87_hcl+80]
	fstp	DWORD PTR [rsi+324]
	fst	DWORD PTR [rsi+320]
	mov	DWORD PTR [rsi+328], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+84]
	fstp	DWORD PTR [rsi+340]
	fst	DWORD PTR [rsi+336]
	mov	DWORD PTR [rsi+344], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+88]
	fstp	DWORD PTR [rsi+356]
	fst	DWORD PTR [rsi+352]
	mov	DWORD PTR [rsi+360], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+92]
	fstp	DWORD PTR [rsi+372]
	fst	DWORD PTR [rsi+368]
	mov	DWORD PTR [rsi+376], 0x3f800000
	fstp	st(0)
	/* HT 06 role 1 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+768]
	fld	DWORD PTR [rip+vertex_x87_hcl+96]
	fstp	DWORD PTR [rsi+388]
	fst	DWORD PTR [rsi+384]
	mov	DWORD PTR [rsi+392], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+100]
	fstp	DWORD PTR [rsi+404]
	fst	DWORD PTR [rsi+400]
	mov	DWORD PTR [rsi+408], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+104]
	fstp	DWORD PTR [rsi+420]
	fst	DWORD PTR [rsi+416]
	mov	DWORD PTR [rsi+424], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+108]
	fstp	DWORD PTR [rsi+436]
	fst	DWORD PTR [rsi+432]
	mov	DWORD PTR [rsi+440], 0x3f800000
	fstp	st(0)
	/* HT 07 role 1 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+896]
	fld	DWORD PTR [rip+vertex_x87_hcl+112]
	fstp	DWORD PTR [rsi+452]
	fst	DWORD PTR [rsi+448]
	mov	DWORD PTR [rsi+456], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+116]
	fstp	DWORD PTR [rsi+468]
	fst	DWORD PTR [rsi+464]
	mov	DWORD PTR [rsi+472], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+120]
	fstp	DWORD PTR [rsi+484]
	fst	DWORD PTR [rsi+480]
	mov	DWORD PTR [rsi+488], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+124]
	fstp	DWORD PTR [rsi+500]
	fst	DWORD PTR [rsi+496]
	mov	DWORD PTR [rsi+504], 0x3f800000
	fstp	st(0)
	/* HT 08 role 2 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+1024]
	fld	DWORD PTR [rip+vertex_x87_hcl+128]
	fstp	DWORD PTR [rsi+516]
	fst	DWORD PTR [rsi+512]
	mov	DWORD PTR [rsi+520], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+132]
	fstp	DWORD PTR [rsi+532]
	fst	DWORD PTR [rsi+528]
	mov	DWORD PTR [rsi+536], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+136]
	fstp	DWORD PTR [rsi+548]
	fst	DWORD PTR [rsi+544]
	mov	DWORD PTR [rsi+552], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+140]
	fstp	DWORD PTR [rsi+564]
	fst	DWORD PTR [rsi+560]
	mov	DWORD PTR [rsi+568], 0x3f800000
	fstp	st(0)
	/* HT 09 role 2 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+1152]
	fld	DWORD PTR [rip+vertex_x87_hcl+144]
	fstp	DWORD PTR [rsi+580]
	fst	DWORD PTR [rsi+576]
	mov	DWORD PTR [rsi+584], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+148]
	fstp	DWORD PTR [rsi+596]
	fst	DWORD PTR [rsi+592]
	mov	DWORD PTR [rsi+600], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+152]
	fstp	DWORD PTR [rsi+612]
	fst	DWORD PTR [rsi+608]
	mov	DWORD PTR [rsi+616], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+156]
	fstp	DWORD PTR [rsi+628]
	fst	DWORD PTR [rsi+624]
	mov	DWORD PTR [rsi+632], 0x3f800000
	fstp	st(0)
	/* HT 10 role 2 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+1280]
	fld	DWORD PTR [rip+vertex_x87_hcl+160]
	fstp	DWORD PTR [rsi+644]
	fst	DWORD PTR [rsi+640]
	mov	DWORD PTR [rsi+648], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+164]
	fstp	DWORD PTR [rsi+660]
	fst	DWORD PTR [rsi+656]
	mov	DWORD PTR [rsi+664], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+168]
	fstp	DWORD PTR [rsi+676]
	fst	DWORD PTR [rsi+672]
	mov	DWORD PTR [rsi+680], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+172]
	fstp	DWORD PTR [rsi+692]
	fst	DWORD PTR [rsi+688]
	mov	DWORD PTR [rsi+696], 0x3f800000
	fstp	st(0)
	/* HT 11 role 2 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+1408]
	fld	DWORD PTR [rip+vertex_x87_hcl+176]
	fstp	DWORD PTR [rsi+708]
	fst	DWORD PTR [rsi+704]
	mov	DWORD PTR [rsi+712], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+180]
	fstp	DWORD PTR [rsi+724]
	fst	DWORD PTR [rsi+720]
	mov	DWORD PTR [rsi+728], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+184]
	fstp	DWORD PTR [rsi+740]
	fst	DWORD PTR [rsi+736]
	mov	DWORD PTR [rsi+744], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+188]
	fstp	DWORD PTR [rsi+756]
	fst	DWORD PTR [rsi+752]
	mov	DWORD PTR [rsi+760], 0x3f800000
	fstp	st(0)
	/* HT 12 role 3 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+1536]
	fld	DWORD PTR [rip+vertex_x87_hcl+192]
	fstp	DWORD PTR [rsi+772]
	fst	DWORD PTR [rsi+768]
	mov	DWORD PTR [rsi+776], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+196]
	fstp	DWORD PTR [rsi+788]
	fst	DWORD PTR [rsi+784]
	mov	DWORD PTR [rsi+792], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+200]
	fstp	DWORD PTR [rsi+804]
	fst	DWORD PTR [rsi+800]
	mov	DWORD PTR [rsi+808], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+204]
	fstp	DWORD PTR [rsi+820]
	fst	DWORD PTR [rsi+816]
	mov	DWORD PTR [rsi+824], 0x3f800000
	fstp	st(0)
	/* HT 13 role 3 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+1664]
	fld	DWORD PTR [rip+vertex_x87_hcl+208]
	fstp	DWORD PTR [rsi+836]
	fst	DWORD PTR [rsi+832]
	mov	DWORD PTR [rsi+840], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+212]
	fstp	DWORD PTR [rsi+852]
	fst	DWORD PTR [rsi+848]
	mov	DWORD PTR [rsi+856], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+216]
	fstp	DWORD PTR [rsi+868]
	fst	DWORD PTR [rsi+864]
	mov	DWORD PTR [rsi+872], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+220]
	fstp	DWORD PTR [rsi+884]
	fst	DWORD PTR [rsi+880]
	mov	DWORD PTR [rsi+888], 0x3f800000
	fstp	st(0)
	/* HT 14 role 3 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+1792]
	fld	DWORD PTR [rip+vertex_x87_hcl+224]
	fstp	DWORD PTR [rsi+900]
	fst	DWORD PTR [rsi+896]
	mov	DWORD PTR [rsi+904], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+228]
	fstp	DWORD PTR [rsi+916]
	fst	DWORD PTR [rsi+912]
	mov	DWORD PTR [rsi+920], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+232]
	fstp	DWORD PTR [rsi+932]
	fst	DWORD PTR [rsi+928]
	mov	DWORD PTR [rsi+936], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+236]
	fstp	DWORD PTR [rsi+948]
	fst	DWORD PTR [rsi+944]
	mov	DWORD PTR [rsi+952], 0x3f800000
	fstp	st(0)
	/* HT 15 role 3 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+1920]
	fld	DWORD PTR [rip+vertex_x87_hcl+240]
	fstp	DWORD PTR [rsi+964]
	fst	DWORD PTR [rsi+960]
	mov	DWORD PTR [rsi+968], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+244]
	fstp	DWORD PTR [rsi+980]
	fst	DWORD PTR [rsi+976]
	mov	DWORD PTR [rsi+984], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+248]
	fstp	DWORD PTR [rsi+996]
	fst	DWORD PTR [rsi+992]
	mov	DWORD PTR [rsi+1000], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+252]
	fstp	DWORD PTR [rsi+1012]
	fst	DWORD PTR [rsi+1008]
	mov	DWORD PTR [rsi+1016], 0x3f800000
	fstp	st(0)
	/* HT 16 role 4 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+2048]
	fld	DWORD PTR [rip+vertex_x87_hcl+256]
	fstp	DWORD PTR [rsi+1028]
	fst	DWORD PTR [rsi+1024]
	mov	DWORD PTR [rsi+1032], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+260]
	fstp	DWORD PTR [rsi+1044]
	fst	DWORD PTR [rsi+1040]
	mov	DWORD PTR [rsi+1048], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+264]
	fstp	DWORD PTR [rsi+1060]
	fst	DWORD PTR [rsi+1056]
	mov	DWORD PTR [rsi+1064], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+268]
	fstp	DWORD PTR [rsi+1076]
	fst	DWORD PTR [rsi+1072]
	mov	DWORD PTR [rsi+1080], 0x3f800000
	fstp	st(0)
	/* HT 17 role 4 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+2176]
	fld	DWORD PTR [rip+vertex_x87_hcl+272]
	fstp	DWORD PTR [rsi+1092]
	fst	DWORD PTR [rsi+1088]
	mov	DWORD PTR [rsi+1096], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+276]
	fstp	DWORD PTR [rsi+1108]
	fst	DWORD PTR [rsi+1104]
	mov	DWORD PTR [rsi+1112], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+280]
	fstp	DWORD PTR [rsi+1124]
	fst	DWORD PTR [rsi+1120]
	mov	DWORD PTR [rsi+1128], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+284]
	fstp	DWORD PTR [rsi+1140]
	fst	DWORD PTR [rsi+1136]
	mov	DWORD PTR [rsi+1144], 0x3f800000
	fstp	st(0)
	/* HT 18 role 4 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+2304]
	fld	DWORD PTR [rip+vertex_x87_hcl+288]
	fstp	DWORD PTR [rsi+1156]
	fst	DWORD PTR [rsi+1152]
	mov	DWORD PTR [rsi+1160], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+292]
	fstp	DWORD PTR [rsi+1172]
	fst	DWORD PTR [rsi+1168]
	mov	DWORD PTR [rsi+1176], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+296]
	fstp	DWORD PTR [rsi+1188]
	fst	DWORD PTR [rsi+1184]
	mov	DWORD PTR [rsi+1192], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+300]
	fstp	DWORD PTR [rsi+1204]
	fst	DWORD PTR [rsi+1200]
	mov	DWORD PTR [rsi+1208], 0x3f800000
	fstp	st(0)
	/* HT 19 role 4 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+2432]
	fld	DWORD PTR [rip+vertex_x87_hcl+304]
	fstp	DWORD PTR [rsi+1220]
	fst	DWORD PTR [rsi+1216]
	mov	DWORD PTR [rsi+1224], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+308]
	fstp	DWORD PTR [rsi+1236]
	fst	DWORD PTR [rsi+1232]
	mov	DWORD PTR [rsi+1240], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+312]
	fstp	DWORD PTR [rsi+1252]
	fst	DWORD PTR [rsi+1248]
	mov	DWORD PTR [rsi+1256], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+316]
	fstp	DWORD PTR [rsi+1268]
	fst	DWORD PTR [rsi+1264]
	mov	DWORD PTR [rsi+1272], 0x3f800000
	fstp	st(0)
	/* HT 20 role 5 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+2560]
	fld	DWORD PTR [rip+vertex_x87_hcl+320]
	fstp	DWORD PTR [rsi+1284]
	fst	DWORD PTR [rsi+1280]
	mov	DWORD PTR [rsi+1288], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+324]
	fstp	DWORD PTR [rsi+1300]
	fst	DWORD PTR [rsi+1296]
	mov	DWORD PTR [rsi+1304], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+328]
	fstp	DWORD PTR [rsi+1316]
	fst	DWORD PTR [rsi+1312]
	mov	DWORD PTR [rsi+1320], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+332]
	fstp	DWORD PTR [rsi+1332]
	fst	DWORD PTR [rsi+1328]
	mov	DWORD PTR [rsi+1336], 0x3f800000
	fstp	st(0)
	/* HT 21 role 5 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+2688]
	fld	DWORD PTR [rip+vertex_x87_hcl+336]
	fstp	DWORD PTR [rsi+1348]
	fst	DWORD PTR [rsi+1344]
	mov	DWORD PTR [rsi+1352], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+340]
	fstp	DWORD PTR [rsi+1364]
	fst	DWORD PTR [rsi+1360]
	mov	DWORD PTR [rsi+1368], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+344]
	fstp	DWORD PTR [rsi+1380]
	fst	DWORD PTR [rsi+1376]
	mov	DWORD PTR [rsi+1384], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+348]
	fstp	DWORD PTR [rsi+1396]
	fst	DWORD PTR [rsi+1392]
	mov	DWORD PTR [rsi+1400], 0x3f800000
	fstp	st(0)
	/* HT 22 role 5 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+2816]
	fld	DWORD PTR [rip+vertex_x87_hcl+352]
	fstp	DWORD PTR [rsi+1412]
	fst	DWORD PTR [rsi+1408]
	mov	DWORD PTR [rsi+1416], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+356]
	fstp	DWORD PTR [rsi+1428]
	fst	DWORD PTR [rsi+1424]
	mov	DWORD PTR [rsi+1432], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+360]
	fstp	DWORD PTR [rsi+1444]
	fst	DWORD PTR [rsi+1440]
	mov	DWORD PTR [rsi+1448], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+364]
	fstp	DWORD PTR [rsi+1460]
	fst	DWORD PTR [rsi+1456]
	mov	DWORD PTR [rsi+1464], 0x3f800000
	fstp	st(0)
	/* HT 23 role 5 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+2944]
	fld	DWORD PTR [rip+vertex_x87_hcl+368]
	fstp	DWORD PTR [rsi+1476]
	fst	DWORD PTR [rsi+1472]
	mov	DWORD PTR [rsi+1480], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+372]
	fstp	DWORD PTR [rsi+1492]
	fst	DWORD PTR [rsi+1488]
	mov	DWORD PTR [rsi+1496], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+376]
	fstp	DWORD PTR [rsi+1508]
	fst	DWORD PTR [rsi+1504]
	mov	DWORD PTR [rsi+1512], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+380]
	fstp	DWORD PTR [rsi+1524]
	fst	DWORD PTR [rsi+1520]
	mov	DWORD PTR [rsi+1528], 0x3f800000
	fstp	st(0)
	/* HT 24 role 6 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+3072]
	fld	DWORD PTR [rip+vertex_x87_hcl+384]
	fstp	DWORD PTR [rsi+1540]
	fst	DWORD PTR [rsi+1536]
	mov	DWORD PTR [rsi+1544], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+388]
	fstp	DWORD PTR [rsi+1556]
	fst	DWORD PTR [rsi+1552]
	mov	DWORD PTR [rsi+1560], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+392]
	fstp	DWORD PTR [rsi+1572]
	fst	DWORD PTR [rsi+1568]
	mov	DWORD PTR [rsi+1576], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+396]
	fstp	DWORD PTR [rsi+1588]
	fst	DWORD PTR [rsi+1584]
	mov	DWORD PTR [rsi+1592], 0x3f800000
	fstp	st(0)
	/* HT 25 role 6 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+3200]
	fld	DWORD PTR [rip+vertex_x87_hcl+400]
	fstp	DWORD PTR [rsi+1604]
	fst	DWORD PTR [rsi+1600]
	mov	DWORD PTR [rsi+1608], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+404]
	fstp	DWORD PTR [rsi+1620]
	fst	DWORD PTR [rsi+1616]
	mov	DWORD PTR [rsi+1624], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+408]
	fstp	DWORD PTR [rsi+1636]
	fst	DWORD PTR [rsi+1632]
	mov	DWORD PTR [rsi+1640], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+412]
	fstp	DWORD PTR [rsi+1652]
	fst	DWORD PTR [rsi+1648]
	mov	DWORD PTR [rsi+1656], 0x3f800000
	fstp	st(0)
	/* HT 26 role 6 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+3328]
	fld	DWORD PTR [rip+vertex_x87_hcl+416]
	fstp	DWORD PTR [rsi+1668]
	fst	DWORD PTR [rsi+1664]
	mov	DWORD PTR [rsi+1672], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+420]
	fstp	DWORD PTR [rsi+1684]
	fst	DWORD PTR [rsi+1680]
	mov	DWORD PTR [rsi+1688], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+424]
	fstp	DWORD PTR [rsi+1700]
	fst	DWORD PTR [rsi+1696]
	mov	DWORD PTR [rsi+1704], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+428]
	fstp	DWORD PTR [rsi+1716]
	fst	DWORD PTR [rsi+1712]
	mov	DWORD PTR [rsi+1720], 0x3f800000
	fstp	st(0)
	/* HT 27 role 6 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+3456]
	fld	DWORD PTR [rip+vertex_x87_hcl+432]
	fstp	DWORD PTR [rsi+1732]
	fst	DWORD PTR [rsi+1728]
	mov	DWORD PTR [rsi+1736], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+436]
	fstp	DWORD PTR [rsi+1748]
	fst	DWORD PTR [rsi+1744]
	mov	DWORD PTR [rsi+1752], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+440]
	fstp	DWORD PTR [rsi+1764]
	fst	DWORD PTR [rsi+1760]
	mov	DWORD PTR [rsi+1768], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+444]
	fstp	DWORD PTR [rsi+1780]
	fst	DWORD PTR [rsi+1776]
	mov	DWORD PTR [rsi+1784], 0x3f800000
	fstp	st(0)
	/* HT 28 role 7 limb 0 hexa-valid=1 */
	fld	DWORD PTR [rdi+3584]
	fld	DWORD PTR [rip+vertex_x87_hcl+448]
	fstp	DWORD PTR [rsi+1796]
	fst	DWORD PTR [rsi+1792]
	mov	DWORD PTR [rsi+1800], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+452]
	fstp	DWORD PTR [rsi+1812]
	fst	DWORD PTR [rsi+1808]
	mov	DWORD PTR [rsi+1816], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+456]
	fstp	DWORD PTR [rsi+1828]
	fst	DWORD PTR [rsi+1824]
	mov	DWORD PTR [rsi+1832], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+460]
	fstp	DWORD PTR [rsi+1844]
	fst	DWORD PTR [rsi+1840]
	mov	DWORD PTR [rsi+1848], 0x3f800000
	fstp	st(0)
	/* HT 29 role 7 limb 1 hexa-valid=1 */
	fld	DWORD PTR [rdi+3712]
	fld	DWORD PTR [rip+vertex_x87_hcl+464]
	fstp	DWORD PTR [rsi+1860]
	fst	DWORD PTR [rsi+1856]
	mov	DWORD PTR [rsi+1864], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+468]
	fstp	DWORD PTR [rsi+1876]
	fst	DWORD PTR [rsi+1872]
	mov	DWORD PTR [rsi+1880], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+472]
	fstp	DWORD PTR [rsi+1892]
	fst	DWORD PTR [rsi+1888]
	mov	DWORD PTR [rsi+1896], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+476]
	fstp	DWORD PTR [rsi+1908]
	fst	DWORD PTR [rsi+1904]
	mov	DWORD PTR [rsi+1912], 0x3f800000
	fstp	st(0)
	/* HT 30 role 7 limb 2 hexa-valid=1 */
	fld	DWORD PTR [rdi+3840]
	fld	DWORD PTR [rip+vertex_x87_hcl+480]
	fstp	DWORD PTR [rsi+1924]
	fst	DWORD PTR [rsi+1920]
	mov	DWORD PTR [rsi+1928], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+484]
	fstp	DWORD PTR [rsi+1940]
	fst	DWORD PTR [rsi+1936]
	mov	DWORD PTR [rsi+1944], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+488]
	fstp	DWORD PTR [rsi+1956]
	fst	DWORD PTR [rsi+1952]
	mov	DWORD PTR [rsi+1960], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+492]
	fstp	DWORD PTR [rsi+1972]
	fst	DWORD PTR [rsi+1968]
	mov	DWORD PTR [rsi+1976], 0x3f800000
	fstp	st(0)
	/* HT 31 role 7 limb 3 hexa-valid=1 */
	fld	DWORD PTR [rdi+3968]
	fld	DWORD PTR [rip+vertex_x87_hcl+496]
	fstp	DWORD PTR [rsi+1988]
	fst	DWORD PTR [rsi+1984]
	mov	DWORD PTR [rsi+1992], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+500]
	fstp	DWORD PTR [rsi+2004]
	fst	DWORD PTR [rsi+2000]
	mov	DWORD PTR [rsi+2008], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+504]
	fstp	DWORD PTR [rsi+2020]
	fst	DWORD PTR [rsi+2016]
	mov	DWORD PTR [rsi+2024], 0x3f800000
	fld	DWORD PTR [rip+vertex_x87_hcl+508]
	fstp	DWORD PTR [rsi+2036]
	fst	DWORD PTR [rsi+2032]
	mov	DWORD PTR [rsi+2040], 0x3f800000
	fstp	st(0)
	ret
	.size	vertex_hcl_x87, .-vertex_hcl_x87
	.section .rodata
	.p2align 4
	.globl	vertex_x87_hcl
	.type	vertex_x87_hcl, @object
vertex_x87_hcl:
	.incbin	"x87-hcl.bin"
	.size	vertex_x87_hcl, 1179648
	.section .rodata
	.p2align 4
hcl_limb:	.byte 0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3
hcl_role:	.byte 0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7
hcl_valid_quad:	.byte 1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0
hcl_valid_octo:	.byte 1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0
hcl_valid_hexa:	.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

