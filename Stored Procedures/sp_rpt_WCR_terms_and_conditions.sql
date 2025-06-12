
CREATE PROCEDURE sp_rpt_WCR_terms_and_conditions
AS
/***************************************************************************************
Returns terms & conditions for WCR
Loads to:		Plt_AI
PB Object(s):	d_rpt_WCR_terms_and_conditions
09/20/2011		SK	Created
05/17/2013		RB	Replaced text "Waste Characterization Report" with "Waste Profile Form"
09/19/2017		MPM	Replaced "bad" apostrophe in Condition 9.

EXEC sp_rpt_WCR_terms_and_conditions

****************************************************************************************/
-----------------------------------------------------------
-- Create table to store terms & conditions
-----------------------------------------------------------
CREATE TABLE #tmp_terms_conditions (
	sequence_id		tinyint			NULL
,	sub_sequence_id	tinyint			NULL
,	title			varchar(100)	NULL
,	sub_title		varchar(100)	NULL	
,	cond_desc		varchar(max)	NULL )

-----------------------------------------------------------
-- Condition 1 DEFINITIONS
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 1, 1, 'Definitions', '"Acceptable Waste"'
,'"Acceptable Waste" shall mean any hazardous waste, as defined under applicable State or federal law, determined by EQ as acceptable for treatment and/or disposal in accordance with this Agreement.'
) 
	
INSERT INTO #tmp_terms_conditions VALUES( 1, 2, 'Definitions', '"Delivered Wastes"'
,'"Delivered Wastes" shall mean all wastes (i) which are transported, delivered, or tendered to EQ by the Customer; (ii) which the Customer has arranged for the transport, delivery or tender to EQ; or (iii) ) which are transported, delivered, or tendered to EQ under a Credit Agreement between the Customer and EQ.'
)

INSERT INTO #tmp_terms_conditions VALUES( 1, 3, 'Definitions', '"Non-Conforming Wastes"'
,'"Non-Conforming Wastes" shall mean wastes that (a) are not in accordance in all material respects with the warranties, descriptions, specifications or limitations stated in the Waste Profile Form and this Agreement; (b) have constituents or components of a type or concentration not specifically identified in the Waste Profile Form (i) which increase the nature or extent of the hazard and risk undertaken by EQ in treating and/or disposing of the waste, or (ii) for whose treatment and/or disposal a Waste Management Facility is not designed or permitted, or (iii) which increase the cost of treatment and/or disposal of waste beyond that specified in EQ''s price quote; or (c) are not properly packaged, labeled, described, or placarded, or otherwise not in compliance with United States Department of Transportation and United States Environmental Protection Agency regulations.'
)

-----------------------------------------------------------
-- Condition 2 CONTROL OF OPERATIONS               
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 2, NULL, 'Control of Operations.', NULL
,'EQ shall have sole control over all aspects of the operation of any treatment and/or disposal facility of EQ receiving Delivered Wastes under this Agreement (hereinafter, 
"Waste Management Facility"), including, without limitation, maintaining EQ''s desired volume of Acceptable Wastes being delivered to any Waste Management Facility by the Customer or any other person or entity.
')

-----------------------------------------------------------
-- Condition 3 IDENTIFICATION OF WASTE
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 3, NULL, 'Identification of Waste.', NULL
,'For each waste material to be transported, delivered, or tendered to EQ under this Agreement, the Customer shall provide, or cause to be provided, to EQ a representative sample of the waste material and a completed Waste Profile Form containing a physical and chemical description or analysis of such waste material, which description shall conform with any and all guidelines for waste acceptance provided by EQ.  On the basis of EQ''s analysis of such representative sample of the waste material and such Waste Profile Form, EQ will determine whether such wastes are Acceptable Wastes.  EQ does not make any guarantee that it will handle any waste material or any particular quantity or type of waste material, and EQ reserves the right to the decline to transport, treat and/or dispose of waste material.  The Customer shall promptly furnish to EQ any information regarding known, suspected or planned changes in the composition of the waste material.  Further, the Customer shall promptly inform EQ of any change in the characteristic or condition of the waste material which becomes known to the Customer subsequent to the date of the Waste Profile Form.'
)

-----------------------------------------------------------
-- Condition 4 NON-CONFORMING WASTES
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 4, NULL, 'Non-Conforming Wastes.', NULL
,'In the event that EQ at any time discovers that any Delivered Waste is Non-Conforming Waste, EQ may reject or revoke its acceptance of the Non-Conforming Waste.  The Customer shall have seven (7) days to direct an alternative lawful manner of disposition of the waste, unless it is necessary by reason of law or otherwise to move the Non-Conforming Waste prior to expiration of the seven (7) day period.  If the Customer does not direct an alternative disposal, at its option, EQ may return any such Non-Conforming Wastes to the Customer, and the Customer shall pay or reimburse EQ for all costs and expenses incurred by EQ in connection with the receipt, handling, sampling, analyses, transportation and return to the Customer of such Non-Conforming Wastes.  If it is impossible or impractical for EQ to return the Non-Conforming Waste to the Customer, the Customer shall reimburse EQ for all costs, of any type or nature whatsoever, incurred by EQ, solely because such Delivered Waste was Non-Conforming Waste (including, but not limited to, all costs associated with any remedial steps necessary, due to the nature of the Non-Conforming Waste, in connection with material with which the Non-Conforming Waste may have been commingled and all expenses and charges for analyzing, handling, locating, preparing for transporting, storing and disposing of any Non-Conforming Waste).'
)

-----------------------------------------------------------
-- Condition 5 CUSTOMER WARRANTY - ACCEPTABLE WASTES.
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 5, NULL, 'Customer Warranty - Acceptable Wastes.', NULL
,'All Delivered Wastes shall be Acceptable Wastes and shall conform in all material respects to the description and specifications contained in the Waste Profile Form.  The information set forth in the Waste Profile Form or any manifest, placard or label associated with any Delivered Wastes, or otherwise represented by the Customer or the generator (if other than the Customer) to EQ, is and shall be true, accurate and complete as of the date of receipt of the involved waste by EQ.'
)

-----------------------------------------------------------
-- Condition 6 CUSTOMER WARRANTY - TITLE TO WASTES.
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 6, NULL, 'Customer Warranty - Title to Wastes.', NULL
,'Either the Customer or the generator (if other than the Customer) shall hold clear title, free of any all liens, claims, encumbrances, and charges to Delivered Waste until such waste is accepted by EQ.'
)

-----------------------------------------------------------
-- Condition 7 CUSTOMER WARRANTY - COMPLIANCE WITH LAWS.  
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 7, NULL, 'Customer Warranty - Compliance with Laws.', NULL
,'The Customer shall comply with all applicable federal, state and local environmental statutes, regulations, and other governmental requirements, as well as directives issued by EQ from time to time, governing the transportation, treatment and/or disposal of Acceptable Wastes, including, but not limited to, all packaging, manifesting, containerization, placarding and labeling requirements.'
)

-----------------------------------------------------------
-- Condition 8 CUSTOMER WARRANTY - UPDATING INFORMATION.
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 8, NULL, 'Customer Warranty - Updating Information.', NULL
,'If the Customer receives information that Delivered Waste or other hazardous waste described in the Waste Profile Form, or some component of such waste, presents or may present a hazard or risk to persons, property or the environment which was not disclosed to EQ, or if the Customer or generator (if other than the Customer) has changed the process by which such waste results, the Customer shall promptly report such information to EQ in writing.'
)

-----------------------------------------------------------
-- Condition 9 CUSTOMER INDEMNITY
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 9, NULL, 'Customer Indemnity.', NULL
,'The Customer shall indemnify, defend and hold harmless EQ, and its affiliated or related companies, and all of their respective present or future officers, directors, shareholders, employees and agents from and against any and all losses, damages, liabilities, penalties, fines, forfeitures, demands, claims, causes of action, suits, costs and expenses (including, but not limited to, reasonable costs of defense, settlement, and reasonable attorneys'' fees), which may be asserted against any or all of them by any person or any governmental agency, or which any or all of them may hereafter suffer, incur, be responsible for or pay out, as a result of or in connection with bodily injuries (including, but not limited to, death, sickness, disease and emotional or mental distress) to any person (including EQ''s employees), damage (including, but not limited to, loss of use) to any property (public or private), or any requirements to conduct or incur expense for investigative, removal or remedial expenses in connection with contamination of or adverse effect on the environment, or any violation or alleged violation of any statutes, ordinances, orders, rules or regulations of any governmental entity or agency, caused or arising out of (i) a breach of this Agreement by the Customer, (ii) the failure of any warranty of the Customer to be true, accurate and complete, or (iii) any willful or negligent act or omission of the Customer, or its employees or agents in connection with the performance of this Agreement.'
)

-----------------------------------------------------------
-- Condition 10 FORCE MAJEURE
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 10, NULL, 'Force Majeure.', NULL
,'EQ shall not be liable for any failure to accept, receive, handle, treat, and/or dispose of Delivered Waste due to an act of God, fire, casualty, flood, war, strike, lockout, labor trouble, failure of public utilities, equipment failure, facility shutdown, injunction, accident, epidemic, riot, insurrection, destruction of operation or transportation facilities, the inability to procure materials, equipment, or sufficient personnel or energy in order to meet operational needs without the necessity of allocation, the failure or inability to obtain any governmental approvals or to meet Environmental Requirements (including, but not limited to voluntary or involuntary compliance with any act, exercise, assertion, or requirement of any governmental authority) which may temporarily or permanently prohibit operations of EQ, the Customer, or the Generator, or any other circumstances beyond the control of EQ which prevents or delays performance of any of its obligations under this Agreement.'
)

-----------------------------------------------------------
-- Condition 11 GOVERNING LAWS
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 11, NULL, 'Governing Laws', NULL
,'This Agreement shall in all respects be governed by and shall be construed in accordance with the laws of the State of Michigan applied to contracts executed and performed wholly within such state.'
)

-----------------------------------------------------------
-- Condition 12 BULK DISPOSAL CHARGES
-----------------------------------------------------------
INSERT INTO #tmp_terms_conditions VALUES( 12, NULL, 'Bulk Disposal Charges', NULL
,'Quoted bulk disposal charges for solid materials will be billed by the cubic yard, if the waste density is less than 2,000lbs./cubic yard. If waste density is greater than 2,000 lbs./cubic yard, then bulk disposal charges will be billed by the ton, regardless of the approved container.'
)

--------------------------------------------------------------------------
-- SELECT ALL TERMS & CONDITIONS ORDER BY SEQUENCE ID, SUB SEQUENCE ID
--------------------------------------------------------------------------
SELECT * FROM #tmp_terms_conditions ORDER BY sequence_id, sub_sequence_id asc

DROP TABLE #tmp_terms_conditions

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_WCR_terms_and_conditions] TO [EQAI]
    AS [dbo];

