/******************************************************************************************************/
/*                                                                                                    */
/* Program: /mnt/files/datasources/references/Cohort/useperiods.sas                                   */
/* Purpose: Get each distinct Period of Use, flagging periods that qualifying as new use.             */
/*          The input dataset should contain only claims that should be considered for use.           */
/*                                                                                                    */
/* Created on April 26, 2011                                                                          */
/* Created by Virginia Pate                                                                           */
/*                                                                                                    */
/* Inputs:                                                                                            */
/*   GRACE=&GP           - Length of grace period (in days), for determining discontinuation date     */
/*                                                                                                    */
/*   WASHOUT=&WP         - Length of the washout period (in days), for determining periods of new use */
/*                                                                                                    */
/*   WPGP=Y              - Flag to indicate whether the washout period for first period of use after  */
/*                         start of enrollment should include the length of the grace period and days */
/*                         supply (Y) or only the length of the washout period (N)                    */
/*                                                                                                    */
/*   DAYSIMP=0           - Value to use for days supply if raw data has a value<=0 (including missing)*/
/*                                                                                                    */
/*   MAXDAYS=            - Maximum days supply of drug a patient should be allowed to accumulate; if  */
/*                         patient reaches this max, their future days covered is capped at &maxdays  */
/*                                                                                                    */
/*   MULTICLAIM=max      - Option of how to handle multiple claims on the same day for the same       */
/*                         patient; options are MAX, MIN, or SUM of days supply                       */
/*                                                                                                    */
/*   INDS=claims         - Input dataset name                                                         */
/*                         Dataset must contain one record per RX fill of interest per patient and    */
/*                         the following variables must be present in the dataset:                    */
/*                             &IDVAR:      Patient ID                                                */
/*                             &STARTENROLL: Start Date of continuous enrollment period               */
/*                             &RXDATE:     Date of prescription fill                                 */
/*                             &DAYSSUP:    Days Supply                                               */
/*                             &ENDENROLL:   End Date of continuous enrollment period                 */
/*                                                                                                    */
/*   IDVAR=id            - Name of the variable(s) in &INDS that identifies a unique patient          */
/*                                                                                                    */
/*   STARTENROLL=startdt - Name of the variable in &INDS that holds the start date of the period of   */
/*                          continuous enrollment in which the RX claim falls                         */
/*                                                                                                    */
/*   RXDATE=rx_date      - Name of the variable in &INDS that holds the date of the RX fill           */
/*                                                                                                    */
/*   ENDENROLL=enddt     - Name of the variable in &INDS that holds the end date of the period of     */
/*                         continuous enrollment in which the RX claim falls                          */
/*                                                                                                    */
/*   DAYSSUP=days        - Name of the variable in &INDS that holds the number of days supply         */
/*                                                                                                    */
/*   KEEPVARS=           - List of variables to carry through macro, values based on index fills      */
/*                                                                                                    */
/*   OUTDS=useperiods    - Name of the output dataset                                                 */
/*                                                                                                    */
/* Outputs: OUTDS        - Output dataset containing one record per period, containing variables:     */
/*                               &IDVAR: same as input &idvar                                         */
/*                               INDEXDATE: Date of 1st RX fill for given period of use               */
/*                               DISCONTDATE: Date of discontinuation for given period of use         */
/*                               NEWUSE: Flag indicating whether period of use qualifies as NEW USE   */
/*                               PERIOD: Sequentially numbered distinct period of use within &IDVAR   */
/*                               REASON: Reason for discontinuation                                   */
/*                               NUMFILL: Number of RX fills during the period of use                 */
/*                               FILLDATE2: Date of the 2nd RX fill during the period of use          */
/*                               SUPPLY1: Number of days supply of the index prescription             */
/*                               LASTFILLDT: Date of the last RX fill of the period of use            */
/*                                                                                                    */
/* Updates: 8/9/2011  --  moved from IMS and made more generic for use across studies                 */
/*          6/7/2012  --  added STARTENROL, ENDENROL and updated code to censor at end of enrollment  */
/*          1/17/2014 --  corrected fillDate2 variable to reset with new periods of use               */
/*          1/7/2015  --  corrected IndexDate to reset for new value of &group                        */
/*          4/30/2015 --  updated to allow input and output datasets to have options                  */
/*          5/8/2015  --  updated to allow grace period to be a variable name or a number; removed    */
/*                        GROUP parameter (no longer needed since input dataset can have options);    */
/*                        added MULTICLAIM parameter to allow for options when dealing with multiple  */
/*                        claims on the same day for the same patient; changed WP parameter to WPGP   */
/*                        and changed its function to be an option as to whether to include the length*/
/*                        of the grace period in the initial washout period per person                */
/*          1/27/2016 --  added KEEPVARS option                                                       */
/*          10/5/2016 --  added NUMCLAIMS_INDEX variable and corrected for when KEEPVARS has multiple */
/*                        values on the same day                                                      */
/*          11/20/2017--  applied &multiclaim function to grace period as well as days supply         */
/*          12/15/2017--  corrected variable grace period to use last value when determining discontDT*/
/******************************************************************************************************/
  
%macro useperiods(grace=&gp, washout=&wp, wpgp=Y, daysimp=0, maxDays=, multiclaim=max,
                 inds=claims, idvar=id, startenroll=startDT, rxdate=rx_date, endenroll=enddt, dayssup=days, 
                 keepvars=, outds=useperiods);

   /* Parse input dataset */
      /* Parse libname and dataset name */
      %IF %INDEX(&inds,.)>0 %THEN %DO;  
         %LET inlib = %SCAN(&inds,1,'.'); %LET inds = %SCAN(&inds,2,'.');
      %END; %ELSE %DO; %LET inlib = WORK; %END;

      /* Parse dataset name and options */
      %LET indsName = %SYSFUNC(cats(/*_,*/%SCAN(&inds,1,'('))); 

   /* Parse output dataset */
      /* Parse libname and dataset name */
      %IF %INDEX(&outds,.)>0 %THEN %DO;  
         %LET outlib = %SCAN(&outds,1,'.'); %LET outds = %SCAN(&outds,2,'.');
      %END; %ELSE %DO; %LET outlib = WORK; %END;

      /* Parse dataset name and options */
      %LET outdsName = %SYSFUNC(cats(_,%SCAN(&outds,1,'('))); 

   /* If keep variables are specified, separate into separate variables */
      %IF &keepvars ne  %THEN %DO; 
         %LET numKV = %SYSFUNC(countw(&keepvars));
         %DO i=1 %TO &numKV; %LET keepVar&i = %SCAN(&keepvars, &i); %END;
         proc contents data=&inds noprint out=_md_; run;
         data _null_; set _md_; %DO i=1 %TO &numKV;
            if upcase(name) = "%UPCASE(&&keepVar&i)" then do; 
               call symput("kvType&i", type); call symput("kvLength&i", length); call symput("kvLabel&i", label); end; %END; 
         run;
      %END; %ELSE %DO; %LET numKV = 0; %END; 

   /* If multiple id variables, determine the last one */
      %LET numID = %SYSFUNC(countw(&idvar));
      %DO i=1 %TO &numID; %LET idVar&i = %SCAN(&idvar, &i); %END;

   /* Ensure that input data is sorted properly & deal with multiple claims on the same day */
   proc sql; create table &indsName._new as select distinct 
         %DO i=1 %TO &numID; &&idvar&i, %END; &startEnroll as startEnroll, &endEnroll as endEnroll, 
         &rxdate as rxdate, &multiclaim.(days_imp) as days, grace1, count(*) as numClaims_index0
         %IF &numKV > 0 %THEN %DO; , %DO i=1 %TO &numKV; 
            %IF &&kvType&i=2 %THEN case when count(distinct &&keepVar&i)>1 then 'Multiple' else &&keepVar&i end as &&keepVar&i..0;
            %ELSE &multiclaim.(&&keepVar&i) as &&keepvar&i..0; %IF &i<&numKV %THEN ,; %END; %END;
      from (select *, case when &dayssup<=0 then &daysimp else &dayssup end as days_imp,
            %IF "%upcase(&grace)" = "%upcase(&dayssup)" %THEN calculated days_imp; %ELSE &grace; as grace1
         from &inlib..&inds)
      group by %DO i=1 %TO &numID; &&idvar&i, %END; &startEnroll, &rxdate
      order by %DO i=1 %TO &numID; &&idvar&i, %END; startEnroll, rxdate; quit;

   /* Process data */
   data &outdsName; set &indsName._new;
      by &idvar startenroll;
      length reason $100 %IF &numKV>0 %THEN %DO; %DO i=1 %TO &numKV; %IF &&kvType&i=2 %THEN &&keepVar&i $&&kvLength&i; %END; %END; ;
      retain IndexDate newuse lastdt FillDate2 supply1 lastFillDT usePeriod grace numClaims_index
             %IF &numKV>0 %THEN %DO; %DO i=1 %TO &numKV; &&keepVar&i %END; %END; ;

      if first.&&IDvar&numID then usePeriod=0;

      /*First Fill during period of continuous enrollment*/
      if first.startenroll then do; 
         *Reset variables;
         numfill = 1; usePeriod + 1; filldate2=.; discontDate=.; supply1 = days; numClaims_index=numClaims_index0;
         %IF &numKV>0 %THEN %DO; %DO i=1 %TO &numKV; &&keepVar&i = &&keepVar&i..0; %END; %END;
         IndexDate = rxdate; 
         grace = grace1;

         *Determine if period qualifies as new use & update follow-up variables;
         %IF &wpgp = Y %THEN %DO;
            if startenroll + grace + &washout < rxdate then newuse = 1; else newuse = 0; 
            lastdt = max(indexdate, startenroll + grace) + days; 
         %END; %ELSE %DO; 
            if startenroll + &washout < rxdate then newuse = 1; else newuse = 0;
            lastdt = rxdate + days; 
         %END;
         lastFillDT = rxdate;

         /*If first.&startenroll and last.&startenroll then only one fill during enrollment period*/
         if last.startenroll then do;
            DiscontDate = min(endenroll, lastdt+grace);
            if endenroll <= lastdt + grace then  reason = 'End of Enrollment';
               else reason = 'Drug Discontinuation';
            output;
         end;
      end;

      /*If not first.&startenroll or last.&startenroll then check if there is a gap in drug coverage*/
         /*  If so, output; */
         /*  otherwise update vars and move to next fill; if the RX is filled with >&maxdays days remaining */
         /*     on the previous fill, reset last day covered to RX Fill Date + Days Supply                  */
      else if ^last.startenroll then do;
         /*If no gap in drug coverage, update variables*/
         if rxdate <= lastdt + grace + 1 then do;
            numfill + 1; if numfill=2 then fillDate2 = rxdate;
            %IF &maxDays ne  %THEN %DO;
               if rxdate < lastdt - &maxDays then lastdt = min(endenroll, rxdate+days); 
               else 
            %END;
            lastdt = min(endenroll, max(lastdt, rxdate) + days);
            grace = grace1;
         end;
         /*If there is a gap in drug coverage, output period of use and start a new period*/
         else if rxdate > lastdt + grace + 1 then do;
            DiscontDate = lastdt + grace;
            reason = 'Drug Discontinuation';
            output;

            *Reset variables;
            usePeriod + 1; numfill=1; fillDate2 = .; supply1 = days; numClaims_index = numClaims_index0;
            %IF &numKV>0 %THEN %DO; %DO i=1 %TO &numKV; &&keepVar&i = &&keepVar&i..0; %END; %END;
            indexdate = rxdate;
            if indexdate - discontdate > &washout then newuse = 1; else newuse = 0; 
            lastdt = indexdate + days; discontDate=.;
         end;
         lastFillDT = rxdate;
         grace = grace1;
      end;

      /*If last fill of continuous enrollment, check if there was a gap in coverage prior to this fill*/
      else if last.startenroll then do;
         /*If no gap in drug coverage, determine end date and output a single record*/
         if rxdate <= lastdt + grace + 1 then do;
            numfill + 1; if numfill = 2 then fillDate2 = rxdate;
            %IF &maxDays ne  %THEN %DO;
               if rxdate < lastdt - &maxDays then lastdt = rxdate + days;
               else
            %END;
            grace=grace1;
            lastdt = max(lastdt, rxdate) + days;
            DiscontDate = min(lastdt + grace, endenroll);
            if lastdt + grace < endenroll then reason = 'Drug Discontinuation';
               else reason = 'End of Enrollment';
            lastFillDT = rxdate;
            output;
         end;
         /*If there is a gap in drug coverage, first output the previous period of use and then output the last period of use (which has only one fill)*/
         else if rxdate > lastdt + grace + 1 then do;
            DiscontDate = lastdt + grace;
            reason = 'Drug Discontinuation';
            output;

            *Reset variables;
            usePeriod + 1; numfill=1; fillDate2=.; supply1 = days; numClaims_index = numClaims_index0;
            %IF &numKV>0 %THEN %DO; %DO i=1 %TO &numKV; &&keepVar&i = &&keepVar&i..0; %END; %END;
            indexdate = rxdate; grace=grace1;
            lastdt = indexdate + days;
            if indexdate - discontdate > &washout then newuse = 1; else newuse = 0; 
            DiscontDate = min(lastdt + grace, endEnroll);
            if lastdt + grace < endenroll then reason = 'Drug Discontinuation';
               else reason = 'End of Enrollment';
            lastFillDT = rxdate;
            output;
         end;
      end;

      label newuse = "New Use Indicator (&washout-day washout period)"
            reason = 'Reason for Censoring'
            supply1 = 'Number of Days Supplied in First RX Fill of the Period'
            indexDate = "Date of First RX Fill"
            filldate2 = "Date of 2nd RX fill in period"
            lastfillDT = "Date of Last RX fill in period"
            numFill = 'Number of Fills during Period'
            discontDate = "Date of Drug Discontinuation (&grace-day grace period)"
            usePeriod = 'Sequentially Numbered Period of Use within ID'
            numClaims_index = 'Number of Claims on Index Date'
            %IF &numKV > 0 %THEN %DO; %DO i=1 %TO &numKV; &&keepVar&i = "&&kvLabel&i" %END; %END; ;
                
      format indexdate discontdate startenroll endenroll fillDate2 lastFillDT date9.;
      keep &idvar indexdate discontdate newuse reason startEnroll endEnroll numfill fillDate2 numClaims_index supply1 lastFillDT useperiod &keepVars;
      rename startEnroll = &startEnroll endEnroll = &endEnroll;
   run;

   proc sort data=&outdsName out=&outds; by &idvar indexdate discontdate; run;

   proc datasets lib=work nolist nodetails; delete &outdsName &indsName._new /*&indsName*/; run; quit;

%mend useperiods;

