/*****************************************************************************************************/
/* Program: /mnt/files/datasources/medicare/macros/setup.sas                                         */
/* Purpose: Macro for assigning libnames, titles and footnotes for project run, allowing for easy    */
/*          change from sample to full data                                                          */
/*                                                                                                   */
/* Created: June 15, 2011                                                                            */
/* Author: Virginia Pate                                                                             */
/*                                                                                                   */
/* Macro Inputs:                                                                                     */
/*   SAMP: SAMPLE OF DATA ON WHICH TO RUN PROGRAM                                                    */
/*         Accepted values are: 1pct and full                                                        */
/*                                                                                                   */
/*   PROGNAME: PROGRAM NAME                                                                          */
/*            Name of the program being run.  This value is used in the footnote of any output that  */
/*            is produced with this program and is also used when saving the log                     */
/*                                                                                                   */
/*   SAVELOG: Y/N FLAG INDICATING WHETHER LOG FILE SHOULD BE SAVED TO A PERMANENT FILE               */
/*            If Y, log file is saved to .../programs/logs/random1pct or .../programs/logs/full      */
/*            with a file name YYYYMMDD_&PROGNAME..LOG, using the system date and the specified      */
/*            PROGNAME macro parameter to name the file                                              */
/*****************************************************************************************************/

%macro setup(sample, ProgramName, saveLog=N, serverSpace=local);

   /* DEFINE PROJECT SPECIFIC DATABASE AND PROJECT NAME */
     %LET db = medicare; 
     %LET proj = ablocker;
     %LET DUA = 20386;

   /* DEFINE PROJECT SPECIFIC FILE PATHS, DEPENDENT ON SAMPLE */
      %LET sample = %SYSFUNC(lowcase(&sample));
      %IF &sample = 1pct %THEN %LET sample = random1pct;

      %GLOBAL ProjDir LogPath LogDate; 
      %IF &serverSpace = local %THEN %DO; 
         %IF &syshostname = n1 %THEN %LET ProjDir = /n2/projects/&db./&proj.;
         %ELSE %LET ProjDir = /local/projects/&db./&proj.;
      %END; %ELSE %IF &serverSpace = nearline %THEN %LET ProjDir = /nearline/files/projects/&db./&proj.;

      %LET ProgPath = &ProjDir./programs; 
      %LET LogPath = &ProgPath./logs/&sample;

   /* IF SAVELOG IS SPECIFIED, START LOG FILE AND SET REQUIRED OPTIONS */
      %LET LogDate = %sysfunc(date(),yymmddn8.);
      %IF &saveLog = Y %THEN %DO;
         %LET programNameP = %SYSFUNC(translate(&programName,_,/));
         proc printto new log="&LogPath./&logDate._&programNameP..log"; run;
         %passinfo;
         options fullstimer mprint;
      %END;
          
   /* INCLUDE FORMATS NEEDED FOR PROJECT */
      proc format;
         value mo  1='Jan' 2='Feb' 3='Mar' 4='Apr' 5='May' 6='Jun' 
                   7='Jul' 8='Aug' 9='Sep' 10='Oct' 11='Nov' 12='Dec';
         value any 0='0' 1-high='1+';
         value two 0-1='0-1' 2-high='2+';
      run;

   /* DEFINE LIBNAMES */
      /* Raw and Derived Datasets */
      %IF &db = medicare %THEN %DO;
			%LET dataPath = /local/data/master/medicare;
			%LET viewPath = /local/prep/medicare/views/DUA&DUA;

         libname char "&viewPath./charFiles" access=readonly;
         libname _char "&dataPath./charFiles/datasets" access=readonly;

		 	/*Updated with the new Medicare data organization*/
			libname raw "&viewPath./&sample./raw" access=readonly;
			libname _raw "&dataPath./&sample./raw/datasets" access=readonly;

			libname der "&viewPath./&sample./derived" access=readonly;
			libname _der "&dataPath./&sample./derived/datasets" access=readonly;

         libname _xwalk "&dataPath./mcbs/crosswalks";
         libname xwalk "&viewPath./mcbs/crosswalks/DUA&DUA";

         libname _mcbsCS "&dataPath./mcbs/cost/survey";
         libname mcbsCS "&viewPath./mcbs/cost/survey/DUA&DUA";

         libname _mcbsCC "&dataPath./mcbs/cost/claims";
         libname mcbsCC "&viewPath./mcbs/cost/claims/DUA&DUA";

         libname _mcbsAS "&dataPath./mcbs/access/survey";
         libname mcbsAS "&viewPath./mcbs/access/survey/DUA&DUA";

         libname _mcbsAC "&dataPath./mcbs/access/claims";
         libname mcbsAC "&viewPath./mcbs/access/claims/DUA&DUA";
      %END;

      %ELSE %IF &db = marketscanccae %THEN %DO;
         libname red "/nearline/files/datasources/marketscanccae/redbook" access=readonly;
         %IF &sample = random1pct %THEN %DO;
            libname raw ("/local/projects/marketscanccae/data/random1pct"
                         "/nearline/files/datasources/marketscanccae/redbook") access=readonly;
            libname der "/local/projects/marketscanccae/data/random1pct/derivedDatasets" access=readonly;

            libname mdcr "/nearline/files/datasources/marketscanccae/random1pct/mdcr" access=readonly;
            libname mdcrder "/nearline/files/datasources/marketscanccae/derivedDatasets/random1pct/mdcr" access=readonly;
         %END;
         %ELSE %IF &sample = full %THEN %DO;
            libname raw ("/nearline/data/marketscanccae"
                         "/nearline/files/datasources/marketscanccae/redbook") access=readonly;

            libname der (%IF &syshostname=n1 %THEN "/local/prep/marketscanccae/data/derivedDatasets";
							    "/nearline/data/marketscanccae/derivedDatasets") access=readonly;

            libname mdcr "/nearline/data/marketscanccae/mdcr" access=readonly;
            libname mdcrder "/nearline/data/marketscanccae/derivedDatasets/mdcr" access=readonly;
         %END;
      %END;

      %ELSE %DO;
         %IF &sample = random1pct %THEN %Do;
            libname raw "/nearline/files/datasources/&db./random1pct" access=readonly;
            libname der "/nearline/files/datasources/&db./derivedDatasets" access=readonly;
         %END;
         %ELSE %IF &sample = full %THEN %DO;
            libname raw "/nearline/data/&db." access=readonly;
            libname der "/nearline/data/&db./derivedDatasets" access=readonly;
         %END;
      %END;

      %IF &sample ^= random1pct %THEN %DO; %IF &sample ^= full %THEN %DO;
         %PUT ABORT: INVALID VALUE FOR SAMPLE PARAMETER;
         %PUT SAMPLE PARAMETER MUST TAKE ON A VALUE OF random1pct, 1pct OR full (CASE SENSITIVE);
         %ABORT;
      %END; %END;

      %IF &db = medicare %THEN %DO;
         options nosource2;
         %include "/nearline/files/datasources/medicare/views/check_expiration_date.sas";
         %check_expiration_date(&DUA);
         options source2;
      %END;


      /* Output Datasets */
      libname out "&ProjDir./data/&sample" %IF &sysuserid^=vpate & &sample=full %THEN access=readonly;;
      libname temp "&ProjDir./data/&sample./temp"; 
      libname ana "&ProjDir./data/&sample./analysis";

      /* Reference Files */
      %GLOBAL OutPath RefPath;
      %LET RefPath = &ProjDir./documentation/definitions; 
      libname expref "&RefPath./exposure";
      libname exclref "&RefPath./exclusion";
      libname covref "&RefPath./covariates";
      libname frail "&RefPath./covariates/frailty";
      libname outref "&RefPath./outcomes";
      libname rxcov  "&RefPath./covariates/rxcovar";

      /* Output Paths */
      %LET OutPath = &ProjDir./output/&sample; 
      ods listing gpath= "&OutPath./graphics";

      /* Formats */
      %LET codePath = /nearline/files/datasources/references/Code Reference Sets;
      libname codes "&codePath.";
      libname dx "&codePath./ICD9DX";
      libname icdp "&codePath./ICD9Proc";
      libname dx10 "&codePath./ICD10DX";
      libname icdp10 "&codePath./ICD10Proc";
      libname cpt "&codePath./CPT_HCPCS";
      libname atc "&codePath./Drugs";
      libname fmt "/nearline/files/datasources/&db./formats";

      options fmtsearch= (dx.dxfmts icdp.formats cpt dx10.dxfmts icdp10.formats
         %IF &db = medicare %THEN fmt.formats fmt.partdfmts06 fmt.partdfmts07 fmt.partdfmts08 fmt.plancharfmts ;
         %IF &db = marketscanccae %THEN fmt.formats ;);

   /* DEFINE FOOTNOTES AND TITLES */
      %GLOBAL footnote1 footnote2;
      %LET footnote1 = %STR(j=l "Program: &ProgPath./&programName..sas");
      %LET footnote2 = %STR(j=l "Run on the &sample. dataset by &SYSUSERID. on &SYSDATE. ");

      footnote1 &footnote1;
      footnote2 &footnote2;

%mend setup;
