CREATE PROCEDURE sp_rpt_batch_gallons
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location_in		varchar(15)
,	@tracking_num_in	varchar(15)
,	@user_id			varchar(10)
,	@debug				int
,	@cycle_in			int
,	@recipe_id			int
,	@reagent_id			int
AS
/***************************************************************************************

execute dbo.sp_rpt_batch_gallons 21,0,'09/11/2008', '09/15/2008', 'SYSTECH', '90968','ANITHA_M',0, 1,1,125

10/29/2018 AM	Created/Started
  This is copy of sp_batch_gallons procedure. 

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
@cycle varchar(15),
@pound_conv decimal(10,4),
@container_gallons decimal(10,4)

-- Create a table to receive the container list
CREATE TABLE #tmp (
	Container 			varchar(15) NULL,
	receipt_id 			int NULL, 
	line_id 			int NULL, 
	container_type 		varchar(1) NULL, 
	container_id 		int NULL, 
	sequence_id 		int NULL, 
	company_id			int NULL,
	profit_ctr_id 		int NULL,
	location 			varchar(15) NULL, 
	tracking_num 		varchar(15) NULL, 
	cycle				int NULL,
	receipt_date 		datetime NULL, 
	disposal_date 		datetime NULL, 
	generator_name 		varchar(40), 
	quantity 			decimal(10,4) NULL, 
	bill_unit_code 		varchar(4) NULL,
	gal_conv 			decimal(10,4) NULL, 
	manifest 			varchar(15) NULL, 
	manifest_line_id 	varchar(1) NULL, 
	approval_code 		varchar(15) NULL, 
	treatment_id 		int NULL, 
	bulk_flag 			varchar(1) NULL, 
	benzene 			float NULL, 
	generic_flag 		varchar(1) NULL,
	approval_comments 	varchar(1700) NULL, 
	waste_flag 			varchar(1) NULL, 
	const_flag 			varchar(1) NULL, 
	group_waste 		varchar(2000) NULL, 
	group_const 		varchar(2000) NULL, 
	group_container 	varchar(2000) NULL, 
	base_container 		varchar(15) NULL, 
	user_id 			varchar(8) NULL,
	batch_date			datetime NULL,
	manifest_line       int null
)

IF @cycle_in = 0 
	SET @cycle = 'ALL' 
ELSE
	SET @cycle = CONVERT(varchar(15), @cycle_in)

IF @date_from IS NULL
	SET @date_from = '1-1-1980'
IF @date_to IS NULL
	SET @date_to = getdate()

---------------------------------------------
-- Get the gallons
---------------------------------------------
-- These are receipt gallons
EXEC sp_work_batch_container @company_id, @profit_ctr_id, @date_from, @date_to, @location_in, @tracking_num_in, @user_id, 0
	
SELECT @pound_conv = pound_conv
FROM BillUnit  
WHERE bill_unit_code = 'GAL' 

SELECT DISTINCT ( 
 SELECT  Round( SUM (quantity * gal_conv), 2 ) * lab_reagent_percentage /100 * @pound_conv  )
 FROM #tmp
 JOIN RecipeHeader rh ON #tmp.company_id = rh.company_id 
   AND #tmp.profit_ctr_id = rh.profit_ctr_id 
   AND #tmp.location = rh.batch_location  
   AND rh.recipe_id  = @recipe_id
 JOIN RecipeDetail rd ON #tmp.company_id = rd.company_id 
   AND #tmp.profit_ctr_id = rd.profit_ctr_id  
   AND rd.recipe_id  = @recipe_id
   AND rd.reagent_uid  = @reagent_id 
 JOIN Reagent r ON r.reagent_uid = rd.reagent_uid
 WHERE (@cycle = 'ALL' OR #tmp.cycle <= @cycle_in)    
GROUP BY quantity ,gal_conv
    , lab_reagent_percentage
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_gallons] TO [EQAI]
    AS [dbo];
GO

