/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 2_stratified_analysis_cohort
	PURPOSE: The goal of this program is to recalculate the primary study effect estimates
	in the primary cohort, stratified by obesity and smoking for quantitative bias analysis.

	CREATED BY: Chase Latour
	DATE CREATED: 2023 SEP 07

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - ANALYSES STRATIFIED BY OBESITY
	02 - ANALYSES STRATIFIED BY SMOKING
	03 - ANALYSES STRATIFIED BY SMOKING AND COPD

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
libname lana slibref=ana server=server;



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

*Call in the dataset;
proc sort data=ana.primary_cohort out=cohort_primary; by bene_id indexdate; run;






/************************************************************************************************
							01 - ANALYSES STRATIFIED BY OBESITY

Re-run all of the primary analyses, stratified by obesity status.
************************************************************************************************/

**Limit the population to those where bl_obese = 1;
data cohort_obesity_1;
set cohort_primary;
	where bl_obesity = 1;
run;

***Look at the weighted treatment populations ;

*Fit the ps model;
%ps_obesity(inds=cohort_obesity_1, outds=ps);

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

*Re-fit PS model;
%ps_obesity(inds = ps3, outds = ps_trim);

*Calculate the IPTW;
%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Sum the weights across the treatment groups;
proc means data=cohort_weights2 sum;
	class ab;
	var iptw;
run;



*Calculate effect estimate with IPTW for MACE as the study outcome
Remove obesity from the variables because we are stratifying on obesity status;

%risk_weights_multiple_sample(inds=cohort_obesity_1, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd /*bl_obesity*/ rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd /*bl_obesity*/ rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero /*bl_obesity*/ rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=obesity_1, noiptw=0,
      numiterations=1);

**Limit the population to those where bl_obese = 0;
data cohort_obesity_0;
set cohort_primary;
	where bl_obesity = 0;
run;


***Look at the weighted treatment populations ;

*Fit the ps model;
%ps_obesity(inds=cohort_obesity_0, outds=ps);

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

*Re-fit PS model;
%ps_obesity(inds = ps3, outds = ps_trim);

*Calculate the IPTW;
%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Sum the weights across the treatment groups;
proc means data=cohort_weights2 sum;
	class ab;
	var iptw;
run;

*Calculate effect estimate with IPTW for MACE as the study outcome
Remove obesity from the variables because we are stratifying on obesity status;

%risk_weights_multiple_sample(inds=cohort_obesity_0, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd /*bl_obesity*/ rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur bl_tobacco bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd /*bl_obesity*/ rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg bl_tobacco bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero /*bl_obesity*/ rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=obesity_0, noiptw=0,
      numiterations=1);

**Create a weighted Table 1;





/************************************************************************************************
							02 - ANALYSES STRATIFIED BY SMOKING

Re-run all of the primary analyses, stratified by smoking/tobacco status.
************************************************************************************************/

**Limit the population to those where bl_tobacco = 1;
data cohort_tobacco_1;
set cohort_primary;
	where bl_tobacco = 1;
run;

***Look at the weighted treatment populations ;

*Fit the ps model;
%ps_tobacco(inds=cohort_tobacco_1, outds=ps);

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

*Re-fit PS model;
%ps_tobacco(inds = ps3, outds = ps_trim);

*Calculate the IPTW;
%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Sum the weights across the treatment groups;
proc means data=cohort_weights2 sum;
	class ab;
	var iptw;
run;


*Calculate effect estimate with IPTW for MACE as the study outcome
Remove obesity from the variables because we are stratifying on tobacco status;

%risk_weights_multiple_sample(inds=cohort_tobacco_1, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg /*bl_tobacco*/ bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=tobacco_1, noiptw=0,
      numiterations=1);

**Limit the population to those where bl_tobacco = 0;
data cohort_tobacco_0;
set cohort_primary;
	where bl_tobacco = 0;
run;


***Look at the weighted treatment populations ;

*Fit the ps model;
%ps_tobacco(inds=cohort_tobacco_0, outds=ps);

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

*Re-fit PS model;
%ps_tobacco(inds = ps3, outds = ps_trim);

*Calculate the IPTW;
%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Sum the weights across the treatment groups;
proc means data=cohort_weights2 sum;
	class ab;
	var iptw;
run;



*Calculate effect estimate with IPTW for MACE as the study outcome
Remove obesity from the variables because we are stratifying on tobacco status;

%risk_weights_multiple_sample(inds=cohort_tobacco_0, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid bl_copd bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid bl_copd bl_hchl bl_mi bl_strk bl_pcip bl_cabg /*bl_tobacco*/ bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=tobacco_0, noiptw=0,
      numiterations=1);



/************************************************************************************************
						03 - ANALYSES STRATIFIED BY SMOKING AND COPD

Re-run all of the primary analyses, stratified by smoking/tobacco status and COPD.
************************************************************************************************/

**Limit the population to those where bl_tobacco = 1 or bl_copd = 1;
data cohort_tobacco_copd_1;
set cohort_primary;
	where bl_tobacco = 1 OR bl_copd = 1;
run;

***Look at the weighted treatment populations ;

*Fit the ps model;
%ps_tobacco_copd(inds=cohort_tobacco_copd_1, outds=ps);

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

*Re-fit PS model;
%ps_tobacco_copd(inds = ps3, outds = ps_trim);

*Calculate the IPTW;
%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Sum the weights across the treatment groups;
proc means data=cohort_weights2 sum;
	class ab;
	var iptw;
run;


*Calculate effect estimate with IPTW for MACE as the study outcome
Remove obesity from the variables because we are stratifying on tobacco status;

%risk_weights_multiple_sample(inds=cohort_tobacco_copd_1, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid /*bl_copd*/ bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid /*bl_copd*/ bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid /*bl_copd*/ bl_hchl bl_mi bl_strk bl_pcip bl_cabg /*bl_tobacco*/ bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=tobacco_copd_1, noiptw=0,
      numiterations=1);

**Limit the population to those where bl_tobacco = 0;
data cohort_tobacco_copd_0;
set cohort_primary;
	where bl_tobacco = 0 and bl_copd = 0;
run;


***Look at the weighted treatment populations ;

*Fit the ps model;
%ps_tobacco_copd(inds=cohort_tobacco_copd_0, outds=ps);

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

*Re-fit PS model;
%ps_tobacco_copd(inds = ps3, outds = ps_trim);

*Calculate the IPTW;
%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Sum the weights across the treatment groups;
proc means data=cohort_weights2 sum;
	class ab;
	var iptw;
run;



*Calculate effect estimate with IPTW for MACE as the study outcome
Remove obesity from the variables because we are stratifying on tobacco status;

%risk_weights_multiple_sample(inds=cohort_tobacco_copd_0, startDT=FillDate2, censorDT=endDT_itt, 
      daysEst=365, psvars=age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid /*bl_copd*/ bl_hchl 
				bl_mi bl_strk bl_diab bl_chdz*bl_hf_hosp*bl_chronickid*bl_copd*bl_hchl*bl_mi*bl_strk*bl_diab 
				bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_acei*bl_arb*bl_bb*bl_peripheralvaso*bl_bb*bl_ccb*bl_thiazide*bl_combodiuretics*bl_ksparingdiuretic*bl_loop*bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				dovars= age cal_year bl_aur /*bl_tobacco*/ bl_chdz /*bl_hf*/ bl_hf_hosp bl_chronickid /*bl_copd*/ bl_hchl 
				bl_mi bl_strk bl_diab bl_pcip bl_cabg bl_athero bl_acei bl_arb bl_bb bl_peripheralvaso bl_bb
				bl_ccb bl_thiazide bl_combodiuretics bl_ksparingdiuretic bl_loop bl_otherdiuretics
				bl_anycoagcat bl_opioidcat bl_nicotine_varen bl_statins bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat 
				bl_sglt bl_sulfonylurea bl_tzd bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness bl_ambulance 
				bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, 
				classvars= cal_year bl_aur bl_chdz /*bl_heartfail*/ bl_hf_hosp 
				bl_chronickid /*bl_copd*/ bl_hchl bl_mi bl_strk bl_pcip bl_cabg /*bl_tobacco*/ bl_anycoagcat bl_opioidcat bl_nicotine_varen
				bl_statins bl_diab bl_dpp bl_glp bl_lainsulin_cat bl_sainsulin_cat bl_sglt bl_sulfonylurea bl_tzd
				bl_athero bl_obesity rti_race bl_arthritis bl_bladder bl_braininjury bl_decub bl_dement
				/*bl_hf*/ bl_hyposhock bl_lipid bl_paralysis bl_pd bl_podiatric bl_psych bl_screening bl_vertigo bl_weakness 
				bl_ambulance bl_hospBed bl_outpatientvisit bl_rehab bl_oxygen bl_wheelchair, trtvar=ab, 
				cohort=tobacco_copd_0, noiptw=0,
      numiterations=1);

