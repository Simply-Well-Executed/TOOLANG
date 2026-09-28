/* VERTEX HCL 1.0 → BASIC
 * scalar x87. fmul/fld/fstp. No SIMD. Byte LUT, never idiv.
 * Fabric: 32 HT × 8 ICQ + 4 OEP. Hexa default (4 limbs, all rows valid).
 * Disk is cheap. Compute is expensive. limb/valid/role come from LUT route.
 * Transcoded from public/gpu/cutthrough.hcl (itself transcoded from WebGL2).
 */

	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_hcl_basic
	.type	vertex_hcl_basic, @function
vertex_hcl_basic:
	# rdi=icq rsi=oep edx=limbs xmm0=union
	push	rbx
	push	r12
	mov	r12d, edx
	cmp	r12d, 2
	jge	1f
	mov	r12d, 2
1:	xor	ebx, ebx
.Lht:
	movzx	eax, BYTE PTR [rip+hcl_limb+rbx]
	mov	ecx, r12d
	sub	ecx, 2
	cmp	ecx, 2
	jbe	2f
	mov	ecx, 2
2:	imul	ecx, ecx, 32
	movzx	edx, BYTE PTR [rip+hcl_valid_quad+rcx+rbx]
	mov	rax, rbx
	imul	rax, rax, 128
	fld	DWORD PTR [rdi+rax]
	xor	ecx, ecx
.Lport:
	mov	r8, rbx
	imul	r8, r8, 4
	add	r8, rcx
	shl	r8, 4
	test	edx, edx
	jz	.Lhold
	fst	DWORD PTR [rsi+r8]
	movzx	r9d, BYTE PTR [rip+hcl_limb+rbx]
	cvtsi2ss xmm1, r9d
	movss	DWORD PTR [rsi+r8+4], xmm1
	mov	DWORD PTR [rsi+r8+8], 0x3f800000
	movss	DWORD PTR [rsi+r8+12], xmm0
	jmp	.Lnext
.Lhold:
	mov	DWORD PTR [rsi+r8], 0
	mov	DWORD PTR [rsi+r8+4], 0
	mov	DWORD PTR [rsi+r8+8], 0
	mov	DWORD PTR [rsi+r8+12], 0
.Lnext:
	inc	ecx
	cmp	ecx, 4
	jb	.Lport
	fstp	st(0)
	inc	ebx
	cmp	ebx, 32
	jb	.Lht
	pop	r12
	pop	rbx
	ret
	.size	vertex_hcl_basic, .-vertex_hcl_basic
	.section .rodata
	.p2align 4
hcl_limb:	.byte 0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3,0,1,2,3
hcl_role:	.byte 0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,6,6,6,6,7,7,7,7
hcl_valid_quad:	.byte 1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0,1,1,0,0
hcl_valid_octo:	.byte 1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1,1,1,0
hcl_valid_hexa:	.byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
