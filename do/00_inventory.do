*==============================================================================
* 00_inventory.do - Inventory of the DHS files in $RAW
* Lists every PR/IR file with its interview year and number of records, and
* reports which of the variables used in this project are present.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L00
log using "$LOG/00_inventory.log", replace text name(L00)

local prneed hv001 hv002 hvidx hv005 hv104 hv105 hv115 hv121 hv270 hv206 hv207 hv208 hv209 hv210 hv211 hv212
local irneed caseid v001 v002 v003 v005 v006 v007 v012 v013 v021 v022 v023 v024 v025 v106 v130 v190 v201 v501 v511

local files : dir "$RAW" files "*"
foreach f of local files {
    if lower(substr("`f'",-4,4)) != ".dta" continue
    local stem = upper(substr("`f'",1,length("`f'")-4))
    local type = substr("`stem'",3,2)
    if !inlist("`type'","PR","IR") continue

    quietly describe using "$RAW/`f'", short
    local N = r(N)
    quietly describe using "$RAW/`f'", varlist
    local vars `r(varlist)'

    local yv = cond("`type'"=="PR","hv007","v007")
    local need = cond("`type'"=="PR","`prneed'","`irneed'")

    local yrs "?"
    capture {
        quietly use `yv' using "$RAW/`f'", clear
        quietly summarize `yv'
        local y0 = r(min)
        local y1 = r(max)
        if `y0'<100 local y0 = `y0' + 1900
        if `y1'<100 local y1 = `y1' + 1900
        local yrs "`y0'-`y1'"
    }

    local missing_vars ""
    foreach v of local need {
        local pos : list posof "`v'" in vars
        if `pos'==0 local missing_vars `missing_vars' `v'
    }
    di as txt _n "`stem' | type `type' | N = `N' | interview years `yrs'"
    if "`missing_vars'"=="" di as txt "    all needed variables present"
    else di as err "    NOT in file: `missing_vars'"
}

log close L00
