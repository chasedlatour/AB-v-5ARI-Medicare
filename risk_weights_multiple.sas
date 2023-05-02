/* INDS = input dataset name, must contain variables &IDVAR, &STARTDT, &EVENTDT, &CRDT, &CENSORDT 
          and all variables in &PSVARS and &DOVARS
/* STARTDT = variable name for date of start of follow-up
/* EVENTDT = variable name for date of outcome of interest
/* CRDT = variable name for date of competing risk event
/* CENSORDT = variable name for date of other censoring event

/* DAYSEST = time points (in days) to get estimates (must be listed in increasing order and separated by spaces)

/* PSVARS = list of variables to be included in the propensity score model (separated by spaces)
/* DOVARS = list of variables to be included in the dropout model (separated by spaces)
/* TRTVAR = treatment variable name (values=0,1)

/* NUMITERATIONS = number of iterations
/* INITIALSEED = optional parameter for initial seed (so results will be reporducible)
/*
/* OUTDS = name of output dataset, containing one record per iteration*/

/* correction log                  */
/*		9/16/2020 - 3 corrections in drop out weight calculations:   */
/*                1. outcome variables corrected in drop out weight step */
/*                2. drop out weight calculation corrected (inverse of weigts previously calculated) */
/*                3. corrected coding error in actual drop out weight calculation */

/*This version has been modified for the alpha-blockers analysis.*/


%macro risk_weights_multiple(inds=cohort, startDT=indexDate, censorDT=censorDT, 
      daysEst=365, psvars=age sex race, dovars=age sex race, classvars=sex race, trtvar=trt, 
      numiterations=1000, cohort=, noiptw=0);

*STEP 0: Parse macro variables;
   %LET numEst = %SYSFUNC(countw(&daysEst));
   %DO d=1 %TO &numEst; %LET est&d = %SCAN(&daysEst,&d); %END;

%PUT STEP 1: PREPARE ANALYTIC COHORT DATASET;
   data _anacohort /*(where = (days>0))*/; set &inds;
      * 1a: create analytic variables for time to event and outcome;
	  outcome_dt_mace = min(mi_date, stroke_date, death_dt);
	  outcome_dt_macehf = min(mi_date, stroke_date, death_dt, HF_date);
	  outcome_dt_death = death_dt;
   
      days_mace = min(outcome_dt_mace, &censorDT) - &startDT + 1;
	  days_macehf = min(outcome_dt_macehf, &censorDT) - &startDT + 1;
	  days_death = min(outcome_dt_death, &censorDT) - &startDT + 1;

      if .z<outcome_dt_mace<=min(&censorDT) then outcome_mace=1; else outcome_mace=0;
	  if .z<outcome_dt_macehf<=min(&censorDT) then outcome_macehf=1; else outcome_macehf=0;
	  if .z<outcome_dt_death<=min(&censorDT) then outcome_death=1; else outcome_death=0;
      *if .z<&crDT<=min(&censorDT,&eventDT-1) then comprisk=1; *else comprisk=0;

      *combined=max(outcome,comprisk);
      *if outcome=1 then event=1; *else if comprisk=1 then event=2; *else event=0;

      if days_mace>&&est&numEst then do; outcome_mace=0; *event=0; days_mace=&&est&numEst+1; end;
	  if days_macehf>&&est&numEst then do; outcome_macehf=0; days_macehf=&&est&numEst+1; end;
	  if days_death>&&est&numEst then do; outcome_death=0; days_death=&&est&numEst+1; end;
   run;


	*Runn the do loop over teh bootstraps;

   %DO i=1 %TO &numIterations;

   		%IF &i>1 %then options nomlogic nomprint nosymbolgen nonotes;;

		%put *********STARTING ITERATOIN 1 FOR OUTCOME &OUTCOME;

      %PUT STEP 2: CREATE BOOTSTRAP SAMPLES - This will be used for all outcomes;
      %LET seed = &i; *%SYSFUNC(floor(%SYSFUNC(ranuni(&initialseed))));
	  %PUT STEP 2: CREATE BOOTSTRAP SAMPLES;
      proc surveyselect noprint data=_anacohort out=_anacohort&i(rename=(replicate=b) drop=numberhits) 
         seed=&seed method=urs samprate=1 outhits rep=1;
		data _anacohort&i; set _anacohort&i; _id=_N_; run;

	  %PUT STEP 3a: CALCULATE FIRST PS MODEL FOR TRIMMING - PS model is agnostic of outcome so same for all;
 	  proc logistic data=_anacohort&i noprint; class &classVars; model &trtvar (reference="AR5")=&psvars; output out=_ps p=ps; run;

	  *STEP 3b: IDENTIFY NON-OVERLAP AND TRIM POPULATION;
	  %put STEP 3b: IDENTIFY NON-OVERLAP AND TRIM POPULATION;
	  *Calculate min & max PSs;
	  proc sort data=_ps; by &trtvar; run;
	  proc means data=_ps min max noprint;
	  	by &trtvar;
		var ps;
		output out=_sumstat min=minPS max=maxPS;
	  run;

	  *Apply min & max to opposite treatments;
	  data _sumstat2;
	  set _sumstat;
	  	if &trtvar=0 then jointo=1;
			else if &trtvar=1 then jointo=0;
	  run;

	  *Merge the datasets so that can remove people;
	  proc sql;
	  	create table _ps2 as
		select a.*, b.minPS, b.maxPS
		from _ps as a
		left join _sumstat2 as b
		on a.ab=b.jointo;
		quit;

	   *Indicate which values to delete & remove those individuals;
	  data _ps3 (where=(delete=0));
	  set _ps2;
	  	delete=0;
		if ab=0 & ps<=minPS then delete=1;
		if ab=1 & ps>=maxPS then delete=1;
	  run;


      %PUT STEP 3c: RE-FIT PS MODEL & CREATE IPT WEIGHTS;
      proc logistic data=_ps3 noprint; class &classVars; model &trtvar (reference="AR5")=; output out=_num(keep=_id n) p=n; run;
      proc logistic data=_ps3 noprint; class &classVars; model &trtvar (reference="AR5")=&psvars; output out=_den(keep=_id d) p=d; run;

	  proc sort data=_num; by _id; run;
	  proc sort data=_den; by _id; run;
      data __anacohort&i; 
         merge _anacohort&i _num _den; by _id; 
         if &trtvar then expwgt=n/d; else expwgt=(1-n)/(1-d); 
         keep _id &trtvar expwgt outcome_mace outcome_macehf outcome_death days_mace days_macehf days_death /*event*/ &dovars;
      run;

      %PUT STEP 4: CREATE DROP OUT WEIGHTS - Do one model for each outcome;

	  %PUT MACE outcomes;
	  data _anacohort_mace&i; set __anacohort&i /*_anacohort&i*/; where days_mace>0; run;
      proc univariate data=_anacohort_mace&i noprint; where outcome_mace=0; var days_mace;
         output out=_quintiles pctlpts=20 40 60 80 100 pctlpre=p; run;
      data _null_; set _quintiles; 
         call symputx('p20', p20); call symputx('p40',p40); call symputx('p60',p60); call symputx('p80',p80); 
		 call symputx('p100',p100);run;
      data ___anacohort_mace&i; set __anacohort&i(rename=(days_mace=days1_mace outcome_mace=outcome1_mace) where=(days1_mace>0) );
         array j{6} j1-j6 (0, &p20, &p40, &p60, &p80, &p100);
         do k=1 to 5;
            in=j(k);
            if j(k)<days1_mace<=j(k+1) then do; days_mace=days1_mace; if outcome1_mace=0 then drop=1; else drop=0; outcome_mace=outcome1_mace; output; end;
            else if j(k+1)<days1_mace then do; days_mace=j(k+1); drop=0; outcome_mace=0; output; end;
         end;
         keep _id in days_mace outcome_mace drop expwgt &trtvar &dovars;
      run;*9/16/2020 - corrected OUTCOME, COMPRISK and COMBINED variables in above step;

		*9/16/2020 - flipped denominator and numerator;
      proc logistic data=___anacohort_mace&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in; output out=num(keep=_id in dn) p=dn; run;
      proc logistic data=___anacohort_mace&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in &dovars; output out=denom(keep=_id in dd) p=dd; run;

      proc sort data=___anacohort_mace&i; by _id in; run;
      proc sort data=denom; by _id in; run;
      proc sort data=num; by _id in; run;

      data ____anacohort_mace&i; merge ___anacohort_mace&i denom num; by _id in;
         retain num denom lastNum lastDenom;

         if first._id then do; num=1; denom=1; end;
         else do; num=num*lastNum; denom=denom*lastDenom; end;

         lastNum=dn; lastDenom=dd;*9/16/2020 - corrected this ilne to use DN and DD rather than NUM and DENOM;
         dowgt = num / denom;
         wgt = expwgt * dowgt;
         keep _id &trtvar in days_mace outcome_mace wgt dowgt;
      run;
      proc datasets lib=work nolist nodetails; delete ___anacohort_mace&i; run; quit;

	*The people being dropped at this stage is because they do not have overlapping PS weights.;



	  %PUT MACE and HF outcomes;
	  data _anacohort_macehf&i; set __anacohort&i /*_anacohort&i*/; where days_macehf>0; run;
      proc univariate data=_anacohort_macehf&i noprint; where outcome_macehf=0; var days_macehf;
         output out=_quintiles pctlpts=20 40 60 80 100 pctlpre=p; run;
      data _null_; set _quintiles; 
         call symputx('p20', p20); call symputx('p40',p40); call symputx('p60',p60); call symputx('p80',p80); 
		 call symputx('p100',p100);run;
      data ___anacohort_macehf&i; set __anacohort&i(rename=(days_macehf=days1_macehf outcome_macehf=outcome1_macehf) where=(days1_macehf>0) );
         array j{6} j1-j6 (0, &p20, &p40, &p60, &p80, &p100);
         do k=1 to 5;
            in=j(k);
            if j(k)<days1_macehf<=j(k+1) then do; days_macehf=days1_macehf; if outcome1_macehf=0 then drop=1; else drop=0; outcome_macehf=outcome1_macehf; output; end;
            else if j(k+1)<days1_macehf then do; days_macehf=j(k+1); drop=0; outcome_macehf=0; output; end;
         end;
         keep _id in days_macehf outcome_macehf drop expwgt &trtvar &dovars;
      run;*9/16/2020 - corrected OUTCOME, COMPRISK and COMBINED variables in above step;

		*9/16/2020 - flipped denominator and numerator;
      proc logistic data=___anacohort_macehf&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in; output out=num(keep=_id in dn) p=dn; run;
      proc logistic data=___anacohort_macehf&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in &dovars; output out=denom(keep=_id in dd) p=dd; run;

      proc sort data=___anacohort_macehf&i; by _id in; run;
      proc sort data=denom; by _id in; run;
      proc sort data=num; by _id in; run;

      data ____anacohort_macehf&i; merge ___anacohort_macehf&i denom num; by _id in;
         retain num denom lastNum lastDenom;

         if first._id then do; num=1; denom=1; end;
         else do; num=num*lastNum; denom=denom*lastDenom; end;

         lastNum=dn; lastDenom=dd;*9/16/2020 - corrected this ilne to use DN and DD rather than NUM and DENOM;
         dowgt = num / denom;
         wgt = expwgt * dowgt;
         keep _id &trtvar in days_macehf outcome_macehf wgt dowgt;
      run;
      proc datasets lib=work nolist nodetails; delete ___anacohort_macehf&i; run; quit;

	*The people being dropped at this stage is because they do not have overlapping PS weights.;


	  %PUT DEATH outcomes;
	  data _anacohort_death&i; set __anacohort&i /*_anacohort&i*/; where days_death>0; run;
      proc univariate data=_anacohort_death&i noprint; where outcome_death=0; var days_death;
         output out=_quintiles pctlpts=20 40 60 80 100 pctlpre=p; run;
      data _null_; set _quintiles; 
         call symputx('p20', p20); call symputx('p40',p40); call symputx('p60',p60); call symputx('p80',p80); 
		 call symputx('p100',p100);run;
      data ___anacohort_death&i; set __anacohort&i(rename=(days_death=days1_death outcome_death=outcome1_death) where=(days1_death>0) );
         array j{6} j1-j6 (0, &p20, &p40, &p60, &p80, &p100);
         do k=1 to 5;
            in=j(k);
            if j(k)<days1_death<=j(k+1) then do; days_death=days1_death; if outcome1_death=0 then drop=1; else drop=0; outcome_death=outcome1_death; output; end;
            else if j(k+1)<days1_death then do; days_death=j(k+1); drop=0; outcome_death=0; output; end;
         end;
         keep _id in days_death outcome_death drop expwgt &trtvar &dovars;
      run;*9/16/2020 - corrected OUTCOME, COMPRISK and COMBINED variables in above step;

		*9/16/2020 - flipped denominator and numerator;
      proc logistic data=___anacohort_death&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in; output out=num(keep=_id in dn) p=dn; run;
      proc logistic data=___anacohort_death&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in &dovars; output out=denom(keep=_id in dd) p=dd; run;

      proc sort data=___anacohort_death&i; by _id in; run;
      proc sort data=denom; by _id in; run;
      proc sort data=num; by _id in; run;

      data ____anacohort_death&i; merge ___anacohort_death&i denom num; by _id in;
         retain num denom lastNum lastDenom;

         if first._id then do; num=1; denom=1; end;
         else do; num=num*lastNum; denom=denom*lastDenom; end;

         lastNum=dn; lastDenom=dd;*9/16/2020 - corrected this ilne to use DN and DD rather than NUM and DENOM;
         dowgt = num / denom;
         wgt = expwgt * dowgt;
         keep _id &trtvar in days_death outcome_death wgt dowgt;
      run;
      proc datasets lib=work nolist nodetails; delete ___anacohort_death&i; run; quit;

	*The people being dropped at this stage is because they do not have overlapping PS weights.;



		proc datasets lib=work nolist nodetails; delete _anacohort&i __anacohort&i; run; quit;


      %PUT STEP 5: RUN ANALYSIS;

		%PUT MACE;
      proc phreg data=____anacohort_mace&i noprint; strata &trtvar;
         model days_mace*outcome_mace(0)= /entry=in; weight %IF &noiptw=0 %THEN wgt; %ELSE dowgt;; 
         baseline out=_c2_mace survival=s/method=ch; run;

	  proc sort data=_c2_mace; by &trtvar days_mace; run;
	  *Calculate the estimates for each of the days that interested in;

	  *Cannot run this on more than one length of follow-up;

	   *Calculate risk;
		  data _c3_mace;
		  set _c2_mace;
		  	by &trtvar days_mace;
			if last.&trtvar then do;
				risk = 1-s;
				output;
			end;
			keep &trtvar days_mace risk;
		  run;

		  *Calculate RD and RR;
		  data _c4_mace (where=(&trtvar=1));
		  set _c3_mace;
		  	retain r0;
			r = risk;
			if &trtvar=0 then do; r0=r; lnrr=0; rr=1; rd=0; end;
			else do; lnrr=log( r/r0 ); rr=r/r0; rd=r-r0; end;
			samplingseed = &seed;
			drop days_mace risk;
		  run;

      %IF &i=1 %THEN %DO; data %IF &noiptw=0 %THEN ana.mace_365_&cohort; %ELSE ana.mace_365_&cohort._noiptw;; set _c4_mace; run; %END;
      %ELSE %DO; proc append base=%IF &noiptw=0 %THEN ana.mace_365_&cohort; %ELSE ana.mace_365_&cohort._noiptw; data=_c4_mace; run; %END;


		%PUT MACE and HF;
      proc phreg data=____anacohort_macehf&i noprint; strata &trtvar;
         model days_macehf*outcome_macehf(0)= /entry=in; weight %IF &noiptw=0 %THEN wgt; %ELSE dowgt;; 
         baseline out=_c2_macehf survival=s/method=ch; run;

	  proc sort data=_c2_macehf; by &trtvar days_macehf; run;
	  *Calculate the estimates for each of the days that interested in;

	  *Cannot run this on more than one length of follow-up;

	   *Calculate risk;
		  data _c3_macehf;
		  set _c2_macehf;
		  	by &trtvar days_macehf;
			if last.&trtvar then do;
				risk = 1-s;
				output;
			end;
			keep &trtvar days_macehf risk;
		  run;

		  *Calculate RD and RR;
		  data _c4_macehf (where=(&trtvar=1));
		  set _c3_macehf;
		  	retain r0;
			r = risk;
			if &trtvar=0 then do; r0=r; lnrr=0; rr=1; rd=0; end;
			else do; lnrr=log( r/r0 ); rr=r/r0; rd=r-r0; end;
			samplingseed = &seed;
			drop days_macehf risk;
		  run;

      %IF &i=1 %THEN %DO; data %IF &noiptw=0 %THEN ana.macehf_365_&cohort; %ELSE ana.macehf_365_&cohort._noiptw;; set _c4_macehf; run; %END;
      %ELSE %DO; proc append base=%IF &noiptw=0 %THEN ana.macehf_365_&cohort; %ELSE ana.macehf_365_&cohort._noiptw; data=_c4_macehf; run; %END;


		%PUT DEATH;
      proc phreg data=____anacohort_death&i noprint; strata &trtvar;
         model days_death*outcome_death(0)= /entry=in; weight %IF &noiptw=0 %THEN wgt; %ELSE dowgt;; 
         baseline out=_c2_death survival=s/method=ch; run;

	  proc sort data=_c2_death; by &trtvar days_death; run;
	  *Calculate the estimates for each of the days that interested in;

	  *Cannot run this on more than one length of follow-up;

	   *Calculate risk;
		  data _c3_death;
		  set _c2_death;
		  	by &trtvar days_death;
			if last.&trtvar then do;
				risk = 1-s;
				output;
			end;
			keep &trtvar days_death risk;
		  run;

		  *Calculate RD and RR;
		  data _c4_death (where=(&trtvar=1));
		  set _c3_death;
		  	retain r0;
			r = risk;
			if &trtvar=0 then do; r0=r; lnrr=0; rr=1; rd=0; end;
			else do; lnrr=log( r/r0 ); rr=r/r0; rd=r-r0; end;
			samplingseed = &seed;
			drop days_death risk;
		  run;

      %IF &i=1 %THEN %DO; data %IF &noiptw=0 %THEN ana.death_365_&cohort; %ELSE ana.death_365_&cohort._noiptw;; set _c4_death; run; %END;
      %ELSE %DO; proc append base=%IF &noiptw=0 %THEN ana.death_365_&cohort; %ELSE ana.death_365_&cohort._noiptw; data=_c4_death; run; %END;



      proc datasets lib=work nolist nodetails; delete _anacohort&i _data_merge&i; run; quit;
   %END;

%mend;

