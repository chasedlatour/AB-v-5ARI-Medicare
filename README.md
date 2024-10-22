# AB-v-5ARI-Medicare

This repository provides analytic SAS code for Zhang, Latour et al. 2023 (PMID: 37962887, DOI: 10.1001/jamanetworkopen.2023.43299). 

Data for this analysis  come from Centers for Medicare & Medicaid Services (CMS) Part D Medicare Database, as maintained by the University of North Carolina at Chapel Hill’s Cecil G. Sheps Center for Health Services Research. This database contains patient information on in-patient, out-patient, and prescription drug service claims among a 20% random sample of Medicare beneficiaries in the United States from 2007-2019. We linked individual-level claims data on the enrollee identification number. All analyses in this study were approved with the University of North Carolina at Chapel Hill’s Institutional Review Board.

These data cannot be provided publicly but can be obtained through an appropriate data use agreement.

Multiple files are provided with this project and have been substantially commented to facilitate reader understanding. Code can be separated into buckets.

(1) Macros used throughout.
- calculate_est.sas - Calculated RD and RR estimates from the boostrapped estimates.
- competingrisk_risks_single.sas - This runs the competing events analysis without bootstrapping (done for checking and making survival curves).
- competingrisk_weights.sas - This runs the competing events analysis with boostrapping (primary analysis).
- competingrisk_weights_pstrim.sas - This runs the competing events analysis with additional propensity score (PS) trimming (sensitivity analysis).
- iptw.sas - Macro to create inverse probability of treatment weights
- logparse.sas - Automatically ran with set up macro
- passinfo.sas - Automatically ran with the set up macro
- ps.sas - Main propensity score models.
- ps_mi.sas - Propensity score model without myocardial infarction (sensitivity analysis)
- ps_obesity.sas - Propensity score model without obesity indicator (sensitivity analysis)
- ps_tobacco.sas - PS model without tobacco use indicator (sensitivity analysis)
- ps_tobacco_copd.sas - PS model without tobacco use and COPD indicator (sensitivity analysis)
- right_weights_multiple.sas - Kaplan-Meier (KM) estimator for primary KM analyses (multiple refers to multiple outcomes being analyzed in one macro) (primary analysis)
- right_weights_multiple_pstrim.sas - KM estimator with additional PS trimming (sensitivity analysis)
- risk_weights_multiple_sample - KM estimator for the primary sample without bootstrapping (derive risk curves)
- setup.sas - RUN AT BEGINNING. Macro that calls all the other macros to be run.
- table1.sas - Macro to easily create table 1
- table1_siptw.sas - Macro to easily create table1 with standardized inverse probability of treatment weights applied (primary analysis)
- useperiods.sas - Macro used by 01_exposure.sas to identify periods of new use of medications

(2) Defining analytic varibles.
- dx9_dx10.sas - This was used to define necessary variable codelists so that they matched others used in the analysis.
- Defining Variables.sas - This was used to define necessary variable code lists.
- Variable Identification_Supplement.xlsx - Excel file with all of the codelists that could not be uploaded with the manuscript.
- .sas7bdat files with all of the variable code lists.
- defineCovariates.sas
- defineExclusions.sas
- defineExposure.sas
- defineOutcomes.sas
- gemsmap.sas, gemsmap_macro_for_mapping_icd_codes.sas - macro created by Alan Kinlaw to map ICD codes from the ICD-9 to ICD-10 era (link: https://github.com/alankinlaw/Easy_ICD9-to-10_GEMs_mapping)
- macro_frailty_update.sas - Updated code for Faurot Frailty Index in ICD 9 to 10 transition (PMID: 37431778, DOI: 10.1093/aje/kwad151)

(3) Checking outcome code usage across the ICD-9 to ICD-10 transition.
- icd9_10_outcome_check.sas

(4) Deriving the relevant variables for the cohort from Medicare claims files (not the raw files provided by Medicare but derived files at UNC through Cecil G. Sheps Center), and
- 01_exposure.sas - Identify a cohort of new-users of a-Blockers or 5ARIs.
- 02a_covariates.sas - Derive covariates for the cohort
- 02b_outcomes.sas - Derive outcomes for the cohort

(5) Conducting analyses.
- 1_primary_cohort_derive.sas - Derive the final cohort dataset from those files created in (4)
- 2_primary_analysis_cohort.sas - Conduct the primary analysis in the single cohort.
- 3a_primary_boot_risks. - Boostrap the risks for the KM estimators in the primary analysis.
- 3b_primary_boot_cabg_iptw.sas, 3b_primary_boot_cabg_noiptw.sas - Boostrap the risks for the CABG outcome in the primary analysis (AJ estimator), with and without IPTW
- 3b_primary_boot_hf_iptw.sas, 3b_primary_boot_hb_noiptw.sas - Bootstrap the risks for the Heart failure outcome in the primary analysis (AJ estimator), with and without IPTW
- 3b_primary_boot_pcip_iptw.sas, 3b_primary_boot_pcip_noiptw.sas - Bootstrap the risks for the PCIP outcome in the primary analysis (AJ estimator), with and without IPTW
- 4_primary_comb_boot.sas - Combine the bootstrapped estimates from the primary analyses
- 5_mi_cohort.sas - Derive cohort without history of myocardial infarction (MI)
- 6_mi_analysis.sas - Primary analyses in that cohort (derive curves, etc.)
- 7_mi_boot.sas - Set up for bootstrapping in the MI cohort
- 7a_mi_boot_risks.sas - Run all KM estimators with bootstrapping in the no MI cohort
- 7b_mi_boot_cabg.sas - AJ estimator with CABG outcome in the no MI cohort - bootstrapping
- 7b_mi_boot_hf.sas - AJ estimator with heart failure outcome in the no MI cohort - bootstrapping
- 7b_miboot_pcip.sas - AJ estimator with PCIP outcome in the no MI cohort - bootstrapping
- 8_mi_comb_boot.sas - Combine the bootstrapped estimates among the no MI history cohort.
- 9a-c -- Same analyses, considering the restricted exposure definition (sensitivity analysis)
- 10a-c -- Same analyses, considering additional PS trimming (sensitivity analysis)
- 11 -- Look at cohort with BPH code in the last 6 months and output table 1 (sensitivity analysis)
- 12a-c -- Same analyses, considering additional confounding control for BPH severity (sensitivity analysis)
- 13a-c -- Same analyses, with additional restriction on anticoagulant use (sensitivity analysis)
- 14a-c -- Same analysis restricting to the ICD-10 era (sensitivity analysis)
- 15a-c -- Same analyses restricting to those with an inpatient hospitalization for MI, heart failure or stroke within 12 months prior to cohort entry (sensitivity analysis)
- 17a-c -- Same analyses with additional BPH confounding control (sensitivity analysis)
- 18a-c -- Same analysis with additional indicators for socioeconomic status (SES) (sensitivity analysis)
- 19a-c -- Negative control outcome analysis (sensitivity analysis) (sensitivity analysis)
