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


*Current concerns:
- Cannot successfully run this analysis right now with more than one follow-up time
- Would like to be able to do PS trimming & re-fitting;

%macro competingrisk_weights(inds=cohort, startDT=indexDate, eventDT=outcomeDT, crDT=deathDT, censorDT=censorDT, 
      daysEst=365, psvars=age sex race, dovars=age sex race, classvars=sex race, trtvar=trt, 
      numiterations=1000, initialseed=23244, outds=ana.comprisk, noiptw=0);

*STEP 0: Parse macro variables;
   %LET numEst = %SYSFUNC(countw(&daysEst));
   %DO d=1 %TO &numEst; %LET est&d = %SCAN(&daysEst,&d); %END;

%PUT STEP 1: PREPARE ANALYTIC COHORT DATASET;
   data _anacohort; set &inds;
      * 1a: create analytic variables for time to event and outcome;
      days = min(&eventDT, &crDT, &censorDT) - &startDT + 1;

      if .z<&eventDT<=min(&censorDT, &crDT) then outcome=1; else outcome=0;
      if .z<&crDT<=min(&censorDT,&eventDT-1) then comprisk=1; else comprisk=0;

      combined=max(outcome,comprisk);
      if outcome=1 then event=1; else if comprisk=1 then event=2; else event=0;

      if days>&&est&numEst then do; outcome=0; comprisk=0; combined=0; event=0; days=&&est&numEst+1; end;
   run;

   *Remove people with an outcome between the first and second fill;
   data _anacohort;
   set _anacohort (where = (days>0));
   run;

   %PUT 1b: Jitter tied event times;
   %LET jitterFlag=1;
   %LET i=0;

   %DO %WHILE (&jitterFlag=1);
      Title "Iteration &i";
      proc sql noprint; 
         select case when max(numEvents)>1 then 1 else 0 end into :jitterFlag from 
            (select distinct days, count(*) as numEvents from _anacohort where combined=1 group by days); 
      quit;

      %IF &jitterFlag=1 %THEN %DO;
         %LET i = %EVAL(&i+1);
         data _anacohort; set _anacohort; call streaminit(123+&i); days+rand("uniform")*.0055-.00275; run;
      %END;
   %END;

   %DO i=1 %TO &numIterations;

		%IF &i>1 %then options nomlogic nomprint nosymbolgen nonotes;;
   		
      %PUT STEP 2: CREATE BOOTSTRAP SAMPLES;
      %LET seed = &i; *%SYSFUNC(floor(%SYSFUNC(ranuni(&initialseed))));
      proc surveyselect noprint data=_anacohort out=_anacohort&i(rename=(replicate=b) drop=numberhits) 
         seed=&seed method=urs samprate=1 outhits rep=1;
		data _anacohort&i; set _anacohort&i; _id=_N_; run;

	  %PUT STEP 3a: CALCULATE FIRST PS MODEL FOR TRIMMING;
 	  proc logistic data=_anacohort&i noprint; class &classVars; model &trtvar (reference="AR5")=&psvars; output out=_ps p=ps; run;

	  %PUT STEP 3b: IDENTIFY NON-OVERLAP AND TRIM POPULATION;
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
         keep _id &trtvar expwgt outcome comprisk combined days event &dovars;
      run;

      %PUT STEP 4: CREATE DROP OUT WEIGHTS

	  Should this go to the days that are of-interest for that estimate?
	  Yes - Can only run this macro for one FUP interest;
      proc univariate data=__anacohort&i /*_anacohort&i*/ noprint; where combined=0; var days; *Previously not trimmed.;
         output out=_quintiles pctlpts=20 40 60 80 100 pctlpre=p; run;
      data _null_; set _quintiles; 
         call symputx('p20', p20); call symputx('p40',p40); call symputx('p60',p60); call symputx('p80',p80); 
		 call symputx('p100',p100); run;
      data ___anacohort&i; set __anacohort&i(rename=(days=days1 outcome=outcome1 comprisk=comprisk1 combined=combined1));
         array j{6} j1-j6 (0, &p20, &p40, &p60, &p80, &p100);
         do k=1 to 5;
            in=j(k);
            if j(k)<days1<=j(k+1) then do; days=days1; if combined1=0 then drop=1; else drop=0; outcome=outcome1; comprisk=comprisk1; combined=combined1; output; end;
            else if j(k+1)<days1 then do; days=j(k+1); drop=0; outcome=0; comprisk=0; combined=0; output; end;
         end;
         keep _id in days outcome comprisk combined drop expwgt &trtvar &dovars;
      run;*9/16/2020 - corrected OUTCOME, COMPRISK and COMBINED variables in above step;
      proc datasets lib=work nolist nodetails; delete _anacohort&i __anacohort&i; run; quit;

		*9/16/2020 - flipped denominator and numerator;
      proc logistic data=___anacohort&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in; output out=num(keep=_id in dn) p=dn; run;
      proc logistic data=___anacohort&i noprint; class in &classvars / param=ref;
         model drop = &trtvar in &dovars; output out=denom(keep=_id in dd) p=dd; run;

      proc sort data=___anacohort&i; by _id in; run;
      proc sort data=denom; by _id in; run;
      proc sort data=num; by _id in; run;

      data ____anacohort&i; merge ___anacohort&i denom num; by _id in;
         retain num denom lastNum lastDenom;

         if first._id then do; num=1; denom=1; end;
         else do; num=num*lastNum; denom=denom*lastDenom; end;

         lastNum=dn; lastDenom=dd;*9/16/2020 - corrected this ilne to use DN and DD rather than NUM and DENOM;
         dowgt = num / denom;
         wgt = expwgt * dowgt;
         keep _id &trtvar in days outcome comprisk combined wgt dowgt;
      run;
      proc datasets lib=work nolist nodetails; delete ___anacohort&i _ps _sumstat _sumstat2 _ps2 _ps3 _num _den _quintiles
														num denom; 
			run; quit;

      %PUT STEP 5: RUN ANALYSIS;
      proc phreg data=____anacohort&i noprint; strata &trtvar;
         model days*combined(0)= /entry=in; weight %IF &noiptw=0 %THEN wgt; %ELSE dowgt;; 
         baseline out=_combined(rename=(survival=s_combined) keep=&trtvar days survival) survival=_ALL_/method=ch; run;

      proc phreg data=____anacohort&i noprint; strata &trtvar;
         model days*outcome(0)= /entry=in; weight %IF &noiptw=0 %THEN wgt; %ELSE dowgt;;
         baseline out=_outcome(rename=(survival=s_outcome) keep=&trtvar days survival) survival=_ALL_/method=ch; run;

      proc phreg data=____anacohort&i noprint; strata &trtvar;
         model days*comprisk(0)= /entry=in; weight %IF &noiptw=0 %THEN wgt; %ELSE dowgt;;
         baseline out=_comprisk(rename=(survival=s_comprisk) keep=&trtvar days survival) survival=_ALL_/method=ch; run;

      proc datasets lib=work nolist nodetails; delete ____anacohort&i; run; quit;
      proc sort data=_combined; by &trtvar days; run;
      proc sort data=_outcome;  by &trtvar days; run;
      proc sort data=_comprisk; by &trtvar days; run;

      data _surv(keep=&trtvar %DO d=1 %TO &numEst; rate&&est&d %END;/*rate&daysEst*/); 
         merge _combined _outcome _comprisk; by &trtvar days;
         retain cum_outcome 0 cum_comprisk 0 olds_combined olds_outcome olds_comprisk 
                %DO d=1 %TO &numEst; rate&&est&d %END;;
         if first.&trtvar then do; %DO d=1 %TO &numEst; rate&&est&d=.; %END; /*rate&daysEst=.*/ end; 
         if days=0 then do; 
            olds_combined=1; olds_outcome=1; olds_comprisk=1; iptw=1; 
            outcome=0; comprisk=0; cum_outcome=0; cum_comprisk=0; e_outcome=0; e_comprisk=0; 
         end;

         %DO d=1 %TO &numEst;
            if days>=&&est&numEst and rate&&est&d=. then do; rate&&est&d=1-cum_outcome; output; end;
         %END;

         if s_outcome ne .  then do; 
            h_outcome=-log(s_outcome)--log(olds_outcome); 
            e_outcome=olds_combined*h_outcome;   
            cum_outcome=cum_outcome+e_outcome; 
         end;

         if s_comprisk ne . then do; 
            h_comprisk=-log(s_comprisk)--log(olds_comprisk); 
            e_comprisk=olds_combined*h_comprisk; 
            cum_comprisk=cum_comprisk+e_comprisk; 
         end;  

         combined=cum_outcome+cum_comprisk;
         if s_combined ne . then olds_combined=s_combined;
         if s_outcome ne . then olds_outcome=s_outcome;
         if s_comprisk ne . then olds_comprisk=s_comprisk;

         if last.&trtvar then do; %DO d=1 %TO &numEst;
            if rate&&est&d=. then do; rate&&est&d = 1 - cum_outcome; output; end;  %END; end;
      run;

	  proc datasets lib=work nolist nodetails; delete _combined _outcome _comprisk; run; quit;

	  %PUT Summarize the datasets;

      data _rd&i(drop=&trtvar); 
         merge _surv(where=(&trtvar=0) rename=(%DO d=1 %TO &numEst; rate&&est&d=e0_surv&&est&d %END;))
               _surv(where=(&trtvar=1) rename=(%DO d=1 %TO &numEst; rate&&est&d=e1_surv&&est&d %END;)); 
            %DO d=1 %TO &numEst;
               e0_rate&&est&d = 1 - e0_surv&&est&d;
               e1_rate&&est&d = 1 - e1_surv&&est&d;
               riskDiff&&est&d = e1_rate&&est&d - e0_rate&&est&d; 
			   riskRatio&&est&d = e1_rate&&est&d / e0_rate&&est&d; 
			   lnriskRatio&&est&d = log( e1_rate&&est&d / e0_rate&&est&d );
               drop e0_surv&&est&d e1_surv&&est&d;
            %END;
			samplingseed = &seed;
      run;

	*Original;
/*	  %IF &i=1 %THEN %DO; data &outds; set _rd&i; run; %END;*/
/*      %ELSE %DO; proc append base=&outds data=_rd&i; run; %END;*/


      %IF &i=1 %THEN %DO; data %IF &noiptw=0 %THEN &outds; %ELSE &outds._noiptw;; set _rd&i; run; %END;
      %ELSE %DO; proc append base=%IF &noiptw=0 %THEN &outds; %ELSE &outds._noiptw; data=_rd&i; run; %END;
      proc datasets lib=work nolist nodetails; delete _surv _rd&i; run; quit;
   %END;
%mend;

