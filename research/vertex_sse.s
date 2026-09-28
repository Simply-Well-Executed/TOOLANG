/* vertex_sse.S — SSE packed-single. xmm0–xmm7 only. No SSE2+. */
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_sse
	.type	vertex_sse, @function
vertex_sse:
	sub	rsp, 80
	movss	DWORD PTR [rsp], xmm0
	movss	DWORD PTR [rsp+4], xmm1
	movss	DWORD PTR [rsp+8], xmm2
	movss	DWORD PTR [rsp+12], xmm3
	movaps	xmm4, xmm0
	mulss	xmm4, xmm0
	movaps	xmm5, xmm4
	mulss	xmm5, xmm0
	movss	DWORD PTR [rsp+16], xmm0
	movss	DWORD PTR [rsp+20], xmm4
	movss	DWORD PTR [rsp+24], xmm5
	mulss	xmm4, DWORD PTR [rip+k_hfac]
	movss	DWORD PTR [rsp+32], xmm4
	xorps	xmm7, xmm7
	subss	xmm7, xmm4
	movss	DWORD PTR [rsp+36], xmm7
	xor	eax, eax
.Lloop:
	cmp	eax, 3
	jae	.La
	movss	xmm0, DWORD PTR [rsp+24]
	movss	xmm1, DWORD PTR [rsp+32]
	movss	xmm2, DWORD PTR [rsp+4]
	xorps	xmm3, xmm3
	jmp	.Lg
.La:
	cmp	eax, 6
	jae	.Lo
	movss	xmm0, DWORD PTR [rsp+20]
	xorps	xmm1, xmm1
	movss	xmm2, DWORD PTR [rsp+8]
	movss	xmm3, DWORD PTR [rip+k_pi3]
	jmp	.Lg
.Lo:
	movss	xmm0, DWORD PTR [rsp+16]
	movss	xmm1, DWORD PTR [rsp+36]
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
	cvtsi2ss xmm4, ecx
	mulss	xmm4, DWORD PTR [rip+k_twopi3]
	addss	xmm4, xmm3
	addss	xmm4, xmm2
	movaps	xmm5, xmm4
	mulss	xmm5, xmm4
	movaps	xmm6, xmm5
	mulss	xmm6, xmm4
	movaps	xmm7, xmm5
	mulss	xmm7, xmm5
	mulss	xmm5, DWORD PTR [rip+k_c1]
	mulss	xmm7, DWORD PTR [rip+k_c2]
	movss	xmm3, DWORD PTR [rip+k_one]
	addss	xmm3, xmm5
	addss	xmm3, xmm7
	mulss	xmm6, DWORD PTR [rip+k_s1]
	movaps	xmm2, xmm4
	addss	xmm2, xmm6
	mulss	xmm3, xmm0
	mulss	xmm2, xmm0
	mov	ecx, eax
	imul	ecx, ecx, 12
	movss	DWORD PTR [rdi+rcx], xmm3
	movss	DWORD PTR [rdi+rcx+4], xmm1
	movss	DWORD PTR [rdi+rcx+8], xmm2
	inc	eax
	cmp	eax, 9
	jb	.Lloop
	add	rsp, 80
	ret
	.size	vertex_sse, .-vertex_sse
	.section .rodata
	.p2align 4
k_hfac:		.float 0.52
k_pi3:		.float 1.0471975511965976
k_twopi3:	.float 2.0943951023931953
k_one:		.float 1.0
k_c1:		.float -0.5
k_c2:		.float 0.0416666679
k_s1:		.float -0.1666666716
