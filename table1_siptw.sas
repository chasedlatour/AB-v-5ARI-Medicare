
%Macro cat(var);
/*EXPOSURE COHORT*/
ods output OneWayFreqs=a;
proc freq data=exp;
  tables &var;
run;
Data a (keep=table exp_var);
	set a;
		if &var=1; 
		exp_var=compress(put(frequency,8.))|| ' ('||compress(put((percent),6.1))||')';
		run;
/*UNEXPOSURE COHORT*/
ods output OneWayFreqs=b;
proc freq data=unexp;
  tables &var;
run;
Data b(keep=table unexp_var);
	set b;
		if &var=1; 
		unexp_var= compress(put(frequency,8.))||' ('||compress(put((percent),6.1))||')';
		run;
/*WEIGHTED EXPOSURE COHORT*/
ods output OneWayFreqs=c;
proc freq data=exp;
 weight siptw;/*siptw*/
  tables &var;
run;
Data c (keep=table exp_siptw_var);/*siptw*/
	set c;
		if &var=1; 
		exp_siptw_var="(" || compress(put((percent),6.1)) || ")"; 
		run;
/*WEIGHTED UNEXPOSURE COHORT*/
ods output OneWayFreqs=d;
proc freq data=unexp;
 weight siptw;/*siptw*/
  tables &var;
run;
Data D (keep=table unexp_siptw_var);/*siptw*/
	set D;
		if &var=1; 
		unexp_siptw_var="(" ||compress(put((percent),6.1))  ||")" ;
		run;
/*MERGE BINARY*/
Data &var;
	merge a b c d;
	by table;
	run;
%Mend;

%Macro multicat(var);
/*EXPOSURE COHORT*/
ods output OneWayFreqs=a;
proc freq data=exp;
  tables &var;
run;

Data a (keep=&var exp_var);
	set a;
		exp_var= compress(put(frequency,8.))|| " ("||compress(put((percent),6.1))||")";
		run;
/*UNEXPOSURE COHORT*/
ods output OneWayFreqs=b;
proc freq data=unexp;
  tables &var;
run;

Data b(keep=&var unexp_var);
	set b;
		unexp_var= compress (put(frequency,8.)) || " ("||compress(put((percent),6.1))||")";
		run;

/*WEIGHTED EXPOSURE COHORT*/
ods output OneWayFreqs=c;
proc freq data=exp;
 weight siptw;/*siptw*/
  tables &var;
run;
Data c (keep=&var exp_siptw_var);/*siptw*/
	set c;
		exp_siptw_var="("||compress(put((percent),6.1))||")";/*siptw*/
		run;

/*WEIGHTED UNEXPOSURE COHORT*/
ods output OneWayFreqs=d;
proc freq data=unexp;
 weight siptw;/*siptw*/
  tables &var;
run;
Data D (keep=&var unexp_siptw_var);/*siptw*/
	set D;
		unexp_siptw_var="("||compress(put((percent),6.1))||")";/*siptw*/
		run;

/*MERGE MULTICATEGORY*/
Data &var;
	merge a b c d;
	by &var;
	run;
%Mend;

proc means data=exp mean std;
  var mage ;
run;

%Macro mean(var, mean, std);
ods output Summary=a;
proc means data=exp mean std;
  var &var ;
run;
data a (keep=table /*exp_freq exp_pct*/ exp_var);
  set a;
  table="&var";
  exp_var=compress(put((&mean),6.1))||' ('||compress(put((&std),6.1))||')';
run;

ods output Summary=b;
proc means data=unexp mean std;
  var &var;
run;
data b (keep=table /*unexp_freq unexp_pct*/ unexp_var);
  set b;
  table="&var";
  unexp_var= compress(put((&mean),6.1))||' ('||compress(put((&std),6.1))||')';
run;

ods output Summary=c;
proc means data=unexp VARDEF=WDF mean std;
  weight siptw;
  var &var ;
run;
data c(keep=table exp_siptw_var);
  set c;
  table="&var";
  exp_siptw_var= compress(put((&mean),6.1))||' ('||compress(put((&std),6.1))||')';
run;

ods output Summary=d;
proc means data=unexp VARDEF=WDF mean std;
  weight siptw;
  var &var ;
run;
data d(keep=table unexp_siptw_var);
  set d;
  table="&var";
  unexp_siptw_var= compress(put((&mean),6.1))||' ('||compress(put((&std),6.1))||')';
run;

Data &var;
	merge a b c d;
	by table;
	run;
%Mend;
