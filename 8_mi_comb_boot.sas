/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 8_mi_comb_boot
	DESCRIPTION:Combine the bootstrapped estimates from the MI sub-analysis.

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
options source source2 msglevel=I mcompilenote=all mautosource mprint
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");


%setup(full, 8_mi_comb_boot, saveLog=N);
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
						11 - SUMMARIZE BOOTSTRAPPED ESTS
**********************************************************************************/

*Macro to re-name the variables

The risk and competing risk macros output the variables with different names; 
%macro rename_risk(inds=, fup=);

	data rename_&inds;
	set &inds (drop = ab
		rename = (r0=e0_rate&fup r=e1_rate&fup lnrr=lnriskRatio&fup rr=riskRatio&fup rd=riskDiff&fup));
	run;
		
%mend;








*(1) HF;

***
IPTW
***;

*Calculate the study estimates;
%calculate_est(inds=ana.hf_365_mi_boot, outds=hf_365_mi_summary, fup=365, rd_multiple=100);
data ana.hf_365_mi_summary; set ana.hf_365_mi_summary; 
	variable = "Heart Failure Outcome"; run;


***
Without IPTW
***;

*Calculate the study estimates;
%calculate_est(inds=ana.hf_365_mi_boot_noiptw, outds=hf_365_mi_summary_noiptw, fup=365, rd_multiple=100);
data ana.hf_365_mi_summary_noiptw; set ana.hf_365_mi_summary_noiptw; 
	variable = "Heart Failure Outcome"; run;



*(2) MACE;

****
	IPTW
****;

*De-dup the dataset;
proc sql;
	create table mace_365_mi as
	select distinct *
	from ana.mace_365_mi_boot
	; quit;


*Rename the variables;
%rename_risk(inds=mace_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_mace_365_mi, outds=mace_365_mi_summary, fup=365, rd_multiple=100);
data ana.mace_365_mi_summary; set ana.mace_365_mi_summary; 
	variable = "MACE Outcome"; run;


*****
	Without IPTW
*****;


*De-dup the dataset;
proc sql;
	create table mace_365_mi as
	select distinct *
	from ana.mace_365_mi_boot_noiptw
	; quit;


*Rename the variables;
%rename_risk(inds=mace_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_mace_365_mi, outds=mace_365_mi_summary_noiptw, fup=365, rd_multiple=100);
data ana.mace_365_mi_summary_noiptw; set ana.mace_365_mi_summary_noiptw; 
	variable = "MACE Outcome"; run;




*(3) MACE + HF;


****
	With IPTW
****;

*De-dup the dataset;
proc sql;
	create table macehf_365_mi as
	select distinct *
	from ana.macehf_365_mi_boot
	; quit;

*Rename the variables;
%rename_risk(inds=macehf_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_macehf_365_mi, outds=macehf_365_mi_summary, fup=365, rd_multiple=1000);
data ana.macehf_365_mi_summary; set ana.macehf_365_mi_summary; 
	variable = "MACE and HF Outcome"; run;


****
	Without IPTW
****;

*De-dup the dataset;
proc sql;
	create table macehf_365_mi as
	select distinct *
	from ana.macehf_365_mi_boot_noiptw
	; quit;

*Rename the variables;
%rename_risk(inds=macehf_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_macehf_365_mi, outds=macehf_365_mi_summary_noiptw, fup=365, rd_multiple=1000);
data ana.macehf_365_mi_summary_noiptw; set ana.macehf_365_mi_summary_noiptw; 
	variable = "MACE and HF Outcome"; run;





*(4) DEATH;


*******
	With IPTW
*******;

*De-dup the dataset;
proc sql;
	create table death_365_mi as
	select distinct *
	from ana.death_365_mi_boot
	; quit;

*Rename the variables;
%rename_risk(inds=death_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_death_365_mi, outds=death_365_mi_summary, fup=365, rd_multiple=1000);
data ana.death_365_mi_summary; set ana.death_365_mi_summary; 
	variable = "Death Outcome"; run;


*******
	Without IPTW
*******;

*De-dup the dataset;
proc sql;
	create table death_365_mi as
	select distinct *
	from ana.death_365_mi_boot_noiptw
	; quit;

*Rename the variables;
%rename_risk(inds=death_365_mi, fup=365);

*Calculate the study estimates;
%calculate_est(inds=rename_death_365_mi, outds=death_365_mi_summary_noiptw, fup=365, rd_multiple=1000);
data ana.death_365_mi_summary_noiptw; set ana.death_365_mi_summary_noiptw; 
	variable = "Death Outcome"; run;






*(5) CABG;


***
IPTW
***;

*Calculate the study estimates;
%calculate_est(inds=ana.cabg_365_mi_boot, outds=cabg_365_mi_summary, fup=365, rd_multiple=1000);
data ana.cabg_365_mi_summary; set ana.cabg_365_mi_summary; 
	variable = "CABG Outcome"; run;


***
Without IPTW
***;

*Calculate the study estimates;
%calculate_est(inds=ana.cabg_365_mi_boot_noiptw, outds=cabg_365_mi_summary_noiptw, fup=365, rd_multiple=1000);
data ana.cabg_365_mi_summary_noiptw; set ana.cabg_365_mi_summary_noiptw; 
	variable = "CABG Outcome"; run;



*(6) PCIP;

*Calculate the study estimates;

***
With IPTW
***;
%calculate_est(inds=ana.pcip_365_mi_boot, outds=pcip_365_mi_summary, fup=365, rd_multiple=1000);
data ana.pcip_365_mi_summary; set ana.pcip_365_mi_summary; 
	variable = "PCI Procedure"; run;


***
Without IPTW
***;

*Calculate the study estimates;
%calculate_est(inds=ana.pcip_365_mi_boot_noiptw, outds=pcip_365_mi_summary_noiptw, fup=365, rd_multiple=1000);
data ana.pcip_365_mi_summary_noiptw; set ana.pcip_365_mi_summary_noiptw; 
	variable = "PCI Procedure"; run;




**
Combine the estimates into one dataset
**;


****
	With IPTW
*****;


proc sql;
	create table mi_365_est_iptw as
	select * from ana.hf_365_mi_summary
	union
	select * from ana.mace_365_mi_summary
	union
	select * from ana.macehf_365_mi_summary
	union
	select * from ana.death_365_mi_summary
	union
	select * from ana.pcip_365_mi_summary
	union
	select * from ana.cabg_365_mi_summary
	;
	quit; 

data ana.mi_365_est_iptw (keep = risk0 risk0_CI risk1 risk1_CI
				rd rd_CI rr rr_ci rd_multiple variable);
set mi_365_est_iptw;
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


proc sql;
	create table mi_365_est_noiptw as
	select * from ana.hf_365_mi_summary_noiptw
	union
	select * from ana.mace_365_mi_summary_noiptw
	union
	select * from ana.macehf_365_mi_summary_noiptw
	union
	select * from ana.death_365_mi_summary_noiptw
	union
	select * from ana.pcip_365_mi_summary_noiptw
	union
	select * from ana.cabg_365_mi_summary_noiptw
	;
	quit; 

data ana.mi_365_est_noiptw (keep = risk0 risk0_CI risk1 risk1_CI
				rd rd_CI rr rr_ci rd_multiple variable);
set mi_365_est_noiptw;
	risk0 = round(risk0_365, 0.01);
	risk0_CI = cats(round(risk0_365_LCL, 0.01), ", ", round(risk0_365_UCL,0.01));
	risk1 = round(risk1_365, 0.01);
	risk1_CI = cats(round(risk1_365_LCL, 0.01), ", ", round(risk1_365_UCL,0.01));
	rd = round(rd365, 0.01);
	rd_CI = cats(round(rd365_LCL,0.01), ", ", round(rd365_UCL, 0.01));
	rr = round(rr365, 0.01);
	rr_CI = cats(round(rr365_LCL,0.01), ", ", round(rr365_UCL, 0.01));
run;









