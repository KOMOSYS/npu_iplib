set search_path [list . \
    [format "%s%s"  $synopsys_root /libraries/syn] \
    /DKIT/SEC_4LPP/STD_CELL/FE-Liberty/LIBERTY/flk
]

switch $cond {
    "tt_25c" {
        set link_library [list * \
            dw_foundation.sldb \
            ln04lpp_sc_s7p94t_flk_rvt_c60l06_tt_nominal_max_0p7500v_25c_lvf_dth.db_ccs_tn
        ]
    }
    "tt_85c" {
        set link_library [list * \
            dw_foundation.sldb \
            ln04lpp_sc_s7p94t_flk_rvt_c60l06_tt_nominal_max_0p7500v_85c_lvf_dth.db_ccs_tn
        ]
    }
    "tt_125c" {
        set link_library [list * \
            dw_foundation.sldb \
            ln04lpp_sc_s7p94t_flk_rvt_c60l06_tt_nominal_max_0p7500v_125c_lvf_dth.db_ccs_tn
        ]
    }
}
