/* vertex_x87.S — 80-bit long double split into hexa (4 × binary64).
 * 70-point lattice (N^{-4}..N^4, ο→πʹ, 0–CM). Software raster gathers all four limbs.
 * 1 MiB sine LUT + 1.13 MiB HCL fat fabric LUT + baked hexa raster.
 * Disk is cheap. Compute is expensive. Generated from isa/kernels.c + HCL.
 */
	.file	"kernels.c"
	.text
	.type	wrap_pi, @function
wrap_pi:
.LFB0:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$32, %rsp
	movss	%xmm0, -20(%rbp)
	flds	.LC0(%rip)
	fstps	-4(%rbp)
	flds	.LC1(%rip)
	fstps	-8(%rbp)
	flds	-20(%rbp)
	fadds	-4(%rbp)
	fstps	-24(%rbp)
	movss	-8(%rbp), %xmm0
	movaps	%xmm0, %xmm1
	movss	-24(%rbp), %xmm0
	call	fmodf@PLT
	movd	%xmm0, %eax
	movl	%eax, -20(%rbp)
	flds	-20(%rbp)
	fldz
	fcomip	%st(1), %st
	fstp	%st(0)
	jbe	.L2
	flds	-20(%rbp)
	fadds	-8(%rbp)
	fstps	-20(%rbp)
.L2:
	flds	-20(%rbp)
	fsubs	-4(%rbp)
	fstps	-24(%rbp)
	movss	-24(%rbp), %xmm0
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE0:
	.size	wrap_pi, .-wrap_pi
	.type	wrap_pi_d, @function
wrap_pi_d:
.LFB1:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$32, %rsp
	movsd	%xmm0, -24(%rbp)
	fldl	.LC4(%rip)
	fstpl	-8(%rbp)
	fldl	.LC5(%rip)
	fstpl	-16(%rbp)
	fldl	-24(%rbp)
	faddl	-8(%rbp)
	fstpl	-32(%rbp)
	movsd	-16(%rbp), %xmm0
	movapd	%xmm0, %xmm1
	movsd	-32(%rbp), %xmm0
	call	fmod@PLT
	movq	%xmm0, %rax
	movq	%rax, -24(%rbp)
	fldl	-24(%rbp)
	fldz
	fcomip	%st(1), %st
	fstp	%st(0)
	jbe	.L7
	fldl	-24(%rbp)
	faddl	-16(%rbp)
	fstpl	-24(%rbp)
.L7:
	fldl	-24(%rbp)
	fsubl	-8(%rbp)
	fstpl	-32(%rbp)
	movq	-32(%rbp), %rax
	movq	%rax, %xmm0
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE1:
	.size	wrap_pi_d, .-wrap_pi_d
	.type	wrap4, @function
wrap4:
.LFB2:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	pushq	%rbx
	subq	$40, %rsp
	.cfi_offset 3, -24
	movq	%rdi, -40(%rbp)
	movl	$0, -20(%rbp)
	jmp	.L12
.L13:
	movl	-20(%rbp), %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-40(%rbp), %rax
	addq	%rdx, %rax
	movl	(%rax), %eax
	movl	-20(%rbp), %edx
	movslq	%edx, %rdx
	leaq	0(,%rdx,4), %rcx
	movq	-40(%rbp), %rdx
	leaq	(%rcx,%rdx), %rbx
	movd	%eax, %xmm0
	call	wrap_pi
	movd	%xmm0, %eax
	movl	%eax, (%rbx)
	addl	$1, -20(%rbp)
.L12:
	cmpl	$3, -20(%rbp)
	jle	.L13
	nop
	nop
	movq	-8(%rbp), %rbx
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE2:
	.size	wrap4, .-wrap4
	.type	store9, @function
store9:
.LFB3:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movq	%rdi, -24(%rbp)
	movq	%rsi, -32(%rbp)
	movq	%rdx, -40(%rbp)
	movq	%rcx, -48(%rbp)
	movl	$0, -4(%rbp)
	jmp	.L15
.L16:
	movl	-4(%rbp), %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-32(%rbp), %rax
	leaq	(%rdx,%rax), %rcx
	movl	-4(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-24(%rbp), %rax
	addq	%rdx, %rax
	flds	(%rcx)
	fstps	(%rax)
	movl	-4(%rbp), %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-40(%rbp), %rax
	leaq	(%rdx,%rax), %rcx
	movl	-4(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	cltq
	addq	$1, %rax
	leaq	0(,%rax,4), %rdx
	movq	-24(%rbp), %rax
	addq	%rdx, %rax
	flds	(%rcx)
	fstps	(%rax)
	movl	-4(%rbp), %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-48(%rbp), %rax
	leaq	(%rdx,%rax), %rcx
	movl	-4(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	cltq
	addq	$2, %rax
	leaq	0(,%rax,4), %rdx
	movq	-24(%rbp), %rax
	addq	%rdx, %rax
	flds	(%rcx)
	fstps	(%rax)
	addl	$1, -4(%rbp)
.L15:
	cmpl	$8, -4(%rbp)
	jle	.L16
	nop
	nop
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE3:
	.size	store9, .-store9
	.type	radii, @function
radii:
.LFB4:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movss	%xmm0, -4(%rbp)
	movq	%rdi, -16(%rbp)
	movq	%rsi, -24(%rbp)
	movq	%rdx, -32(%rbp)
	movq	%rcx, -40(%rbp)
	movq	-16(%rbp), %rax
	flds	-4(%rbp)
	fstps	(%rax)
	flds	-4(%rbp)
	fmul	%st(0), %st
	movq	-24(%rbp), %rax
	fstps	(%rax)
	flds	-4(%rbp)
	fmul	%st(0), %st
	fmuls	-4(%rbp)
	movq	-32(%rbp), %rax
	fstps	(%rax)
	movq	-24(%rbp), %rax
	flds	(%rax)
	flds	.LC7(%rip)
	fmulp	%st, %st(1)
	movq	-40(%rbp), %rax
	fstps	(%rax)
	nop
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE4:
	.size	radii, .-radii
	.type	split80, @function
split80:
.LFB5:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movq	%rdi, -24(%rbp)
	fldt	16(%rbp)
	fstpl	-32(%rbp)
	fldl	-32(%rbp)
	movq	-24(%rbp), %rax
	fstpl	(%rax)
	movq	-24(%rbp), %rax
	fldl	(%rax)
	fldt	16(%rbp)
	fsubp	%st, %st(1)
	fstpt	-16(%rbp)
	movq	-24(%rbp), %rax
	addq	$8, %rax
	fldt	-16(%rbp)
	fstpl	-32(%rbp)
	fldl	-32(%rbp)
	fstpl	(%rax)
	movq	-24(%rbp), %rax
	addq	$8, %rax
	fldl	(%rax)
	fldt	-16(%rbp)
	fsubp	%st, %st(1)
	fstpt	-16(%rbp)
	movq	-24(%rbp), %rax
	addq	$16, %rax
	fldt	-16(%rbp)
	fstpl	-32(%rbp)
	fldl	-32(%rbp)
	fstpl	(%rax)
	movq	-24(%rbp), %rax
	addq	$16, %rax
	fldl	(%rax)
	fldt	-16(%rbp)
	fsubp	%st, %st(1)
	fstpt	-16(%rbp)
	movq	-24(%rbp), %rax
	addq	$24, %rax
	fldt	-16(%rbp)
	fstpl	-32(%rbp)
	fldl	-32(%rbp)
	fstpl	(%rax)
	nop
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE5:
	.size	split80, .-split80
	.type	store_hexa, @function
store_hexa:
.LFB6:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$16, %rsp
	movq	%rdi, -8(%rbp)
	movl	%esi, -12(%rbp)
	movl	-12(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	sall	$2, %eax
	cltq
	leaq	0(,%rax,8), %rdx
	movq	-8(%rbp), %rax
	addq	%rdx, %rax
	pushq	24(%rbp)
	pushq	16(%rbp)
	movq	%rax, %rdi
	call	split80
	addq	$16, %rsp
	movl	-12(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	sall	$2, %eax
	cltq
	addq	$4, %rax
	leaq	0(,%rax,8), %rdx
	movq	-8(%rbp), %rax
	addq	%rdx, %rax
	pushq	40(%rbp)
	pushq	32(%rbp)
	movq	%rax, %rdi
	call	split80
	addq	$16, %rsp
	movl	-12(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	sall	$2, %eax
	cltq
	addq	$8, %rax
	leaq	0(,%rax,8), %rdx
	movq	-8(%rbp), %rax
	addq	%rdx, %rax
	pushq	56(%rbp)
	pushq	48(%rbp)
	movq	%rax, %rdi
	call	split80
	addq	$16, %rsp
	nop
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE6:
	.size	store_hexa, .-store_hexa
	.type	gather4, @function
gather4:
.LFB7:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	movq	%rdi, -8(%rbp)
	movq	-8(%rbp), %rax
	fldl	(%rax)
	movq	-8(%rbp), %rax
	addq	$8, %rax
	fldl	(%rax)
	faddp	%st, %st(1)
	movq	-8(%rbp), %rax
	addq	$16, %rax
	fldl	(%rax)
	faddp	%st, %st(1)
	movq	-8(%rbp), %rax
	addq	$24, %rax
	fldl	(%rax)
	faddp	%st, %st(1)
	popq	%rbp
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE7:
	.size	gather4, .-gather4
	.globl	vertex_x87
	.type	vertex_x87, @function
vertex_x87:
.LFB8:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$336, %rsp
	movss	%xmm0, -292(%rbp)
	movss	%xmm1, -296(%rbp)
	movss	%xmm2, -300(%rbp)
	movss	%xmm3, -304(%rbp)
	movq	%rdi, -312(%rbp)
	flds	-292(%rbp)
	fstpt	-32(%rbp)
	fldt	-32(%rbp)
	fstpt	-48(%rbp)
	fldt	-32(%rbp)
	fmul	%st(0), %st
	fstpt	-64(%rbp)
	fldt	-64(%rbp)
	fldt	.LC8(%rip)
	fmulp	%st, %st(1)
	fstpt	-80(%rbp)
	fldt	-64(%rbp)
	fldt	.LC9(%rip)
	fmulp	%st, %st(1)
	fstpt	-96(%rbp)
	fldt	-48(%rbp)
	fldt	.LC10(%rip)
	fmulp	%st, %st(1)
	fstpt	-112(%rbp)
	fldt	-64(%rbp)
	fldt	.LC11(%rip)
	fmulp	%st, %st(1)
	fstpt	-128(%rbp)
	fldz
	fstpt	-144(%rbp)
	fldt	-128(%rbp)
	fchs
	fstpt	-336(%rbp)
	movq	-336(%rbp), %rax
	movl	-328(%rbp), %edx
	movq	%rax, -160(%rbp)
	movl	%edx, -152(%rbp)
	fldt	.LC13(%rip)
	fstpt	-176(%rbp)
	fldt	-176(%rbp)
	fldt	.LC14(%rip)
	fdivrp	%st, %st(1)
	fstpt	-192(%rbp)
	fldt	-176(%rbp)
	fldt	.LC15(%rip)
	fdivrp	%st, %st(1)
	fstpt	-208(%rbp)
	fldt	-176(%rbp)
	fldt	.LC16(%rip)
	fdivrp	%st, %st(1)
	fstpt	-224(%rbp)
	movl	$0, -4(%rbp)
	jmp	.L23
.L24:
	flds	-296(%rbp)
	fildl	-4(%rbp)
	fldt	-192(%rbp)
	fmulp	%st, %st(1)
	faddp	%st, %st(1)
	fstpt	-272(%rbp)
	pushq	-264(%rbp)
	pushq	-272(%rbp)
	call	sinl@PLT
	addq	$16, %rsp
	fldt	-80(%rbp)
	fmulp	%st, %st(1)
	fstpt	-336(%rbp)
	pushq	-264(%rbp)
	pushq	-272(%rbp)
	call	cosl@PLT
	addq	$16, %rsp
	fldt	-80(%rbp)
	fmulp	%st, %st(1)
	movl	-4(%rbp), %edx
	movq	-312(%rbp), %rax
	pushq	-328(%rbp)
	pushq	-336(%rbp)
	pushq	-120(%rbp)
	pushq	-128(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	movl	%edx, %esi
	movq	%rax, %rdi
	call	store_hexa
	addq	$48, %rsp
	addl	$1, -4(%rbp)
.L23:
	cmpl	$8, -4(%rbp)
	jle	.L24
	movl	$0, -8(%rbp)
	jmp	.L25
.L26:
	flds	-300(%rbp)
	fildl	-8(%rbp)
	fldt	.LC17(%rip)
	faddp	%st, %st(1)
	fldt	-208(%rbp)
	fmulp	%st, %st(1)
	faddp	%st, %st(1)
	fstpt	-256(%rbp)
	pushq	-248(%rbp)
	pushq	-256(%rbp)
	call	sinl@PLT
	addq	$16, %rsp
	fldt	-96(%rbp)
	fmulp	%st, %st(1)
	fstpt	-336(%rbp)
	pushq	-248(%rbp)
	pushq	-256(%rbp)
	call	cosl@PLT
	addq	$16, %rsp
	fldt	-96(%rbp)
	fmulp	%st, %st(1)
	movl	-8(%rbp), %eax
	leal	9(%rax), %edx
	movq	-312(%rbp), %rax
	pushq	-328(%rbp)
	pushq	-336(%rbp)
	pushq	-136(%rbp)
	pushq	-144(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	movl	%edx, %esi
	movq	%rax, %rdi
	call	store_hexa
	addq	$48, %rsp
	addl	$1, -8(%rbp)
.L25:
	cmpl	$23, -8(%rbp)
	jle	.L26
	movl	$0, -12(%rbp)
	jmp	.L27
.L28:
	flds	-304(%rbp)
	fildl	-12(%rbp)
	fldt	.LC17(%rip)
	faddp	%st, %st(1)
	fldt	-224(%rbp)
	fmulp	%st, %st(1)
	faddp	%st, %st(1)
	fstpt	-240(%rbp)
	pushq	-232(%rbp)
	pushq	-240(%rbp)
	call	sinl@PLT
	addq	$16, %rsp
	fldt	-112(%rbp)
	fmulp	%st, %st(1)
	fstpt	-336(%rbp)
	pushq	-232(%rbp)
	pushq	-240(%rbp)
	call	cosl@PLT
	addq	$16, %rsp
	fldt	-112(%rbp)
	fmulp	%st, %st(1)
	movl	-12(%rbp), %eax
	leal	33(%rax), %edx
	movq	-312(%rbp), %rax
	pushq	-328(%rbp)
	pushq	-336(%rbp)
	pushq	-152(%rbp)
	pushq	-160(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	movl	%edx, %esi
	movq	%rax, %rdi
	call	store_hexa
	addq	$48, %rsp
	addl	$1, -12(%rbp)
.L27:
	cmpl	$36, -12(%rbp)
	jle	.L28
	flds	vertex_x87_lut(%rip)
	fstps	-276(%rbp)
	flds	-276(%rbp)
	fstp	%st(0)
	flds	vertex_x87_hcl(%rip)
	flds	1179644+vertex_x87_hcl(%rip)
	faddp	%st, %st(1)
	fstps	-280(%rbp)
	flds	-280(%rbp)
	fstp	%st(0)
	nop
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE8:
	.size	vertex_x87, .-vertex_x87
	.globl	raster_x87
	.type	raster_x87, @function
raster_x87:
.LFB9:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$4224, %rsp
	movq	%rdi, -4200(%rbp)
	movq	%rsi, -4208(%rbp)
	movl	%edx, -4212(%rbp)
	movl	%ecx, -4216(%rbp)
	movl	-4212(%rbp), %eax
	movslq	%eax, %rdx
	movl	-4216(%rbp), %eax
	cltq
	imulq	%rax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rax, %rdx
	movq	-4208(%rbp), %rax
	movl	$9, %esi
	movq	%rax, %rdi
	call	memset@PLT
	fldt	.LC18(%rip)
	fstpt	-80(%rbp)
	movl	$0, -4(%rbp)
	jmp	.L30
.L34:
	movl	-4(%rbp), %ecx
	movslq	%ecx, %rax
	imulq	$954437177, %rax, %rax
	shrq	$32, %rax
	movl	%eax, %edx
	sarl	%edx
	movl	%ecx, %eax
	sarl	$31, %eax
	subl	%eax, %edx
	movl	%edx, %eax
	sall	$3, %eax
	addl	%edx, %eax
	subl	%eax, %ecx
	movl	%ecx, %edx
	movl	-4(%rbp), %eax
	movslq	%eax, %rcx
	movq	%rcx, %rax
	addq	%rax, %rax
	addq	%rcx, %rax
	salq	$2, %rax
	addq	%rbp, %rax
	subq	$528, %rax
	movl	%edx, (%rax)
	movl	-4(%rbp), %eax
	leal	9(%rax), %ecx
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	salq	$2, %rax
	addq	%rbp, %rax
	subq	$524, %rax
	movl	%ecx, (%rax)
	movl	-4(%rbp), %edx
	movl	%edx, %eax
	sall	$3, %eax
	addl	%edx, %eax
	sall	$2, %eax
	movslq	%eax, %rdx
	imulq	$-1307163959, %rdx, %rdx
	shrq	$32, %rdx
	addl	%eax, %edx
	sarl	$4, %edx
	sarl	$31, %eax
	subl	%eax, %edx
	leal	6(%rdx), %ecx
	movslq	%ecx, %rax
	imulq	$-580400985, %rax, %rax
	shrq	$32, %rax
	addl	%ecx, %eax
	sarl	$5, %eax
	movl	%eax, %edx
	movl	%ecx, %eax
	sarl	$31, %eax
	subl	%eax, %edx
	movl	%edx, %eax
	sall	$3, %eax
	addl	%edx, %eax
	sall	$2, %eax
	addl	%edx, %eax
	subl	%eax, %ecx
	movl	%ecx, %edx
	leal	33(%rdx), %ecx
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	salq	$2, %rax
	addq	%rbp, %rax
	subq	$520, %rax
	movl	%ecx, (%rax)
	movl	-4(%rbp), %ecx
	movslq	%ecx, %rax
	imulq	$1431655766, %rax, %rax
	shrq	$32, %rax
	movq	%rax, %rdx
	movl	%ecx, %eax
	sarl	$31, %eax
	subl	%eax, %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	subl	%eax, %ecx
	movl	%ecx, %edx
	testl	%edx, %edx
	jne	.L31
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$608, %rax
	movb	$-56, (%rax)
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$607, %rax
	movb	$-60, (%rax)
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$606, %rax
	movb	$-68, (%rax)
	jmp	.L32
.L31:
	movl	-4(%rbp), %ecx
	movslq	%ecx, %rax
	imulq	$1431655766, %rax, %rax
	shrq	$32, %rax
	movq	%rax, %rdx
	movl	%ecx, %eax
	sarl	$31, %eax
	subl	%eax, %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	subl	%eax, %ecx
	movl	%ecx, %edx
	cmpl	$1, %edx
	jne	.L33
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$608, %rax
	movb	$-98, (%rax)
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$607, %rax
	movb	$-60, (%rax)
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$606, %rax
	movb	$-48, (%rax)
	jmp	.L32
.L33:
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$608, %rax
	movb	$-40, (%rax)
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$607, %rax
	movb	$-60, (%rax)
	movl	-4(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$606, %rax
	movb	$-96, (%rax)
.L32:
	addl	$1, -4(%rbp)
.L30:
	cmpl	$23, -4(%rbp)
	jle	.L34
	movl	$0, -8(%rbp)
	jmp	.L35
.L36:
	movl	-8(%rbp), %edx
	movl	%edx, %eax
	addl	%eax, %eax
	addl	%edx, %eax
	sall	$2, %eax
	cltq
	leaq	0(,%rax,8), %rdx
	movq	-4200(%rbp), %rax
	addq	%rdx, %rax
	movq	%rax, -232(%rbp)
	movq	-232(%rbp), %rax
	movq	%rax, %rdi
	call	gather4
	movl	-8(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$1728, %rax
	fstpt	(%rax)
	movq	-232(%rbp), %rax
	addq	$32, %rax
	movq	%rax, %rdi
	call	gather4
	movl	-8(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$2848, %rax
	fstpt	(%rax)
	movq	-232(%rbp), %rax
	addq	$64, %rax
	movq	%rax, %rdi
	call	gather4
	movl	-8(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$3968, %rax
	fstpt	(%rax)
	addl	$1, -8(%rbp)
.L35:
	cmpl	$69, -8(%rbp)
	jle	.L36
	movl	$0, -12(%rbp)
	jmp	.L37
.L64:
	movl	$1, -16(%rbp)
	movl	$0, -20(%rbp)
	jmp	.L38
.L42:
	movl	-20(%rbp), %eax
	movslq	%eax, %rcx
	movl	-12(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rcx, %rax
	movl	-528(%rbp,%rax,4), %eax
	movl	%eax, -84(%rbp)
	movl	-84(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$3968, %rax
	fldt	(%rax)
	fldt	.LC19(%rip)
	faddp	%st, %st(1)
	fstpt	-112(%rbp)
	fldt	-112(%rbp)
	fldt	-80(%rbp)
	fcomip	%st(1), %st
	fstp	%st(0)
	jbe	.L69
	movl	$0, -16(%rbp)
	jmp	.L41
.L69:
	movl	-84(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$1728, %rax
	fldt	(%rax)
	fldt	-112(%rbp)
	fdivrp	%st, %st(1)
	fildl	-4212(%rbp)
	fldt	.LC20(%rip)
	fmulp	%st, %st(1)
	fmulp	%st, %st(1)
	fildl	-4212(%rbp)
	fldt	.LC17(%rip)
	fmulp	%st, %st(1)
	faddp	%st, %st(1)
	movl	-20(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$4192, %rax
	fstpt	(%rax)
	movl	-84(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$2848, %rax
	fldt	(%rax)
	fldt	.LC21(%rip)
	faddp	%st, %st(1)
	fchs
	fldt	-112(%rbp)
	fdivrp	%st, %st(1)
	fildl	-4216(%rbp)
	fldt	.LC20(%rip)
	fmulp	%st, %st(1)
	fmulp	%st, %st(1)
	fildl	-4216(%rbp)
	fldt	.LC11(%rip)
	fmulp	%st, %st(1)
	faddp	%st, %st(1)
	movl	-20(%rbp), %eax
	cltq
	salq	$4, %rax
	addq	%rbp, %rax
	subq	$4144, %rax
	fstpt	(%rax)
	addl	$1, -20(%rbp)
.L38:
	cmpl	$2, -20(%rbp)
	jle	.L42
.L41:
	cmpl	$0, -16(%rbp)
	je	.L70
	fldt	-4160(%rbp)
	fldt	-4176(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fminl@PLT
	addq	$32, %rsp
	fldt	-4192(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fminl@PLT
	addq	$32, %rsp
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	floorl@PLT
	addq	$16, %rsp
	fnstcw	-4218(%rbp)
	movzwl	-4218(%rbp), %eax
	orb	$12, %ah
	movw	%ax, -4220(%rbp)
	fldcw	-4220(%rbp)
	fistpl	-24(%rbp)
	fldcw	-4218(%rbp)
	fldt	-4160(%rbp)
	fldt	-4176(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fmaxl@PLT
	addq	$32, %rsp
	fldt	-4192(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fmaxl@PLT
	addq	$32, %rsp
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	ceill@PLT
	addq	$16, %rsp
	fnstcw	-4218(%rbp)
	movzwl	-4218(%rbp), %eax
	orb	$12, %ah
	movw	%ax, -4220(%rbp)
	fldcw	-4220(%rbp)
	fistpl	-28(%rbp)
	fldcw	-4218(%rbp)
	fldt	-4112(%rbp)
	fldt	-4128(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fminl@PLT
	addq	$32, %rsp
	fldt	-4144(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fminl@PLT
	addq	$32, %rsp
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	floorl@PLT
	addq	$16, %rsp
	fnstcw	-4218(%rbp)
	movzwl	-4218(%rbp), %eax
	orb	$12, %ah
	movw	%ax, -4220(%rbp)
	fldcw	-4220(%rbp)
	fistpl	-32(%rbp)
	fldcw	-4218(%rbp)
	fldt	-4112(%rbp)
	fldt	-4128(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fmaxl@PLT
	addq	$32, %rsp
	fldt	-4144(%rbp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	fmaxl@PLT
	addq	$32, %rsp
	leaq	-16(%rsp), %rsp
	fstpt	(%rsp)
	call	ceill@PLT
	addq	$16, %rsp
	fnstcw	-4218(%rbp)
	movzwl	-4218(%rbp), %eax
	orb	$12, %ah
	movw	%ax, -4220(%rbp)
	fldcw	-4220(%rbp)
	fistpl	-36(%rbp)
	fldcw	-4218(%rbp)
	cmpl	$0, -24(%rbp)
	jns	.L45
	movl	$0, -24(%rbp)
.L45:
	cmpl	$0, -32(%rbp)
	jns	.L46
	movl	$0, -32(%rbp)
.L46:
	movl	-28(%rbp), %eax
	cmpl	-4212(%rbp), %eax
	jl	.L47
	movl	-4212(%rbp), %eax
	subl	$1, %eax
	movl	%eax, -28(%rbp)
.L47:
	movl	-36(%rbp), %eax
	cmpl	-4216(%rbp), %eax
	jl	.L48
	movl	-4216(%rbp), %eax
	subl	$1, %eax
	movl	%eax, -36(%rbp)
.L48:
	fldt	-4176(%rbp)
	fldt	-4192(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4112(%rbp)
	fldt	-4144(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fldt	-4160(%rbp)
	fldt	-4192(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4128(%rbp)
	fldt	-4144(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fsubrp	%st, %st(1)
	fstpt	-128(%rbp)
	fldt	-128(%rbp)
	fabs
	fldt	.LC22(%rip)
	fcomip	%st(1), %st
	fstp	%st(0)
	ja	.L71
	movl	-32(%rbp), %eax
	movl	%eax, -40(%rbp)
	jmp	.L51
.L62:
	movl	-24(%rbp), %eax
	movl	%eax, -44(%rbp)
	jmp	.L52
.L61:
	movl	$0, -48(%rbp)
	fldt	.LC23(%rip)
	fstpt	-4096(%rbp)
	fldt	.LC23(%rip)
	fstpt	-4080(%rbp)
	fldt	.LC24(%rip)
	fstpt	-4064(%rbp)
	fldt	.LC23(%rip)
	fstpt	-4048(%rbp)
	fldt	.LC23(%rip)
	fstpt	-4032(%rbp)
	fldt	.LC24(%rip)
	fstpt	-4016(%rbp)
	fldt	.LC24(%rip)
	fstpt	-4000(%rbp)
	fldt	.LC24(%rip)
	fstpt	-3984(%rbp)
	movl	$0, -52(%rbp)
	jmp	.L53
.L58:
	fildl	-44(%rbp)
	movl	-52(%rbp), %eax
	cltq
	salq	$5, %rax
	addq	%rbp, %rax
	subq	$4096, %rax
	fldt	(%rax)
	faddp	%st, %st(1)
	fstpt	-160(%rbp)
	fildl	-40(%rbp)
	movl	-52(%rbp), %eax
	cltq
	salq	$5, %rax
	addq	%rbp, %rax
	subq	$4080, %rax
	fldt	(%rax)
	faddp	%st, %st(1)
	fstpt	-176(%rbp)
	fldt	-4176(%rbp)
	fldt	-160(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4112(%rbp)
	fldt	-176(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fldt	-4160(%rbp)
	fldt	-160(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4128(%rbp)
	fldt	-176(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fsubrp	%st, %st(1)
	fstpt	-192(%rbp)
	fldt	-4160(%rbp)
	fldt	-160(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4144(%rbp)
	fldt	-176(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fldt	-4192(%rbp)
	fldt	-160(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4112(%rbp)
	fldt	-176(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fsubrp	%st, %st(1)
	fstpt	-208(%rbp)
	fldt	-4192(%rbp)
	fldt	-160(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4128(%rbp)
	fldt	-176(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fldt	-4176(%rbp)
	fldt	-160(%rbp)
	fsubrp	%st, %st(1)
	fldt	-4144(%rbp)
	fldt	-176(%rbp)
	fsubrp	%st, %st(1)
	fmulp	%st, %st(1)
	fsubrp	%st, %st(1)
	fstpt	-224(%rbp)
	fldt	-192(%rbp)
	fldt	-128(%rbp)
	fdivrp	%st, %st(1)
	fstpt	-192(%rbp)
	fldt	-208(%rbp)
	fldt	-128(%rbp)
	fdivrp	%st, %st(1)
	fstpt	-208(%rbp)
	fldt	-224(%rbp)
	fldt	-128(%rbp)
	fdivrp	%st, %st(1)
	fstpt	-224(%rbp)
	fldz
	fldt	-192(%rbp)
	fcomip	%st(1), %st
	fstp	%st(0)
	jb	.L54
	fldz
	fldt	-208(%rbp)
	fcomip	%st(1), %st
	fstp	%st(0)
	jb	.L54
	fldz
	fldt	-224(%rbp)
	fcomip	%st(1), %st
	fstp	%st(0)
	jb	.L54
	addl	$1, -48(%rbp)
.L54:
	addl	$1, -52(%rbp)
.L53:
	cmpl	$3, -52(%rbp)
	jle	.L58
	cmpl	$0, -48(%rbp)
	je	.L72
	movl	-40(%rbp), %eax
	movslq	%eax, %rdx
	movl	-4212(%rbp), %eax
	cltq
	imulq	%rax, %rdx
	movl	-44(%rbp), %eax
	cltq
	addq	%rax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	movq	%rax, -136(%rbp)
	movl	-48(%rbp), %eax
	movl	%eax, -140(%rbp)
	movl	-12(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$608, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %eax
	imull	-140(%rbp), %eax
	movl	%eax, %ecx
	movq	-4208(%rbp), %rdx
	movq	-136(%rbp), %rax
	addq	%rdx, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %edx
	movl	$4, %eax
	subl	-140(%rbp), %eax
	imull	%edx, %eax
	addl	%ecx, %eax
	shrl	$2, %eax
	movl	%eax, %ecx
	movq	-4208(%rbp), %rdx
	movq	-136(%rbp), %rax
	addq	%rdx, %rax
	movl	%ecx, %edx
	movb	%dl, (%rax)
	movl	-12(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$607, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %eax
	imull	-140(%rbp), %eax
	movl	%eax, %ecx
	movq	-136(%rbp), %rax
	leaq	1(%rax), %rdx
	movq	-4208(%rbp), %rax
	addq	%rdx, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %edx
	movl	$4, %eax
	subl	-140(%rbp), %eax
	imull	%edx, %eax
	addl	%ecx, %eax
	shrl	$2, %eax
	movl	%eax, %ecx
	movq	-136(%rbp), %rax
	leaq	1(%rax), %rdx
	movq	-4208(%rbp), %rax
	addq	%rdx, %rax
	movl	%ecx, %edx
	movb	%dl, (%rax)
	movl	-12(%rbp), %eax
	movslq	%eax, %rdx
	movq	%rdx, %rax
	addq	%rax, %rax
	addq	%rdx, %rax
	addq	%rbp, %rax
	subq	$606, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %eax
	imull	-140(%rbp), %eax
	movl	%eax, %ecx
	movq	-136(%rbp), %rax
	leaq	2(%rax), %rdx
	movq	-4208(%rbp), %rax
	addq	%rdx, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %edx
	movl	$4, %eax
	subl	-140(%rbp), %eax
	imull	%edx, %eax
	addl	%ecx, %eax
	shrl	$2, %eax
	movl	%eax, %ecx
	movq	-136(%rbp), %rax
	leaq	2(%rax), %rdx
	movq	-4208(%rbp), %rax
	addq	%rdx, %rax
	movl	%ecx, %edx
	movb	%dl, (%rax)
	jmp	.L60
.L72:
	nop
.L60:
	addl	$1, -44(%rbp)
.L52:
	movl	-44(%rbp), %eax
	cmpl	-28(%rbp), %eax
	jle	.L61
	addl	$1, -40(%rbp)
.L51:
	movl	-40(%rbp), %eax
	cmpl	-36(%rbp), %eax
	jle	.L62
	jmp	.L63
.L70:
	nop
	jmp	.L63
.L71:
	nop
.L63:
	addl	$1, -12(%rbp)
.L37:
	cmpl	$23, -12(%rbp)
	jle	.L64
	nop
	nop
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE9:
	.size	raster_x87, .-raster_x87
	.section	.rodata
	.align 32
	.type	HCL_LIMB, @object
	.size	HCL_LIMB, 32
HCL_LIMB:
	.string	""
	.string	"\001\002\003"
	.string	"\001\002\003"
	.string	"\001\002\003"
	.string	"\001\002\003"
	.string	"\001\002\003"
	.string	"\001\002\003"
	.string	"\001\002\003"
	.ascii	"\001\002\003"
	.align 32
	.type	HCL_VALID, @object
	.size	HCL_VALID, 96
HCL_VALID:
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001"
	.string	""
	.string	"\001\001\001"
	.string	"\001\001\001"
	.string	"\001\001\001"
	.string	"\001\001\001"
	.string	"\001\001\001"
	.string	"\001\001\001"
	.string	"\001\001\001"
	.string	"\001\001\001"
	.ascii	"\001\001\001\001\001\001\001\001\001\001\001\001\001\001\001"
	.ascii	"\001\001\001\001\001\001\001\001\001\001\001\001\001\001\001"
	.ascii	"\001\001"
	.text
	.globl	hcl_cutthrough
	.type	hcl_cutthrough, @function
hcl_cutthrough:
.LFB10:
	.cfi_startproc
	pushq	%rbp
	.cfi_def_cfa_offset 16
	.cfi_offset 6, -16
	movq	%rsp, %rbp
	.cfi_def_cfa_register 6
	subq	$80, %rsp
	movq	%rdi, -56(%rbp)
	movq	%rsi, -64(%rbp)
	movl	%edx, -68(%rbp)
	movss	%xmm0, -72(%rbp)
	cmpl	$2, -68(%rbp)
	jle	.L74
	cmpl	$3, -68(%rbp)
	jne	.L75
	movl	$1, %eax
	jmp	.L77
.L75:
	movl	$2, %eax
	jmp	.L77
.L74:
	movl	$0, %eax
.L77:
	movl	%eax, -28(%rbp)
	movl	$0, -12(%rbp)
	fldz
	fstpl	-24(%rbp)
	movq	-64(%rbp), %rax
	movl	$2048, %edx
	movl	$0, %esi
	movq	%rax, %rdi
	call	memset@PLT
	movl	$0, -4(%rbp)
	jmp	.L78
.L83:
	movl	-4(%rbp), %eax
	cltq
	movl	-28(%rbp), %edx
	movslq	%edx, %rdx
	salq	$5, %rdx
	addq	%rax, %rdx
	leaq	HCL_VALID(%rip), %rax
	addq	%rdx, %rax
	movzbl	(%rax), %eax
	movzbl	%al, %eax
	movl	%eax, -32(%rbp)
	movl	-4(%rbp), %eax
	cltq
	leaq	HCL_LIMB(%rip), %rdx
	movzbl	(%rax,%rdx), %eax
	movzbl	%al, %eax
	movl	%eax, -36(%rbp)
	movl	-4(%rbp), %eax
	sall	$5, %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-56(%rbp), %rax
	addq	%rdx, %rax
	flds	(%rax)
	fstps	-40(%rbp)
	cmpl	$0, -32(%rbp)
	je	.L79
	movl	-4(%rbp), %eax
	sall	$5, %eax
	cltq
	addq	$1, %rax
	leaq	0(,%rax,4), %rdx
	movq	-56(%rbp), %rax
	addq	%rdx, %rax
	flds	(%rax)
	fldl	-24(%rbp)
	faddp	%st, %st(1)
	fstpl	-24(%rbp)
	addl	$1, -12(%rbp)
.L79:
	movl	$0, -8(%rbp)
	jmp	.L80
.L82:
	movl	-4(%rbp), %eax
	leal	0(,%rax,4), %edx
	movl	-8(%rbp), %eax
	addl	%edx, %eax
	sall	$2, %eax
	movl	%eax, -44(%rbp)
	cmpl	$0, -32(%rbp)
	je	.L81
	movl	-44(%rbp), %eax
	cltq
	leaq	0(,%rax,4), %rdx
	movq	-64(%rbp), %rax
	addq	%rdx, %rax
	flds	-40(%rbp)
	fstps	(%rax)
	movl	-44(%rbp), %eax
	cltq
	addq	$1, %rax
	leaq	0(,%rax,4), %rdx
	movq	-64(%rbp), %rax
	addq	%rdx, %rax
	fildl	-36(%rbp)
	fstps	(%rax)
	movl	-44(%rbp), %eax
	cltq
	addq	$2, %rax
	leaq	0(,%rax,4), %rdx
	movq	-64(%rbp), %rax
	addq	%rdx, %rax
	fld1
	fstps	(%rax)
	movl	-44(%rbp), %eax
	cltq
	addq	$3, %rax
	leaq	0(,%rax,4), %rdx
	movq	-64(%rbp), %rax
	addq	%rdx, %rax
	flds	-72(%rbp)
	fstps	(%rax)
.L81:
	addl	$1, -8(%rbp)
.L80:
	cmpl	$3, -8(%rbp)
	jle	.L82
	addl	$1, -4(%rbp)
.L78:
	cmpl	$31, -4(%rbp)
	jle	.L83
	cmpl	$0, -12(%rbp)
	je	.L84
	fildl	-12(%rbp)
	fldl	-24(%rbp)
	fdivp	%st, %st(1)
	fldl	.LC26(%rip)
	faddp	%st, %st(1)
	fstpl	-80(%rbp)
	cvttsd2sil	-80(%rbp), %eax
	jmp	.L86
.L84:
	movss	-72(%rbp), %xmm0
	cvttss2sil	%xmm0, %eax
.L86:
	leave
	.cfi_def_cfa 7, 8
	ret
	.cfi_endproc
.LFE10:
	.size	hcl_cutthrough, .-hcl_cutthrough
	.section	.rodata
	.align 4
.LC0:
	.long	1078530011
	.align 4
.LC1:
	.long	1086918619
	.align 8
.LC4:
	.long	1413754136
	.long	1074340347
	.align 8
.LC5:
	.long	1413754136
	.long	1075388923
	.align 4
.LC7:
	.long	1057300152
	.align 16
.LC8:
	.long	858993459
	.long	-1288490189
	.long	16382
	.long	0
	.align 16
.LC9:
	.long	1374389535
	.long	-343597384
	.long	16382
	.long	0
	.align 16
.LC10:
	.long	-1717986918
	.long	-1181116007
	.long	16383
	.long	0
	.align 16
.LC11:
	.long	687194767
	.long	-171798692
	.long	16381
	.long	0
	.align 16
.LC13:
	.long	560513589
	.long	-921707870
	.long	16385
	.long	0
	.align 16
.LC14:
	.long	0
	.long	-1879048192
	.long	16386
	.long	0
	.align 16
.LC15:
	.long	0
	.long	-1073741824
	.long	16387
	.long	0
	.align 16
.LC16:
	.long	0
	.long	-1811939328
	.long	16388
	.long	0
	.align 16
.LC17:
	.long	0
	.long	-2147483648
	.long	16382
	.long	0
	.align 16
.LC18:
	.long	-1717986918
	.long	-1717986919
	.long	16382
	.long	0
	.align 16
.LC19:
	.long	0
	.long	-1073741824
	.long	16386
	.long	0
	.align 16
.LC20:
	.long	-171798692
	.long	-1030792152
	.long	16381
	.long	0
	.align 16
.LC21:
	.long	-858993459
	.long	-858993460
	.long	16381
	.long	0
	.align 16
.LC22:
	.long	-2073964803
	.long	-1412663535
	.long	16356
	.long	0
	.align 16
.LC23:
	.long	0
	.long	-2147483648
	.long	16381
	.long	0
	.align 16
.LC24:
	.long	0
	.long	-1073741824
	.long	16382
	.long	0
	.align 8
.LC26:
	.long	0
	.long	1071644672
	.ident	"GCC: (Debian 12.2.0-14+deb12u1) 12.2.0"
	.section	.note.GNU-stack,"",@progbits

	.section	.rodata
	.p2align 4
	.globl	vertex_x87_lut
	.type	vertex_x87_lut, @object
vertex_x87_lut:
	.incbin	"x87-lut.bin"
	.size	vertex_x87_lut, 1048576
	.globl	vertex_x87_ppm
vertex_x87_ppm:
	.incbin	"x87-raster.ppm"
	.globl	vertex_x87_hcl
	.type	vertex_x87_hcl, @object
vertex_x87_hcl:
	.incbin	"x87-hcl.bin"
	.size	vertex_x87_hcl, 1179648
