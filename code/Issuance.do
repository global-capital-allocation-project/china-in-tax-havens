***************************************************
* SETUP
***************************************************

* THIS CODE PRODUCES FIGURE 1 GRAPHS BY USING THE ISSUANCE EQUITY AND CORPORATE BONDS RAW FILES
* AND COMPUTE THE SHARE OF TOTAL TAX HAVEN ISSUANCE ACROSS TIME 
* OUTPUT IS FIGURE 1A AND 1B

qui do Project_globals.do
cap log close
cap mkdir "$ccdms1/logs"
log using "$ccdms1/logs/issuance_figures", text replace

*Install packages/programs 
net install grc1leg,from( http://www.stata.com/users/vwiggins/) 

* Bracket creation program
cap program drop graph_bracket
program define graph_bracket
    * Parse arguments
    local ymin = `1'
    local ymax = `2'
    local bracket_text = `"`3'"'
    * More parameters
    local b_width = .04
    local xx = .6
    local brace_height = `ymax' - `ymin'
    local xax_h = 40
    local beta = 300/`brace_height'
    local res_param = 1000
    * Calculations
    local res = int(`res_param')*2+1
    local mid_p = int(`res_param')+1
    local y_mid = `brace_height'/2 + `ymin'
    * Set obs high enough to generate smooth bracket
    if _N<`res' {
        set obs `res'
    }
    * Generate linear y-space
    gen y = (_n-1)*`brace_height'/`res' + `ymin'
    gen y_half = y if _n <= `mid_p'
    * Calculate bottom half of brace
    gen x_half_brace = 1/(1 + exp(-`beta'*(y_half-y_half[1]))) + 1/(1 + exp(-`beta'*(y_half-y_half[`mid_p'])))
    replace x_half_brace = 0 if x_half_brace==. & _n <= `mid_p'
    gen x = x_half_brace if _n <= `mid_p'
    * Fill in top half of brace symmetrically
    qui forval i = 1/`mid_p' {
        replace x = x[`i'] if _n==(`res'+1-`i')
    }
    * Set end points
    replace x = .5 if _n==1  
    replace x = 1.5 if _n==`mid_p'
    replace x = .5 if _n==`res'
    * Rescale to flatten bracket
    replace x = `xx' + (`b_width' * x - .2) * `xax_h'
    * Calculate text coordinates 
    local text_point_x = `xx' + (`b_width' * 1.5 - .2) * `xax_h' + 0.3
    local text_point_y = `y_mid'
    local plot_end = `text_point_x' + .2
    * Plot
    twoway line y x , lcolor(black) ylabel(,nogrid nolabel notick) xlabel(,labcol(white) tlcol(white) nogrid) yscale(lstyle(none)) xscale(lstyle(none) range(0 `plot_end')) ytitle("") xtitle("") fxsize(10) text(`text_point_y' `text_point_x'  "`bracket_text'" , placement(e)) name(bracket , replace) 
end


***************************************************
* FIG 1a: Issuance Equities
***************************************************

* Import equity issuance data; see Coppola et al. (2021, QJE) for details and code on the construction of these data
use "$ccdms1/raw/issuance/equity_issuance_master", clear
rename (cgs_domicile country_bg marketcap_usd) (residency nationality value)
keep if inlist(residency, $tax_haven_1) | inlist(residency, $tax_haven_2) | inlist(residency, $tax_haven_3) | inlist(residency, $tax_haven_4) | inlist(residency, $tax_haven_5) | inlist(residency, $tax_haven_6) | inlist(residency, $tax_haven_7) | inlist(residency, $tax_haven_8)
drop if !inrange(year,2002,2020)
drop if residency == "HKG"
drop if residency==nationality
replace residency = "OTH" if ~inlist(residency, "CYM", "BMU", "VGB")
replace nationality = "OTH" if nationality!="CHN"

collapse (sum) value , by(year nationality residency)
replace nationality = "_" + nationality
reshape wide value , i(year residency) j(nationality) str
replace residency = "_" + residency
reshape wide value* , i(year) j(residency) str

egen chn_total = rowtotal(value_CHN_*)
egen oth_total = rowtotal(value_OTH_*)
gen all_total = chn_total + oth_total

*Generate cumulative sums of below residencies for the figure 
gen cumulative_sum = 0
foreach th in CYM BMU VGB OTH {
    gen sh_CHN_`th' = (value_CHN_`th' / all_total) 
    gen sh_CHN_`th'_plot = (value_CHN_`th' / all_total) + cumulative_sum
    replace cumulative_sum = cumulative_sum + (value_CHN_`th' / all_total)
}

*Label country names
label var sh_CHN_CYM_plot "Cayman Islands"
label var sh_CHN_BMU_plot "Bermuda"
label var sh_CHN_VGB_plot "British Virgin Islands"
label var sh_CHN_OTH_plot "Other Tax Havens"

save "$ccdms1/temp/issuance_fig_equity_data.dta" , replace
export excel "$ccdms1/temp/issuance_fig_equity_data", replace firstrow(variables)

*Produce the main figure
tw (area sh_CHN_CYM_plot year) ///
(rarea sh_CHN_CYM_plot sh_CHN_BMU_plot year) ///
(rarea sh_CHN_BMU_plot sh_CHN_VGB_plot year) ///
(rarea sh_CHN_VGB_plot sh_CHN_OTH_plot year), xlab(2002(2)2020) ylab(0 "0%" .1 "10%" .2 "20%" .3 "30%" .4 "40%" .5 "50%" .6 "60%" ,angle(0)) xtitle("") ytitle("Share of Total TH Issuance") graphregion(margin(1 10 1 4)) name(pp_issuance_fig_equity , replace) ///
legend(order(1 "Cayman Islands" 2 "Bermuda" 3 "British Virgin Islands" 4 "Other Tax Havens")) 
local y_end = sh_CHN_OTH_plot[_N]
graph_bracket 0 `y_end' "\$2.4 trn"

*Add the brackets to the right
grc1leg pp_issuance_fig_equity bracket , ycommon imargin(0 6 0 0) legendfrom(pp_issuance_fig_equity)
graph export "$ccdms1/output/pp_issuance_fig_equity.pdf", as(pdf) replace

***************************************************
* FIG 1b : Issuance Bonds
***************************************************

* Import bond issuance data; see Coppola et al. (2021, QJE) for details and code on the construction of these data
use "$ccdms1/raw/issuance/dealogic_factset_issuance_timeseries.dta", clear
keep if is_corp == 1
rename (value_cur_adj) (value)
keep if inlist(residency, $tax_haven_1) | inlist(residency, $tax_haven_2) | inlist(residency, $tax_haven_3) | inlist(residency, $tax_haven_4) | inlist(residency, $tax_haven_5) | inlist(residency, $tax_haven_6) | inlist(residency, $tax_haven_7) | inlist(residency, $tax_haven_8)
drop if year<2002
drop if residency == "HKG"
drop if residency==nationality

replace residency = "OTH" if ~inlist(residency, "CYM", "BMU", "VGB")
replace nationality = "OTH" if nationality!="CHN"
collapse (sum) value , by(year nationality residency)

replace nationality = "_" + nationality
reshape wide value , i(year residency) j(nationality) str
replace residency = "_" + residency
reshape wide value* , i(year) j(residency) str

foreach var of varlist value* {
    replace `var' = 0 if missing(`var')
}

egen chn_total = rowtotal(value_CHN_*)
egen oth_total = rowtotal(value_OTH_*)
gen all_total = chn_total + oth_total

*Generate cumulative sums of below residencies for the figure 
gen cumulative_sum = 0
foreach th in CYM BMU VGB OTH {
    gen sh_CHN_`th' = (value_CHN_`th' / all_total) 
    gen sh_CHN_`th'_plot = (value_CHN_`th' / all_total) + cumulative_sum
    replace cumulative_sum = cumulative_sum + (value_CHN_`th' / all_total)
}

*Label country names
label var sh_CHN_CYM_plot "Cayman Islands"
label var sh_CHN_BMU_plot "Bermuda"
label var sh_CHN_VGB_plot "British Virgin Islands"
label var sh_CHN_OTH_plot "Other Tax Havens"

save "$ccdms1/temp/issuance_fig_corp_bonds_data.dta", replace
export excel "$ccdms1/temp/issuance_fig_corp_bonds_data", replace firstrow(variables)

*Produce the main figure
tw (area sh_CHN_CYM_plot year) ///
(rarea sh_CHN_CYM_plot sh_CHN_BMU_plot year) ///
(rarea sh_CHN_BMU_plot sh_CHN_VGB_plot year) ///
(rarea sh_CHN_VGB_plot sh_CHN_OTH_plot year), xlab(2002(2)2020) ///
    ylab(0 "0%" .04 "4%" .08 "8%" .12 "12%" .16 "16%" .2 "20%", angle(0)) xtitle("") ytitle("Share of Total TH Issuance") ///
    graphregion(margin(1 10 1 4)) legend(order(1 "Cayman Islands" 2 "Bermuda" 3 "British Virgin Islands" 4 "Other Tax Havens")) name(pp_issuance_fig_corp_bonds , replace) 

local y_end = sh_CHN_OTH_plot[_N]

*Add the brackets to the right
graph_bracket 0 `y_end' "\$0.6 trn"
grc1leg pp_issuance_fig_corp_bonds bracket , ycommon imargin(0 6 0 0) legendfrom(pp_issuance_fig_corp_bonds)
graph export "$ccdms1/output/pp_issuance_fig_corp_bonds.pdf", as(pdf) replace

cap log close
