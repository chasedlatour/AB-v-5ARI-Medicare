/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 14a_icd10_analysis.sas
	DESCRIPTION: The goal of this analysis is to replicate the primary analyses, excluding 
	those new-use episodes prior to the ICD-10 transition for capturing outcomes.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10

	DATE UPDATED

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - FORMAT DATASET
	02 - OUTPUT TABLE 1


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

%setup(full, 9a_restrict_exp_analysis, saveLog=N);
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





*Remove the episodes with a history of anticoagulant use in the last year;
data ana.icd10_cohort (where = (icd10 = 1));
set ana.primary_cohort;
	
	icd10=0;
	if indexdate >= 20362 then icd10=1;

run;

*Dropped from 189,886 persons to 77,302 persons/new-use episodes;


/************************************************************************************************
										02 - OUTPUT TABLE 1

This matches with what Sola did. However, it does not reflect the PS model specification.
The table that matches the weighted table is output later.
************************************************************************************************/

*Output table 1;

proc sort data=ana.icd10_cohort out=icd10_cohort; by bene_id indexdate; run;
%table1(inds = icd10_cohort, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
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
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_ICD-10_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;

