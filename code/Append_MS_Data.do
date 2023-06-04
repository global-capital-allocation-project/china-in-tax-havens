***************************************************
* SETUP
***************************************************

qui do Project_globals.do
cap log close
cap mkdir "$ccdms1/logs"
log using "$ccdms1/logs/append_ms_data", text replace


***************************************************
* Appending estimates based on Morningstar data
***************************************************

clear all 
forvalues year=2014/2020 {
    append using "$ccdms1/temp/china_nationality_th_`year'.dta" // outputs of ms_data.do
    rm "$ccdms1/temp/china_nationality_th_`year'.dta"
}

save "$ccdms1/holdings/china_nationality_th_analysis.dta" , replace
   
cap log close
