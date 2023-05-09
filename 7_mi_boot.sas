/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: primary_analysis
	DESCRIPTION:Run primary analyses of the alpha-
	blockers vs. 5-alpha reductase inhibitors analysis.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10

	DATE UPDATED

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - FORMAT DATASET
	02 - OUTPUT TABLE 1
	03 - FIT PS MODEL
	04 - ASSESS FIT AND PLOT PS DISTRIBUTION
	05 - CALCULATE WEIGHTS
	06 - ASSESS BALANCE
	07 - RESTRICT ALPHA-BLOCKERS -- REMOVED
	08 - COMBINE PS DATA WITH OUTCOMES
	09 - CHECK CENSORING EVENTS
	10 - BOOTSTRAP EFFECT ESTIMATES
	11 - FOCUS ON POPULATION WITH MI HISTORY

************************************************************************************************/





/************************************************************************************************
										00 - SET-UP
************************************************************************************************/
*Local submit to prompt sign on into server;
SIGNOFF;
%LET server=n2.schsr.unc.edu 1234;options comamid=tcp remote=server;signon username=_prompt_;

*Set up directories for project;
options source source2 msglevel=I mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, primary_analysis, saveLog=N);
*%setup(1pct, primary_analysis, saveLog=N);

*Map local mirrors for all remote libraries using LOCAL submit;
libname lout slibref=out server=server;
libname lwork slibref=work server=server;
libname lraw slibref=raw server=server;
libname lder slibref=der server=server;



/************************************************************************************************
									01 - FORMAT DATASET
************************************************************************************************/

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


****
Count people at each stage of the data pull.
Apply exclusion criteria.
****;

* Count the number of episodes;
proc sql;
	select count(bene_id) as count_bene_id
	from out.covariates;
	quit;
	*# of episodes of new-use = 714,338;

*Limit the cohort to people without sufficient continuous enrollment & people without new use 
of the study medications - DONE ALREADY;

*Limit the dataset to the correct age at index.;
proc sql;
	create table cohort_restrict as
	select *
	from out.covariates
	where 66 le age le 90
	;
	quit;
	*Number of new-use periods = 691,092;



*Count the unique number of people 66-90 with a new-use episode;
proc sql;
	select count (distinct bene_id) as num_people,
			count (bene_id) as num_episodes
	from cohort_restrict;
	quit;
	*515,956 people; 
	*691,092 episodes;


*Limit the new-use episodes to those with a BPH diagnosis code at least 12 months prior;
proc sql;
	create table cohort_restrict1 as
	select *
	from cohort_restrict
	where exclude_1yrlb_BPHWOUS ge 1 or exclude_1yrlb_BPHWUS ge 1
	;
	quit;


*Count the unique number of people and episodes in cohort_restrict 1;
proc sql;
	select count (distinct bene_id) as num_people,
		   count (bene_id) as num_episodes
	from cohort_restrict1;
	quit;
	*354,366 people; 
	*466,931 episodes;


*Limit the cohort to those without:
	(1) history of hospice care in the last 12 months
	(2) history of prostate cancer or prostatectomy with all-availalbe lookback
	(3) history of chemotherapy in the last 6 months prior to treatment;
proc sql;
	create table cohort_restrict2 as
	select *
	from cohort_restrict1
	where bl_hospice = 0 and exclude_6moslb_chemotherapy = 0 and exclude_aalb_prostatecancer = 0 and exclude_aalb_prostatectomy = 0
	;
	quit;



*Count the unique number of people and episodes in cohort_restrict2;
proc sql;
	select count (distinct bene_id) as num_people,
		   count (bene_id) as num_episodes
	from cohort_restrict2;
	quit;
	*323,517 people; 
	*421,809 episodes;



*Limit the dataset to those that don't meet entry criteria for new-use based upon second fill;
proc sql;
	create table cohort_restrict3 as
	select *
	from cohort_restrict2
	where excludeFlag_sameDayInitiator = 0 & excludeflag_prevalentuser = 0 & excludeflag_prefill2initiator = 0 & filldate2 ~= .;
	quit;
	*Number of new-uses: 162,745;


*Count the unique number of people and episodes in cohort_restrict3;
proc sql;
	select count (distinct bene_id) as num_people,
		   count (bene_id) as num_episodes
	from cohort_restrict3;
	quit;
	*152,801 people; 
	*158,204 episodes;





*Create dataset where don't have more than one episode per person - take the earliest new-use episode;
proc sql;
	create table cohort_restrict4 as
	select *
	from cohort_restrict3
	group by bene_id having indexdate=min(indexdate);
	quit;



*Count the unique number of people and episodes in cohort_restrict4;
proc sql;
	select count (distinct bene_id) as num_people,
		   count (bene_id) as num_episodes
	from cohort_restrict4;
	quit;
	*152,801 people; 
	*152,801 episodes;


*Matches with the Tables exclusion numbers;







*Specify the values for each of the variables
	This is necessary to do for the table 1;
data cohort_primary;
set cohort_restrict4;

	*Create calendar year variable;
	cal_year = year(IndexDate);

	*Acute urinary retention - y/n;
	if bl_1yrlb_aur = 0 then bl_aur= 0;
		else if bl_1yrlb_aur GE 1 then bl_aur = 1;

	*Coronary heart disease - y/n;
	if bl_1yrlb_chdz = 0 then bl_chdz = 0;
		else if bl_1yrlb_chdz GE 1 then bl_chdz = 1;

	*Heart failure - y/n;
	if bl_1yrlb_hf = 0  then bl_heartfail = 0;
		else if bl_1yrlb_hf GE 1 then bl_heartfail = 1;

	*Need to ask what this is - y/n;
	bl_hf_sub = bl_1yrlb_hf-bl_1yrlb_hf_inpt;

	*Need to ask - y/n;
	if bl_hf_sub = 0 THEN bl_hf_op = 0;
		else if bl_hf_sub GE 1 then bl_hf_op = 1; 

	*Baseline inpatient heart failure - y/n;
	if bl_1yrlb_hf_inpt = 0 THEN bl_hf_hosp = 0;
		else if bl_1yrlb_hf_inpt GE 1 then bl_hf_hosp =1;

	*Chronic kidney disease - y/n;
	if bl_1yrlb_ckd = 0 then bl_chronickid = 0;
		else if bl_1yrlb_ckd GE 1 then bl_chronickid = 1;

	*COPD - y/n;
	if bl_1yrlb_copd = 0 then bl_copd = 0;
		else if bl_1yrlb_copd GE 1 then bl_copd = 1;

	*High cholesterol - y/n;
	if bl_1yrlb_hchl = 0 then bl_hchl = 0;
		else if bl_1yrlb_hchl GE 1 then bl_hchl = 1;

	*Myocardial infarction - y/n;
	if bl_1yrlb_mi_inpt = 0 then bl_mi = 0;
		else if bl_1yrlb_mi_inpt GE 1 then bl_mi = 1;

	*In-patient stroke - y/n;
	if bl_1yrlb_stroke_inpt = 0 then bl_strk = 0;
		else if bl_1yrlb_stroke_inpt GE 1 then bl_strk = 1;

	*PCI Procedure - y/n;
	if bl_1yrlb_pcip = 0 then bl_pcip = 0;
		else if bl_1yrlb_pcip = 1 then bl_pcip = 1;

	*In-patient CABG - y/n;
	if bl_1yrlb_cabg_inpt = 0 then bl_cabg = 0;
		else if bl_1yrlb_cabg_inpt = 1 then bl_cabg = 1;

	*Tobacco use - y/n;
	if bl_1yrlb_tobacco= 0 then bl_tobacco = 0;
		else if bl_1yrlb_tobacco GE 1 then bl_tobacco = 1;

	*ACE inhibitors - y/n;
	if bl_1yrlb_acei = 0 then bl_acei = 0;
		else if bl_1yrlb_acei GE 1 then bl_acei = 1;

	*ARBs - y/n;
	if bl_1yrlb_arb = 0 then bl_arb = 0;
		else if bl_1yrlb_arb GE 1 then bl_arb = 1;

	*Rivaroxaban - y/n;
	if bl_1yrlb_rivaroxaban = 0 then bl_rivaroxaban = 0;
		else if bl_1yrlb_rivaroxaban GE 1 then bl_rivaroxaban = 1;

	*Heparin - y/n;
	if bl_1yrlb_heparin = 0 then bl_heparin = 0;
		else if bl_1yrlb_heparin GE 1 then bl_heparin = 1;

	*Opioids - y/n;
	if bl_1yrlb_opioids = 0 then bl_opioids = 0;
		else if bl_1yrlb_opioids GE 1 then bl_opioids = 1;

	*Beta-Blockers - y/n;
	if bl_1yrlb_BB = 0 then bl_bb = 0;
		else if bl_1yrlb_BB GE 1 then bl_bb= 1;

	*Peripheral vasodilators - y/n	;
	if bl_1yrlb_peripheralvaso = 0 then bl_peripheralvaso = 0;
		else if bl_1yrlb_peripheralvaso GE 1 then bl_peripheralvaso = 1;

	*Biguanide - y/n;
	if bl_1yrlb_biguanide = 0 then bl_biguanide = 0;
		else if bl_1yrlb_biguanide GE 1 then bl_biguanide = 1;

	*Calcium channel blocker  - y/n;
	if bl_1yrlb_ccb = 0 then bl_ccb = 0;
		else if bl_1yrlb_ccb GE 1 then bl_ccb = 1;

	*DPP-i - y/n;
	if bl_1yrlb_dpp = 0 then bl_dpp = 0;
		else if bl_1yrlb_dpp GE 1 then bl_dpp = 1;

	*GLPs - y/n;
	if bl_1yrlb_glp = 0 then bl_glp = 0;
		else if bl_1yrlb_glp GE 1 then bl_glp = 1;

	*Combodiuretics - y/n;
	if bl_1yrlb_combodiuretics = 0 then bl_combodiuretics = 0;
		else if bl_1yrlb_combodiuretics GE 1 then bl_combodiuretics = 1;

	*Potassium-sparing diuretic - y/n;
	if bl_1yrlb_ksparingdiuretic = 0 then bl_ksparingdiuretic = 0;
		else if bl_1yrlb_ksparingdiuretic GE 1 then bl_ksparingdiuretic = 1;

	*Long-acting insulin - y/n;
	if bl_1yrlb_lainsulin = 0 then bl_lainsulin= 0;
		else if bl_1yrlb_lainsulin GE 1 then bl_lainsulin = 1;

	*Loop diuretic - y/n	;
	if bl_1yrlb_loop = 0 then bl_loop = 0;
		else if bl_1yrlb_loop GE 1 then bl_loop = 1;

	*Short-acting insulin - y/n;
	if bl_1yrlb_sainsulin = 0 then bl_sainsulin = 0;
		else if bl_1yrlb_sainsulin GE 1 then bl_sainsulin = 1;

	*Aspirin;
	if bl_1yrlb_aspirin = 0 then bl_aspirin = 0;
		else if bl_1yrlb_aspirin GE 1 then bl_aspirin = 1;

	*SGLT inhibitor - y/n;
	if bl_1yrlb_sglt= 0 then bl_sglt= 0;
		else if bl_1yrlb_sglt GE 1 then bl_sglt = 1;

	*Thiazide diuretic - y/n;
	if bl_1yrlb_thiazide = 0 then bl_thiazide = 0;
		else if bl_1yrlb_thiazide GE 1 then bl_thiazide= 1;

	*Sulfonylurea - y/n;
	if bl_1yrlb_sulfonylurea = 0 then bl_sulfonylurea = 0;
		else if bl_1yrlb_sulfonylurea GE 1 then bl_sulfonylurea = 1;

	*Other diuretics - y/n;
	if bl_1yrlb_otherdiuretics = 0 then bl_otherdiuretics = 0;
		else if bl_1yrlb_otherdiuretics GE 1 then bl_otherdiuretics = 1;

	*Thiazolidinedione - y/n;
	if bl_1yrlb_THIAZOLIDINEDIONE = 0 then bl_tzd = 0;
		else if bl_1yrlb_THIAZOLIDINEDIONE GE 1 then bl_tzd = 1;

	*Warfarin - y/n;
	if bl_1yrlb_warfarin = 0 then bl_warfarin = 0;
		else if bl_1yrlb_warfarin GE 1 then bl_warfarin = 1;

	*Nicotine treatment - y/n;
	if bl_1yrlb_nicotine_varen = 0 then bl_nicotine_varen = 0;
		else if bl_1yrlb_nicotine_varen GE 1 then bl_nicotine_varen = 1;

	*Statins - y/n;
	if bl_1yrlb_statins = 0 then bl_statins = 0;
		else if bl_1yrlb_statins GE 1 then bl_statins = 1;

	*Dabigatran - y/n;
	if bl_1yrlb_dabigatran = 0 then bl_dabi = 0;
		else if bl_1yrlb_dabigatran GE 1 then bl_dabi = 1;

	*Apixaban - y/n;
	if bl_1yrlb_apixaban = 0 then bl_apix = 0;
		else if bl_1yrlb_apixaban GE 1 then bl_apix = 1;

	*Edoxaban - y/n	;
	if bl_1yrlb_edoxaban = 0 then bl_edox = 0;
		else if bl_1yrlb_edoxaban GE 1 then bl_edox= 1;

	*Diabetes diagnosis - y/n;
	if bl_1yrlb_diabetes = 0 or bl_1yrlb_diabetes=1 then bl_diab = 0;
		else if bl_1yrlb_diabetes >=2 then bl_diab = 1;

	*Atherosclerosis diagnosis - y/n;
	if bl_1yrlb_atherosclerosis = 0 or bl_1yrlb_atherosclerosis = 1 Then bl_athero = 0;
		else if bl_1yrlb_atherosclerosis >=2 then bl_athero = 1;

	*Multiple categories of long-acting insulin;
	if bl_1yrlb_lainsulin = 0 then bl_lainsulin_cat = 0;
		else if bl_1yrlb_lainsulin = 1 then bl_lainsulin_cat = 1;
		else if bl_1yrlb_lainsulin GE 2 then bl_lainsulin_cat = 2; 

	*Multiple categories of short-acting insulin;
	if bl_1yrlb_sainsulin = 0 then bl_sainsulin_cat = 0;
		else if bl_1yrlb_sainsulin = 1 then bl_sainsulin_cat = 1;
		else if bl_1yrlb_sainsulin GE 2 then bl_sainsulin_cat = 2; 

	*Multiple categories of opioid usage;
	if bl_1yrlb_opioids = 0 then bl_opioidcat = 0;
		else if bl_1yrlb_opioids = 1 then bl_opioidcat = 1;
		else if bl_1yrlb_opioids GE 2 then bl_opioidcat = 2; 

	*Multiple categories of warfarin usage;
	if bl_1yrlb_warfarin = 0 THEN bl_warfarincat = 0;
		else if bl_1yrlb_warfarin = 1 then bl_warfarincat = 1;
		else if bl_1yrlb_warfarin GE 2 then bl_warfarincat = 2;

	*Multiple categories of heparin usage;
	if bl_1yrlb_heparin = 0 THEN bl_heparincat = 0;
		else if bl_1yrlb_heparin = 1 then bl_heparincat = 1;
		else if bl_1yrlb_heparin  GE 2 then bl_heparincat = 2;

	*Multiple categories of rivaroxaban;
	if bl_1yrlb_rivaroxaban = 0 THEN bl_rivaroxabancat = 0;
		else if bl_1yrlb_rivaroxaban = 1 then bl_rivaroxabancat = 1;
		else if bl_1yrlb_rivaroxaban GE 2 then bl_rivaroxabancat = 2;

	*Multiple categories of dabigatran;
	if bl_1yrlb_dabigatran = 0 then bl_dabigatrancat = 0;
		else if bl_1yrlb_dabigatran = 1 then bl_dabigatrancat = 1;
		else if bl_1yrlb_dabigatran GE 2 then bl_dabigatrancat = 2;

	*Multiple categories of apixaban;
	if bl_1yrlb_apixaban = 0 THEN bl_apixabancat = 0;
		else if bl_1yrlb_apixaban = 1 then bl_apixabancat = 1;
		else if bl_1yrlb_apixaban GE 2 then bl_apixabancat = 2;

	*Multiple categories of edoxaban;
	if bl_1yrlb_edoxaban = 0 THEN bl_edoxabancat = 0;
		else if bl_1yrlb_edoxaban = 1 then bl_edoxabancat = 1;
		else if bl_1yrlb_edoxaban  GE 2 then bl_edoxabancat = 2;

	*Binary obesity variable - y/n;
	if bl_1yrlb_obesity = 0 then bl_obesity = 0;
		else if bl_1yrlb_obesity GE 1 then bl_obesity = 1;

	*Create any anticoagulant variable - y/n;
	if (bl_warfarincat = 0  & bl_heparincat= 0 & bl_rivaroxabancat = 0 & bl_dabigatrancat= 0 & bl_apixabancat = 0 & bl_edoxabancat = 0)  
			THEN bl_anycoag = 0;
		ELSE if (bl_warfarincat > 0 | bl_heparincat > 0 | bl_rivaroxabancat > 0 | bl_dabigatrancat > 0 | bl_apixabancat > 0 |bl_edoxabancat > 0 ) 
			THEN bl_anycoag = 1;
 

	*Create multiple categories for anticoagulant variable;
	IF  (bl_warfarincat = 0 & bl_heparincat= 0 & bl_rivaroxabancat = 0 & bl_dabigatrancat= 0 & bl_apixabancat = 0 & bl_edoxabancat = 0 )
			THEN bl_anycoagcat =0;
		ELSE IF (bl_warfarincat = 1  | bl_heparincat= 1 | bl_rivaroxabancat = 1 | bl_dabigatrancat= 1 | bl_apixabancat = 1 | bl_edoxabancat = 1) 
			THEN bl_anycoagcat = 1;
		ELSE IF (bl_warfarincat GE 2  | bl_heparincat GE 2 | bl_rivaroxabancat GE 2 | bl_dabigatrancat GE 2 | bl_apixabancat GE 2 | bl_edoxabancat GE 2) 
			THEN bl_anycoagcat = 2;

	*Create multiple categories of antihypertensive variable;
	IF bl_1yrlb_acei = 0 & bl_1yrlb_arb = 0& bl_1yrlb_bb = 0 & bl_1yrlb_ccb = 0 & bl_1yrlb_thiazide = 0 & bl_1yrlb_peripheralvaso = 0 
			THEN bl_hypercat = 0;
		ELSE IF bl_1yrlb_acei = 1 or bl_1yrlb_arb = 1 or bl_1yrlb_bb = 1 or bl_1yrlb_ccb = 1 or bl_1yrlb_thiazide = 1 or bl_1yrlb_peripheralvaso = 1 
			THEN bl_hypercat = 1;
		ELSE IF bl_1yrlb_acei GE 2 & (bl_1yrlb_arb = 0 & bl_1yrlb_bb = 0 & bl_1yrlb_ccb = 0 & bl_1yrlb_thiazide = 0 & bl_1yrlb_peripheralvaso = 0) 
			THEN bl_hypercat = 2;
		ELSE IF bl_1yrlb_arb GE 2 & (bl_1yrlb_acei = 0 & bl_1yrlb_bb = 0 & bl_1yrlb_ccb = 0 & bl_1yrlb_thiazide = 0 & bl_1yrlb_peripheralvaso = 0) 
			THEN bl_hypercat = 2;
		ELSE IF bl_1yrlb_bb GE 2 & (bl_1yrlb_arb = 0 & bl_1yrlb_acei = 0 & bl_1yrlb_ccb = 0 & bl_1yrlb_thiazide = 0 & bl_1yrlb_peripheralvaso = 0) 
			THEN bl_hypercat = 2;
		ELSE IF bl_1yrlb_ccb GE 2 & (bl_1yrlb_arb = 0 & bl_1yrlb_bb = 0 & bl_1yrlb_acei = 0 & bl_1yrlb_thiazide = 0 & bl_1yrlb_peripheralvaso = 0) 
			THEN bl_hypercat = 2;
		ELSE IF bl_1yrlb_thiazide GE 2 & (bl_1yrlb_arb = 0 & bl_1yrlb_bb = 0 & bl_1yrlb_ccb = 0 & bl_1yrlb_acei = 0 & bl_1yrlb_peripheralvaso = 0) 
			THEN bl_hypercat = 2;
		ELSE IF bl_1yrlb_peripheralvaso GE 2 & (bl_1yrlb_arb = 0 & bl_1yrlb_bb = 0 & bl_1yrlb_ccb = 0 & bl_1yrlb_thiazide = 0 & bl_1yrlb_acei = 0)
			THEN bl_hypercat = 2;
		ELSE IF (bl_1yrlb_acei GE 2 & bl_1yrlb_arb GE 2) or (bl_1yrlb_acei GE 2 & bl_1yrlb_ccb GE 2) or (bl_1yrlb_acei GE 2 & bl_1yrlb_bb GE 2) or
				(bl_1yrlb_acei GE 2 & bl_1yrlb_thiazide GE 2) or (bl_1yrlb_acei GE 2 & bl_1yrlb_peripheralvaso) or (bl_1yrlb_arb GE 2 & bl_1yrlb_bb GE 2) or
				(bl_1yrlb_arb GE 2 & bl_1yrlb_thiazide GE 2) or (bl_1yrlb_arb GE 2 & bl_1yrlb_ccb GE 2) or (bl_1yrlb_arb GE 2 & bl_1yrlb_peripheralvaso GE 2) or 
				(bl_1yrlb_ccb GE 2 & bl_1yrlb_bb GE 2) or (bl_1yrlb_ccb GE 2 & bl_1yrlb_thiazide GE 2) or (bl_1yrlb_ccb GE 2 & bl_1yrlb_peripheralvaso GE 2) or 
				(bl_1yrlb_bb GE 2 & bl_1yrlb_thiazide GE 2) or (bl_1yrlb_bb GE 2 & bl_1yrlb_peripheralvaso GE 2) or (bl_1yrlb_thiazide GE 2 & bl_peripheralvaso GE 2) or 
 				(bl_1yrlb_thiazide GE 2 & bl_1yrlb_peripheralvaso GE 2 & bl_1yrlb_acei = 0 & bl_1yrlb_arb = 0& bl_1yrlb_bb = 0 & bl_1yrlb_ccb = 0) 
			THEN bl_hypercat = 3;


	*Apply these formats if you would like to run the Table 1 files.;

	*Add formats and labels from 'tables' file;
	format bl_PERIPHERALVASO bl_CHDZ bl_heartfail bl_hf_op bl_hf_hosp bl_chronickid bl_COPD bl_HCHL  bl_MI bl_STRK
			bl_PCIP bl_CABG bl_ACEI bl_ARB bl_BB bl_BIGUANIDE bl_CCB bl_DPP bl_GLP
			bl_KSPARINGDIURETIC bl_OTHERDIURETICS bl_LAINSULIN bl_LOOP bl_SAINSULIN bl_SGLT  bl_SULFONYLUREA  bl_THIAZIDE  bl_obesity bl_TOBACCO bl_OPIOIDS
		 	bl_tzd bl_STATINS  bl_ASPIRIN bl_APIX bl_dabi  bl_WARFARIN bl_EDOX bl_HEPARIN bl_RIVAROXABAN bl_NICOTINE_VAREN bl_anycoag  bl_athero bl_diab yn.
			race_cd $race. race $raceCat. 	ab ab. bl_anycoagcat bl_lainsulin_cat bl_sainsulin_cat bl_opioidcat bl_warfarincat bl_heparincat bl_rivaroxabancat 
			bl_dabigatrancat bl_apixabancat bl_edoxabancat drugcat. bl_hypercat hypercat. ;

	label race_cd = 'Race' race = 'Race' age='Age' sex='Sex' 
	        bl_Aur = "Acute Urinary Retention" bl_athero='Atherosclerosis or Peripheral Vascular Disease' bl_CHDZ ='CHD' bl_heartfail='Any Heart Failure Diagnosis' bl_hf_op = 'Outpatient Heart Failure Diagnosis' bl_hf_hosp = 'Hospitalization due to Heart Failure' bl_chronickid='Chronic Kidney Disease' bl_COPD= 'COPD'
	        bl_diab='Diabetes' bl_HCHL='Hypercholesterolemia' bl_MI='Hospitalization due to MI' bl_strk='Hospitalization due to Stroke'  
			bl_1yrlb_ANGIOPLASTY = "Angioplasty" bl_1yrlb_REVASCULARIZATION = 'Revascularization' bl_pcip = "PCIP" bl_cabg = "CABG" bl_OBESITY = "Obesity" bl_TOBACCO = "Tobacco Use"
			bl_ACEI = "Ace Inhibitor" bl_ARB = "ARB" bl_BB = "Beta Blocker" bl_PERIPHERALVASO = "Peripheral Vasodilators" bl_BIGUANIDE = "Biguanide" bl_CCB = "Calcium Chanel Blocker"
			bl_DPP = "DPP-4i" bl_GLP = "GLP-1" bl_COMBODIURETICS = "Combination Diuretics" bl_OTHERDIURETICS = "Other Diuretics" bl_KSPARINGDIURETIC = "Potassium Sparing Diuretic" bl_LAINSULIN = "Long Acting Insulin"
			bl_LOOP = "Loop Diuretics" bl_SAINSULIN = "Short Acting Insulin" bl_SGLT = "SGLT" bl_SULFONYLUREA = "Sulfonylureas" bl_THIAZIDE = "Thiazide Diuretics"
			bl_tzd = "TZD" bl_STATINS = "Statin" bl_ASPIRIN = "Aspirin" bl_DABI ="Dabigatran" bl_APIX = "Apixaban" bl_EDOX = "Edoxaban" Bl_RIVAROXABAN = "Rivaroxaban"
			bl_HEPARIN = "Heparin" bl_WARFARIN = "Warfarin" bl_NICOTINE_VAREN = "Nicotine or Varenicline" bl_OPIOIDS = "Opioids" bl_lainsulin_cat = "Long Acting Insulin Category" bl_sainsulin_cat = "Short Acting Insulin Category"
			bl_opioidcat = "Opioid Category" bl_warfarincat = "Warfarin Category" bl_heparincat = "Heparin Category" bl_rivaroxabancat = "Rivaroxaban Category" bl_dabigatrancat = "Dabigatran Category" bl_Apixabancat =  "Apixaban Category"
			bl_edoxabancat = "Edoxaban Category" bl_anycoag = "Any Anticoagulant Use" bl_anycoagcat = "Any Anticoagulant Use Category" bl_hypercat = "Antihypertensive Category" predictedfrailty = "Predicted Frailty" ;


run;



/************************************************************************************************
										02 - OUTPUT TABLE 1

This matches with what Sola did. However, it does not reflect the PS model specification.
The table that matches the weighted table is output later.
************************************************************************************************/

*Output table 1;

proc sort data=cohort_primary; by bene_id indexdate; run;
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
Decided that we wanted to look at the distributions of the medications over time.
***;

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
proc sort data=cohort_primary; by ab; run;
proc freq data=cohort_primary noprint;
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
	keylegend / title="Generic Name";
	*keylegend / location=inside position = topleft;
run;





/************************************************************************************************
										03 - FIT PS MODEL
************************************************************************************************/


*Look at the probability of treatment by age;
proc freq data=cohort_primary;
	tables age * ab;
run;
*Not much of a relationship, slightly linear;

*Build the propensity score model;

%MACRO ps(inds =, outds =);

	proc logistic data=&inds;
		class cal_year bl_aur bl_chdz bl_heartfail bl_hf_hosp bl_chronickid bl_copd bl_hchl
				bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
				
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
				/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
				bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race
				/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
				bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
				bl_outpatientvisit bl_oxygen bl_wheelchair;
		model ab (reference = /*'0'*/ 'AR5') = age cal_year bl_aur bl_tobacco 
				/*make flexible around heart conditions*/ 
				bl_chdz bl_hf bl_hf_hosp bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_diab 
				bl_chdz*bl_hf*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero

				/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
					bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
					bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins 
				/*antidiabetics*/ 
				bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				 bl_obesity rti_race
				/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
				bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
				bl_outpatientvisit bl_oxygen bl_wheelchair;
		output out=&outds p=PS;
	run;

%MEND;

%ps(inds = cohort_primary, outds = ps);

/************************************************************************************************
							04 - ASSESS FIT AND PLOT PS DISTRIBUTION
************************************************************************************************/


*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Hist - Primary";
proc sgplot data=ps;
	title "Histogram - PS Distributions by Treatment Group in the Primary Cohort";
	histogram ps / group = ab transparency=0.7;
	*density ps / type = kernel;
	keylegend / location=inside position = topleft;
run;

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
	by ab;
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
	if ab = 0 & ps < minPS then delete=1;
	if ab = 1 & ps > maxPS then delete=1;
run;
*Now, 152792 individuals;


***
Need to re-fit the PS model in that population.
***;


*Re-fit PS model;
%ps(inds = ps3, outds = ps_trim);

/*proc means data=ps_trim min max;*/
/*	class ab;*/
/*	var ps;*/
/*run;*/

*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Hist - Primary - Trimmed";
proc sgplot data=ps_trim;
	title "Histogram - PS Distributions by Treatment Group in the Primary Cohort After Trimming";
	histogram ps / group = ab transparency=0.7;
	*density ps / type = kernel;
	keylegend / location=inside position = topleft;
run;

*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Density - Primary - Trimmed";
proc sgplot data=ps_trim;
	title "Density - PS Distributions by Treatment Group in the Primary Cohort After Trimming";
	*histogram ps / group = ab;
	density ps / group = ab type = kernel;
	keylegend / location=inside position = topleft;
run;






/************************************************************************************************
									05 - CALCULATE WEIGHTS
************************************************************************************************/

%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2);

*Calculate mean, max, and min of weights;
proc means data=cohort_weights2 max min mean;
	class ab;
	var iptw;
run;


/************************************************************************************************
									06 - ASSESS BALANCE
************************************************************************************************/


**
Create new tables in trimmed population
**;

*Unweighted;
proc sort data=ps_trim; by bene_id indexdate; run;
%table1(inds = ps_trim, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_Trimmed Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





*Output the IPTW Table 1:

Can use table1 macro for weighted comparison;
proc sort data=cohort_weights2; by bene_id indexdate; run;
%table1(inds = cohort_weights2, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
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
			bl_outpatientvisit bl_oxygen bl_wheelchair, wgtVar = iptw, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics with IPTW_Trimmed Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





/************************************************************************************************
									07 - RESTRICT ALPHA-BLOCKERS

Decided not to actually do this analysis.
************************************************************************************************/

*Remove individuals treated with terazosin or doxazosin;
data cohort_primary2;
set cohort_primary;
	where gnn ~= "TERAZOSIN" and gnn ~= "DOXAZOSIN";
run;
proc sort data=cohort_primary2; by ab; run;
proc freq data=cohort_primary2;
	by ab;
	tables gnn;
run;

%ps(inds = cohort_primary2, outds = ps_restrict);



*Output an unweighted Table 1 that matches the variables in the weighted table:

Now, excluding alpha-blockers with 2 indications

Can use table1 macro for unweighted comparison;
proc sort data=cohort_primary2; by bene_id indexdate; run;
%table1(inds = cohort_primary2, maxLevels = 5, colVar = age cal_year rti_race
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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics w Restricted Alpha-Blockers_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;








/**********************************************************************************
						08 - COMBINE PS DATA WITH OUTCOMES
**********************************************************************************/


*Left-join the Outcomes dataset on the trimmed, primary cohort
join death and censoring dates from the cohortds file;

*Changed this to pull directly from the original cohort because we want to apply
trimming, PS modeling, weights etc. in the bootstrapping process. They should 
be re-fit each time the bootstrap sample is run.;

proc sql;
	create table primary_analysis as 
	select a.*, b.*
	from /*cohort_weights2*/ cohort_primary as a
	left join out.outcomes /*ana.outcomes_correct*/ as b
	on a.bene_id = b.bene_id and a.indexdate = b.indexdate
	;
	quit;



***
Look at the number of people that have events after entering hospice
***;

data hospice;
set primary_analysis;
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
							09 - CHECK CENSORING EVENTS

Here, we have defined censoring as disenrollment from Medicare Parts A & B.
********************************************************************************/


***
Assess censoring in the cohort;
***;
data censoring;
set primary_analysis;
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
						10 - BOOTSTRAP EFFECT ESTIMATES
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







options mprint;




**
(1) hosp for HF
**;

***
365
***;
* Run on the sample;
*%competingrisk_single_weights(inds=primary_analysis, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=1, initialseed=23244, outds=ana.HF_365_sample);


***
Run with bootstrap;

*365 - Crude;
%competingrisk_weights_crude(inds=primary_analysis, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=500, initialseed=23244, outds=ana.HF_365_primary_crude);

*365 - Weighted;
*%competingrisk_weights(inds=primary_analysis, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=200, initialseed=23244, outds=ana.HF_365_primary);





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
No Bootstrapping
***;
*%risk_weights_multiple_sample(inds=primary_analysis, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=1);

***
365
***;

*Without IPTW ( Crude);
%risk_weights_multiple_crude(inds=primary_analysis, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=1);


*With IPTW;
*%risk_weights_multiple(inds=primary_analysis, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=200);


***
1825
***;
*%risk_weights_boot(inds=primary_analysis, startDT=FillDate2, eventDT=(mi_date, stroke_date, death_dt), censorDT=endDT_itt, 
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
      numiterations=1, initialseed=23244, outds=ana.mace_1825_primary);





**
(5) PCIP
**;
*Bootstrap for CI;
%competingrisk_mod_boot(inds = primary_analysis, startDT=FillDate2, eventDT=pcip_date, crDT = compEvent_dt,
					censorDt=censorDate_itt, daysEst=365 1825, numiterations=200, trtvar=ab, outds=ana.comprisk_PCIP_boot);



**
(6) CABG
**;
*Bootstrap for CI;
%competingrisk_mod_boot(inds = primary_analysis, startDT=FillDate2, eventDT=cabg_date, crDT = compEvent_dt,
					censorDt=censorDate_itt, daysEst=365 1825, numiterations=200, trtvar=ab, outds=ana.comprisk_CABG_boot);



**
Combine the estimates into one dataset
**;
proc sql;
	create table ana.primary_365_estimates as
/*	select * from ana.hf_365_primary_summary*/
/*	union*/
	select * from ana.mace_365_primary_summary
	union
	select * from ana.macehf_365_primary_summary
	union
	select * from ana.death_365_primary_summary
	;
	quit



/**********************************************************************************
						11 - SUMMARIZE BOOTSTRAPPED ESTS
**********************************************************************************/

*Macro to re-name the variables

The risk and competing risk macros output the variables with different names; 
%macro rename_risk(inds=, fup=);

	data rename_&inds;
	set ana.&inds (drop = ab
		rename = (r0=e0_rate&fup r=e1_rate&fup lnrr=lnriskRatio&fup rr=riskRatio&fup rd=riskDiff&fup));
	run;
		
%mend;


*(1) HF;

*Combine the estimates from multiple bootstraps;
proc sql;
	create table ana.hf_365_primary as
	select e0_rate365, e1_rate365, riskDiff365, riskRatio365, lnriskRatio365, samplingseed
	from ana.hf_365_primary_first200
	union
	select * from ana.hf_365_primary_last300
	order by samplingseed
	;
	quit;

*Calculate the study estimates;
%calculate_est(inds=ana.hf_365_primary, outds=hf_365_primary_summary, fup=365, rd_multiple=10000);
data ana.hf_365_primary_summary; set ana.hf_365_primary_summary; 
	variable = "Heart Failure Outcome"; run;




*(2) MACE;

*Combine the estimates from multiple bootstraps;
proc sql;
	create table mace_365_primary as
	select * from ana.mace_365_primary_first200 
	union
	select * from ana.mace_365_primary
	;
	quit;
proc sort data=mace_365_primary; by samplingseed; run;
data ana.mace_365_primary; set mace_365_primary; run;

*Rename the variables;
%rename_risk(inds=mace_365_primary, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_mace_365_primary, outds=mace_365_primary_summary, fup=365, rd_multiple=1000);
data ana.mace_365_primary_summary; set ana.mace_365_primary_summary; 
	variable = "MACE Outcome"; run;

*(3) MACE + HF;

*Combine the estimates from multiple bootstraps;
proc sql;
	create table macehf_365_primary as
	select * from ana.macehf_365_primary_first200 
	union
	select * from ana.macehf_365_primary
	;
	quit;
proc sort data=macehf_365_primary; by samplingseed; run;
data ana.macehf_365_primary; set macehf_365_primary; run;

*Rename the variables;
%rename_risk(inds=macehf_365_primary, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_macehf_365_primary, outds=macehf_365_primary_summary, fup=365, rd_multiple=1000);
data ana.macehf_365_primary_summary; set ana.macehf_365_primary_summary; 
	variable = "MACE and HF Outcome"; run;

*(4) DEATH;

proc sql;
	create table death_365_primary as
	select * from ana.death_365_primary_first200 
	union
	select * from ana.death_365_primary
	;
	quit;
proc sort data=death_365_primary; by samplingseed; run;
*Look at data before running;
data ana.death_365_primary; set death_365_primary; run;

*Rename the variables;
%rename_risk(inds=death_365_primary, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_death_365_primary, outds=death_365_primary_summary, fup=365, rd_multiple=1000);
data ana.death_365_primary_summary; set ana.death_365_primary_summary; 
	variable = "Death Outcome"; run;

*(5) CABG;

*(6) PCIP;






**
Combine the estimates into one dataset
**;
proc sql;
	create table primary_365_estimates as
	select * from ana.hf_365_primary_summary
	union
	select * from ana.mace_365_primary_summary
	union
	select * from ana.macehf_365_primary_summary
	union
	select * from ana.death_365_primary_summary
	;
	quit; 

data ana.primary_365_estimates (keep = risk0 risk0_CI risk1 risk1_CI
				rd rd_CI rr rr_ci rd_multiple variable);
set primary_365_estimates;
	risk0 = round(risk0_365, 0.01);
	risk0_CI = cats(round(risk0_365_LCL, 0.01), ", ", round(risk0_365_UCL,0.01));
	risk1 = round(risk1_365, 0.01);
	risk1_CI = cats(round(risk1_365_LCL, 0.01), ", ", round(risk1_365_UCL,0.01));
	rd = round(rd365, 0.01);
	rd_CI = cats(round(rd365_LCL,0.01), ", ", round(rd365_UCL, 0.01));
	rr = round(rr365, 0.01);
	rr_CI = cats(round(rr365_LCL,0.01), ", ", round(rr365_UCL, 0.01));
run;










/**********************************************************************************
						11 - FOCUS ON POPULATION WITH MI HISTORY
**********************************************************************************/

*Limit the dataset to patients with a history of hospitalization for MI prior to 
baseline;

data primary_analysis_mi;
set primary_analysis;
	where bl_mi = 1;
run;
*2,971 observations;




*Output table 1;

proc sort data=primary_analysis_mi; by bene_id indexdate; run;
%table1(inds = primary_analysis_mi, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_heartfail 
			bl_hf_hosp bl_chronickid bl_copd bl_hchl
			bl_mi bl_strk bl_pcip bl_cabg bl_tobacco 
			/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics - MI Only_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;




*Fit the propensity score model;

%MACRO ps_mi(inds =, outds =);

	proc logistic data=&inds;
		class cal_year bl_aur bl_chdz bl_heartfail bl_hf_hosp bl_chronickid bl_copd bl_hchl
				bl_strk bl_pcip bl_cabg bl_tobacco 
				
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_diab
				/*antidiabetics*/ bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt
				bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race
				/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hf bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
				bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
				bl_outpatientvisit bl_oxygen bl_wheelchair;
		model ab (reference = /*'0'*/ 'AR5') = age cal_year bl_aur bl_tobacco 
				/*make flexible around heart conditions
					Everyone has bl_chdz*/ 
				/*bl_chdz*/ bl_hf bl_hf_hosp bl_chronickid bl_copd bl_hchl bl_strk bl_diab 
				/*bl_chdz*/ bl_hf*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero

				/*antihypertensives*/ bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
					bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop
					bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins 
				/*antidiabetics*/ 
				bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				 bl_obesity rti_race
				/*frailty*/ bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric
				bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance bl_hospBed
				bl_outpatientvisit bl_oxygen bl_wheelchair;
		output out=&outds p=PS;
	run;

%MEND;

%ps_mi(inds = primary_cohort_mi, outds = ps_mi);


***
Assess PS fit
***;


*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Hist - MI Cohort";
proc sgplot data=ps_mi;
	title "Histogram - PS Distributions by Treatment Group in the Primary Cohort";
	histogram ps / group = ab transparency=0.7;
	*density ps / type = kernel;
	keylegend / location=inside position = topleft;
run;

*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Density - MI Cohort";
proc sgplot data=ps_mi;
	title "Density - PS Distributions by Treatment Group in the Primary Cohort";
	*histogram ps / group = ab;
	density ps / group = ab type = kernel;
	keylegend / location=inside position = topleft;
run;


****
Trim non-overlapping PSs
****;


*Calculate the min and max of each so that we can trim the non-overlapping regions;
proc sort data=ps_mi; by ab; run;
proc means data=ps_mi mean min max;
	by ab;
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
	create table ps2_mi as
	select a.*, b.minPS, b.maxPS
	from ps_mi as a
	left join sumstat2 as b
	on a.ab = b.jointo
	;
	quit;

*Indicate which values to delete & remove those individuals;
data ps3_mi (where = (delete = 0));
set ps2_mi;
	delete=0;
	if ab = 0 & ps < minPS then delete=1;
	if ab = 1 & ps > maxPS then delete=1;
run;
*Now, 2,954 individuals;


***
Need to re-fit the PS model in that population.
***;


*Re-fit PS model;
%ps_mi(inds = ps3_mi, outds = ps_trim_mi);


*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Hist - MI Cohort - Trimmed";
proc sgplot data=ps_trim_mi;
	title "Histogram - PS Distributions by Treatment Group in the MI Cohort After Trimming";
	histogram ps / group = ab transparency=0.7;
	*density ps / type = kernel;
	keylegend / location=inside position = topleft;
run;

*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Density - MI Cohort - Trimmed";
proc sgplot data=ps_trim_mi;
	title "Density - PS Distributions by Treatment Group in the MI Cohort After Trimming";
	*histogram ps / group = ab;
	density ps / group = ab type = kernel;
	keylegend / location=inside position = topleft;
run;


***
Calculate Weights
***;
%iptw(inds = primary_cohort_mi, psds = ps_trim_mi, outds = cohort_weights_mi);


*Calculate mean, max, and min of weights;
proc means data=cohort_weights_mi max min mean;
	class ab;
	var iptw;
run;



***
Output the IPTW Table 1
***;

proc sort data=cohort_weights_mi; by bene_id indexdate; run;
%table1(inds = cohort_weights_mi, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
			bl_aur bl_chdz bl_heartfail 
			bl_hf_hosp bl_chronickid bl_copd bl_hchl
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
			bl_outpatientvisit bl_oxygen bl_wheelchair, wgtVar=iptw, contStat=median, smd_cat=overall);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics with IPTW - MI Only&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





***
Bootstrap effect estimates
***;


*Look at how many outcome events are in each cohort;




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



options mprint;

**
(1) hosp for HF
**;

**
Estimate on the primary sample
**;
%competingrisk_single_weights(inds=primary_analysis_mi, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=1, initialseed=23244, outds=ana.HF_365_mi_sample);

%calculate_est(inds=ana.hf_365_mi, outds=hf_365_mi_summary, fup=365, rd_multiple=1);


***
365
***;
%competingrisk_weights(inds=primary_analysis_mi, startDT=FillDate2, eventDT=HF_date, crDT=death_dt, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=200, initialseed=23244, outds=ana.HF_365_mi);





**
1825
**;
%competingrisk_weights(inds=primary_analysis, startDT=FillDate2, eventDT=HF_date, crDT=compEvent_dt, censorDT=endDT_itt, 
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







**
(2) Composite MACE
(3) Composite MACE or hosp for HF
(4) Death
**;

***
No bootstrapping
***;
%risk_weights_multiple_mi_sample(inds=primary_analysis_mi, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=1);

***
365
***;
%risk_weights_multiple_mi(inds=primary_analysis_mi, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
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
      numiterations=200);

**
(5) PCIP
**;



**
(6) CABG
**;



****
Calculate estimates from bootstraps
****;



*(1) HF;

*Combine estimates;
proc sql;
	create table ana.hf_365_mi as
	select * from ana.hf_365_mi_first200
	union
	select * from ana.hf_365_mi_last300
	order by samplingseed
	;
	quit;

*Calculate the study estimates;
%calculate_est(inds=ana.hf_365_mi, outds=hf_365_mi_summary, fup=365, rd_multiple=100);
data ana.hf_365_mi_summary; set ana.hf_365_mi_summary; 
	variable = "Heart Failure Outcome"; run;



*(2) MACE;


*Rename the variables;
%rename_risk(inds=mace_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_mace_365_mi, outds=mace_365_mi_summary, fup=365, rd_multiple=10000);
data ana.mace_365_mi_summary; set ana.mace_365_mi_summary; 
	variable = "MACE Outcome"; run;




*(3) MACE + HF;

*Rename the variables;
%rename_risk(inds=macehf_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_macehf_365_mi, outds=macehf_365_mi_summary, fup=365, rd_multiple=100);
data ana.macehf_365_mi_summary; set ana.macehf_365_mi_summary; 
	variable = "MACE and HF Outcome"; run;



*(4) DEATH;

*Rename the variables;
%rename_risk(inds=death_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_death_365_mi, outds=death_365_mi_summary, fup=365, rd_multiple=1000);
data ana.death_365_mi_summary; set ana.death_365_mi_summary; 
	variable = "Death Outcome"; run;

*(5) CABG;

*(6) PCIP;




	
**
Combine the estimates into one dataset
**;
proc sql;
	create table mi_365_estimates as
	select * from ana.hf_365_mi_summary
	union
	select * from ana.mace_365_mi_summary
	union
	select * from ana.macehf_365_mi_summary
	union
	select * from ana.death_365_mi_summary
	order by variable
	;
	quit; 

data ana.mi_365_estimates (keep = risk0 risk0_CI risk1 risk1_CI
				rd rd_CI rr rr_ci rd_multiple variable);
set mi_365_estimates;
	risk0 = round(risk0_365, 0.01);
	risk0_CI = cats(round(risk0_365_LCL, 0.01), ", ", round(risk0_365_UCL,0.01));
	risk1 = round(risk1_365, 0.01);
	risk1_CI = cats(round(risk1_365_LCL, 0.01), ", ", round(risk1_365_UCL,0.01));
	rd = round(rd365, 0.01);
	rd_CI = cats(round(rd365_LCL,0.01), ", ", round(rd365_UCL, 0.01));
	rr = round(rr365, 0.01);
	rr_CI = cats(round(rr365_LCL,0.01), ", ", round(rr365_UCL, 0.01));
run;
















/**********************************************************************************
							   		OLD CODE
**********************************************************************************/


***
Create macros needed for data processing from the output files.
***;


/*Macro to combine datasets from the boostrap datasets and the final estimate*/

/*%macro combine_comprisk(boot_ds=, est_ds=, out_ds=, var=);*/
/**/
/*	*Calculate the confidence intervals for your estimates;*/
/*	proc univariate data=&boot_ds noprint;*/
/*		var riskDiff365 riskRatio365 riskDiff1825 riskRatio1825;*/
/*		output out = _CI_values pctlpts = 2.5 97.5 pctlpre = riskDiff365 riskRatio365 riskDiff1825 riskRatio1825;*/
/*	run;*/
/**/
/*	*Get the RD and RR estimates;*/
/*	proc sql;*/
/*		create table _estimates as*/
/*		select riskDiff365 as RD365, riskRatio365 as RR365, riskDiff1825 as RD1825,*/
/*				riskRatio1825 as RR1825*/
/*		from &est_ds*/
/*		;*/
/*		quit;*/
/**/
/*	*Get the CI estimates for each;*/
/*	proc sql;*/
/*		create table _CIs as*/
/*		select riskDiff3652_5 as RD365_LCL, riskDiff36597_5 as RD365_UCL,*/
/*				riskRatio3652_5 as RR365_LCL, riskRatio36597_5 as RR365_UCL, */
/*				riskDiff18252_5 as RD1825_LCL, riskDiff182597_5 as RD1825_UCL,*/
/*				riskRatio18252_5 as RR1825_LCL, riskRatio182597_5 as RR1825_UCL*/
/*		from _CI_values */
/*		;*/
/*		quit;*/
/**/
/*	*Merge the two datasets;*/
/*	data &out_ds;*/
/*	merge _estimates*/
/*		  _CIs;*/
/*		  variable = &var;*/
/*	run;*/
/**/
/**/
/*%mend;*/
/**/
/**/
/*/*Macro to combine datasets from the boostrap datasets and the final estimate*/
/*specific to the risk macro, not competing risk*/*/
/**/
/*%macro combine_risk(boot_ds=, est_ds=, out_ds=, var=);*/
/**/
/*	*Calculate the confidence intervals for your estimates;*/
/*	proc univariate data=&boot_ds noprint;*/
/*		var rd365 rr365 rd1825 rr1825;*/
/*		output out = _CI_values pctlpts = 2.5 97.5 pctlpre = rd365 rr365 rd1825 rr1825;*/
/*	run;*/
/**/
/*	*Get the RD and RR estimates;*/
/*	data _estimates;*/
/*	set &est_ds (keep = (rd365 rr365 rd1825 rr1825));*/
/*	run;*/
/**/
/*	*Get the CI estimates for each;*/
/*	proc sql;*/
/*		create table _CIs as*/
/*		select rd3652_5 as RD365_LCL, rd36597_5 as RD365_UCL,*/
/*				rr3652_5 as RR365_LCL, rd36597_5 as RR365_UCL, */
/*				rdf18252_5 as RD1825_LCL, rd182597_5 as RD1825_UCL,*/
/*				rr18252_5 as RR1825_LCL, rr182597_5 as RR1825_UCL*/
/*		from _CI_values */
/*		;*/
/*		quit;*/
/**/
/*	*Merge the two datasets;*/
/*	data &out_ds;*/
/*	merge _estimates*/
/*		  _CIs;*/
/*		  variable = &var;*/
/*	run;*/
/**/
/**/
/*%mend;*/




