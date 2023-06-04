***************************************************
* SETUP
***************************************************

macro drop _all
qui do Project_globals.do
cap log close
cap mkdir "$ccdms1/logs"
log using "$ccdms1/logs/firm_level", text replace

***************************************************
* FIRM LEVEL FIGURES
***************************************************

clear all
set linesize 225
global est_year 2020
cap restore
clear

*Clean names and add values on the string names
cap program drop clean_names
program clean_names
	replace Company = "PING AN INS GROUP" if Company == "PING AN INS GROUP CO CHINA LTD"
	replace Company = "MEITUAN DIANPING" if Company == "MEITUAN DIANPING"
	replace Company = "JD COM INC" if Company == "JD COM INC"
	replace Company = "ALIBABA GROUP" if Company == "ALIBABA GROUP HLDG LTD"
	replace Company = "TENCENT" if Company == "TENCENT HLDGS LTD"
    replace Company = "BANK OF CHINA" if Company == "BANK OF CHINA LTD, BEIJING"
    replace Company = "IND. & COM. BANK OF CHINA" if Company == "INDUSTRIAL AND COMMERCIAL BANK OF CHINA LTD, BEIJING"
    replace Company = "XINJIANG HUITONG GROUP" if Company == "XINJIANG HUITONG GROUP INC"
	replace Company = "ZOTHER" if Company == "OTH"
	
	replace Issuer = "BERMUDA" if Issuer == "BMU"
	replace Issuer = "CHINA" if Issuer == "CHN"
	replace Issuer = "CAYMAN ISLANDS" if Issuer == "CYM"
	replace Issuer = "HONG KONG" if Issuer == "HKG"
	replace Issuer = "OTHER TAX HAVENS" if Issuer == "OTH"
	replace Issuer = "SINGAPORE" if Issuer == "SGP"
    replace Issuer = "B. VIRGIN ISLANDS" if Issuer == "VGB"
end

cap program drop add_values_to_names
program add_values_to_names
    bys Issuer: egen total_issuer = total(q_N_if) 
    bys Investor: egen total_investor = total(q_N_if) 
    bys Company: egen total_company = total(q_N_if)
    bys Investor Issuer: egen total_investor_issuer = total(q_N_if)
    replace total_issuer = round(total_issuer, 1)
    tostring total_issuer, replace
    replace Issuer = Issuer + " $" + total_issuer + "B"
    *replace Investor = Investor + " $" + total_investor+ "B" 
    *replace Company = Company + " $" + total_company+ "B"
    order Investor Issuer Company
    drop country_bg
    rename q_N_if restated_position_values
end

***************************************************
* Keep relevant investor countries and restated destination
***************************************************

* Importing issuer-level collapsed estimates based on Morningstar holdings data for mutual funds and ETFs
* as well as data on US insurance companies' holdings from S&P Global Services. See Maggiori et al. (2020, JPE) 
* and Coppola et al. (2021, QJE) for details and code on the construction of these estimates
use "$ccdms1/raw/holdings/mns_issuer_summary_including_insurance", clear

*Only keep the following investors
keep if inlist(DomicileCountryId, "USA", "EMU", "GBR", "CAN")
*Only keep corporate bond and equities 
keep if (inlist(asset_class, "Bonds - Corporate", "Equity") & inlist(DomicileCountryId, "USA")) | ///
    (inlist(asset_class, "Bonds - Corporate", "Equity", "Bonds - Government", "Bonds - Sovranational", "Bonds - Structured Finance") ///
    & inlist(DomicileCountryId, "EMU", "GBR", "CAN"))


*Only keep if domicile is China or a tax haven
keep if tax_haven == 1 | cgs_domicile == "CHN"
keep if year == $est_year

gen asset_class_br = asset_class
replace asset_class_br = "E" if inlist(asset_class, "Equity")
replace asset_class_br = "B" if strpos(asset_class, "Bonds")

*Values in billions
replace marketvalue_usd = marketvalue_usd/1e9

save "$ccdms1/temp/china_sankey_summary", replace

*Save the full list of companies and market values at the investor level
preserve
keep if country_bg == "CHN"
collapse (sum) marketvalue_usd (firstnm) issuer_name_up, by(year DomicileCountryId cusip6_up_bg  asset_class)
save "$ccdms1/temp/list_of_companies.dta" , replace
restore

* Construct the theta-by-omega
use "$ccdms1/temp/china_sankey_summary", clear
collapse (sum) marketvalue_usd (firstnm) issuer_name_up, by(asset_class_br DomicileCountryId cgs_domicile country_bg cusip6_up_bg)
bys asset_class_br DomicileCountryId cgs_domicile: egen x_R_ij = total(marketvalue_usd)
gen theta_omega = marketvalue_usd / x_R_ij
keep if country_bg == "CHN"
count if missing(cusip6_up_bg)
save "$ccdms1/temp/china_sankey_theta_omegas", replace
keep DomicileCountryId asset_class_br cgs_domicile
duplicates drop DomicileCountryId asset_class_br cgs_domicile, force
rename cgs_domicile Issuer
rename DomicileCountryId Investor
save "$ccdms1/temp/china_sankey_theta_omegas_catalog", replace

***************************************************
* Estimate the values for USA (separate methodology due to use of insurance data and TIC instead of CPIS)
***************************************************

* Perform the estimation: USA, get relevant TIC values
use "$ccdms1/raw/gcap/Restated_Bilateral_External_Portfolios.dta", clear
keep if Methodology == 2 & inlist(Investor, "USA")
keep if Year == $est_year
keep if inlist(Asset_Class_Code, "E", "BC")
gen asset_class_br = Asset_Class_Code
replace asset_class_br = "B" if asset_class_br == "BC"
qui mmerge asset_class_br Investor Issuer using "$ccdms1/temp/china_sankey_theta_omegas_catalog"
assert _merge != 2 if Investor == "USA"
keep if _merge == 3
keep Investor asset_class_br Issuer Position_Residency
save "$ccdms1/temp/china_sankey_tic_vector", replace

* Perform the estimation: USA, multiply by firm shares
use "$ccdms1/temp/china_sankey_tic_vector", clear
rename Investor DomicileCountryId
rename Issuer cgs_domicile
qui mmerge DomicileCountryId asset_class_br cgs_domicile using "$ccdms1/temp/china_sankey_theta_omegas"
assert _merge == 3 if DomicileCountryId == "USA"
keep if _merge == 3
drop _merge
rename Position_Residency q_R_ij
gen q_N_if = q_R_ij * theta_omega
assert country_bg == "CHN"
bys DomicileCountryId issuer_name_up asset_class_br: egen q_N_f = total(q_N_if)
save "$ccdms1/temp/china_sankey_q_N_if", replace

***************************************************
* Estimate the values for non-USA (Equity and Bonds handled separately)
***************************************************

*EQUITIES
* Perform the estimation: non-US equities, get relevant CPIS values
use "$ccdms1/raw/gcap/Restated_Bilateral_External_Portfolios.dta", clear
keep if Methodology == 2 & inlist(Investor, "EMU", "CAN", "GBR")
keep if Year == $est_year
keep if inlist(Asset_Class_Code, "EF")
gen asset_class_br = Asset_Class_Code
replace asset_class_br = "E" if asset_class_br == "EF"
replace Position_Residency = Estimated_Common_Equity if ~missing(Estimated_Common_Equity)
qui mmerge asset_class_br Investor Issuer using "$ccdms1/temp/china_sankey_theta_omegas_catalog"
assert _merge != 2 if inlist(Investor, "EMU", "CAN", "GBR") & asset_class_br == "E"
keep if _merge == 3
keep Investor asset_class_br Issuer Position_Residency
save "$ccdms1/temp/china_sankey_cpis_equity_vector", replace

* Perform the estimation: non-US equities, multiply by firm shares
use "$ccdms1/temp/china_sankey_cpis_equity_vector", clear
rename Investor DomicileCountryId
rename Issuer cgs_domicile
qui mmerge DomicileCountryId asset_class_br cgs_domicile using "$ccdms1/temp/china_sankey_theta_omegas"
assert _merge == 3 if inlist(DomicileCountryId, "EMU", "CAN", "GBR") & asset_class_br == "E"
keep if _merge == 3
drop _merge
rename Position_Residency q_R_ij
gen q_N_if = q_R_ij * theta_omega
assert country_bg == "CHN"
bys DomicileCountryId issuer_name_up asset_class_br: egen q_N_f = total(q_N_if)
save "$ccdms1/temp/china_sankey_q_N_if_nonUS_equity", replace

*BONDS
* Perform the estimation: non-US bonds, get relevant CPIS values
use "$ccdms1/raw/gcap/Restated_Bilateral_External_Portfolios.dta", clear
keep if Methodology == 2 & inlist(Investor, "CAN", "GBR", "EMU")
keep if Year == $est_year
keep if inlist(Asset_Class_Code, "B")
gen asset_class_br = Asset_Class_Code
qui mmerge asset_class_br Investor Issuer using "$ccdms1/temp/china_sankey_theta_omegas_catalog"
assert _merge != 2 if inlist(Investor, "CAN", "GBR", "EMU") & asset_class_br == "B"
keep if _merge == 3
keep Investor asset_class_br Issuer Position_Residency
save "$ccdms1/temp/china_sankey_cpis_bonds_vector", replace

* Perform the estimation: non-US bonds, multiply by firm shares
use "$ccdms1/temp/china_sankey_cpis_bonds_vector", clear
rename Investor DomicileCountryId
rename Issuer cgs_domicile
qui mmerge DomicileCountryId asset_class_br cgs_domicile using "$ccdms1/temp/china_sankey_theta_omegas"
assert _merge == 3 if inlist(DomicileCountryId, "CAN", "GBR", "EMU") & asset_class_br == "B"
keep if _merge == 3
drop _merge
rename Position_Residency q_R_ij
gen q_N_if = q_R_ij * theta_omega
assert country_bg == "CHN"
bys DomicileCountryId issuer_name_up asset_class_br: egen q_N_f = total(q_N_if)
save "$ccdms1/temp/china_sankey_q_N_if_nonUS_bonds", replace

use "$ccdms1/temp/china_sankey_q_N_if", clear
keep if asset_class_br == "B"
keep if cgs_domicile == "CHN"
keep cusip6_up_bg issuer_name_up q_N_if q_N_f
unique cusip6_up_bg
save "$ccdms1/temp/china_sankey_us_chn_bonds_catalog", replace

append using "$ccdms1/temp/china_sankey_q_N_if_nonUS_bonds"
keep if asset_class_br == "B"
keep if cgs_domicile == "CHN"
qui mmerge cusip6_up_bg using "$ccdms1/temp/china_sankey_us_chn_bonds_catalog", uname(us_)
keep if _merge == 1
collapse (sum) q_N_f (firstnm) issuer_name_up, by(cusip6_up_bg)
gsort -q_N_f

use "$ccdms1/temp/china_sankey_q_N_if", clear
append using "$ccdms1/temp/china_sankey_q_N_if_nonUS_bonds"
append using "$ccdms1/temp/china_sankey_q_N_if_nonUS_equity"
drop q_R_ij marketvalue_usd theta_omega
* manual remove some bonds deemed non-corporate: 
drop if asset_class_br == "B" & inlist(cusip6_up_bg, "Y1R06F", "Y1456T", "Y1460S", "00890G")
gsort DomicileCountryId -q_N_if
save "$ccdms1/temp/china_sankey_firm_estimates_complete", replace

***************************************************
* PLOTTING CODE FOR SANKEY CHARTS
***************************************************

***************************************************
* Collapse observations at the issuer and company level based on number of observations to be kept and classify the rest as "OTH"
***************************************************

*keep top 5 companies for combined
use "$ccdms1/temp/china_sankey_firm_estimates_complete.dta", clear
replace q_N_if = q_N_if/1e3
replace asset_class_br = "BE"
collapse (sum) q_N_if, by(cgs_domicile country_bg DomicileCountryId issuer_name_up asset_class_br)
*Get the list of top 4 domiciles and call all the others OTH by collapsing and summing over market values
preserve
bys cgs_domicile: egen total_value = total(q_N_if)
gen inv_total_value = -total_value
egen id = group(inv_total_value)
keep if id <= 4
levelsof cgs_domicile, local(keep_tax_havens)
restore
gen th_keep = 0
foreach country of local keep_tax_havens {
    replace th_keep = 1 if cgs_domicile== "`country'"
}
replace cgs_domicile = "OTH" if th_keep == 0
collapse (sum) q_N_if, by(cgs_domicile country_bg DomicileCountryId issuer_name_up asset_class_br)
preserve
*Get the list of top 5 companies and call all the others OTH by collapsing and summing over market values 
bys issuer_name_up: egen total_value = total(q_N_if)
gen inv_total_value = -total_value
egen id = group(inv_total_value)
keep if id <= 5
levelsof issuer_name_up, local(keep_companies)
restore
gen comp_keep = 0
foreach company of local keep_companies {
    replace comp_keep = 1 if issuer_name_up== "`company'"
}
replace issuer_name_up = "OTH" if comp_keep == 0
collapse (sum) q_N_if, by(cgs_domicile country_bg DomicileCountryId issuer_name_up asset_class_br)
order DomicileCountryId cgs_domicile country_bg q_N_if
rename (DomicileCountryId cgs_domicile asset_class_br issuer_name_up) (Investor Issuer Asset_Class_Code Company)
save "$ccdms1/temp/china_sankey_firm_estimates_fig_combined", replace

***************************************************
* Saves the outputs after cleaning names and adding total investment
***************************************************

*Prepare the data for the sankey figure: clean names and add values to names
use "$ccdms1/temp/china_sankey_firm_estimates_fig_combined", clear
qui clean_names
qui add_values_to_names
export excel using "$ccdms1/output/china_sankey_firm_estimates_combined.xls", replace firstrow(variables)

cap log close
