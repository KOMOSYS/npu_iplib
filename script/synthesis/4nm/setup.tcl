set search_path [list . \
    [format "%s%s"  $synopsys_root /libraries/syn] \
    /DKIT/SEC_4LPP/STD_CELL/FE-Liberty/LIBERTY/flk
]

set link_library [list * dw_foundation.sldb]

set target_library [list \
    ln04lpp_sc_s7p94t_flk_rvt_c60l06_sspg_nominal_max_0p6750v_m40c_lvf_dth.db_ccs_tn
]