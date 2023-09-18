/* 9/30/2022 - added count and dates of BPH diagnoses */
/* 10/19/2022 - corrected frailty CPT codes */
/* 9/8/2023 - added LICS, added additional HF and BPH covariates*/


options source source2 msglevel=I mcompilenote=all mautosource mprint 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(full, 02a_covariates, saveLog=Y)
/*Could run the include macro if want to automatically run another SAS file*/
*%include();

/*libname lwork slibref=work server=server;*/
/*libname lout slibref=out server=server;*/

%LET startYear=2007;
%LET endYear=2019;
%LET bldays = 365;
/*Baseline Covariates*/
%macro getdx(startYr=&startYear, endYr=&endYear);
	/* Step 1: Read in all ICD-10 dx covariate defintions from CODEREF library */
	%GLOBAL NumDxCov;
	%DO i=1 %TO 100;
		%GLOBAL dxcov&i;
	%END;
	/*%GLOBAL NumDxCov %DO i=1 %TO 100; dxcov&i %END;; - Changed this to the above*/
	proc sql noprint;
		select distinct substr(memname,1,length(memname)-8) into :dxexcl1-:dxexcl100 from dictionary.members
			where libname='EXCLREF' and index(upcase(memname),'ICD10DX')>0;
		%LET NumDxExcl = &SqlObs;

		select distinct substr(memname,1,length(memname)-8) into :dxcov1-:dxcov100 from dictionary.members
			where libname='COVREF' and index(upcase(memname),'ICD10DX')>0;
		%LET NumDxCov = &SqlObs;

		select distinct name into :fraildx1-:fraildx100 from dictionary.columns
			where libname='FRAIL' and upcase(memname)='FAUROT_COMPONENTS_ICD9DX' and upcase(name) ^in ('CODE' 'CODE_TYPE' 'DESCRIPTION');
		%LET NumFrailDx = &SqlObs;
	quit;

	data dxRef_icd9dx; length code $5;
		set %DO i=1 %TO &numDxExcl; exclref.&&dxexcl&i.._icd9dx (in=excl&i) %END;
			%DO i=1 %TO &numDxCov; covref.&&dxcov&i.._icd9dx (in=cov&i) %END;
			frail.faurot_components_icd9dx(drop=code_type description); 
		length variable $20; 
		%DO i=1 %TO &numDxExcl; if excl&i then variable="&&dxexcl&i"; %END; 
		%DO i=1 %TO &numDxCov; if cov&i then variable="&&dxcov&i"; %END; 
	run;

	data dxRef_icd10dx; length code $7;
		set %DO i=1 %TO &numDxExcl; exclref.&&dxexcl&i.._icd10dx (in=excl&i) %END;
			%DO i=1 %TO &numDxCov; covref.&&dxcov&i.._icd10dx (in=cov&i) %END;
			frail.faurot_components_icd10dx(drop=code_type description); 
		length variable $20; 
		%DO i=1 %TO &numDxExcl; if excl&i then variable="&&dxexcl&i"; %END; 
		%DO i=1 %TO &numDxCov; if cov&i then variable="&&dxcov&i"; %END; 
	run;

	/* Step 2: Pull all claims of interest from DER.ALLDX and create person level summary variables */
	proc sql;
	   create table dx as
	   select distinct a.bene_id, a.indexdate,
			min(case when upcase(b.variable)='BPHWUS' then from_dt else . end) as first_bphwus_dt format=date9. label='Date of First BPH w/ US Diagnosis prior to Index Date',
			min(case when upcase(b.variable)='BPHWOUS' then from_dt else . end) as first_bphwous_dt format=date9. label='Date of First BPH w/out US Diagnosis prior to Index Date',

			count(distinct case when upcase(b.variable)='BPHWUS' and flag_1yrlb=1 then from_dt else . end) as num_dx1yr_bphwus label='Number of (1-yr LB) Diagnoses for BPH w/ US',
			count(distinct case when upcase(b.variable)='BPHWOUS' and flag_1yrlb=1 then from_dt else . end) as num_dx1yr_bphwous label='Number of (1-yr LB) Diagnoses for BPH w/o US',

			count(distinct case when upcase(b.variable)='BPHWUS' and flag_1yrlb=1 and inpt=1 then from_dt else . end) as numInpt_dx1yr_bphwus label='Number of Inpatient (1-yr LB) Diagnoses for BPH w/ US',
			count(distinct case when upcase(b.variable)='BPHWOUS' and flag_1yrlb=1 and inpt=1 then from_dt else . end) as numInpt_dx1yr_bphwous label='Number of Inpatient (1-yr LB) Diagnoses for BPH w/o US',
			count(distinct case when upcase(b.variable)='BPHWUS' and flag_1yrlb=1 and inpt=0 then from_dt else . end) as numOutpt_dx1yr_bphwus label='Number of Outpatient (1-yr LB) Diagnoses for BPH w/ US',
			count(distinct case when upcase(b.variable)='BPHWOUS' and flag_1yrlb=1 and inpt=0 then from_dt else . end) as numOutpt_dx1yr_bphwous label='Number of Outpatient (1-yr LB) Diagnoses for BPH w/o US',

			case when calculated numInpt_dx1yr_bphwus>=1 or calculated numOutpt_dx1yr_bphwus>=2 then 1 else 0 end as bl_1yrlb_bphwus_1in_2out label='1-Year LB, 1 Inpt or 2 Outpt BPH w/ US Dx',
			case when calculated numInpt_dx1yr_bphwous>=1 or calculated numOutpt_dx1yr_bphwous>=2 then 1 else 0 end as bl_1yrlb_bphwous_1in_2out label='1-Year LB, 1 Inpt or 2 Outpt BPH w/o US Dx',

			count(distinct case when upcase(b.variable)='HF' and flag_1yrlb=1 and inpt=1 then from_dt else . end) as numInpt_dx1yr_hf label='Number of Inpatient (1-yr LB) Diagnoses for HF',
			count(distinct case when upcase(b.variable)='HF' and flag_1yrlb=1 and inpt=0 then from_dt else . end) as numOutpt_dx1yr_hf label='Number of Outpatient (1-yr LB) Diagnoses for HF',
			case when calculated numInpt_dx1yr_hf>=1 or calculated numOutpt_dx1yr_hf>=2 then 1 else 0 end as bl_1yrlb_hf_1in_2out label='1-Year LB, 1 Inpt or 2 Outpt HF Dx',

			%DO i=1 %TO &numDxExcl; 		
					sum(case when b.variable= "&&dxexcl&i" then 1 else 0 end) as exclude_aalb_&&dxexcl&i label="All-Available LB, &&dxexcl&i",
					sum( b.variable="&&dxexcl&i" and flag_1yrlb ) as exclude_1yrlb_&&dxexcl&i label="1-Year LB, &&dxexcl&i",
					sum( b.variable="&&dxexcl&i" and flag_6moslb) as exclude_6moslb_&&dxexcl&i label="6-Month LB, &&dxexcl&i",%END; 

			sum( b.variable="STROKE" and flag_1yrlb and inpt) as bl_1yrlb_stroke_inpt label="1-Year LB, Inpatient Stroke",
			sum( b.variable="HF" and flag_1yrlb and inpt) as bl_1yrlb_hf_inpt label="1-Year LB, Inpatient Heart Failure",
			sum( b.variable="MI" and flag_1yrlb and inpt) as bl_1yrlb_mi_inpt label="1-Year LB, Inpatient MI",

			%DO i=1 %TO &numDxCov; 
					sum(case when b.variable="&&dxcov&i" then 1 else 0 end) as bl_aalb_&&dxcov&i label = "All-Available LB, &&dxcov&i",
					sum (case when b.variable="&&dxcov&i" and flag_1yrlb then 1 else 0 end) as bl_1yrlb_&&dxcov&i label= "1-Year LB, &&dxcov&i",
					sum(case when b.variable="&&dxcov&i" and flag_6moslb then 1 else 0 end) as bl_6moslb_&&dxcov&i label= "6-Month LB, &&dxcov&i",%END;

			%DO i=1 %TO &numFrailDx; max(b.&&fraildx&i=1 /*and flag_1yrlb=1*/) as bl_&&fraildx&i %IF &i<&NumFrailDx %THEN ,; %END;         
	   		from out.cohortDS as a 
		left join
	      (select distinct a.bene_id, a.indexdate, b.from_dt, c.variable, %DO f=1 %TO &NumFrailDx; c.&&fraildx&f, %END;
					case when a.indexdate-360<=b.from_dt<=a.indexdate then 1 else 0 end as flag_1yrlb,
					case when a.indexdate-180<=b.from_dt<=a.indexdate then 1 else 0 end as flag_6moslb,
					case when b.source='MedPar' then 1 else 0 end as inpt
		      from out.cohortDS as a 
					inner join der.alldx as b 
		         		on a.bene_id = b.bene_id and /*a.indexdate-&blDays<=*/b.from_dt<=a.indexdate 
					inner join dxRef_icd9dx as c on b.dx=c.code 

		  	union corresponding 

			%DO yr=%SYSFUNC(max(2015,&startYr)) %TO &endYr;
			select distinct a.bene_id, a.indexdate, b.from_dt, c.variable,  %DO f=1 %TO &NumFrailDx; c.&&fraildx&f, %END; 
					case when a.indexdate-360<=b.from_dt<=a.indexdate then 1 else 0 end as flag_1yrlb,
					case when a.indexdate-180<=b.from_dt<=a.indexdate then 1 else 0 end as flag_6moslb,
					case when b.source='MedPar' then 1 else 0 end as inpt
		      from out.cohortDS as a 
					inner join der.alldx10&yr as b 
		         		on a.bene_id = b.bene_id and /*a.indexdate-&blDays<=*/b.from_dt<=a.indexdate
					inner join dxRef_icd10dx as c on b.dx&yr=c.code
			%IF &yr<&endYr %THEN union corresponding; %END;
	      ) as b
	         on a.bene_id = b.bene_id and a.indexdate = b.indexdate
	   group by a.bene_id, a.indexdate
	   order by bene_id, indexdate;
	quit;
%mend;
%getdx()


/*Baseline procedures*/
%macro getpx(startYr=&startYear, endYr=&endYear);
	/* Step 1: Read in all pr procedures defintions from CODEREF library */
	proc sql noprint;
		
		select distinct substr(memname,1,length(memname)-3) into :pxexcl1-:pxexcl100 from dictionary.members
			where libname='EXCLREF' and substr(memname,length(memname)-2)='_PR'; /*index(upcase(memname),'PR')>0;*/
		%LET NumPxExcl = &SqlObs;

		select distinct substr(memname,1,length(memname)-3) into :pxcov1-:pxcov100 from dictionary.members
			where libname='COVREF' and substr(memname,length(memname)-2)='_PR'; /*index(upcase(memname),'PR')>0;*/
		%LET NumPxCov = &SqlObs;
	quit;

	data pxRef9;
	set %DO i=1 %TO &numPxExcl; exclref.&&pxexcl&i.._pr9 (in=excl&i) %END;
			%DO i=1 %TO &numpxCov; covref.&&pxcov&i.._pr9 (in=cov&i) %END;	;
		length variable $20; 
		%DO i=1 %TO &numPxExcl; if excl&i then variable="&&pxexcl&i"; %END; 
		%DO i=1 %TO &numPxCov; if cov&i then variable="&&pxcov&i"; %END; 
	run;

	data pxRef10;
		set %DO i=1 %TO &numPxExcl; exclref.&&pxexcl&i.._pr (in=excl&i) %END;
			%DO i=1 %TO &numpxCov; covref.&&pxcov&i.._pr (in=cov&i) %END;; 
		length variable $20; 
		%DO i=1 %TO &numPxExcl; if excl&i then variable="&&pxexcl&i"; %END; 
		%DO i=1 %TO &numPxCov; if cov&i then variable="&&pxcov&i"; %END; 
	run;
/* Step 2: Pull all claims of interest from DER.ALLDX and create person level summary variables */
	proc sql;
	   create table px as
	   select distinct a.bene_id, a.indexdate,

			%DO i=1 %TO &numPxExcl; 
					max(b.variable="&&pxexcl&i") as exclude_aalb_&&pxexcl&i label="All-Available LB, &&pxexcl&i",
					max(b.variable="&&pxexcl&i" and flag_1yrlb) as exclude_1yrlb_&&pxexcl&i label="1-Year LB, &&pxexcl&i",
					max(b.variable="&&pxexcl&i" and flag_6moslb) as exclude_6moslb_&&pxexcl&i label="6-Month LB, &&pxexcl&i",
			%END;
			sum(b.variable="CABG" and flag_1yrlb and inpt) as exclude_1yrlb_cabg_inpt label="1-Year LB, Inpatient CABG",
/*max(b.variable="&&pxexcl&i") as exclude_&&pxexcl&i , %END;*/
			%DO i=1 %TO &numPxCov; 
					max(b.variable="&&pxcov&i") as bl_aalb_&&pxcov&i label = "All-Available LB, &&pxcov&i",
					max(b.variable="&&pxcov&i" and flag_1yrlb) as bl_1yrlb_&&pxcov&i label= "1-Year LB, &&pxcov&i",
					max(b.variable="&&pxcov&i" and flag_6moslb) as bl_6moslb_&&pxcov&i label= "6-Month LB, &&pxcov&i"
					%IF &i<&NumPxCov %THEN ,; 
			%END;
	   		from out.cohortDS as a 
		left join
	      (select distinct a.bene_id, a.indexdate, c.variable, 
					case when a.indexdate-360<=b.proc_dt<=a.indexdate then 1 else 0 end as flag_1yrlb, /*check here*/
					case when a.indexdate-180<=b.proc_dt<=a.indexdate then 1 else 0 end as flag_6moslb,
					case when b.source='Inpatient' then 1 else 0 end as inpt
		      from out.cohortDS as a 
					inner join der.allicd9_proc  as b 
		         		on a.bene_id = b.bene_id and /*a.indexdate-&blDays<=*/b.proc_dt<=a.indexdate
					inner join pxRef9 as c on b.proc=c.code 

			union corresponding /*added this*/

			%DO yr=%SYSFUNC(max(2015,&startYr)) %TO &endYr;
			select distinct a.bene_id, a.indexdate, c.variable, 
					case when a.indexdate-360<=b.proc_dt<=a.indexdate then 1 else 0 end as flag_1yrlb,
					case when a.indexdate-180<=b.proc_dt<=a.indexdate then 1 else 0 end as flag_6moslb,
					case when b.source='Inpatient' then 1 else 0 end as inpt
		      from out.cohortDS as a 
					inner join der.allicd10_proc&yr as b 
		         		on a.bene_id = b.bene_id and /*a.indexdate-&blDays<=*/b.proc_dt<=a.indexdate
					inner join pxRef10 as c on b.proc=c.icd10pr 
			%IF &yr<&endYr %THEN union corresponding; %END;
	      ) as b
	         on a.bene_id = b.bene_id and a.indexdate = b.indexdate
	   group by a.bene_id, a.indexdate
	   order by bene_id, indexdate;
	quit;
%mend;
%getpx()


%macro getcpt(startYr=&startYear, endYr=&endYear);
	/* Step 1: Read in all cpt procedures defintions from CODEREF library */
	proc sql;* noprint;
		select distinct substr(memname,1,length(memname)-4) into :cptexcl1-:cptexcl100 from dictionary.members
			where libname='EXCLREF' and index(upcase(memname),'CPT')>0;
		%LET NumCptExcl = &SqlObs;

		select distinct substr(memname,1,length(memname)-4) into :cptcov1-:cptcov100 from dictionary.members
			where libname='COVREF' and index(upcase(memname),'CPT')>0;
		%LET NumCptCov = &SqlObs;

		select distinct name into :frailcpt1-:frailcpt100 from dictionary.columns
			where libname='FRAIL' and upcase(memname)='FAUROT_COMPONENTS_CPT' and upcase(name) ^in ('CODE' 'DESCRIPTION');quit;
		%LET NumFrailCPT = &SqlObs;
	quit;

	data cptRef; length code $5;
		set %DO i=1 %TO &numCptExcl; exclref.&&cptexcl&i.._cpt (in=excl&i) %END;
			%DO i=1 %TO &numCptCov; covref.&&cptcov&i.._cpt (in=cov&i) %END;
			frail.faurot_components_cpt; 
		length variable $20; 
		%DO i=1 %TO &numCptExcl; if excl&i then variable="&&cptexcl&i"; %END; 
		%DO i=1 %TO &numCptCov; if cov&i then variable="&&cptcov&i"; %END; 
	run;

/* Step 2: Pull all claims of interest from DER.ALLDX and create person level summary variables */
	proc sql;
	   create table cpt as
	   select distinct a.bene_id, a.indexdate,
			%DO i=1 %TO &numCptExcl; 
					max(b.variable="&&cptexcl&i") as exclude_aalb_&&cptexcl&i label="All-Available LB, &&cptexcl&i",
					max(b.variable="&&cptexcl&i" and flag_1yrlb) as exclude_1yrlb_&&cptexcl&i label="1-Year LB, &&cptexcl&i",
					max(b.variable="&&cptexcl&i" and flag_6moslb) as exclude_6moslb_&&cptexcl&i label="6-Month LB, &&cptexcl&i",
			%END;

			%DO i=1 %TO &numCptCov; 
					max(b.variable="&&cptcov&i") as bl_aalb_&&cptcov&i label = "All-Available LB, &&cptcov&i",
					max(b.variable="&&cptcov&i" and flag_1yrlb) as bl_1yrlb_&&cptcov&i label= "1-Year LB, &&cptcov&i",
					max(b.variable="&&cptcov&i" and flag_6moslb) as bl_6moslb_&&cptcov&i label= "6-Month LB, &&cptcov&i",
			%END;

			%DO i=1 %TO &numFrailCPT; max(b.&&frailcpt&i=1 /*and flag_1yrlb=1*/) as bl_&&frailcpt&i %IF &i<&numFrailCPT %THEN ,; %END;         
	   from out.cohortDS as a 
		left join
	      (select distinct a.bene_id, a.indexdate, c.variable, %DO f=1 %TO &numFrailCPT; c.&&frailcpt&f, %END;
		  			case when a.indexdate-360<=b.proc_dt<=a.indexdate then 1 else 0 end as flag_1yrlb,
					case when a.indexdate-180<=b.proc_dt<=a.indexdate then 1 else 0 end as flag_6moslb
		      from out.cohortDS as a 
					inner join der.allcpt as b 
		         		on a.bene_id = b.bene_id and /*a.indexdate-&blDays<=*/b.proc_dt<=a.indexdate
					inner join cptRef as c on b.proc=c.code
	      ) as b
	         on a.bene_id = b.bene_id and a.indexdate = b.indexdate
	   group by a.bene_id, a.indexdate
	   order by bene_id, indexdate;
	quit;

	proc sql;
		create table cabg_inpt as 
			select distinct a.bene_id, a.indexdate, max(b.variable='CABG') as bl_1yrlb_cabg_inpt
			from out.cohortDS as a 
			left join 
				(%DO yr=&startYr %TO &endYr;
					select distinct a.bene_id, a.indexdate, 'CABG' as variable
					from out.cohortDS as a 
						inner join raw.bcarrier_line&yr as b on a.bene_id=b.bene_id and a.indexdate-360<=b.thru_dt<=a.indexdate
						inner join covref.cabg_cpt as c on b.hcpcs_cd=c.code
					where b.plcsrvc='21'

				%IF &yr<&endYr %THEN union all corresponding; %END;
				) as b
	         	on a.bene_id = b.bene_id and a.indexdate = b.indexdate
		   group by a.bene_id, a.indexdate
		   order by bene_id, indexdate;
	quit;
%mend;
%getcpt()

/*baselinedrugs*/
%macro getrx(startYr=&startYear, endYr=&endYear);
	/* Step 1: Read in all rx covariate defintions from CODEREF library */
	proc sql noprint;
		select distinct substr(memname,1,length(memname)-4) into :rxexcl1-:rxexcl100 from dictionary.members
			where upcase(libname)='EXCLREF' and substr(memname,length(memname)-3)='_NDC'; /*index(upcase(memname),'_NDC')>0;*/
		%LET NumRxExcl = &SqlObs;

		select distinct substr(memname,1,length(memname)-4) into :rxcov1-:rxcov100 from dictionary.members
			where upcase(libname)='RXCOV' and substr(memname,length(memname)-3)='_NDC'; /*index(upcase(memname),'_NDC')>0;*/
		%LET NumRxCov = &SqlObs;
	quit;


	data rx_ref;
		set %DO i=1 %TO &numRxExcl; exclref.&&rxexcl&i.._ndc (in=excl&i) %END;
			%DO i=1 %TO &numRxCov; rxcov.&&rxcov&i.._ndc (in=cov&i) %END;; 
		length variable $20; 
		%DO i=1 %TO &numRxExcl; if excl&i then variable="&&rxexcl&i"; %END; 
		%DO i=1 %TO &numRxCov; if cov&i then variable="&&rxcov&i"; %END; 
	run;

	/* Step 2: Pull all claims of interest from DER.ALLDX and create person level summary variables */
	proc sql;
	   create table rx as
	   select distinct a.bene_id, a.indexdate,
			%DO i=1 %TO &numRxExcl; 
					sum(case when b.variable="&&rxexcl&i" then 1 else 0 end) as exclude_aalb_&&rxexcl&i label="All-Available LB, Number of &&rxexcl&i Fills",
					sum( b.variable="&&rxexcl&i" and flag_1yrlb) as exclude_1yrlb_&&rxexcl&i label="1-Year LB, Number of &&rxexcl&i Fills",
					sum( b.variable="&&rxexcl&i" and flag_6moslb) as exclude_6moslb_&&rxexcl&i label="6-Month LB, Number of &&rxexcl&i Fills",
					%END;
/*max(b.variable="&&rxexcl&i") as exclude_&&rxexcl&i , %END;*/
			%DO i=1 %TO &numRxCov; 
					sum(case when b.variable="&&rxcov&i" then 1 else 0 end) as bl_aalb_&&rxcov&i label = "All-Available LB, Number of &&rxcov&i",
					sum(case when b.variable="&&rxcov&i" and flag_1yrlb then 1 else 0 end) as bl_1yrlb_&&rxcov&i label= "1-Year LB, &&rxcov&i",
					sum(case when b.variable="&&rxcov&i" and flag_6moslb then 1 else 0 end) as bl_6moslb_&&rxcov&i label= "6-Month LB, &&rxcov&i" /*,*/
				%IF &i<&NumRxCov %THEN ,; %END;         
	   		from out.cohortDS as a 
		left join(%DO yr=&startYr %TO &endYr;
			select distinct a.bene_id, a.indexdate, c.variable, b.srvc_dt,
					case when a.indexdate-360<=b.srvc_dt<=a.indexdate then 1 else 0 end as flag_1yrlb,
					case when a.indexdate-180<=b.srvc_dt<=a.indexdate then 1 else 0 end as flag_6moslb
		      from out.cohortDS as a 
					inner join raw.pde_saf_file&yr as b 
		         		on a.bene_id = b.bene_id and /*a.indexdate-&blDays<=*/b.srvc_dt<=a.indexdate
					inner join rx_ref as c on substr(b.prdsrvid,1,9)=c.ndc9
			%IF &yr<&endYr %THEN union corresponding; %END;) as b
	     on a.bene_id = b.bene_id and a.indexdate = b.indexdate
	     group by a.bene_id, a.indexdate
	   order by bene_id, indexdate;
	quit;
%mend;
%getrx()


%macro hospice(startYr=&startYear, endYr=&endYear);
	proc sql;
		create table hospice as select distinct a.bene_id, a.indexdate,
			max(a.indexdate-&bldays<=b.thru_dt<=a.indexdate) as bl_hospice label='Baseline Hospice Claim',
			min(case when a.indexdate<=b.from_dt then b.from_dt else . end) as fup_hospice_dt format=date9. label='Date of First Hospice Claim during FOllow-Up' 
		from out.cohortDS as a
		left join  (%DO yr=&startYr %TO &endYr;
			select a.bene_id, a.indexdate, b.from_dt, b.thru_dt
				from out.cohortDS as a inner join raw.hospice_base_claims&yr as b 
					on a.bene_id =b.bene_id and a.indexdate-&bldays<=b.thru_dt 
			%IF &yr<&endYr %THEN union corresponding; %END;) as b
		on a.bene_id=b.bene_id and a.indexdate=b.indexdate
		group by a.bene_id, a.indexdate
		order by bene_id, indexdate;
	quit;
%mend;
%hospice()

*BUYIN variable based on this: https://resdac.org/cms-data/variables/medicare-entitlementbuy-indicator (for index month);
	*0=No, 1=Yes;
*CSTSHR variable based on this: https://resdac.org/cms-data/variables/monthly-cost-sharing-group-under-part-d-low-income-subsidy-january (for index month);
	*0=None, 1=Full, 2=Partial;
*DUAL variable based on this: https://resdac.org/cms-data/variables/monthly-medicare-medicaid-dual-eligibility-code-january (for index month);
	*0=None, 1=Full, 2=Partial;

%macro lis(startYr=&startYear, endYr=&endYear);
	proc sql;
		create table lics as select distinct a.bene_id, a.indexdate,
			b.buyin label="State Buy-in (Part A/B) in Index Month",
			b.cstshr label="Part D Cost-Share Eligible (Part D) in Index Month",
			b.dual label="Dual Eligible in Index Month"
		from out.cohortDS as a
		left join 
			(%DO yr=&startYr %TO &endYr;
				select a.bene_id, a.indexdate, 
					case %DO i=1 %TO 9; when month(indexdate)=&i then b.buyin0&i %END; 
						%DO i=10 %TO 12; when month(indexdate)=&i then b.buyin&i %END; else '' end as buyin_mo, 
					case when calculated buyin_mo in ('A' 'B' 'C') then 1          
						 else 0 end as buyin label="State Buy-in (Part A/B) in Index Month",

					%IF &yr>2009 & &yr<2015 %THEN %DO;
						case %DO i=1 %TO 9; when month(indexdate)=&i then c.dual_0&i %END; 
							%DO i=10 %TO 12; when month(indexdate)=&i then c.dual_&i %END; else '' end as dual_mo,        
					%END; %ELSE %DO;
						case %DO i=1 %TO 9; when month(indexdate)=&i then b.dual_0&i %END; 
							%DO i=10 %TO 12; when month(indexdate)=&i then b.dual_&i %END; else '' end as dual_mo,        
					%END;
					case when calculated dual_mo in ('02' '04' '08') then 1          
						  when calculated dual_mo in ('01' '03' '05' '06') then 2
						 else 0 end as dual label="Dual Eligible in Index Month (1=full, 2=partial)",

					%IF &yr>2009 & &yr<2015 %THEN %DO;
						case %DO i=1 %TO 9; when month(indexdate)=&i then c.cstshr0&i %END; 
							%DO i=10 %TO 12; when month(indexdate)=&i then c.cstshr&i %END; else '' end as cstshr_mo,        
					%END; %ELSE %DO;
						case %DO i=1 %TO 9; when month(indexdate)=&i then b.cstshr0&i %END; 
							%DO i=10 %TO 12; when month(indexdate)=&i then b.cstshr&i %END; else '' end as cstshr_mo,        
					%END;
					case when calculated cstshr_mo in ('01' '02' '03') then 1              
						 when calculated cstshr_mo in ('04' '05' '06' '07' '08') then 2               
						 else 0 end as cstshr label="Part D Cost-Share Eligible (Part D) in Index Month"

				from out.cohortDS(where=(year(indexdate)=&yr)) as a
				inner join 
					%IF &yr<2010 %THEN raw.bsf&yr; %ELSE %IF &yr<2015 %THEN raw.mbsf_ab&yr; %ELSE raw.mbsf_abcd&yr; as b on a.bene_id=b.bene_id
					%IF &yr>2009 & &yr<2015 %THEN inner join raw.mbsf_d&yr as c on a.bene_id=c.bene_id;
				%IF &yr<&endYr %THEN union all corresponding; %END;
			) as b
		on a.bene_id=b.bene_id and a.indexdate=b.indexdate
		group by a.bene_id, a.indexdate
		order by bene_id, indexdate;
	quit;
%mend;
%lis()


data out.covariates;
	if _N_ = 1 then set frail.frailtyEstimates;

	merge out.cohortDS(/*where=(excludeflag_prefill2initiator= 0 & excludeflag_prevalentuser =0)*/ rename=(race=race_cd) in=a) 
			dx (rename =(exclude_aalb_chemotherapy=dx_exclude_aalb_chemo exclude_1yrlb_chemotherapy=dx_exclude_1yrlb_chemo exclude_6moslb_chemotherapy=dx_exclude_6moslb_chemo
							bl_aalb_tobacco=dx_bl_aalb_tobacco bl_1yrlb_tobacco=dx_bl_1yrlb_tobacco bl_6moslb_tobacco=dx_bl_6moslb_tobacco
							bl_rehab=dx_bl_rehab)) 

			px (rename=(bl_aalb_pcip=px_bl_aalb_pcip bl_1yrlb_pcip=px_bl_1yrlb_pcip bl_6moslb_pcip=px_bl_6moslb_pcip
						   exclude_aalb_chemotherapy=px_exclude_aalb_chemo exclude_1yrlb_chemotherapy=px_exclude_1yrlb_chemo exclude_6moslb_chemotherapy=px_exclude_6moslb_chemo
							bl_aalb_cabg=px_bl_aalb_cabg bl_1yrlb_cabg=px_bl_1yrlb_cabg bl_6moslb_cabg=px_bl_6moslb_cabg)) 

			cpt (rename=(bl_aalb_pcip=cpt_bl_aalb_pcip bl_1yrlb_pcip=cpt_bl_1yrlb_pcip bl_6moslb_pcip=cpt_bl_6moslb_pcip
						   exclude_aalb_chemotherapy=cpt_exclude_aalb_chemo exclude_1yrlb_chemotherapy=cpt_exclude_1yrlb_chemo exclude_6moslb_chemotherapy=cpt_exclude_6moslb_chemo 
							bl_aalb_cabg=cpt_bl_aalb_cabg bl_1yrlb_cabg=cpt_bl_1yrlb_cabg bl_6moslb_cabg=cpt_bl_6moslb_cabg
							exclude_aalb_transplant=cpt_exclude_aalb_trans exclude_1yrlb_transplant=cpt_exclude_1yrlb_trans exclude_6moslb_transplant=cpt_exclude_6moslb_trans
							bl_aalb_tobacco=cpt_bl_aalb_tobacco bl_1yrlb_tobacco=cpt_bl_1yrlb_tobacco bl_6moslb_tobacco=cpt_bl_6moslb_tobacco
							bl_rehab=cpt_bl_rehab)) 
			cabg_inpt
			rx (rename=(exclude_aalb_chemotherapy=rx_exclude_aalb_chemo exclude_1yrlb_chemotherapy=rx_exclude_1yrlb_chemo exclude_6moslb_chemotherapy=rx_exclude_6moslb_chemo))

			hospice
			lics; 
	by bene_id indexdate;
	if a;

	bl_rehab = max(dx_bl_rehab, cpt_bl_rehab);

	bl_aalb_pcip=max(px_bl_aalb_pcip, cpt_bl_aalb_pcip);
	bl_1yrlb_pcip=max(px_bl_1yrlb_pcip, cpt_bl_1yrlb_pcip);
	bl_6moslb_pcip=max(px_bl_6moslb_pcip, cpt_bl_6moslb_pcip);

	exclude_aarlb_transplant = max(cpt_exclude_aalb_trans);
	exclude_1yrlb_transplant = max(cpt_exclude_1yrlb_trans);
	exclude_6moslb_transplant = max(cpt_exclude_6moslb_trans);

	bl_aalb_cabg = max(px_bl_aalb_cabg, cpt_bl_aalb_cabg);
	bl_1yrlb_cabg = max(px_bl_1yrlb_cabg, cpt_bl_1yrlb_cabg);
	bl_6moslb_cabg = max(px_bl_6moslb_cabg, cpt_bl_6moslb_cabg);

	exclude_aalb_chemotherapy = max(dx_exclude_aalb_chemo, px_exclude_aalb_chemo, cpt_exclude_aalb_chemo, rx_exclude_aalb_chemo);
	exclude_1yrlb_chemotherapy = max(dx_exclude_1yrlb_chemo, px_exclude_1yrlb_chemo, cpt_exclude_1yrlb_chemo, rx_exclude_1yrlb_chemo);
	exclude_6moslb_chemotherapy = max(dx_exclude_6moslb_chemo, px_exclude_6moslb_chemo, cpt_exclude_6moslb_chemo, rx_exclude_6moslb_chemo);

	bl_aalb_tobacco=max(dx_bl_aalb_tobacco, cpt_bl_aalb_tobacco);
	bl_1yrlb_tobacco=max(dx_bl_1yrlb_tobacco, cpt_bl_1yrlb_tobacco);
	bl_6moslb_tobacco=max(dx_bl_6moslb_tobacco, cpt_bl_6moslb_tobacco);

	drop px_: dx_: cpt_:;

	if race_cd='1' then race='W'; else if race_cd='2' then race='B'; else if race_cd='5' then race='H'; else race='O';
	age65 = age-65;
	age65sq = age65 * age65;

	frailtyOdds = est_intercept + est_age65*age65 + est_age65sq*age65sq + est_sex*(sex='2') +
	   est_raceB*(race='B') + est_raceH*(race='H') + est_raceO*(race='O') + 
	   est_screening*(bl_screening>0) + est_lipid*(bl_lipid>0) + est_vertigo*(bl_vertigo>0) + 
	   est_arthritis*(bl_arthritis>0) + est_bladder*(bl_bladder>0) + est_podiatric*(bl_podiatric>0) + 
	   est_hf*(bl_hf>0) + est_psych*(bl_psych>0) + est_rehab*(bl_rehab>0) + est_oxygen*(bl_oxygen>0) +
	   est_hyposhock*(bl_hyposhock>0) + est_ambulance*(bl_ambulance>0) +  est_brainInjury*(bl_brainInjury>0) + 
	   est_dement*(bl_dement>0) + est_pd*(bl_pd>0) + est_weakness*(bl_weakness>0) + est_decub*(bl_decub>0) +
	   est_paralysis*(bl_paralysis>0) + est_wheelchair*(bl_wheelchair>0) + est_hospbed*(bl_hospbed>0);

	predictedFrailty = exp(frailtyOdds) / (1+exp(frailtyOdds));

	drop est_:;
run;





