################################### (Passing Values from EXCEL to MATLAB to AMPL)  ##########################
set Abbrev; param Param{Abbrev};
#suffix objpriority IN; suffix objweight IN; # Required for GUROBI Multi-Objective optimization

set Price_Scenario; # (s \in S): Stochastic Natural Gas Price Scenarios

#------ Monthly Drilling Time Horizon (t, \tau \in T) -------------------------------------------------------
param Present_Month, default 0;# Incrementally increased via MATLAB : Section 2.8, Moving Horizon Procedure	|
#																											|
param Final_Month, default 0; # Incrementally increased via MATLAB : Section 2.8, Moving Horizon Procedure	|
#																											|
set Param_Horizon = 0..Present_Month; #																		|
#																											|
set Optimizaton_Horizon = 0..Final_Month; #																	|
#																											|
set Constraint_Horizon = Present_Month..Final_Month;  #														|
#																											|
set Param_Horizon_A = Param_Horizon diff Constraint_Horizon; #												|
#																											|
set Price_Horizon = 0..Param['Optimization_Horizon'] + Param['Futures_Curve_Horizon'];#						|
#																											|
set Price_Horizon_A = 1..Param['Optimization_Horizon'] + Param['Futures_Curve_Horizon'];#					|
#																											|
set Optimizaton_Horizon_A = Optimizaton_Horizon diff {0}; #													|
#																											|
set Optimizaton_Horizon_B = Optimizaton_Horizon diff {Final_Month};#										|
#																											|
set Constraint_Horizon_A = Constraint_Horizon diff {Present_Month}; #										|
#																											|
set Constraint_Horizon_B = Constraint_Horizon diff {Final_Month}; #											|
#------------------------------------------------------------------------------------------------------------

################################### Section 2.1 (General Problem Statement and Assumptions) #################

	#NO SETS, PARAMATERS or VARIABLES
	
################################### Section 2.2 (Well Development and Gas Production) #######################

#-#-#-#-#-#-#-#-#-# Sets (Section 2.2) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

set Tier; # a \in A: Well EUR Tiers
set Component; # c \in C: Exponential Decline Components
	# s \in S: Stochastic Natural Gas Price Scenarios
	# t, \tau \in T: Monthly Drilling Time Horizon

#-#-#-#-#-#-#-#-#-# Parameters (Section 2.2) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

param Coefficient{Component}; # b_c: Exponential Decline Coefficients
param EUR{Tier}; #  EUR_a: Estimated Ultimate Recovery(EUR) {[}Mcf{]}
param GGC = Param['GGC_Cost']; # GGC: In-field Gas Gathering Cost [$/Mcf]
param R := Param['Discount_Rate']/12; # r: Monthly Discount Rate
param DF{i in Price_Horizon} = exp(-R*i); # Monthly Discount Rate as a scaling factor
param Count{Tier}; # W_a: Number of Wells in Each Tier [Wells]
param EUR_Percent{Component}; # \gamma_c: Fraction of EUR in Component
	# Time Period Based Step-Function (\chi^{WP}_{t,\tau})
	# \chi^{WP}_{t,\tau} is implied in Cumulative Gas Production's (Q_{t,s}) formulation

#-#-#-#-#-#-#-#-#-# Variable (Section 2.2) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

	# Net Present Cost of In-field Gas Gathering (NPC^{gg}_{s}) -  DEFINED AT THE END OF THE SUBSECTION
	
	# Q_{t,s} & q_{t,s} after defined after Well Production (WP_{a,t,s})
	# q_{t,s}:$ & Monthly Gas Production
	# Q_{t,s}:$ & Cumulative Gas Production
	
var Well_Development_Integer{Constraint_Horizon, Price_Scenario}>=0, integer; 	
	# WD_{a,t,s}:$ & Well Development [Wells] - Integer 	





#------ Well Production (WP_{a,t,s}) [Wells]  ---------------------------------------------------------------
var x_v{Tier, Constraint_Horizon, Price_Scenario}>=0; #														|
#																							 				|
param x_p{Tier, Optimizaton_Horizon, Price_Scenario}, default 0; #											|
#																							 				|
var x{i in Optimizaton_Horizon, ps in Price_Scenario} = if i>= Present_Month then #							| 
	sum{a in Tier}(x_v[a,i,ps] + x_p[a,i,ps]) else sum{a in Tier}(x_p[a,i,ps]); #							|
#------------------------------------------------------------------------------------------------------------

	# Monthly Gas Production (q_{t,s}) is function of Cumulative Gas Production (Q_{t,s})

#------ Cumulative Gas Production (Q_{t,s}) [Bcf] -----------------------------------------------------------
var CCP{i in Optimizaton_Horizon, o in Component, ps in Price_Scenario} = #									|
	sum {t in Present_Month..i, a in Tier}(EUR[a]*EUR_Percent[o]*x_v[a,t,ps]*(1-exp(Coefficient[o]*(t-i))));#
#																							 				|
param CCP_p{i in Optimizaton_Horizon, o in Component, ps in Price_Scenario} = #								|
	sum {t  in 0..i, a in Tier} (EUR[a]*EUR_Percent[o]*x_p[a,t,ps]*(1-exp(Coefficient[o]*(t-i)))); #		|
#Time Period Based Step-Function = sum {t  in Present_Month..i} & sum {t  in 0..i}							|
#------------------------------------------------------------------------------------------------------------
	
#------ Monthly Gas Production (q_{t,s}) [Bcf] --------------------------------------------------------------
var GP{i in Optimizaton_Horizon, ps in Price_Scenario} #													|
	= if i = 0 then 0 else sum{o in Component}(CCP[i,o,ps] - CCP[i-1,o,ps]);#		 		 				|
#																							 				|
param GP_p{i in Optimizaton_Horizon, ps in Price_Scenario} #												| 
	= if i = 0 then 0 else sum{o in Component}(CCP_p[i,o,ps] - CCP_p[i-1,o,ps]);#		 					|
#																							 				|
var GP_v{i in Optimizaton_Horizon, ps in Price_Scenario} = GP[i,ps] + GP_p[i,ps];#							|										
#------------------------------------------------------------------------------------------------------------

#------ Net Present Cost of In-field Gas Gathering (NPC^{gg}_{s}) -------------------------------------------
var GG_NPV{i in Constraint_Horizon, ps in Price_Scenario} = #												|
	sum {o in Component}(sum{a in Tier}(EUR[a]*x_v[a,i,ps])*EUR_Percent[o]*Coefficient[o])/ #				|
	(Coefficient[o]+R);#																					|
#																							 				|				
param GG_NPV_p{i in Param_Horizon, ps in Price_Scenario} = #												|
	sum {o in Component}(sum{a in Tier}(EUR[a]*x_p[a,i,ps])*EUR_Percent[o]*Coefficient[o])/ #				|
	(Coefficient[o]+R); #																					|	
#																							 				|					
var GG_Cost{i in Constraint_Horizon, ps in Price_Scenario} = GGC * GG_NPV[i,ps]; #							|
#																							 				|				
param GG_Cost_p{i in Param_Horizon, ps in Price_Scenario} = GGC * GG_NPV_p[i,ps]; #							|						
#------------------------------------------------------------------------------------------------------------


#------ NPC^{mid}_{t,s}: Net Present Cost of Midstream Services  --------------------------------------------
var NPC_GG_v{ps in Price_Scenario} = sum{i in Constraint_Horizon}(DF[i]*GG_Cost[i,ps]);  #					|
param NPC_GG_p{ps in Price_Scenario} = sum{i in Param_Horizon_A}(DF[i]*GG_Cost_p[i,ps]);  #					|
#																											|		
var NPC_GG{ps in Price_Scenario} = NPC_GG_v[ps] + NPC_GG_p[ps];  #											|
#------------------------------------------------------------------------------------------------------------

#-#-#-#-#-#-#-#-#-#  Constraints (Section 2.2) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
	
#------ Equation 2.1 ----------------------------------------------------------------------------------------
subject to Well_Limit{a in Tier, ps in Price_Scenario}: #													| 
	sum{i in Constraint_Horizon}(x_v[a,i,ps]) + sum{t in Param_Horizon}(x_p[a,t,ps]) <= Count[a]; #			|
#------------------------------------------------------------------------------------------------------------

	# Equation 2.2 is included in Upstream Services (Section 2.2)
	# Equation 2.3 = Cumulative Gas Production [Bcf]
	# Equation 2.4 = Time Period Based Step-Function (\chi^{WP}_{t,\tau})
	# Equation 2.5 = Monthly Gas Production [Bcf]
	# Equation 2.6 = Net Present Cost of In-field Gas Gathering
	# Equation 2.7 = Intertal Approximation for valuing gas production outside of drilling window





################################### Section 2.3 (Long-Term Agreement Specifications) ########################

#-#-#-#-#-#-#-#-#-#  Sets (Section 2.3) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

	# t \in T: Monthly Drilling Time Horizon

#-#-#-#-#-#-#-#-#-#  Parameters (Section 2.3) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#

#------ Upstream Long-Term Agreements Specifications --------------------------------------------------------
set WD_Configurations;  param WD_Configuration_Selection, default 1; # Selected via MATLAB Script			| 
#																											|
set WD_Horizon = 0..Param['LT_WD_Max_Horizon']; #															|
param Long_Term_WD_Options{WD_Configurations, WD_Horizon}, default 0; #										|
#																											|
var Long_Term_WD{i in Price_Horizon}>=0; #																	|
#																											|
subject to Long_Term_WD_ST_1{i in WD_Horizon}: #															|
	Long_Term_WD[i]=Long_Term_WD_Options[WD_Configuration_Selection, i]; #									|
#																											|
subject to Long_Term_WD_ST_2{i in Price_Horizon diff WD_Horizon}:Long_Term_WD[i]=0; # 						|	
#------------------------------------------------------------------------------------------------------------

#------ Midsteam Long-Term Agreements Specifications --------------------------------------------------------
set GT_Configurations;  param GT_Configuration_Selection, default 1; # Selected via MATLAB Script			| 
#																											|
set GT_Horizon = 0..Param['LT_GT_Max_Horizon']; #														 	|
param Take_or_Pay_Options{GT_Configurations, GT_Horizon}, default 0; #									 	|
#																											|
var Take_or_Pay{i in Price_Horizon}>=0; #																	|
#																											|
subject to Long_Term_GT_ST_1{i in GT_Horizon}: #															|
	Take_or_Pay[i] = Take_or_Pay_Options[GT_Configuration_Selection, i]; #									|
subject to Long_Term_GT_ST_2{i in Price_Horizon diff GT_Horizon}:Take_or_Pay[i]=0; # 						|
#------------------------------------------------------------------------------------------------------------

################################### Section 2.4 (Upstream Services) #########################################

#-#-#-#-#-#-#-#-#-# Sets (Section 2.4) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

	# a \in A: Well EUR Tiers
	# s \in S: Stochastic Natural Gas Price Scenarios
	# t, \tau \in T: Monthly Drilling Time Horizon

#-#-#-#-#-#-#-#-#-# Parameters (Section 2.4) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
	
	# var Long_Term_WD{i in Price_Horizon}>=0; # LT^{up}_{t}: Long-Term Upstream Agreement [Wells/Month]$	
param Max_Up = Param['Max_Up']; # Max^{up}: Upstream Services Limit [Wells/Month]
	# param R := Param['Discount_Rate']/12; # Monthly Discount Rate
	
param GR_UP = Param['GR_UP']; # RCL^{up}: Upstream Services Rate of Change Limit [Wells/Month]
param Mob_Cost = Param['Mobilization_Cost']; # RMC: Rig Mobilization Cost
param SR_UP, default 0; # SR^{up}: Long-Term Upstream Agreement Cost Savings 
param Well_Cost = Param['Well_Cost']; # WDC: Well Development Costs
param CapEx = Param['Well_CapEx_Percent'] * Well_Cost; # WDC^{fx}: Fixed Portion of Well Development Costs
param OpEx = Param['Well_OpEx_Percent'] * Well_Cost; # WDC^{vr}: Variable Portion of Well Development Costs

#-#-#-#-#-#-#-#-#-# Variable (Section 2.4) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

var Long_Term_WD_Usage{Constraint_Horizon, Price_Scenario}>=0;
param Long_Term_WD_Usage_p{Param_Horizon, Price_Scenario}, default 0;
	# LTU^{up}_{t,s}: Long-Term Upstream Services [Wells/Month]
	
	# NPC^{up}_{s}: Net Present Cost of Upstream Services -  DEFINED AT THE END OF THE SUBSECTION

var On_Demand_WD{Constraint_Horizon, Price_Scenario} >= 0;
param On_Demand_WD_p{Param_Horizon, Price_Scenario}, default 0;
	# OD^{up}_{t,s}: On-Demand Upstream Services [Wells/Month]

var Rig_Mobilization{Constraint_Horizon, Price_Scenario}>=0, integer; # RM_{t,s}: Rig Mobilizations [Rigs]	
param Rig_Mobilization_p{Param_Horizon, Price_Scenario}, default 0;

#------ Equation 2.16 ---------------------------------------------------------------------------------------
var Upstream_Service_Rate_of_Change{i in Constraint_Horizon, ps in Price_Scenario} = #						|
	if i = 0 then On_Demand_WD[i,ps] + Long_Term_WD[i] #													|
	else if i = Present_Month then #																		|
		 On_Demand_WD[i,ps] + Long_Term_WD[i] - (On_Demand_WD_p[i-1,ps] + Long_Term_WD[i-1]) #				|
	else On_Demand_WD[i,ps] + Long_Term_WD[i] - (On_Demand_WD[i-1,ps]+ Long_Term_WD[i-1]); #				|
#																											|		
subject to Rig_Mobilization_ST{i in Constraint_Horizon, ps in Price_Scenario}: #							|
	Rig_Mobilization[i,ps] >= Upstream_Service_Rate_of_Change[i,ps]; #										|
#------------------------------------------------------------------------------------------------------------

#------ Equation 2.12 ---------------------------------------------------------------------------------------
subject to Upstream_ST_1{i in Constraint_Horizon, ps in Price_Scenario}: #									|
	Long_Term_WD_Usage[i,ps] <= Long_Term_WD[i]; #									 						|
#------------------------------------------------------------------------------------------------------------

#------ Equation 2.13 ---------------------------------------------------------------------------------------
subject to Upstream_ST_2{i in Constraint_Horizon, ps in Price_Scenario}: #									|
	Long_Term_WD[i] + On_Demand_WD[i,ps] <= Max_Up; #														|
#------------------------------------------------------------------------------------------------------------

#------ Equation 2.14 ---------------------------------------------------------------------------------------
subject to Upstream_ST_3{i in Constraint_Horizon_A, ps in Price_Scenario}: #								|
	Upstream_Service_Rate_of_Change[i,ps]  <= GR_UP; #														|
#------------------------------------------------------------------------------------------------------------

# Well Development is treated as a culumative value in the optimization
subject to WDI_1{i in Constraint_Horizon_A, ps in Price_Scenario}:
	Well_Development_Integer[i,ps] >= Well_Development_Integer[i-1,ps];

#------ Equation 2.17 ---------------------------------------------------------------------------------------
subject to WDI_2{i in Constraint_Horizon, ps in Price_Scenario}: #											|
	sum{t in Present_Month..i}(On_Demand_WD[t,ps] + Long_Term_WD_Usage[t,ps]) + #							|
	sum{tt in 0..Present_Month}(On_Demand_WD_p[tt,ps] + Long_Term_WD_Usage_p[tt,ps]) #						|
		>= Well_Development_Integer[i,ps]; #																|
#																											|		
subject to WDI_3{i in Constraint_Horizon, ps in Price_Scenario}: #											|
	sum{t in Present_Month..i, a in Tier}(x_v[a,t,ps]) + #													|
	sum{tt in 0..Present_Month, b in Tier}(x_p[b,tt,ps]) <= Well_Development_Integer[i,ps]; #				|
#------------------------------------------------------------------------------------------------------------

#------ Equation 2.18 (NPC^{up}_{s}) ------------------------------------------------------------------------
var On_Demand_WD_Cost_v{i in Constraint_Horizon, ps in Price_Scenario} #									|
	= On_Demand_WD[i,ps]*(CapEx+OpEx); #																	|
#																											|		
param On_Demand_WD_Cost_p{i in Param_Horizon, ps in Price_Scenario} = On_Demand_WD_p[i,ps]*(CapEx+OpEx); #	|
#																											|		
var Rig_Mobilization_Cost{i in Constraint_Horizon, ps in Price_Scenario} #									|
	= Rig_Mobilization[i,ps]*Mob_Cost; #																	|
#																											|			
param Rig_Mobilization_Cost_p{i in Param_Horizon, ps in Price_Scenario} #									|
	= Rig_Mobilization_p[i,ps]*Mob_Cost; #																	|
#																											|		
var Well_OpEx{i in Constraint_Horizon, ps in Price_Scenario} =  Long_Term_WD_Usage[i,ps]*OpEx; #			|
#																											|		
param Well_OpEx_p{i in Param_Horizon, ps in Price_Scenario} =  Long_Term_WD_Usage_p[i,ps]*OpEx; #			|
#																											|		
var WD_Cost_v{i in Constraint_Horizon, ps in Price_Scenario} = On_Demand_WD_Cost_v[i,ps] + #				|
	Long_Term_WD[i] * CapEx*(1-SR_UP) + Well_OpEx[i,ps] + Rig_Mobilization_Cost[i,ps]; #					|
#																											|		
var WD_Cost_p{i in Param_Horizon, ps in Price_Scenario} = On_Demand_WD_Cost_p[i,ps] + #						|
	Long_Term_WD[i] * CapEx*(1-SR_UP) + Well_OpEx_p[i,ps] + Rig_Mobilization_Cost_p[i,ps]; #				|
#------------------------------------------------------------------------------------------------------------








################################### Section 2.5 (Midstream Services) ########################################

#-#-#-#-#-#-#-#-#-# Sets (Section 2.5) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

	# a \in A: Well EUR Tiers
	# c \in C: Exponential Decline Components
	# s \in S: Stochastic Natural Gas Price Scenarios
	# t, \tau \in T: Monthly Drilling Time Horizon

#-#-#-#-#-#-#-#-#-# Parameters (Section 2.4) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
	
	# LT^{mid}_{t}: Long-Term Midstream Agreement [Bcf]
param Max_Mid = Param['Max_Mid']; # Max^{mid}: Midstream Services Limit [Bcf]
param MSC = Param['Midstream_Cost']; # MSC: Midstream Service Cost [\$/Bcf]
param SR_MID, ; # SR^{mid}: Long-Term Midstream Agreement Cost Savings (READ in from MATLAB/NOT Excel Sheet)
	# r: Monthly Discount Rate
param GR_MID = Param['GR_MID']; # RCL^{mid}: Midstream Services Rate of Change Limit [Bcf]

#-#-#-#-#-#-#-#-#-# Variable (Section 2.6) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

	# NPC^{mid}_{t,s}: Net Present Cost of Midstream Services
	
	# OD^{mid}_{t,s}: On-Demand Midstream Services
var Flexible_MS_v{Constraint_Horizon, Price_Scenario}>=0;
param Flexible_MS_p{Param_Horizon, Price_Scenario}, default 0;
	# q_{t,s}: Monthly Gas Production [Bcf]
	# Q_{t,s}: Cumulative Gas Production [Bcf]

var Midstream_Service_Rate_of_Change{i in Constraint_Horizon, ps in Price_Scenario} = 
	if i = 0 then Flexible_MS_v[i,ps] 
	else if i = Present_Month then Flexible_MS_v[i,ps] - Flexible_MS_p[i-1,ps] 
	else Flexible_MS_v[i,ps] - Flexible_MS_v[i-1,ps]; 

#------ Equation 2.19 ---------------------------------------------------------------------------------------
subject to MS_ST_1{i in Constraint_Horizon, ps in Price_Scenario}: #										|
	Flexible_MS_v[i,ps] + Take_or_Pay[i] <= Max_Mid; #														|
#------------------------------------------------------------------------------------------------------------

#------ Equation 2.20 ---------------------------------------------------------------------------------------
subject to MS_ST_2{i in Constraint_Horizon diff {0}, ps in Price_Scenario}: #								|
	Midstream_Service_Rate_of_Change[i,ps] <= GR_MID; #														|
#------------------------------------------------------------------------------------------------------------	

#------ Equation 2.22 ---------------------------------------------------------------------------------------
subject to MS_ST_4{i in Constraint_Horizon, ps in Price_Scenario}: #										|
	Flexible_MS_v[i,ps] + Take_or_Pay[i] >= sum{a in Tier}(x_v[a,i,ps]*EUR[a]); #							|
#------------------------------------------------------------------------------------------------------------

#------ Equation 2.23 ---------------------------------------------------------------------------------------
var Take_or_Pay_Cost{i in Optimizaton_Horizon} = #															|
	sum {o in Component}(Take_or_Pay[i]*EUR_Percent[o]*Coefficient[o])/(Coefficient[o]+R); #				|
#																											|			
var On_Demand_MS_v{i in Constraint_Horizon, ps in Price_Scenario} =  #										|
	(sum{o in Component}(Flexible_MS_v[i,ps]*EUR_Percent[o]*Coefficient[o])/(Coefficient[o]+R)); #			|
#																											|		
param On_Demand_MS_p{i in Param_Horizon, ps in Price_Scenario} =  #											|
	(sum {o in Component}(Flexible_MS_p[i,ps]*EUR_Percent[o]*Coefficient[o])/(Coefficient[o]+R));	#		|
#																											|		
var MS_Cost_v{i in Constraint_Horizon, ps in Price_Scenario} #												|
	= MSC*(Take_or_Pay_Cost[i]*(1-SR_MID) + On_Demand_MS_v[i,ps]); #										|
#																											|		
var MS_Cost_p{i in Param_Horizon, ps in Price_Scenario} #													|
	= MSC*(Take_or_Pay_Cost[i]*(1-SR_MID) + On_Demand_MS_p[i,ps]); #										|
#------------------------------------------------------------------------------------------------------------

#------ NPC^{mid}_{t,s}: Net Present Cost of Midstream Services  --------------------------------------------
var NPC_Mid_v{ps in Price_Scenario} = sum{i in Constraint_Horizon}(DF[i]*MS_Cost_v[i,ps]);  #				|
var NPC_Mid_p{ps in Price_Scenario} = sum{i in Param_Horizon_A}(DF[i]*MS_Cost_p[i,ps]);  #					|
#																											|		
var NPC_Mid{ps in Price_Scenario} = NPC_Mid_v[ps] + NPC_Mid_p[ps];  #										|
#------------------------------------------------------------------------------------------------------------

################################### Section 2.6 (Natural Gas Price Model) ###################################

#-#-#-#-#-#-#-#-#-# Sets (Section 2.6) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

	# s \in S: Stochastic Natural Gas Price Scenarios
	# t, \tau \in T: Monthly Drilling Time Horizon

#-#-#-#-#-#-#-#-#-# Parameters (Section 2.6) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

param MR = Param['MeanRev']*21; # \lambda_\omega: Process Reversion Speed
	# \sigma_\omega: Process Volatility
param x_bar = log(Param['ReversionLevel']); # \overline{\omega}: Process Reversion Level

#-#-#-#-#-#-#-#-#-# Variable (Section 2.6) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

# \omega_{t,s}: Natural Logarithm of Gas Price [$\ln$(\$/MMBtu)]
param NGP{Price_Horizon, Price_Scenario}; #  Natural Logarithm of Gas Price [ln($/MMBtu)]

#------ Natural Gas Price and Future Expectation [$/MMBtu]  -------------------------------------------------
param NG_Price{i in Price_Horizon, ps in Price_Scenario} = if i <= Present_Month then exp(NGP[i,ps]) #		|
	else exp(x_bar + (NGP[Present_Month,ps] - x_bar)*exp(MR*(Present_Month-i))); #							|
#																											|		
param NG_Realized{i in Param_Horizon, ps in Price_Scenario} = NG_Price[i,ps]; #								|
#																											|		
param NG_Future{i in Constraint_Horizon, ps in Price_Scenario} = NG_Price[i,ps]; #							|
#------------------------------------------------------------------------------------------------------------












































################################### Section 2.7 (Net Present Cost, Revenue and Value) #######################

#-#-#-#-#-#-#-#-#-# Sets (Section 2.7) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

	# a \in A: Well EUR Tiers
	# c \in C: Exponential Decline Components 
	# s \in S: Stochastic Natural Gas Price Scenarios
	# t, \tau \in T: Monthly Drilling Time Horizon

#-#-#-#-#-#-#-#-#-# Parameters (Section 2.7) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

param GPM = (1+Param['Gross_Profit_Margin']); # PMT: Profit Margin Target 
param RR = Param['Royalty_Rate'];  # RR: Royalty Rate
	# \gamma_c: Fraction of EUR in Component 
 	# \Delta \tau: Planning Window Width [Months]
	# \Psi_{t,\tau,s}: Natural Gas Price and Future Expectation [\$/MMBtu]
	# \omega_{t,s}: Natural Logarithm of Gas Price [$\ln$(\$/MMBtu)]

#-#-#-#-#-#-#-#-#-# Variable (Section 2.7) #-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-


#------ NPC^{up}_{t,s}: Net Present Cost of Upstream Services  ----------------------------------------------
var NPC_Up_v{ps in Price_Scenario} = sum{i in Constraint_Horizon}(DF[i]*WD_Cost_v[i,ps]); #					|		
var NPC_Up_p{ps in Price_Scenario} = sum{i in Param_Horizon_A}(DF[i]*WD_Cost_p[i,ps]);  #					|
#																											|		
var NPC_Up{ps in Price_Scenario} = NPC_Up_v[ps] + NPC_Up_p[ps]; #											|
#------------------------------------------------------------------------------------------------------------

#------ NPC_{\tau,s}: Total Net Present Cost  ---------------------------------------------------------------
var NPC{ps in Price_Scenario} = NPC_Mid[ps] + NPC_Up[ps] + NPC_GG[ps];  #									|
#------------------------------------------------------------------------------------------------------------

#------ NPR_{\tau,s}: Net Present Revenue -------------------------------------------------------------------
var OpRev{i in Optimizaton_Horizon, ps in Price_Scenario} = GP[i,ps]*(NG_Price[i,ps]*(1-RR)); #				|
param OpRev_p{i in Optimizaton_Horizon, ps in Price_Scenario} = GP_p[i,ps]*(NG_Price[i,ps]*(1-RR)); #		|
#																											|			
var EUR_v{o in Component, ps in Price_Scenario} = #															| 
	sum{i in Constraint_Horizon, a in Tier}(x_v[a,i,ps]*EUR[a]*EUR_Percent[o]) - CCP[Final_Month,o,ps];  #	|
#																											|			
param EUR_p{o in Component, ps in Price_Scenario} =   #														|
	sum{i in Param_Horizon, a in Tier}(x_p[a,i,ps]*EUR[a]*EUR_Percent[o]) - CCP_p[Final_Month,o,ps];  #		|
#																											|		
var Terminal_NPP_v{ps in Price_Scenario} = #																|
	sum{o in Component}(EUR_v[o,ps]*Coefficient[o]/(Coefficient[o]+R));   #									|
#																											|	
param Terminal_NPP_p{ps in Price_Scenario} = #																|
	sum{o in Component}(EUR_p[o,ps]*Coefficient[o]/(Coefficient[o]+R));   #									|
#																											|
var Terminal_Rev_v{ps in Price_Scenario} = (Terminal_NPP_v[ps]*exp(x_bar)*(1-RR)); #						|
param Terminal_Rev_p{ps in Price_Scenario} = (Terminal_NPP_p[ps]*exp(x_bar)*(1-RR)); #						|
#																											|			
var NPR_v{ps in Price_Scenario} = sum{i in Optimizaton_Horizon}(DF[i]*OpRev[i,ps]);   #						|
param NPR_p{ps in Price_Scenario} = sum{i in Optimizaton_Horizon}(DF[i]*OpRev_p[i,ps]);   #					|
#																											|		
var NPR{ps in Price_Scenario} = NPR_v[ps] + NPR_p[ps] +   #													|
	Terminal_Rev_v[ps]*DF[Final_Month] + Terminal_Rev_p[ps]*DF[Final_Month];   #							|
#------------------------------------------------------------------------------------------------------------

#------ NPV_{\tau,s}: Net Present Value ---------------------------------------------------------------------
var NPV_CM{ps in Price_Scenario} =  #																		| 
	(NPR_v[ps] +  Terminal_Rev_v[ps]*DF[Final_Month] - (NPC_Up_v[ps] + NPC_Mid_v[ps] + NPC_GG_v[ps])*GPM) + #
	(NPR_p[ps] +  Terminal_Rev_p[ps]*DF[Final_Month] - (NPC_Up_p[ps] + NPC_Mid_p[ps] + NPC_GG_p[ps])*GPM);  #
#------------------------------------------------------------------------------------------------------------
	
maximize OF_1:NPV_CM[1]; # Additional objective functions terms are added with Matlab Script 
# Recall we are using GUROBI's multi-objective to solve price scenarios in parallel 
