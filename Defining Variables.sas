
/***************************************************************
Program Name: ICD 9 to 10 mapping.sas
Programmar: Chase
Description: Code that uses Alan Kinlaw's macro to translate
ICD-9 codes to ICD-10 codes. These codes will then be cross-
referenced with our clinicians.
Date last modified: 3/28/22
***************************************************************/


libname projlib "/local/projects/medicare/ablocker/data/coderef";



/************CABG Procedure Codes**************/

*Had originally used the code below but decided to re-write it;

*ICD-9;
data icd9_cabg; set projlib.icd9to10pr;
			where source in:('361','362');
				run;
data cabg2; set icd9_cabg (KEEP = source);;
	rename source = code;
run;
proc sql;
	create table projlib.cabg_pr9 as
	select distinct *
	from cabg2;
	run;


*ICD-10;
data icd10_cabg; set projlib.icd10to9pr;
			where source in:('0210','0211','0212','0213');
				run;
data cabg2; set icd10_cabg (KEEP = source);
	rename source = code;
run;
proc sql;
	create table projlib.cabg_pr10 as
	select distinct *
	from cabg2;
	run;
	proc print data=projlib.cabg_pr10;run;



/*CABG ICD-9 procedure codes were contained in nearline in the covariate
folder on the n2 server. These are included below.*/


data icd9_pr_codelist; input icd9_pr_self $; cards;
	361
	3610
	3611
	3612
	3613
	3614
	3615
	3616
	3617
	3619
	362
	; 
run;

%gemsmap(cabg,pr);

data projlib.cabg_pr9;
set icd9_pr_codelist;
run;

*Add some codes that think should have been included in the FBM mapping for CABG;
	**Note that the dataset has already been renamed;

proc sql;
	insert into projlib.cabg_pr10
		set icd10pr = "0210344"
		set icd10pr = "02103D4"
		set icd10pr = "0210444"
		set icd10pr = "0211344"
		set icd10pr = "02113D4"
		set icd10pr = "0211444"
		set icd10pr = "0212344"
		set icd10pr = "02123D4"
		set icd10pr = "0212444"
		set icd10pr = "02124D4"
		set icd10pr = "0213344"
		set icd10pr = "02133D4"
		set icd10pr = "0213444";
		quit;

data projlib.cabg_pr10;
set projlib.cabg_pr10;
	if SUBSTR(icd10pr, 1, 4) = "021K" then delete;
	if SUBSTR(icd10pr, 1, 4) = "021L" then delete;
run;
proc print data=test; run;


/**** print out the ACEI NDCs********/

libname drugcode "/nearline/files/datasources/references/Definitions/drugs";

proc export data=drugcode.acei_ndc dmbs=xlsx
	outfile = "/local/projects/medicare/ablocker/data/coderef/acei_ndc.xlsx"
	replace;
run;

/**** print out the ARB NDCs********/

libname drugcode "/nearline/files/datasources/references/Definitions/drugs";

proc export data=drugcode.arb_ndc dmbs=xlsx
	outfile = "/local/projects/medicare/ablocker/data/coderef/arb_ndc.xlsx"
	replace;
run;


/**** print out the BB NDCs********/

libname drugcode "/nearline/files/datasources/references/Definitions/drugs";

proc export data=drugcode.bb_ndc dmbs=xlsx
	outfile = "/local/projects/medicare/ablocker/data/coderef/bb_ndc.xlsx"
	replace;
run;



/************Injury or Poisoning Diagnosis Codes**************/

*Get all teh diagnosis codes;
data icd9_dx_codelist1; set projlib.icd9to10dx;
			where source in:('800', '801', '802', '803', '804', '805', '806', 
							'807', '808', '809', '810', '811', '812', '813',  
							'814', '815', '816', '817', '818', '819', '820',  
							'821', '822', '823', '824', '825', '826', '827',  
							'828', '829', '830', '831', '832', '833', '834',  
							'835', '836', '837', '838', '839', '840', '841',  
							'842', '843', '844', '845', '846', '847', '848',  
							'849', '850', '851', '852', '853', '854', '855',  
							'856', '857', '858', '859', '860', '861', '862',  
							'863', '864', '865', '866', '867', '868', '869',  
							'870', '871', '872', '873', '874', '875', '876',  
							'877', '878', '879', '880', '881', '882', '883',  
							'884', '885', '886', '887', '888', '889', '890',  
							'891', '892', '893', '894', '895', '896', '897',  
							'898', '899', '900', '901', '902', '903', '904',  
							'905', '906', '907', '908', '909', '910', '911',  
							'912', '913', '914', '915', '916', '917', '918',  
							'919', '920', '921', '922', '923', '924', '925',  
							'926', '927', '928', '929', '930', '931', '932',  
							'933', '934', '935', '936', '937', '938', '939', 
							 '940', '941', '942', '943', '944', '945', '946',  
							'947', '948', '949', '950', '951', '952', '953',  
							'954', '955', '956', '957', '958', '959', '960',  
							'961', '962', '963', '964', '965', '966', '967',  
							'968', '969', '970', '971', '972', '973', '974',  
							'975', '976', '977', '978', '979', '980', '981',  
							'982', '983', '984', '985', '986', '987', '988',  
							'989', '990', '991', '992', '993', '994', '995',  
							'996', '997', '998', '999');
							icd9_dx_self = source;
							drop source;
				run;

proc sql; create table icd9_dx_codelist as select distinct(icd9_dx_self) from icd9_dx_codelist1; quit;

%gemsmap(inj,dx);

*Make the final codelists for injury;

data projlib.inj_dx9;
set icd9_dx_codelist;
	code = icd9_dx_self;
	drop icd9_dx_self;
run;

proc export data=projlib.inj_dx9 dbms=xlsx
	outfile = "/local/projects/medicare/ablocker/data/coderef/inj_icd9.xlsx" replace;
run;


data projlib.inj_dx10;
set projlib.inj_dx_fbm_final;
	where fbm_forward_backward = 1;
	code = icd10dx;
	keep code;
run;

proc export data=projlib.inj_dx10 dbms=xlsx
	outfile = "/local/projects/medicare/ablocker/data/coderef/inj_icd10.xlsx" replace;
run;


/************CHD Diagnosis Codes**************/

*Get all teh diagnosis codes;
data _0; set projlib.icd9to10dx;
			where source in:('410','411','412','413','414');
				run;


data icd9_dx_codelist; input icd9_dx_self $; cards;
	41000                                                                                                 
	41001                                                                                                 
	41002                                                                                                 
	41010                                                                                                 
	41011                                                                                                 
	41012                                                                                                 
	41020                                                                                                 
	41021                                                                                                 
	41022                                                                                                 
	41030                                                                                                 
	41031                                                                                                 
	41032                                                                                                 
	41040                                                                                                 
	41041                                                                                                 
	41042                                                                                                 
	41050                                                                                                 
	41051                                                                                                 
	41052                                                                                                 
	41060                                                                                                 
	41061                                                                                                 
	41062                                                                                                 
	41070                                                                                                 
	41071                                                                                                 
	41072                                                                                                 
	41080                                                                                                 
	41081                                                                                                 
	41082                                                                                                 
	41090                                                                                                 
	41091                                                                                                 
	41092                                                                                                 
	4110                                                                                                  
	4111                                                                                                  
	41181                                                                                                 
	41189                                                                                                 
	412                                                                                                   
	4130                                                                                                  
	4131                                                                                                  
	4139                                                                                                  
	41400                                                                                                 
	41401                                                                                                 
	41402                                                                                                 
	41403                                                                                                 
	41404                                                                                                 
	41405                                                                                                 
	41406                                                                                                 
	41407                                                                                                 
	41410                                                                                                 
	41411                                                                                                 
	41412                                                                                                 
	41419                                                                                                 
	4142                                                                                                  
	4143                                                                                                  
	4144                                                                                                  
	4148                                                                                                  
	4149
	4292
	V4581
	; 
run;
data projcode.chdz_dx9_final;
set icd9_dx_codelist; run;

%gemsmap(chdz,dx);

proc export data=projcode.chf_icd9dx dbms=xlsx
	outfile = "/local/projects/medicare/ablocker/data/coderef/chf_icd9.xlsx" replace;
run;

**Final CHDZ Codelist;

data projlib.chdz_dx_final; input code_type $ code $ @@; cards;
	ICD10	I20		ICD10	I200		ICD10	I201
	ICD10	I208 	ICD10	I209 		ICD10	I21 
	ICD10	I210 	ICD10	I2101 		ICD10	I2102 
	ICD10	I2109 	ICD10	I211 		ICD10	I2111 
	ICD10 	I2119 	ICD10	I212 		ICD10	I2121 
	ICD10	I2129 	ICD10	I213		ICD10	I214
	ICD10	I219 	ICD10	I21A1		ICD10	I21A9 
	ICD10	I22 	ICD10	I220 		ICD10	I221 
	ICD10	I222 	ICD10	I228 		ICD10	I229
	ICD10	I24 	ICD10	I240 		ICD10	I241 
	ICD10	I248 	ICD10	I249 		ICD10	I25 
	ICD10	I251 	ICD10	I2510 		ICD10	I2511 
	ICD10	I25110 	ICD10	I25111 		ICD10	I25118 
	ICD10	I25119 	ICD10	I252 		ICD10	I253 
	ICD10	I254 	ICD10	I2541 		ICD10	I2542 
	ICD10	I255 	ICD10	I256 		ICD10	I257 
	ICD10	I2570 	ICD10	I25700		ICD10	I25701
	ICD10	I25708 	ICD10	I25709		ICD10	I2571
	ICD10	I25710 	ICD10	I25711 		ICD10	I25718 
	ICD10	I25719 	ICD10	I2572 		ICD10	I25720 
	ICD10	I25721 	ICD10	I25728 		ICD10	I25729 
	ICD10	I2573 	ICD10	I25730 		ICD10	I25731 
	ICD10	I25738 	ICD10	I25739 		ICD10	I2575 
	ICD10	I25750 	ICD10	I25751 		ICD10	I25758 
	ICD10	I25759 	ICD10	I2576 		ICD10	I25760 
	ICD10	I25761 	ICD10	I25768 		ICD10	I25769 
	ICD10	I2579 	ICD10	I25790 		ICD10	I25791 
	ICD10	I25798 	ICD10	I25799 		ICD10	I258 
	ICD10	I2581 	ICD10	I25810 		ICD10	I25811 
	ICD10	I25812 	ICD10	I2582 		ICD10	I25.83 
	ICD10 	I2584 	ICD10	I2589 		ICD10	I259 
	ICD10	Z951
	ICD9	41000 	ICD9	41001		ICD9	41002                                                                                                 
	ICD9	41010	ICD9	41011		ICD9	41012                                                                                                 
	ICD9	41020	ICD9	41021		ICD9	41022                                                                                                 
	ICD9	41030   ICD9	41031       ICD9	41032                                                                                                 
	ICD9	41040   ICD9	41041       ICD9	41042                                                                                                 
	ICD9	41050   ICD9	41051       ICD9	41052                                                                                                 
	ICD9	41060   ICD9	41061       ICD9	41062                                                                                                 
	ICD9	41070   ICD9	41071       ICD9	41072                                                                                                 
	ICD9	41080   ICD9	41081       ICD9	41082                                                                                                 
	ICD9	41090   ICD9	41091       ICD9	41092                                                                                                 
	ICD9	4110    ICD9	4111        ICD9	41181                                                                                                 
	ICD9	41189   ICD9	412         ICD9	4130                                                                                                  
	ICD9	4131    ICD9	4139        ICD9	41400                                                                                                 
	ICD9	41401   ICD9	41402       ICD9	41403                                                                                                 
	ICD9	41404   ICD9	41405       ICD9	41406                                                                                                 
	ICD9	41407   ICD9	41410       ICD9	41411                                                                                                 
	ICD9	41412   ICD9	41419       ICD9	4142                                                                                                  
	ICD9	4143    ICD9	4144        ICD9	4148                                                                                                  
	ICD9	4149	ICD9	4292		ICD9	V4581
	; 
run;


/************Stroke/TIA Diagnosis Codes**************/

*Get all the diagnosis codes of-interest for ICD-9 codes;
data projlib.stroke_dx9; set projlib.icd9to10dx;
			where source in:('348','34982','430','431','432',
							 '43301', '43311', '43321', '43331',
							 '43391', '43401', '43411', '43491',
							 '436', '852', '853', '854');
			*where source in:('430','431','433','434','436','437','438');
			rename source = code;
				run;
data projlib.stroke_dx9;
set projlib.stroke_dx9 (KEEP = code);
	label code = "Code";
run;

data projlib.stroke_dx10; set projlib.icd10to9dx;
	where source in: ('G92', 'G931', 'G934', 'G935', 
					  'G936', 'G9389', 'G939', 'I60', 'I61', 
					  'I62', 'I6300', 'I6301', 'I6302', 
					  'I6303', 'I6310', 'I6311', 'I6312', 
					  'I6313', 'I632', 'I633', 'I634', 'I635', 'I636',
					  'I638', 'I639', 'I6783', 'I6789', 'S0190', 'S061', 
					  'S062', 'S0630', 'S0634', 'S0635', 'S0636', 
					  'S064', 'S065', 'S066', 'S068', 'S069');
	*where source in: ('I60','I61','I63','I67','I69');
	rename source = code;
run;
data projlib.stroke_dx10;
set projlib.stroke_dx10 (keep = code);
	label code = "Code";
run;







/************IntraCranial Hemorrhage Diagnosis Codes**************/

*Get all the diagnosis codes;
data _0; set projlib.icd9to10dx;
			where source in:('430','431','432','852','853');
				run;
proc sql; select distinct(source) from _0; quit;


data icd9_dx_codelist; input icd9_dx_self $; cards;
	430                                                                                                   
	431                                                                                                   
	4320                                                                                                  
	4321                                                                                                  
	4329                                                                                                  
	85200                                                                                                 
	85201                                                                                                 
	85202                                                                                                 
	85203                                                                                                 
	85204                                                                                                 
	85205                                                                                                 
	85206                                                                                                 
	85209                                                                                                 
	85210                                                                                                 
	85211                                                                                                 
	85212                                                                                                 
	85213                                                                                                 
	85214                                                                                                 
	85215                                                                                                 
	85216                                                                                                 
	85219                                                                                                 
	85220                                                                                                 
	85221                                                                                                 
	85222                                                                                                 
	85223                                                                                                 
	85224                                                                                                 
	85225                                                                                                 
	85226                                                                                                 
	85229                                                                                                 
	85230                                                                                                 
	85231                                                                                                 
	85232                                                                                                 
	85233                                                                                                 
	85234                                                                                                 
	85235                                                                                                 
	85236                                                                                                 
	85239                                                                                                 
	85240                                                                                                 
	85241                                                                                                 
	85242                                                                                                 
	85243                                                                                                 
	85244                                                                                                 
	85245                                                                                                 
	85246                                                                                                 
	85249                                                                                                 
	85250                                                                                                 
	85251                                                                                                 
	85252                                                                                                 
	85253                                                                                                 
	85254                                                                                                 
	85255                                                                                                 
	85256                                                                                                 
	85259                                                                                                 
	85300                                                                                                 
	85301                                                                                                 
	85302                                                                                                 
	85303                                                                                                 
	85304                                                                                                 
	85305                                                                                                 
	85306                                                                                                 
	85309                                                                                                 
	85310                                                                                                 
	85311                                                                                                 
	85312                                                                                                 
	85313                                                                                                 
	85314                                                                                                 
	85315                                                                                                 
	85316                                                                                                 
	85319
	8002
	8003
	8007
	8008
	8012
	8013
	8017
	8018
	8032
	8033
	8037
	8038
	8042
	8043
	8047
	8048
	; 
run;
data projcode.inth_dx9_final; set icd9_dx_codelist (RENAME=(icd9_dx_self = code)); run;


%gemsmap(inth,dx);



/************Diabetes Diagnosis Codes**************/

*Get all the diagnosis codes;

data icd9_dx_codelist; input icd9_dx_self $; cards;
	24900
	24901
	24910
	24911
	24920
	24921
	24930
	24931
	24940
	24941
	24950
	24951
	24960
	24961
	24970
	24971
	24980
	24981
	24990
	24991
	25000
	25001
	25002
	25003
	25010
	25011
	25012
	25013
	25020
	25021
	25022
	25023
	25030
	25031
	25032
	25033
	25040
	25041
	25042
	25043
	25050
	25051
	25052
	25053
	25060
	25061
	25062
	25063
	25070
	25071
	25072
	25073
	25080
	25081
	25082
	25083
	25090
	25091
	25092
	25093
	3572
	36201
	36202
	36203
	36204
	36205
	36206
	36641
	; 
run;


%gemsmap(diab,dx);


/************Congestive Heart Failure**************/

*Get all the diagnosis codes;

data icd9_dx_codelist; input icd9_dx_self $; cards;
	428
	4280
	4281
	4282
	42820
	42821
	42822
	42823
	4283
	42830
	42831
	42832
	42833
	4284
	42840
	42841
	42842
	42843
	4289
	40201
	40211
	40291
	40401
	40403
	40411
	40413
	40491
	; 
run;


%gemsmap(chfd,dx);



/*********High cholesterol*********/

data icd9_dx_codelist; input icd9_dx_self $; cards;
	2720
	2721
	2722
	2723
	2724
	; 
run;

%gemsmap(hchl,dx);

data projlib.hchl_dx_fbm_final;
set projlib.hchl_dx_fbm_final (KEEP = icd10dx); 
run;

proc sql;
	insert into projlib.hchl_dx_fbm_final
		set	icd10dx = "E780";
		quit;


/******Acute Urinary Retention******/

*Want to creat this sas data file;

data projlib.aur_dx_final; input code_type $ code $; cards;
	ICD10 R33
	ICD10 R330
	ICD10 R338
	ICD10 R339
	ICD9  7882
	ICD9  78820
	ICD9  78821
	ICD9  78829
	;
run;


/*****Myocardial Infarction****/

proc export data=projcode.mi_icd9dx dbms=xlsx
	outfile="/local/projects/medicare/ablocker/data/coderef/mi_icd9dx.xlsx" replace;
run;

data projlib.mi_dx; set projlib.mi_icd9dx; run;

*Insert some codes that were missing;
proc sql;
	insert into projlib.mi_dx
		set	code_type = "ICD9", code = "41000", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41002", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41010", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41012", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41020", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41022", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41030", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41032", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41040", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41042", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41050", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41052", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41060", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41062", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41070", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41072", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41080", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41082", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41090", desc = "Subsequent visit"
		set code_type = "ICD9", code = "41092", desc = "Subsequent visit";
		quit;

*Add in some additional codes;

data mi_dx_10; input code_type $ code $; cards;
	ICD10 I21
	ICD10 I210
	ICD10 I2101
	ICD10 I2102
	ICD10 I2109
	ICD10 I211
	ICD10 I2111
	ICD10 I2119
	ICD10 I212
	ICD10 I2121
	ICD10 I2129
	ICD10 I213
	ICD10 I214
	ICD10 I219
	ICD10 I21A1
	ICD10 I21A9
	ICD10 I22
	ICD10 I220
	ICD10 I221
	ICD10 I222
	ICD10 I228
	ICD10 I229
	;
run;

proc sql;
	create table projlib.mi_dx as
	select * 
	from projlib.mi_dx
	union corresponding
	select *
	from mi_dx_10;
	quit;


/*******Chronic Kidney Disease*******/

*pull in the CKD DX 9 file and add missing codes;
data ckd_dx9; set projlib.ckd_icd9dx; run;

proc sql;
	insert into ckd_dx9
		set	label = "Parent code", code = "0160"
		set	label = "Parent code", code = "2494"
		set	label = "Parent code", code = "2504"
		set	label = "Parent code", code = "581"
		set	label = "Parent code", code = "5818"
		set	label = "Parent code", code = "582"
		set	label = "Parent code", code = "5828"
		set	label = "Parent code", code = "583"
		set	label = "Parent code", code = "5838"
		set	label = "Parent code", code = "584"
		set	label = "Parent code", code = "585";
		quit;

data ckd_dx9; set ckd_dx9;
	code_type = "ICD9";
run;

*pull in the CKD DX 10 file and add missing codes;

data ckd_dx10; set projlib.ckd_icd10dx; run;

proc sql;
	insert into ckd_dx10
		set	label = "Parent code", code = "C64"
		set	label = "Parent code", code = "D300"
		set	label = "Parent code", code = "D410"
		set	label = "Parent code", code = "D411"
		set	label = "Parent code", code = "D412"
		set	label = "Parent code", code = "E082"
		set	label = "Parent code", code = "E092"
		set	label = "Parent code", code = "E102"
		set	label = "Parent code", code = "E112"
		set	label = "Parent code", code = "E132"
		set	label = "Parent code", code = "I12"
		set	label = "Parent code", code = "I13"
		set	label = "Parent code", code = "I131"
		set	label = "Parent code", code = "Q611"
		set	label = "Parent code", code = "Q621"
		set	label = "Parent code", code = "M103"
		set	label = "Parent code", code = "M1031"
		set	label = "Parent code", code = "M1032"
		set	label = "Parent code", code = "M1033"
		set	label = "Parent code", code = "M1034"
		set	label = "Parent code", code = "M1035"
		set	label = "Parent code", code = "M1036"
		set	label = "Parent code", code = "M1037"
		set	label = "Parent code", code = "N00"
		set	label = "Parent code", code = "N01"
		set	label = "Parent code", code = "N02"
		set	label = "Parent code", code = "N03"
		set	label = "Parent code", code = "N04"
		set	label = "Parent code", code = "N05"
		set	label = "Parent code", code = "N06"
		set	label = "Parent code", code = "N07"
		set	label = "Parent code", code = "N133"
		set	label = "Parent code", code = "N14"
		set	label = "Parent code", code = "N17"
		set	label = "Parent code", code = "N18"
		set	label = "Parent code", code = "N25"
		set	label = "Parent code", code = "N258"
		set	label = "Parent code", code = "Q623";
		quit;

data ckd_dx10; set ckd_dx10;
	code_type = "ICD10";
run;

*Merge the two datasets together;
proc sql;
	create table projlib.ckd_dx as
	select *
	from ckd_dx9
	union corresponding
	select *
	from ckd_dx10;
	quit;



/*************************************/







/******Ischemic Heaert Disease******/


data icd9_dx_codelist; input icd9_dx_self $; cards;
	4100
	41000
	41001
	41002
	4101
	41010
	41011
	41012
	4102
	41020
	41021
	41022
	4103
	41030
	41031
	41032
	4104
	41040
	41041
	41042
	4105
	41050
	41051
	41052
	4106
	41060
	41061
	41062
	4107
	41070
	41071
	41072
	4108
	41080
	41081
	41082
	4109
	41090
	41091
	41092
	4110
	4111
	4118
	41181
	41189
	412
	413
	4130
	4131
	4139
	4140
	41400
	41401
	41402
	41403
	41404
	41405
	41406
	41407
	4141
	41410
	41411
	41412
	41419
	4142
	4143
	4144
	4148
	4149
	; 
run;

%gemsmap(ihdz,dx);


/*****PCI - Procedure Codes****/



data icd9_pr_codelist; input icd9_pr_self $; cards;
	066
	3601
	3602
	3603
	3604
	3605
	3606
	3607
	3609
	1755
	; 
run;
data projcode.pci_icd9pr; set icd9_pr_codelist (RENAME=(icd9_pr_self=code)); run;

%gemsmap(pcip,pr);

*Remove codes for excising tongue..;
data projlib.pcip_pr_final;
set projlib.pcip_pr_fbm_final;
	IF icd10pr = "0CB70ZZ" or icd10pr = "0CB73ZZ" or icd10pr = "0CB7XZZ" or icd10pr = "NoPCS" THEN DELETE;
run;

*Give it the name that we want;
data projlib.pic_pr10;
set projlib.pcip_pr_fbm_final;
run;

*Create dataset for the CPT codes;
data projlib.pcip_cpt_final;
	input codetype $ code $;
	cards;
	CPT 92920
	CPT 92924
	CPT 92928
	CPT 92933
	CPT 92937
	CPT 92941
	CPT 92943
	;
run;



/******Chemotherapy*******/

*CPT codelist;
data chemo_cpt_final;
input code $; cards;
	0519F
	36823
	51720
	61517
	95990
	95991
	96400
	96401
	96402
	96405
	96406
	96408
	96409
	96410
	96411
	96412
	96413
	96414
	96415
	96416
	96417
	96420
	96422
	96423
	96425
	96440
	96445
	96446
	96450
	96520
	96521
	96522
	96523
	96530
	96542
	96545
	;
run;
data projcode.chemo_cpt_final;
set chemo_cpt_final;
	codetype = "CPT";
run;

*HCPCS codes;
data chemo_hcpcs_final;
input code $ @@; datalines;
	C8953 C8954 C8955
	G0355 G0357 G0358 G0359 G0360 G0361 G0362 G0370
	J7150
	Q0083 Q0084 Q0085
	S5019 S5020 S9329 S9330 S9331 S9425
	C1086 C1166 C1167 C1178 C9012 C9110 C9127 C9205 C9207
	C9213 C9214 C9215 C9217 C9218 C9235 C9257 C9262 C9414
	C9415 C9417 C9418 C9419 C9420 C9421 C9422 C9423 C9424
	C9425 C9426 C9427 C9429 C9431 C9432 C9433 C9437 C9440
	J0594 J0894 J8510 J8520 J8521 J8530 J8560 J8565 J8600
	J8610 J8700 J8705 J8999 J9000 J9001 J9010 J9017 J9020
	J9025 J9027 J9033 J9035 J9040 J9041 J9045 J9050 J9055
	J9060 J9062 J9065 J9070 J9080 J9090 J9091 J9092 J9093
	J9094 J9095 J9096 J9097 J9098 J9100 J9110 J9120 J9130
	J9140 J9150 J9151 J9170 J9171 J9178 J9180 J9181 J9182
	J9185 J9190 J9200 J9201 J9206 J9207 J9208 J9211 J9230
	J9245 J9250 J9260 J9261 J9263 J9264 J9265 J9266 J9268
	J9270 J9280 J9290 J9291 J9293 J9300 J9303 J9305 J9307
	J9310 J9315 J9320 J9328 J9330 J9340 J9350 J9351 J9355
	J9357 J9360 J9370 J9375 J9380 J9390 J9999
	Q2017 Q2024
	S0087 S0088 S0115 S0116 S0172 S0176 S0178 S0182
	;
run;
data projcode.chemo_hcpcs_final;
set chemo_hcpcs_final;
	codetype = "HCPCS";
run;

*ICD9-10 chemotherapy mapping - diagnosis;
data projlib.chemo_dx9; input code$; cards;
	V581
	V5811
	V5812
	;
run;


data projlib.chemo_dx10;
	input codetype $ code $;
	datalines;
	ICD10 Z511
	ICD10 Z5111
	ICD10 Z5112
	;
run;

*procedure codes: ICD 9-10 mapping;
data icd9_pr_codelist; input icd9_pr_self $; cards;
	0010
	1770
	9925
	9928
	;
run;
%gemsmap(chem,pr);
data projlib.chemo_pr9; set icd9_pr_codelist; run;

*Manually renamed the ICD-10 codelist.;

*NDC Codelist for chemotherapy;
data projlib.chemo_ndc;
	input ndc11 @@;
	cards;
	00004110013 00004110020 00004110022 00004110051
	00004110116 00004110150 00005450704 00005450705
	00005450707 00005450709 00005450723 00005450791
	00015050301 00015050302 00015050401 00015309145
	00054412925 00054413025 00054455015 00054455025
	00054808925 00054813025 00054855003 00054855005
	00054855006 00054855007 00054855010 00054855025
	00081004535 00085124401 00085124402 00085124801
	00085124802 00085125201 00085125202 00085125901
	00085125902 00173004535 00173071325 00182153901
	00182153995 00364249901 00364249936 00378001401
	00378001450 00378326694 00536399801 00536399836
	00555057202 00555057235 00555057245 00555057246 
	00555057247 00555057248 00555057249 00555092701
	00555092801 00555092901 00555094501 00603449921 
	00677161001 00781107601 00781107636 00904174960
	00904174973 51079067005 51079096505 51285050902
	54569571700 54868414300 54868414301 54868414302
	54868414303 54868526000 54868526001 54868526002
	54868526003 54868526004 54868526005 54868526006
	54868526007 54868526008 54868526009 59911587401
	62701094036 62701094099
	;
run;




/*****TRANSPLANT CODES****/

*CPT codes;
data projlib.transplant_cpt;
	input cpt $ @@;
	datalines;
	32851 32852	32853 32854 33935 33945 38240
	44136 47135 47136 48554 50360 50365 
	;
run;

*HCPCS codes;
data projlib.transplant_hcpcps;
	input hcpcs $ @@;
	datalines;
	G0369 Q0510 S2052 S2053 S2054 S2060 S2065 S2152
	;
run;

*ICD-9 Pr;
data projlib.transplant_pr9;
	input code $ @@;
	datalines;
	33.5 33.50 33.51 33.52 33.6 37.51 
	41.94 46.97 50.5 50.51 50.59 52.80 
	52.82 52.83 55.69
	;
run;
data projlib.transplant_pr9;
set projlib.transplant_pr9;
	code = compress(code,'.');
run;

*ICD-10 Procedure;
data pr10; set projlib.icd10to9pr;
			where source in:('0TY00Z','0TY10Z','07YP0Z','0BYC','0BYD',
							'0BYF','0BYG','0BYH','0BYJ','0BYK','0BYL',
							'0BYM','0DY6','0DY8','0DYE','0FY0','0FYG',
							'02YA');
				run;/* proc sql; select distinct(source) from pr10; quit;*/
proc sql;
	create table projlib.transplant_pr10 as
	select distinct(source) as code
	from pr10;
	quit;






/*************FINAL Heart Failure*********/

*This is what was actually used
Adapted from the CCW codelist; 

libname ccw "/nearline/files/datasources/references/Definitions/covariates/CCW";


*ICD-10 codes;
data hf_10_1;
set ccw.hf_icd10dx;
	code_type = "ICD10";
run;

data hf_10_2; input code_type $ code $; cards;
	ICD10	I50	
	ICD10	I502
	ICD10	I503
	ICD10	I504
	;
run;

proc sql;
	create table hf_dx_10 as
	select * 
	from hf_10_1 
	union corresponding
	select *
	from hf_10_2;
	quit;

*ICD-9 codes;

data hf_9_1;
set ccw.hf_icd9dx;
	code_type = "ICD9";
run;

data hf_9_2; input code_type $ code $; cards;
	ICD9	428
	ICD9	4282
	ICD9	4283
	ICD9	4284
	;
run;

proc sql;
	create table projlib.hf_dx as
	select * 
	from hf_dx_10
	union corresponding
	select *
	from hf_9_1
	union corresponding
	select *
	from hf_9_2;
	quit;



/*****************************************/






/*************TOBACCO**************/


data projlib.tobacco_use_dx_px;
	input code_type $ code $ @@; cards;
	ICD9	3051		ICD9	30510		ICD9	30511
	ICD9	30512		ICD9	30513		ICD9	6490
	ICD9	64900		ICD9	64901		ICD9	64902
	ICD9	64903 		ICD9	64904		ICD9	98984
	ICD9	V1582
	ICD10 	F17			ICD10	F172		ICD10	F1720
	ICD10	F17200		ICD10	F17201		ICD10	F17203
	ICD10	F17208		ICD10	F18209		ICD10	F1721
	ICD10	F17210		ICD10	F17211		ICD10	F17213
	ICD10	F17218		ICD10	F17219		ICD10	F1722
	ICD10	F17220		ICD10	F17221		ICD10	F17223
	ICD10	F17228		ICD10	F17229		ICD10	F1729
	ICD10	F17290		ICD10	F17291		ICD10	F17293
	ICD10	F17298		ICD10	F17299		ICD10	O99.33
	ICD10	O99330		ICD10	O99331		ICD10	O99332
	ICD10	O99333		ICD10	O99334		ICD10	O99335
	ICD10	Z716		ICD10	Z720		ICD10	Z87.891
	CPT 	99406		CPT 	99407 		CPT		G0436
	CPT		G0437		CPT		G9016		CPT 	S9453
	CPT		S4995		CPT		G9276		CPT		G9458
	CPT		1034F		CPT		4004F		CPT		4001F
	;
run;




/*****************************************/










/***************OBESITY******************/


data projlib.obesity;
	input code_type $ code $ @@; cards;
	ICD9 	V853		ICD9	V8530 		ICD9	V8531
	ICD9	V8532		ICD9	V8533		ICD9	V8534
	ICD9	V8535		ICD9	V8536		ICD9	V8537
	ICD9	V8538		ICD9	V8539		ICD9	27801
	ICD9	V854		ICD9	V8540		ICD9	V8541
	ICD9	V8542		ICD9	V8543		ICD9	V8544
	ICD9	V8545		ICD9	2780		ICD9	27803
	ICD9	278.00
	ICD10	E660		ICD10	Z6830		ICD10	Z6831
	ICD10	Z6832		ICD10	Z6833		ICD10	Z6834
	ICD10	Z6835		ICD10	Z6836		ICD10	Z6837
	ICD10	Z6838		ICD10	Z6839 		ICD10	E6601
	ICD10	E662 		ICD10	Z684		ICD10	Z6841
	ICD10	Z6842 		ICD10	Z6843	 	ICD10	Z6844 
	ICD10	Z6845		ICD10	E6609		ICD10	E669
	;
run;



/*****************************************/





/*********STROKE - OUTCOME**************/


data stroke_outcome_dx10;
	input code $ @@; cards;
	I60 I60.0 I60.00 I60.01 I60.02 I60.1 I60.10 
	I60.11 I60.12 I60.2 I60.20 I60.21 I60.22 I60.3 
	I60.30 I60.31 I60.32 I60.4 I60.5 I60.50 I60.51 I60.52 
	I60.6 I60.7 I60.8 I60.9 I61 I61.0 I61.1 I61.2 I61.3 I61.4 I61.5 
	I61.6 I61.8 I61.9 I63 I63.0 I63.00 I63.01 I63.011 I63.012 I63.013
	I63.019 I63.02 I63.03 I63.031 I63.032 I63.033 I63.039 I63.09 
	I63.1 I63.10 I63.11 I63.111 I63.112 I63.113 I63.119 I63.12 I63.13
	I63.131 I63.132 I63.133 I63.139 I63.19 I63.2 I63.20 I63.21 I63.211
	I63.212 I63.213 I63.219 I63.22 I63.23 I63.231 I63.232 I63.233 
	I63.239 I63.29 I63.3 I63.30 I63.31 I63.311 I63.312 I63.313 I63.319
	I63.32 I63.321 I63.322 I63.323 I63.329 I63.33 I63.331 I63.332 
	I63.333 I63.339 I63.34 I63.341 I63.342 I63.343 I63.349 I63.39 I63.4
	I63.40 I63.41 I63.411 I63.412 I63.413 I63.419 I63.42 I63.421 I63.422
	I63.423 I63.429 I63.43 I63.431 I63.432 I63.433 I63.439 I63.44 I63.441
	I63.442 I63.443 I63.449 I63.49 I63.5 I63.50 I63.51 I63.511 I63.512 
	I63.513 I63.519 I63.52 I63.521 I63.522 I63.523 I67 I67.0 I67.1 I67.2
	I67.3 I67.4 I67.5 I67.6 I67.7 I67.8 I67.81 I67.82 I67.83 I67.84 I67.841
	I67.848 I67.89 I67.9 I69 I69.0 I69.00 I69.01 I69.010 I69.011 I69.012
	I69.013 I69.014 I69.015 I69.018 I69.019 I69.02 I69.020 I69.021 I69.022
	I69.023 I69.028 I69.03 I69.031 I69.032 I69.033 I69.034 I69.039 I69.04 I69.041
	I69.042 I69.043 I69.044 I69.049 I69.05 I69.051 I69.052 I69.053 I69.054 I69.059
	I69.06 I69.061 I69.062 I69.063 I69.064 I69.065 I69.069 I69.09 I69.090 
	I69.091 I69.092 I69.093 I69.098 I69.1 I69.10 I69.11 I69.110 I69.111 I69.112
	I69.113 I69.114 I69.115 I69.118 I69.119 I69.12 I69.120 I69.121 I69.122 I69.123
	I69.128 I69.13 I69.131 I69.132 I69.133 I69.134 I69.139 I69.14 I69.141 I69.142
	I69.143 I69.144 I69.149 I69.15 I69.151 I69.152 I69.153 I69.154 I69.159 I69.16
	I69.161 I69.162 I69.163 I69.164 I69.165 I69.169 I69.19 I69.190 I69.191 I69.192
	I69.193 I69.198 I69.2 I69.20 I69.21
	;
run;

data projlib.stroke_outcome_dx10;
set stroke_outcome_dx10;
	code = compress(code,".");
run;


/*****************************************/











/*********INTRACRANIAL HEMORRHAGE*********/


proc sql;
	insert into projlib.inth_icd9dx
		set	label = "Parent code", code = "432"
		set	label = "Parent code", code = "8520"
		set	label = "Parent code", code = "8521"
		set	label = "Parent code", code = "8522"
		set	label = "Parent code", code = "8523"
		set	label = "Parent code", code = "8524"
		set	label = "Parent code", code = "8525"
		set	label = "Parent code", code = "8530"
		set	label = "Parent code", code = "852"
		set	label = "Parent code", code = "853"
		set	label = "Parent code", code = "80020"
		set	label = "Parent code", code = "80021"
		set	label = "Parent code", code = "80022"
		set	label = "Parent code", code = "80023"
		set	label = "Parent code", code = "80024"
		set	label = "Parent code", code = "80025"
		set	label = "Parent code", code = "80026"
		set	label = "Parent code", code = "80029"
		set	label = "Parent code", code = "80030"
		set	label = "Parent code", code = "80031"
		set	label = "Parent code", code = "80032"
		set	label = "Parent code", code = "80033"
		set	label = "Parent code", code = "80034"
		set	label = "Parent code", code = "80035"
		set	label = "Parent code", code = "80036"
		set	label = "Parent code", code = "80039"
		set	label = "Parent code", code = "80070"
		set	label = "Parent code", code = "80071"
		set	label = "Parent code", code = "80072"
		set	label = "Parent code", code = "80073"
		set	label = "Parent code", code = "80074"
		set	label = "Parent code", code = "80075"
		set	label = "Parent code", code = "80076"
		set	label = "Parent code", code = "80079"
		set	label = "Parent code", code = "80080"
		set	label = "Parent code", code = "80081"
		set	label = "Parent code", code = "80082"
		set	label = "Parent code", code = "80083"
		set	label = "Parent code", code = "80084"
		set	label = "Parent code", code = "80085"
		set	label = "Parent code", code = "80086"
		set	label = "Parent code", code = "80089"
		set	label = "Parent code", code = "80130"
		set	label = "Parent code", code = "80131"
		set	label = "Parent code", code = "80132"
		set	label = "Parent code", code = "80133"
		set	label = "Parent code", code = "80134"
		set	label = "Parent code", code = "80135"
		set	label = "Parent code", code = "80136"
		set	label = "Parent code", code = "80139"
		set	label = "Parent code", code = "80170"
		set	label = "Parent code", code = "80171"
		set	label = "Parent code", code = "80172"
		set	label = "Parent code", code = "80173"
		set	label = "Parent code", code = "80174"
		set	label = "Parent code", code = "80175"
		set	label = "Parent code", code = "80176"
		set	label = "Parent code", code = "80179"
		set	label = "Parent code", code = "80180"
		set	label = "Parent code", code = "80181"
		set	label = "Parent code", code = "80182"
		set	label = "Parent code", code = "80183"
		set	label = "Parent code", code = "80184"
		set	label = "Parent code", code = "80185"
		set	label = "Parent code", code = "80186"
		set	label = "Parent code", code = "80189"
		set	label = "Parent code", code = "80320"
		set	label = "Parent code", code = "80321"
		set	label = "Parent code", code = "80322"
		set	label = "Parent code", code = "80323"
		set	label = "Parent code", code = "80324"
		set	label = "Parent code", code = "80325"
		set	label = "Parent code", code = "80326"
		set	label = "Parent code", code = "80329"
		set	label = "Parent code", code = "80330"
		set	label = "Parent code", code = "80331"
		set	label = "Parent code", code = "80332"
		set	label = "Parent code", code = "80333"
		set	label = "Parent code", code = "80334"
		set	label = "Parent code", code = "80335"
		set	label = "Parent code", code = "80336"
		set	label = "Parent code", code = "80339"
		set	label = "Parent code", code = "80370"
		set	label = "Parent code", code = "80371"
		set	label = "Parent code", code = "80372"
		set	label = "Parent code", code = "80373"
		set	label = "Parent code", code = "80374"
		set	label = "Parent code", code = "80375"
		set	label = "Parent code", code = "80376"
		set	label = "Parent code", code = "80379"
		set	label = "Parent code", code = "80380"
		set	label = "Parent code", code = "80381"
		set	label = "Parent code", code = "80382"
		set	label = "Parent code", code = "80383"
		set	label = "Parent code", code = "80384"
		set	label = "Parent code", code = "80385"
		set	label = "Parent code", code = "80386"
		set	label = "Parent code", code = "80389"
		set	label = "Parent code", code = "80420"
		set	label = "Parent code", code = "80421"
		set	label = "Parent code", code = "80422"
		set	label = "Parent code", code = "80423"
		set	label = "Parent code", code = "80424"
		set	label = "Parent code", code = "80425"
		set	label = "Parent code", code = "80426"
		set	label = "Parent code", code = "80429"
		set	label = "Parent code", code = "80430"
		set	label = "Parent code", code = "80431"
		set	label = "Parent code", code = "80432"
		set	label = "Parent code", code = "80433"
		set	label = "Parent code", code = "80434"
		set	label = "Parent code", code = "80435"
		set	label = "Parent code", code = "80436"
		set	label = "Parent code", code = "80439"
		set	label = "Parent code", code = "80470"
		set	label = "Parent code", code = "80471"
		set	label = "Parent code", code = "80472"
		set	label = "Parent code", code = "80473"
		set	label = "Parent code", code = "80474"
		set	label = "Parent code", code = "80475"
		set	label = "Parent code", code = "80476"
		set	label = "Parent code", code = "80479"
		set	label = "Parent code", code = "80480"
		set	label = "Parent code", code = "80481"
		set	label = "Parent code", code = "80482"
		set	label = "Parent code", code = "80483"
		set	label = "Parent code", code = "80484"
		set	label = "Parent code", code = "80485"
		set	label = "Parent code", code = "80486"
		set	label = "Parent code", code = "80489";
		quit;


/*****************************************/









/*****************PROSTATECTOMY************************/

*ICD-9 Codes;
data projlib.prostatectomy_pr9; input code $ @@; cards;
	602 6021 6029 603 604 605 6062
	;
run;

*CPT Codes;
data projlib.prostatectomy_cpt; input code $ @@; cards;
	00865 00908 52601 52612 52614 55801 55810
	55812 55815 55821 55831 55840 55842 55845 
	55866 52620 52630
	;
run;

*ICD-10 Codes;
data projlib.prostatectomy_dx10; input code $ @@; cards;
	N5231
	N5234
	;
run;

*FBM to get prostatectomy ICD-10 procedure codes;
data icd9_pr_codelist; input icd9_pr_self $ @@; cards;
602 6021 6029 603 604 605 6062
; run;

%gemsmap(pros,pr);

*Input the ones that actually want;
data prostatectomy; set projlib.icd10to9pr;
			where source in:('0V50','0VB0','0VT0');
				run; proc sql; select distinct(source) from prostatectomy; quit;

data projlib.prostatectomy_pr10; set prostatectomy;
	rename source = code;
run;
data projlib.prostatectomy_pr10;
set projlib.prostatectomy_pr10 (keep = code);
	label code = "Code";
run;




/*****************************************/





/*****************BPH************************/

*ICD-9: BPH with urinary symptoms;
data projlib.bph_wUS_dx9;
input code $ @@;
	cards;
	60001
	60011
	60021
	60091
	;
run;

*ICD-9: BPH without urinary symptoms;
data projlib.bph_woUS_dx9;
input code $ @@;
	cards;
	60000
	60010
	60020
	60090
	;
run;

*ICD-9: All BPH codes;
data projlib.bph_dx9;
input code $ @@;
	cards;
	60001	60011	60021	60091
	60000	60010	60020	60090
	;
run;

*ICD-10: BPH with urinary symptoms;
data projlib.bph_wUS_dx10;
input code $ @@;
	cards;
	N401 N403
	;
run;


*ICD-10: BPH without urinary symptoms;
data projlib.bph_woUS_dx10;
input code $ @@;
	cards;
	N400 N402
	;
run;

*ICD-10: All BPH codes;
data projlib.bph_dx10;
input code $ @@;
	cards;
	N401 	N403	N400 	N402
	;
run;

/*****************************************/







/*****************PROSTATE CANCER************************/

*ICD-9 Codes;
data projlib.prostatecancer_dx9;
input code $ @@;
	cards;
	185 2334 2365 V1046
	;
run;


*ICD-10 Codes;
data projlib.prostatecancer_dx10;
input code $ @@;
	cards;
	C61 D075 D400 Z8546
	;
run;


/*****************************************/








/********************PNEUMONIA*******************/

*Upload the sheet from the Excel file;
proc import datafile="/local/projects/medicare/ablocker/documentation/Variable Identification_Supplement.xlsx"
	out=projlib.pneumonia
	dbms = xlsx;
	sheet = "Pneumonia";
run;

*ICD-9 Codes;
data projlib.pneumonia_dx9;
	set projlib.pneumonia;
	where code_type = "ICD9 Dx" and variable in ("Pneumonia", "Lobar pneumonia");
run;

data projlib.pneumonia_2nd_dx9;
	set projlib.pneumonia;
	where code_type = "ICD9 Dx" and variable not in ("Pneumonia", "Lobar pneumonia");
run;

*ICD-10 Codes;
data projlib.pneumonia_dx10;
	set projlib.pneumonia;
	where code_type = "ICD10 Dx" and variable in ("Pneumonia", "Lobar pneumonia");
run;

data projlib.pneumonia_2nd_dx10;
	set projlib.pneumonia;
	where code_type = "ICD10 Dx" and variable not in ("Pneumonia", "Lobar pneumonia");
run;

/************************************************/












***********************************************************************************************************
***********************************************************************************************************;
***********************************************************************************************************;




 
* EXAMPLE USING DIAGNOSIS CODES WHEN YOU KNOW THE ICD-9-CM CODES YOU NEED ;
	* insert your ICD-9-CM diagnosis codes in the WHERE statement below ; 
	* for rectal cancer, my example ICD-9-CM codes are 154.1 and 154.8 ;
		data _0; set projlib.icd9to10dx;
			where source in:('1541','1548');
				run; proc sql; select distinct(source) from _0; quit;
	* read off the codes from SAS output and insert them on separate lines below ;
	* n.b.: these may be more numerous than the ones you entered because of descendant codes 
			you should make sure that you aren't accidentally including any improper ones! ;
	     data icd9_dx_codelist; input icd9_dx_self $; cards;
1541
1548
; run;

	* in the macro call below, 
		(1) use a four-letter text-string to name your dx of interest (ex: rect below) 
		(2) choose either "dx" (diagnosis) or "pr" (procedure) for the type of codes you are identifying ;	
		%gemsmap(rect,dx);

	* your output will contain the ICD-10-CM codes that mapped through forward-backward mapping to the ICD-9-CM codes you provided.
	* the dataset at projlib.&condition._&codetype._fbm_final shows detailed data on which codes matched on:
		(a) sfm (simple forward mapping)
		(b) sbm (simple backward mapping)
		(c) fbm (forward backward mapping) /*This is the one you want typically*/
 





***********************************************************************************************************
***********************************************************************************************************;
***********************************************************************************************************;




 
* EXAMPLE USING PROCEDURE CODES WHEN YOU KNOW THE ICD-9-CM PROCEDURE CODES YOU NEED ;
	* insert your ICD-9-CM procedure codes in the WHERE statement below ; 
	* for lung lobectomy, my example ICD-9-PCS codes are all codes that start with 32.4 (aka 32.4x) ;
		data _1; set projlib.icd9to10pr;
			where source in:('324');
				run; proc sql; select distinct(source) from _1; quit;
	* read off the codes from SAS output and insert them on separate lines below ;
	* n.b.: these may be more numerous than the ones you entered because of descendant codes 
			you should make sure that you aren't accidentally including any improper ones! ;
	     data icd9_pr_codelist; input icd9_pr_self $; cards;
3241
3249
; run;

	* in the macro call below, 
		(1) use a four-letter text-string to name your dx of interest (ex: rect below) 
		(2) choose either "dx" (diagnosis) or "pr" (procedure) for the type of codes you are identifying ;	
		%gemsmap(lulo,pr);

	* your output will contain the ICD-10-PCS codes that mapped through forward-backward mapping to the ICD-9-PCS codes you provided.
	* the dataset at projlib.&condition._&codetype._fbm_final shows detailed data on which codes matched on:
		(a) sfm (simple forward mapping)
		(b) sbm (simple backward mapping)
		(c) fbm (forward backward mapping)

