/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 16_st_mi_hf_comb_boot.sas
	DESCRIPTION: Summarize the RR and RD estimates output via bootstrapping among the cohort
	of patients with at least 1 hospitalization for stroke, mi, or hf in the 12 months prior to
	cohort entry.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10


*************************************************************************************************/





/************************************************************************************************

TABLE OF CONTENTS:

	00 - SET UP
	01 - FORMAT DATASET
	02 - SUMMARIZE BOOTSTRAPPED ESTIMATES

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

%setup(full, 19b_injury_comb_boot, saveLog=N);
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





/**********************************************************************************
						02 - SUMMARIZE BOOTSTRAPPED ESTS
**********************************************************************************/





*(1) Injury or poisoning;

***
IPTW
***;

*Figure out the number of rows;
/*proc contents data=ana.injury_365_boot; */
/*run;*/
*500 - it's done running;

*Calculate the study estimates;
%calculate_est(inds=ana.injury_365_boot, outds=injury_summary, fup=365, rd_multiple=1000);
data ana.injury_summary; set ana.injury_summary; 
	variable = "Injury or Poisoning"; run;


**
Combine the estimates into one dataset
**;


****
	With IPTW
*****;


proc sql;
	create table injury_365_est_iptw as
	select * from ana.injury_summary
	;
	quit; 

data ana.injury_365_est_iptw (keep = risk0 risk0_CI risk1 risk1_CI
				rd rd_CI rr rr_ci rd_multiple variable);
set injury_365_est_iptw;
	risk0 = round(risk0_365, 0.01);
	risk0_CI = cats(round(risk0_365_LCL, 0.01), ", ", round(risk0_365_UCL,0.01));
	risk1 = round(risk1_365, 0.01);
	risk1_CI = cats(round(risk1_365_LCL, 0.01), ", ", round(risk1_365_UCL,0.01));
	rd = round(rd365, 0.01);
	rd_CI = cats(round(rd365_LCL,0.01), ", ", round(rd365_UCL, 0.01));
	rr = round(rr365, 0.01);
	rr_CI = cats(round(rr365_LCL,0.01), ", ", round(rr365_UCL, 0.01));
run;



