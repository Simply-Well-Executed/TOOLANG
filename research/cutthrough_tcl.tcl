# VERTEX HCL 1.0 → Native Tcl 8. Exclusive kernel language.
# Hexa fabric. LUT, not expr remainder. CPU twin of the WebGL2 switch.
proc hcl_limb {} { list 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 0 1 2 3 }
proc hcl_valid {limbs} {
    if {$limbs <= 2} { return [list 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0 1 1 0 0] }
    if {$limbs == 3} { return [list 1 1 1 0 1 1 1 0 1 1 1 0 1 1 1 0 1 1 1 0 1 1 1 0 1 1 1 0 1 1 1 0] }
    return [list 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]
}
proc cutthrough {icq oep limbs union} {
    set valid [hcl_valid $limbs]
    set limb [hcl_limb]
    for {set h 0} {$h < 32} {incr h} {
        set v [lindex $valid $h]
        set payload [lindex $icq [expr {$h * 32}]]
        for {set p 0} {$p < 4} {incr p} {
            set oq [expr {($h * 4 + $p) * 4}]
            if {$v} {
                lset oep $oq $payload
                lset oep [expr {$oq + 1}] [lindex $limb $h]
                lset oep [expr {$oq + 2}] 1
                lset oep [expr {$oq + 3}] $union
            } else {
                lset oep $oq 0
                lset oep [expr {$oq + 1}] 0
                lset oep [expr {$oq + 2}] 0
                lset oep [expr {$oq + 3}] 0
            }
        }
    }
    return $oep
}
