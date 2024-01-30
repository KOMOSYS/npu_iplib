set search_path [list . \
    [format "%s%s"  $synopsys_root /libraries/syn] \
    /DKIT/ARM_5LPE/STD_CELL/ln05lpe/DB
]

set link_library [list * dw_foundation.sldb]

set target_library [list \
    sc6mcz_ln05lpe_base_rvt_c10_sspg_nominal_max_0p675v_m40c.db
]