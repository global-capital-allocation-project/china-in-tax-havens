***************************************************
* SETUP
***************************************************

qui do Project_globals.do
cap log close
cap mkdir "$ccdms1/logs"
log using "$ccdms1/logs/ms_data_`1'", text replace

***************************************************
* Filtering Morningstar holdings data
***************************************************

local year=2013+`1'

* Importing estimates based on Morningstar holdings data for mutual funds and ETFs
* See Maggiori et al. (2020, JPE) and Coppola et al. (2021, QJE) for details and code 
* on the construction of these estimates
di "processing year `year'"
use "$ccdms1/raw/holdings/HD_`year'_m_for_analysis.dta", clear
gen _temp_month = month(dofm(date_m))
keep if inlist(_temp_month,12)
drop _temp_month
drop if marketvalue ==0
drop if missing(marketvalue)
gen marketvalue_usd=marketvalue/lcu
order marketvalue marketvalue_usd
drop if marketvalue_usd==.
replace marketvalue_usd=marketvalue_usd/(10^9)

gen tax_haven = 0
replace tax_haven = 1 if inlist(cgs_domicile,$tax_haven_1) | inlist(cgs_domicile,$tax_haven_2) | inlist(cgs_domicile,$tax_haven_3)
replace tax_haven = 1 if inlist(cgs_domicile,$tax_haven_4) | inlist(cgs_domicile,$tax_haven_5) | inlist(cgs_domicile,$tax_haven_6)
replace tax_haven = 1 if inlist(cgs_domicile,$tax_haven_7) | inlist(cgs_domicile,$tax_haven_8) 

replace country_bg = cgs_domicile if tax_haven == 0
gen issuer_nationality = country_bg
replace issuer_nationality = cgs_domicile if missing(country_bg)
gen issuer_residency = cgs_domicile
gen investor = DomicileCountryId

keep if (issuer_nationality == "CHN") 
cap drop _merge

qui gen asset_class = "Equities" if class_code1 == "E"
qui replace asset_class = "Corporate Bonds" if class_code2 == "BC" | class_code3 == "BCP-C"
qui replace asset_class = "Government Bonds" if class_code2 == "BLS" | class_code2 == "BS" | class_code3 == "BCP-LS"
qui replace asset_class = "Other Bonds" if class_code1 == "B" & mi(asset_class)
drop if mi(asset_class)

gen year = year(dofm(date_m))
drop date_m

* keep relevant variables: 
keep currency year investor issuer_number isin cusip marketvalue_usd asset_class MasterPortfolioId securityname FundName  issuer_nationality	issuer_residency class_code1

* save data
save "$ccdms1/temp/china_nationality_th_`year'.dta", replace

cap log close
