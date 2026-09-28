/* vertex_sse2.S — SSE2: movdqa, punpckldq, cvtdq2ps. */
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_sse2
	.type	vertex_sse2, @function
vertex_sse2:
	sub	rsp, 64
	movdqa	xmm4, XMMWORD PTR [rip+k_idx]
	cvtdq2ps xmm4, xmm4
	mulps	xmm4, XMMWORD PTR [rip+k_twopi3v]
	movss	DWORD PTR [rsp], xmm0
	shufps	xmm0, xmm0, 0
	movaps	xmm5, xmm0
	mulps	xmm5, xmm0
	movaps	xmm6, xmm5
	mulps	xmm6, xmm0
	movss	DWORD PTR [rsp+16], xmm1
	movss	DWORD PTR [rsp+20], xmm2
	movss	DWORD PTR [rsp+24], xmm3
	xor	eax, eax
.Lloop:
	cmp	eax, 3
	jae	.La
	movaps	xmm0, xmm6
	movaps	xmm1, xmm5
	mulss	xmm1, DWORD PTR [rip+k_hfac]
	movss	xmm2, DWORD PTR [rsp+16]
	xorps	xmm3, xmm3
	jmp	.Lg
.La:
	cmp	eax, 6
	jae	.Lo
	movaps	xmm0, xmm5
	xorps	xmm1, xmm1
	movss	xmm2, DWORD PTR [rsp+20]
	movss	xmm3, DWORD PTR [rip+k_pi3]
	jmp	.Lg
.Lo:
	movss	xmm0, DWORD PTR [rsp]
	movaps	xmm1, xmm5
	mulss	xmm1, DWORD PTR [rip+k_hfac]
	xorps	xmm7, xmm7
	subss	xmm7, xmm1
	movaps	xmm1, xmm7
	movss	xmm2, DWORD PTR [rsp+24]
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
	add	rsp, 64
	ret
	.size	vertex_sse2, .-vertex_sse2
	.section .rodata
	.p2align 4
k_idx:		.long 0,1,2,3
k_twopi3v:	.float 2.0943951023931953, 2.0943951023931953, 2.0943951023931953, 2.0943951023931953
k_hfac:		.float 0.52
k_pi3:		.float 1.0471975511965976
k_twopi3:	.float 2.0943951023931953
k_one:		.float 1.0
k_c1:		.float -0.5
k_s1:		.float -0.1666666716
