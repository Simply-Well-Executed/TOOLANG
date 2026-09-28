/* vertex_sse4.S — SSE4.1: dpps, roundps, blendps. */
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_sse4
	.type	vertex_sse4, @function
vertex_sse4:
	sub	rsp, 48
	movss	DWORD PTR [rsp], xmm0
	movss	DWORD PTR [rsp+4], xmm1
	movss	DWORD PTR [rsp+8], xmm2
	movss	DWORD PTR [rsp+12], xmm3
	shufps	xmm0, xmm0, 0
	movaps	xmm4, xmm0
	dpps	xmm4, xmm0, 0xF1
	movaps	xmm5, xmm0
	mulss	xmm5, DWORD PTR [rsp]
	mulss	xmm5, DWORD PTR [rsp]
	xor	eax, eax
.Lloop:
	cmp	eax, 3
	jae	.La
	movaps	xmm0, xmm5
	mulss	xmm0, DWORD PTR [rsp]
	movaps	xmm1, xmm4
	mulss	xmm1, DWORD PTR [rip+k_hfac]
	roundps	xmm1, xmm1, 0
	movss	xmm2, DWORD PTR [rsp+4]
	xorps	xmm3, xmm3
	jmp	.Lg
.La:
	cmp	eax, 6
	jae	.Lo
	movaps	xmm0, xmm4
	xorps	xmm1, xmm1
	movss	xmm2, DWORD PTR [rsp+8]
	movss	xmm3, DWORD PTR [rip+k_pi3]
	jmp	.Lg
.Lo:
	movss	xmm0, DWORD PTR [rsp]
	movaps	xmm1, xmm4
	mulss	xmm1, DWORD PTR [rip+k_hfac]
	xorps	xmm7, xmm7
	subss	xmm7, xmm1
	blendps	xmm1, xmm7, 1
	movss	xmm2, DWORD PTR [rsp+12]
	xorps	xmm3, xmm3
.Lg:
	mov	ecx, eax
	cmp	ecx, 3
	jb	.Lm
	sub	ecx, 3
	cmp	ecx, 3
	jb	.Lm
	sub	ecx, 3
.Lm:
	cvtsi2ss xmm7, ecx
	mulss	xmm7, DWORD PTR [rip+k_twopi3]
	addss	xmm7, xmm3
	addss	xmm7, xmm2
	roundps xmm6, xmm7, 0
	movaps	xmm2, xmm7
	mulss	xmm2, xmm7
	movaps	xmm3, xmm2
	mulss	xmm3, xmm7
	mulss	xmm2, DWORD PTR [rip+k_c1]
	mulss	xmm3, DWORD PTR [rip+k_s1]
	addss	xmm2, DWORD PTR [rip+k_one]
	addss	xmm3, xmm7
	mulss	xmm2, xmm0
	mulss	xmm3, xmm0
	mov	ecx, eax
	imul	ecx, ecx, 12
	movss	DWORD PTR [rdi+rcx], xmm2
	movss	DWORD PTR [rdi+rcx+4], xmm1
	movss	DWORD PTR [rdi+rcx+8], xmm3
	inc	eax
	cmp	eax, 9
	jb	.Lloop
	add	rsp, 48
	ret
	.size	vertex_sse4, .-vertex_sse4
	.section .rodata
	.p2align 4
k_hfac:		.float 0.52
k_pi3:		.float 1.0471975511965976
k_twopi3:	.float 2.0943951023931953
k_one:		.float 1.0
k_c1:		.float -0.5
k_s1:		.float -0.1666666716
