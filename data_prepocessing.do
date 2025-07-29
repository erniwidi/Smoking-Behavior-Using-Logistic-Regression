**Data preprocessing
** Import Individual Demographic Data
clear all
set more off 
global datadir "D:\Perokok\Dataset" // Folder
use "D:\Perokok\Dataset\bk_ar1.dta", clear  // File

* Merge with residence data
merge m:1 hhid14 using "D:\Perokok\Dataset\bk_sc1.dta"
keep if _merge == 3
drop _merge

* Merge with smoking data
merge m:1 pidlink using "D:\Perokok\Dataset\b3b_km.dta"
keep if _merge == 3
drop _merge

* Save individual data
save "D:\Perokok\Dataset\Data Individu.dta", replace


** Import household consumption
clear all
set more off 
global datadir "D:\Perokok\Dataset" 
use "D:\Perokok\Dataset\b1_ks1.dta", clear

* Aggregate food expenditure (Rp)
collapse (sum) ks02 , by(hhid14) // per week

* Save household consumption data
save "D:\Perokok\Dataset\Data Konsumsi.dta", replace


** Merge individual data and household data
clear all
set more off 
global datadir "D:\Perokok\Dataset" // Folder

use "D:\Perokok\Dataset\Data Individu.dta", clear 
merge m:1 hhid14 using "D:\Perokok\Dataset\Data Konsumsi.dta"
keep if _merge == 3
drop _merge

* Data Cleaning
* Needed variables
keep hhid14_9 hhid14 pidlink ar07 ar09 ar15c ar13 ar16 sc01_14_14 sc05 km04 ks02
keep if sc01_14_14 == 34 // DIY Resident


* Handle duplicate data
* Convert unique variables to numeric
encode pidlink, generate(Individu)
sum Individu
sort Individu
	
* Drop duplicate
duplicates report Individu
duplicates list Individu
duplicates drop Individu, force


** Rename variable
* Smoking
gen smoking = 0 if km04 == 3
replace smoking = 1 if km04 == 1

label define smoking 0 "Not/Quit Smoking" 1 "Smoking"
label value smoking smoking

* Gender
gen gender = 0 if ar07 == 3
replace gender =1 if ar07 == 1
	
label define gender 0 "Female" 1 "Male"
label value gender gender

* Age
gen age = cond(ar09 >= 15 & ar09 <= 35, 1, ///
            cond(ar09 >= 36 & ar09 <= 55, 2, ///
            cond(ar09 >= 56 & ar09 <= 75, 3, ///
            cond(ar09 >= 76, 4, .))))
	
label define age 1 "15-35" 2 "36-55" 3 "56-75" 4 "diatas 75"
label value age age

* Education
gen education = . // Initialization of education variable with missing values

foreach val of numlist 01 02 11 72 {
    replace education = 1 if ar16 == `val'
}

foreach val of numlist 03 04 12 73 {
    replace education = 2 if ar16 == `val'
}

foreach val of numlist 05 06 15 74 {
    replace education = 3 if ar16 == `val'
}

foreach val of numlist 13 61 62 63 60 {
    replace education = 4 if ar16 == `val'
}

replace education = 0 if ar16 == 01 // The first row, outside the loop, because it will be overwritten by the first loop
	
label define education 0 "Not in School" 1 "Primary School" 2 "High School" 3 "Senior High School" 4 "University"
label value education education

* Occupation
gen employed = cond(ar15c == 01, 1, 0)
replace employed = 0 if inlist(ar15c, 02, 03, 04, 05, 06, 07, 98)
	
label define employed 0 "Unemployed" 1 "Employed"
label value employed employed

* Marital Status
gen marital_status = cond(ar13 == 2, 1, 0)
replace marital_status = 0 if inlist(ar13, 1, 3, 4, 5)

label define marital_status 0 "Not Married/Divorced" 1 "Married"
label value marital_status marital_status

* Residence
gen residence = 0 if sc05 == 2
replace residence = 1 if sc05 == 1
	
label define residence 0 "Rural" 1 "Urban"
label value residence residence

* Food Expenditure
gen food_expenditure = ks02*4 // per month
	
* Determining the poverty line (Below = Low, Above = High)
gen expenditure = 0 if food_expenditure <= 321056 // According to BPS (Statistics Indonesia), in 2014 the poverty line in DIY (Special Region of Yogyakarta) was IDR 321,056 per capita/month.
replace expenditure = 1 if food_expenditure > 321056
	
label define expenditure 0 "Low" 1 "High"
label value expenditure expenditure

* Handle missing value
foreach var of varlist smoking gender education employed marital_status residence expenditure {
	drop if missing(`var')
}


* Save Excel
export excel using "D:\Perokok\Data Final.xls", firstrow(variables) nolabel replace


** Descriptive Analysis
foreach var of varlist smoking age gender education employed marital_status residence expenditure {
	tab `var'
}

* Statistic Analysis
logit smoking gender age education employed marital_status residence expenditure
logistic smoking gender age education employed marital_status residence expenditure

* Wald Test
foreach x in age gender education employed marital_status residence expenditure _cons {
    local wald= (_b[`x']/_se[`x'])^2
    display "Wald statistic for `x' = " %4.3f `wald'
}

* Hosmer-Lemeshow Test
estat gof, group(10)

* ROC Curve
lroc

* Classification Matrix
predict probability
generate prediction = (probability >= 0.5)
table smoking prediction
