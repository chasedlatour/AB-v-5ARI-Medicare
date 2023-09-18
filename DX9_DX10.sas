options source source2 msglevel=I mcompilenote=all mautosource 
     sasautos=(SASAUTOS "/local/projects/medicare/ablocker/programs/macros");

libname locref '/local/projects/medicare/ablocker/data/coderef'; 
* Acute urinary retention dx9;
data locref.aur_dx9;
	set locref.aur_dx_final;
	IF code_type = "ICD10" THEN DELETE;
RUN;
	
*Acute urinary rentention dx10;
data locref.aur_dx10;
	set locref.aur_dx_final;
	IF code_type = "ICD9" THEN DELETE;
RUN;

***heart failure dx9 and 10; 
data locref.hf_dx9; 
	SET locref.hf_dx;
	IF code_type = "ICD10" THEN DELETE;
RUN; 

data locref.hf_dx10; 
	SET locref.hf_dx;
	IF code_type = "ICD9" THEN DELETE;
RUN; 

**MI dx9 and dx10;
data locref.mi_dx9; 
	SET locref.mi_dx;
	IF code_type = "ICD10" THEN DELETE;
RUN; 

data locref.mi_dx10; 
	SET locref.mi_dx;
	IF code_type = "ICD9" THEN DELETE;
RUN; 


***chdz dx9 and dx10; 
data locref.chdz_dx9; 
	SET locref.chdz_dx_final;
	IF code_type = "ICD10" THEN DELETE;
RUN; 

data locref.chdz_dx10 ;
	SET locref.chdz_dx_final;
	IF code_type = "ICD9" THEN DELETE;
RUN; 

**CKD dx9 and dx10; 
data locref.ckd_dx9; 
	SET locref.ckd_dx;
	IF code_type = "ICD10" THEN DELETE;
RUN; 

data locref.ckd_dx10 ;
	SET locref.ckd_dx;
	IF code_type = "ICD9" THEN DELETE;
RUN; 

**Tobacco use;
data locref.tobacco_dx9;
	SET locref.tobacco_use_dx_px;
	IF code_type = "ICD10"  | code_type = "CPT" THEN DELETE;
RUN;

data locref.tobacco_dx10;
	SET locref.tobacco_use_dx_px;
	IF code_type = "ICD9"  | code_type = "CPT" THEN DELETE;
RUN;

data locref.tobacco_cpt;
	SET locref.tobacco_use_dx_px;
	IF code_type = "ICD9"  | code_type = "ICD10" THEN DELETE;
RUN;

**OBESITY;
data locref.obesity_dx9;
	SET locref.obesity;
	IF code_type = "ICD10" THEN DELETE;
RUN;

data locref.obesity_dx10;
	SET locref.obesity;
	IF code_type = "ICD9" THEN DELETE;
RUN;
