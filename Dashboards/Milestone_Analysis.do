

/* Code to start preliminary milestone analysis - looking at how long 
each step takes in each site (application submission, issuance, lease-up, etc.) */

	clear 
	capture log close
	set more off

	global rdata "Y:\LHP\FUP\Impact Study\RData\"
	global tables "Y:\LHP\FUP\Impact Study\Tables\Dashboards\"
	global log "Y:\LHP\FUP\Impact Study\Do\Log\"
	global do "Y:\LHP\FUP\Impact Study\Do\Dashboards\"
	global cdata "Y:\LHP\FUP\Impact Study\CData\Dashboards\"
	global temp "Y:\LHP\FUP\Impact Study\Temp\"
	global rand "Y:\LHP\FUP\Impact Study\Randomization\"

	log using "${log}MILESTONE_ANALYSIS_$S_DATE.log", replace

	
	use "${cdata}DashboardData.dta", clear
	
	keep if treatment == 1 
	
	gen site_text = ""
		replace site_text = "KCSEA" if site == 1
		replace site_text = "PHX" if site == 2
		replace site_text = "OC" if site == 3
		replace site_text = "BC" if site == 4
		replace site_text = "SCC" if site == 5
		replace site_text = "CHI" if site == 6
		drop if mi(site_text) 
		
	gen cw_text = ""
		replace cw_text = "Reunif" if reunif == 1
		replace cw_text = "Pres" if reunif == 0
	
	/* Some early randomization tool entries only had entered_d */
	replace assigned_d = entered_d if assigned_d == . & entered_d != . & treatment != . 
	assert assigned_d != . & lastdash != . & treatment != . 
	
	gen submitted_t = submitted_d - assigned_d 
	gen issued_t = issued_d - assigned_d 
	gen leasedup_t = leaseup_d - assigned_d 
	
	replace submitted_t = 0 if submitted_t < 0 					/* Why is this happening? PHX and BC */
	assert issued_t >= 0
	assert leasedup_t >= 0
	
	assert issued == 0 & leasedup == 0 if submitted == 0
	assert site == 2 if leasedup == 1 & issued == 0
	replace issued = 1 if leasedup == 1 & issued == 0 & site == 2
	
	assert site == 3 if mi(submitted_t) & submitted == 1
	// assert issued_t >= 0 & issued_t != . if issued == 1  // not true for Phx 
	assert leasedup_t >= 0 & leasedup_t != . if leasedup == 1

	
	gen count = 1
	
	{ /*OVERALL CUMULATIVE TABLE*/ 
	putexcel set "${tables}Milestone_$S_DATE.xlsx", sheet("Overall") replace

	putexcel A1 = "Milestones (within N months is calculated only among families observed in the dashboard data for N months)"
	putexcel A2 = "Outcome"
	putexcel B2 = "Within 1 month", txtwrap
	putexcel C2 = "Within 2 months", txtwrap
	putexcel D2 = "Within 3 months", txtwrap
	putexcel E2 = "Within 4 months", txtwrap
	putexcel F2 = "Within 5 months", txtwrap
	putexcel G2 = "Within 6 months", txtwrap
	putexcel H2 = "Mean days from referral for those observed at least 6 mo.", txtwrap
	putexcel I2 = "Median days from referral for those observed at least 6 mo.", txtwrap
	putexcel A3 = "N"
	putexcel A4 = "Application submitted"
	putexcel A5 = "Voucher issued"
	putexcel A6 = "Leased up"

	local ncol = 2 
	
	forval i = 30(30)180 {
	
	preserve
	keep if lastdash - assigned_d >= `i'
	
	/* Generate variable with number that are eligible for this */
	by site p_id, sort: gen t_denom = _n == 1
		replace t_denom = sum(t_denom)
		replace t_denom = t_denom[_N]
	
	local col: word `ncol' of `c(ALPHA)'
	putexcel `col'3 = t_denom
	sum count if submitted_t < `i'
	putexcel `col'4 = ((`r(N)')/t_denom), nformat(percent)
	sum count if issued_t < `i'
	putexcel `col'5 = ((`r(N)')/t_denom), nformat(percent)
	sum count if leasedup_t < `i'
	putexcel `col'6 = ((`r(N)')/t_denom), nformat(percent)
		
	local ++ncol
	restore 
	}
	
	sum count if lastdash - assigned_d >= 180
	putexcel H3 = `r(N)'
	putexcel I3 = `r(N)'
	summarize submitted_t if lastdash - assigned_d >= 180, detail
	local mean = round(`r(mean)',0.1)
	putexcel H4 = `mean'
	putexcel I4 = `r(p50)'
	summarize issued_t if lastdash - assigned_d >= 180, detail 
	local mean = round(`r(mean)',0.1)
	putexcel H5 = `mean'
	putexcel I5 = `r(p50)'
	summarize leasedup_t if lastdash - assigned_d >= 180, detail 
	local mean = round(`r(mean)',0.1)
	putexcel H6 = `mean'
	putexcel I6 = `r(p50)'
	
	/* Create table conditional on previous step */
	preserve
	keep if lastdash - assigned_d >= 180
	
	putexcel A7 = "Conditional Outcomes: Among those observed for at least 6 months"
	putexcel B8 = "Share achieving outcome", txtwrap
	putexcel C8 = "Mean days from previous step", txtwrap
	putexcel D8 = "Median days from previous step", txtwrap
	putexcel A9 = "N"
	putexcel A10 = "Application submission", txtwrap
	putexcel A11 = "Voucher Issuance (conditional)", txtwrap
	putexcel A12 = "Leased Up (conditional)", txtwrap
	
	gen issued_t_marg = (issued_t - submitted_t) if submitted == 1 
	gen leasedup_t_marg = (leasedup_t - issued_t)  if issued == 1 
	/* confining to only count outcomes observed within 6 months */
	replace submitted_t = . if submitted_t > 180
	replace issued_t_marg = . if issued_t > 180
	replace leasedup_t_marg = . if leasedup_t > 180
	
	by site p_id, sort: gen t_denom = _n == 1
		replace t_denom = sum(t_denom)
		replace t_denom = t_denom[_N]
	
	sum count 
	putexcel B9 = `r(N)'
	putexcel C9 = `r(N)'
	putexcel D9 = `r(N)'
	sum count if submitted == 1 & submitted_t <= 180
	putexcel B10 = ((`r(N)')/t_denom), nformat(percent)
	sum count if issued == 1 & issued_t <= 180
	putexcel B11 = ((`r(N)')/t_denom), nformat(percent)
	sum count if leasedup == 1 & leasedup_t <= 180
	putexcel B12 = ((`r(N)')/t_denom), nformat(percent)
	
	summarize submitted_t, detail
	local mean = round(`r(mean)',0.1)
	putexcel C10 = `mean'
	putexcel D10 = `r(p50)'
	summarize issued_t_marg, detail
	local mean = round(`r(mean)',0.1)
	putexcel C11 = `mean'
	putexcel D11 = `r(p50)'
	summarize leasedup_t_marg, detail
	local mean = round(`r(mean)',0.1)
	putexcel C12 = `mean'
	putexcel D12 = `r(p50)'
	
	restore 

	}
	
	
	
	{ /* SITE SPECIFIC */
	
	
	foreach site in KCSEA PHX OC BC {
		
	putexcel set "${tables}Milestone_$S_DATE.xlsx", sheet("`site'") modify
	
	putexcel A1 = "Milestones (within N months is calculated only among families observed in the dashboard data for N months)"
	putexcel A2 = "Outcome"
	putexcel B2 = "Within 1 month", txtwrap
	putexcel C2 = "Within 2 months", txtwrap
	putexcel D2 = "Within 3 months", txtwrap
	putexcel E2 = "Within 4 months", txtwrap
	putexcel F2 = "Within 5 months", txtwrap
	putexcel G2 = "Within 6 months", txtwrap
	putexcel H2 = "Mean days from referral for those observed at least 6 mo.", txtwrap
	putexcel I2 = "Median days from referral for those observed at least 6 mo.", txtwrap
	putexcel A3 = "N"
	putexcel A4 = "Application submitted"
	putexcel A5 = "Voucher issued"
	putexcel A6 = "Leased up"

	local ncol = 2 
	
	/* Loop through time intervals */
	forval i = 30(30)180 {
	
	preserve
	keep if lastdash - assigned_d >= `i' & site_text == "`site'"
	
	/* Generate variable with number that are eligible for this */
	by site p_id, sort: gen t_denom = _n == 1
		replace t_denom = sum(t_denom)
		replace t_denom = t_denom[_N]
	
	local col: word `ncol' of `c(ALPHA)'
	putexcel `col'3 = t_denom
	sum count if submitted_t < `i'
	putexcel `col'4 = ((`r(N)')/t_denom), nformat(percent)
	sum count if issued_t < `i'
	putexcel `col'5 = ((`r(N)')/t_denom), nformat(percent)
	sum count if leasedup_t < `i'
	putexcel `col'6 = ((`r(N)')/t_denom), nformat(percent)
		
	local ++ncol
	restore 
	}
	
	summarize count if lastdash - assigned_d >= 180 & site_text == "`site'"
	putexcel H3 = `r(N)'
	putexcel I3 = `r(N)'
	summarize submitted_t if site_text == "`site'" & lastdash - assigned_d >= 180, detail
	local mean = round(`r(mean)',0.1)
	putexcel H4 = `mean'
	putexcel I4 = `r(p50)'
	summarize issued_t if site_text == "`site'" & lastdash - assigned_d >= 180, detail 
	local mean = round(`r(mean)',0.1)
	putexcel H5 = `mean'
	putexcel I5 = `r(p50)'
	summarize leasedup_t if site_text == "`site'" & lastdash - assigned_d >= 180, detail 
	local mean = round(`r(mean)',0.1)
	putexcel H6 = `mean'
	putexcel I6 = `r(p50)'

	
	/* Create table conditional on previous step */
	preserve
	keep if lastdash - assigned_d >= 180 & site_text == "`site'"
	
	putexcel A7 = "Conditional Outcomes: Among those observed for at least 6 months"
	putexcel B8 = "Share achieving outcome", txtwrap
	putexcel C8 = "Mean days from previous step", txtwrap
	putexcel D8 = "Median days from previous step", txtwrap
	putexcel A9 = "N"
	putexcel A10 = "Application submission", txtwrap
	putexcel A11 = "Voucher Issuance (conditional)", txtwrap
	putexcel A12 = "Leased Up (conditional)", txtwrap
	
	gen issued_t_marg = (issued_t - submitted_t) if submitted == 1 
	gen leasedup_t_marg = (leasedup_t - issued_t)  if issued == 1 
	/* confining to only count outcomes observed within 6 months */
	replace submitted_t = . if submitted_t > 180
	replace issued_t_marg = . if issued_t > 180
	replace leasedup_t_marg = . if leasedup_t > 180
	
	by site p_id, sort: gen t_denom = _n == 1
		replace t_denom = sum(t_denom)
		replace t_denom = t_denom[_N]
	
	sum count 
	putexcel B9 = `r(N)'
	putexcel C9 = `r(N)'
	putexcel D9 = `r(N)'
	sum count if submitted == 1 & submitted_t <= 180
	putexcel B10 = ((`r(N)')/t_denom), nformat(percent)
	sum count if issued == 1 & issued_t <= 180
	putexcel B11 = ((`r(N)')/t_denom), nformat(percent)
	sum count if leasedup == 1 & leasedup_t <= 180
	putexcel B12 = ((`r(N)')/t_denom), nformat(percent)
	
	summarize submitted_t, detail
	local mean = round(`r(mean)',0.1)
	putexcel C10 = `mean'
	putexcel D10 = `r(p50)'
	summarize issued_t_marg, detail
	local mean = round(`r(mean)',0.1)
	putexcel C11 = `mean'
	putexcel D11 = `r(p50)'
	summarize leasedup_t_marg, detail
	local mean = round(`r(mean)',0.1)
	putexcel C12 = `mean'
	putexcel D12 = `r(p50)'
	
	restore 
	} 
	
	}
	
	
	{ /* PRES/REUNIFICATION*/
	
	foreach status in Pres Reunif {
		
	putexcel set "${tables}Milestone_$S_DATE.xlsx", sheet("`status'") modify
	
	putexcel A1 = "Milestones (within N months is calculated only among families observed in the dashboard data for N months)"
	putexcel A2 = "Outcome"
	putexcel B2 = "Within 1 month", txtwrap
	putexcel C2 = "Within 2 months", txtwrap
	putexcel D2 = "Within 3 months", txtwrap
	putexcel E2 = "Within 4 months", txtwrap
	putexcel F2 = "Within 5 months", txtwrap
	putexcel G2 = "Within 6 months", txtwrap
	putexcel H2 = "Mean days from referral for those observed at least 6 mo.", txtwrap
	putexcel I2 = "Median days from referral for those observed at least 6 mo.", txtwrap
	putexcel A3 = "N"
	putexcel A4 = "Application submitted"
	putexcel A5 = "Voucher issued"
	putexcel A6 = "Leased up"

	local ncol = 2 
	
	/* Loop through time intervals */
	forval i = 30(30)180 {
	
	preserve
	keep if lastdash - assigned_d >= `i' & cw_text == "`status'"
	
	/* Generate variable with number that are eligible for this */
	by site p_id, sort: gen t_denom = _n == 1
		replace t_denom = sum(t_denom)
		replace t_denom = t_denom[_N]
	
	local col: word `ncol' of `c(ALPHA)'
	putexcel `col'3 = t_denom
	sum count if submitted_t < `i'
	putexcel `col'4 = ((`r(N)')/t_denom), nformat(percent)
	sum count if issued_t < `i'
	putexcel `col'5 = ((`r(N)')/t_denom), nformat(percent)
	sum count if leasedup_t < `i'
	putexcel `col'6 = ((`r(N)')/t_denom), nformat(percent)
		
	local ++ncol
	restore 
	}
	
	summarize count if lastdash - assigned_d >= 180 & cw_text == "`status'" 
	putexcel H3 = `r(N)'
	putexcel I3 = `r(N)'
	summarize submitted_t if cw_text == "`status'"  & lastdash - assigned_d >= 180, detail
	local mean = round(`r(mean)',0.1)
	putexcel H4 = `mean'
	putexcel I4 = `r(p50)'
	summarize issued_t if cw_text == "`status'"  & lastdash - assigned_d >= 180, detail 
	local mean = round(`r(mean)',0.1)
	putexcel H5 = `mean'
	putexcel I5 = `r(p50)'
	summarize leasedup_t if cw_text == "`status'"  & lastdash - assigned_d >= 180, detail 
	local mean = round(`r(mean)',0.1)
	putexcel H6 = `mean'
	putexcel I6 = `r(p50)'

	
	/* Create table conditional on previous step */
	preserve
	keep if lastdash - assigned_d >= 180 & cw_text == "`status'"
	
	putexcel A7 = "Conditional Outcomes: Among those observed for at least 6 months"
	putexcel B8 = "Share achieving outcome within 6 mo", txtwrap
	putexcel C8 = "Mean days from previous step", txtwrap
	putexcel D8 = "Median days from previous step", txtwrap
	putexcel A9 = "N"
	putexcel A10 = "Application submission", txtwrap
	putexcel A11 = "Voucher Issuance (conditional)", txtwrap
	putexcel A12 = "Leased Up (conditional)", txtwrap
	
	gen issued_t_marg = (issued_t - submitted_t) if submitted == 1 
	gen leasedup_t_marg = (leasedup_t - issued_t)  if issued == 1 
	/* confining to only count outcomes observed within 6 months */
	replace submitted_t = . if submitted_t > 180
	replace issued_t_marg = . if issued_t > 180
	replace leasedup_t_marg = . if leasedup_t > 180
	
	by site p_id, sort: gen t_denom = _n == 1
		replace t_denom = sum(t_denom)
		replace t_denom = t_denom[_N]
	
	sum count 
	putexcel B9 = `r(N)'
	putexcel C9 = `r(N)'
	putexcel D9 = `r(N)'
	sum count if submitted == 1 & submitted_t <= 180
	putexcel B10 = ((`r(N)')/t_denom), nformat(percent)
	sum count if issued == 1 & issued_t <= 180
	putexcel B11 = ((`r(N)')/t_denom), nformat(percent)
	sum count if leasedup == 1 & leasedup_t <= 180
	putexcel B12 = ((`r(N)')/t_denom), nformat(percent)
	
	summarize submitted_t, detail
	local mean = round(`r(mean)',0.1)
	putexcel C10 = `mean'
	putexcel D10 = `r(p50)'
	summarize issued_t_marg, detail
	local mean = round(`r(mean)',0.1)
	putexcel C11 = `mean'
	putexcel D11 = `r(p50)'
	summarize leasedup_t_marg, detail
	local mean = round(`r(mean)',0.1)
	putexcel C12 = `mean'
	putexcel D12 = `r(p50)'
	
	restore 
	} 
	
	}
	
	// think about how the missings are being incorporated to ensure it's right 
	// look at data to confirm it looks right -- what is the summarize percentiles showing
	// add notes 
	
	
	
	
	
	
		
