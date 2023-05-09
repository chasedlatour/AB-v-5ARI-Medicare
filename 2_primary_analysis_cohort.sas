/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: primary_analysis
	PURPOSE: The goal of this program is to run primary analyses of the alpha-blockers vs. 
	5-alpha reductase inhibitors analysis. This code only considers the primary cohort without
	bootstrapping. Other code is provided that was batch-submitted to conduct bootstrapping
	and subsequently summarize those estimates.

	CREATED BY: Chase Latour
	DATE CREATED: 2023 JAN 10

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - OUTPUT TABLE 1
	02 - FIT PS MODEL
	03 - ASSESS FIT AND PLOT PS DISTRIBUTION
	04 - CALCULATE WEIGHTS
	05 - ASSESS BALANCE
	06 - LOOK AT HOSPICE
	07 - CHECK CENSORING EVENTS
	08 - CALCULATE EFFECT ESTIMATES
	09 - LOOK AT TRT DISCONTINUATION & SWITCHING
	10 - CALCULATE N REMOVED FROM EACH SPECIFIC ANALYSIS
	11 - INVESTIGATE GNN = 'MULTIPLE'

************************************************************************************************/





/************************************************************************************************
										00 - SET-UP

This set-up information uses the %setup macro and maps to UNC's Cecil G. Sheps servers.
************************************************************************************************/

*Local submit to prompt sign on into server;
SIGNOFF;
%LET server=n2.schsr.unc.edu 1234;options comamid=tcp remote=server;signon username=_prompt_;

*Set up directories for project;
options source source2 msglevel=I mcompilenote=all mautosource mprint
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, 2_primary_analysis_cohort, saveLog=N);
*%setup(1pct, primary_analysis, saveLog=N);

*libname ana "/local/projects/medicare/ablocker/data/full/analysis/";

*Map local mirrors for all remote libraries using LOCAL submit;
libname lout slibref=out server=server;
libname lwork slibref=work server=server;
libname lraw slibref=raw server=server;
libname lder slibref=der server=server;



*Create formats;
proc format;
   value $ raceCat 'W'='White' 'B'='Black' 'H'='Hispanic' 'O'='Other';
   value exclcat 0 = "Not excluded" 1 = "Excluded";
   value filled 0 = "Filled" 1 = "Did not fill";
 	value yn 0='No' 1 ='Yes';
	value ab 0='AR5' 1='AB';
	value drugcat 0 = 'No fill in last 12 month' 1= 'One fill in last 12 months' 2 = 'Two or more fills in last 12 months';
	value hypercat 0 = "No fill in last 12 months" 1 = "One fill of same drug class in last 12 months" 2 = "Two or more fills of the same drug class" 3 = "Two or more fills of different drug classes";
run;






/************************************************************************************************
										01 - OUTPUT TABLE 1

These are the descriptive statistics of the entire study population without any PS 
trimming. These won't be presented in the later results because it makes sense to compare
the unweighted and weighted versions of the same study population.

This is just included for data exploration of the total study population.
************************************************************************************************/

*Output table 1;

proc sort data=ana.primary_cohort out=cohort_primary; by bene_id indexdate; run;
%table1(inds = cohort_primary, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_heartfail bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
				bl_otherdiuretics
			bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
			/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
			bl_sulfonylurea bl_tzd
			bl_athero bl_obesity
			/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
			bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
			bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
			bl_outpatientvisit bl_oxygen bl_wheelchair, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





***
We wanted to look at the distributions of the medications prescribed at the indexing 
fills over time.
***;


*Rename Multiple so it can be separated by type;
data cohort_primary;
set cohort_primary;
	if ab = 1 and gnn = "Multiple" then gnn = "Multiple-AB";
		else if ab = 0 and gnn = "Multiple" then gnn = "Multiple-5ARI";
		else if ab = 0 then gnn = gnn;
		else if ab = 1 then gnn = gnn;
run;
*Describe distribution of each med;
proc sort data=cohort_primary;
	by ab;
run;
proc freq data=cohort_primary;
	by ab;
	tables gnn;
run;

*Describe the distribution of meds by calendar year.;
data cohort_primary;
set cohort_primary;
	year_index = year(indexdate);
run;
/*proc sort data=cohort_primary; by ab; run;*/
proc freq data=cohort_primary ;
	*by ab;
	tables gnn * year_index / out=proportion_year outpct;
run;

*Look at a plot of the proportions;
ods graphics on / reset imagename="Treatment Proportions by Year";
proc sgplot data=proportion_year;
	title "Benign Prostatic Hyperplasia Treatment Percentages by Year";
	vbar year_index / response = pct_col stat = sum group=gnn nostatlabel;
	xaxis label="Year of Index Date";
	yaxis label = "Percentage of BPH Prescriptions the Year";
	keylegend / title="Generic Name of Index Drug";
	*keylegend / location=inside position = topleft;
run;

*Output this as a  table and print the RTF file.;
proc sort data=proportion_year out=prop_yr_sort;
	by year_index gnn;
run;
data prop_yr_sort;
set prop_yr_sort;
	pct_col = round(pct_col, 0.01);
run;

proc freq data=prop_yr_sort; 
	tables ab*gnn;
run;

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Distribution of Medications Over Time.rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=prop_yr_sort noobs label;
   	var year_index gnn count pct_col;
	run;

ods rtf close;




/************************************************************************************************
										02 - FIT PS MODEL
************************************************************************************************/


*Look at the probability of treatment by age
-- Trying to understand how variables are associated with the study outcomes;
/*proc freq data=cohort_primary;*/
/*	tables age * ab;*/
/*run;*/
*Not much of a relationship, slightly linear;

*Build the propensity score model;
%ps(inds = cohort_primary, outds = ps);




***Output the model's predictor parameters.;
proc logistic data=cohort_primary covout outest=primary_ps_pretrim noprint;
		class cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_rehab bl_oxygen bl_wheelchair;
		model ab (reference = /*'0'*/ 'AR5') = age cal_year bl_aur bl_tobacco 
				age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_rehab bl_oxygen bl_wheelchair
run;


proc means data=ana.primary_cohort min max;
	var age;
run;

*Export the dataset as an Excel spreadsheet;
proc export data=primary_ps_pretrim
	outfile="/local/projects/medicare/ablocker/output/full/PS model in primary pre-trimmed dataset.xlsx"
	dbms=xlsx replace;
run;



/************************************************************************************************
							03 - ASSESS FIT AND PLOT PS DISTRIBUTION
************************************************************************************************/


*Look at a plot of the PSs;
/*ods graphics on / reset imagename="PS Distributions - Hist - Primary";*/
/*proc sgplot data=ps;*/
/*	title "Histogram - PS Distributions by Treatment Group in the Primary Cohort";*/
/*	histogram ps / group = ab transparency=0.7;*/
/*	*density ps / type = kernel;*/
/*	keylegend / location=inside position = topleft;*/
/*run;*/

*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Density - Primary";
proc sgplot data=ps;
	title "Density - PS Distributions by Treatment Group in the Primary Cohort";
	*histogram ps / group = ab;
	density ps / group = ab type = kernel;
	keylegend / location=inside position = topleft;
run;

*For primary analyses, trim non-overlapping PSs;

*Calculate the min and max of each so that we can trim the non-overlapping regions;
proc sort data=ps; by ab; run;
proc means data=ps mean min max;
	class ab;
	var ps;
	output out=sumstat min=minPS max=maxPS;
run;

*Want to apply to opposite treatments;
data sumstat2;
set sumstat;
	if ab = 0 then jointo = 1;
		else if ab = 1 then jointo = 0;
run;


*Merge the datasets so that can remove people;
proc sql;
	create table ps2 as
	select a.*, b.minPS, b.maxPS
	from ps as a
	left join sumstat2 as b
	on a.ab = b.jointo
	;
	quit;

*Indicate which values to delete & remove those individuals;
data ps3 (where = (delete = 0));
set ps2;
	delete=0;
	if ab = 0 & ps <= minPS then delete=1;
	if ab = 1 & ps >= maxPS then delete=1;
run;
*Now, 189,866 individuals;


***
Need to re-fit the PS model in that population.
***;


*Re-fit PS model;
%ps(inds = ps3, outds = ps_trim);

/*proc means data=ps_trim min max;*/
/*	class ab;*/
/*	var ps2;*/
/*run;*/

*Look at a plot of the PSs - Histogram, hard to see;
/*ods graphics on / reset imagename="PS Distributions - Hist - Primary - Trimmed";*/
/*proc sgplot data=ps_trim;*/
/*	title "Histogram - PS Distributions by Treatment Group in the Primary Cohort After Trimming";*/
/*	histogram ps2 / group = ab transparency=0.7;*/
/*	*density ps / type = kernel;*/
/*	keylegend / location=inside position = topleft;*/
/*run;*/

*Look at a plot of the PSs - DENSITY;
ods graphics on / reset imagename="PS Distributions - Density - Primary - Trimmed";
proc sgplot data=ps_trim;
	title "Density - PS Distributions by Treatment Group in the Primary Cohort After Trimming";
	*histogram ps / group = ab;
	density ps2 / group = ab type = kernel;
	keylegend / location=inside position = topleft;
run;




/************************************************************************************************
									04 - CALCULATE WEIGHTS
************************************************************************************************/

%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Calculate mean, max, and min of weights;
proc means data=cohort_weights2 max min mean;
	class ab;
	var iptw;
run;


/************************************************************************************************
									05 - ASSESS BALANCE
************************************************************************************************/


**
Create new tables in trimmed population
**;

*Unweighted;
proc sort data=ps_trim; by bene_id indexdate; run;
%table1(inds = ps_trim, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
				bl_otherdiuretics
			bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
			/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
			bl_sulfonylurea bl_tzd
			bl_athero bl_obesity
			/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
			bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
			bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
			bl_rehab bl_oxygen bl_wheelchair, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_Trimmed Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





*Output the IPTW Table 1:

Can use table1 macro for weighted comparison;
proc sort data=cohort_weights2; by bene_id indexdate; run;
%table1(inds = cohort_weights2, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz  bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
				bl_otherdiuretics
			bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
			/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
			bl_sulfonylurea bl_tzd
			bl_athero bl_obesity
			/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
			bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
			bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
			bl_rehab bl_oxygen bl_wheelchair, wgtVar = iptw, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics with IPTW_Trimmed Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;




/**********************************************************************************
							06 - LOOK AT HOSPICE

Goal is to understand the role of hospice in the analysis - if it is truly a
competing event.

Decision was that it was not because you can see events occur afterwards for 
all outcomes (even if very small). 
**********************************************************************************/

***
Look at the number of people that have events after entering hospice
***;

data hospice;
set ana.primary_cohort;
	where fup_hospice_dt ne .;

	*Number of HF events after hospice;
	if fup_hospice_dt < HF_date then hospice_hf = 1;

	*Number of Mace events after hospice;
	if fup_hospice_dt < min(mi_date, stroke_date) then hospice_mace = 1;

	*Number of PCI events after hospice;
	if fup_hospice_dt < pcip_date then hospice_pcip = 1;

	*Number fo CABG events after hospice;
	if fup_hospice_dt < cabg_date then hospice_cabg = 1;

run;

proc freq data=hospice;	
	tables hospice_hf hospice_mace hospice_pcip hospice_cabg;
run;





*Create a competing event outcome that's the minimum of hospice start
	date and the death date

Decided not use initiation of hospice as a competing event because there
were events of interest afterwards;
/*data primary_analysis;*/
/*set primary_analysis;*/
/**/
/*	compEvent_dt = min(fup_hospice_dt, death_dt);*/
/**/
/*run;*/






***
Check proportion of death vs. hospice events
***;
/**/
/*data compevent;*/
/*set primary_analysis;*/
/*	*/
/*	if compEvent_dt = death_dt then outcome = "death";*/
/*		else if compEvent_dt = fup_hospice_dt then outcome = "Hospice";*/
/*		else if compEvent_dt = . then outcome = "Neither";*/
/*run;*/
/*proc freq data=compevent;*/
/*	tables ab*outcome;*/
/*run;*/
*Supports the idea that hospice should be combined with death - only about 12-13% of otucome events
I guess could technically estimate these separately.;


	
/********************************************************************************
							07 - CHECK CENSORING EVENTS

Here, we have defined censoring as disenrollment from Medicare Parts A & B.
********************************************************************************/


***
Assess censoring in the cohort;
***;
data censoring;
set ana.primary_cohort;
	where death_dt = .;
	if endDT_itt /*censorDate_itt*/ - fillDate2 < 366 then censor366 = 1; else censor366 = 0;
	if endDT_itt /*censorDate_itt*/ - fillDate2 < 1825 then censor1825 = 1; else censor1825 = 0;
run;

*Look at the frequency breakdown by censoring events;
proc sort data=censoring; by ab; run;
proc means data=censoring mean;
	by ab;
	var censor366 censor1825;
run;

*There's quite a bit of censoring here. Further, it's different by treatment, particularly by treatment;


*Try to figure out what variables are associated with censoring;
proc freq data=censoring;
	where death_dt = .;
	tables censor366*(age cal_year rti_race
			bl_aur bl_chdz bl_heartfail 
			bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_athero bl_obesity);
run;

	



/**********************************************************************************
						08 - CALCULATE EFFECT ESTIMATES

The final study estimates will be calculated with boot-strapping. However,
it will be good to understand what the estimate is in the primary study population
prior to bootstrapping.

We want to calculate crude and adjusted estimates.
**********************************************************************************/

****Macro that we will need later.

Be sure to run this all in order;



**Want to get counts at 50 day intervals;

%MACRO count_survival(outcome=, outds=, inds=_anacohort);

	data _out1_&outcome;
	set &inds;

		if days_&outcome > 0 then &outcome.0 = 1;
			else &outcome.0 = 0;
		if days_&outcome > 50 then &outcome.50 = 1;
			else &outcome.50 = 0;
		if days_&outcome > 100 then &outcome.100 = 1;
			else &outcome.100 = 0;
		if days_&outcome > 150 then &outcome.150 = 1;
			else &outcome.150 = 0;
		if days_&outcome > 200 then &outcome.200 = 1;
			else &outcome.200 = 0;
		if days_&outcome > 250 then &outcome.250 = 1;
			else &outcome.250 = 0;
		if days_&outcome > 300 then &outcome.300 = 1;
			else &outcome.300 = 0;
		if days_&outcome > 350 then &outcome.350 = 1;
			else &outcome.350 = 0;

		keep bene_id ab &outcome.0 &outcome.50 &outcome.100 &outcome.150
				&outcome.200 &outcome.250 &outcome.300
				&outcome.350;

	run;

	proc sql;
		create table &outds as
		select ab, sum(&outcome.0) as sum0, sum(&outcome.50) as sum50,
				sum(&outcome.100) as sum100, sum(&outcome.150) as sum150,
				sum(&outcome.200) as sum200, sum(&outcome.250) as sum250,
				sum(&outcome.300) as sum300, sum(&outcome.350) as sum350
		from _out1_&outcome
		group by ab
		; 
		quit;


%MEND;




**
Calculate the RD and RR estimates that we need.

Needs to have different values based on the outcome assessed
	(1) hosp for HF
	(2) composite MACE (hosp for stroke, MI, or death from any cause)
	(3) composite MACE or hosp for HF
	(4) death from any cause
	(5) PCIP
	(6) CABG

Need to eventually set this to 2,000 iterations for the Bootstrapping.
**;




**
(1) hosp for HF
**;

***
365
***;
* Estimate with IPTW;
%competingrisk_single_weights(inds=ana.primary_cohort, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
      numiterations=1, initialseed=23244, outds=ana.HF_365_sample, noiptw=0);


*Rename the days variable so that we can use the macro we specified earlier;

data _anacohort;
set _anacohort;
	rename days = days_hf;
run;
%count_survival(outcome=hf, outds=ana.survival_hf);


**censorDT might should be endDT_itt, censorDate_ITT = min(abenddt, death_dt);


**
(2) Composite MACE
(3) Composite MACE + HF
(4) Death

	  These are all run in the same macro to minimize sampling requirements.
**;


***
365
***;

*With IPTW;

%risk_weights_multiple_sample(inds=ana.primary_cohort, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=p_samp, noiptw=0,
      numiterations=1);


%count_survival(outcome=mace, outds=ana.survival_count_mace);
%count_survival(outcome=macehf, outds=ana.survival_macehf);
%count_survival(outcome=death, outds=ana.survival_death);





/******************************************************************************
	  			08b - LOOK AT CUMULATIVE INCIDENCE FUNCTIONS

Want to print a 4-panel figure with all of the cumulative incidence functions
	  for each of the study outcomes.

Do this for mortality outcomes first, and then figure it out for HF, since
	  it has a competing event.
******************************************************************************/



****MACE -- Need to have run the sample code above.;

*Make risk variable;
data _c2_mace;
set _c2_mace;
	risk = 1-s;
run;
ods graphics on / reset imagename="MACE CIF Curve" noborder;
title "(b) Major Adverse Cardiovascular Events (MACE)" ;
proc sgplot data=_c2_mace noautolegend;
	styleattrs datacontrastcolors = (tomato darkturquoise);
	step x = days_mace y = risk/group = ab name = "km" lineattrs=(thickness=2);
	xaxis label = "Days From Treatment Initiation" max = 365 labelattrs=(size=12) valueattrs=(size=14) values=(0 to 365 by 50);
	yaxis label = "Cumulative Risk" min=0 max = .125 labelattrs=(size=12) valueattrs=(size=14);
	keylegend "km"/location = inside position = bottomright across=1 down=2 noborder valueattrs=(size=14);
	*format noart afmt.;
	footnote;
run;
title;


****MACE + HF;
data _c2_macehf;
set _c2_macehf;
	risk = 1-s;
run;
ods graphics on / reset imagename="MACE HF CIF Curve" noborder;
title "(c) Composite MACE or HF";
proc sgplot data=_c2_macehf noautolegend;
	styleattrs datacontrastcolors = (tomato darkturquoise);
	step x = days_macehf y = risk/group = ab name = "km" lineattrs=(thickness=2);
	xaxis label = "Days From Treatment Initiation" max = 365 labelattrs=(size=12) valueattrs=(size=14) values=(0 to 365 by 50);
	yaxis label = "Cumulative Risk" min=0 max = .125 labelattrs=(size=12) valueattrs=(size=14);
	keylegend "km"/location = inside position = bottomright across=1 down=2 noborder valueattrs=(size=14);
	*format noart afmt.;
	footnote;
run;
title;


****Death;
data _c2_death;
set _c2_death;
	risk = 1-s;
run;
ods graphics on / reset imagename="Death CIF Curve" noborder;
title "(d) All-Cause Mortality";
proc sgplot data=_c2_death noautolegend;
	styleattrs datacontrastcolors = (tomato darkturquoise);
	step x = days_death y = risk/group = ab name = "km" lineattrs=(thickness=2);
	xaxis label = "Days From Treatment Initiation" max = 365 labelattrs=(size=12) valueattrs=(size=14) values=(0 to 365 by 50);
	yaxis label = "Cumulative Risk" min=0 max = .125 labelattrs=(size=12) valueattrs=(size=14);
	keylegend "km"/location = inside position = bottomright across=1 down=2 noborder valueattrs=(size=14);
	*format noart afmt.;
	footnote1;
run;
title;






data ana.primary_hf/*(keep=&trtvar %DO d=1 %TO &numEst; rate&&est&d %END;rate&daysEst)*/; 
         merge _combined _outcome _comprisk; by ab days;
         retain cum_outcome 0 cum_comprisk 0 olds_combined olds_outcome olds_comprisk 
                rate365;
         if first.ab then do; rate365=.; end; 
         if days=0 then do; 
            olds_combined=1; olds_outcome=1; olds_comprisk=1; iptw=1; 
            outcome=0; comprisk=0; cum_outcome=0; cum_comprisk=0; e_outcome=0; e_comprisk=0; 
         end;

         *%DO d=1 %TO &numEst;
            /*if days>=365 and rate365=. then do; rate365=1-cum_outcome; output; end;*/
         *%END;

         if s_outcome ne .  then do; 
            h_outcome=-log(s_outcome)--log(olds_outcome); 
            e_outcome=olds_combined*h_outcome;   
            cum_outcome=cum_outcome+e_outcome; 
         end;

         if s_comprisk ne . then do; 
            h_comprisk=-log(s_comprisk)--log(olds_comprisk); 
            e_comprisk=olds_combined*h_comprisk; 
            cum_comprisk=cum_comprisk+e_comprisk; 
         end;  

         combined=cum_outcome+cum_comprisk;
         if s_combined ne . then olds_combined=s_combined;
         if s_outcome ne . then olds_outcome=s_outcome;
         if s_comprisk ne . then olds_comprisk=s_comprisk;

         if last.ab then do; 
            if rate365=. then do; rate365 = 1 - cum_outcome; *output; end;  end;
      run;


****Heart Failure;
ods graphics on / reset imagename="HF CIF Curve" noborder;
title "(a) Heart Failure (HF)";
proc sgplot data=ana.primary_hf noautolegend;
	styleattrs datacontrastcolors = (tomato darkturquoise);
	step x = days y = cum_outcome/group = ab name = "km" lineattrs=(pattern=solid thickness=2);
	xaxis label = "Days From Treatment Initiation" max = 365 labelattrs=(size=12) valueattrs=(size=14) values=(0 to 365 by 50);
	yaxis label = "Cumulative Risk" min=0 max = .125 labelattrs=(size=12) valueattrs=(size=14);
	keylegend "km"/location = inside position = bottomright across=1 down=2 noborder valueattrs=(size=14);
	*format noart afmt.;
	footnote;
run;
title;






*Finally, print out the number ;

proc print data=ana.survival_hf; run;
proc print data=ana.survival_mace; run;
proc print data=ana.survival_macehf; run;
proc print data=ana.survival_death; run;




/******************************************************************************
	  			09 - LOOK AT TRT DISCONTINUATION & SWITCHING

Our goal here is to understand how long people are continuously using these
medications after being assigned to them and what treatment switching looks like.
******************************************************************************/


*First, figure out what variables we should be working with;
proc contents data=ana.primary_cohort; run;

*Does everyone have a enddt_itt value?;
proc summary data=ana.primary_cohort;
	var endDt_ITT;
	output out=mm min=min max=max;
run;
*Yes - there are no missing values;


*Calculate the days to treatment discontinuation, new med, and censoring;
data day_summary;
set ana.primary_cohort;

	*Want INF to be the value if they don't have a date for that value
	because we want to be able to identify the smallest time;
	if discontDate = . then 
		days_discont = .I; *This should set to infinity;
		else days_discont = discontDate - FillDate2;

	if switchAugmentDate = . then
		days_switchaug = .I;
		else days_switching = switchAugmentDate - FillDate2;

	days_censor = endDT_ITT - FillDate2;

run;


*Determine which event occurs first and assign that to a variable to
describe the earliest event and the timing of that event;
data day_summary2;
set day_summary (keep = ab discontDate FillDate2 switchAugmentDate endDT_ITT days_censor days_switching days_discont bene_id);
length event $ 13;
	
	days = min(days_discont, days_switching, days_censor);

	if days = days_censor then event = "Censor";
		else if days = days_discont then event = "Discontinue";
		else if days = days_switching then event = "Other Rx Fill";
		else if discontDate = endDT_ITT then event = "Censor";

run;

*Plot a histogram of these times to event;

ods graphics on / reset imagename="Days from 2nd Index Fill";
proc sgpanel data=day_summary2;
	title "Days From the Second Fill Until the Indicated Outcome";
	panelby ab / layout=rowlattice rows=2;
	histogram days / group=event transparency = 0.6;
run;
title ;



*Calculate stats to describe the days to events;

*Calculate the proportion to 1, 2, and 3 years;

data day_summary3;
set day_summary2;
	
	*Create nested flags of where the days are;
	if days <= 365 then days365 = 1;
		else days365 = 0;

	if days <= 730 then days730 = 1;
		else days730 = 0;

	if days <= 1095 then days1095 = 1;
		else days1095 = 0;

run;


*Count the number of people in each event category;
proc freq data=day_summary3 (where = (ab=1));
	tables event;
run;
proc freq data=day_summary3 (where = (ab=0));
	tables event;
run;

*Count the median and IQR for  days since the follow-up;

*AB first;
proc means data=day_summary3 (where = (ab=1)) median q1 q3;
	class event;
	var days;
run;
*5ARI;
proc means data=day_summary3 (where = (ab=0)) median q1 q3;
	class event;
	var days;
run;

*Now look at the counts and percentages until follow-up for the treatment events.;
proc freq data=day_summary3 (where = (ab=1));
	tables days365*event days730*event days1095*event;
run;
proc freq data=day_summary3 (where = (ab=0));
	tables days365*event days730*event days1095*event;
run;









/**********************************************************************************
				10 - CALCULATE N REMOVED FROM EACH SPECIFIC ANALYSIS

Each outcome-specific analysis will have a slightly different number of 
patients included becuase individuals with outcomes between the 1st and 2nd rx
fill are removed. Here, we count the number of individuals removed from each of 
the analyses because they experienced an outcome prior to their second rx fill.
**********************************************************************************/


*Prepare the analytic cohorr -- Similar to what's done in the risk macro;

data _anacohort;
set ana.primary_cohort;

	outcome_dt_mace = min(mi_date, stroke_date, death_dt);
	outcome_dt_macehf = min(mi_date, stroke_date, death_dt, HF_date);
	outcome_dt_death = death_dt;
	outcome_dt_hf = min(HF_date, death_dt);
	*FillDate2;

	***Indicate if outcome is before the 2nd rx fill date;

	*For non-competing events;
	if .z < outcome_dt_mace < filldate2 then mace_ind = 1;
		else mace_ind = 0;
	if .z < outcome_dt_macehf < filldate2 then macehf_ind = 1;
		else macehf_ind = 0;
	if .z < outcome_dt_death < filldate2 then death_ind = 1;
		else death_ind = 0;

	*For competing events;
	if .z < outcome_dt_hf < filldate2 then hf_total_ind = 1;
		else hf_total_ind = 0;
	if outcome_dt_hf = HF_date and .z < outcome_dt_hf < filldate2 then hf_ind = 1;
		else hf_ind = 0;
	if outcome_dt_hf = death_dt and .z < outcome_dt_hf < filldate2 then hf_death_ind = 1;
		else hf_death_ind=0;

run;

*Count these;
proc freq data=_anacohort;
	tables mace_ind*ab macehf_ind*ab death_ind*ab hf_ind*ab hf_death_ind;
run;


****Going to output table 1 for each analysis, after removing the affected individuals.;

**Not going to include these tables unless required by a reviewer.;

*Heart Failure;

data _anacohort_hf; set _anacohort; where hf_ind = 0; run;
proc sort data=_anacohort_hf; by bene_id indexdate; run;
%table1(inds = _anacohort_hf, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_heartfail bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
				bl_otherdiuretics
			bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
			/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
			bl_sulfonylurea bl_tzd
			bl_athero bl_obesity
			/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
			bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
			bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
			bl_outpatientvisit bl_oxygen bl_wheelchair, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_HF analysis_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





*MACE;


data _anacohort_mace; set _anacohort; where mace_ind = 0; run;
proc sort data=_anacohort_mace; by bene_id indexdate; run;
%table1(inds = _anacohort_mace, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_heartfail bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
				bl_otherdiuretics
			bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
			/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
			bl_sulfonylurea bl_tzd
			bl_athero bl_obesity
			/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
			bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
			bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
			bl_outpatientvisit bl_oxygen bl_wheelchair, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_MACE analysis_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;




*MACE + HF;


data _anacohort_macehf; set _anacohort; where macehf_ind = 0; run;
proc sort data=_anacohort_macehf; by bene_id indexdate; run;
%table1(inds = _anacohort_macehf, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_heartfail bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
				bl_otherdiuretics
			bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
			/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
			bl_sulfonylurea bl_tzd
			bl_athero bl_obesity
			/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
			bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
			bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
			bl_outpatientvisit bl_oxygen bl_wheelchair, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_MACE HF analysis_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;




/******************************************************************

				11 - INVESTIGATE GNN = 'MULTIPLE'

Some of the indexing claims have gnn = multiple. Here, we investigate
which medication class they are in.

*******************************************************************/

*Get the variable names to determine what would be helpful to look at;
proc contents data=ana.primary_cohort; run;

*Get a printout to understand what's happening;
proc print data=ana.primary_cohort;
	where gnn='Multiple';
	var bene_id ab gnn;
run;






