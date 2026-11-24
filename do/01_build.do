*==============================================================================
* 01_build.do - Build the pooled analytic file
*
* Base file: the individual recode (IR, women 15-49) of each survey, with
* household-roster variables from the person recode (PR) merged in. All IR women
* are retained so that the survey design (strata, PSUs) is intact; the target
* population (married or cohabiting women aged 15-24) is flagged (tgt) and
* subsets are taken later with -svy, subpop()-.
*   Link: IR (v001 v002 v003) = PR (hv001 hv002 hvidx).
*   Region and religion are harmonised from value labels (codes differ by survey).
*   Wealth: pooled PCA on household assets common to all surveys (wq_pca, wq3)
*   and the DHS wealth quintile v190 (wq_dhs, survey-specific).
*
* Input : raw DHS PR and IR files in $RAW
* Output: $OUT/gdhs_pooled.dta
*==============================================================================
version 17.0
if "$ROOT"=="" {
    di as err "Run 00_master.do first"
    exit 198
}
capture log close L01
log using "$LOG/01_build.log", replace text name(L01)

* Variables to pull; a variable absent from a survey is created as missing and reported
local PRVARS hv001 hv002 hvidx hv005 hv104 hv105 hv110 hv115 hv121 hv206 hv207 hv208 hv209 hv210 hv211 hv212
local IRVARS caseid v001 v002 v003 v005 v006 v007 v012 v013 v021 v022 v023 v024 v025 v106 v130 v190 v201 v501 v511

tempfile pool prtmp
local first 1

foreach y of global WAVES {
    di _n as txt "=========================  WAVE `y'  ========================="
    local prf "${RAW}/${PR_`y'}.dta"
    local irf "${RAW}/${IR_`y'}.dta"
    foreach f in prf irf {
        capture confirm file "``f''"
        if _rc {
            di as err "Cannot find ``f''"
            local lst : dir "$RAW" files "*"
            di as err `"Files in RAW: `lst'"'
            exit 601
        }
    }

    *---------------------------------------------------------------- PR part
    use "`prf'", clear
    local keepv
    foreach v of local PRVARS {
        capture confirm variable `v'
        if _rc==0 local keepv `keepv' `v'
        else di as txt "  [PR `y'] not in file: `v'"
    }
    keep `keepv'
    capture confirm variable hv104
    if _rc==0 keep if hv104==2
    foreach v of local PRVARS {
        capture confirm variable `v'
        if _rc gen double `v' = .
    }
    * 1993 and 1998 PR files record school attendance in hv110
    if inlist(`y',1993,1998) {
        drop hv121
        rename hv110 hv121
    }
    isid hv001 hv002 hvidx
    save `prtmp', replace

    *---------------------------------------------------------------- IR part
    use "`irf'", clear
    local keepv
    foreach v of local IRVARS {
        capture confirm variable `v'
        if _rc==0 local keepv `keepv' `v'
        else di as txt "  [IR `y'] not in file: `v'"
    }
    keep `keepv'
    foreach v of local IRVARS {
        capture confirm variable `v'
        if _rc gen double `v' = .
    }
    gen long hv001 = v001
    gen long hv002 = v002
    gen int  hvidx = v003
    isid hv001 hv002 hvidx
    merge 1:1 hv001 hv002 hvidx using `prtmp', keep(master match) gen(_mpr)
    gen byte flag_pr = (_mpr==3)
    drop _mpr
    quietly count
    local nIR = r(N)
    quietly count if flag_pr
    di as txt "  IR women `nIR'; matched to PR roster: " r(N)

    gen int wave = `y'

    * interview timing (relevant to the school-year reference period of hv121)
    gen int int_month = v006
    gen int int_year  = v007
    replace int_year  = int_year + 1900 if int_year < 100

    * ---- weights, PSU, strata
    gen double wt    = v005/1000000
    gen double wt_hh = hv005/1000000
    gen long psu_raw = cond(!missing(v021), v021, v001)
    gen long strat_raw = v022 if !missing(v022)
    local src "v022"
    quietly count if !missing(strat_raw)
    if r(N)==0 {
        replace strat_raw = v023 if !missing(v023)
        local src "v023"
    }
    quietly count if !missing(strat_raw)
    if r(N)==0 {
        replace strat_raw = v024*10 + v025
        local src "region x residence (constructed)"
    }
    di as txt "  strata source wave `y': `src'"
    gen long psu    = `y'*100000 + psu_raw
    gen long strata = `y'*1000   + strat_raw

    * ---- age, residence, union status
    gen byte agegrp = 1 if inrange(v012,15,19)
    replace  agegrp = 2 if inrange(v012,20,24)
    gen byte urban  = (v025==1) if inlist(v025,1,2)
    gen byte mstat  = 0 if v501==0
    replace  mstat  = 1 if inlist(v501,1,2)
    replace  mstat  = 2 if inlist(v501,3,4,5)
    gen byte cohab  = (v501==2) if inlist(v501,1,2)

    * ---- region: harmonised to the 10 pre-2018 regions (new regions mapped to parent region)
    capture decode v024, gen(_reg)
    if _rc gen str30 _reg = ""
    replace _reg = lower(trim(_reg))
    foreach ch in "-" "/" "_" "." {
        replace _reg = subinstr(_reg,"`ch'"," ",.)
    }
    replace _reg = subinstr(_reg," region","",.)
    replace _reg = itrim(_reg)
    gen byte region10 = .
    replace region10 = 1  if inlist(_reg,"western","western north")
    replace region10 = 2  if _reg=="central"
    replace region10 = 3  if inlist(_reg,"greater accra","accra")
    replace region10 = 4  if inlist(_reg,"volta","oti")
    replace region10 = 5  if _reg=="eastern"
    replace region10 = 6  if _reg=="ashanti"
    replace region10 = 7  if inlist(_reg,"brong ahafo","brong","bono","bono east","ahafo")
    replace region10 = 8  if inlist(_reg,"northern","savannah","north east")
    replace region10 = 9  if _reg=="upper east"
    replace region10 = 10 if _reg=="upper west"
    quietly count if missing(region10)
    if r(N)>0 {
        di as err "Unmapped region labels in wave `y':"
        tab _reg if missing(region10), missing
        exit 459
    }
    di as txt "  region label -> region10 mapping, wave `y':"
    tab _reg region10

    gen byte zone3 = 1 if inlist(region10,1,2,3,4)     // coastal
    replace  zone3 = 2 if inlist(region10,5,6,7)       // middle belt
    replace  zone3 = 3 if inlist(region10,8,9,10)      // northern

    * ---- religion from labels (codes differ across surveys)
    capture decode v130, gen(_rel)
    if _rc gen str40 _rel = ""
    replace _rel = lower(trim(_rel))
    gen byte relig4 = .
    replace relig4 = 1 if regexm(_rel,"catholic|anglican|methodist|presbyterian|protestant|pentecost|charismatic|christian|lutheran|baptist|adventist|apostolic|church|jehovah")
    replace relig4 = 2 if regexm(_rel,"islam|muslim|moslem|ahmadi")
    replace relig4 = 3 if regexm(_rel,"tradition|spiritual|no religion|none|animist|atheist")
    replace relig4 = 4 if missing(relig4) & _rel!="" & !regexm(_rel,"missing|^dk|don")
    di as txt "  religion label -> relig4 mapping, wave `y':"
    tab _rel relig4, missing

    * ---- education (DHS v106: 0 none 1 primary 2 secondary 3 higher; 8/9 missing)
    gen byte educ3 = 0 if v106==0
    replace  educ3 = 1 if v106==1
    replace  educ3 = 2 if inlist(v106,2,3)

    * ---- wealth: DHS within-survey quintile + common household assets (PR)
    gen byte wq_dhs = v190 if inrange(v190,1,5)
    gen byte elec  = hv206 if inlist(hv206,0,1)
    gen byte radio = hv207 if inlist(hv207,0,1)
    gen byte tv    = hv208 if inlist(hv208,0,1)
    gen byte fridge= hv209 if inlist(hv209,0,1)
    gen byte bike  = hv210 if inlist(hv210,0,1)
    gen byte moto  = hv211 if inlist(hv211,0,1)
    gen byte car   = hv212 if inlist(hv212,0,1)

    * ---- fertility and marriage timing
    gen byte has_child = (v201>0) if !missing(v201) & v201<90
    gen byte early_mar = (v511<18) if !missing(v511) & v511<90

    * ---- outcome
    * hv121: 0 no; 1 currently attending; 2 attended at some time this school year;
    * 8/9 don't know/missing. Primary outcome: codes 1 or 2 (attended school this
    * school year), the only definition available in every survey. Strict outcome:
    * code 1 only, where that code exists.
    gen byte hv121_raw = hv121
    gen byte attend = inlist(hv121,1,2) if inlist(hv121,0,1,2)
    quietly count if hv121==1
    if r(N)>0 gen byte attend_cur = (hv121==1) if inlist(hv121,0,1,2)
    else gen byte attend_cur = .
    di as txt "  hv121 raw codes among IR women 15-24, wave `y':"
    tab hv121_raw if inrange(v012,15,24), missing

    drop _reg _rel
    keep caseid wave int_year int_month psu strata wt wt_hh v001 v012 v013 v106 v190 v501 hv105 hv115 ///
         flag_pr agegrp urban mstat cohab region10 zone3 relig4 educ3 wq_dhs elec radio tv fridge bike ///
         moto car has_child early_mar hv121_raw attend attend_cur
    foreach v of varlist _all {
        capture label values `v'
    }
    capture label drop _all

    if `first' {
        save `pool', replace
        local first 0
    }
    else {
        append using `pool'
        save `pool', replace
    }
}

use `pool', clear

*------------------------------------------------------------------------------
* Sample flags (nothing dropped)
*------------------------------------------------------------------------------
gen byte in1524  = inrange(v012,15,24)
gen byte inunion = (mstat==1)
gen byte tgt     = in1524 & inunion                 // target population
gen byte insamp  = tgt & !missing(attend)           // outcome observed
gen byte ins1524 = in1524 & !missing(attend)        // all women 15-24 (comparison groups)

*------------------------------------------------------------------------------
* Harmonised wealth: pooled PCA on the assets present in every survey
*------------------------------------------------------------------------------
local assets elec radio tv fridge moto car
local use_assets
levelsof wave, local(ws)
foreach a of local assets {
    local ok 1
    foreach w of local ws {
        quietly count if wave==`w' & !missing(`a')
        if r(N)==0 local ok 0
    }
    if `ok' local use_assets `use_assets' `a'
    else di as txt "Asset `a' dropped from pooled PCA (absent in at least one wave)"
}
di as txt "Assets used in pooled PCA: `use_assets'"
pca `use_assets' [aweight=wt] if flag_pr, components(1)
estat loadings
predict double wscore if flag_pr, score
local a1 : word 1 of `use_assets'
quietly corr wscore `a1' [aweight=wt]
if r(rho)<0 replace wscore = -wscore          // make higher = wealthier
xtile wq_pca = wscore [pweight=wt] if flag_pr, nquantiles(5)
gen byte wq3 = 1 if inlist(wq_pca,1,2)
replace  wq3 = 2 if wq_pca==3
replace  wq3 = 3 if inlist(wq_pca,4,5)

gen byte period3 = 1 if wave<=1998
replace  period3 = 2 if inrange(wave,2003,2008)
replace  period3 = 3 if wave>=2014
gen double t10 = (wave - 1993)/10

* Complete cases for the fullest model (M3 in 04_models.do)
gen byte cc = insamp & !missing(agegrp,urban,zone3,wq_pca,relig4,educ3,has_child,early_mar,cohab)

*------------------------------------------------------------------------------
* Labels
*------------------------------------------------------------------------------
label define lb_agegrp 1 "15-19" 2 "20-24"
label define lb_urban 0 "Rural" 1 "Urban"
label define lb_zone 1 "Coastal" 2 "Middle belt" 3 "Northern"
label define lb_educ 0 "No education" 1 "Primary" 2 "Secondary+"
label define lb_relig 1 "Christian" 2 "Muslim" 3 "Traditional/none" 4 "Other"
label define lb_wq 1 "Poorest" 2 "Poorer" 3 "Middle" 4 "Richer" 5 "Richest"
label define lb_wq3 1 "Poorest 40%" 2 "Middle 20%" 3 "Richest 40%"
label define lb_yn 0 "No" 1 "Yes"
label define lb_mstat 0 "Never married" 1 "Married/cohabiting" 2 "Formerly married"
label define lb_period 1 "1993-1998" 2 "2003-2008" 3 "2014-2022"
label define lb_reg 1 "Western" 2 "Central" 3 "Greater Accra" 4 "Volta" 5 "Eastern" 6 "Ashanti" ///
    7 "Brong Ahafo" 8 "Northern" 9 "Upper East" 10 "Upper West"
label values agegrp lb_agegrp
label values urban lb_urban
label values zone3 lb_zone
label values educ3 lb_educ
label values relig4 lb_relig
label values wq_dhs wq_pca lb_wq
label values wq3 lb_wq3
label values has_child early_mar cohab attend attend_cur lb_yn
label values mstat lb_mstat
label values period3 lb_period
label values region10 lb_reg
label var attend    "Attended school this school year (hv121 = 1 or 2)"
label var attend_cur "Currently attending (hv121 = 1 only; missing where code absent)"
label var wt "Women's weight (v005/1e6)"
label var wq_pca "Wealth quintile, pooled PCA on common assets"
label var wq_dhs "Wealth quintile, DHS v190 (survey-specific)"
label var region10 "Region (10 pre-2018 regions; new regions mapped to parent)"
label var tgt "Target population: women 15-24 married/cohabiting"
label var cc "Complete cases for full model"

sort wave caseid
duplicates report wave caseid
compress
label data "Pooled GDHS IR women 15-49 with PR roster variables"
datasignature set
save "$OUT/gdhs_pooled.dta", replace
di as txt _n "Saved $OUT/gdhs_pooled.dta"
log close L01
