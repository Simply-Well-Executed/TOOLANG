;; VERTEX HCL 1.0 → wasm32. f32.load from LUT in memory.
;; Hexa fabric. ICQ 32×8, OEP 32×4. No remainder. Disk LUT lives at mem 4096.
(module
  (memory (export "memory") 1)
  (func (export "cutthrough")
    (param $icq i32) (param $oep i32) (param $limbs i32) (param $union f32)
    (local $h i32) (local $p i32) (local $pi i32) (local $valid i32)
    (local $payload f32) (local $limb f32)
    (local.set $pi
      (if (result i32) (i32.le_s (local.get $limbs) (i32.const 2))
        (then (i32.const 0))
        (else (if (result i32) (i32.eq (local.get $limbs) (i32.const 3))
          (then (i32.const 1))
          (else (i32.const 2))))))
    (loop $HT
      (local.set $valid
        (i32.load8_u
          (i32.add (i32.const 4096)
            (i32.add (i32.mul (local.get $pi) (i32.const 32)) (local.get $h)))))
      (local.set $payload
        (f32.load (i32.add (local.get $icq) (i32.mul (local.get $h) (i32.const 128)))))
      (local.set $limb
        (f32.convert_i32_u
          (i32.load8_u (i32.add (i32.const 4064) (local.get $h)))))
      (local.set $p (i32.const 0))
      (loop $PORT
        (if (local.get $valid)
          (then
            (f32.store (i32.add (local.get $oep)
              (i32.mul (i32.add (i32.mul (local.get $h) (i32.const 4)) (local.get $p)) (i32.const 16)))
              (local.get $payload))
            (f32.store offset=4 (i32.add (local.get $oep)
              (i32.mul (i32.add (i32.mul (local.get $h) (i32.const 4)) (local.get $p)) (i32.const 16)))
              (local.get $limb))
            (f32.store offset=8 (i32.add (local.get $oep)
              (i32.mul (i32.add (i32.mul (local.get $h) (i32.const 4)) (local.get $p)) (i32.const 16)))
              (f32.const 1))
            (f32.store offset=12 (i32.add (local.get $oep)
              (i32.mul (i32.add (i32.mul (local.get $h) (i32.const 4)) (local.get $p)) (i32.const 16)))
              (local.get $union))))
        (local.set $p (i32.add (local.get $p) (i32.const 1)))
        (br_if $PORT (i32.lt_s (local.get $p) (i32.const 4))))
      (local.set $h (i32.add (local.get $h) (i32.const 1)))
      (br_if $HT (i32.lt_s (local.get $h) (i32.const 32))))
  )
)
