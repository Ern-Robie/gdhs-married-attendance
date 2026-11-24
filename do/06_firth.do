*==============================================================================
* 06_firth.do - Firth penalised-likelihood robustness check for sparse data
*
* Few married women attend school in the early surveys, so some survey-by-
* covariate cells have few or no events, which can lead to (quasi-)separation in
* maximum-likelihood logit. Firth's penalised likelihood gives finite estimates.
* -firthlogit- is not a survey command and does not accept probability weights;
* the estimates are therefore unweighted and serve as a check on the
* design-based results of 04_models.do.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L06
log using "$LOG/06_firth.log", replace text name(L06)

use "$OUT/gdhs_pooled.dta", clear
replace cc = 0 if missing($WQ)
keep if cc
do "$DO/_make_dummies.do"
svyset psu [pweight=wt], strata(strata) singleunit(centered)

*------------------------------------------------------------------------------
* A. Diagnose sparsity: attenders per dummy (events-per-variable)
*------------------------------------------------------------------------------
quietly count if attend==1
di as txt _n "Total attenders in cc sample: " r(N) "; parameters in full model: " `: word count $PD $FX' + 1
di as txt "--- Attenders per category (flag < 10) ---"
foreach v of global PD {
    quietly count if `v'==1 & attend==1
    di as txt %-12s "`v'" "  events = " r(N)
}
foreach v of global FX {
    quietly count if `v'==1 & attend==1
    di as txt %-12s "`v'" "  events = " r(N)
}

*------------------------------------------------------------------------------
* B. Main model: ML logit vs Firth vs survey logit (odds ratios)
*------------------------------------------------------------------------------
eststo clear
eststo L_unw: logit attend $PD $FX, or
eststo F_unw: firthlogit attend $PD $FX, or
eststo L_svy: svy: logit attend $PD $FX, or

esttab L_unw F_unw L_svy using "$TAB/table_firth_main.rtf", eform b(%9.2f) ci(%9.2f) nobase ///
    keep($PD) mtitles("ML logit" "Firth" "Survey logit") nonumbers replace

* coefficient plot of wave ORs across estimators (visual robustness check)
coefplot (L_unw, label("ML logit")) (F_unw, label("Firth")) (L_svy, label("Survey logit")), ///
    keep($PD) eform xline(1) xtitle("Odds ratio vs 1993-98 (log scale)") xscale(log) ///
    legend(rows(1)) scheme(s1mono)
graph export "$FIG/fig6_firth_vs_ml.png", replace width(2400)

*------------------------------------------------------------------------------
* C. Interactions with linear time under Firth (one moderator at a time)
*    'late' = 2014-22 versus earlier surveys; the joint test of the interaction terms is reported.
*------------------------------------------------------------------------------
local mod1 "rural"
local mod2 "z_mid z_north"
local mod3 "ed_sec"
local mod4 "$WQD"
local mod5 "age20_24"
local lab1 "residence"
local lab2 "zone"
local lab3 "education"
local lab4 "wealth"
local lab5 "age group"

local FXl "$FX"
forvalues i = 1/5 {
    local ints
    foreach m of local mod`i' {
        capture drop latex`m'
        gen double latex`m' = late*`m'
        local ints `ints' latex`m'
    }
    local oth : list FXl - mod`i'
    local _dp "ed_prim"
    if `i'==3 local oth : list oth - _dp   // education as secondary+ versus none/primary
    di _n as txt "=== Firth: late period (2014-22) x `lab`i'' ==="
    capture noisily {
        firthlogit attend late `mod`i'' `ints' `oth', or
        test `ints'
    }
    di as txt "--- same model, ML logit with cluster-robust SEs, for comparison ---"
    capture noisily {
        logit attend late `mod`i'' `ints' `oth', vce(cluster psu) or
        test `ints'
    }
}

log close L06
