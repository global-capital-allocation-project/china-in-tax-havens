***************************************************
* SETUP
***************************************************

* THIS CODE READS THE PUBLIC RESTATEMENT MATRICES AND HOLDINGS BY RESIDENCY (CPIS and TIC)
* AND COMPUTE THE AMOUNTS HELD BY RESIDENCY THAT IS CHINESE UNDER NATIONALITY
* OUTPUT IS FIGURE 1C AND 1D

qui do Project_globals.do
cap log close
cap mkdir "$ccdms1/logs"
log using "$ccdms1/logs/holdings_chinese_assets", text replace

***************************************************
* FIG 1c: Holdings Equities
***************************************************

* Change Methodology from encoded to string for merge
use "$ccdms1/raw/gcap/Restated_Bilateral_External_Portfolios", clear
decode Methodology, gen(temp)
drop Methodology
rename temp Methodology
save $ccdms1/temp/Restated_Bilateral_External_Portfolios, replace

use "$ccdms1/raw/gcap/Restatement_Matrices.dta", clear
gen tax_haven = 0
replace tax_haven = 1 if inlist(Destination, $tax_haven_1) | inlist(Destination, $tax_haven_2) | inlist(Destination, $tax_haven_3)
replace tax_haven = 1 if inlist(Destination, $tax_haven_4) | inlist(Destination, $tax_haven_5) | inlist(Destination, $tax_haven_6)
replace tax_haven = 1 if inlist(Destination, $tax_haven_7) | inlist(Destination, $tax_haven_8) 
* keep if TH or onshore
keep if (tax_haven == 1 & Destination_Restated == "CHN") |  (Destination == "CHN" & Destination_R == "CHN")
rename tax_haven offshore
decode Methodology, gen(temp)
drop if Investor == "World" | Investor == "AUS" // keep dm9 ex AUS
* decision: use enhanced when available (USA and NOR)
keep if (Asset_Class_Code == "E" & !inlist(Investor,"USA","NOR") & temp =="Fund Holdings") | (Investor == "NOR" & Asset_Class_Code == "E" & temp == "Enhanced Fund Holdings")  ///
| (Investor == "USA" & Asset_Class_Code == "E" & temp == "Enhanced Fund Holdings") 
drop Methodology
rename temp Methodology
replace Asset_Class_Code = "EF" if Investor != "USA"
qui mmerge Methodology Year Investor Asset_Class_Code Destination using $ccdms1/temp/Restated_Bilateral_External_Portfolios, ///
umatch(Methodology Year Investor Asset_Class_Code Issuer) ukeep(Position_Residency Estimated_Common_Equity) unmatched(m)
assert _merge == 3
drop if Investor == "EMU" & Destination == "LUX"
assert Estimated_Common_Equity != . if Investor != "USA" & Destination != "CHN"
replace Position_Residency = Estimated_Common_Equity if Investor != "USA" & Destination != "CHN"
gen Position = Position_Residency * Value
replace Destination = "OTH" if !inlist(Destination,"CHN","CYM","HKG","BMU","VGB")
collapse (sum) Position, by(Year Destination offshore)
replace Position = Position/1e3
drop offshore
reshape wide Position, i(Year) j(Destination, string)
* for figure: 
order Year PositionCYM  PositionBMU PositionVGB PositionOTH PositionHKG PositionCHN
cap drop PositionCum*
foreach location in  "BMU" "VGB" "OTH" "HKG" "CHN" {
* cumulative sum
qui egen PositionCum`location' = rowtotal(PositionCYM-Position`location')
}
 * plot rarea
tw (area PositionCYM Year) ///
(rarea PositionCYM PositionCumBMU Year) ///
(rarea PositionCumBMU PositionCumVGB Year) ///
(rarea PositionCumVGB PositionCumOTH Year) ///
(rarea PositionCumOTH PositionCumHKG Year, lcolor(gs3) lwidth(vthin) lpattern(solid) fcolor("145 200 240")) ///
(rarea PositionCumHKG PositionCumCHN Year, lcolor(gs3) lwidth(vthin) lpattern(solid) fcolor(gray%70)), ///
xlabel(2007(1)2020, labsize(small)) xtitle("") graphregion(margin(1 10 1 4)) ///
legend(order(1 "Cayman Islands" 2 "Bermuda" 3 "British Virgin Islands" 4 "Other Tax Havens" 5 "Hong Kong" 6 "China") cols(3))ytitle("USD Billions" " ", size(small))  ylab(,labsize(small) angle(horizontal))

graph export "$ccdms1/output/geo_level_equity.pdf", replace as(pdf)


***************************************************
* FIG 1d: Holdings All Bonds
***************************************************

* Start from restatement matrices (online, public file)
use "$ccdms1/raw/gcap/Restatement_Matrices.dta", clear
gen tax_haven = 0
replace tax_haven = 1 if inlist(Destination, $tax_haven_1) | inlist(Destination, $tax_haven_2) | inlist(Destination, $tax_haven_3)
replace tax_haven = 1 if inlist(Destination, $tax_haven_4) | inlist(Destination, $tax_haven_5) | inlist(Destination, $tax_haven_6)
replace tax_haven = 1 if inlist(Destination, $tax_haven_7) | inlist(Destination, $tax_haven_8) 
* keep if TH or onshore
keep if (tax_haven == 1 & Destination_Restated == "CHN") |  (Destination == "CHN" & Destination_Re == "CHN")
rename tax_haven offshore
decode Methodology, gen(temp)
drop if Investor == "World" | Investor == "AUS" // keep dm9 ex AUS
* decision: use enhanced when available (USA corporates and NOR)
keep if (Asset_Class_Code == "B" & !inlist(Investor,"USA","NOR") & temp =="Fund Holdings") | (Investor == "NOR" & Asset_Class_Code == "B" & temp == "Enhanced Fund Holdings")  ///
| (Investor == "USA" & Asset_Class_Code == "BC" & temp == "Enhanced Fund Holdings") | (Investor == "USA" & inlist(Asset_Class_Code,"BG","BSF") & temp == "Fund Holdings")
drop Methodology
rename temp Methodology
* merge with Positions
mmerge Methodology Year Investor Asset_Class_Code Destination using $ccdms1/temp/Restated_Bilateral_External_Portfolios, ///
umatch(Methodology Year Investor Asset_Class_Code Issuer) ukeep(Position_Residency) unmatched(m)
drop _merge
gen Position = Position_Residency * Value
replace Destination = "OTH" if !inlist(Destination,"CHN","CYM","HKG","BMU","VGB")
collapse (sum) Position, by(Year Destination offshore)
replace Position = Position/1e3
drop offshore
reshape wide Position, i(Year) j(Destination, string)
* for figure
order Year PositionCYM  PositionBMU PositionVGB PositionOTH PositionHKG PositionCHN
cap drop PositionCum*
foreach location in  "BMU" "VGB" "OTH" "HKG" "CHN" {
* cumulative sum
qui egen PositionCum`location' = rowtotal(PositionCYM-Position`location')
}
 * plot rarea
tw (area PositionCYM Year) ////
(rarea PositionCYM PositionCumBMU Year) ///
(rarea PositionCumBMU PositionCumVGB Year) ///
(rarea PositionCumVGB PositionCumOTH Year) ///
(rarea PositionCumOTH PositionCumHKG Year, lcolor(gs3) lwidth(vthin) lpattern(solid) fcolor("145 200 240")) ///
(rarea PositionCumHKG PositionCumCHN Year, lcolor(gs3) lwidth(vthin) lpattern(solid) fcolor(gray%70)), ///
xlabel(2007(1)2020, labsize(small)) xtitle("") graphregion(margin(1 10 1 4))  ///
legend(order(1 "Cayman Islands" 2 "Bermuda" 3 "British Virgin Islands" 4 "Other Tax Havens" 5 "Hong Kong" 6 "China") cols(3)) ytitle("USD Billions" " ", size(small))  ylab(,labsize(small) angle(horizontal))

graph export "$ccdms1/output/geo_level_bonds.pdf", replace as(pdf)

cap log close
