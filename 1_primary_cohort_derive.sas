/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 1_primary_cohort_derive
	DESCRIPTION:The goal of this program is to derive our final patient cohort from the cleaned
	claims data.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - FORMAT DATASET
	02 - OUTPUT DATASET

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

%setup(full, primary_cohort, saveLog=N);
*%setup(1pct, primary_analysis, saveLog=N);

*Map local mirrors for all remote libraries using LOCAL submit;
libname lout slibref=out server=server;
libname lwork slibref=work server=server;
libname lraw slibref=raw server=server;
libname lder slibref=der server=server;
libname lana slibref=ana server=server;



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



*Limit the cohort to people without sufficient continuous enrollment & people without new use 
of the study medications - DONE ALREADY;

* Count the number of episodes & unique individuals;
proc sql;
	select count(bene_id) as count_episodees, count(distinct bene_id) as count_bene_id
	from out.covariates;
	quit;
	*# of episodes of new-use = 898,454
	# of unique individuals = 653,996;



*Limit the dataset to the correct age at index.;
proc sql;
	create table cohort_restrict as
	select *
	from out.covariates
	where 66 le age le 90
	;
	quit;



*Count the unique number of people 66-90 with a new-use episode;
proc sql;
	select count (distinct bene_id) as num_people,
			count (bene_id) as num_episodes
	from cohort_restrict;
	quit;
	*635,007 people; 
	*869,476 episodes;


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
	*440,079 people; 
	*590,890 episodes;


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
	*395,648 people; 
	*524,089 episodes;



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
	*189,886 people; 
	*197,684 episodes;





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
	*189,886 people; 
	*189,886 episodes;


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




/**********************************************************************************

							02 - OUTPUT DATASET

**********************************************************************************/


*Left-join the Outcomes dataset on the trimmed, primary cohort
join death and censoring dates from the cohortds file;

*Changed this to pull directly from the original cohort because we want to apply
trimming, PS modeling, weights etc. in the bootstrapping process. They should 
be re-fit each time the bootstrap sample is run.;

proc sql;
	create table ana.primary_cohort as 
	select a.*, b.*
	from /*cohort_weights2*/ cohort_primary as a
	left join out.outcomes /*ana.outcomes_correct*/ as b
	on a.bene_id = b.bene_id and a.indexdate = b.indexdate
	;
	quit;


**Calculate variable: days from first BPH diagnosis to index_date;
data ana.primary_cohort;
set ana.primary_cohort;
	first_bph_date = min(first_bphwous_dt, first_bphwus_dt);

	days_first_bph = indexdate - first_bph_date;

	*Make a categorical days since first diagnosis;
	if days_first_bph < 180 then cat_bph_days = 1;
		else if days_first_bph >= 180 then cat_bph_days = 2;

	*Make Categorical BPH number diagnosis codes;
	if num_dx1yr_bphwous = 1 and num_dx1yr_bphwus = 0 then num_bph = 1;
		else if num_dx1yr_bphwous = 0 and num_dx1yr_bphwus = 1 then num_bph = 1;
		else if num_dx1yr_bphwous = 1 and num_dx1yr_bphwus = 1 then num_bph = 2;
		else if num_dx1yr_bphwous = 2 and num_dx1yr_bphwus = 0 then num_bph = 2;
		else if num_dx1yr_bphwous = 0 and num_dx1yr_bphwus = 2 then num_bph = 2;
		else num_bph = 3;

run;



