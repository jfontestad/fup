

/* Code to make .csvs that feed into (for now only Phoenix) housing assistance form */

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
	
	global today_d "2021_02_02"

	/* HOUSING ASSISTANCE FORM : 
	Universe for all sites except OC: everyone who submitted an application. 
	e.g. issued a voucher, expired, denied, or voluntarily withdrew after getting voucher  */
	
	/* Phoenix 
	TO-DOS: possibly remove searching */
	global last_phx_haf "2021_02_01"
	use "${cdata}DashboardData.dta", clear
		
		keep if dashboard == 1 & treatment == 1 & site == 2
		
		/* deduplicate */
		duplicates tag p_id, gen(t_dup)
			assert t_dup == 0
			drop t_dup
			
		/* confirm data looks good */
		assert leasedup == 1 if !mi(leaseup_d)
		assert expired == 1 if !mi(expired_d)
		assert leasedup == 0 & denied == 0 if expired == 1
		
		gen status = ""
			replace status = "Expired" if expired == 1 
			replace status = "Leased up" if leasedup == 1
			replace status = "Case closed" if case_closed_postissue == 1 
			replace status = "Denied" if denied == 1 							// after 1/11 mtg, denied families included
			replace status = "Withdrew" if vol_withdrawal_post == 1
			
			keep if status != ""
			
		gen status_q = ""
			replace status_q = "provided a voucher, but the voucher expired" if status == "Expired"
			replace status_q = "leased up" if status == "Leased up"
			replace status_q = "provided a voucher, but the case closed prior to the family leasing up" if status == "Case closed"
			replace status_q = "denied a voucher" if status == "Denied"
			replace status_q = "provided a voucher, but withdrew from the program" if status == "Withdrew"
			
		gen voucher_date = expired_d if status == "Expired"
			replace voucher_date = leaseup_d if status == "Leased up"
			replace voucher_date = denied_d if status == "Denied"
			replace voucher_date = . if status == "Case closed" | status == "Withdrew"
			format voucher_date %td

			assert status_q != ""
					
		keep p_id status status_q submitted_d issued_d voucher_date
		
		rename p_id caseid 
		rename issued_d issued
		rename submitted_d submit 
		gen casemanager = ""
		gen cmemail = ""
		
		/* generating flag for new since last list sent */
		preserve
			//import delimited "${rdata}Data Collection\PHX_HAF_Eligible_${last}.csv", varnames(1) case(lower) clear USE THIS 
			import excel "${rdata}PHA\PHX\Other Spreadsheets for Study\PHX_HAQ List_20201216.xlsx", firstrow case(lower) clear
			keep caseid 
			duplicates drop 
			capture tostring caseid, replace 
			replace caseid = trim(caseid)
			drop if inlist(caseid, "XXXXXX", "YYYYYY", "ZZZZZZ", ".")
			tempfile last_sent
			save `last_sent'
		restore
			
		merge m:1 caseid using `last_sent'
			// assert _merge != 2 
			drop if _merge == 2 												// doing this because they previously included Searching, now dropping those 
			gen newflag_lastname = (_merge == 1) 								/* naming it this this so Kassie remembers to include in link list output */
			drop _merge 
			
			// number of new ones to tell the team 
			unique caseid if newflag_lastname == 1 			
		
	expand 4
	gen qualtrics_fname = caseid 
	sort newflag_lastname caseid 
	
	order caseid qualtrics_fname status status_q casemanager cmemail submit issued voucher_date  newflag_lastname
		
	export delimited "${rdata}Data Collection\PHX_HAF_Eligible_${today_d}.csv", replace 

	/* Orange County 
	Universe for OC: everyone issued a voucher, expired, voluntarily withdrew after submitting app, or 
	denied because of incomplete app / didn't show up to appointments 
	Wait to put on list until terminal outcome (e.g. expired, withdrew, denied, leased up) not issued only */
	global last_oc_haf "2021_02_01"
	use "${cdata}DashboardData.dta", clear
		
		keep if dashboard == 1 & treatment == 1 & site == 3
		
		/* deduplicate */
		duplicates tag p_id, gen(t_dup)
			assert t_dup == 0
			drop t_dup
			
		/* confirm data looks good */
		assert leasedup == 1 if !mi(leaseup_d)
		assert expired == 1 if !mi(expired_d)
		assert leasedup == 0 & denied == 0 if expired == 1
		
		gen string = "leased up" if leasedup == 1
			replace string = "provided a voucher, but the voucher expired" if expired == 1
			replace string = "denied a voucher" if denied == 1 & inlist(denied_r, "Incomplete Application", "No show")
			replace string = "provided a voucher, but withdrew from the program" if vol_withdrawal_post == 1			
		
			keep if !mi(string)
			
		keep p_id string 
		
		gen qualtrics_fname = p_id 
		gen email = "hdaly@urban.org"
		
		/* GET THIS UP AND RUNNING FOR NEXT TIME 
			preserve
			import delimited "${rdata}Data Collection\OC_OSQ_Eligible_${last_oc_osq}.csv", varnames(1) case(lower) clear
			keep p_id 
			duplicates drop /* merge in from the last list previously added case manager IDs */
			tempfile last_sent
			save `last_sent'
		restore
			
		merge m:1 p_id using `last_sent'
			assert _merge != 2 
			gen newflag_lastname = (_merge == 1) 	/* naming it this this so Kassie remembers to include in link list output */
			drop _merge */
			
		gen newflag_lastname = 1
		
		expand 4 
		order p_id qualtrics_fname string email newflag_lastname
		sort newflag_lastname p_id 
		
		export delimited "${rdata}Data Collection\OC_HAF_Eligible_${today_d}.csv", replace 
		
	/* Santa Clara */
	use "${cdata}DashboardData.dta", clear
	assert dashboard == 0 if site == 5
	
	/* Chicago */
	assert dashboard == 0 if site == 6
	
	/* Oakland */
	assert dashboard == 0 if site == 7


	/* ONGOING SERVICES QUESTIONNAIRE: 
	for those who have leased up for six months or lost a voucher */
	
	/* Orange County 
	IF THERE ARE ANY THAT WERE IN THE PROGRAM FOR 6 MONTHS AND THEN LOST THEIR VOUCHER 
	lost voucher not due to expiration then handle those */
	global last_oc_osq "2021_01_08"
	use "${cdata}DashboardData.dta", clear
	
		keep if site == 3 & treatment == 1
			
		duplicates tag p_id, gen(t_dup)
			assert t_dup == 0
			drop t_dup
			
		keep if leasedup == 1
		
		gen date_today = date("`c(current_date)'","DMY") 
		format date_today %td
		keep if date_today - leaseup_d > 181 /* where to put voucher exit date if we have any of those? */
		
		gen string = ""
			replace string = "leased up" if leasedup == 1 
			
		drop if string == ""
		keep p_id string leaseup_d   
				
		expand 4
		sort p_id 
		replace p_id = upper(p_id)
		
		gen day = day(leaseup_d)
		gen month = month(leaseup_d)
		gen year = year(leaseup_d)
		tostring day month year, replace 
		drop leaseup_d 
		gen leaseup_d = month + "/" + day + "/" + year
		drop day month year 
		
		gen qualtrics_fname = p_id
		gen email = "hdaly@urban.org"
		
		/* generating flag for new since last list sent */
		preserve
			import delimited "${rdata}Data Collection\OC_OSQ_Eligible_${last_oc_osq}.csv", varnames(1) case(lower) clear
			keep p_id 
			duplicates drop /* merge in from the last list previously added case manager IDs */
			tempfile last_sent
			save `last_sent'
		restore
			
		merge m:1 p_id using `last_sent'
			assert _merge != 2 
			gen newflag_lastname = (_merge == 1) 	/* naming it this this so Kassie remembers to include in link list output */
			drop _merge 
			
			// number of new ones to tell the team 
			unique p_id if newflag_lastname == 1
			sort newflag_lastname p_id 
		
	export delimited "${rdata}Data Collection\OC_OSQ_Eligible_${today_d}.csv", replace  // without replace option! 
	
	
	/* Phoenix 
	IF THERE ARE ANY THAT WERE IN THE PROGRAM FOR 6 MONTHS AND THEN LOST THEIR VOUCHER 
	lost voucher not due to expiration then handle those */
	global last_phx_osq "2021_01_08"
	use "${cdata}DashboardData.dta", clear
	
		keep if site == 2 & treatment == 1
			
		duplicates tag p_id, gen(t_dup)
			assert t_dup == 0
			drop t_dup
			
		keep if leasedup == 1
		
		gen date_today = date("`c(current_date)'","DMY") 
		format date_today %td
		keep if date_today - leaseup_d > 181
		
		gen status_q = ""
			replace status_q = "leased up" if leasedup == 1 
			
		drop if status_q == ""
		keep p_id status_q leaseup_d 
				
		expand 4
		sort p_id 
		
		gen day = day(leaseup_d)
		gen month = month(leaseup_d)
		gen year = year(leaseup_d)
		tostring day month year, replace 
		drop leaseup_d 
		gen leaseup_d = month + "/" + day + "/" + year
		drop day month year 
		
		rename p_id caseid 
		gen firstname_q = caseid 
		gen casemanager_name = ""
		gen casemanager_email = ""
		order caseid firstname_q leaseup_d casemanager_name casemanager_email status_q
		
		/* generating flag for new since last list sent */
		preserve
			import delimited "${rdata}Data Collection\PHX_OSQ_Eligible_${last_phx_osq}.csv", varnames(1) case(lower) stringcols(_all) clear
			keep caseid 
			duplicates drop
			tempfile last_sent
			save `last_sent'
		restore
			
		merge m:1 caseid using `last_sent'
			assert _merge != 2 
			gen newflag_lastname = (_merge == 1) 	/* naming it this this so Kassie remembers to include in link list output */
			drop _merge 
			
			unique caseid if newflag_lastname == 1
			sort newflag_lastname caseid 
		
	export delimited "${rdata}Data Collection\PHX_OSQ_Eligible_${today_d}.csv", replace 
	
	
	/* Chicago */
	
	/* Oakland */
	
	/* Santa Clara */
	
	
	
	

	// OLD 
						
	/* PREPARING BC HOUSING ASSISTANCE FORM INPUTS 
	use "${cdata}DashboardData.dta", clear 
		
		keep if site == 4 
		
		duplicates tag p_id, gen(t_dup)
			assert t_dup == 0
			drop t_dup
			
		rename p_id caseid
		
		gen email = "tlodonnell@buckscounty.org"
		
		assert leasedup == 0 & denied == 0 if expired == 1
		tab leasedup denied, m
		gen string = ""
			replace string = "leased up" if leasedup == 1
			replace string = "denied a voucher" if denied == 1 
			replace string = "not able to lease up before the voucher expired" if expired == 1
			
		keep if string != ""
		
		keep caseid email string 
		
		export delimited "${temp}Bucks_HAF_Inputs.csv", replace */

		
		
		
		
		
		
		
