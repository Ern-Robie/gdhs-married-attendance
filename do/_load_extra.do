*==============================================================================
* _load_extra.do - pooled analysis file plus additional PR/IR variables
*
* Adds to gdhs_pooled.dta the variables that are not carried by 01_build.do:
*   PR: hv122 (level of education attended), hv108 (years of education),
*       hv109 (attainment), hv110 (attendance, 1993/98 coding), hv103 (slept last night)
*   IR: v213 (currently pregnant), v008 (interview date, CMC),
*       b3_01 (birth date of the youngest child, CMC), v135 (residence type)
* The merged file is saved once as $OUT/gdhs_pooled_extra.dta and reused.
* Also sets the survey design, the dummies from _make_dummies.do and the
* comparison-group variables used by 08_additional_analyses.do and
* 09_robustness_checks.do.
* Called by 08_additional_analyses.do and 09_robustness_checks.do.
*==============================================================================
capture confirm file "$OUT/gdhs_pooled_extra.dta"
if _rc {
    tempfile extra irx
    local first 1
    foreach y of global WAVES {
        use "${RAW}/${IR_`y'}.dta", clear
        foreach v in v213 v008 b3_01 v135 {
            capture confirm variable `v'
            if _rc gen double `v' = .
        }
        gen long hv001 = v001
        gen long hv002 = v002
        gen int  hvidx = v003
        keep caseid hv001 hv002 hvidx v213 v008 b3_01 v135
        save `irx', replace
        use "${RAW}/${PR_`y'}.dta", clear
        foreach v in hv122 hv108 hv109 hv110 hv103 hv104 {
            capture confirm variable `v'
            if _rc gen double `v' = .
        }
        keep if hv104==2
        keep hv001 hv002 hvidx hv122 hv108 hv109 hv110 hv103
        merge 1:1 hv001 hv002 hvidx using `irx', keep(match) nogen
        gen int wave = `y'
        if `first' {
            save `extra', replace
            local first 0
        }
        else {
            append using `extra'
            save `extra', replace
        }
    }
    use "$OUT/gdhs_pooled.dta", clear
    merge 1:1 caseid wave using `extra', keep(master match) nogen
    save "$OUT/gdhs_pooled_extra.dta", replace
}
use "$OUT/gdhs_pooled_extra.dta", clear

svyset psu [pweight=wt], strata(strata) singleunit(centered)
replace cc = 0 if missing($WQ)
do "$DO/_make_dummies.do"

* comparison group: never-married versus married/cohabiting women 15-24
gen byte union_st = mstat if inlist(mstat,0,1)
gen byte nm_cc = ins1524 & !missing(union_st,agegrp,urban,zone3,${WQ},relig4)

* two periods (1993-2008, 2014-2022) and finer age bands
gen byte period2 = 1 if wave<=2008
replace  period2 = 2 if wave>=2014
gen byte ageband = 1 if inrange(v012,15,17)
replace  ageband = 2 if inrange(v012,18,19)
replace  ageband = 3 if inrange(v012,20,22)
replace  ageband = 4 if inrange(v012,23,24)
label define ab 1 "15-17" 2 "18-19" 3 "20-22" 4 "23-24"
label values ageband ab
