*==============================================================================
* 07_table1.do - Table 1: weighted sample characteristics by period (STROBE 14a)
* Weighted column percentages among target women with the outcome observed
* (insamp). Missing values are shown as a separate category.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L07
log using "$LOG/07_table1.log", replace text name(L07)

use "$OUT/gdhs_pooled.dta", clear
keep if insamp
gen byte all_ = 0                     // single 'overall' column
gen byte one = 1

tempfile t1
local first 1
local vars agegrp urban zone3 educ3 relig4 $WQ has_child early_mar cohab

foreach v of local vars {
    local vlab : variable label `v'
    local lblname : value label `v'
    gen int _tv = `v'
    replace _tv = 99 if missing(_tv)
    quietly levelsof _tv, local(lv)
    foreach l of local lv {
        if `l'==99 local ll "Missing"
        else if "`lblname'"=="" local ll "`l'"
        else local ll : label `lblname' `l'
        foreach byv in period3 all_ {
            preserve
            gen double _w1 = wt*(_tv==`l')
            collapse (sum) sw1=_w1 sw=wt n=one, by(`byv')
            gen double pct = 100*sw1/sw
            rename `byv' col
            gen str20 colvar = "`byv'"
            gen str30 variable = "`v'"
            gen str40 category = "`ll'"
            keep colvar col variable category pct
            if `first' {
                save `t1', replace
                local first 0
            }
            else {
                append using `t1'
                save `t1', replace
            }
            restore
        }
    }
    drop _tv
}
use `t1', clear
gen str12 column = cond(colvar=="all_","Overall","P"+string(col))
drop colvar col
reshape wide pct, i(variable category) j(column) string
order variable category pctP1 pctP2 pctP3 pctOverall
foreach v of varlist pct* {
    replace `v' = 0 if missing(`v')
}
format pct* %5.1f
list, noobs sep(0)
export delimited using "$TAB/table1_characteristics.csv", replace
di as txt "P1 = 1993-98, P2 = 2003-08, P3 = 2014-22. Unweighted Ns are in audit_flow.csv."
log close L07
