*==============================================================================
* 08_additional_analyses.do - Supplementary analyses
*
* R1   Weighted pooled prevalence, design degrees of freedom, PSU/strata ids
* R2   2022 vs 2014 contrast, 2008-2014-2022 series, pairwise period contrasts
* R3   Education as a mediator; prior attainment net of the current school year
* R4   Never-married comparison group
* R5   Level of school attended, interview timing, residence status
* R6   Current pregnancy and age of the youngest child
* R7   Bounds for the invalid attendance code (hv121 = 9) in 2003 and 2008
* R8   Fairlie decomposition (random ordering), early vs late period
* R9   Fairlie and Oaxaca-Blinder decompositions, 2014 vs 2022
* R10  Coding of hv110 / hv121 by education in 1993-98
*
* Requires 00_master.do and 01_build.do to have been run.
* Each block is wrapped in -capture noisily- so one failure does not stop the rest.
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L08
log using "$LOG/08_additional_analyses.log", replace text name(L08)

do "$DO/_load_extra.do"
local X2 i.agegrp i.urban i.zone3 i.${WQ} i.relig4
local X3 `X2' i.educ3 i.has_child i.early_mar i.cohab

*------------------------------------------------------------------------------
* R1. Weighted pooled prevalence, overall and by period; design df
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R1. Weighted pooled prevalence ==="
    svy, subpop(insamp): proportion attend
    svy, subpop(insamp): proportion attend, over(period3)
    svy, subpop(insamp): proportion attend, over(period2)
    di "Design df:"
    svy, subpop(cc): logit attend i.wave `X3'
    di "df_r = " e(df_r) "   strata = " e(N_strata) "   PSUs = " e(N_psu)
    * PSU and strata identifiers must not be shared across surveys
    preserve
    keep if insamp
    bysort psu (wave): gen byte _bad = (wave[1]!=wave[_N])
    quietly count if _bad
    di "PSU ids shared across waves: " r(N)
    bysort strata (wave): replace _bad = (wave[1]!=wave[_N])
    quietly count if _bad
    di "Strata ids shared across waves: " r(N)
    restore
}

*------------------------------------------------------------------------------
* R2. 2014 vs 2022, 2008-2014-2022 series, pairwise period contrasts
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R2a. 2022 vs 2014 ==="
    svy, subpop(if cc & inlist(wave,2014,2022)): logit attend i.w2022 `X2', or
    svy, subpop(if cc & inlist(wave,2014,2022)): logit attend i.w2022 `X3', or
    di _n "=== R2b. 2008-2014-2022 series (hv121 code 2 only) ==="
    svy, subpop(if cc & wave>=2008): logit attend ib2008.wave `X3', or
    testparm i.wave
    di _n "=== R2c. Pairwise period contrasts from M3 ==="
    svy, subpop(cc): logit attend ib2014.period3 `X3'
    lincom 1.period3, or     // 1993-98 vs 2014-22
    lincom 2.period3, or     // 2003-08 vs 2014-22
    svy, subpop(cc): logit attend ib2.period3 `X3'
    lincom 3.period3, or     // 2014-22 vs 2003-08
    di _n "=== R2d. 2022 against each earlier survey (M3) ==="
    svy, subpop(cc): logit attend ib2022.wave `X3'
    foreach w in 1993 1998 2003 2008 2014 {
        lincom `w'.wave, or
    }
    di _n "=== R2e. 2022 vs the pooled earlier surveys ==="
    gen byte pre2017 = (wave<=2014) if !missing(wave)
    svy, subpop(cc): logit attend i.pre2017 `X3', or
}

*------------------------------------------------------------------------------
* R3. Education as a mediator; prior attainment net of the current school year
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R3a. Period estimates with and without education ==="
    svy, subpop(if cc & wave>=2008): logit attend i.w2022 `X2' i.has_child i.early_mar i.cohab, or
    svy, subpop(if cc & wave>=2008): logit attend i.w2022 `X3', or
    svy, subpop(cc): logit attend i.period3 `X2' i.has_child i.early_mar i.cohab, or
    svy, subpop(cc): logit attend i.period3 `X3', or

    di _n "=== R3b. Prior attainment net of the current year (2008-2022) ==="
    * hv122: 0 none/pre-school, 1 primary, 2 secondary, 3 higher
    gen byte educ_prior = educ3
    replace educ_prior = 0 if attend==1 & hv122==1
    replace educ_prior = 1 if attend==1 & hv122==2
    replace educ_prior = 2 if attend==1 & hv122==3
    tab educ3 educ_prior if insamp & wave>=2008, missing
    svy, subpop(if cc & wave>=2008 & !missing(educ_prior)): logit attend i.w2022 `X2' i.educ_prior i.has_child i.early_mar i.cohab, or

    di _n "=== R3c. Women who had completed primary before this school year ==="
    svy, subpop(if cc & wave>=2008 & educ_prior>=1): logit attend i.w2022 `X2' i.has_child i.early_mar i.cohab, or
}

*------------------------------------------------------------------------------
* R4. Never-married comparison group (women 15-24, same surveys)
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R4. Union status by period ==="
    svy, subpop(if ins1524 & !missing(union_st)): proportion attend, over(union_st wave)
    svy, subpop(if ins1524 & !missing(union_st)): proportion attend, over(union_st period2)
    svy, subpop(nm_cc): logit attend i.union_st##i.period2 i.agegrp i.urban i.zone3 i.${WQ} i.relig4, or
    margins union_st#period2, subpop(nm_cc)
    margins period2, dydx(union_st) subpop(nm_cc)
    testparm i.union_st#i.period2
    svy, subpop(if nm_cc & wave>=2008): logit attend i.union_st##i.w2022 i.agegrp i.urban i.zone3 i.${WQ} i.relig4, or
    margins union_st#w2022, subpop(if nm_cc & wave>=2008)
}

*------------------------------------------------------------------------------
* R5. Level of school attended, interview timing, residence status
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R5a. Level currently attended among attenders (2008-2022) ==="
    tab hv122 wave if insamp & attend==1, col
    svy, subpop(if insamp & attend==1 & wave>=2008): tab hv122 period2, col count
    tab hv122 agegrp if insamp & attend==1, col
    di _n "=== R5b. Attendance by level (weighted % of all married women 15-24) ==="
    foreach L in 1 2 3 {
        gen byte att_L`L' = (attend==1 & hv122==`L') if insamp & wave>=2008
        svy, subpop(if insamp & wave>=2008): proportion att_L`L', over(wave)
    }
    di _n "=== R5c. Interview month by survey ==="
    tab int_month wave if insamp
    di _n "=== R5d. De facto residents and visitors in the analytic sample ==="
    tab hv103 wave if insamp, col
}

*------------------------------------------------------------------------------
* R6. Current pregnancy and age of the youngest child
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R6. Pregnancy and age of the youngest child ==="
    gen byte pregnant = (v213==1) if inlist(v213,0,1)
    gen int  ageyc_m  = v008 - b3_01 if !missing(b3_01) & !missing(v008)
    gen byte yc_grp = 0 if has_child==0
    replace  yc_grp = 1 if has_child==1 & ageyc_m<12
    replace  yc_grp = 2 if has_child==1 & inrange(ageyc_m,12,35)
    replace  yc_grp = 3 if has_child==1 & ageyc_m>=36 & !missing(ageyc_m)
    tab yc_grp wave if insamp, col
    svy, subpop(if cc & !missing(pregnant,yc_grp)): logit attend i.period3 `X2' i.educ3 i.yc_grp i.pregnant i.early_mar i.cohab, or
    tab early_mar agegrp if cc, col
    tab early_mar if cc & inrange(v012,15,17)
    tab early_mar if cc & inrange(v012,18,19)
}

*------------------------------------------------------------------------------
* R7. Bounds for the invalid attendance code (hv121 = 9), 2003 and 2008
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R7. Bounds analysis (hv121 == 9) ==="
    gen byte att_lo = attend
    gen byte att_hi = attend
    replace att_lo = 0 if hv121_raw==9 & tgt
    replace att_hi = 1 if hv121_raw==9 & tgt
    di "Lower bound (all code-9 women not attending):"
    svy, subpop(if tgt & inlist(wave,2003,2008)): proportion att_lo, over(wave)
    di "Upper bound (all code-9 women attending):"
    svy, subpop(if tgt & inlist(wave,2003,2008)): proportion att_hi, over(wave)
    di "Unweighted counts:"
    tab wave hv121_raw if tgt & inlist(wave,2003,2008), missing
}

*------------------------------------------------------------------------------
* R8. Fairlie decomposition with random ordering of covariates
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R8. Fairlie, random ordering (early vs late period) ==="
    preserve
    gen byte grp = .
    foreach w of global FG0 {
        replace grp = 0 if wave==`w'
    }
    foreach w of global FG1 {
        replace grp = 1 if wave==`w'
    }
    global FXD "age20_24 rural z_mid z_north $WQD $RELD ed_sec child early_mar cohab"
    keep if cc & !missing(grp)
    set seed 20261108
    fairlie attend $FXD [pweight=wt], by(grp) reps(100) ro
    restore
}
capture restore

*------------------------------------------------------------------------------
* R9. Decompositions restricted to 2014 (group 0) and 2022 (group 1)
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R9. Fairlie and Oaxaca-Blinder, 2014 vs 2022 ==="
    preserve
    keep if cc & inlist(wave,2014,2022)
    gen byte grp = (wave==2022)
    global FXD "age20_24 rural z_mid z_north $WQD $RELD ed_sec child early_mar cohab"
    set seed 20261108
    capture noisily fairlie attend $FXD [pweight=wt], by(grp) reps(100) ro
    capture noisily oaxaca attend $FXD [pweight=wt], by(grp) pooled swap vce(cluster psu)
    restore
}
capture restore

*------------------------------------------------------------------------------
* R10. Coding of hv110 / hv121 by education in 1993-98
*------------------------------------------------------------------------------
capture noisily {
    di _n "=== R10. hv110 / hv121 by education ==="
    tab hv121_raw educ3 if tgt & wave<=1998, missing col
    tab hv110 educ3 if tgt & wave<=1998, missing col
    tab hv121_raw educ3 if tgt & wave>=2003, missing col
}

log close L08
