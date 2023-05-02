/*****************************************************************************************************/
/* Program: /projects/medicare/ablocker/programs/macros/calculate_est.sas                                 */
/* Purpose: Produce output for a typical Table 1: Baseline Covariates                                */
/*                                                                                                   */
/* Created on: December 14, 2022                                                                    */
/* Created by: Chase Latour                                                                         */
/*                                                                                                   */
/* Inputs: INDS = Input dataset where the probabilities of treatment should be calculated
*/
/*                                                                                                   */
/*		   PSDS = name of the dataset where IPTW denominator PSs have been calculated

		   OUTDS = name of the output dataset*/

/* Details: This macro calculates risk differences and risk ratios from the boostrapped datasets
		associated with the alpha-blockers analysis.
*/
/*                                                                                                   */
/*****************************************************************************************************/


**
Create macro for calculating IPTW
**;

*Macro to create IPTW;
%MACRO iptw(inds =, psds =, outds =, psvar=);

	*Get marginal probabilities;
	proc logistic data=&inds noprint;
		model ab (reference = /*'0'*/ "AR5")=;
		output out=weight_analysis prob=prev;
	run;

	*Calculate stabilized IPTW;

	*First, merge the probabilities;
	proc sql;
		create table _cohort_weights as
		select a.*, b.prev
		from &psds as a
		left join weight_analysis as b
		on a.bene_id = b.bene_id
		;
		quit;

	*Now, calculate the weights;
	data &outds;
	set _cohort_weights;
		
		if ab = 1 then iptw = prev / &psvar;
			else if ab=0 then iptw = (1-prev)/(1-&psvar);

	run;

%MEND;
