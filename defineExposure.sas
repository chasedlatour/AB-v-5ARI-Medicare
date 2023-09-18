
/************************************************/
/* Program: defineExposure.sas					*/
/* Programmars: Sola & Chase				    */
/* Purpose: This program creates datasets that  */
/*	define our pharmacologic exposures.			*/
/*												*/
/* Exposures:									*/
/*	(1) Alpha-blockers (selective)				*/
/*	(2) Alpha-blockers (non-selective)			*/
/* 	(3) 5-alpha reductase inhibitors			*/
/*	(4) Combination drugs						*/
/*												*/
/*	Analytic notes: We have decided to define	*/
/*	all of our exposures here without using 	*/
/*	pre-defined datasets, for practice and to	*/
/*	ensure that everyting was captured correctly*/
/************************************************/


*STEP 1: Remote submit this statement. This ensures that all analyses
are pointing to the correct libraries;
options source source2 msglevel=I mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(1pct, defineExposure, saveLog=N);


*STEP 2: Remote submit these library statements and mprint option;
libname atc '/nearline/files/datasources/references/Code Reference Sets/Drugs';
libname ref '/nearline/files/datasources/references/Definitions/drugs/';

options mprint;


*STEP 3: Local submit these statements. Create local mirrors of server libraries 
so that you can see the stored datasets;
libname ldata slibref=raw server=server;
*libname loutlab3 slibref=outlab3 server=server;
libname lwork slibref=work server=server;
libname lexpref slibref=expref server=server;


*STEP 4: Remote submit this macro;
%macro getndc(class, atc);
   proc sort data=&class._name; by drugName; run;
   proc sql noprint; 
      select distinct drugName into :drug1-:drug100 from &class._name;
      %LET NumDrug = &SqlObs; 

      select distinct atc into :atc1-:atc100 from &class._name;
      %LET NumATC = &SqlObs;
   quit;

   proc sql;
      create table expref.&class._ndc(where=(ndc11 ne '')) as
      select case when a.drugName ne '' then a.drugName 
         %DO i=1 %TO &numDrug; 
            when index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") then "&&drug&i"
         %END; end as drug, b.*
      from &class._name as a 
       full join atc.atc_ndc(where=(atc in: (&atc) or
           %DO i=1 %TO &numDrug; 
                index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") or %END;
           %IF &numATC > 0 %THEN %DO; %DO i=1 %TO &numATC;
                 atc=:"&&atc&i" %IF &i<&numATC %THEN or ; %END; %END;)) as b
       on a.atc = b.atc
       order by drug, ndc11;
   quit;
%mend;


*STEP 5: Step through and make datasets for each drug class.;



/********************************************/
/* 		   SELECTIVE ALPHA-BLOCKERS			*/
/********************************************/

*(i) Create a dataset that contains the drug names
and ATC codes for Alpha-blockers. Originally, we had
split up the datasets by what hte ATC codes started with.
However, after re-running after our meeting, I realized
that that wasn't necessary.;

data ablocker_selective_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	ALFUZOSIN	G04CA01
	TAMSULOSIN	G04CA02
	TERAZOSIN	G04CA03
	SILODOSIN	G04CA04
	PRAZOSIN	C02CA01
	DOXAZOSIN	C02CA04
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=ablocker_selective, atc=%STR('G04CA','C02CA'));

*(iii) Remove those rows where the ATC codes do not match the ones
that we are interested in. Specifically, with the code, we only keep those
rows that we are interested in.;
PROC SQL;
	CREATE TABLE expref.ablocker_selective_ndc_final AS
	SELECT *
	FROM expref.ablocker_selective_ndc 
	WHERE atc in ('G04CA01','G04CA02','G04CA03','G04CA04','C02CA01','C02CA04')
	;
	QUIT;



/********************************************/
/* 		 NON-SELECTIVE ALPHA-BLOCKERS		*/
/********************************************/
*i) Create a dataset that contains the drug names
and ATC codes for non-selective alpha-blockers;
*confirm these are the non-selective and if they are currently still in use;

data ablocker_nonselective_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	PHENOXYBENZAMINE	C04AX02
	PHENTOLAMINE		C04AB01
	TOLAZOLINE			C04AB02
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=ablocker_nonselective, atc=%STR('C04A'));

*(iii) Remove those rows where the ATC codes do not match the ones
that we are interested in. Specifically, with the code, we only keep those
rows that we are interested in.;
PROC SQL;
	CREATE TABLE expref.ablocker_nselective_ndc_final AS
	SELECT *
	FROM expref.ablocker_nonselective_ndc 
	WHERE atc in ('C04AX02','C04AB01','C04AB02')
	;
	QUIT;

/********************************************/
/* 		5-ALPHA REDUCTASE INHIBITORS		*/
/********************************************/
*i) Create a dataset that contains the drug names
and ATC codes for 5-Alpha Reductase;


data five_areductase_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	DUTASTERIDE		G04CB02
	FINASTERIDE		G04CB01
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=five_areductase, atc=%STR('G04CB'));

*(iii) Remove those rows where the ATC codes do not match the ones
that we are interested in. Specifically, with the code, we only keep those
rows that we are interested in.;
PROC SQL;
	CREATE TABLE expref.five_areductase_ndc_final AS
	SELECT *
	FROM expref.five_areductase_ndc 
	WHERE atc in ('G04CB01','G04CB02')
	;
	QUIT;

/********************************************/
/* 			COMBINATION THERAPIES			*/
/********************************************/
*i) Create a dataset that contains the drug names
and ATC codes for combination therapies;
*ATC code for Polythiazide/Prazosin missing;

data combinationtherapy_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	DUTASTERIDE/TAMSULOSIN	G04CA52
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=combinationtherapy, atc=%STR('G04CA'));

*(iii) Remove those rows where the ATC codes do not match the ones
that we are interested in. Specifically, with the code, we only keep those
rows that we are interested in.;
PROC SQL;
	CREATE TABLE expref.combinationtherapy_ndc_final AS
	SELECT *
	FROM expref.combinationtherapy_ndc 
	WHERE atc in ('G04CA52')
	;
	QUIT;






/*************************************************
Stack all of the data sets in ndc10
**************************************************/
PROC SQL;
	CREATE TABLE expref.allcodes9 AS 
	SELECT *, 1 as ab_sel, 0 as ab_nsel, 0 as ar5, 0 as comb
	FROM expref.ablocker_selective_ndc_final
	UNION 
	SELECT *, 0 as ab_sel, 1 as ab_nsel, 0 as ar5, 0 as comb
	FROM expref.ablocker_nselective_ndc_final
	UNION
	SELECT *, 0 as ab_sel, 0 as ab_nsel, 1 as ar5, 0 as comb
	FROM expref.five_areductase_ndc_final
	UNION
	SELECT *, 0 as ab_sel, 0 as ab_nsel, 0 as ar5, 1 as comb
	FROM expref.combinationtherapy_ndc_final
	;
	QUIT;


PROC SQL;
	CREATE TABLE expref.combinationtherapy_ndc_final AS
	SELECT *
	FROM expref.combinationtherapy_ndc 
	WHERE atc in ('G04CA52')
	;
	QUIT;






/********************************************/
/*     DEFINE MEDS THAT AREN'T EXPOSURE		*/
/********************************************/








/********************************************/
/* 		  			 NICOTINE				*/
/********************************************/

*(i) Create a dataset that contains the drug names
and ATC codes for nicotine.;

data nicotine_varen_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
   	NICOTINE	N07BA1
	VARENICLINE N07BA3
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=nicotine_varen, atc=%STR('N07BA'));


/****************************************************/





/************ANTITHROMBOTIC AGENTS**************/

*Warfarin;

*(i) Create a dataset that contains the drug names
and ATC codes;

data warfarin_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	WARFARIN	B01AA03
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=warfarin, atc=%STR('B01AA03'));


*Heparin;

*(i) Create a dataset that contains the drug names
and ATC codes;

data heparin_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	HEPARIN			B01AB01
	HEPARIN_COMB	B01AB51
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=heparin, atc=%STR('B01AB01','B01AB51'));


*Rivaroxaban;

*(i) Create a dataset that contains the drug names
and ATC codes;

data rivaroxaban_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	RIVAROXABAN		B01AF01
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=rivaroxaban, atc=%STR('B01AF01'));


*Dabigatran;

*(i) Create a dataset that contains the drug names
and ATC codes;

data dabigatran_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	DABIGRATRAN		B01AE07
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=dabigatran, atc=%STR('B01AE07'));



*Apixaban;

*(i) Create a dataset that contains the drug names
and ATC codes;

data apixaban_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	APIXABAN		B01AF02
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=apixaban, atc=%STR('B01AF02'));



*Edoxaban;

*(i) Create a dataset that contains the drug names
and ATC codes;

data edoxaban_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
	EDOXABAN		B01AF03
   ;
run;

*(ii) Run the getndc macro on the dataset;
%getndc(class=edoxaban, atc=%STR('B01AF03'));



/**********************************************/










/****EXAMPLE CODE FROM VIRGINIA******/
libname rxref '/nearline/files/datasources/references/Definitions/drugs';

data rxcovar.arb;  set rxref.arb_ndc(keep=drug_name ndc9); run;
data rxcovar.acei; set rxref.acei_ndc(keep=drug_name ndc9); run;

data rxcovar.saInsulin; set rxref.rapidinsulin_ndc(keep=drug_name ndc9); run;

data rxcovar.laInsulin; 
   set rxref.intermediateInsulin_ndc(keep=drug_name ndc9)
        rxref.mixedInsulin_ndc(keep=drug_name ndc9)
        rxref.lai_ndc(keep=drug_name ndc9);
run;

/********************************************/
/* EXAMPLE 2: CREATING YOUR OWN DEFINITIONS */
/********************************************/

libname atc '/nearline/files/datasources/references/Code Reference Sets/Drugs';
libname ref '/nearline/files/datasources/references/Definitions/drugs/';

%macro getndc(class, atc);
   proc sort data=&class._name; by drugName; run;
   proc sql noprint; 
      select distinct drugName into :drug1-:drug100 from &class._name;
      %LET NumDrug = &SqlObs; 

      select distinct atc into :atc1-:atc100 from &class._name;
      %LET NumATC = &SqlObs;
   quit;

   proc sql;
      create table expref.&class._ndc(where=(ndc11 ne '')) as
      select case when a.drugName ne '' then a.drugName 
         %DO i=1 %TO &numDrug; 
            when index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") then "&&drug&i"
         %END; end as drug, b.*
      from &class._name as a 
       full join atc.atc_ndc(where=(atc in: (&atc) or
           %DO i=1 %TO &numDrug; 
                index(upcase(drug_name),"&&drug&i") or index(upcase(atc_label),"&&drug&i") or %END;
           %IF &numATC > 0 %THEN %DO; %DO i=1 %TO &numATC;
                 atc=:"&&atc&i" %IF &i<&numATC %THEN or ; %END; %END;)) as b
       on a.atc = b.atc
       order by drug, ndc11;
   quit;
%mend;

/*EXAMPLE: H2-ANTAGONISTS*/
data h2antagonist_name; length drugName $70 atc $7; input drugName $ atc $;
   cards
   ;
   CIMETIDINE A02BA01
   CIMETIDINE A02BA51
   RANITIDINE A02BA02
   RANITIDINE A02BA07
   FAMOTIDINE A02BA03
   FAMOTIDINE A02BA53
   NIZATIDINE A02BA04
   NIPEROTIDINE A02BA05
   ROXATIDINE A02BA06
   LAFUTIDINE A02BA08
   ;
run;
%getndc(class=h2antagonist, atc=%STR('A02BA'))




