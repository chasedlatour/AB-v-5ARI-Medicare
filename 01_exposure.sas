/**************************************************************************************/
/* Project: Alpha-Blocker Treatment for BPH                                                  */
/* Program: /mnt/files/projects/medicare/ablocker/programs/01_exposure.sas */
/* Copied from incretinCRC project directory on 9/30/2015                             */
/* Adapted from example provided by Virginia above									  */
/*                                                                                    */
/* Updates: Took out grace period for now because at-present considering ITT analysis */
/* Updates: included exclusion/inclusion criteria                                     */
/* Updates:                        */
/*                                                                                    */
/* Objective: Create the following new user cohort                                    */
/*                                                                                    */
/*     (1) A-blocker (all) vs 5-a reductase inhibitors: 365 days washout   			  */
/*     (2) A-blocker (specific) vs 5-a reductase inhibitors: 365 days washout   	  */
/*     (3) A-blocker (specific) vs both drugs: 365 days washout                       */
/*     (4) A blocker (specific) vs combination therapy: 365 days washout              */
/*                                                                                    */
/*	Trajectory:																		  */
/*	- Define these new-user cohorts													  */
/*	- Identify those people with BPH & provide Table 1								  */
/*	- Investigate treatment switching -- Come back to this piece					  */
/*                                                                                    */
/* Analysis Notes:																	  */
/*                                                                                    */
/* Updates:                                                                           */
/*   10/19/22 - added RTI_RACE variable (added to dataset via addon program, added    */
/*              here to incorporate in future runs)                                   */
/**************************************************************************************/
/*SIGNOFF;
%LET server=n2.schsr.unc.edu 1234;options comamid=tcp remote=server;signon username=_prompt_;
*/

options source source2 msglevel=I mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, 01_exposure, saveLog=Y)

*Map local mirrors for all remote libraries using LOCAL SUBMIT (plain ol' running man button, or F3);
*libname ldata slibref=raw server=server;
*libname lder slibref=der server=server; *Look at the derived data files;
*libname loutlab3 slibref=outlab3 server=server;
*libname lwork slibref=work server=server;
*libname lexpref slibref=expref server=server;

%LET startYear=2007; /*Changed to 2007 now interested in all available years */
%LET endYear=2019;

/*proc contents data=raw.pde_saf_file2017; run;*/
/*proc contents data=expref.allcodes10; run;*/


/*Step 1: Get all RX claims*/

%macro allRX(startyr=&startYear, endyr=&endYear, update=N);
   proc sql;
      create table allclaims as
      select distinct a.bene_id, a.srvc_dt, a.gnn, a.atc, 
	  			a.ab_sel, a.ab_nsel, a.ar5, a.comb,
			 /*a.compound,a.glp, a.dpp, a.su, a.tzd, a.lai,*/
             max(a.dayssply) as dayssply, /*Virginia: What is the max() doing here?*/
             max('01JAN2007'd, b.abdanystartdt) as startEnrol format=date9. label='Start of ABD Continuous Enrollment', 
             min(b.abdanyendDT, b.death_dt) as endPartD format=date9. label='End of ABD Continuous Enrollment'
      from (/*Stack all fills across all years*/
           %DO i=&startyr %TO &endyr;
                 select distinct p.bene_id, p.srvc_dt, p.dayssply, g.atc_label as gnn, g.atc,
                    g.ab_sel, g.ab_nsel, g.ar5, g.comb
                 from raw.pde_saf_file&i as p inner join expref.allcodes9 as g
                 on substr(p.prdsrvid,1,9) = g.ndc9
            %IF &i < &endyr %THEN union all corresponding ;
            %END;
        ) as a inner join der.enrlper_abdany as b
             on a.bene_id = b.bene_id and b.abdanystartDT <= a.srvc_dt <= min(b.abdanyendDT, b.death_dt)
			where b.sex='1'
     group by a.bene_id, a.srvc_dt, a.gnn
       order by a.bene_id, a.srvc_dt
      ;
   quit;
%mend allRX;
%allRX;

Title "Unique beneficiaries with at least fill of interest";
proc sql;
	select 
		count(distinct bene_id) as overall format=comma12.0 label='Any Fill',
		count(distinct case when ab_sel=1 then bene_id else '' end) as ab_sel format=comma12.0 label='AB_SEL',
		count(distinct case when ab_nsel=1 then bene_id else '' end) as ab_nsel format=comma12.0 label='AB_NSEL',
		count(distinct case when ar5=1 then bene_id else '' end) as ar5 format=comma12.0 label='AR5',
		count(distinct case when comb=1 then bene_id else '' end) as comb format=comma12.0 label='COMB'
	from allclaims;
quit;


/* Step 2: Get periods of continuous use*/

%useperiods(grace=30, washout=365, wpgp=N, inds=%str(allclaims(where=(ab_sel=1))), idvar = bene_id,
startenroll=startEnrol, rxdate=srvc_dt, endenroll=endPartD, dayssup=dayssply, keepvars=gnn, outds=useperiods_ABSEL);

/* TO GET NEW DISCONTINUATION DATE WHEN RESTRICTING TO TAMSULOSIN, USE THIS CODE */
%useperiods(grace=30, washout=365, wpgp=N, inds=%str(allclaims(where=(ab_sel=1 and gnn='TAMSULOSIN'))), idvar = bene_id,
startenroll=startEnrol, rxdate=srvc_dt, endenroll=endPartD, dayssup=dayssply, outds=useperiods_tamsulosin);

*11,158 observations - are these distinct individuals or use periods?;
***Update 2015-2017 observations = 9,241;
***** updated (6/22/22) 2007-2017 observations = 19193

*This is only pulling 1 record?? - Sola noted that these are rarely used.;
%useperiods(grace=30, washout=365, wpgp=N, inds=%str(allclaims(where=(ab_nsel=1))), idvar = bene_id,
startenroll=startEnrol, rxdate=srvc_dt, endenroll=endPartD, dayssup=dayssply, keepvars=gnn, outds=useperiods_ABNSEL);
*1 observation;

%useperiods(grace=30, washout=365, wpgp=N, inds=%str(allclaims(where=(ar5=1))), idvar = bene_id,
startenroll=startEnrol, rxdate=srvc_dt, endenroll=endPartD, dayssup=dayssply, keepvars=gnn, outds=useperiods_AR5);
*3,793 observations;
***Update 2015-2017 N = 3,159;
*****updated (6/22/22) 2007-2017 N = 7162; 

%useperiods(grace=30, washout=365, wpgp=N, inds=%str(allclaims(where=(comb=1))), idvar = bene_id,
startenroll=startEnrol, rxdate=srvc_dt, endenroll=endPartD, dayssup=dayssply, keepvars=gnn, outds=useperiods_COMB);
*107 observations;
**Update 2015-2017 N = 80;
**** updated (6/22/22) 2007-2017 N= 208; 


data useperiods_all; 
	set useperiods_absel(in=a) useperiods_abnsel(in=b) useperiods_ar5(in=c) useperiods_comb(in=d); 
	absel=a; abnsel=b; ar5=c; comb=d;
run;
proc sql; 
	Title 'Benes with at least one fill';
	select count(distinct bene_id) from useperiods_all;

	title 'Benes with at least one fill that qualifies as new use within drug class';
	title2 '(e.g., not a prevalent user at database entry)';
	select count(distinct bene_id) from useperiods_all where newuse=1;
quit;

/* Step 3: Determine periods of new use for each of the comparisons to be made:  */
/* (1) Alpha Blocker - Selective vs 5-Alpha Reductase Inhibitor  */
%macro newuse(drug1, drug2, gp=30, wp=365);
   proc sql;
      create table new&drug1.(drop=newuse reason1 useperiod) as
      select /* Check for comparator fill during follow-up -- censor at comparator fill date */
         distinct a.*, 
            min(b.indexdate) as switchAugmentDate format=date9. label='Date of Drug Switch/Augmentation'
      from (/* Check for comparator fill prior to 2nd fill date -- flag dual initiators, prevalent users, and those with only 1 fill*/
         select distinct a.*, 
            max(a.indexdate - &wp <= b.discontDate and b.indexdate < a.indexdate) as excludeFlag_prevalentUser label='EXCLUSION FLAG: Prevalent User of Comparator Drug',
            max(a.indexdate = b.indexdate) as excludeFlag_sameDayInitiator label='EXCLUSION FLAG: Dual Initiator of Comparator Drugs',
            max(a.indexdate < b.indexdate <=  a.filldate2) as excludeFlag_preFill2Initiator label='EXCLUSION FLAG: Pre-second fill initiator'
     

         from useperiods_&drug1.(where=(newuse=1) rename=(reason=reason1)) as a 
            left join useperiods_&drug2. as b on a.bene_id = b.bene_id
         group by a.bene_id, a.indexdate) as a 
      left join useperiods_&drug2. as b 
         on a.bene_id = b.bene_id and a.indexdate <= b.indexdate <=  a.discontdate
      group by a.bene_id, a.indexdate 
      order by bene_id, indexdate;
   quit; 
%mend;

%macro getCohort(drug1, drug2);
   %newuse(&drug1., &drug2.)
   %newuse(&drug2., &drug1.)

   data newusers_&drug1.v&drug2. (sortedby=bene_id indexdate);
      set new&drug1.(in=a) new&drug2.;
      by bene_id indexdate;
      &drug1.=a; 
      label &drug1. = "Drug Class: 1=&drug1., 0=&drug2.";
   run;
%mend;
options mprint;

%getCohort(absel, ar5);
/*%getCohort(ar5, absel);*/





/*
NOTE: There were 1936 observations read from the data set WORK.NEWAR5.
NOTE: There were 5490 observations read from the data set WORK.NEWABSEL.
NOTE: The data set WORK.NEWUSERS_AR5VABSEL has 7426 observations and 15 variables.
*/
*****Updated Numbers: 526 Observations in WORK.NEWAR5 
					  1651 in WORK.NEWABSEL
					  2177 in WORK.NEWUSERS_AR5VABSEL;


******Update Numbers (06/22/22): 2194 observations in Work.NEWAR5
								 6071 observations in WORK.NEWABSEL
								 8265 Observations in Newusers_ar5vabsel and 15 variables;
/*************** STEP 4: APPLY ADDITIONAL EXCLUSION CRITERIA **************/
/*4a*/
/* age > 65 on indexdate and those with at least 12 months of coverage and include censor date */
proc sql;
   create table out.cohortDS as
      select a.*, b.race, b.rti_race, b.sex, floor((a.indexdate-b.dob)/365.25) as age label='Age at Index Date', 
             b.death_dt format=date9. label='Date of Death',
             b.abenddt as endDT_ITT format=date9. label='End of AB Enrollment',
			min(b.abenddt, b.death_dt) as censorDate_ITT format=date9. label='ITT Censor Date'
      from (
				(select a.*, 1 as ab label='AB initiator', b.discontDate as discontDate_tamsolusin format=date9.
						from newabsel as a left join useperiods_tamsulosin as b on a.bene_id=b.bene_id and a.indexdate=b.indexdate)
              union all corresponding
              (select *, 0 as ab label='AR5 initiator', . as discontDate_tamsolusin format=date9. from newar5)
            ) as a
         left join der.enrlper_ab as b
            on a.bene_id=b.bene_id and b.abstartdt<=a.indexdate<=b.abenddt
      having age>65
      order by bene_id, indexdate;
quit;




Title "Unique beneficiaries with new use (>=365 days enrollment and no baseline comparator drug use)";
proc sql;
	select 
	count(distinct bene_id) as overall format=comma12.0 label='Any Fill',
	count(distinct case when ab=1 then bene_id else '' end) as absel format=comma12.0 label='ABSEL',
	count(distinct case when ab=0 then bene_id else '' end) as ar5 format=comma12.0 label='AR5'
	from out.cohortDS
where (excludeFlag_prevalentUser=0) or (excludeFlag_sameDayInitiator = 0) or (excludeFlag_preFill2Initiator = 0) ;
quit;


/*
NOTE: The data set WORK.NEWUSERS has 7186 observations and 20 variables.
		It includes beneficiaries with index date >= 66 years. */

***UPDATE: 2067 obs with 20 variables;
*****updated (06/22/22): 7879 obs with 20 variables;


/*4b*/
*This dataset is saved into the ablocker project folder;
/*DATA out.cohortDS;*/
/*	SET newusers;*/
/*	where sex='1';*/
/*RUN;*/

/*PROC CONTENTS DATA = out.cohortDS;*/
/*RUN;*/
*Note: The data set WORK.NEWUSERS has 2067 observations and 20 variables, while out.cohortds has 7019 with 20 variables restricted to men;



























/*****Old codes;*/
/*/*Updated code*/*/
/*/* STEP 1: Get all RX claims */*/
/*/*%macro allRX(startyr=&startYear, endyr=&endYear, update=N);*/
/*   proc sql;*/
/*      create table allclaims as*/
/*      select distinct a.bene_id, a.srvc_dt, a.gnn, a.atc, */
/*	  			a.ab_sel, a.ab_nsel, a.ar5, a.comb,*/
/*			 /*a.compound,a.glp, a.dpp, a.su, a.tzd, a.lai,*/*/
/*             max(a.dayssply) as dayssply, /*Virginia: What is the max() doing here?*/ */
/*			 /*Virginia said consider changing this to sum rather than max, and using ndc codes instead of gnn incase some indiviuals are filling more than one in a day*/
/*			 Like in depression meds were doses are being uptritrated, we can ask clinicians if this something we expect to see here*/*/
/*             max("01JAN&startYr"d, b.abdanystartdt) as startEnrol format=date9. label='Start of ABD Continuous Enrollment', */
/*             min(b.abdanyendDT, b.death_dt, "31DEC&endYr"d) as endPartD format=date9. label='End of ABD Continuous Enrollment'*/
/*      from (/*Stack all fills across all years*/*/
/*          /* %DO i=&startyr %TO &endyr;*/
/*                 select distinct p.bene_id, p.srvc_dt, p.dayssply, g.atc_label as gnn, g.atc,*/
/*                    g.ab_sel, g.ab_nsel, g.ar5, g.comb*/
/*                 from raw.pde_saf_file&i as p inner join expref.allcodes9 as g*/
/*                 on substr(p.prdsrvid,1,9) = g.ndc9*/
/*            %IF &i < &endyr %THEN union all corresponding ;*/
/*            %END;*/
/*        ) as a inner join der.enrlper_abdany as b*/
/*             on a.bene_id = b.bene_id and max("01JAN&startYr"d, b.abdanystartDT) <= a.srvc_dt <= min(b.abdanyendDT, b.death_dt, "31DEC&endYr"d)*/
/*     group by a.bene_id, a.srvc_dt, a.gnn*/
/*       order by a.bene_id, a.srvc_dt*/
/*      ;*/
/*   quit;*/
/*%mend allRX;*/
/*%allRX;*/*/

/*Step 2: Get periods of continuous use of each drug: AB_SEL, AB_NSEL, AR5, COMB*/

/*%macro useperiods(grace=, washout=, daysimp=, maxDays=,*/
/*                  inds=, idvar=bene_id, startenrol=startEnrol, rxdate=srvc_dt, endenrol=endPartD, dayssup=dayssply, */
/*                  group=, outds=, GPWP=N);*/

*DAYSIMP - Value to use for days supply if raw data has a value <= 0;



*Notes that we need to address:
- We need a combination of both 5-alpha reductase inhibitors and alpha blockers, with no prior use of either - New-use of
the both. -- If we look at both drugs, we need to consider a window where one can be started after the other. (30 days?);


*Is this identifying continued periods using generic name or compound?
- Do we even need this?

Decided not to run this one.;

/*%macro bylevel(drug, level);
   proc sql noprint; select distinct &level into :drug1-:drug200 from allclaims(where=(&drug=1)); quit;
   %LET N=&SqlObs;

   %DO d=1 %TO &N;
      %useperiods(grace=90, washout=365, daysimp=30,     
            inds=%str(allclaims(where=(&drug.=1 and &level="&&drug&d"))), outds=useperiods_&drug._&level._&d)
      data useperiods_&drug._&level._&d; set useperiods_&drug._&level._&d; length drug $100; drug="&&drug&d"; run;
   %END;
%mend;
%bylevel(drug=glp, level=gnn)
%bylevel(drug=dpp, level=gnn)

%bylevel(drug=glp, level=compound)
%bylevel(drug=dpp, level=compound)
*/










/*%getCohort(GLP, TZD)
%getCohort(GLP, LAI)*/


   
%macro byLevel2(drug, level);
   proc sql noprint; select distinct &level into :drug1-:drug200 from allclaims(where=(&drug=1)); quit;
   %LET N=&SqlObs;

   data useperiods_&drug._&level.; set %DO d=1 %TO &N; useperiods_&drug._&level._&d %END;; run;
   proc sql;
      create table &drug._&level. as select distinct a.bene_id, a.indexdate, 1 as &drug.,
         %DO d=1 %TO &N; max(a.indexdate=b.indexdate and b.drug="&&drug&d") as index_&level.&d label="Index Drug: &level &&drug&d", %END;
         min(case when a.indexdate<b.indexdate<=a.discontDate then b.indexdate else . end) as switchAugmentDate_&level format=date9.
      from useperiods_&drug._&level.(where=(newuse=1)) as a 
         left join useperiods_&drug._&level. as b
            on a.bene_id=b.bene_id and a.indexdate<=b.indexdate
      group by a.bene_id, a.indexdate
      order by bene_id, indexdate;
   quit;

   %IF &level=compound %THEN %DO;
      proc datasets lib=work nolist nodetails;
         modify &drug._&level;
            rename %DO d=1 %TO &N; index_&level.&d = index_&&drug&d %END;;
      run; quit;
   %END;
%mend;
/*%byLevel2(drug=glp, level=gnn)*/
/*%byLevel2(drug=dpp, level=gnn)*/
/**/
/*%byLevel2(drug=glp, level=compound)*/
/*%byLevel2(drug=dpp, level=compound)*/



%macro merge(drug1, drug2);
   proc sort data=newusers_&drug1.v&drug2.; by bene_id indexdate &drug1; run;
   data temp.newusers_&drug1.v&drug2.;
      merge newusers_&drug1.v&drug2.(in=a) &drug1._gnn &drug1._compound;
      by bene_id indexdate &drug1.;
      if a;
      label switchAugmentDate_gnn = "Date of first &drug1. fill OTHER than Index Generic Drug"
            switchAugmentDate_compound = "Date of first &drug1. fill OTHER than Index Compound";
   run;
%mend;
/*%merge(DPP, SU)*/
/*%merge(DPP, TZD)*/
/**/
/*%merge(GLP, TZD)*/
/*%merge(GLP, LAI)*/
/**/




			
