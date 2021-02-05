
/* Code to compile dashboard reports and produce randomization tables 
Have to have Stata 16 and Python installed on your machine */

clear 
capture log close
set more off

global rdata "Y:\LHP\FUP\Impact Study\RData\"
global tables "Y:\LHP\FUP\Impact Study\Tables\Dashboards\"
global log "Y:\LHP\FUP\Impact Study\Do\Log\"
global do "Y:\LHP\FUP\Impact Study\Do\Dashboards\"
global cdata "Y:\LHP\FUP\Impact Study\CData\Dashboards\"
global temp "Y:\LHP\FUP\Impact Study\Temp\"
global particip "Y:\LHP\FUP\Impact Study\Randomization\Temp\Participant Lists\"
global rand "Y:\LHP\FUP\Impact Study\Randomization\"

log using "${log}DASHBOARD_COMPILE_$S_DATE.log", replace

/* HOW TO UPDATE THIS FILE
When we get a new dashboard: update global last[SITE] and lastdash variable below
When we want a new dashboard report: update today_d in Stata and Python 
*/

/* NEXT STEPS FOR DASHBOARD
Update to add "searching for housing" row mostly in Excel */

clear 

/* UPDATE THESE BEFORE RUNNING FOR NEW REPORT */
global today_m "02"
global today_d "CHANGEME"																
global today_y "2021"

global last "2021_02_05_updated" 												// What today previously was – when last dashboard was run 
global lastwa "20210126"														// For reading in most recent raw data 
global lastphx "20210201"														
global lastoc "20210131"
global lastbc "20210121"

/* Setting full dates */
global today = "${today_y}"+"_"+"${today_m}"+"_"+"${today_d}" 					// for dashboard filename
global todayrand = "${today_m}"+"/"+"${today_d}"+"/"+"${today_y}"				// for date in dashboard report 
			
*****************************************************************************
/* Pull in from randomization tool and save as .csv */
*****************************************************************************
{
// UPDATE THIS VARIABLE TODAY FOR NEW DASHBOARD REPORT 
python:
	# pull in dates from Stata
from sfi import Macro 
today = Macro.getGlobal('today')
last = Macro.getGlobal('last')								

	# Pull in participant list from randomization tool API 
import requests
import json
import pandas as pd
from datetime import datetime 

# read in token from separate file 
credentials = pd.read_csv("K:\LHP\KThomas\credentials-rafup.txt")
token = credentials['key'][0]
 
url = "https://rafup.urban.org/api/v1/paticipants-all/"
head = {'Authorization': 'token {}'.format(token)}
resp = requests.get(url, headers=head)
assert resp.status_code == 200
print(resp.headers["content-type"])

	# Convert to tabular 
data_json = resp.json()
print(len(data_json))

from pandas import json_normalize 
data_tab = json_normalize(data_json)
	# Save as CSV
now = datetime.now()

data_tab.to_csv(r'Y:\LHP\FUP\Impact Study\Randomization\Temp\Participant Lists\ParticipantAll- {}.csv'.format(now.strftime("%#d %b %Y")), index=None, header=True)  

# Save last week's dashboard with a new name 
import os
import shutil

os.chdir('Y:\LHP\FUP\Impact Study\Tables\Dashboards')
dir = os.curdir
name_last = "Dashboard_" + last + ".xlsx"
name_new = "Dashboard_" + today + ".xlsx"
shutil.copy(name_last, name_new)
end
}

/*CLEAN DATES PROGRAM*/

capture program drop clean_dates2
	program define clean_dates2
			args var new_var label 
			split `var', p("-")
			rename `var'1 year 
			rename `var'2 month 
			rename `var'3 day
			destring month day year, replace
			
			gen `new_var'=mdy(month, day, year) 
					label var `new_var' "`label'"
			assert `new_var'!=. if `var'!=""
			drop `var' month day year 
			format `new_var' %td 	
		end
		
capture program drop clean_bad_dates
program define clean_bad_dates
		args var new_var type label 
		
		replace `var' = "" if !regexm(`var',"[0-9]")							// replace with missing if all letters
		gen t = `var' if regexm(`var', "[a-zA-Z]")								// handle separately if 01jan2000 date format 
		replace `var' = "" if regexm(`var',"[a-zA-Z]")
		
		gen t2 = date(t, "DMY")
		format t2 %td 
		
		// cleaning dates to get into right format of those in entirely numeric format 
		replace `var' = subinstr(`var',"//","/",.) 						// fixing dates like 9//15/2020
		replace `var' = `var' + "-randomstring"							// fixing dates that end in YY and not YYYY
		replace `var' = regexr(`var', "/20-randomstring", "/2020")		// appending this string to be clear where the end of the string is 
		replace `var' = subinstr(`var', "-randomstring", "",.)			// then replacing /20-randomstring, then replacing that with missingness 
		
		
		gen `new_var'=date(`var', "`type'") 
		replace `new_var' = t2 if t2 != . 
		
		label var `new_var' "`label'"
		format `new_var' %td
		assert `new_var'!=. if `var'!=""
		drop `var'	t t2 
	end		
	
*****************************************************************************
/* Basic cleaning of randomization tool data */ 
*****************************************************************************
{
	
// This might break when reading in - if so delete or add a space before the $S_DATE
import delimited "${particip}ParticipantAll-$S_DATE.csv", case(lower) clear
		
	rename childwelfareid cw_id 
	replace cw_id = lower(cw_id)
	replace projectid = lower(projectid)
	gen p_id = ""
		replace p_id = projectid if site == 1 | site == 3 | site == 5 | site == 6
		replace p_id = cw_id if site == 2 | site == 4
	
	gen referral = (referralform != "")
	drop referralform formreceived enteredby 
	
	assert site == 1 | site == 2 | site == 3 | site == 4 | site == 5 | site == 6
	label define site 1 "King County" 2 "Phoenix" 3 "Orange County" 4 "Bucks County" 5 "Santa Clara County" ///
		6 "Chicago"
	label values site site 
	
	recode childwelfarestatus (1 = 0) (2 = 1)
	rename childwelfarestatus reunif 
	label define reunif 0 "Preservation" 1 "Reunification"
	label values reunif reunif 
	
	gen treatment=1 if assignment == "Treatment"
		replace treatment=0 if assignment=="Control"
		drop assignment

	clean_dates2 auditdatetime entered_d "Date entered"
	replace assignmentdatetime = substr(assignmentdatetime,1, 10)
	clean_dates2 assignmentdatetime assigned_d "Date randomized"
		assert assigned_d >= entered_d 
		gen t_month1 = month(entered_d)
		gen t_month2 = month(assigned_d)
		drop t_*
	
	keep if treatment == 1 | treatment == 0 
	
	gen lastdash = td(26jan2021) if site == 1
		replace lastdash = td(01feb2021) if site == 2
		replace lastdash = td(31jan2021) if site == 3
		replace lastdash = td(21jan2021) if site == 4
		format lastdash %td
		
	/* Correcting wrong IDs or mismatches between dashboard and rand tool 
	See documentation for some in Y:\Randomization\Documentation*/
	replace p_id = "640576" if p_id == "640575" & site == 2
	
	replace p_id = "m14827" if p_id == "14827" & site == 4
	replace p_id = "r28728" if p_id == "28728" & site == 4
	replace p_id = "l25771" if p_id == "25771" & site == 4
	replace p_id = "k36427" if p_id == "36427" & site == 4
	replace p_id = "h24983" if p_id == "24983" & site == 4
	replace p_id = "g25795" if p_id == "25795" & site == 4
	replace p_id = "b37367" if p_id == "37367" & site == 4
	replace p_id = "a17701" if p_id == "17701" & site == 4
		 
	
drop rowid  
save "${rdata}\Randomization\RandomizationData.dta", replace 
}
	
*****************************************************************************
/* LOOPING IN DASHBOARD DATA */
*****************************************************************************
{	

// ensure format hasn't changed -- that rows haven't been deleted at top or
// columns moved around. make sure there's nothing interesting after lease-up 

	import excel "${rdata}\PHA\WA\WA_PHA_Dashboard_${lastwa}.xlsx", sheet("Data Entry") ///
		case(lower) allstring clear
		rename C p_id
		rename I datesubmitted
		rename L dateissued
		rename M datedenied
		rename N reasondenied 
		rename O dateleasedup 
		rename W reasonlost  
		keep p_id date* reason*
		drop in 1/5
		gen site = 1
		
		/* Some site specific cleaning things */
		replace dateissued = "" if p_id == "161" 								/* Denied but still there is an issuance date */
		save "${temp}DashboardSite1.dta", replace 

	import excel "${rdata}\PHA\PHX\PHX_PHA_Dashboard_${lastphx}.xlsx", sheet("Data Entry") ///
		 case(lower) allstring clear
		rename A p_id  
		rename D datesubmitted  
		rename H dateissued 
		rename I datedenied
		rename J reasondenied 
		rename K reasonnoapp
		rename L dateleasedup
		rename R datelost 
		rename S reasonlost  	
		rename U dateconsented
		rename W dateconsentreceived
		rename X consent
		rename Y comments
		keep p_id date* reason* consent comments 	
		drop in 1/2
		gen site = 2		
		
			/* if this fails then we need to update osq list to include those who lost voucher besides expired */
		replace reasonlost = trim(reasonlost)
		assert reasonlost == "Expired" | reasonlost == "--" | reasonlost == "---" | reasonlost == "N/A" | reasonlost == ""
		save "${temp}DashboardSite2.dta", replace
	
	import excel "${rdata}\PHA\OC\OC_PHA_Dashboard_${lastoc}.xlsx", sheet("Dashboard") ///
		 case(lower) allstring clear
		 rename B p_id  
		 rename E oc_reasoninelig
		 rename G oc_orientation 
		 rename F dateorientation 
			replace oc_orientation = "No" if mi(oc_orientation)
		 rename H dateissued 
		 rename I datedenied 
		 rename K reasondenied 
		 rename L expired_oc  		/* add check that theres no other voucher loss reason */
		 rename M dateleasedup
		 rename N dateconsented
		 rename O dateconsentreceived
		 rename P consent 
		 
		 drop in 1/4

		 drop if mi(p_id)
		 // for re-referred families, keep second referral 
		 by p_id (C), sort: egen t_seq = seq()
		 duplicates tag p_id, gen(t_dup)
			tab p_id if t_dup == 1 
			drop if t_dup == 1 & t_seq == 1 									
			drop t_dup
			
		gen oc_denied_pcwa = (!mi(oc_reasoninelig) | !mi(reasondenied)) & oc_orientation == "No"
		gen oc_denied = (!mi(oc_reasoninelig) | !mi(reasondenied)) & oc_orientation == "Yes"
		/* Make sure if they were denied or ineligible then either they weren't issued a voucher or it expired */
		assert mi(dateissued) | strpos(expired_oc, "Yes") > 0 if oc_denied_pcwa == 1 | oc_denied == 1 
		drop  dateorientation 
		
		 keep p_id date* reason* consent expired* oc_* 
		 gen site = 3
		 // 7/31 dashboard there's two denial dates saved as denial reason ok need to fix 
		save "${temp}DashboardSite3.dta", replace 
	
	import excel "${rdata}\PHA\BC\BC_PHA_Dashboard_${lastbc}.xlsx", sheet("Sheet1") ///
		case(lower) allstring clear
		rename A p_id  
		rename G datesubmitted
		rename J dateissued 
		rename K datedenied
		rename L reasondenied 
		rename M dateleasedup
		keep p_id date* reason*
		drop in 1/3
		gen site = 4
		replace p_id = "p28255" if p_id == "P28555"								// typos and changes in their IDs 
		replace p_id = "c024969" if p_id == "C024949"
		replace p_id = "m9569" if p_id == "M09569"
		replace p_id = "f21892-1" if p_id == "F21892"
		save "${temp}DashboardSite4.dta", replace 
	
	use "${temp}DashboardSite1.dta", clear
		append using "${temp}DashboardSite2.dta"
		append using "${temp}DashboardSite3.dta"
		append using "${temp}DashboardSite4.dta"
		
	drop if p_id == ""
	replace p_id = trim(p_id)
	replace p_id = lower(p_id)
		
	
	duplicates tag site p_id, gen(t_dup)
		assert t_dup == 0
		drop t_*
		
	merge 1:1 p_id using "${rdata}\Randomization\RandomizationData.dta"
		assert _merge != 1
		gen randomized = (_merge == 3 | _merge == 2)
		gen dashboard = (_merge != 2)
		drop _merge 
	
	assert randomized == 1  
	/* Number included in the report not randomized */
	tab site if randomized == 0 
	/* Controls receiving housing:
	146 from KC 
	Submitted voucher application, PHX one denied */ 
	tab p_id site if treatment == 0 & dashboard == 1
	gen crossover = (treatment == 0 & dashboard == 1)
	drop if randomized == 0 
					
	tab datesubmitted, m
	replace datesubmitted = dateissued if site == 3
	clean_bad_dates datesubmitted submitted_d "MDY" "Date Voucher Application Submitted"
	gen submitted = (submitted_d != .)
		replace submitted = 1 if oc_orientation == "Yes"
		drop oc_orientation
	
	/* With expired here - making sure this is count as an expiration not a denial
	If the date isn't in denial date - might be in expiration date? Or can calculate
	with issue date + 180 for PHX, 120 for BC, check for other sites */
	gen expired = 0 
		replace expired = 1 if strpos(reasondenied, "xpired") > 0
		replace expired = 1 if strpos(reasonlost, "xpired") > 0
		replace expired = 1 if strpos(expired_oc, "Yes") > 0
		replace reasondenied = "" if expired == 1 
		
		
	gen dateexpired = ""
		replace dateexpired = datelost if expired == 1 & !mi(datelost) & site == 2 // getting from Phoenix
		replace expired_oc = subinstr(expired_oc,"Yes ","",.)					// getting from OC
		replace dateexpired = expired_oc if !mi(expired_oc) & site == 3			
		clean_bad_dates dateexpired expired_d "MDY" "Date expired" 
		
	tab datedenied, m
	tab reasondenied, m
	replace oc_reasoninelig = reasondenied if oc_denied != 1 & site == 3
	replace reasondenied = "" if oc_denied != 1  & site == 3
	replace reasondenied = "" if reasondenied == "NA" | reasondenied == "N/A" | reasondenied == "MA" | reasondenied == "--"
	replace reasondenied = "" if strpos(reasondenied, "extn") > 0
	replace reasondenied = lower(reasondenied)
	replace reasondenied = trim(reasondenied)
	replace reasondenied = "" if reasondenied == "---"
	
	/* Handling families who didn't get voucher for whatever reason:
	Denials 
	Voucher expired
	Ineligible by child welfare agency
	Voluntary withdrawal */
	
	clean_bad_dates datedenied denied_d "MDY" "Date Voucher Application Denied"
		tab denied_d 
		replace denied_d = . if reasondenied == "" & site == 3					// doing this because they put date of voucher denial or expiration, even if voucher hasn't expired 
		
		/* families whose voucher was expired - don't count as denial */
		replace expired_d = denied_d if expired == 1 & mi(expired_d)
			replace denied_d = . if expired == 1 	
	
		/* cleaning denial reason */
		gen denied_r = ""

		/* background screening */
		replace denied_r = "Background screening" if strpos(reasondenied,"background") > 0 | ///
			strpos(reasondenied, "failed bc") > 0 | ///
			strpos(reasondenied,"drug") > 0 | ///
			strpos(reasondenied, "violent") > 0 | ///
			strpos(reasondenied, "possession") > 0 | ///
			strpos(reasondenied, "criminal") > 0
			
		/* incomplete application*/
		replace denied_r = "Incomplete Application" if strpos(reasondenied, "documentation") > 0 | ///
			strpos(reasondenied, "did not show") > 0 | ///
			strpos(reasondenied, "no response") > 0 | ///
			strpos(reasondenied, "failure to submit") > 0| ///
			strpos(reasonnoapp, "necessary documents") > 0 | ///
			strpos(reasondenied, "incomplete") > 0 | ///
			strpos(reasondenied, "information not returned") > 0
			
		/* didn't show up to appointments */
		replace denied_r = "No show" if strpos(reasondenied, "appointments") > 0
		
		/* out of jurisdiction */
		replace denied_r = "Out of jurisdiction" if strpos(reasondenied,"surfing") > 0
	
		/* overincome */
		replace denied_r = "Overincome" if strpos(reasondenied,"income") > 0
		
		
		/* voluntary withdrawal */
		gen vol_withdrawal = (strpos(reasondenied,"voluntary") > 0 | ///
			strpos(reasondenied, "interested") > 0 |  ///
			strpos(reasondenied, "withdrawn") > 0 | ///
			strpos(reasondenied, "moved")  > 0|    ///
			strpos(reasondenied,"declined") > 0) | ///
			strpos(reasondenied, "no longer wishes") > 0 | ///
			strpos(reasondenied, "per request") > 0 | ///
			strpos(oc_reasoninelig, "interested") > 0 | ///
			strpos(oc_reasoninelig, "declined") > 0
		replace vol_withdrawal = 1 if strpos(comments, "Voluntary Withdrawal") > 0 & p_id != "567935" 
				/* This PHX case is marked as voluntary withdrawal in comments but voucher expired */
			
		/* handling "other" reasons*/
		tab reasondenied if reasondenied != "" & denied_r == "" & vol_withdrawal == 0
		replace denied_r = "Other" if denied_r == "" & reasondenied != "" & vol_withdrawal == 0

	replace reasonnoapp = lower(reasonnoapp)
	replace reasonnoapp = trim(reasonnoapp)
	replace reasonnoapp = "" if reasonnoapp == "n/a" | reasonnoapp == "--"
	replace reasonnoapp = "bridgette says consider denied" if (p_id == "613435" | p_id == "422196") & site == 2 
	/* Separating out "denials" that happened before application was submitted */
	gen denied_pcwa = ((denied_d != . | denied_r != "") & submitted == 0 & site != 3)
		/* can't tell in OC whether PCWA or PHA denied because no submitted date */
		replace denied_pcwa = 0 if vol_withdrawal == 1 | expired == 1 
		replace denied_pcwa = 1 if strpos(reasonnoapp, "not reunification") > 0 
		replace denied_pcwa = 1 if strpos(reasonnoapp, "no longer eligible") > 0
		replace denied_pcwa = 1 if reasonnoapp == "bridgette says consider denied"
		replace denied_pcwa = 1 if oc_denied_pcwa == 1 & site == 3
		replace denied_pcwa = 0 if vol_withdrawal == 1
	
	replace comments = lower(comments)
	replace comments = trim(comments)
	gen case_closed_ever = (strpos(reasonnoapp, "case closed") > 0 | strpos(comments, "case closed") > 0)
	gen case_closed_preissue = case_closed_ever == 1 & mi(dateissued)
	gen case_closed_postissue = case_closed_ever == 1 & !mi(dateissued)
		replace case_closed_ever = . if site != 2
		replace case_closed_preissue = . if site != 2
		replace case_closed_postissue = . if site != 2
	
	gen denied = 0
		replace denied = 1 if denied_d != . 
		replace denied = 1 if denied_r != ""
		replace denied = 0 if vol_withdrawal == 1 | expired == 1 | denied_pcwa == 1 | case_closed_preissue == 1
		
	gen denied_bg = (denied_r == "Background screening")
	gen denied_jur = (denied_r == "Out of jurisdiction")
	gen denied_app = (denied_r == "Incomplete Application")
	gen denied_noshow = (denied_r == "No show")
	gen denied_inc = (denied_r == "Overincome")
	gen denied_oth = (denied_r == "Other")
	
	replace denied_r = "" if denied == 0
	foreach x in bg jur app noshow inc oth {
	replace denied_`x' = . if denied == 0
	}
	
	/* Handling two types of voluntary withdrawal:
	Some folks said they weren't interested and never submitted application 
	Other folks applied and then withdrew */
	gen vol_withdrawal_pre = (vol_withdrawal == 1 & submitted == 0)
		replace vol_withdrawal_pre = 1 if strpos(reasonnoapp, "left state") > 0
		replace vol_withdrawal_pre = 1 if strpos(reasonnoapp, "change to mesa") > 0
		replace vol_withdrawal_pre = 1 if strpos(reasonnoapp, "purchase home") > 0
		replace vol_withdrawal_pre = 1 if strpos(reasonnoapp, "not needed now") > 0
		replace vol_withdrawal_pre = 1 if strpos(reasonnoapp, "self-selected out") > 0
	gen vol_withdrawal_post = (vol_withdrawal == 1 & submitted == 1)
	drop vol_withdrawal
	
	foreach x in vol_withdrawal_pre case_closed_preissue denied_pcwa {
		replace `x' = . if submitted == 1 
	}

	gen pending = (vol_withdrawal_pre == 0 & denied_pcwa == 0 & submitted == 0 )
		replace pending = 0 if case_closed_preissue == 1
		replace pending = . if dashboard == 0
	
	assert mi(reasonnoapp) if vol_withdrawal_pre != 1 & denied_pcwa != 1 & case_closed_preissue != 1 & pending != 1 & submitted != 1 
	// tab reasonnoapp if vol_withdrawal_pre != 1 & denied_pcwa != 1 & case_closed != 1 & pending != 1 & submitted != 1 
	// Helpful if new Phx dashboard to make sure all looks good 
	// browse submitted submitted_d denied denied_d vol_withdrawal_pre denied_pcwa case_closed vol_withdrawal_post pending reasonnoapp if reasonnoapp != ""
	/* Two that say case closed but it was after submitting 
	One that says case withdrawn but */
	
	/* Making sure denied_d only represents those denied, new variable for denied_pcwa or vol_withdrawal dates */
	gen disposition_d = denied_d if !mi(denied_d) & denied == 0
		format disposition_d %td
	replace denied_d = . if denied == 0
	
	
	replace dateissued = trim(dateissued)
	clean_bad_dates dateissued issued_d "MDY" "Date Voucher Issued"
	replace issued_d = td(28jan2020) if p_id == "oc0067" & site == 3			/* Year typo, randomized in Nov*/
	gen issued = (issued_d != .)
	
	clean_bad_dates dateleasedup leaseup_d "MDY" "Date Applicant Leased Up"
	replace leaseup_d = td(14nov2019) if p_id == "612932" & site == 2   		 /* Typo probably, said 2009*/
	gen leasedup = (leaseup_d != .)
	
	foreach x in submitted_d submitted expired denied_d expired_d 				 ///
		denied_pcwa case_closed_ever case_closed_preissue case_closed_postissue ///
		denied denied_bg denied_jur denied_app denied_noshow 					///
		denied_inc denied_oth vol_withdrawal_pre vol_withdrawal_post pending ///
		issued_d issued leaseup_d leasedup {
			replace `x' = . if treatment == 0
			replace `x' = . if dashboard == 0
		}
		
	/* Handling consent */
	tab dateconsented site, m
	tab dateconsentreceived site, m
	tab consent site, m
	rename consent t_consent 
	replace t_consent = lower(t_consent)
	
	gen consent_administered = (!mi(dateconsented) | !mi(dateconsentreceived) | !mi(t_consent))
	gen consent_returned = (!mi(dateconsentreceived) | !mi(t_consent))
	gen consent = (t_consent == "yes")
	
	replace consent_administered = . if treatment == 0 | issued == 0 // actually universe is treatment families at the voucher briefing or something 
	replace consent_returned = . if treatment == 0 | issued == 0
	replace consent = . if treatment == 0 | issued == 0
	
	drop t_*  dateconsented dateconsentreceived 
	
	/* doing checks */
	
		tab submitted_d site, m
		assert submitted == 1 if !mi(submitted_d)
		assert submitted == 1 if issued == 1 | !mi(issued_d) | denied == 1 | !mi(denied_d)
		/*foreach var of varlist inc1-inc12 {
			replace `var' = . if submitted == 0
		} */
		
		tab issued site, m
		tab issued_d site, m
		assert issued == 1 if leasedup == 1
		
		tab leasedup site, m
		tab leaseup_d site, m
		assert leasedup == 1 if !mi(leaseup_d)
		
		/* Making sure exit reasons are mutually exhaustive
		Possible exits: vol_withdrawal_pre, denied_pcwa, case_closed, vol_withdrawal_post, 
		denied, expired 
		FIX MISSING VERSUS ZERO */
		tab vol_withdrawal_pre site, m
		assert leasedup != 1 & submitted != 1 & issued != 1 & case_closed_ever != 1 & ///
			vol_withdrawal_post != 1 & expired != 1 & denied_pcwa != 1 & denied != 1 if vol_withdrawal_pre == 1
		
		tab denied_pcwa site, m
		assert leasedup != 1 & submitted != 1 & issued != 1 						///
			& case_closed_ever != 1 & vol_withdrawal_pre != 1 							///
			& vol_withdrawal_post != 1 & expired != 1 & denied != 1 if denied_pcwa == 1
			
		tab case_closed_preissue site, m
		assert leasedup != 1 & submitted != 1 & issued != 1 & vol_withdrawal_pre != 1 ///
			& denied_pcwa != 1 & vol_withdrawal_post != 1 & denied != 1 & expired != 1 if case_closed_preissue == 1
		
		tab expired site, m
		assert expired == 1 if !mi(expired_d) /* Can bring this in from voucher loss date */
		assert issued == 1 if expired == 1
		assert leasedup != 1 & denied != 1 & denied_pcwa != 1 & case_closed_preissue != 1 & ///
			vol_withdrawal_pre != 1 & vol_withdrawal_post != 1 if expired == 1

		tab reasondenied denied_r if site == 1
		tab reasondenied denied_r if site == 2
		tab reasondenied denied_r if site == 3
		tab reasondenied denied_r if site == 4
		assert leasedup != 1 & issued != 1 & denied_pcwa != 1 & case_closed_preissue != 1 & vol_withdrawal_pre != 1 ///
			& vol_withdrawal_post != 1 & expired != 1 if denied == 1 | !mi(denied_d)
		
		
		tab pending site if submitted == 0, m
		
	drop reasondenied reasonnoapp reasonlost comments projectid cw_id referral  randomized oc_* 
	
	/* tracking housing assistance & ongoing services questionnaires
	getting denominators from eligible lists produced each month */
	preserve
		global last_run "2021_02_01"
		import delimited "${rdata}Data Collection\PHX_HAF_Eligible_${last_run}.csv", clear
			rename caseid p_id
			tostring p_id, replace 
			gen site = 2 
			keep p_id site 
			tempfile phx_haf
			save `phx_haf'
		
		import delimited "${rdata}Data Collection\OC_HAF_Eligible_${last_run}.csv", clear 
			replace p_id = lower(p_id)
			gen site = 3
			keep p_id site 
			append using `phx_haf'
			duplicates drop
			save "${temp}HAF_Eligible.dta", replace 
			
			
		import delimited "${rdata}Data Collection\PHX_OSQ_Eligible_${last_run}.csv", clear 
			rename caseid p_id 
			tostring p_id, replace 
			gen site = 2
			keep p_id site 
			tempfile phx_osq 
			save `phx_osq'
			
		import delimited "${rdata}Data Collection\OC_OSQ_Eligible_${last_run}.csv", clear 
			replace p_id = lower(p_id)
			gen site = 3 
			keep p_id site 
			append using `phx_osq'
			duplicates drop
			save "${temp}OSQ_Eligible.dta", replace 
	restore 
	
	merge 1:1 p_id site using "${temp}HAF_Eligible.dta"
		assert _merge != 2
		gen haf_eligible = (_merge == 3)
		drop _merge 
	merge 1:1 p_id site using "${temp}OSQ_Eligible.dta"
		assert _merge != 2
		gen osq_eligible = (_merge == 3)
		drop _merge
	merge 1:1 p_id site using "${temp}HAF_Completed.dta"					// pulling in from the data download R file
		assert _merge != 2
		gen haf_completed = (_merge == 3)
		drop _merge
	merge 1:1 p_id site using "${temp}OSQ_Completed.dta"					// pulling in from data download R file 
		assert _merge != 2
		gen osq_completed = (_merge == 3)
		drop _merge
		
	/* Variable labels */
	label var submitted "Appplication submitted "
	label var dashboard "Family included in dashboard"
	label var crossover "Control family included in dashboard"
	label var expired "Voucher expired"
	label var expired_d "Voucher expired date"
	label var denied_r "Voucher denial reason"
	label var denied_pcwa "Determined ineligible by PCWA"
	label var case_closed_preissue "Case closed before application was submitted (PHX only)" /* This doesn't align with PHX HAF entries*/
	label var case_closed_postissue "Case closed after application was isssued (PHX only)"
	label var denied "Voucher denied"
	label var denied_bg "Voucher denied due to background check"
	label var denied_jur "Voucher denied due to client out of jurisdiction"
	label var denied_app "Voucher denied due to incomplete application"
	label var denied_noshow "Voucher denied due to client not showing up to appointments"
	label var denied_inc "Voucher denied due to client over income limit"
	label var denied_oth "Voucher denied due to other reason"
	label var vol_withdrawal_pre "Family not interested in submitting application"
	label var vol_withdrawal_post "Family withdrew after submitting application"
	label var pending "Application submission pending"
	label var issued_d "Voucher issuance date"
	label var issued "Voucher issued"
	label var leasedup "Client leased up"
	label var consent_administered "Consent form was mailed out or administered"
	label var consent_returned "Consent form was filled out or mailed back"
	label var consent "Client consented"
	
	save "${cdata}DashboardData.dta", replace 

}	

*****************************************************************************
/* POPULATING DASHBOARD */
*****************************************************************************

{	
	gen count = 1

	preserve
	keep if treatment == 0 | treatment == 1	
	tab reunif treatment, m
	tabout reunif treatment using "${rand}Tables\Rand_Tracking$S_DATE.xls", replace 
	tabout reunif treatment if site == 1 using "${rand}Tables\Rand_Tracking$S_DATE.xls", append
	tabout reunif treatment if site == 2 using "${rand}Tables\Rand_Tracking$S_DATE.xls", append
	tabout reunif treatment if site == 3 using "${rand}Tables\Rand_Tracking$S_DATE.xls", append
	tabout reunif treatment if site == 4 using "${rand}Tables\Rand_Tracking$S_DATE.xls", append
	restore   
	
	putexcel set "${tables}Dashboard_${today}.xlsx", sheet("Dashboard") modify
		
	tab treatment, matcell(overall)
	tab treatment reunif, matcell(subgroup)
	putexcel C4 = overall[1,1]													// Control, overall
	putexcel C5 = subgroup[1,1]													// Control, P
	putexcel C6 = subgroup[1,2]													// Control, R
	putexcel C7 = overall[2,1] 													// Treatment, overall
	putexcel C8 = subgroup[2,1]													// Treatment, P
	putexcel C9 = subgroup[2,2]													// Treatment, R
	putexcel C10 = (`r(N)') 													// Overall 
	sleep 20
	
	gen site_col = "D" if site == 4
		replace site_col = "E" if site == 1
		replace site_col = "F" if site == 3
		replace site_col = "G" if site == 2
		replace site_col = "H" if site == 6
		replace site_col = "J" if site == 5
		
	local cols D E F G H J
	foreach col of local cols {
	
	putexcel `col'3 = "${todayrand}"
	
	tab treatment if site_col == "`col'", matcell(overall)
	tab treatment reunif if site_col == "`col'", matcell(subgroup)
	putexcel `col'4 = overall[1,1]												// Control, overall
	putexcel `col'5 = subgroup[1,1]												// Control, P
	putexcel `col'6 = subgroup[1,2]												// Control, R
	putexcel `col'7 = overall[2,1] 												// Treatment, overall
	putexcel `col'8 = subgroup[2,1]												// Treatment, P
	putexcel `col'9 = subgroup[2,2]												// Treatment, R
	putexcel `col'10 = (`r(N)') 													// Overall 
	sum count if entered_d < lastdash & treatment == 1 & site_col == "`col'"
	putexcel `col'16= (`r(N)') 
	}
	sleep 20
		
	gen t = "${today_m}"+"${today_d}"+"${today_y}"									// for calculating since last month 
	gen today_d = date(t, "MDY")
	format today_d %td  
	drop t 
	
	tab treatment if (today_d - assigned_d < 30), matcell(overall)
	tab treatment reunif if (today_d - assigned_d < 30), matcell(subgroup)
	putexcel B4 = overall[1,1]													// Control, overall
	putexcel B5 = subgroup[1,1]													// Control, P
	putexcel B6 = subgroup[1,2]													// Control, R
	putexcel B7 = overall[2,1] 													// Treatment, overall
	putexcel B8 = subgroup[2,1]													// Treatment, P
	putexcel B9 = subgroup[2,2]													 // Treatment, R
	putexcel B10 = (`r(N)') 	
	
	preserve
	
	keep if dashboard == 1 & crossover == 0 
	
	putexcel D14 = "${lastbc}"
	putexcel E14 = "${lastwa}"
	putexcel F14 = "${lastoc}"
	putexcel G14 = "${lastphx}"
	tab site, matcell(counts)
	putexcel C15 = `r(N)'
	putexcel D15 = counts[4,1]
	putexcel E15 = counts[1,1]
	putexcel F15 = counts[3,1]
	putexcel G15 = counts[2,1]
	
	local cols D E F G 
	foreach col of local cols {
		sum count if submitted == 1 & site_col == "`col'"
		putexcel `col'17 = (`r(N)')
		sum count if vol_withdrawal_pre == 1 & site_col == "`col'"
		putexcel `col'19 = (`r(N)') 
		sum count if denied_pcwa == 1 & site_col == "`col'"
		putexcel `col'20 = (`r(N)') 
		sum count if pending == 1 & site_col == "`col'"
		putexcel `col'22 = (`r(N)')
		sum count if pending == 1 & (today_d - entered_d <= 60) & site_col == "`col'"
		putexcel `col'23 = (`r(N)') 
		sum count if pending == 1 & (today_d - entered_d > 60) & site_col == "`col'"
		putexcel `col'24 = (`r(N)') 
		sum count if vol_withdrawal_post == 1 & site_col == "`col'"
		putexcel `col'25 = (`r(N)') 
		tab denied if site_col == "`col'", matcell(denied)
		putexcel `col'26 = denied[2,1]
		sum count if denied_bg == 1 & site_col == "`col'"
		putexcel `col'27 = (`r(N)')  
		sum count if denied_app == 1 & site_col == "`col'"
		putexcel `col'28 = (`r(N)') 
		sum count if denied_noshow == 1 & site_col == "`col'"
		putexcel `col'29 = (`r(N)') 
		sum count if denied_jur == 1 & site_col == "`col'"
		putexcel `col'30 = (`r(N)') 
		sum count if denied_inc == 1 & site_col == "`col'"
		putexcel `col'31 = (`r(N)') 
		sum count if denied_oth == 1 & site_col == "`col'"
		putexcel `col'32 = (`r(N)') 
		tab issued if site_col == "`col'", matcell(issued)
		putexcel `col'33 = issued[2,1]
		sum count if expired == 1 & site_col == "`col'"
		putexcel `col'34 = (`r(N)') 
		tab leasedup if site_col == "`col'", matcell(lease)
		putexcel `col'35 = lease[2,1]
		tab consent_administered if site_col == "`col'", matcell(consentadmin)
		putexcel `col'40 = consentadmin[2,1]				
		tab consent_returned if site_col == "`col'", matcell(consentreturned)
		putexcel `col'41 = consentreturned[2,1]
		tab consent if site_col == "`col'", matcell(consent)
		putexcel `col'42 = consent[2,1]
		tab consent if site_col == "`col'" & leasedup == 1, matcell(consentleased)
		putexcel `col'43 = consentleased[2,1]
		tab haf_completed if site_col == "`col'", matcell(haf_completed)
		putexcel `col'46 = haf_completed[2,1]
		tab haf_eligible if site_col == "`col'", matcell(haf_eligible)
		putexcel `col'47 = haf_eligible[2,1]
		tab osq_completed if site_col == "`col'", matcell(osq_completed)
		putexcel `col'50 = osq_completed[2,1]
		tab osq_eligible if site_col == "`col'", matcell(osq_eligible)
		putexcel `col'51 = osq_eligible[2,1]
	}
	sleep 10 
	
	/* Adding this outside loop since it only applies to Phoenix */
	sum count if case_closed_preissue == 1 & site == 2
	putexcel G21 = (`r(N)') 
	
	sum count if submitted == 1 & (today_d - submitted_d < 30)
	putexcel B17 = (`r(N)')
	sum count if vol_withdrawal_pre == 1 & (today_d - denied_d < 30)
	putexcel B19 = (`r(N)') 
	sum count if denied_pcwa == 1 & (today_d - denied_d < 30)
	putexcel B20 = (`r(N)') 
	sum count if vol_withdrawal_post == 1 & (today_d - denied_d < 30)
	putexcel B23 = (`r(N)') 
	sum count if denied == 1 & (today_d - denied_d < 30)
	putexcel B24 = (`r(N)')
	sum count if denied_bg == 1 & (today_d - denied_d < 30)
	putexcel B25 = (`r(N)') 
	sum count if denied_app == 1 & (today_d - denied_d < 30)
	putexcel B26 = (`r(N)') 
	sum count if denied_noshow == 1 & (today_d - denied_d < 30)
	putexcel B27 = (`r(N)') 
	sum count if denied_jur == 1 & (today_d - denied_d < 30)
	putexcel B28 = (`r(N)') 
	sum count if denied_inc == 1 & (today_d - denied_d < 30)
	putexcel B29 = (`r(N)') 
	sum count if denied_oth == 1 & (today_d - denied_d < 30)
	putexcel B30 = (`r(N)') 
	tab issued if (today_d - issued_d < 30)
	putexcel B31 = issued[2,1]
	sum count if expired == 1 & (today_d - expired_d < 30)
	putexcel B32 = (`r(N)') 
	tab leasedup if month(leaseup_d) != (today_d - leaseup_d < 30)
	putexcel B33 = lease[2,1] 
	
	restore 
	
}

	preserve
	keep if site == 3 & treatment == 1 
	rename assigned_d rand_date
	rename vol_withdrawal_pre family_not_interested
	rename denied_pcwa determined_inelig_pcwa 
	rename vol_withdrawal_post voluntary_withdrawal
	 
	keep p_id submitted family_not_interested determined_inelig_pcwa pending /// 
		voluntary_withdrawal denied denied_bg denied_app denied_noshow 		///
		denied_jur denied_inc denied_oth issued expired leasedup
		
	order p_id submitted family_not_interested determined_inelig_pcwa pending ///
		voluntary_withdrawal denied denied_bg denied_app denied_noshow        ///
		denied_jur denied_inc denied_oth issued expired leasedup

	outsheet using "${cdata}DashboardData_OC.csv", comma replace 
	restore 
	

/* Figure out a way to generate a file with families that have HAF/OSQ and whether they've filled it out or not for Claudia/hannah !!! */

	
	
	

// TO DOS

	// how to reflect if someone was ported out ?
	// does OC not-submitted make sense?
	// assume a voucher expired if expiration date is in the past and haven't leased up?
	
	// update participant list file path to paste with today_d 
	// Clean dashboard data -- add labels, make dummies missing if not in dashboard 
		
	


	
	
	
	
	