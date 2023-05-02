/*****************************************************************************************************/
/* Program:  frailty.sas                                                                             */
/* Purpose:  create flags for indicators of frailty and use indicators to calculate probability of   */
/*           ADL-Dependency based on Faurot et al., PDS 2015. This macro was updated in 2022 for the */
/*			 ICD-10-CM transition (Duchesneau et al., manuscript in progress).						 */
/* Location: This program and the accompanying frailtyEstimates.sas7bitm can be downloaded from the  */
/*           UNC Harry Guess website: http://sph.unc.edu/epid/harry-guess-research-community/.       */                             
/*                                                                                                   */
/* Overview: This macro requires three datasets as inputs: cohort dataset, diagnosis dataset and     */
/*           procedure dataset.  The cohort dataset must contain one record per cohort member and    */
/*           must contain a unique patient-level identifier and a cohort entry date.  The diagnosis  */
/*           dataset must contain one record per diagnosis and must contain the unique person-level  */
/*           identifier and the date of the diagnosis.  The procedure dataset must contain one       */
/*           record per HCPC procedure code and must contain the unique person-level identifier and  */
/*           the date of the procedure.                                                              */
/*                                                                                                   */
/* Macro parameters:                                                                                 */
/*    COHORTDS: name of cohort dataset containing one record per cohort member with the following    */
/*              demographic variables:                                                               */
/*              AGE:  numeric variable containing age at cohort entry date (used to calculate AGE65) */
/*              SEX:  numeric variable: 0=Male, 1=Female                                             */
/*              RACE: character variable: W=White, B=Black, H=Hispanic, O=Other                      */
/*                                                                                                   */
/*    IDVAR:    variable name of unique person-level identifier, present in all three datasets       */
/*    DATEVAR:  variable name of cohort entry date, present in &COHORTDS                             */
/*                                                                                                   */
/*    DXDS:     name of dataset containing one record per diagnosis                                  */
/*    DXVAR:    variable name of diagnosis code, present in &DXDS                                    */
/*    DXDATE:   variable name of date of diagnosis, present in &DXDS                                 */
/*                                                                                                   */
/*    PROCDS:   name of dataset containing one record per procedure                                  */
/*    PROCVAR:  variable name of procedure code, present in &PROCDS                                  */
/*    PROCDATE: variable name of date of procedure, present in &PROCDS                               */
/*                                                                                                   */
/*    MAXDAYS:  length of look-back period for assessing frailty                                     */
/*    LIB:      library name where FrailtyEstimates.sas7bitm is stored                               */
/*    OUTDS:    name of output dataset                                                               */
/*****************************************************************************************************/

%macro frailty(cohortDS=out.cohort2009, idvar=baseid, datevar=svy_dt,
               dxds=allDX, dxvar=dgn, dxdate=from_dt,
               procds=allHCPC, procvar=hcpc, procdate=from_dt,
               maxDays=238, lib=frail, outds=frailty);

	*Flag indicators based on diagnosis codes;
	*Arthritis;
		%let arth_icd9 = 	"710"	"711"	"712"	"714"	"715"	"718"	"725"	"7165"	"7166"	"7168"	"7169"	"7190"	"7191"	"7194"	"7195"	"7199";
		%let arth_icd10 =	"M00" "M01" "M021" "M023" "M028" "M042" "M048" "M049" "M05" "M060" "M061" "M063" "M064"
							"M068" "M069" "M076" "M080" "M082" "M083" "M084" "M088" "M089" "M111" "M112" "M118" "M119"
							"M120" "M128" "M129" "M130" "M131" "M15" "M16" "M17" "M18" "M190" "M191" "M192" "M199" "M220"
							"M221" "M235" "M240" "M241" "M243" "M244" "M245" "M246" "M247" "M248" "M249" "M250" "M252"
							"M253" "M254" "M255" "M256" "M259" "M3210" "M3212" "M3213" "M3214" "M3215" "M3219" "M328"
							"M329" "M33" "M34" "M3500" "M3501" "M3502" "M3503" "M3504" "M3509" "M351" "M352" "M353" "M355"
							"M358" "M359" "M368" "M433" "M434" "M435X2" "M435X3" "M435X4" "M435X5" "M435X6" "M435X7"
							"M435X8" "M435X9" "M79646";

	*Bladder dysfunction;
		%let blad_icd9 =	"5965" 	"5996" 	"7882" 	"7883";
		%let blad_icd10 =	 "N13" "N31" "N32" "N36" "N393" "N394" "N398" "N399" "R32" "R33" "R3914" "R3981";

	*Decubitus ulcer;
		%let decu_icd9 =	"707";
		%let decu_icd10 =	"L89" "L97" "L984";

	*Dementia;
		%let demt_icd9 =	"290" 	"294" 	"331" 	"797" 	"4380" 	"33390" "33392" "33399" "78093";
		%let demt_icd10 =	"F01" "F02" "F03" "F04" "F068" "G138" "G210" "G257" "G2589" "G259" "G26" "G30" "G310"
							"G311" "G3183" "G3184" "G3185" "G3189" "G319" "G911" "G912" "G913" "G918" "G919" "G94"
							"I69010" "I69011" "I69014" "I69015" "I69018" "I69019" "I69110" "I69111" "I69114" "I69115"
							"I69118" "I69119" "I69210" "I69211" "I69215" "I69218" "I69219" "I69310" "I69311" "I69314"
							"I69315" "I69318" "I69319" "I69810" "I69811" "I69814" "I69815" "I69818" "I69819" "I6991"
							"R411" "R412" "R413" "R4181";
	*Heart failure;
		%let hfai_icd9 =	"425" 	"428" 	"4290" 	"4291" 	"4293" 	"4294";
		%let hfai_icd10 =	"I0981" "I110" "I130" "I132" "I255" "I42" "I43" "I50" "I514" "I515" "I517" "I970"
							"I9711" "I97120" "I9713" "I9719";
	*Hyposhock;
		%let hypo_icd9 =	"458" 	"7855" 	"9584" 	"9980";
		%let hypo_icd10 =	"I95" "R57" "R652" "T794" "T811";

	*Lipid abnormality;
		%let lipi_icd9 =	"272";
		%let lipi_icd10 =	"E7130" "E7521" "E7522" "E7524" "E753" "E755" "E756" "E770" "E780" "E781" "E782" "E783"
							"E784" "E785" "E786" "E7870" "E7879" "E788" "E789" "E881" "E8889";
	*Paralysis;	
		%let para_icd9 =	"342" 	"344" 	"4382" 	"4383" 	"4384" 	"4385" 	"7814";
		%let para_icd10 =	"G81" "G82" "G831" "G832" "G833" "G835" "G8389" "G839" "I6903" "I6904" "I6905" "I6906"
							"I6913" "I6914" "I6915" "I6916" "I6923" "I6924" "I6925" "I6926" "I6933" "I6934" "I6935"
							"I6936" "I6983" "I6984" "I6985" "I6986" "I6993" "I6994" "I6995" "I6996" "R295";
	*Parkinson's disease;
		%let park_icd9 =	"332";
		%let park_icd10 =	"G20" "G211" "G212" "G213" "G214" "G218" "G219";

	*Podiatric care;
		%let podi_icd9 =	"700" 	"703" 	"6811";
		%let podi_icd10 =	"L0261" "L0303" "L0304" "L60" "L62" "L84";

	*Psychiatric diagnoses;
		%let psyc_icd9 =	"29" 	"310" 	"311" 	"3000";
		%let psyc_icd10 =	"F01" "F02" "F03" "F04" "F05" "F06" "F07" "F09" "F1013" "F1014" "F1015" "F10180"
							"F10182" "F10188" "F1023" "F1024" "F1025" "F1026" "F1027" "F10280" "F10282" "F1093" "F1094"
							"F1095" "F1096" "F1097" "F10980" "F10982" "F1113" "F1114" "F1115" "F11182" "F1123" "F1124"
							"F1125" "F11282" "F1193" "F1194" "F1195" "F11982" "F1213" "F1215" "F12180" "F1223" "F1225"
							"F12280" "F1293" "F1295" "F12980" "F1313" "F1314" "F1315" "F13180" "F13182" "F1323" "F1324"
							"F1325" "F1326" "F1327" "F13280" "F13282" "F1393" "F1394" "F1395" "F1396" "F1397" "F13980"
							"F13982" "F1413" "F1414" "F1415" "F14180" "F14182" "F1423" "F1424" "F1425" "F14280" "F14282"
							"F1493" "F1494" "F1495" "F14980" "F14982" "F1513" "F1514" "F1515" "F15180" "F15182" "F1523"
							"F1524" "F1525" "F15280" "F15282" "F1593" "F1594" "F1595" "F15980" "F15982" "F1614" "F1615"
							"F16180" "F1624" "F1625" "F16280" "F1694" "F1695" "F16980" "F17203" "F17213" "F17223" "F17293"
							"F1814" "F1815" "F1817" "F18180" "F1824" "F1825" "F1827" "F18280" "F1894" "F1895" "F1897"
							"F18980" "F1913" "F1914" "F1915" "F1916" "F1917" "F19180" "F19182" "F1923" "F1924" "F1925"
							"F1926" "F1927" "F19280" "F19282" "F1993" "F1994" "F1995" "F1996" "F1997" "F19980" "F19982"
							"F20" "F22" "F23" "F24" "F25" "F28" "F29" "F30" "F31" "F320" "F321" "F322" "F323" "F324"
							"F325" "F3289" "F329" "F32A" "F33" "F348" "F349" "F39" "F41" "F482" "F600" "F840" "F843"
							"F845" "F848" "F849" "F99";

	*Rehabilitation services;
		%let reha_icd9 =	"V571" 	"V573" 	"V578" 	"V579" 	"V5721";
		%let reha_icd10 =	"Z5189";
		*Note: rehabilitation services is also identified using CPT codes;

	*Screening;	
		%let scrn_icd9 =	"V76";
		%let scrn_icd10 =	"Z12";

	*Stroke/brain injury;
		%let stro_icd9 =	"348" 	"430" 	"431" 	"432" 	"436" 	"852" 	"853" 	"854" 	"34982" 	"43301" "43311" "43321" "43331" "43391" "43401" "43411" 
							"43491";
		%let stro_icd10 =	"G92" "G931" "G934" "G935" "G936" "G9389" "G939" "I60" "I61" "I62" "I6300" "I6301"
							"I6302" "I6303" "I6310" "I6311" "I6312" "I6313" "I632" "I633" "I634" "I635" "I636" "I638"
							"I639" "I6783" "I6789" "S0190" "S061" "S062" "S0630" "S0634" "S0635" "S0636" "S064" "S065"
							"S066" "S068" "S069";

	*Vertigo;
		%let vert_icd9 =	"386" 	"7804" 	"43885";
		%let vert_icd10 =	"H81" "H82" "H830" "H831" "H832" "R42";

	*Weakness;	
		%let weak_icd9 =	"7282" 	"7283" 	"7993" 	"72887" "V4984";
		%let weak_icd10 =	"M625" "M6281" "M6284" "M6289" "R5381" "R54" "Z740" "Z7401";

	data _temp_dxflags0_;
		set &dxds.;
		*Arthritis;					arthritis=&dxvar. in:(&arth_icd9. &arth_icd10.);
		*Bladder dysfunction;		bladder=&dxvar. in:(&blad_icd9. &blad_icd10.);
		*Decubitus ulcer;			decub=&dxvar. in:(&decu_icd9. &decu_icd10.);
		*Dementia;					dement=&dxvar. in:(&demt_icd9. &demt_icd10.);
		*Heart failure;				hf=&dxvar. in:(&hfai_icd9. &hfai_icd10.);
		*Hyposhock;					hyposhock=&dxvar. in:(&hypo_icd9. &hypo_icd10.);
		*Lipid abnormality;			lipid=&dxvar. in:(&lipi_icd9. &lipi_icd10.);
		*Paralysis;					paralysis=&dxvar. in:(&para_icd9. &para_icd10.);
		*Parkinson's disease;		pd=&dxvar. in:(&park_icd9. &park_icd10.);
		*Podiatric care;			podiatric=&dxvar. in:(&podi_icd9. &podi_icd10.);
		*Psychiatric diagnoses;		psych=&dxvar. in:(&psyc_icd9. &psyc_icd10.);
		*Rehabilitation services;	rehab=&dxvar. in:(&reha_icd9. &reha_icd10.);
		*Screening;					screening=&dxvar. in:(&scrn_icd9. &scrn_icd10.);
		*Stroke/brain injury;		brain_inj=&dxvar. in:(&stro_icd9. &stro_icd10.);
		*Vertigo;					vertigo=&dxvar. in:(&vert_icd9. &vert_icd10.);
		*Weakness;					weakness=&dxvar. in:(&weak_icd9. &weak_icd10.);
	run;

	*Merge diagnosis codes with the cohort dataset;
	proc sql;
		create table _temp_dxflags1_ as
		select distinct a.&idvar., a.&datevar., b.arthritis, b.bladder, b.brain_inj, b.decub, b.dement, b.hf, b.hyposhock, b.lipid,
						b.paralysis, b.pd, b.podiatric, b.psych, b.rehab, b.screening, b.vertigo, b.weakness
		from &cohortds. as a 
        left join _temp_dxflags0_ as b
        on a.&idvar. = b.&idvar. and 0 <= a.&datevar. - b.&dxdate. %IF &maxDays. ^=  %THEN <= &maxDays. ;;
	quit;

	*Create indicators based on procedure codes;

      /* Create indicators based on procedure codes */
	proc sql;
      	create table _temp_hcpcflags_ as 
         select distinct a.&idvar, a.&datevar,

		 	/*Ambulance*/
            case when c.&procvar in ("A0426" "A0427" "A0428" "A0429" "A0999")
                then 1 else 0 end as ambulance,

			/*Home hospital bed*/
            case when c.&procvar in ("E0250" "E0251" "E0255" "E0256" "E0260" "E0261" "E0265" "E0266" "E0270"
                                     "E0290" "E0291" "E0292" "E0293" "E0294" "E0295" "E0296" "E0297" "E0301"
                                     "E0302" "E0303" "E0304" "E0316")
                then 1 else 0 end as hospbed,

			/*Home oxygen*/
            case when c.&procvar in ("E1390" "E1391" "E1392" "E0431" "E0433" "E0434" "E0435" "E0439" "E0441"
                                     "E0442" "E0443")
                then 1 else 0 end as oxygen,

			/*Wheelchair*/
            case when c.&procvar in ("E1050" "E1060" "E1070" "E1083" "E1084" "E1085" "E1086" "E1087" "E1088" 
                                     "E1089" "E1090" "E1091" "E1092" "E1093" "E1100" "E1110" "E1140" "E1150"
                                     "E1160" "E1161" "E1170" "K0001" "K0002" "K0003" "K0004" "K0005" "K0006" 
                                     "K0007" "K0008" "K0009")
                then 1 else 0 end as wheelchair,

			/*Rehabilitation services*/
			case when c.&procvar in ("97110" "97161" "97162" "97116" "97535" "92507" "97164" "97012" "97112" "97530" "97113")
            then 1 else 0 end as rehab_cpt

         from &cohortds as a 
            left join &procds as c
               on a.&idvar = c.&idvar and 0 <= a.&datevar-c.&procdate %IF &maxDays ^=  %THEN <= &maxDays ;;


      /* Combine diagnoses and procedures and collapse into person level dataset */
      create table __temp_cohort_ as
         select distinct a.&idvar, a.&datevar, a.age - 65 as age65, (calculated age65)**2 as age65sq, a.sex, a.race,
            max(b.arthritis) as bl_arthritis label='Arthritis',
            max(b.bladder) as bl_bladder label='Bladder dysfunction',
            max(b.brain_inj) as bl_brain_inj label='Stroke/brain injury',
            max(b.decub) as bl_decub label='Skin ulcer (decubitus)',
            max(b.dement) as bl_dement label='Dementias',
            max(b.hf) as bl_hf label='Heart failure',
            max(b.hyposhock) as bl_hyposhock label='Hypotension or shock',
				max(b.lipid) as bl_lipid label='Lipid abnormality',
            max(b.paralysis) as bl_paralysis label='Paralysis',
            max(b.pd) as bl_pd label='Parkinsons disease',
            max(b.podiatric) as bl_podiatric label='Podiatric care',
            max(b.psych) as bl_psych label='Psychiatric illness',
            max(b.rehab, c.rehab_cpt) as bl_rehab label='Rehabilitation care', 
            max(b.screening) as bl_screening label='Cancer screening',
            max(b.vertigo) as bl_vertigo label='Vertigo',
            max(b.weakness) as bl_weakness label='Weakness',
            max(c.ambulance) as bl_ambulance label='Ambulance',
            max(c.hospbed) as bl_hospbed label='Home Hospital Bed',
            max(c.oxygen) as bl_oxygen label='Home oxygen',
            max(c.wheelchair) as bl_wheelchair label='Wheelchair'
         from &cohortds as a
            left join _temp_dxflags1_ as b on a.&idvar = b.&idvar and a.&datevar = b.&datevar
            left join _temp_hcpcflags_ as c on a.&idvar = c.&idvar and a.&datevar = c.&datevar
         group by a.&idvar, a.&datevar;

		 create table _temp_cohort_ as
		 select distinct &idvar, &datevar, age65, age65sq, sex, race, 
				bl_arthritis, bl_bladder, bl_brain_inj, bl_decub, bl_dement, bl_hf, bl_hyposhock, bl_lipid, 
				bl_paralysis, bl_pd, bl_podiatric, bl_psych, max(bl_rehab) as bl_rehab label='Rehabilitation care', 
            	bl_screening, bl_vertigo,  bl_weakness, bl_ambulance, bl_hospbed, bl_oxygen, bl_wheelchair
		from __temp_cohort_
		group by &idvar, &datevar;
   quit;

   /* Apply estimates from Faurot, et al */
	data &outds;
	   if _N_ = 1 then set &lib..frailtyEstimates;
	   set _temp_cohort_;

	   frailtyOdds = est_intercept + est_age65*age65 + est_age65sq*age65sq + est_sex*(sex='2') +
	       est_raceB*(race='B') + est_raceH*(race='H') + est_raceO*(race='O') + 
	       est_screening*(bl_screening>0) + est_lipid*(bl_lipid>0) + est_vertigo*(bl_vertigo>0) + 
	       est_arthritis*(bl_arthritis>0) + est_bladder*(bl_bladder>0) + est_podiatric*(bl_podiatric>0) + 
	       est_hf*(bl_hf>0) + est_psych*(bl_psych>0) + est_rehab*(bl_rehab>0) + est_oxygen*(bl_oxygen>0) +
	       est_hyposhock*(bl_hyposhock>0) + est_ambulance*(bl_ambulance>0) +  est_brain_inj*(bl_brain_inj>0) + 
	       est_dement*(bl_dement>0) + est_pd*(bl_pd>0) + est_weakness*(bl_weakness>0) + est_decub*(bl_decub>0) +
	       est_paralysis*(bl_paralysis>0) + est_wheelchair*(bl_wheelchair>0) + est_hospbed*(bl_hospbed>0);

	    predictedFrailty = exp(frailtyOdds) / (1+exp(frailtyOdds));
	run;

   /* Clean up temporary datasets */
   proc datasets lib=work nolist nodetails; delete _temp_dxflags_ _temp_hcpcflags_ _temp_cohort_; run;quit;
%mend frailty;

