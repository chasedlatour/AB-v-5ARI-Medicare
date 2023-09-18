/*****************************************************************************************************/
/* Program: /projects/medicare/ablocker/programs/macros/calculate_est.sas                                 */
/* Purpose: Produce output for a typical Table 1: Baseline Covariates                                */
/*                                                                                                   */
/* Created on: December 14, 2022                                                                    */
/* Created by: Chase Latour                                                                         */
/*                                                                                                   */
/* Inputs: INDS = Input dataset where the probabilities of treatment should be calculated
*/
/*                                                                                                   */
/*		   PSDS = name of the dataset where IPTW denominator PSs have been calculated

		   OUTDS = name of the output dataset*/

/* Details: This macro was created to fit the primary PS model. This may be modified for sensitivity 
	analyses, but this limited the number of times that the PS macro needs to be re-typed into a file.
*/
/*                                                                                                   */
/*****************************************************************************************************/


**
Create macro for calculating the PS model
**;

%MACRO ps_tobacco(inds =, outds =);

	proc logistic data=&inds;
		class cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg /*bl_tobacco*/ bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair;
		model ab (reference = /*'0'*/ 'AR5') = 
				age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair;
		output out=&outds p=PS;
	run;

%MEND;
