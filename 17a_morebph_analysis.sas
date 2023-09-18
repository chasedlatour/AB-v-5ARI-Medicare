/************************************************************************************************

	PROJECT: Alpha-Blockers & BPH
	PROGRAM: 15a_stroke_mi_hf_analysis.sas
	DESCRIPTION: The goal of this analysis is to replicate the primary analyses, restricted
	to those patients who had at least 2 outpatient or 1 inpatient diagnosis code for BPH.

	This code replicates the primary analysis without bootstrapping.

	CREATED BY: Chase Latour
	DATE CREATED: 2022 OCT 10

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

%setup(full, 17_morebph_analysis, saveLog=N);
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


*Restrict to those individuals with the baseline characteristics of-interest;
data ana.cohort_bph;
set ana.primary_cohort;
	
	where bl_1yrlb_bphwous_1in_2out = 1 OR bl_1yrlb_bphwus_1in_2out = 1; **MODIFY;

run;

*Dropped from 189,886 persons to 86,652 persons/new-use episodes;







/************************************************************************************************
										03 - FIT PS MODEL
************************************************************************************************/



*Build the propensity score model;
%ps(inds = ana.cohort_bph, outds = ps);



/************************************************************************************************
							04 - ASSESS FIT AND PLOT PS DISTRIBUTION

Trim the PS distributions across the two treatment groups.
************************************************************************************************/


*Look at a plot of the PSs;
ods graphics on / reset imagename="PS Distributions - Density - More BPH";
proc sgplot data=ps;
	title "Density - PS Distributions by Treatment Group in Restricted Exp Cohort";
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
ods graphics on / reset imagename="PS Distributions - Density - More BPH - Trimmed";
proc sgplot data=ps_trim;
	title "Density - PS Distributions by Treatment Group in the BPH Cohort with More Requirements After Trimming";
	*histogram ps / group = ab;
	density ps2 / group = ab type = kernel;
	keylegend / location=inside position = topleft;
run;






/************************************************************************************************
									05 - CALCULATE WEIGHTS
************************************************************************************************/

%iptw(inds = ps_trim, psds = ps_trim, outds = cohort_weights2, psvar=ps2);

*Calculate mean, max, and min of weights;
proc means data=cohort_weights2 max min mean;
	*class ab;
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
			bl_outpatientvisit bl_oxygen bl_wheelchair, contStat=median, smd_cat=level);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics_Trimmed_More BPH Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;





*Output the IPTW Table 1:

Can use table1 macro for weighted comparison;
proc sort data=cohort_weights2; by bene_id indexdate; run;
%table1(inds = cohort_weights2, maxLevels = 5, colVar = ab, rowVars = age cal_year rti_race
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
			bl_outpatientvisit bl_oxygen bl_wheelchair, wgtVar = iptw, contStat=median, smd_cat=level);

ods noptitle; ods escapechar='~';Title ;
ods rtf file="&OutPath./Table 1: Distribution of Study Baseline Characteristics with IPTW_Trimmed_More BPH Population_&logdate..rtf" style=vpmin startpage=never ;

      ods rtf text="~S={just=center outputwidth=100% font=('Arial',10PT,Bold)}
   Table 2: Study population characteristics, stratified by drug use";

   proc print data=final noobs label; var row total ab ar5 sdiff2; run;

ods rtf close;



