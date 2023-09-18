
/*****************************************************************************************************/
/* Created on: July 20, 2020                                                                         */
/* Created by: Sola Olawore                                                                          */
/*                                                                                                   */
/* 9/28/2022 - added variables for procedure based outcomes using only CPT codes from carrier file   */
/* 9/4/2023 - Added pneumonia as negative control ouitcome											 */
/*****************************************************************************************************/

options source source2 msglevel=I mprint mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, 02b_outcomes, saveLog=Y);
*%setup(1pct, 02b_outcomes, saveLog=Y);



%LET startYear=2007;
%LET endYear=2019;
proc sql noprint;
   select distinct substr(memname,1,length(memname)-7) into :dxout1-:dxout20 from dictionary.members 
      where libname='OUTREF' and index(upcase(memname),'ICD9DX')>0; 
   %LET NdxOut = &sqlObs; 

   select distinct substr(memname,1,length(memname)-6) into :procout1-:procout20 from dictionary.members 
      where libname='OUTREF' and index(upcase(memname),'ICD9P')>0;
   %LET NprocOut = &sqlObs; 

   select distinct memname into :cptout1-:cptout20 from dictionary.members 
      where libname='OUTREF' and index(upcase(memname),'CPT')>0;
   %LET NcptOut = &sqlObs; 
quit;

%macro getout();
   /* diagnosis codes */
   data dxout; set %DO i=1 %TO &NdxOut; outref.&&dxout&i.._icd9dx (keep=code in=in&i) %END;;
      length outVar $30; %DO i=1 %TO &NdxOut; if in&i then outVar="&&dxout&i"; %END;
      outvar=upcase(outvar);
   run;

   proc sql;
   	create table all_outcomes as
   	select distinct a.bene_id, a.indexdate, a.fillDate2, b.from_dt, c.outVar,
            
              
               case when b.dxLoc_claim=1 then 1 else 0 end as primary,
               case when b.dxLoc_claim=2 then 1 else 0 end as secondary

             from out.cohortDS as a /*should I use covariate dataset?*/
                inner join der.alldx as b on a.bene_id = b.bene_id and b.from_dt>=a.indexdate /*>.z*/
                inner join dxout as c on b.dx = c.code
             where b.source='MedPar';
  
   
      create table outDX as 
         select distinct bene_id, indexdate, filldate2, 
            %DO i=1 %TO &NdxOut;
               min(case when upcase(outVar)="&&dxout&i" and (primary or secondary) then from_dt else . end) as &&dxout&i.._date_9
                  format=date9. label="Date of First &&dxout&i DX (primary or secondary) During FUP",
               min(case when upcase(outVar)="&&dxout&i" and (primary) then from_dt else . end) as &&dxout&i.._FP_date_9
                  format=date9. label="Date of First &&dxout&i DX (primary only) During FUP"
			   %IF &i<&NdxOut %THEN ,; 
            %END;
	  
         from all_outcomes
         group by bene_id, indexdate, filldate2
         order by bene_id, indexdate, filldate2;
   quit;
   
                     /* diagnosis codes  ICD 10*/
   data dxoutten; set %DO i=1 %TO &NdxOut; outref.&&dxout&i.._icd10dx (keep=code in=in&i) %END;;
      length outVar $30; %DO i=1 %TO &NdxOut; if in&i then outVar="&&dxout&i"; %END;
      outvar=upcase(outvar);
   run;
   
 proc sql;
 	create table all_outcomesten as
		%DO yr=2015 %TO &endYear; 
		 	select distinct a.bene_id, a.indexdate, a.fillDate2, b.from_dt, c.outVar,
            
               case when b.dxLoc_claim=1 then 1 else 0 end as primary,
               case when b.dxLoc_claim=2 then 1 else 0 end as secondary

             from out.cohortDS as a 
                inner join der.alldx10&yr as b on a.bene_id = b.bene_id and b.from_dt>=a.indexdate
                inner join dxoutten as c on b.dx&yr = c.code
             where b.source='MedPar' 
		%IF &yr<&endYear %THEN union corresponding; %END;;
             
             
      create table outDX10 as 
         select distinct bene_id, indexdate, filldate2,

            %DO i=1 %TO &NdxOut;
		
               min(case when upcase(outVar)="&&dxout&i" and (primary or secondary)  then from_dt else . end) as &&dxout&i.._date_10
                  format=date9. label="Date of First &&dxout&i DX (primary or secondary) During FUP",
               min(case when upcase(outVar)="&&dxout&i" and (primary)  then from_dt else . end) as &&dxout&i.._FP_date_10
                  format=date9. label="Date of First &&dxout&i DX (primary only) During FUP"
			   %IF &i<&NdxOut %THEN ,; 
            %END;
      
         from all_outcomesten
         group by bene_id, indexdate, filldate2
         order by bene_id, indexdate, filldate2;
   quit;
   

	data dx_outcomes;
		merge outDX outDX10;
		by bene_id indexdate filldate2;

		%DO i=1 %TO &NdxOut; 
			&&dxout&i.._date = min(&&dxout&i.._date_9, &&dxout&i.._date_10);
				label &&dxout&i.._date = "Date of First &&dxout&i DX (primary or secondary) During FUP";
				format &&dxout&i.._date date9.;
			&&dxout&i.._FP_date = min(&&dxout&i.._FP_date_9, &&dxout&i.._FP_date_10);
				label &&dxout&i.._FP_date = "Date of First &&dxout&i DX (primary only) During FUP";
				format &&dxout&i.._FP_date date9.;
		%END;

		drop %DO i=1 %TO &NdxOut; &&dxout&i.._date_9 &&dxout&i.._date_10 &&dxout&i.._FP_date_9 &&dxout&i.._FP_date_10 %END;;
	run;

%mend;
%getout();


%macro getproc();
                       /* ICD-9 procedure codes */
   data procout; set %DO i=1 %TO &NprocOut; outref.&&procout&i.._icd9p (keep=code in=in&i) %END;;
      length outVar $30; %DO i=1 %TO &NprocOut; if in&i then outVar="&&procout&i"; %END;
      outvar=upcase(outvar);
   run;

   proc sql;
      create table allproc as
       select a.bene_id, a.indexdate, a.filldate2, b.proc_dt format=date9., c.outVar
             from out.cohortDS as a 
               inner join der.allICD9_proc as b on a.bene_id = b.bene_id and 
               b.proc_dt>=a.indexdate
               inner join procout as c on b.proc = c.code;
   
      create table outProc as 
         select distinct bene_id, indexdate, filldate2, 

            %DO i=1 %TO &NprocOut;
               min(case when upcase(outVar)="&&procout&i"  then proc_dt else . end) as &&procout&i.._date_9
                  format=date9. label="Date of First &&procout&i ICD-9 Procedure Code During FUP"               
            %IF &i<&NprocOut %THEN ,; %END;
	
         from allProc
         group by bene_id, indexdate, filldate2
         order by bene_id, indexdate, filldate2;
   quit;

	data procoutten; set %DO i=1 %TO &NprocOut; outref.&&procout&i.._icd10p (keep=code in=in&i) %END;;
      length outVar $30; %DO i=1 %TO &NprocOut; if in&i then outVar="&&procout&i"; %END;
      outvar=upcase(outvar);
   run;

   proc sql;
     create table allproc10 as 
	  	%DO yr=2015 %TO &endyear;
	     select a.bene_id, a.indexdate, a.filldate2, b.proc_dt format=date9., c.outVar
	             from out.cohortDS as a 
	               inner join der.allICD10_proc&yr as b on a.bene_id = b.bene_id and b.proc_dt>=a.indexdate /*>.z*/
	               inner join procoutten as c on b.proc = c.code
      %IF &yr<&endYear %THEN union all corresponding; %END;;

      create table outProc10 as 
         select distinct bene_id, indexdate, filldate2, 

            %DO i=1 %TO &NprocOut;
               min(case when upcase(outVar)="&&procout&i" then proc_dt else . end) as &&procout&i.._date_10
                  format=date9. label="Date of First &&procout&i ICD-10 Procedure Code During FUP"
            %IF &i<&NprocOut %THEN ,; %END;

         from allproc10
         group by bene_id, indexdate, filldate2
         order by bene_id, indexdate, filldate2;
   quit;


	data px_outcomes;
		merge outProc outProc10;
		by bene_id indexdate filldate2;

		%DO i=1 %TO &NprocOut; 
			&&procout&i.._icd_date = min(&&procout&i.._date_9, &&procout&i.._date_10);
				label &&procout&i.._icd_date = "Date of First &&procout&i ICD Procedure Code During FUP";
		%END;

		drop %DO i=1 %TO &NprocOut; &&procout&i.._date_9 &&procout&i.._date_10 %END;;
	run;
%mend;
%getproc();
	

%macro getcpt();
   				/* CPT codes */
   data cptout; set %DO i=1 %TO &NcptOut; outref.&&cptout&i (keep=code in=in&i) %END;;
      length outVar $30; %DO i=1 %TO &NcptOut; if in&i then outVar="&&cptout&i"; %END;
      outvar=upcase(outvar);
   run;

   proc sql;
      create table allcpt as 
      select a.bene_id, a.indexdate, a.filldate2, b.proc_dt format=date9., c.outVar,
			case when upcase(b.source)='B CARRIER' then 1 else 0 end as carrier
             from out.cohortDS as a 
               inner join der.allcpt as b on a.bene_id = b.bene_id and b.proc_dt>=a.indexdate /*>.z*/
               inner join cptout as c on b.proc = c.code;
               
      create table outCPT as 
         select distinct bene_id, indexdate, filldate2, 

            %DO i=1 %TO &NcptOut;
	               min(case when upcase(outVar)="&&cptout&i"  then proc_dt else . end) as &&cptout&i.._date
                  format=date9. label="Date of First &&cptout&i CPT Code During FUP",

               min(case when upcase(outVar)="&&cptout&i" and carrier=1 then proc_dt else . end) as &&cptout&i.._carr_date
                  format=date9. label="Date of First &&cptout&i CPT Code from Carrier File During FUP"
            %IF &i<&NcptOut %THEN ,; %END;

         from allcpt
         group by bene_id, indexdate, filldate2
         order by bene_id, indexdate, filldate2;
   quit;

%mend;
%getcpt();

/*proc sort data=out.cohortDS; by bene_id indexdate filldate2; run;*/

*Chase had to set this to "ana.outcomes_correct" because she does not
have write access to the out. folder in the full sample;

data out.outcomes/*ana.outcomes_correct*/; 
	merge /*out.cohortDS (in=a)*/
			dx_outcomes px_outcomes outCPT;
	by bene_id indexdate filldate2;
	*if a;

	cabg_date = min(cabg_icd_date, cabg_cpt_date);
		label cabg_date = ="Date of First CABG Procedure Code During FUP";
		format cabg_date date9.;
	pcip_date = min(pcip_icd_date, pcip_cpt_date);
		label pcip_date = ="Date of First PCIP Procedure Code During FUP";
		format pcip_date date9.;

	*drop cabg_icd_date cabg_cpt_date pcip_icd_date pcip_cpt_date;
run;





























































































/*data all;*/
/*   set temp.newusers_sgltvsu*/
/*         (where=(filldate2 ne . and excludeFlag_prevalentUser=0 and excludeFlag_sameDayInitiator=0 and excludeFlag_preFill2Initiator=0)*/
/*          keep=bene_id indexdate filldate2 */
/*          in=a)*/
/*      temp.newusers_sgltvtzd*/
/*         (where=(filldate2 ne . and excludeFlag_prevalentUser=0 and excludeFlag_sameDayInitiator=0 and excludeFlag_preFill2Initiator=0)*/
/*          keep=bene_id indexdate filldate2 ;*/
/*          in=b);*/
/*   suCohort=a;*/
/*run;*/
/*proc sql;*/
/*   create table newusers as*/
/*   select distinct bene_id, indexdate, filldate2,  */
/*         max(suCohort=1) as suCohort, max(suCohort=0) as tzdCohort*/
/*   from all group by bene_id, indexdate, filldate2;*/
/*quit;*/
/**/
/*proc datasets lib=work nolist nodetails; delete all; run;quit;*/
/**/
/**/
/**/
/*%macro getrx(startyr=&startYear, endyr=&endYear);*/
/*   proc sql;*/
/*        create table outRx as select distinct bene_id, indexdate, filldate2,*/
/*             max(padRX * pre) as pad_RXpre, max(padRX * post) as pad_RX, */
/*             min(padRX * post * srvc_dt) as pad_RX_date format=date9.,*/
/*             max(nitratesRX * pre) as nitrates_RXpre, max(nitratesRX * post) as nitrates_RX,*/
/*             min(nitratesRX * post * srvc_dt) as nitrates_RX_date format=date9.*/
/*        from (*/
/*         %DO i=&startyr %TO &endyr;*/
/*             select a.bene_id, a.indexdate, a.filldate2, b.srvc_dt,*/
/*                  case when b.srvc_dt < a.filldate2 then 1 else . end as pre,*/
/*                  case when b.srvc_dt >= a.filldate2 then 1 else . end as post,*/
/*                  case when index(upcase(b.gnn),'CILOSTAZOL')>0 or index(upcase(b.gnn),'PENTOXIFYLLINE')>0*/
/*                       then 1 else . end as padRX,*/
/*                  case when index(upcase(b.gnn),'NYTROGLICERINE')>0 or index(upcase(b.gnn),'RANOLAZINE')>0*/
/*                       then 1 else . end as nitratesRX*/
/*             from newusers(where=(year(indexdate)<=&i)) as a inner join raw.pde_saf_file&i as b*/
/*                  on a.bene_id = b.bene_id and a.indexdate < b.srvc_dt */
/*               where index(upcase(b.gnn),'CILOSTAZOL')>0 or index(upcase(b.gnn),'PENTOXIFYLLINE')>0*/
/*                     or index(upcase(b.gnn),'NYTROGLICERINE')>0 or index(upcase(b.gnn),'RANOLAZINE')>0*/
/*             %IF &i<&endyr %THEN union all corresponding ;*/
/*        %END; */
/*        ) group by bene_id, indexdate, filldate2*/
/*        order by bene_id, indexdate, filldate2*/
/*        ;*/
/*quit;*/
/*%mend;*/
/*%getrx()*/
/**/
/**/
/*proc sql noprint;*/
/*   select distinct memname into :dxout1-:dxout20 from dictionary.members */
/*      where libname='REFOUT' and index(upcase(memname),'CPT')=0 and index(upcase(memname),'ICD9P')=0;*/
/*   %LET NdxOut = &sqlObs; */
/**/
/*   select distinct memname into :procout1-:procout20 from dictionary.members */
/*      where libname='REFOUT' and index(upcase(memname),'ICD9P')>0;*/
/*   %LET NprocOut = &sqlObs; */
/**/
/*   select distinct memname into :cptout1-:cptout20 from dictionary.members */
/*      where libname='REFOUT' and index(upcase(memname),'CPT')>0;*/
/*   %LET NcptOut = &sqlObs; */
/*quit;*/


/*%macro getout();*/
/*   * diagnosis codes ;*/
/*   data dxout; set %DO i=1 %TO &NdxOut; refout.&&dxout&i (keep=code in=in&i) %END;;*/
/*      length outVar $30; %DO i=1 %TO &NdxOut; if in&i then outVar="&&dxout&i"; %END;*/
/*      outvar=upcase(outvar);*/
/*   run;*/
/**/
/*   proc sql;*/
/*      create table outDX(drop=miPre mi_date strokePre stroke_date) as */
/*         select distinct bene_id, indexdate, filldate2,*/
/**/
/*            %DO i=1 %TO &NdxOut;*/
/*               max(upcase(outVar)="&&dxout&i" and preFill2=1) as &&dxout&i..Pre label="&&dxout&i DX b/n 1st and 2nd RX Fill",*/
/*               min(case when upcase(outVar)="&&dxout&i" and preFill2=0 then from_dt else . end) as &&dxout&i.._date*/
/*                  format=date9. label="Date of First &&dxout&i DX During FUP",*/
/*            %END;*/
/**/
/*            max(upcase(outVar)='MI' and (primary or secondary) and preFill2=1) as miPrimaryPre*/
/*                  label='Non-Fatal MI b/n 1st and 2nd RX Fill',*/
/*            min(case when upcase(outVar)='MI' and (primary or secondary) and preFill2=0 then from_dt */
/*                  else . end) as miPrimary_date format=date9. label='Date of Earliest Non-Fatal MI during Follow-Up',*/
/**/
/*            max(upcase(outVar)='STROKE' and primary and preFill2=1) as strokePrimaryPre label='Stroke b/n 1st and 2nd RX Fill',*/
/*            min(case when upcase(outVar)='STROKE' and primary and preFill2=0 then from_dt */
/*                  else . end) as strokePrimary_date format=date9. label='Date of Earliest Stroke during Follow-Up'*/
/**/
/*         from (select distinct a.bene_id, a.indexdate, a.fillDate2, b.from_dt, c.outVar,*/
/*            */
/*               case when b.from_dt<a.filldate2 then 1 else 0 end as preFill2,*/
/**/
/*               case when b.dxLoc_claim=1 then 1 else 0 end as primary,*/
/*               case when b.dxLoc_claim=2 then 1 else 0 end as secondary*/
/**/
/*             from newusers as a */
/*                inner join der.alldx as b on a.bene_id = b.bene_id and a.indexdate < b.from_dt*/
/*                inner join dxout as c on b.dx = c.code*/
/*             where b.source='MedPar' )*/
/*         group by bene_id, indexdate, filldate2*/
/*         order by bene_id, indexdate, filldate2;*/
/*   quit;*/
/**/
/*   * ICD-9 procedure codes;*/
/*   data procout; set %DO i=1 %TO &NprocOut; refout.&&procout&i (keep=code in=in&i) %END;;*/
/*      length outVar $30; %DO i=1 %TO &NprocOut; if in&i then outVar="&&procout&i"; %END;*/
/*      outvar=upcase(outvar);*/
/*   run;*/
/**/
/*   proc sql;*/
/*      create table outProc as */
/*         select distinct bene_id, indexdate, filldate2,  */
/**/
/*            %DO i=1 %TO &NprocOut;*/
/*               max(upcase(outVar)="&&procout&i" and preFill2=1) as &&procout&i..Pre label="&&procout&i ICD-9 Procedure Code b/n 1st and 2nd RX Fill",*/
/*               min(case when upcase(outVar)="&&procout&i" and preFill2=0 then proc_dt else . end) as &&procout&i.._date*/
/*                  format=date9. label="Date of First &&procout&i ICD-9 Procedure Code During FUP"*/
/*            %IF &i<&NprocOut %THEN ,; %END;*/
/**/
/*         from ( */
/*             select a.bene_id, a.indexdate, a.filldate2, b.proc_dt, c.outVar,*/
/*                    case when b.proc_dt<a.filldate2 then 1 else 0 end as preFill2*/
/*             from newusers as a */
/*               inner join der.allICD9_proc as b on a.bene_id = b.bene_id and a.indexdate < b.proc_dt*/
/*               inner join procout as c on b.proc = c.code)*/
/*         group by bene_id, indexdate, filldate2*/
/*         order by bene_id, indexdate, filldate2;*/
/*   quit;*/
/**/
/**/
/*   * CPT codes ;*/
/*   data cptout;*/
/*		set %DO i=1 %TO &NcptOut; refout.&&cptout&i (keep=code in=in&i) %END;;*/
/*      length outVar $30; %DO i=1 %TO &NcptOut; if in&i then outVar="&&cptout&i"; %END;*/
/*      outvar=upcase(outvar);*/
/*   run;*/
/**/
/*   proc sql;*/
/*      create table outCPT as */
/*         select distinct bene_id, indexdate, filldate2,  */
/**/
/*            %DO i=1 %TO &NcptOut;*/
/*               max(upcase(outVar)="&&cptout&i" and preFill2=1) as &&cptout&i..Pre label="&&cptout&i CPT Code b/n 1st and 2nd RX Fill",*/
/*               min(case when upcase(outVar)="&&cptout&i" and preFill2=0 then proc_dt else . end) as &&cptout&i.._date*/
/*                  format=date9. label="Date of First &&cptout&i CPT Code During FUP"*/
/*            %IF &i<&NcptOut %THEN ,; %END;*/
/**/
/*         from ( */
/*             select a.bene_id, a.indexdate, a.filldate2, b.proc_dt, c.outVar,*/
/*                case when b.proc_dt<a.filldate2 then 1 else 0 end as preFill2*/
/*             from newusers as a */
/*               inner join der.allcpt as b on a.bene_id = b.bene_id and a.indexdate < b.proc_dt*/
/*               inner join cptout as c on b.proc = c.code)*/
/*         group by bene_id, indexdate, filldate2*/
/*         order by bene_id, indexdate, filldate2;*/
/*   quit;*/
/*%mend;*/
/*%getout()*/

/**Merge All Outcomes together for entire cohort;*/
/**/
/**/
/**/
/*data out.outcomes_sglt_tzd out.outcomes_sglt_su;*/
/*   merge newusers(in=a) outRX(in=rx) */
/*         outDX(in=dx rename=(miPrimaryPre=miPre miPrimary_date=mi_date strokePrimaryPre=strokePre strokePrimary_date=stroke_date)) */
/*         outProc(in=proc) outCPT(in=cpt);*/
/*   by bene_id indexdate filldate2;*/
/*   if a;*/
/**/
/*   * Revascularization: ICD-9 or CPT codes ;*/
/*   revascPre = max(revascularization_icd9pPre, revascularization_cptPre);*/
/*   revasc_date = min(revascularization_icd9p_date, revascularization_cpt_date);*/
/*   drop revascularization_icd9pPre revascularization_cptPre revascularization_icd9p_date revascularization_cpt_date;*/
/**/
/*   * Peripheral arterial disease (PAD) ;*/
/*   padPre = max(padPre, pad_icd9pPre, pad_RXpre);*/
/*   pad_date = min(pad_date, pad_icd9p_date, pad_RX_date);*/
/*   drop pad_icd9pPre pad_RXpre pad_icd9p_date pad_RX_date;*/
/**/
/*   * Combined CHD: Non-fatal MI, Angina w/ hospitlization, or Coronary Revascularization ;*/
/*   chdPre = max(miPre, anginaPre, revascPre);*/
/*   chd_date = min(mi_date, angina_date, revasc_date);*/
/**/
/*    Combined CVD: Combined CHD, treated angina w/o hosp, stroke, heart failure, PAD */
/*   cvdPre = max(chdPre, nitrates_RXPre, hfPrimaryPre, hfSecondaryPre, padPre);*/
/*   cvd_date = min(chd_date, nitrates_RX_date, hfPrimary_date, hfSecondary_date, pad_date);*/
/*   */
/*   if tzdCohort then output out.outcomes_sglt_tzd;*/
/*   if suCohort then output out.outcomes_sglt_su;*/
/*   drop suCohort tzdCohort;*/
/**/
/*   label chdPre = 'CHD b/n 1st and 2nd RX Fills'*/
/*         chd_date = 'Date of Earliest Indication of CHD during Follow-Up'*/
/*         cvdPre = 'CVD b/n 1st and 2nd RX Fills'*/
/*         cvd_date = 'Date of Earliest Indication of CVD during Follow-Up'*/
/*         revascPre = 'Revascularization b/n 1st and 2nd RX Fills'*/
/*         revasc_date = 'Date of Earliest Indication of Revascularization during Follow-Up'*/
/*         padPre = 'Peripheral Arterial Disease b/n 1st and 2nd RX Fills'*/
/*         pad_date = 'Date of Earliest Indication of Peripheral Arterial Disease during Follow-Up';*/
/**/
/*   format chd_date cvd_date revasc_date pad_date date9.;*/
/*run;*/
