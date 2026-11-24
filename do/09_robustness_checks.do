*==============================================================================
* 09_robustness_checks.do - Robustness and supplementary checks
*
* B1  2022 versus 1993 with 1993 as the reference category; sparse cells; Firth
* B2  Never-married comparison: ratio scale, risk difference, age-specific
*     models, finer age bands, sample sizes
* B3  Never-married attendance by survey and age group
* B4  Junior versus senior high school among attenders
* B5  Oaxaca-Blinder decompositions with Yun (2005) normalisation
* B6  Pregnancy and age of the youngest child
* B7  Minimum detectable interaction odds ratios
*
* Requires 00_master.do and 01_build.do to have been run.
* Subsets are taken with -svy, subpop()- rather than -keep- so that the design
* degrees of freedom are preserved. Each block is wrapped in -capture noisily-.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close LOC
log using "$LOG/09_robustness_checks.log", replace text name(LOC)

do "$DO/_load_extra.do"

local X2 i.agegrp i.urban i.zone3 i.${WQ} i.relig4
local X3 `X2' i.educ3 i.has_child i.early_mar i.cohab
di _n as txt "Analysis sample: " _c
count if cc
di as txt "Attenders in the analysis sample: " _c
count if cc & attend==1

*==============================================================================
* B1  2022 versus 1993 with 1993 as the reference category
*==============================================================================
capture noisily {
    di _n "=== B1a. Attenders by education, each survey (sparse-cell report) ==="
    tab wave educ3 if insamp & attend==1, row
    tab wave educ3 if insamp, row
    di _n "=== B1b. M3 with 1993 as reference: the 2022 coefficient is the 2022 vs 1993 OR ==="
    svy, subpop(cc): logit attend ib1993.wave `X3'
    lincom 2022.wave, or
    lincom 2022.wave-1998.wave, or
    di _n "=== B1c. Unadjusted odds ratios ==="
    svy, subpop(insamp): logit attend ib1993.wave, or
    di _n "=== B1d. M3 with 2022 as reference ==="
    svy, subpop(cc): logit attend ib2022.wave `X3', or
    di _n "=== B1e. Unweighted logit, 1993-98 only ==="
    capture noisily logit attend `X3' if cc & wave<=1998
    di _n "=== B1f. Firth, all surveys, 1993 as reference (unweighted) ==="
    capture noisily firthlogit attend $WD $FX if cc, or
}
capture restore

*==============================================================================
* B2  Never-married comparison: ratio scale, risk difference,
*   age-specific models, sample sizes and events
*==============================================================================
capture noisily {
    di _n "=== B2a. Sample sizes and events ==="
    di "All surveys (1993-2022), nm_cc:"
    count if nm_cc
    count if nm_cc & attend==1
    di "2008-2022 series, nm_cc:"
    count if nm_cc & wave>=2008
    count if nm_cc & wave>=2008 & attend==1
    di "by union status, 2008-2022:"
    tab union_st attend if nm_cc & wave>=2008, row
    tab union_st attend if nm_cc, row

    di _n "=== B2b. Ratio scale (Poisson, design-based SEs): 2008-22 series, 2022 vs 2008-14 ==="
    svy, subpop(if nm_cc & wave>=2008): poisson attend i.union_st##i.w2022 ///
        i.agegrp i.urban i.zone3 i.${WQ} i.relig4, irr
    di _n "=== B2c. Ratio scale: 2014-22 vs 1993-2008 ==="
    svy, subpop(nm_cc): poisson attend i.union_st##i.period2 ///
        i.agegrp i.urban i.zone3 i.${WQ} i.relig4, irr
    di _n "=== B2d. Risk-difference scale (linear probability, design-based SEs) ==="
    svy, subpop(if nm_cc & wave>=2008): regress attend i.union_st##i.w2022 ///
        i.agegrp i.urban i.zone3 i.${WQ} i.relig4
    svy, subpop(nm_cc): regress attend i.union_st##i.period2 ///
        i.agegrp i.urban i.zone3 i.${WQ} i.relig4

    di _n "=== B2e. Age-specific: women aged 20-24 only (2008-22 and all surveys) ==="
    svy, subpop(if nm_cc & agegrp==2 & wave>=2008): poisson attend i.union_st##i.w2022 ///
        i.urban i.zone3 i.${WQ} i.relig4, irr
    svy, subpop(if nm_cc & agegrp==2): poisson attend i.union_st##i.period2 ///
        i.urban i.zone3 i.${WQ} i.relig4, irr
    svy, subpop(if nm_cc & agegrp==2 & wave>=2008): regress attend i.union_st##i.w2022 ///
        i.urban i.zone3 i.${WQ} i.relig4
    di _n "=== B2f. Finer age bands (15-17, 18-19, 20-22, 23-24) in place of the 2-group age ==="
    tab ageband union_st if nm_cc & wave>=2008
    svy, subpop(if nm_cc & wave>=2008 & !missing(ageband)): poisson attend i.union_st##i.w2022 ///
        i.ageband i.urban i.zone3 i.${WQ} i.relig4, irr
    svy, subpop(if nm_cc & wave>=2008 & !missing(ageband)): logit attend i.union_st##i.w2022 ///
        i.ageband i.urban i.zone3 i.${WQ} i.relig4, or
    di _n "=== B2g. Weighted attendance by union status, age group and survey (2008-22) ==="
    svy, subpop(if nm_cc & wave>=2008): proportion attend, over(union_st agegrp w2022)
}
capture restore

*==============================================================================
* B3  Never-married attendance by survey and age group
*==============================================================================
capture noisily {
    di _n "=== B3a. Never-married women, weighted attendance by survey and age group ==="
    svy, subpop(if ins1524 & mstat==0 & wave>=2003): proportion attend, over(wave agegrp)
    di _n "=== B3b. Same, 'currently attending' only (hv121==1), where the code exists ==="
    svy, subpop(if ins1524 & mstat==0 & wave>=2003): proportion attend_cur, over(wave agegrp)
    di _n "=== B3c. Raw codes, never-married 15-24 ==="
    tab hv121_raw wave if ins1524 & mstat==0 & wave>=2003, col missing
    di _n "=== B3d. Interview month, never-married, 2008 vs 2014 vs 2022 ==="
    tab int_month wave if ins1524 & mstat==0 & wave>=2008, col
}

*==============================================================================
* B4  Junior versus senior high school among attenders
*==============================================================================
capture noisily {
    di _n "=== B4a. Level attended, married attenders, by survey ==="
    tab hv122 wave if insamp & attend==1 & wave>=2003, col
    di _n "=== B4b. Years of education completed (hv108) by level (hv122), 2014 and 2022 ==="
    tab hv108 hv122 if insamp & attend==1 & wave==2014
    tab hv108 hv122 if insamp & attend==1 & wave==2022
    di _n "=== B4c. Ghana school level from years completed (hv108) ==="
    * primary = grades 1-6 (completed 0-5), JHS = grades 7-9 (completed 6-8),
    * SHS = grades 10-12 (completed 9-11), post-secondary/tertiary = completed 12+
    gen byte lvl_gh = .
    replace lvl_gh = 1 if inrange(hv108,0,5)  & attend==1
    replace lvl_gh = 2 if inrange(hv108,6,8)  & attend==1
    replace lvl_gh = 3 if inrange(hv108,9,11) & attend==1
    replace lvl_gh = 4 if inrange(hv108,12,25) & attend==1
    label define lg 1 "Primary" 2 "JHS" 3 "SHS" 4 "Post-secondary+"
    label values lvl_gh lg
    tab lvl_gh wave if insamp & attend==1 & wave>=2008, col
    tab lvl_gh hv122 if insamp & attend==1 & wave>=2008, row
    di _n "=== B4d. Weighted % of ALL married women 15-24 attending each Ghana level ==="
    forvalues L = 1/4 {
        gen byte att_gh`L' = (lvl_gh==`L') if insamp & wave>=2008
        svy, subpop(if insamp & wave>=2008): proportion att_gh`L', over(wave)
    }
}

*==============================================================================
* B5  Oaxaca-Blinder decompositions with Yun (2005) normalisation
*   Contributions of the dummy sets (zone, wealth, religion) do not depend on the
*   omitted category. -oaxaca- categorical() requires each set to include its
*   base-category dummy; sets are separated by commas.
*==============================================================================
capture noisily {
    di _n "=== B5a. Oaxaca-Blinder, 2014 vs 2022, Yun-normalised dummy sets ==="
    quietly levelsof ${WQ}, local(_wl)
    local _wf : word 1 of `_wl'
    gen byte z_coast = (zone3==1)      if !missing(zone3)
    gen byte wq_ref  = (${WQ}==`_wf')  if !missing(${WQ})
    gen byte rel_chr = (relig4==1)     if !missing(relig4)
    global FXD "age20_24 rural z_mid z_north $WQD $RELD ed_sec child early_mar cohab"
    preserve
    keep if cc & inlist(wave,2014,2022)
    gen byte grp = (wave==2022)
    capture noisily oaxaca attend $FXD [pweight=wt], by(grp) pooled swap vce(cluster psu) ///
        categorical(z_coast z_mid z_north, wq_ref $WQD, rel_chr $RELD)
    restore
    di _n "=== B5b. Same for 1993-2008 vs 2014-22 ==="
    preserve
    gen byte grp = .
    foreach w of global FG0 {
        replace grp = 0 if wave==`w'
    }
    foreach w of global FG1 {
        replace grp = 1 if wave==`w'
    }
    keep if cc & !missing(grp)
    capture noisily oaxaca attend $FXD [pweight=wt], by(grp) pooled swap vce(cluster psu) ///
        categorical(z_coast z_mid z_north, wq_ref $WQD, rel_chr $RELD)
    restore
}
capture restore

*==============================================================================
* B6  Pregnancy and age of the youngest child
*==============================================================================
capture noisily {
    di _n "=== B6. Pregnancy and age of the youngest child ==="
    gen byte pregnant = (v213==1) if inlist(v213,0,1)
    gen int  ageyc_m  = v008 - b3_01 if !missing(b3_01) & !missing(v008)
    gen byte yc_grp = 0 if has_child==0
    replace  yc_grp = 1 if has_child==1 & ageyc_m<12
    replace  yc_grp = 2 if has_child==1 & inrange(ageyc_m,12,35)
    replace  yc_grp = 3 if has_child==1 & ageyc_m>=36 & !missing(ageyc_m)
    svy, subpop(if cc & !missing(pregnant,yc_grp)): logit attend i.period3 `X2' ///
        i.educ3 i.yc_grp i.pregnant i.early_mar i.cohab, or
    di "Subpopulation n   = " e(N_sub)
    count if cc & !missing(pregnant,yc_grp)
    count if cc & !missing(pregnant,yc_grp) & attend==1
    di _n "--- age and early marriage ---"
    tab early_mar agegrp if cc, col
    tab early_mar if cc & inrange(v012,15,17)
    tab early_mar if cc & inrange(v012,18,19)
}

*==============================================================================
* B7  Minimum detectable interaction odds ratio (80% power, 5% level)
*   MDE OR = exp(2.80 x SE) of the late-period x moderator interaction.
*==============================================================================
capture noisily {
    di _n "=== B7. Minimum detectable interaction OR = exp(2.80 x SE) ==="
    local wqv "${WQ}"
    foreach m in urban agegrp zone3 `wqv' educ3 {
        quietly svy, subpop(cc): logit attend i.late##i.`m' `X3'
        di as txt "Moderator `m':"
        local cn : colnames e(b)
        foreach t of local cn {
            if strpos("`t'","1.late#")>0 & strpos("`t'","b.")==0 {
                di as txt "   `t'   SE = " %6.3f _se[`t'] "   MDE OR = " %6.2f exp(2.80*_se[`t'])
            }
        }
    }
}

log close LOC
