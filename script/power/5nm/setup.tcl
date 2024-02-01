set search_path [list . \
    [format "%s%s"  $synopsys_root /libraries/syn] \
    /DKIT/ARM_5LPE/STD_CELL/ln05lpe/DB
]

switch $cond {
    "tt_25c" {
        set link_library [list * \
            dw_foundation.sldb \
            sc6mcz_ln05lpe_base_rvt_c10_tt_nominal_max_0p75v_25c.db \
        ]
    }
    "tt_85c" {
        set link_library [list * \
            dw_foundation.sldb \
            sc6mcz_ln05lpe_base_rvt_c10_tt_nominal_max_0p75v_85c.db \
        ]
    }
    "tt_125c" {
        set link_library [list * \
            dw_foundation.sldb \
            sc6mcz_ln05lpe_base_rvt_c10_tt_nominal_max_0p75v_125c.db \
        ]
    }
}
