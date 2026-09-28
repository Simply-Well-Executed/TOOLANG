/* vertex_see2.S — packed-double path (SSE2 pd). SEE2 label as requested. */
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_see2
	.type	vertex_see2, @function
vertex_see2:
	sub	rsp, 96
	cvtss2sd xmm0, xmm0
	cvtss2sd xmm1, xmm1
	cvtss2sd xmm2, xmm2
	cvtss2sd xmm3, xmm3
	movsd	QWORD PTR [rsp], xmm0
	movsd	QWORD PTR [rsp+8], xmm1
	movsd	QWORD PTR [rsp+16], xmm2
	movsd	QWORD PTR [rsp+24], xmm3
	movapd	xmm4, xmm0
	mulpd	xmm4, xmm0
	movapd	xmm5, xmm4
	mulsd	xmm5, xmm0
	movsd	QWORD PTR [rsp+32], xmm0
	movsd	QWORD PTR [rsp+40], xmm4
	movsd	QWORD PTR [rsp+48], xmm5
	mulsd	xmm4, QWORD PTR [rip+k_hfac]
	movsd	QWORD PTR [rsp+56], xmm4
	xorpd	xmm7, xmm7
	subsd	xmm7, xmm4
	movsd	QWORD PTR [rsp+64], xmm7
	xor	eax, eax
.Lloop:
	cmp	eax, 3
	jae	.La
	movsd	xmm0, QWORD PTR [rsp+48]
	movsd	xmm1, QWORD PTR [rsp+56]
	movsd	xmm2, QWORD PTR [rsp+8]
	xorpd	xmm3, xmm3
	jmp	.Lg
.La:
	cmp	eax, 6
	jae	.Lo
	movsd	xmm0, QWORD PTR [rsp+40]
	xorpd	xmm1, xmm1
	movsd	xmm2, QWORD PTR [rsp+16]
	movsd	xmm3, QWORD PTR [rip+k_pi3]
	jmp	.Lg
.Lo:
	movsd	xmm0, QWORD PTR [rsp+32]
	movsd	xmm1, QWORD PTR [rsp+64]
	movsd	xmm2, QWORD PTR [rsp+24]
	xorpd	xmm3, xmm3
.Lg:
	mov	ecx, eax
	cmp	ecx, 3
	jb	.Lm
	sub	ecx, 3
	cmp	ecx, 3
	jb	.Lm
	sub	ecx, 3
.Lm:
	cvtsi2sd xmm4, ecx
	mulsd	xmm4, QWORD PTR [rip+k_twopi3]
	addsd	xmm4, xmm3
	addsd	xmm4, xmm2
	movapd	xmm5, xmm4
	mulsd	xmm5, xmm4
	movapd	xmm6, xmm5
	mulsd	xmm6, xmm4
	movapd	xmm7, xmm5
	mulsd	xmm7, xmm5
	mulsd	xmm5, QWORD PTR [rip+k_c1]
	mulsd	xmm7, QWORD PTR [rip+k_c2]
	movsd	xmm3, QWORD PTR [rip+k_one]
	addsd	xmm3, xmm5
	addsd	xmm3, xmm7
	mulsd	xmm6, QWORD PTR [rip+k_s1]
	movapd	xmm2, xmm4
	addsd	xmm2, xmm6
	mulsd	xmm3, xmm0
	mulsd	xmm2, xmm0
	cvtsd2ss xmm3, xmm3
	cvtsd2ss xmm1, xmm1
	cvtsd2ss xmm2, xmm2
	mov	ecx, eax
	imul	ecx, ecx, 12
	movss	DWORD PTR [rdi+rcx], xmm3
	movss	DWORD PTR [rdi+rcx+4], xmm1
	movss	DWORD PTR [rdi+rcx+8], xmm2
	inc	eax
	cmp	eax, 9
	jb	.Lloop
	add	rsp, 96
	ret
	.size	vertex_see2, .-vertex_see2
	.section .rodata
	.p2align 4
k_hfac:		.double 0.52
k_pi3:		.double 1.0471975511965976
k_twopi3:	.double 2.0943951023931953
k_one:		.double 1.0
k_c1:		.double -0.5
k_c2:		.double 0.041666666666666664
k_s1:		.double -0.16666666666666666
