options source source2 msglevel=I mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

%setup(1pct, defineOutcome, saveLog=N);

libname locref "/local/projects/medicare/ablocker/data/coderef";
libname outref "/local/projects/medicare/ablocker/documentation/definitions/outcomes";

*stroke;
data outref.stroke_icd9dx;
	set locref.stroke_dx9;
run; 

data outref.stroke_icd10dx;
	set locref.stroke_dx10;
run; 

*heart failure;
data outref.hf_icd9dx;
	set locref.hf_dx9;
run;

data outref.hf_icd10dx;
	set locref.hf_dx10;
run;

*m.i;
data outref.mi_icd9dx;
	set locref.mi_dx9;
run; 

data outref.mi_icd10dx;
	set locref.mi_dx10;
run;

**procedures;
*PCIP;
data outref.pcip_icd9p;
	set locref.pci_pr9;
run;

data outref.pcip_icd10p;
	set locref.pci_pr_10;
run;
proc datasets lib=outref nolist nodetails; modify pcip_icd10p; rename icd10pr = code; run; quit;

data outref.pcip_cpt;
	set locref.pcip_cpt_final;
run; 

**CABG;

data outref.cabg_icd9p;
	set locref.cabg_pr9;
run;

data outref.cabg_icd10p;
	set locref.cabg_pr10;
run; 

data outref.cabg_cpt;
	set locref.cabg_cpt;
run;

**PNEUMONIA;

data outref.pneumonia_icd9dx;
	set locref.pneumonia_dx9;
run;

data outref.pneumonia_icd10dx;
	set locref.pneumonia_dx10;
run;

**Injury;
data outref.injury_icd9dx;
	set locref.inj_dx9;
run;

data outref.injury_icd10dx;
	set locref.inj_dx10;
run;
