*==============================================================================
* _make_dummies.do  -  explicit 0/1 dummies for user-written commands
* (fairlie, firthlogit and oaxaca need plain variables, not factor notation).
* Called after the pooled file has been loaded.
* Reference categories: age 15-19, urban, coastal, no education, lowest wealth
* group, Christian. Defines the globals FX (covariates), WQD (wealth dummies),
* RELD (religion dummies), PD (period dummies) and WD (survey dummies).
*==============================================================================
gen byte age20_24 = (agegrp==2)        if !missing(agegrp)
gen byte rural    = (urban==0)         if !missing(urban)
gen byte z_mid    = (zone3==2)         if !missing(zone3)
gen byte z_north  = (zone3==3)         if !missing(zone3)
gen byte ed_prim  = (educ3==1)         if !missing(educ3)
gen byte ed_sec   = (educ3==2)         if !missing(educ3)
* wealth dummies for the 3-group (wq3) or 5-group (wq_pca) variable; lowest level = reference
quietly levelsof ${WQ}, local(_wl)
local _wfirst : word 1 of `_wl'
local _wd
foreach q of local _wl {
    if `q' != `_wfirst' {
        gen byte wqd`q' = (${WQ}==`q') if !missing(${WQ})
        local _wd `_wd' wqd`q'
    }
}
global WQD "`_wd'"
* religion: 'other' dummy only if that category is present
gen byte rel_mus  = (relig4==2)        if !missing(relig4)
gen byte rel_trad = (relig4==3)        if !missing(relig4)
global RELD "rel_mus rel_trad"
quietly count if relig4==4
if r(N)>0 {
    gen byte rel_oth = (relig4==4) if !missing(relig4)
    global RELD "$RELD rel_oth"
}
gen byte child    = has_child

global FX "age20_24 rural z_mid z_north $WQD $RELD ed_prim ed_sec child early_mar cohab"

* periods (1993-98 = reference, 2003-08, 2014-22) and a late-period indicator
gen byte per2 = (period3==2) if !missing(period3)
gen byte per3 = (period3==3) if !missing(period3)
gen byte late = (wave>=2014)
global PD "per2 per3"

quietly levelsof wave, local(_ws)
local _first : word 1 of `_ws'
global WD ""
foreach w of local _ws {
    if `w' != `_first' {
        gen byte w`w' = (wave==`w')
        global WD $WD w`w'
    }
}
