/* VERTEX HCL 1.0 → SSE3
 * haddps reduces the union vote across valid HTs.
 * Fabric: 32 HT × 8 ICQ + 4 OEP. Hexa default (4 limbs, all rows valid).
 * Disk is cheap. Compute is expensive. limb/valid/role come from LUT route.
 * Transcoded from public/gpu/cutthrough.hcl (itself transcoded from WebGL2).
 */

	.intel_syntax noprefix
	.text
	.globl	vertex_hcl_sse3
vertex_hcl_sse3:
	xorps	xmm4, xmm4
	xor	eax, eax
.Lht:
	movzx	edx, BYTE PTR [rip+hcl_valid_hexa+rax]
	cvtsi2ss xmm2, edx
	mov	ecx, eax
	imul	ecx, ecx, 128
	movss	xmm0, DWORD PTR [rdi+rcx]
	mulss	xmm0, xmm2
	unpcklps xmm0, xmm2
	haddps	xmm0, xmm0
	addss	xmm4, xmm0
	mov	ecx, eax
	shl	ecx, 6
	movss	DWORD PTR [rsi+rcx], xmm0
	inc	eax
	cmp	eax, 32
	jb	.Lht
	ret
	.section .rodata
	.p2align 4
hcl_limb:	.byte 0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3
hcl_role:	.byte 0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7
hcl_valid_quad:	.byte 1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0
hcl_valid_octo:	.byte 1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0
hcl_valid_hexa:	.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
