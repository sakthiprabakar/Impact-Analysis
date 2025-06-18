CREATE PROCEDURE [dbo].[sp_batch_recipe] 
	@company_id		int, 
	@profit_ctr_id	int,
	@location		varchar(15), 
	@tracking_num	varchar(MAX),
	@cycle			int
AS
/***********************************************************
This SP retrieves the distinct set of recipes from assigned approvals 

Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_batch_recipe.sql
PB Object(s):	None
SQL Object(s):	Called from sp_batch_recalc

10/15/2018 AM	Created
				
sp_batch_recipe 'SYSTECH', '1029966-16', 21, 0, 1, 1 
sp_batch_recipe 21,0,'SYSTECH', '91004',2
sp_batch_recipe 21,0,'702', '23234',4
sp_batch_recipe 21,0,'702', '23234',4
sp_batch_recipe 29,0,'T101', '156',3

02/08/2025	KM	US140503, US140504 Rewrote the Stored Procedure to remove the usage of cursor,
				utilize fn_receipt_weight_container and fn_calculate_gallons,
				obtain the list of common recipes for all the profiles in the batch,
				retrieve the aggregated sum of container weight and volume on the batch,
				enhance the error handling mechanism to show messages relavant to the scenario
**************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @message varchar(500),
        @rowcount int,
		@profile_recipe_count int

CREATE TABLE #tmp_profile_base_data
(company_id int,
profit_ctr_id int,
batch_location varchar(100),
tracking_num varchar(100),
receipt_id int,
line_id int,
profile_id int,
container_id int,
sequence_id int,
container_weight decimal(10, 2),
container_volume decimal(10, 2))

CREATE TABLE #tmp_recipe_result
(profile_id int,
recipe_id int,
mix_order_sequence_id int,
step_status char(1),
reagent_desc varchar(200),
lab_reagent_percentage decimal(5, 2),
batch_total_gallons decimal(10, 2),
batch_total_weight decimal(10, 2))

--Load the Base table for Profile Data
INSERT #tmp_profile_base_data
(company_id, profit_ctr_id, batch_location, tracking_num, receipt_id,
line_id, profile_id, container_id, sequence_id, container_weight)
SELECT DISTINCT
ContainerDestination.Company_id,
ContainerDestination.Profit_ctr_id,
@location,
@tracking_num,
ContainerDestination.Receipt_id,
ContainerDestination.line_id,
Receipt.Profile_id,
ContainerDestination.Container_id,
ContainerDestination.sequence_id,
Container.container_weight * (ContainerDestination.container_percent / 100.0)
from ContainerDestination
JOIN Receipt (NOLOCK)
ON Receipt.company_id = ContainerDestination.company_id
	AND Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Receipt.receipt_id = ContainerDestination.receipt_id
	AND Receipt.line_id = ContainerDestination.line_id
INNER JOIN Container (NOLOCK) ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
WHERE ContainerDestination.location = @location
AND ( ContainerDestination.tracking_num = @tracking_num  OR ContainerDestination.tracking_num IS Null )
AND ( ContainerDestination.cycle <=  @cycle  OR ContainerDestination.cycle IS Null )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'I'
AND Receipt.receipt_status IN ('N','L','U','A')
AND Receipt.fingerpr_status = 'A'
AND ContainerDestination.status = 'C'
UNION
SELECT DISTINCT
ContainerDestination.Company_id,
ContainerDestination.Profit_ctr_id,
@location,
@tracking_num,
ContainerDestination.Receipt_id,
ContainerDestination.line_id,
0 as Profile_id,
ContainerDestination.Container_id,
ContainerDestination.sequence_id,
Container.container_weight * (ContainerDestination.container_percent / 100.0)
FROM  ContainerDestination
INNER JOIN Container ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
where  ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND ( ContainerDestination.tracking_num = @tracking_num   OR ContainerDestination.tracking_num IS Null )
AND ( ContainerDestination.cycle <= @cycle  OR ContainerDestination.cycle IS Null )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.container_type = 'S'

--Update the Weight by calling the fn_receipt_weight_container function
UPDATE #tmp_profile_base_data
SET container_weight = dbo.fn_receipt_weight_container(receipt_id, line_id, @profit_ctr_id, @company_id, container_id, sequence_id)
FROM #tmp_profile_base_data
WHERE (container_weight IS NULL or container_weight = 0)

--Update Batch Gallons by calling the fn_calculated_gallons function
UPDATE #tmp_profile_base_data
SET container_volume = dbo.fn_calculated_gallons(@company_id, @profit_ctr_id, receipt_id, line_id, container_id, sequence_id)
FROM #tmp_profile_base_data

--JOIN the Base table with Recipe Tables and obtain Recipe Attributes, Insert into #tmp_recipe_result
INSERT #tmp_recipe_result (profile_id, recipe_id, mix_order_sequence_id, step_status,
reagent_desc, lab_reagent_percentage)
SELECT DISTINCT
Base.profile_id,
ApprRecipe.recipe_id,
Detail.mix_order_sequence_id,
Detail.Step_status,
Reagent.reagent_desc,
Detail.lab_reagent_percentage
FROM #tmp_profile_base_data Base
JOIN ProfileApprovalRecipe ApprRecipe
	ON Base.profile_id = ApprRecipe.profile_id
	AND Base.company_id = ApprRecipe.company_id
	AND Base.profit_ctr_id = ApprRecipe.profit_ctr_id
JOIN RecipeDetail Detail
	ON ApprRecipe.Recipe_id = Detail.Recipe_id
	AND ApprRecipe.company_id = Detail.company_id
	AND ApprRecipe.profit_ctr_id = Detail.profit_ctr_id
JOIN Reagent
	ON Reagent.Reagent_uid = Detail.Reagent_uid

--Select the Inserted Row Count to show a different error message if the Profiles do have recipes but not the same recipe
SELECT @profile_recipe_count = @@ROWCOUNT

--Update the Batch Total Gallons by summing up on Batch Location and Tracking Number for Non-Stock Containers
UPDATE #tmp_recipe_result SET batch_total_gallons =
(SELECT SUM(container_volume) FROM #tmp_profile_base_data
WHERE receipt_id <> 0
GROUP BY batch_location, tracking_num)

--Update the Batch Total Weight by summing up on Batch Location and Tracking Number for Non-Stock Containers
UPDATE #tmp_recipe_result SET batch_total_weight = 
(SELECT SUM(container_weight) FROM #tmp_profile_base_data
WHERE receipt_id <> 0
GROUP BY batch_location, tracking_num)

--Insert the Results into Recipe Output temp table (The only purpose of this Temp table is to return the ERROR banner
--message if there are no records for the Output
SELECT DISTINCT recipe_id, mix_order_sequence_id, step_status, reagent_desc,
lab_reagent_percentage, batch_total_gallons, batch_total_weight,
((batch_total_weight*lab_reagent_percentage)/100) as calc_lab_weight,
0.00 as actual_amt, 'N' as recipe_select, '' as primary_indicator, NULL AS error_message
INTO #tmp_recipe_output
FROM #tmp_recipe_result
WHERE recipe_id in
(SELECT recipe_id
FROM #tmp_recipe_result
GROUP BY recipe_id
HAVING COUNT(DISTINCT profile_id) = (SELECT COUNT(DISTINCT profile_id) FROM #tmp_recipe_result))

--If there are no records, return an EMPTY row with an Error Message
IF @@ROWCOUNT = 0
	BEGIN
		IF @profile_recipe_count = 0
			BEGIN
				SELECT @message = 'There are no Recipes for any of the Profiles in this Batch. Please review each Profile and associate a Recipe with atleast one of them to determine the Treatment Recipe for this Batch.'
			END
		ELSE
			BEGIN
				SELECT @message = 'The Profiles on the Batch do not have the same Recipe(s) associated with them. Please review each Profile and associate the same Recipe(s) with the Profiles to determine the Treatment Recipe for this Batch.'
			END
		SELECT 0, 0, NULL, NULL, 0, 0, 0, 0, 0, NULL, NULL, @message
	END
ELSE
	BEGIN
		SELECT recipe_id, mix_order_sequence_id, step_status, reagent_desc,
		lab_reagent_percentage, batch_total_gallons, batch_total_weight,
		calc_lab_weight, actual_amt, recipe_select, primary_indicator, error_message from #tmp_recipe_output
	END

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_recipe] TO [EQAI]
    AS [dbo];
GO