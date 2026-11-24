*==============================================================================
* 03_trends.do - Descriptive trends (survey-weighted, design-based)
* Overall trend with confidence intervals, never-married comparison, subgroup
* trends, and linear and non-linear trend tests. Confidence intervals are
* computed on the logit scale and back-transformed.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L03
log using "$LOG/03_trends.log", replace text name(L03)

use "$OUT/gdhs_pooled.dta", clear
svyset psu [pweight=wt], strata(strata) singleunit(centered)

*------------------------------------------------------------------------------
* Helper: weighted prevalence by wave for any subpopulation expression
*------------------------------------------------------------------------------
capture program drop wave_est
program define wave_est
    syntax , SUBpop(string) SAVing(string)
    tempname P
    postfile `P' int wave double(p lb ub) long(n events) using `"`saving'"', replace
    quietly levelsof wave if `subpop', local(ws)
    capture quietly svy, subpop(if `subpop'): logit attend ibn.wave, noconstant
    local rc = _rc
    foreach w of local ws {
        quietly count if wave==`w' & (`subpop')
        local n = r(N)
        quietly count if wave==`w' & (`subpop') & attend==1
        local ev = r(N)
        local p  = .
        local lb = .
        local ub = .
        if `rc'==0 {
            capture quietly lincom _b[`w'.wave]
            if _rc==0 {
                local est = r(estimate)
                local se  = r(se)
                local df  = r(df)
                if `se' < . & `se' > 0 {
                    local p  = invlogit(`est')
                    local lb = invlogit(`est' - invttail(`df',0.025)*`se')
                    local ub = invlogit(`est' + invttail(`df',0.025)*`se')
                }
            }
        }
        post `P' (`w') (`p') (`lb') (`ub') (`n') (`ev')
    }
    postclose `P'
end

*------------------------------------------------------------------------------
* A. Overall trend among married/cohabiting women 15-24
*------------------------------------------------------------------------------
wave_est, subpop(insamp) saving("$TAB/trend_overall.dta")
preserve
use "$TAB/trend_overall.dta", clear
foreach v in p lb ub {
    replace `v' = 100*`v'
}
format p lb ub %5.1f
list, noobs sep(0)
export delimited using "$TAB/trend_overall.csv", replace
levelsof wave, local(wl)
twoway (rcap lb ub wave, lcolor(gs8)) (connected p wave, lcolor(black) mcolor(black) msymbol(O)), ///
    xlabel(`wl') ylabel(, angle(0) format(%3.0f)) ///
    ytitle("% attending school") xtitle("Survey year") legend(off) ///
    title("School attendance, married/cohabiting women 15-24", size(medsmall)) ///
    note("Survey-weighted; 95% CIs on logit scale", size(vsmall)) scheme(s1mono)
graph export "$FIG/fig1_overall_trend.png", replace width(2400)
restore

*------------------------------------------------------------------------------
* B. Comparison: never-married vs married/cohabiting women 15-24
*------------------------------------------------------------------------------
wave_est, subpop(ins1524 & mstat==0) saving("$TAB/_nm.dta")
wave_est, subpop(ins1524 & mstat==1) saving("$TAB/_mar.dta")
preserve
use "$TAB/_nm.dta", clear
gen byte grp = 0
append using "$TAB/_mar.dta"
replace grp = 1 if missing(grp)
foreach v in p lb ub {
    replace `v' = 100*`v'
}
label define lb_g 0 "Never married" 1 "Married/cohabiting"
label values grp lb_g
export delimited using "$TAB/trend_by_marital.csv", replace
levelsof wave, local(wl)
twoway (rcap lb ub wave if grp==0, lcolor(gs10)) (connected p wave if grp==0, lcolor(gs6) mcolor(gs6) msymbol(S)) ///
       (rcap lb ub wave if grp==1, lcolor(gs10)) (connected p wave if grp==1, lcolor(black) mcolor(black) msymbol(O)), ///
    xlabel(`wl') ylabel(0(20)100, angle(0)) ytitle("% attending school") xtitle("Survey year") ///
    legend(order(2 "Never married" 4 "Married/cohabiting") rows(1)) scheme(s1mono)
graph export "$FIG/fig2_marital_comparison.png", replace width(2400)
restore
erase "$TAB/_nm.dta"
erase "$TAB/_mar.dta"

*------------------------------------------------------------------------------
* C. Subgroup trends among married/cohabiting women 15-24
*------------------------------------------------------------------------------
tempfile all
local first 1
foreach g in agegrp urban zone3 educ3 wq3 {
    quietly levelsof `g' if insamp, local(lv)
    foreach l of local lv {
        local lbl : label (`g') `l'
        wave_est, subpop(insamp & `g'==`l') saving("$TAB/_tmp.dta")
        preserve
        use "$TAB/_tmp.dta", clear
        gen str12 gvar   = "`g'"
        gen byte  glevel = `l'
        gen str40 glabel = "`lbl'"
        if `first' {
            save `all', replace
            local first 0
        }
        else {
            append using `all'
            save `all', replace
        }
        restore
    }
}
erase "$TAB/_tmp.dta"
use `all', clear
foreach v in p lb ub {
    replace `v' = 100*`v'
}
save "$TAB/trend_subgroups.dta", replace
export delimited using "$TAB/trend_subgroups.csv", replace

foreach g in agegrp urban zone3 educ3 wq3 {
    use "$TAB/trend_subgroups.dta", clear
    keep if gvar=="`g'" & n>=20 & !missing(p)
    quietly levelsof wave, local(wl)
    quietly levelsof glevel, local(lv)
    local plots
    local leg
    local k 0
    foreach l of local lv {
        local ++k
        quietly levelsof glabel if glevel==`l', local(lab) clean
        local plots `plots' (connected p wave if glevel==`l')
        local leg `leg' `k' "`lab'"
    }
    twoway `plots', xlabel(`wl') ylabel(, angle(0)) ytitle("% attending school") xtitle("Survey year") ///
        legend(order(`leg') rows(2) size(small)) scheme(s1mono) ///
        note("Cells with n<20 not drawn; survey-weighted", size(vsmall))
    graph export "$FIG/fig3_trend_`g'.png", replace width(2400)
}

*------------------------------------------------------------------------------
* D. Trend tests (design-based) among target women
*------------------------------------------------------------------------------
use "$OUT/gdhs_pooled.dta", clear
svyset psu [pweight=wt], strata(strata) singleunit(centered)

di _n as txt "--- Linear trend: odds ratio per DECADE ---"
svy, subpop(insamp): logit attend c.t10, or
margins, dydx(t10) subpop(insamp)
di as txt "(dydx = change in probability per decade, i.e. x100 = percentage points per decade)"

di _n as txt "--- Is the trend non-linear? (quadratic term) ---"
svy, subpop(insamp): logit attend c.t10##c.t10
testparm c.t10#c.t10

di _n as txt "--- Overall wave differences (Wald) ---"
svy, subpop(insamp): logit attend i.wave
testparm i.wave

di _n as txt "--- Period contrasts ---"
svy, subpop(insamp): logit attend i.period3, or

log close L03
