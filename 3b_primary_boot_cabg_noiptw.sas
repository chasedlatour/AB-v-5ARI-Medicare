/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: primary_analysis
	DESCRIPTION:This program conducts bootstrapping for CABG as an outcome, only considering
	those analyses with IPTW (i.e., still using censoring weights). Having these estimates
	will help demonstrate the residual confounding in unadjusted analyses.

	These analyses take substantial time to run and so were batch
	submitted on the UNC server.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10

	DATE UPDATED

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - FORMAT DATASET
	02 - BOOTSTRAP EFFECT ESTIMATES

************************************************************************************************/





/************************************************************************************************
										00 - SET-UP
************************************************************************************************/
*Local submit to prompt sign on into server;
/*SIGNOFF;*/
/*%LET server=n2.schsr.unc.edu 1234;options comamid=tcp remote=server;signon username=_prompt_;*/

*Set up directories for project;
options source source2 msglevel=I mcompilenote=all mautosource mprint
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, 3b_primary_boot_hf, saveLog=Y);
*%setup(1pct, primary_analysis, saveLog=N);

*Map local mirrors for all remote libraries using LOCAL submit;
/*libname lout slibref=out server=server;*/
/*libname lwork slibref=work server=server;*/
/*libname lraw slibref=raw server=server;*/
/*libname lder slibref=der server=server;*/



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


/**********************************************************************************
						02 - BOOTSTRAP EFFECT ESTIMATES
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
(6) CABG
**;


*With IPTW;

*%competingrisk_weights(inds=ana.primary_cohort, startDT=FillDate2, eventDT=cabg_cpt_carr_date, crDT=death_dt, censorDT=endDT_itt, 
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
				noiptw=0,
      numiterations=500, outds=ana.cabg_365_p_boot);




*Without IPTW;

%competingrisk_weights(inds=ana.primary_cohort, startDT=FillDate2, eventDT=cabg_cpt_carr_date, crDT=death_dt, censorDT=endDT_itt, 
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
				noiptw=1,
      numiterations=500, outds=ana.cabg_365_p_boot_noiptw);

