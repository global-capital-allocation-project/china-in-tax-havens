***************************************************
* SETUP
***************************************************

qui do Project_globals.do
cap log close
cap mkdir "$ccdms1/logs"
log using "$ccdms1/logs/figures_curr", text replace

***************************************************
* FIGURES BY CURRENCY
***************************************************

global output $ccdms1/output
set scheme gcap

use "$ccdms1/holdings/china_nationality_th_analysis.dta", clear // output of Append_MS_Data.do
qui drop if investor == "CHN" // drop chinese domestic investments
qui drop if investor == "HKG" // also drop Hong Kong funds

* Keep the 8 countries of interest then Pool all countries
qui keep if inlist(investor,"USA","CHE","CAN","DNK","SWE","NOR","GBR") | inlist(investor,$eu1) | inlist(investor,$eu2) | inlist(investor,$eu3)
qui replace investor = "ROW" 

* Take expansive definition of CNH rather than CNY
gen temp = substr(isin,1,2)
gen HK=0
replace HK=1 if temp=="HK" & currency=="CNY" & regexm(asset_class,"Bond")
replace currency = "CNH" if HK==1

qui drop if mi(currency)
collapse (sum) marketvalue_usd, by(year investor asset_class currency)

* reshape from long to wide for easier operations
egen id = group(year currency)
qui replace asset_class = "eqty" if asset_class == "Equities"
qui replace asset_class = "corp" if asset_class == "Corporate Bonds"
qui replace asset_class = "govt" if asset_class == "Government Bonds"
qui replace asset_class = "other" if asset_class == "Other Bonds"
ren marketvalue_usd mv_
qui reshape wide mv_, i(id) j(asset_class) string

* all bonds
qui egen mv_all_bonds = rowtotal(mv_corp mv_govt mv_other)

* generate total
bys year: egen mv_total = sum(mv_all_bonds)

* keep important currencies
qui replace currency = "Other" if !inlist(currency, "USD", "EUR", "CNY", "CNH", "HKD")
collapse (sum) mv_all_bonds (first) mv_total, by(year currency)
gsort year -mv_all_bonds

* reshape to wide again to use `rarea'
ren mv_all_bonds mv_all_bonds_
qui reshape wide mv_all_bonds_, i(year) j(currency) string    
graph bar (asis) mv_all_bonds_USD mv_all_bonds_EUR mv_all_bonds_CNY mv_all_bonds_CNH mv_all_bonds_HKD mv_all_bonds_Other if year >= 2014, ///
over(year) stack percent bar(5, lpattern(solid)) bar(6, lpattern(solid) lcolor(bluishgray) fcolor(bluishgray)) ylab(, angle(horizontal)) ///
ytitle("Percentage" " ") legend(label(1 "USD") label(2 "EUR") label(3 "CNY") label(4 "CNH") label(5 "HKD") label(6 "Other") rows(1))
graph export "$output/curr_share_pool_ms_all_bonds_2014.pdf", replace

cap log close
