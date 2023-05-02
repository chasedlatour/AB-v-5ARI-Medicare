/*****************************************************************************************************/
/* Program: /projects/medicare/ablocker/programs/macros/calculate_est.sas                                 */
/* Purpose: Produce output for a typical Table 1: Baseline Covariates                                */
/*                                                                                                   */
/* Created on: December 12, 2022                                                                    */
/* Created by: Chase Latour                                                                         */
/*                                                                                                   */
/* Inputs: INDS = one or two level name of the input dataset to be used to create the table; data    */
/*                set should have one record per ID                                                  */
/*                                                                                                   */
/*		   OUTDS = name of the output dataset where the summary file should be saved

		   FUP = Length of time that the study estimates the follow-up from the 2nd fill */

/* Details: This macro calculates risk differences and risk ratios from the boostrapped datasets
		associated with the alpha-blockers analysis.
*/
/*                                                                                                   */
/*****************************************************************************************************/


**
Create macro for calculating bootstrapped estimates
**;

%macro calculate_est(inds=, fup=, outds=, rd_multiple=);

	*Calculate the log-transformed risk for averaging;
/*	data _logrisk;*/
/*	set &inds;*/
/**/
/*		lnrisk0_&fup = log( e0_rate&fup );*/
/*		lnrisk1_&fup = log( e1_rate&fup );*/
/**/
/*	run;*/

	*Output final estimates;
	proc means data=&inds mean std;
		var e0_rate&fup e1_rate&fup riskDiff&fup lnriskRatio&fup;
		ods output summary=_summary;
	run;


	*Output the final estimates;
	data ana.&outds ( keep = risk0_&fup risk0_&fup._LCL risk0_&fup._UCL
							risk1_&fup risk1_&fup._LCL risk1_&fup._UCL
							RD&fup RD&fup._LCL RD&fup._UCL RR&fup RR&fup._LCL RR&fup._UCL 
							rd_multiple);
	set _summary;
		
		*Summarize risk in the untreated;
		risk0_&fup = e0_rate&fup._Mean * 100;
		risk0_&fup._LCL = (e0_rate&fup._Mean - (1.96*e0_rate&fup._StdDev))*100;
		risk0_&fup._UCL = (e0_rate&fup._Mean + (1.96*e0_rate&fup._StdDev))*100;

		*Summarize risk in the treated;
		risk1_&fup = e1_rate&fup._Mean * 100;
		risk1_&fup._LCL = (e1_rate&fup._Mean - (1.96*e1_rate&fup._StdDev))*100;
		risk1_&fup._UCL = (e1_rate&fup._Mean + (1.96*e1_rate&fup._StdDev))*100;

		*Summarize risk differences;
		RD&fup = riskDiff&fup._Mean*&rd_multiple;
		RD&fup._LCL = (riskDiff&fup._Mean - (1.96*riskDiff&fup._StdDev))*&rd_multiple;
		RD&fup._UCL = (riskDiff&fup._Mean + (1.96*riskDiff&fup._StdDev))*&rd_multiple;

		*Summarize risk ratios;
		RR&fup = exp(lnriskRatio&fup._Mean);
		RR&fup._LCL = exp(lnriskRatio&fup._Mean - (1.96*lnriskRatio&fup._StdDev));
		RR&fup._UCL = exp(lnriskRatio&fup._Mean + (1.96*lnriskRatio&fup._StdDev));

		rd_multiple = &rd_multiple;
	run;
	

%mend calculate_est;


