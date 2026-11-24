*==============================================================================
* 04_models.do - Pooled survey-weighted logit, interactions and sensitivity
*
* Nested models, all fitted on the same complete-case subpopulation (cc):
*   M1  survey wave only
*   M2  + age group, residence, zone, wealth, religion
*   M3  + education, ever had a child, married before 18, cohabiting
*   M4  2014-22 versus earlier surveys, with the M3 covariates
* Education, childbearing and age at marriage may lie on the pathway between
* marriage and schooling, so M3 is an associational model.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L04
log using "$LOG/04_models.log", replace text name(L04)

use "$OUT/gdhs_pooled.dta", clear
svyset psu [pweight=wt], strata(strata) singleunit(centered)

local covs_all agegrp urban zone3 $WQ relig4 educ3 has_child early_mar cohab
local X2 i.agegrp i.urban i.zone3 i.${WQ} i.relig4
local X3 `X2' i.educ3 i.has_child i.early_mar i.cohab

* complete cases must be defined on the chosen wealth variable
replace cc = 0 if missing($WQ)
gen byte late = (wave>=2014)     // 2014-22 versus earlier surveys

*------------------------------------------------------------------------------
* A. Main models (odds ratios)
*------------------------------------------------------------------------------
eststo clear
* Adjusted models use three periods rather than six surveys because of few attenders in early surveys.
eststo m1: svy, subpop(cc): logit attend i.wave, or
eststo m2: svy, subpop(cc): logit attend i.period3 `X2', or
eststo m3: svy, subpop(cc): logit attend i.period3 `X3', or
eststo m4: svy, subpop(cc): logit attend i.late `X3', or

di _n as txt "--- Wald test: do period differences remain after adjustment? ---"
estimates restore m3
testparm i.period3
capture noisily estat gof, group(10)

esttab m1 m2 m3 m4 using "$TAB/table_models_or.rtf", eform b(%9.2f) ci(%9.2f) nobase label ///
    mtitles("M1 wave" "M2 period+socio-demog." "M3 +marital/fertility" "M4 2014-22 vs earlier") ///
    scalars("N_sub Subpopulation N" "df_r Design df") nonumbers varwidth(34) replace

*------------------------------------------------------------------------------
* B. Adjusted prevalence by wave and average marginal effects (M3)
*------------------------------------------------------------------------------
estimates restore m3
margins period3, subpop(cc)
marginsplot, recast(line) recastci(rcap) xtitle("Period") ytitle("Adjusted Pr(attending school)") ///
    title("Adjusted attendance probability (M3)", size(medsmall)) scheme(s1mono)
graph export "$FIG/fig4_adjusted_prevalence.png", replace width(2400)

estimates restore m3
margins, dydx(*) subpop(cc) post
eststo ame3
esttab ame3 using "$TAB/table_ame_m3.rtf", b(%9.3f) ci(%9.3f) label nobase replace

*------------------------------------------------------------------------------
* C. Do trends differ across groups?  Wave (period) x covariate interactions
*    For each moderator Z, three Wald tests of the interaction:
*      (i)   late period (2014-22 vs earlier) x Z
*      (ii)  period3 x Z
*      (iii) wave x Z (may not be estimable with sparse cells; see 06_firth.do)
*------------------------------------------------------------------------------
tempname T
postfile `T' str12 moderator double(p_late p_period p_wave) using "$TAB/interaction_tests.dta", replace

foreach z in urban zone3 educ3 agegrp wq3 {
    local zz `z'
    local oth : list covs_all - zz
    local oth : subinstr local oth "$WQ" "wq3", all
    * the wealth variable enters as wq3; the moderator itself is removed
    local oth : list oth - zz
    local oth : list uniq oth
    local spec
    foreach v of local oth {
        local spec `spec' i.`v'
    }
    local p1 = .
    local p2 = .
    local p3 = .

    capture noisily {
        svy, subpop(cc): logit attend i.late##i.`z' `spec'
        testparm i.late#i.`z'
        local p1 = r(p)
    }
    capture noisily {
        svy, subpop(cc): logit attend i.period3##i.`z' `spec'
        testparm i.period3#i.`z'
        local p2 = r(p)
        margins period3#`z', subpop(cc)
        marginsplot, xdimension(period3) title("Adjusted Pr(attending) by period and `z'", size(small)) scheme(s1mono)
        graph export "$FIG/fig5_period_x_`z'.png", replace width(2400)
    }
    capture noisily {
        svy, subpop(cc): logit attend i.wave##i.`z' `spec'
        testparm i.wave#i.`z'
        local p3 = r(p)
    }
    post `T' ("`z'") (`p1') (`p2') (`p3')
}
postclose `T'
preserve
use "$TAB/interaction_tests.dta", clear
format p_* %6.4f
list, noobs sep(0)
export delimited using "$TAB/interaction_tests.csv", replace
restore

*------------------------------------------------------------------------------
* D. Sensitivity analyses (M3 specification, OR for wave shown in the table)
*------------------------------------------------------------------------------
eststo clear
eststo s0: svy, subpop(cc): logit attend i.period3 `X3', or

* S1 region (10) instead of zone (3)
local X3_reg i.agegrp i.urban i.region10 i.${WQ} i.relig4 i.educ3 i.has_child i.early_mar i.cohab
eststo s1: svy, subpop(cc): logit attend i.period3 `X3_reg', or

* S2 DHS within-survey wealth quintile instead of pooled PCA
local X3_dhs i.agegrp i.urban i.zone3 i.wq_dhs i.relig4 i.educ3 i.has_child i.early_mar i.cohab
capture noisily eststo s2: svy, subpop(if cc & !missing(wq_dhs)): logit attend i.period3 `X3_dhs', or

* S3 strict outcome: currently attending (hv121==1) where that code exists
capture noisily eststo s3: svy, subpop(if cc & !missing(attend_cur)): logit attend_cur i.period3 `X3', or

* S4 household-member weight instead of women's weight
svyset psu [pweight=wt_hh], strata(strata) singleunit(centered)
capture noisily eststo s4: svy, subpop(if cc & !missing(wt_hh)): logit attend i.period3 `X3', or
svyset psu [pweight=wt], strata(strata) singleunit(centered)

* S5 unweighted, cluster-robust
eststo s5: logit attend i.period3 `X3' if cc, vce(cluster psu) or

* S6 drop women aged 15-17 (compulsory-age schooling; ages may be misreported)
eststo s6: svy, subpop(if cc & v012>=18): logit attend i.period3 `X3', or

esttab s0 s1 s2 s3 s4 s5 s6 using "$TAB/table_sensitivity.rtf", eform b(%9.2f) ci(%9.2f) nobase ///
    keep(*.period3) label mtitles("Main" "Region10" "DHS wealth" "hv121=1" "HH weight" "Unweighted" "Age 18+") ///
    nonumbers replace
log close L04
