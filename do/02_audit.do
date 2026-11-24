*==============================================================================
* 02_audit.do - Audit of the pooled file before modelling
* Participant flow (STROBE item 13), missingness by survey, raw hv121 codes,
* IR/PR consistency, weight and design diagnostics, harmonisation checks.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L02
log using "$LOG/02_audit.log", replace text name(L02)

use "$OUT/gdhs_pooled.dta", clear
datasignature confirm
duplicates report wave caseid

*------------------------------------------------------------------------------
* A. Participant flow by wave  (STROBE 13a)
*------------------------------------------------------------------------------
gen byte one      = 1
gen byte ev_samp  = (attend==1) & insamp
gen byte ev_cc    = (attend==1) & cc
gen byte tgt_nopr = tgt & !flag_pr
preserve
collapse (sum) n_women=one n_pr=flag_pr n_1524=in1524 n_tgt=tgt n_tgt_nopr=tgt_nopr ///
    n_outcome=insamp n_cc=cc ev_samp ev_cc, by(wave)
gen pct_outcome_missing = 100*(n_tgt - n_outcome)/n_tgt
gen pct_attend_samp     = 100*ev_samp/n_outcome
format pct_* %5.1f
list wave n_women n_pr n_1524 n_tgt n_tgt_nopr n_outcome n_cc ev_samp ev_cc pct_*, noobs sep(0)
export delimited using "$TAB/audit_flow.csv", replace
forvalues i = 1/`=_N' {
    if ev_samp[`i'] < 20 di as err "WARNING wave " wave[`i'] ": only " ev_samp[`i'] " attenders (<20): sparse-data risk (see 06_firth.do)"
    if pct_outcome_missing[`i'] > 5 di as err "WARNING wave " wave[`i'] ": >5% of target women lack hv121"
}
restore

*------------------------------------------------------------------------------
* B. Raw hv121 codes among target women (is the outcome defined the same way?)
*------------------------------------------------------------------------------
di _n as txt "--- hv121 raw codes, target women (0 no / 1 current / 2 any time this school yr / 8,9 DK) ---"
tab hv121_raw wave if tgt, col missing
di as txt "--- Both outcome versions by wave (unweighted) ---"
tab wave attend     if tgt, row
tab wave attend_cur if tgt, row missing

*------------------------------------------------------------------------------
* C. Missingness by wave (share missing among target women) - 1 = always missing
*------------------------------------------------------------------------------
local chk attend hv121_raw agegrp urban region10 zone3 educ3 relig4 wq_dhs wq_pca has_child early_mar cohab wt_hh psu strata
foreach v of local chk {
    gen byte m_`v' = missing(`v')
}
di _n as txt "--- Share missing, target women, by wave ---"
tabstat m_*, by(wave) statistics(mean) format(%5.3f) nototal columns(variables)
drop m_*

*------------------------------------------------------------------------------
* D. Consistency of IR vs PR information
*------------------------------------------------------------------------------
gen int agediff = v012 - hv105 if flag_pr & !missing(hv105)
di _n as txt "--- IR age (v012) minus PR age (hv105): number of mismatches by wave ---"
bysort wave: count if agediff!=0 & !missing(agediff)
di as txt "--- IR marital status (v501) vs PR (hv115) among target women ---"
tab v501 hv115 if tgt & flag_pr, missing
drop agediff

*------------------------------------------------------------------------------
* E. Weights
*------------------------------------------------------------------------------
di _n as txt "--- Women's weight among target women, by wave ---"
tabstat wt if tgt, by(wave) statistics(n mean min max sum) format(%9.3f)

*------------------------------------------------------------------------------
* F. Survey design: PSUs, strata, single-PSU strata
*------------------------------------------------------------------------------
egen byte ptag = tag(psu)
egen byte stag = tag(strata)
di _n as txt "--- Number of PSUs and strata per wave (full IR sample) ---"
tab wave if ptag
tab wave if stag
bysort strata: egen npsu = total(ptag)
di as txt "--- PSUs in strata with only 1 PSU (expected: none) ---"
tab wave if ptag & npsu==1
egen byte ptag_s = tag(psu) if insamp
bysort strata: egen npsu_s = total(ptag_s)
di as txt "--- Strata with <2 PSUs once restricted to target women (hence -svy, subpop()- rather than -if-) ---"
tab wave if stag & npsu_s<2
drop ptag stag npsu ptag_s npsu_s

svyset psu [pweight=wt], strata(strata) singleunit(centered)
svydescribe attend if insamp

*------------------------------------------------------------------------------
* G. Harmonisation checks
*------------------------------------------------------------------------------
di _n as txt "--- Region (10 harmonised) by wave, target women ---"
tab region10 wave if tgt, col nofreq
di as txt "--- Religion by wave ---"
tab relig4 wave if tgt, col nofreq missing
di as txt "--- Wealth: pooled-PCA quintile by wave (weighted, all target women) ---"
tab wq_pca wave if tgt [aweight=wt], col nofreq
di as txt "--- Wealth: DHS v190 quintile by wave (should be ~20% each within wave) ---"
tab wq_dhs wave if tgt [aweight=wt], col nofreq missing
di as txt "--- Agreement between the two wealth measures ---"
tab wq_dhs wq_pca if tgt, row
di as txt "--- Fieldwork month by wave (school-year timing of hv121) ---"
tab int_month wave if tgt, col

*------------------------------------------------------------------------------
* H. Target women excluded between 'outcome observed' and 'complete cases'
*------------------------------------------------------------------------------
di _n as txt "--- Complete-case vs outcome-observed target women ---"
tab wave cc if insamp, row
di as txt "--- Attendance prevalence (unweighted %), complete cases vs others, by wave ---"
tabstat attend if insamp, by(wave) statistics(mean n) format(%6.3f)
tabstat attend if insamp & cc==0, by(wave) statistics(mean n) format(%6.3f)

*------------------------------------------------------------------------------
* I. Sparse cells (events per category) for the full model
*------------------------------------------------------------------------------
di _n as txt "--- Attenders per category (cc sample): categories with fewer than 10 attenders indicate sparse cells ---"
foreach v in agegrp urban zone3 educ3 relig4 wq_pca has_child early_mar cohab wave {
    di as txt _n "variable: `v'"
    tab `v' if cc & attend==1
}
log close L02
