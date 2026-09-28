;; VERTEX - wasm32 kernel. Lattice only. Host libm for sin/cos.
;; HCL cut-through transcode lives at /gpu/cutthrough_wasm.wat (hexa fabric).
;; Instantiated single-thread. Memory[0..215] = 9 x f64 xyz.
(module
  (import "env" "sin" (func $sin (param f64) (result f64)))
  (import "env" "cos" (func $cos (param f64) (result f64)))
  (memory (export "memory") 1)

  (func (export "vertex")
    (param $n f64) (param $sp f64) (param $sa f64) (param $so f64)
    (local $i i32)
    (local $layer i32)
    (local $corner i32)
    (local $n1 f64) (local $n2 f64) (local $n3 f64) (local $h f64)
    (local $r f64) (local $y f64) (local $spin f64) (local $off f64)
    (local $a f64) (local $c f64) (local $s f64)
    (local $ptr i32)

    (local.set $n1 (local.get $n))
    (local.set $n2 (f64.mul (local.get $n) (local.get $n)))
    (local.set $n3 (f64.mul (local.get $n2) (local.get $n)))
    (local.set $h (f64.mul (local.get $n2) (f64.const 0.52)))

    (loop $L
      (local.set $layer (i32.div_u (local.get $i) (i32.const 3)))
      (local.set $corner (i32.rem_u (local.get $i) (i32.const 3)))

      (if (i32.eqz (local.get $layer))
        (then
          (local.set $r (local.get $n3))
          (local.set $y (local.get $h))
          (local.set $spin (local.get $sp))
          (local.set $off (f64.const 0))
        )
        (else
          (if (i32.eq (local.get $layer) (i32.const 1))
            (then
              (local.set $r (local.get $n2))
              (local.set $y (f64.const 0))
              (local.set $spin (local.get $sa))
              (local.set $off (f64.const 1.0471975511965976))
            )
            (else
              (local.set $r (local.get $n1))
              (local.set $y (f64.neg (local.get $h)))
              (local.set $spin (local.get $so))
              (local.set $off (f64.const 0))
            )
          )
        )
      )

      (local.set $a
        (f64.add
          (f64.add (local.get $spin) (local.get $off))
          (f64.mul
            (f64.convert_i32_u (local.get $corner))
            (f64.const 2.0943951023931953)
          )
        )
      )
      (local.set $c (call $cos (local.get $a)))
      (local.set $s (call $sin (local.get $a)))
      (local.set $ptr (i32.mul (local.get $i) (i32.const 24)))
      (f64.store (local.get $ptr) (f64.mul (local.get $r) (local.get $c)))
      (f64.store offset=8 (local.get $ptr) (local.get $y))
      (f64.store offset=16 (local.get $ptr) (f64.mul (local.get $r) (local.get $s)))

      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br_if $L (i32.lt_u (local.get $i) (i32.const 9)))
    )
  )
)
