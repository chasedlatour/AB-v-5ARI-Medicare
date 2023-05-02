
/*****************************************************************************************************

PROJECT:		Alpha-Blocker Treatment for BPH
PROGRAM: 		icd9_10_outcome_check
DESCRIPTION: 	Get monthly prevalence estimates for the study outcomes and compare prevalence
				before and after the ICD-9 to -10 transition.
				This is modeled on work by Emilie Duchesneau for the Faurot Frailty Index.

CREATED BY:		Chase Latour
DATE CREATED:	2022 SEPT 09

DATE UPDATED:

TRAJECTORY:		(1) Define a cohort of patients who were enrolled in Medicare continuously for at
				least 30 days over 2014, 2015, and 2016.
				(2) Define the outcome variables in this population.
				(3) Calculate monthly prevalence estimates for each of the outcomes that are defined
				by ICD-9 and 10 codes across the transition.

*****************************************************************************************************/



/*----------------------------------------------------------------------------------------------*/
/*										TABLE OF CONTENTS										*/
/*----------------------------------------------------------------------------------------------*/
/*	00		SETUP																				*/
/*	01		GET DATASET WITH ALL DIAGNOSES DURING YEARS OF INTEREST								*/
/*	02		MERGE WITH ENROLMENT INFORMATION AND RESTRICT TO FFS								*/
/*	03		GET MONTHLY PREVALENCE ESTIMATES													*/
/*	04		GET MONTHLY PREVALENCE ESTIMATES (STANDARDIZING BY AGE/SEX)							*/
/*	05		CREATE FIGURES																		*/
/*----------------------------------------------------------------------------------------------*/




/*----------------------------------------------------------------------------------------------*/
/*	00		SETUP																				*/
/*----------------------------------------------------------------------------------------------*/

options source source2 msglevel=I mprint mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, icd9_10_outcome_check, saveLog=N);

/*%setup(1pct, icd9_10_outcome_check, saveLog=N);*/


*Set up local mirrors of the libraries;
/*libname lraw 		slibref=raw 	server=server;*/
/*libname lwork 		slibref=work 	server=server;*/
/*libname lder 		slibref=der 	server=server;*/
/*libname lout 		slibref=out		server=server;*/
/*libname lexpref 	slibref=expref 	server=server;*/
/*libname lcovref 	slibref=covref 	server=server;*/
/*libname loutref		slibref=outref 	server=server;*/

*Specify the years that going to look at
	For 9-10 transition, that's just 2014-2016;
%LET startyr=2013;
%LET endyr=2017;





/*----------------------------------------------------------------------------------------------*/
/*	01		GET DATASET WITH ALL DIAGNOSES DURING YEARS OF INTEREST								*/
/*----------------------------------------------------------------------------------------------*/

*Create dataset of all diagnosis codes during years of interest;
*Need to check on this from Virginia -- we do not have any claims for years >2015 -- are ICD10 codes missing???;
data alldx; set der.alldx (where=(&startyr.<=claimyear<=&endyr. and source='MedPar' and dxLoc_Claim in: (1 2) ))
				der.alldx102015 (rename=(dx2015=dx) where=(&startyr.<=claimyear<=&endyr. and source='MedPar' and dxLoc_Claim in: (1 2)))
				der.alldx102016 (rename=(dx2016=dx) where=(&startyr.<=claimyear<=&endyr. and source='MedPar' and dxLoc_Claim in: (1 2)))
				der.alldx102017 (rename=(dx2017=dx) where=(&startyr.<=claimyear<=&endyr. and source='MedPar' and dxLoc_Claim in: (1 2))) ; 
run;



*Create a list of all the codes that interested in;

*Diagnosis codes;
%let component_list=hf mi stroke;
%macro condition_dx(list=&component_list.);
	%do i=1 %to %sysfunc(countw(&list.));
		%let component=%scan(&component_list.,&i.);
		%global &component._icd9dx &component._icd10dx &component._icd9pr &component._icd10pr &component._cpt;
		proc sql noprint;
			select quote(trim(code)) into :&component._icd9dx separated by ' ' 
			from outref.&component._icd9dx;  
/*			select quote(trim(icd10dx)) into :&component._icd10 separated by ' ' */
/*			from covref.&component._dx_fbm_final; */
			/*Update the code here to use the new ICD10 code lists*/
			select quote(trim(code)) into :&component._icd10dx separated by ' ' 
			from outref.&component._icd10dx; 
		quit; 
		%put &&&component._icd9dx..; %put &&&component._icd10dx..;
	%end;
%mend;
%condition_dx;



*Now create flags for each of those variables;
data dx_components;
	format dx_dt date9. codetype best12.;
	set alldx (rename=(from_dt=dx_dt));

	*Heart failure;
		hf = dx in: (&hf_icd9dx. &hf_icd10dx.);
		if dx in: (&hf_icd9dx.) then codetype=9;			if dx in: (&hf_icd10dx.) then codetype=10;

	*Myocardial infarction;
		mi = dx in: (&mi_icd9dx. &mi_icd10dx.);
		if dx in: (&mi_icd9dx.) then codetype=9;			if dx in: (&mi_icd10dx.) then codetype=10;

	*stroke;
		stroke = dx in: (&stroke_icd9dx. &stroke_icd10dx.);
		if dx in: (&stroke_icd9dx.) then codetype=9;		if dx in: (&stroke_icd10dx.) then codetype=10;
 
run;

/*proc freq data=dx_components; tables codetype; run;*/



/*----------------------------------------------------------------------------------------------*/
/*	02		MERGE WITH ENROLMENT INFORMATION AND RESTRICT TO FFS								*/
/*----------------------------------------------------------------------------------------------*/
proc sql;
	create table enrollment_dx as
	select distinct a.bene_id, a.sex, a.dob, max(a.abstartdt, "01JAN&startyr."d) as abstartdt format=date9., min(abenddt, "31DEC&endyr."d) as abenddt format=date9.,
					b.codetype, month(b.dx_dt) as dx_mo, year(b.dx_dt) as dx_yr, 12*(calculated dx_yr - &startYr) + calculated dx_mo as month_counter,
					b.hf, b.mi, b.stroke
	from der.enrlper_ab as a 
	left join dx_components as b
	on a.bene_id=b.bene_id & a.abstartdt<=b.dx_dt<=a.abenddt
	group by a.bene_id
	having abstartdt<abenddt
	order by bene_id, abstartdt, month_counter;
quit;
/*proc freq data=enrollment; tables month_counter/missing; run;*/




/*----------------------------------------------------------------------------------------------*/
/*	03		GET MONTHLY PREVALENCE ESTIMATES													*/
/*----------------------------------------------------------------------------------------------*/


*Create monthly dataset for everyone;
proc sort data=enrollment_dx out=__enroldedup (keep=bene_id sex dob abstartdt abenddt) nodupkey; by bene_id abstartdt abenddt; run;
* this makes an enrollment dataset where each row is a unique enrollment period;

data monthly_enrl (drop=abstartdt abenddt);
	set __enroldedup;
	by bene_id abstartdt;
	startenrl=12*(year(abstartdt)-&startyr.) + month(abstartdt);
	endenrl=12*(year(abenddt)-&startyr.) + month(abenddt);

	do m=startenrl to endenrl;
		output;
	end;
run;


*Now actually calculate the prevalence;

%let dx_components=hf mi stroke;
%put &dx_components.;
%macro prevalence(list, file);
	*Loop through each component;
	%do i=1 %to %sysfunc(countw(&list.));
		%let component=%scan(&list.,&i.);
		*Restrict to individuals who have any estimated prevalence at any time;
		data _&component._collapsed /*(drop=hf--stroke)*/;
			set &file. (where=(&component.>0));
			proc sort nodupkey; 
				by bene_id abstartdt abenddt month_counter codetype; 
		run;

		*Create monthly datafile for each month the person is enrolled in Medicare, flag the prevalence as 1 if the person has a diagnosis
			code for the component of interest and flag prevalence as 0 for all other months;
		data _&component._bymonth (keep=bene_id m prevalence type rename=(prevalence=prev_&component.));
			set _&component._collapsed;
			by bene_id abstartdt;

			retain lastmonth;
			startenrl=12*(year(abstartdt)-&startyr.) + month(abstartdt);
			endenrl=12*(year(abenddt)-&startyr.) + month(abenddt);

			*For the first line for each person in our dataset;
			if first.abstartdt then do;
				*Month counter is missing when individual had no claims for the conditions of interest during their entire enrollment period;
				if month_counter ne . & month_counter>startenrl then do;
					*Output nonrecords for the months preceeding the first diagnosis;
					do m=startenrl to (month_counter-1);
						prevalence=0; type=.; output;
					end;
					*Output record for first month with a diagnosis and set lastmonth to the month with first diagnosis;
					m=month_counter; prevalence=1; type=codetype; output;
				end;
				*If they have a claim in the first month thn set prevalence to 1 and output;
				else if month_counter ne . & month_counter=startenrl then do;
					m=month_counter; prevalence=1; type=codetype; output;
				end;
/*				*For people with no diagnoses for the entirety of the study period, output non-records for every month of enrollment;*/
/*				else if month_counter=. then do;*/
/*					do m=startenrl to endenrl;*/
/*						prevalence=0; output;*/
/*					end;*/
/*				end;		*/
			end;
			
			*If it is not the first line for each person in the dataset;
			else do;
				*Output non-records for months between diagnoses;
				if month_counter>lastmonth then do m=lastmonth+1 to (month_counter-1);
					prevalence=0; type=.; output;
				end;
				*Output records for the next month with a diagnosis;
				m=month_counter; prevalence=1; type=codetype; output;
			end;

			*Output all records for months after the last diagnosis;
			if (last.abstartdt & month_counter ne . & lastmonth ne endenrl) then do m=(month_counter+1) to endenrl;
				prevalence=0; type=.; output;
			end;

			lastmonth=month_counter;
		run;

		proc sql;
			create table _&component._mrg as
			select distinct a.*, b.prev_&component., b.type, ceil(a.m/12) + &startyr. - 1 as year, mod(a.m,12) as month_temp, case when calculated month_temp=0 then 12 else calculated month_temp end as month,
							mdy(calculated month, 1, calculated year) as date format=date9.
			from monthly_enrl as a 
			left join _&component._bymonth as b
			on a.bene_id=b.bene_id & a.m=b.m;
		quit;

		proc sql;
			create table out.prev_&component. as 
			select distinct date, count(*) as denominator, 
							sum(case when type=9 then 1 else 0 end) as numerator_icd9,
							sum(case when type=10 then 1 else 0 end) as numerator_icd10,
							sum(case when type=0 then 1 else 0 end) as numerator_hcpcs,
							(calculated numerator_icd9 / calculated denominator)*100 as prop_icd9,
							(calculated numerator_icd10 / calculated denominator)*100 as prop_icd10,
							(calculated numerator_hcpcs / calculated denominator)*100 as prop_hcpcs
			from _&component._mrg
			group by date
			order by date;
		quit;


	%end;

%mend;
%prevalence(&dx_components., enrollment_dx);




/*----------------------------------------------------------------------------------------------*/
/*	04		GET MONTHLY PREVALENCE ESTIMATES (STANDARDIZING BY AGE/SEX)							*/
/*----------------------------------------------------------------------------------------------*/


*Haven't done this yet. Don't know if we need to.

Emilie did not find this to make much of a difference, so we are not going to do this
for simplicity. Don't anticipate many changes in the 5 years that we're looking at;



/*----------------------------------------------------------------------------------------------*/
/*	05		CREATE FIGURES																		*/
/*----------------------------------------------------------------------------------------------*/


%let component_list=hf mi stroke;
%let component_list_full=Heart failure, Myocardial infarction, Stroke;
options mprint;
%macro indicator_figures(list=&component_list., full_list=&component_list_full., type= /*either sprev or prev depending on whether used standardizaiton*/);
	footnote1;
	footnote2;
	title;
	title2;
	%if &type.=sprev %then %let var=sprop; %else %let var=prop;

	%do i=1 %to %sysfunc(countw(&list.));
		%let component=%scan(&component_list.,&i.);
		%let full=%scan(%bquote(&full_list.), &i., %str(,));
/*		%put &full.;*/
		ods graphics on /reset imagename="&component._incid_final_&type.";
		/*%let title=%sysfunc(propcase(&component.)); %put &title.;*/
		proc sgplot data=out.&type._&component. pad=(left=10) noautolegend; 
			format date year4. &var._icd9 comma10.1 &var._icd10 comma10.1;
/*		  	title "Prevalence from &startyr. to &endyr.";*/
		   	title "&full.";
/*			%if &type.=sprev %then title2 "Standardized by age and sex";;*/
		   	series x=date y=&var._icd9 /name="a" legendlabel= "ICD-9" lineattrs=(color=salmon pattern=solid thickness=2);
		   	series x=date y=&var._icd10 /name="b" legendlabel= "ICD-10" lineattrs=(color=vibg pattern=solid thickness=2);
		   	refline 20362 / axis=x lineattrs=(color=black thickness=3);
/*		   	keylegend "a" "b" "c"/location=outside position=bottom across=1 down=3 noborder;*/
		   	xaxis label="Year" values=(19359 to 21235 by 365.25) labelattrs=(size=14)/*label="Time"*/;
		   	yaxis label="Monthly period prevalence (%)" min=0 valuesformat=comma5.2 /*comma10.1*/ /*label="Monthly prevalence"*/;
		   	*xaxis min=&startYear. max=&endYear.;
		run;
	%end;
%mend;

%indicator_figures(type=prev);















/**********************Old code*****/

*Had previously written out some code to run this on procedure codes
but learned from Michele that we should actually only be looking at CPT
codes in teh Carrier file, not the hospital procedure codes.
So, don't need to ICD 9 to 10 map.;

*Create list of all procedure codes - didn't end up using this;
/*proc freq data=der.alldx (where = (source = 'MedPar')); tables source dxloc_claim; run;*/

/*data allpr; set der.allicd9_proc (where= (&startyr.<=claimyear<=&endyr.))*/
/*				der.allicd10_proc2015 (where=(&startyr.<=claimyear<=&endyr.))*/
/*				der.allicd10_proc2016 (where=(&startyr.<=claimyear<=&endyr.));*/
/*run;*/

*Create dataset of all diagnosis codes during years of interest;

*Only interested in those in the primary and secondary position on the inpatient claim.;

*Create a dataset of all in-patient procedure codes;

/*PROC SQL ;*/
/*	CREATE TABLE all_inp_claims AS*/
/*	SELECT **/
/*	FROM raw.medpar_all_file2014*/
/*	UNION */
/*	SELECT **/
/*	FROM raw.medpar_all_file2015*/
/*	UNION*/
/*	SELECT **/
/*	FROM raw.medpar_all_file2016*/
/*	;*/
/*	QUIT;*/


*Make each row represent a diagnosis code;
/*proc sort data=all_inp_claims out = all_inp_claims_sort;*/
/*	by bene_id admsndt;*/
/*run;*/
/*proc transpose data=all_inp_claims_sort out=out.all_inp_dx12_1416 prefix=dx;*/
/*	by bene_id admsndt;*/
/*	var dgnscd1 dgnscd2;*/
/*run;*/


*Procedure codes;
/*%let component_list=cabg pcip;*/
/*%macro condition_pr(list=&component_list.);*/
/*	%do i=1 %to %sysfunc(countw(&list.));*/
/*		%let component=%scan(&component_list.,&i.);*/
/*		%global &component._icd9pr &component._icd10pr;*/
/*		proc sql noprint;*/
/*			select quote(trim(code)) into :&component._icd9pr separated by ' ' */
/*			from outref.&component._icd9p; */
/*			select quote(trim(code)) into :&component._icd10pr separated by ' ' */
/*			from outref.&component._icd10p; */
/*			select quote(trim(code)) into :&component._cpt separated by ' ' */
/*			from outref.&component._cpt; */
/*		quit; */
/*		%put &&&component._icd9pr..; %put &&&component._icd10pr..;*/
/*		%put &&&component._cpt..;*/
/*	%end;*/
/*%mend;*/
/*%condition_pr;*/


*****Now do procedure codes

/*Currently not looking at CPT codes because only looking at inpatient claims.;*/
/**/
/*PROC SQL ;*/
/*	CREATE TABLE all_inp_claims AS*/
/*	SELECT **/
/*	FROM raw.medpar_all_file2014*/
/*	UNION */
/*	SELECT **/
/*	FROM raw.medpar_all_file2015*/
/*	UNION*/
/*	SELECT **/
/*	FROM raw.medpar_all_file2016*/
/*	;*/
/*	QUIT;*/


*Make each row represent a diagnosis code;
/*proc sort data=all_inp_claims out = all_inp_claims_sort;*/
/*	by bene_id admsndt;*/
/*run;*/
/**/
/**Make each row represent a procedure code;*/
/*proc transpose data=all_inp_claims_sort out=all_inp_proc_long prefix=prcdrcd;*/
/*	by bene_id admsndt;*/
/*	var prcdrcd1 - prcdrcd25;*/
/*run;*/

*Make each row represent a procedure code date;
/*proc transpose data=all_inp_claims_sort out=all_inp_procdt_long prefix=prcdrdt;*/
/*	by bene_id admsndt;*/
/*	var prcdrdt1 - prcdrdt25;*/
/*run;*/
/**/
/**Merge the two datasets together;*/
/*data all_inp_pr_dt;*/
/*	format prcdrdt date9.;*/
/*	merge all_inp_proc_long all_inp_procdt_long;*/
/*	by bene_id admsndt;*/
/*run;*/



*Now create flags for each of those variables;
/*data out.pr_inp_components;*/
/*	format admsndt date9. codetype best12.;*/
/*	set all_inp_pr_dt;*/
/**/
/*	*CABG;*/
/*		cabg = (prcdrcd1 in: (&cabg_icd9pr. &cabg_icd10pr.));*/
/*		if prcdrcd1 in: (&cabg_icd9pr.) then codetype=9;			if prcdrcd1 in: (&cabg_icd10pr.) then codetype=10;*/
/**/
/*	*PCI;*/
/*		pcip = prcdrcd1 in: (&pcip_icd9pr. &pcip_icd10pr.);*/
/*		if prcdrcd1 in: (&pcip_icd9pr.) then codetype=9;			if prcdrcd1 in: (&pcip_icd10pr.) then codetype=10;*/
/* */
/*run;*/
/**/
/*proc print data=out.pr_inp_components (obs=10);*/
/*	where cabg = 1 or pcip = 1;*/
/*run;*/

/*proc freq data=pr_inp_components; tables codetype; run;*/




/*Merge with enrollment*/
/*proc sql;*/
/*	create table enrollment_inp_pr as*/
/*	select distinct a.bene_id, a.sex, a.dob, max(a.abstartdt, "01JAN&startyr."d) as abstartdt format=date9., min(abenddt, "31DEC&endyr."d) as abenddt format=date9.,*/
/*					b.codetype, month(b.prcdrdt1) as pr_mo, year(b.prcdrdt1) as pr_yr, 12*(calculated pr_yr - 2014) + calculated pr_mo as month_counter,*/
/*					b.cabg, b.pcip*/
/*	from der.enrlper_ab as a */
/*	left join out.pr_inp_components as b*/
/*	on a.bene_id=b.bene_id & a.abstartdt<=b.prcdrdt1<=a.abenddt*/
/*	group by a.bene_id*/
/*	having abstartdt<abenddt*/
/*	order by bene_id, abstartdt, month_counter;*/
/*quit;*/





*Create monthly dataset for everyone;
/*proc sort data=enrollment_inp_pr out=__enroldedup_inp_pr (keep=bene_id sex dob abstartdt abenddt) nodupkey; by bene_id abstartdt abenddt; run;*/
/** this makes an enrollment dataset where each row is a unique enrollment period;*/
/**/
/*data monthly_enrl_inp_pr (drop=abstartdt abenddt);*/
/*	set __enroldedup_inp_pr;*/
/*	by bene_id abstartdt;*/
/*	startenrl=12*(year(abstartdt)-&startyr.) + month(abstartdt);*/
/*	endenrl=12*(year(abenddt)-&startyr.) + month(abenddt);*/
/**/
/*	do m=startenrl to endenrl;*/
/*		output;*/
/*	end;*/
/*run;*/
/**/
/**/
/****Now do the calculations for procedures;*/
/*%let pr_components=cabg pcip;*/
/*%put &pr_components.;*/
/**/
/*%prevalence(&pr_components., enrollment_inp_pr);*/






