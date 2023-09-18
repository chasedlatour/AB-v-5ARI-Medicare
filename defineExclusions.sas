

options sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(1pct, defineExclusions, saveLog=N)

libname locref '/local/projects/medicare/ablocker/data/coderef'; 
libname exclref '/local/projects/medicare/ablocker/documentation/definitions/exclusion';

***icd10 AND icd9 bph;
/*data exclref.bph_icd10dx;
	length dx10 $10;
	input dx10 $ @@;
	datalines;
	N40 R399 N401 N402 N403
	;
run;
data exclref.bph_icd9dx;
	length code $10; 
	input code @@;
	datalines;
	6000 60001 60011 6002 60021 6009 60091
	;
run;*/

data exclref.prostatecancer_icd10dx;
	set locref.prostatecancer_dx10;
run;
data exclref.prostatecancer_icd9dx;
	set locref.prostatecancer_dx10;
run;

data exclref.bphwus_icd10dx;
	set locref.bph_wus_dx10;
run;

data exclref.bphwus_icd9dx;
	set locref.bph_wus_dx9;
run;

data exclref.bphwous_icd10dx;
	set locref.bph_wous_dx10;
run;

data exclref.bphwous_icd9dx;
	set locref.bph_wous_dx9;
run;

***chemotherapy;
data exclref.chemotherapy_cpt;
	length code $5;
	set locref.chemo_hcpcs_final
		 locref.chemo_cpt_final;
run;
data exclref.chemotherapy_icd9dx;
	set locref.chemo_dx9;
run;

data exclref.chemotherapy_icd10dx;
	set locref.chemo_dx10;
run; 

data exclref.chemotherapy_pr9;
	set locref.chemo_pr9;
run; 

data exclref.chemotherapy_pr10;
	set locref.chemo_pr10;
run;

data exclref.chemotherapy; set locref.chemo_ndc; ndc11b = put(ndc11, 11.); drop ndc11 ; run; 
data exclref.chemotherapy_ndc; set exclref.chemotherapy; rename ndc11b = ndc11; run;



data exclref.prostatectomy_cpt; length cpt $5; set locref.prostatectomy_cpt; run; 
/*data exclref.prostatectomy_pr9; set locref.prostatectomy_pr9; run;
data exclref.prostatectomy_pr10; set locref.prostatectomy_pr10; run; */	

***Transplant;

data exclref.transplant_cpt;
	length hcpcs $5 cpt $5;
	set locref.transplant_hcpcps
		locref.transplant_cpt;
		
run; 
 
/*data exclref.transplant_icd10dx;
	set locref.transplant_dx10;
run;*/

/*data exclref.transplant_icd9dx;
	length code $10;
	set locref.transplant_dx9
		locref.transplant_ev9;
run;*/

data exclref.transplant_pr9;
	length code $8;
	set locref.transplant_pr9;
run;

data exclref.transplant_pr10;
	set locref.transplant_pr10;
run;


























					












