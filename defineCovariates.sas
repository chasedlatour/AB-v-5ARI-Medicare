options source source2 msglevel=I mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(1pct, defineCovariates, saveLog=N)

/* NOTE: libnames covref & hcuse defined in setup macro */

/************************************************/
/* USING DEFINITIONS ALREADY DEFINED */
/************************************************/
/* Pull reference datasets from /nearlines/files/datasources/references/Definitions/covariates */

libname ref  '/nearline/files/datasources/references/Definitions/covariates';
libname locref '/local/projects/medicare/ablocker/data/coderef'; 
*diagnoses;

**ICD9;
data covref.chdz_icd9dx ; rename icd9_dx_self = code; set locref.chdz_dx9; run;
/*data covref.inth_icd9dx; length code $10;	set locref.inth_dx9_final; run;*/
data covref.stroke_icd9dx; 	set locref.stroke_dx9; run; 
/*data covref.stroketiainclude_icd9dx; length  code $10;	set locref.stroketia_include_icd9dx; run;*/
data covref.diabetes_icd9dx; length  code $10;	set locref.diabetes_icd9dx; run;
data covref.copd_icd9dx; length   code $10;			 set locref.copd_icd9dx;	run;
data covref.ckd_icd9dx;	length code $10;		 set locref.ckd_dx9;	run;
/*data covref.ihdz_icd9dx; length   code $10;	set locref.ischemichtdz_icd9dx; run;*/
data covref.hchl_icd9dx; length code $10;	set locref.hypercholesterolemia_dx9; run; 
/*data covref.chfd_icd9dx; length  code $10;	set locref.chf_icd9dx; run;*/
data covref.mi_icd9dx;	length code $10;	set locref.mi_dx9; run;
data covref.atherosclerosis_icd9dx;	length code $10;	set locref.atherosclerosis_icd9dx ref.peripheralvdz_icd9dx; run;
data covref.peripheralvdz_icd9dx;	length  code $10;	set ref.peripheralvdz_icd9dx; run;
data covref.aur_icd9dx; 	length code $10;	 set locref.aur_dx9; run;
data covref.chdz_icd9dx;	length code $10;	 set locref.chdz_dx9; run;
data covref.hf_icd9dx; 		length code $10;			 set locref.hf_dx9; run;
data covref.obesity_icd9dx; length code $10;	set locref.obesity_dx9; run;
data covref.tobacco_icd9dx; length code $10;	set locref.tobacco_dx9; run;

***ICD10;
data covref.atherosclerosis_icd10dx; length atherosclerosis_icd10dx $7; set locref.atherosclerosis_icd10dx locref.peripheralvdz_icd10 ; run; 
data covref.aur_icd10dx; 		 set locref.aur_dx10; run; 
data covref.chdz_icd10dx;		 set locref.chdz_dx10; run;
data covref.hf_icd10dx; 				 set locref.hf_dx10; run;
/*data covref.chfd_icd10dx;		 set locref.chfd_dx_fbm_final; run;*/
data covref.ckd_icd10dx;			 set locref.ckd_dx10;	run;
data covref.copd_icd10dx;			 set locref.copd_icd10dx;	run;
data covref.diabetes_icd10dx; 		 set locref.diabetes_icd10dx;	run;
data covref.hchl_icd10dx;		set locref.hypercholesterolemia_dx10;	run; 
/*data covref.ihdz_icd10dx;		set locref.ihdz_dx_fbm_final;	run;*/
/*data covref.inth_icd10dx;			set locref.inth_dx_fbm_final;	run;*/
data covref.mi_icd10dx;				set locref.mi_dx10;		run;
data covref.peripheralvdz_icd10dx;   set locref.peripheralvdz_icd10;	run;
data covref.stroke_icd10dx; 	set locref.stroke_dx10;  run; 
/*data covref.stroketiainclude_icd10dx; 	set locref.stroketia_include_icd10dx;	run;*/
data covref.obesity_icd10dx;		set locref.obesity_dx10; run;
data covref.tobacco_icd10dx; 		set locref.tobacco_dx10; run;

*Procedures;
data covref.angioplasty_cpt; length code $5;	set locref.angioplasty_cpt; 		run; 
data covref.revascularization_cpt;  length code $5; set ref.revascularization_cpt; run;
data covref.cabg_cpt; length code $5;		set locref.cabg_cpt; run;
data covref.pcip_cpt;	length code $5;	set locref.pcip_cpt_final;	run;
data covref.pcip_pr;				set locref.pci_pr_10;	run; 
data covref.cabg_pr;				set locref.cabg_pr10;	run;
data covref.cabg_pr9; length code $8;			set locref.cabg_pr9; run; 
data covref.pcip_pr9;	length code $8;	set locref.pci_pr9;	run;
data covref.tobacco_cpt; length code $5; set locref.tobacco_cpt; run;


***drug definitions; 


libname rxref '/local/projects/medicare/ablocker/data/coderef/rxcovar';
libname rxref2 '/nearline/files/datasources/references/Definitions/drugs';
data rxcov.arb_ndc;  set rxref.arb_ndc (keep=drug_name ndc9); run;
data rxcov.peripheralvaso_ndc;  set rxref2.peripheralvasodilator_ndc (keep=drug_name ndc9); run;
data rxcov.aspirin_ndc; set rxref.arb_ndc (keep = drug_name ndc9); run; 
data rxcov.acei_ndc; set rxref.acei_ndc(keep=drug_name ndc9); run;
data rxcov.apixaban_ndc; set rxref.apixaban_ndc(keep=drug_name ndc9); run;
data rxcov.bb_ndc;   set rxref.bb_ndc(keep=drug_name ndc9);	run; 
data rxcov.ccb_ndc;	set rxref.ccb_ndc(keep=drug_name ndc9); run;
data rxcov.thiazide_ndc;	set rxref.thiazide_ndc(keep=drug_name ndc9); run;
data rxcov.loop_ndc;		set rxref.loop_ndc(keep=drug_name ndc9);	run;
data rxcov.otherdiuretics_ndc; set rxref.otherdiuretics_ndc(keep=drug_name ndc9); run;
data rxcov.ksparingdiuretic_ndc;	set rxref.ksparingdiuretic_ndc(keep=drug_name ndc9); run;
data rxcov.combodiuretics_ndc;	set rxref.combodiuretics_ndc(keep=drug_name ndc9);	run;
data rxcov.dabigatran_ndc;		set rxref.dabigatran_ndc(keep=drug_name ndc9); run;
data rxcov.edoxaban_ndc;		set rxref.edoxaban_ndc(keep=drug_name ndc9); run;
data rxcov.heparin_ndc;			set rxref.heparin_ndc(keep=drug_name ndc9); run;
data rxcov.biguanide_ndc;			set rxref.biguanide_ndc(keep=drug_name ndc9); 	run;
data rxcov.dpp_ndc; 				set rxref.dpp_ndc(keep=drug_name ndc9);	run;
data rxcov.glp_ndc;				set rxref.glp_ndc(keep=drug_name ndc9);	run;
data rxcov.sglt_ndc;				set rxref.sglt_ndc(keep=drug_name ndc9); run;
data rxcov.sulfonylurea_ndc;		set rxref.sulfonylurea_ndc(keep=drug_name ndc9); run;
data rxcov.thiazolidinedione_ndc;	set rxref.thiazolidinedione_ndc(keep=drug_name ndc9); run; 
data rxcov.statins_ndc; 			set rxref.statins_ndc(keep = drug_name ndc9); run;
data rxcov.nicotine_varen_ndc;		set rxref.nicotine_varen_ndc(keep =drug_name ndc9); run;
data rxcov.opioids_ndc;				set rxref.opioids_ndc(keep=drug_name ndc9); run;
data rxcov.rivaroxaban_ndc;			set rxref.rivaroxaban_ndc(keep=drug_name ndc9); run;
data rxcov.warfarin_ndc; 			set rxref.warfarin_ndc(keep=drug_name ndc9); run;
data rxcov.saInsulin_ndc; set rxref2.rapidinsulin_ndc(keep=drug_name ndc9); run;

data rxcov.laInsulin_ndc; 
   set rxref2.intermediateInsulin_ndc(keep=drug_name ndc9)
        rxref2.mixedInsulin_ndc(keep=drug_name ndc9)
        rxref2.lai_ndc(keep=drug_name ndc9);
run;

























/*
/************************************************/
/* Creating new definitions*/
/************************************************/
/*
libname alldx10 '/nearline/files/datasources/references/Code Reference Sets/ICD10DX';
*From ACA_coverage gap programe by Omar Diallo;
%macro dx10(name, icd10list);
   %LET N10 = %SYSFUNC(countw(&icd10list,','));
   %DO i=1 %TO &N10; 
      %LET code10_&i = %SYSFUNC(compress(%SCAN(&icd10list, &i, ','),.)); 
   %END;

   %LET newdx10list = ;
   %DO i=1 %TO &N10; %LET newdx10list = &newdx10list "&&code10_&i"; %END;

   data covref.&name._icd10dx(rename=(short_description=label)); set dx10.dx10(keep=code short_description);
      where code in: (&newdx10List); run;
%mend;

/*Define covariates*/
/*
%dx(name= mi,
	   icd10list=%STR(I21, I21.0, I21.01, I21.02, I21.09, I21.1, I21.11, I21.19, I21.2, I21.21, I21.29, I21.3,
						I21.4, I22, I22.0, I22.1, I22.2, I22.8, I22.9 ))


%dx(name= cerobrovasculardz,
	   	icd10list=%STR(I60,I60.0, I60.00, I60.01, I60.02, I60.1, I60.10, I60.11, I60.12, I60.2, I60.20, I60.21, I60.22, 160.3, 160.30,
						I60.31, I60.32, I60.4, I60.5, I60.50, I60.51, I60.52, I60.6, I60.7, I60.8, I60.9, I61, I6.10, I61.1, I61.2, I61.3,
						I61.4, I61.5, I61.6, I61.8, I61.9, I63, I63.0, I63.00, I63.01, I63.011, I63.012, I63.013, I63.019, I63.02, I63.03, I63.031,
						I63.032, I63.033, I63.039, I63.09, I63.1, I63.10, I63.11, I63.111, I63.112, I63.113, I63.119, I63.12, I63.13, I63.131, I63.132,
						I63.133, I63.139, I63.19, I63.2, I63.20, I63.21, I63.211, I63.212, I63.213, I63.219, I63.22, I63.23, I63.231, I63.232, I63.233,
						I63.239, I63.29, I63.3, I63.30, I63.31, I63.311, 163.311, I63.312, I63.313, I63.319, I63.32, I63.321, I63.322, I63.323, I63.329,
						I63.34, I63.341, I63.342, I63.343, I63.349, I63.39, I63.4, I63.40, I63.41, I63.411, I63.412, I64.413, I63.419, I63.42, I63.421,
						I63.422, I63.423, I63.429, I63.43, I63.431, I63.432, I63.433, I63.439, I63.44, I63.441, I63.442, I63.443, I63.449, I63.49, I63.5, I63.50, 
						I63.51, I63.511, I63.512, I63.513, I63.519, I63.52, I63.521, I63.522, I63.523, I67, I67.1, I67.2, I67.81, I67.82, I67.84, I67.841, I67.848, I67.89, I67.9,
						I69, I69.0))

%dx(name= copd,
	   icd10list=%STR(J40, J41.0, J41.1, J41.8, J42, J43.0, J43.1, J43.2, J43.9, J44.0, J44.1, J44.9,
						J47.0, J47.1, J47.9, J98.2, J98.3 ))

/*%dx(name= ischemichtdz,
	   icd10list=%STR(J40, J41.0, J41.1, J41.8, J42, J43.0, J43.1, J43.2, J43.9, J44.0, J44.1, J44.9,
						J47.0, J47.1, J47.9, J98.2, J98.3 ))*/

proc sql; 
   create table covref.stroke_icd9dx as 
   select 'ICD10' as code_type, start as code, substr(label, index(label,'-')+1) as description
   from alldx.dx 
   where start in ('5550' '5551' '5552' '5559' '5560' '5561' '5563' 
               '5564' '5565' '5566' '5568' '5569');
quit;

proc sql; 
   create table covref.connectiveTissue_icd9dx as 
   select 'ICD9' as code_type, start as code, substr(label, index(label,'-')+1) as description
   from alldx.dx 
   where substr(start,1,3) in ('710' '714' '715' '720' '721' '725') 
            or   start      in ('6954' '7293' '74181' '75191');
quit;


























/* example 1a: pull reference datasets from /mnt/files/datasources/references/Definitions/covariates */
libname ref '/mnt/files/datasources/references/Definitions/covariates';

data covref.dmi_icd9dx;        set ref.dmii_icd9dx;       run;
data covref.copd_icd9dx;       set ref.copd_icd9dx;       run;
data covref.depression_icd9dx; set ref.depression_icd9dx; run;



/* example 1b: healthcare utilization variables - these are the same as any other covariate */
/*   use /mnt/files/datasources/references/Definitions/covariates/  */
libname ref '/mnt/files/datasources/references/Definitions/covariates';

data covref.psa_cpt;            set hcref.psa_cpt;            run;
data covref.fecalbloodtest_cpt; set hcref.fecalbloodtest_cpt; run;


/* example 1c: use definitions from another project -- pull reference datasets directly    */
/*   from that project -- /mnt/files/projects/<database>/<project>/data/coderef/covariates */
libname incretin '/mnt/files/projects/medicare/incretinCRC/data/coderef/covariates';
data covref.benigncrc; set incretin.benigncrc; run;

libname incrx '/mnt/files/projects/medicare/incretinCRC/data/coderef/covariates/rxcovar';
data rxcovar.bb; set incrx.bb; run;



/* example 1d: use drug class definitions already defined -- pull from */
/*   /mnt/files/datasources/references/Definitions/drugs               */
/* See defineExposure.sas for additional examples of creating reference datasets using NDC codes */
libname rxref '/mnt/files/datasources/references/Definitions/drugs';

data rxcovar.arb;  set rxref.arb_ndc(keep=drug_name ndc9); run;
data rxcovar.acei; set rxref.acei_ndc(keep=drug_name ndc9); run;

data rxcovar.saInsulin; set rxref.rapidinsulin_ndc(keep=drug_name ndc9); run;

data rxcovar.laInsulin; 
   set rxref.intermediateInsulin_ndc(keep=drug_name ndc9)
        rxref.mixedInsulin_ndc(keep=drug_name ndc9)
        rxref.lai_ndc(keep=drug_name ndc9);
run;







/****************************************/
/* EXAMPLE 2: CREATING A NEW DEFINITION */
/****************************************/

/* example 2a: definition using only ICD-9 diagnosis codes -- pull a subset of codes */
/*      from the dataset containing all ICD-9 diagnosis codes, which is stored under */
/*      /mnt/files/datasources/reference/Code Reference Sets/ICD9DX                  */
libname alldx '/nearline/files/datasources/references/Code Reference Sets/ICD9DX';
proc sql; 
   create table covref.gi_icd9dx as 
   select 'ICD9' as code_type, start as code, substr(label, index(label,'-')+1) as description
   from alldx.dx 
   where start in ('5550' '5551' '5552' '5559' '5560' '5561' '5563' 
               '5564' '5565' '5566' '5568' '5569');
quit;

proc sql; 
   create table covref.connectiveTissue_icd9dx as 
   select 'ICD9' as code_type, start as code, substr(label, index(label,'-')+1) as description
   from alldx.dx 
   where substr(start,1,3) in ('710' '714' '715' '720' '721' '725') 
            or   start      in ('6954' '7293' '74181' '75191');
quit;


/* example 2b: definition using only ICD-9 procedure codes -- pull a subset of codes */
/*      from the dataset containing all ICD-9 diagnosis codes, which is stored under */
/*      /mnt/files/datasources/reference/Code Reference Sets/ICD9Proc                */
libname allproc '/mnt/files/datasources/references/Code Reference Sets/ICD9Proc';

data hcuse.colonoscopy_icd9p; 
   length code $5 code_type $7 description $250; 
   set allproc.icd9;
   where icd9 in ('4521' '4522' '4523' '4524' '4821' '4823');

   code = icd9;
   code_type = 'ICD9P';
   if medicare ne '' then description = medicare; else description=cms;

   keep code code_type description;
run;


/* example 2c: definition using only CPT/HCPC procedure codes -- pull a subset of codes   */
/*      from the dataset containing all CPT & HCPC procedure codes, which is stored under */
/*      /mnt/files/datasources/reference/Code Reference Sets/CPT_HCPCS                    */
libname allcpt '/mnt/files/datasources/references/Code Reference Sets/CPT_HCPCS';

data colonoscopy1; 
   length code_type $7 ; 
   set allcpt.cpt;
    where code in ('44388' '44389' '44390' '44391' '44392' '44393' '44394' '45300' '45305'
        '45330' '45331' '45332' '45333' '45334' '45335' '45337' '45338' '45339' '45340'
         '45345' '45355' '45378' '45379' '45380' '45381' '45382' '45383' '45384' '45385' '45387');
   code_type = 'CPT';
   keep code code_type description;
run;

data colonoscopy2;
   length code_type $7;
   set allcpt.hcpcs (keep=code description);
   where code in ('G0104' 'G0105' 'G0106' 'G0120' 'G0121');
   code_type = 'HCPCS';
run;

data covref.colonoscopy_cpt;
   set colonoscopy1 colonoscopy2; 
run;




/* example 2f: new medication definitions  */
/*     Option 1: download a list of NDC codes from the ICISS website based on your search criteria */
/*     Option 2: work with Virginia to get a list of NDC codes based on ATC codes -- use the 
          following website: http://www.whocc.no/atc_ddd_index */



