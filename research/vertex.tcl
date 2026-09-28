# vertex.tcl — exclusive VERTEX kernel language (Tcl)
# Commercial wrap: Oracle GraalVM 25 LTS, GFTC (production use allowed).
# No TypeScript, JavaScript, PHP, Ruby, or Go in this kernel.

proc sincos {a} {
    list [expr {cos($a)}] [expr {sin($a)}]
}

proc vertex {n sp sa so} {
    set n1 $n
    set n2 [expr {$n * $n}]
    set h [expr {$n2 * 0.48}]
    set pi 3.141592653589793
    set twoPi9 [expr {2.0 * $pi / 9.0}]
    set twoPi24 [expr {2.0 * $pi / 24.0}]
    set twoPi37 [expr {2.0 * $pi / 37.0}]
    set rp [expr {$n2 * 0.7}]
    set ra [expr {$n2 * 0.92}]
    set ro [expr {$n1 * 1.45}]
    set out {}
    for {set k 0} {$k < 9} {incr k} {
        set a [expr {$sp + $k * $twoPi9}]
        set cs [sincos $a]
        set c [lindex $cs 0]
        set s [lindex $cs 1]
        lappend out [list [expr {$rp * $c}] $h [expr {$rp * $s}]]
    }
    for {set k 0} {$k < 24} {incr k} {
        set a [expr {$sa + ($k + 0.5) * $twoPi24}]
        set cs [sincos $a]
        set c [lindex $cs 0]
        set s [lindex $cs 1]
        lappend out [list [expr {$ra * $c}] 0.0 [expr {$ra * $s}]]
    }
    for {set k 0} {$k < 37} {incr k} {
        set a [expr {$so + ($k + 0.5) * $twoPi37}]
        set cs [sincos $a]
        set c [lindex $cs 0]
        set s [lindex $cs 1]
        lappend out [list [expr {$ro * $c}] [expr {0.0 - $h}] [expr {$ro * $s}]]
    }
    return $out
}

proc greek_letters {} {
    list ALPHA BETA GAMMA DELTA EPSILON ZETA ETA THETA IOTA KAPPA LAMBDA MU NU XI OMICRON PI RHO SIGMA TAU UPSILON PHI CHI PSI OMEGA
}

proc union_index {roll} {
    set t $roll
    if {$t < 0} { set t 0 }
    if {$t > 1} { set t 1 }
    expr {int($t * 23 + 0.5)}
}

proc union_letter {roll} {
    lindex [greek_letters] [union_index $roll]
}

proc roll_beta {pts roll} {
    return $pts
}

proc roll_theta {pts roll} {
    return $pts
}

proc roll_alpha {pts roll} {
    return $pts
}

proc canon_faces {} {
    list {0 9 39} {1 10 40} {2 11 42} {3 12 43} {4 13 45} {5 14 46} {6 15 48} {7 16 49} {8 17 51} {0 18 53} {1 19 54} {2 20 56} {3 21 57} {4 22 59} {5 23 60} {6 24 62} {7 25 64} {8 26 65} {0 27 67} {1 28 68} {2 29 33} {3 30 34} {4 31 36} {5 32 38}
}

# HCL cut-through — hexa fabric. LUT, not remainder. Transcoded from WebGL2.
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
            }
        }
    }
    return $oep
}

