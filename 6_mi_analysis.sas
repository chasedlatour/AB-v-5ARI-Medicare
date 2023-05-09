/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 6_mi_analysis
	DESCRIPTION:Run analyses of the alpha-blockers vs. 5-alpha reductase inhibitors 
	analysis among patients with a history of in-patient hospitalization for MI. 

	CREATED BY: Chase Latour
	DATE CREATED: 2023 JAN 10

	DATE UPDATED

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

************************************************************************************************/





/************************************************************************************************
										00 - SET-UP
************************************************************************************************/
*Local submit to prompt sign on into server;
SIGNOFF;
%LET server=n2.schsr.unc.edu 1234;options comamid=tcp remote=server;signon username=_prompt_;

*Set up directories for project;
options source source2 msglevel=I mcompilenote=all mautosource mprint
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, 5_mi_analysis_cohort, saveLog=N);
*%setup(1pct, primary_analysis, saveLog=N);

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

This matches with what Sola did. However, it does not reflect the PS model specification.
The table that matches the weighted table is output later.

These are the descriptive statistics of the entire study population without any potential 
trimming. These won't be presented in the later results because it makes sense to compare
the unweighted and weighted versions of the same study population.

This is just included for data exploration of the total study population.
************************************************************************************************/

*Output table 1;

proc sort data=ana.mi_cohort out=cohort_mi; by bene_id indexdate; run;
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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_MI cohort_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





***
Decided that we wanted to look at the distributions of the medications over time.
***;

*Describe distribution of each med;
/*proc sort data=cohort_primary;*/
/*	by ab;*/
/*run;*/
/*proc freq data=cohort_primary;*/
/*	by ab;*/
/*	tables gnn;*/
/*run;*/

*Describe the distribution of meds by calendar year.;
/*data cohort_primary;*/
/*set cohort_primary;*/
/*	year_index = year(indexdate);*/
/*run;*/
/*proc sort data=cohort_primary; by ab; run;*/
/*proc freq data=cohort_primary ;*/
/*	*by ab;*/
/*	tables gnn * year_index / out=proportion_year outpct;*/
/*run;*/

*Look at a plot of the proportions;
/*ods graphics on / reset imagename="Treatment Proportions by Year";*/
/*proc sgplot data=proportion_year;*/
/*	title "Benign Prostatic Hyperplasia Treatment Percentages by Year";*/
/*	vbar year_index / response = pct_col stat = sum group=gnn nostatlabel;*/
/*	xaxis label="Year of Index Date";*/
/*	yaxis label = "Percentage of BPH Prescriptions the Year";*/
/*	keylegend / title="Generic Name of Index Drug";*/
/*	*keylegend / location=inside position = topleft;*/
/*run;*/
/**/







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
%ps_mi(inds = cohort_mi, outds = ps);



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
ods graphics on / reset imagename="PS Distributions - Density - MI Cohort";
proc sgplot data=ps;
	title "Density - PS Distributions by Treatment Group in the MI Cohort";
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
*Now, 2,712 individuals;


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
ods graphics on / reset imagename="PS Distributions - Density - Primary - Trimmed MI";
proc sgplot data=ps_trim;
	title "Density - PS Distributions by Treatment Group in the MI Cohort After Trimming";
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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_Trimmed MI Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use, among population with MI history";

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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics with IPTW_Trimmed MI Population_&logdate..rtf" style=vpmin startpage=never ;

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
/**/
/*data hospice;*/
/*set ana.primary_cohort;*/
/*	where fup_hospice_dt ne .;*/
/**/
/*	*Number of HF events after hospice;*/
/*	if fup_hospice_dt < HF_date then hospice_hf = 1;*/
/**/
/*	*Number of Mace events after hospice;*/
/*	if fup_hospice_dt < min(mi_date, stroke_date) then hospice_mace = 1;*/
/**/
/*	*Number of PCI events after hospice;*/
/*	if fup_hospice_dt < pcip_date then hospice_pcip = 1;*/
/**/
/*	*Number fo CABG events after hospice;*/
/*	if fup_hospice_dt < cabg_date then hospice_cabg = 1;*/
/**/
/*run;*/
/**/
/*proc freq data=hospice;	*/
/*	tables hospice_hf hospice_mace hospice_pcip hospice_cabg;*/
/*run;*/
/**/




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
/*data censoring;*/
/*set ana.primary_cohort;*/
/*	where death_dt = .;*/
/*	if endDT_itt  - fillDate2 < 366 then censor366 = 1; else censor366 = 0;*/
/*	if endDT_itt - fillDate2 < 1825 then censor1825 = 1; else censor1825 = 0;*/
/*run;*/
/**/
/**Look at the frequency breakdown by censoring events;*/
/*proc sort data=censoring; by ab; run;*/
/*proc means data=censoring mean;*/
/*	by ab;*/
/*	var censor366 censor1825;*/
/*run;*/
/**/
/**There's quite a bit of censoring here. Further, it's different by treatment, particularly by treatment;*/
/**/
/**/
/**Try to figure out what variables are associated with censoring;*/
/*proc freq data=censoring;*/
/*	where death_dt = .;*/
/*	tables censor366*(age cal_year rti_race*/
/*			bl_aur bl_chdz bl_heartfail */
/*			bl_hf_hosp bl_chronickid bl_copd bl_hchl*/
/*			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_athero bl_obesity);*/
/*run;*/
/**/
	



/**********************************************************************************
						08 - CALCULATE EFFECT ESTIMATES

The final study estimates will be calculated with boot-strapping. However,
it will be good to understand what the estimate is in the primary study population
prior to bootstrapping.

We want to calculate crude and adjusted estimates.
**********************************************************************************/


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
* Estimate without IPTW;
%competingrisk_single_weights(inds=ana.primary_cohort, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero 
				bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, trtvar=ab, 
      numiterations=1, initialseed=23244, outds=ana.HF_365_sample, noiptw=1);




**
1825
**;
*%competingrisk_weights(inds=primary_analysis, startDT=FillDate2, eventDT=HF_date, crDT=compEvent_dt, censorDT=endDT_itt, 
      daysEst=1825, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, trtvar=ab, 
      numiterations=1, initialseed=23244, outds=ana.HF_1825_primary);





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
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=p_samp, noiptw=0,
      numiterations=1);

*Without IPTW;

%risk_weights_multiple_sample(inds=ana.primary_cohort, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=p_samp, noiptw=1,
      numiterations=1);


***
1825
***;


**
(5) PCIP
**;



**
(6) CABG
**;







