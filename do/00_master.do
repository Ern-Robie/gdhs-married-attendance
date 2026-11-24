*==============================================================================
* 00_master.do
* Replication code for:
*   "Women in the Classroom: Three Decades of School Attendance Among Married
*    Women in Ghana"
* Robert Naatey Angmor, University of Cape Coast
*
* Data: Ghana Demographic and Health Surveys 1993, 1998, 2003, 2008, 2014, 2022
*       (person recode PR and individual recode IR files, Stata format).
*       The DHS files cannot be redistributed; download them from
*       https://dhsprogram.com and place the unzipped .DTA files in raw/.
*
* Usage: set Stata's working directory to the project folder (the folder that
*        contains do/, raw/ and README.md), then run:  do do/00_master.do
*==============================================================================
version 17.0
clear all
set more off
set linesize 120
set seed 20261108

*------------------------------------------------------------------------------
* 1. Paths (all relative to the project folder)
*------------------------------------------------------------------------------
global ROOT "`c(pwd)'"
capture confirm file "$ROOT/do/00_master.do"
if _rc {
    di as err "Set the working directory to the project folder (the one containing do/ and raw/)."
    exit 601
}
global RAW "$ROOT/raw"
global DO  "$ROOT/do"
global OUT "$ROOT/data"
global TAB "$ROOT/tables"
global FIG "$ROOT/figures"
global LOG "$ROOT/logs"
foreach d in OUT TAB FIG LOG {
    capture mkdir "${`d'}"
}

*------------------------------------------------------------------------------
* 2. Surveys and file names (file name without the .dta extension)
*------------------------------------------------------------------------------
global WAVES "1993 1998 2003 2008 2014 2022"

global PR_1993 "GHPR31FL"
global IR_1993 "GHIR31FL"
global PR_1998 "GHPR41FL"
global IR_1998 "GHIR41FL"
global PR_2003 "GHPR4BFL"
global IR_2003 "GHIR4BFL"
global PR_2008 "GHPR5AFL"
global IR_2008 "GHIR5AFL"
global PR_2014 "GHPR72FL"
global IR_2014 "GHIR72FL"
global PR_2022 "GHPR8CFL"
global IR_2022 "GHIR8CFL"

*------------------------------------------------------------------------------
* 3. Analysis settings
*------------------------------------------------------------------------------
global WQ  "wq3"               // wealth variable in the models: three-group pooled-PCA index
                               // (alternatives: wq_pca, five groups; wq_dhs, DHS v190)
global FG0 "1993 1998"         // decomposition: early-period surveys
global FG1 "2014 2022"         // decomposition: late-period surveys

*------------------------------------------------------------------------------
* 4. User-written packages
*------------------------------------------------------------------------------
foreach p in estout coefplot firthlogit fairlie oaxaca {
    capture which `p'
    if _rc ssc install `p', replace
}

*------------------------------------------------------------------------------
* 5. Run the pipeline
*------------------------------------------------------------------------------
do "$DO/00_inventory.do"
do "$DO/01_build.do"
do "$DO/02_audit.do"
do "$DO/03_trends.do"
do "$DO/04_models.do"
do "$DO/05_decomposition.do"
do "$DO/06_firth.do"
do "$DO/07_table1.do"
do "$DO/08_additional_analyses.do"
do "$DO/09_robustness_checks.do"
