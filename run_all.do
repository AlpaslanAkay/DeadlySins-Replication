* Deadly Sins? Religion and the Marginal Utility of Income
* Run this do-file from the replication package's top-level directory.
* Edit SOEP_DIR if the licensed SOEP files are stored elsewhere.
version 17
set more off
set type double
capture log close _all

global SOEP_DIR "/Users/xakaal/Dropbox/Data/SOEP_v40/SOEP_v40/soepdata"
global ROOT "`c(pwd)'"
global OUTDIR "$ROOT/output"

capture mkdir "$ROOT/data"
capture mkdir "$ROOT/output"

* Construct intermediate SOEP data; then reproduce every manuscript table.
do "$ROOT/code/00_build_soep_2023.do"
do "$ROOT/code/01_estimate_tables.do"
