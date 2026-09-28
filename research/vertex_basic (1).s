/* vertex_basic.S — lightest scalar x86-64. x87 only. No SIMD.
 * void vertex_basic(float n, float sp, float sa, float so, float *out);
 */
	.intel_syntax noprefix
	.text
	.p2align 4
	.globl	vertex_basic
	.type	vertex_basic, @function
vertex_basic:
	push	rbx
	sub	rsp, 80
	movss	DWORD PTR [rsp], xmm0
	movss	DWORD PTR [rsp+4], xmm1
	movss	DWORD PTR [rsp+8], xmm2
	movss	DWORD PTR [rsp+12], xmm3
	fld	DWORD PTR [rsp]
	fld	st(0)
	fmul	st(0), st(1)
	fld	st(0)
	fmul	st(0), st(2)
	fstp	DWORD PTR [rsp+24]
	fst	DWORD PTR [rsp+20]
	fld	DWORD PTR [rip+k_hfac]
	fmulp	st(1), st(0)
	fst	DWORD PTR [rsp+32]
	fchs
	fstp	DWORD PTR [rsp+36]
	fstp	DWORD PTR [rsp+16]
	fstp	st(0)
	xor	ebx, ebx
.Lloop:
	mov	eax, ebx
	xor	edx, edx
	mov	ecx, 3
	div	ecx
	cmp	eax, 0
	je	.Lpow
	cmp	eax, 1
	je	.Lang
	fld	DWORD PTR [rsp+16]
	fld	DWORD PTR [rsp+36]
	fld	DWORD PTR [rsp+12]
	fldz
	jmp	.Lgo
.Lpow:
	fld	DWORD PTR [rsp+24]
	fld	DWORD PTR [rsp+32]
	fld	DWORD PTR [rsp+4]
	fldz
	jmp	.Lgo
.Lang:
	fld	DWORD PTR [rsp+20]
	fldz
	fld	DWORD PTR [rsp+8]
	fld	DWORD PTR [rip+k_pi3]
.Lgo:
	mov	eax, edx
	fld	DWORD PTR [rip+k_twopi3]
	push	rdx
	fild	QWORD PTR [rsp]
	pop	rdx
	fmulp	st(1), st(0)
	faddp	st(1), st(0)
	faddp	st(1), st(0)
	fsincos
	fld	st(3)
	fmulp	st(1), st(0)
	fxch	st(1)
	fld	st(3)
	fmulp	st(1), st(0)
	mov	eax, ebx
	imul	eax, eax, 12
	fxch	st(1)
	fstp	DWORD PTR [rdi+rax]
	fxch	st(1)
	fstp	DWORD PTR [rdi+rax+4]
	fstp	DWORD PTR [rdi+rax+8]
	fstp	st(0)
	inc	ebx
	cmp	ebx, 9
	jb	.Lloop
	add	rsp, 80
	pop	rbx
	ret
	.size	vertex_basic, .-vertex_basic
	.section .rodata
	.p2align 2
k_hfac:		.float 0.52
k_pi3:		.float 1.0471975511965976
k_twopi3:	.float 2.0943951023931953
