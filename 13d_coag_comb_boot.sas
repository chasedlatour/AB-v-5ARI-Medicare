/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 13d_coag_comb_boot
	DESCRIPTION: Combine the bootstrapped estimates from the sensivity analysis excluding new-
	use episodes with a history of anticoagulant use.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10

	DATE UPDATED

*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - FORMAT DATASET
	02 - COUNT THE NUMBER OF PEOPLE IN THE COHORT
	03 - SUMMARIZE THE BOOTSTRAPPED ESTIMATES

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

%setup(full, 12c_bph_conf_comb_boot, saveLog=N);
*%setup(1pct, mi_analysis, saveLog=N);

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


/**********************************************************************************
				02 - COUNT THE NUMBER OF PEOPLE IN THE COHORT
**********************************************************************************/

proc sql;
	select count(*) as n_episodes
	from ana.p_cohort_restrict_coag;
	quit;




/**********************************************************************************
						03 - SUMMARIZE BOOTSTRAPPED ESTS
**********************************************************************************/

*Macro to re-name the variables

The risk and competing risk macros output the variables with different names; 
%macro rename_risk(inds=, fup=);

	data rename_&inds;
	set &inds (drop = ab
		rename = (r0=e0_rate&fup r=e1_rate&fup lnrr=lnriskRatio&fup rr=riskRatio&fup rd=riskDiff&fup));
	run;
		
%mend;




****Didn't run the results without IPTW since this is a sensitivity analysis.;



*(1) HF;

***
IPTW
***;

*Calculate the study estimates;
%calculate_est(inds=ana.hf_365_coag_boot, outds=hf_365_summary, fup=365, rd_multiple=10000);
data ana.hf_365_coag_summary; set ana.hf_365_summary; 
	variable = "Heart Failure Outcome"; run;




*(2) MACE;

****
	IPTW
****;

*De-dup the dataset;
proc sql;
	create table mace_365 as
	select distinct *
	from ana.mace_365_coag_boot
	; quit;


*Rename the variables;
%rename_risk(inds=mace_365, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_mace_365, outds=mace_365_summary, fup=365, rd_multiple=1000);
data ana.mace_365_coag_summary; set ana.mace_365_summary; 
	variable = "MACE Outcome"; run;





*(3) MACE + HF;


****
	With IPTW
****;

*De-dup the dataset;
proc sql;
	create table macehf_365 as
	select distinct *
	from ana.macehf_365_coag_boot
	; quit;

*Rename the variables;
%rename_risk(inds=macehf_365, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_macehf_365, outds=macehf_365_summary, fup=365, rd_multiple=1000);
data ana.macehf_365_coag_summary; set ana.macehf_365_summary; 
	variable = "MACE and HF Outcome"; run;




*(4) DEATH;


*******
	With IPTW
*******;

*De-dup the dataset;
proc sql;
	create table death_365 as
	select distinct *
	from ana.death_365_coag_boot
	; quit;
proc sort data=death_365; by samplingseed; run;

*Rename the variables;
%rename_risk(inds=death_365, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_death_365, outds=death_365_summary, fup=365, rd_multiple=1000);
data ana.death_365_coag_summary; set ana.death_365_summary; 
	variable = "Death Outcome"; run;




**
Combine the estimates into one dataset
**;


****
	With IPTW
*****;


proc sql;
	create table coag_365_est_iptw as
	select * from ana.hf_365_coag_summary
	union
	select * from ana.mace_365_coag_summary
	union
	select * from ana.macehf_365_coag_summary
	union
	select * from ana.death_365_coag_summary
	;
	quit; 

data ana.coag_365_est_iptw (keep = risk0 risk0_CI risk1 risk1_CI
				rd rd_CI rr rr_ci rd_multiple variable);
set coag_365_est_iptw;
	risk0 = round(risk0_365, 0.01);
	risk0_CI = cats(round(risk0_365_LCL, 0.01), ", ", round(risk0_365_UCL,0.01));
	risk1 = round(risk1_365, 0.01);
	risk1_CI = cats(round(risk1_365_LCL, 0.01), ", ", round(risk1_365_UCL,0.01));
	rd = round(rd365, 0.01);
	rd_CI = cats(round(rd365_LCL,0.01), ", ", round(rd365_UCL, 0.01));
	rr = round(rr365, 0.01);
	rr_CI = cats(round(rr365_LCL,0.01), ", ", round(rr365_UCL, 0.01));
run;






****
	Without IPTW
*****;

**Didn't calculate estimates without IPTW because this is a sensitivity analysis;
