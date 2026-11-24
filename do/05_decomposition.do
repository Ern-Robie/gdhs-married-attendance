*==============================================================================
* 05_decomposition.do - Decomposition of the change in attendance between periods
*
* Groups are set in 00_master.do (FG0 = early surveys, FG1 = late surveys).
* (1) Two-way decomposition of the gap from survey-weighted logit models, with
*     late-period and early-period reference coefficients.
* (2) Fairlie (1999, 2005) detailed decomposition (-fairlie-).
* (3) Linear-probability Oaxaca-Blinder decomposition (-oaxaca-), with pooled
*     reference coefficients and PSU-clustered standard errors.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L05
log using "$LOG/05_decomposition.log", replace text name(L05)

use "$OUT/gdhs_pooled.dta", clear
replace cc = 0 if missing($WQ)
do "$DO/_make_dummies.do"

* Decomposition covariates: education enters as secondary or higher versus none or
* primary. A separate primary dummy is perfectly predicted in the early group
* (no uneducated woman attends), so the two lower categories are combined.
local _fx "$FX"
local _drop "ed_prim"
local _fxd : list _fx - _drop
global FXD "`_fxd'"
di as txt "Decomposition covariates: $FXD"

gen byte grp = .
foreach w of global FG0 {
    replace grp = 0 if wave==`w'
}
foreach w of global FG1 {
    replace grp = 1 if wave==`w'
}
tab wave grp if cc, missing

preserve
keep if cc & !missing(grp)

*------------------------------------------------------------------------------
* Descriptive: weighted means of covariates by group (compositional change)
*------------------------------------------------------------------------------
di _n as txt "--- Weighted means by group (0 = early, 1 = late) ---"
tabstat attend $FX [aweight=wt], by(grp) statistics(mean) format(%6.3f) columns(statistics)

*------------------------------------------------------------------------------
* (1) Hand-coded decomposition (weighted logit)
*------------------------------------------------------------------------------
quietly summarize attend [aweight=wt] if grp==1
scalar y1 = r(mean)
quietly summarize attend [aweight=wt] if grp==0
scalar y0 = r(mean)
scalar gap = y1 - y0

* reference = LATE-period coefficients
quietly logit attend $FXD [pweight=wt] if grp==1
quietly predict double p_b1, pr
quietly summarize p_b1 [aweight=wt] if grp==1
scalar m11 = r(mean)
quietly summarize p_b1 [aweight=wt] if grp==0
scalar m01 = r(mean)

* reference = EARLY-period coefficients
quietly logit attend $FXD [pweight=wt] if grp==0
quietly predict double p_b0, pr
quietly summarize p_b0 [aweight=wt] if grp==1
scalar m10 = r(mean)
quietly summarize p_b0 [aweight=wt] if grp==0
scalar m00 = r(mean)

di _n as txt "Late-period attendance (weighted)  : " %6.4f y1
di as txt     "Early-period attendance (weighted) : " %6.4f y0
di as txt     "Gap (late - early)                 : " %6.4f gap
di _n as txt  "Reference = LATE coefficients:  explained = " %6.4f (m11-m01) ///
              "  (" %4.1f 100*(m11-m01)/gap "% of gap);  unexplained = " %6.4f (y1-y0)-(m11-m01)
di as txt     "Reference = EARLY coefficients: explained = " %6.4f (m10-m00) ///
              "  (" %4.1f 100*(m10-m00)/gap "% of gap);  unexplained = " %6.4f (y1-y0)-(m10-m00)
di as txt "Differences between the two lines = index-number problem; report both or the average."

*------------------------------------------------------------------------------
* (2) Fairlie detailed decomposition
*------------------------------------------------------------------------------
* -fairlie- has no seed() option; the seed is set before each call so that the
* random matching is reproducible.
di _n as txt "--- Fairlie decomposition (weighted) ---"
set seed 20261108
capture noisily fairlie attend $FXD [pweight=wt], by(grp) reps(100)
if _rc {
    di as err "Weighted fairlie failed (rc=" _rc "); running the unweighted version."
    set seed 20261108
    capture noisily fairlie attend $FXD, by(grp) reps(100)
    if _rc {
        di as err "fairlie failed (rc=" _rc ")."
    }
}
di as txt "fairlie convention: Difference = group 0 minus group 1 (early - late); negative"
di as txt "contributions therefore explain an increase in attendance. Reference coefficients: group 0."
restore

*------------------------------------------------------------------------------
* (3) Linear-probability Oaxaca-Blinder decomposition
*     'swap' makes the difference late - early; pooled coefficients are the reference.
*------------------------------------------------------------------------------
svyset psu [pweight=wt], strata(strata) singleunit(centered)
keep if cc & !missing(grp)
* Probability weights with PSU-clustered standard errors
capture noisily oaxaca attend $FXD [pweight=wt], by(grp) pooled swap vce(cluster psu)
if _rc {
    di as err "oaxaca failed (rc=" _rc "); re-estimating without pooled coefficients"
    capture noisily oaxaca attend $FXD [pweight=wt], by(grp) swap vce(cluster psu)
}
log close L05
