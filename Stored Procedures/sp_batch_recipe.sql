CREATE PROCEDURE sp_batch_recipe 
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
**************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @receipt_id int,
		@line_id int,
		@container_id int,
		@recipe_id int,
		@mix_order_sequence_id int,
		@reagent_uid int,	
		@lab_reagent_percentage float,
		@ret int,
		@message varchar(500),
		@no_row int,
        @debug int = 0,
        @rowcount int
        
 SET @message = 'There are multiple profiles in this batch. Please review each one and its associated recipe to determine the treatment recipe for this batch.'
		
--IF @debug = 1 print 'called with @location: ' + @location + ' @tracking_num: ' + @tracking_num 
	
CREATE TABLE #tmp_recipe (
		location varchar (15),
		tracking_num	varchar (15),
		receipt_id	int,
		line_id int,
		container_id int,
		recipe_id int		 
	)

CREATE TABLE #tmp_result (
		recipe_id int,
		source_container varchar(40),
		approval varchar(40),
		reagent_desc varchar(40),
		lab_percentage float,
		mix_order_sequence_id int,
		calc_amount float,
		user_calc_amount float ,
		err_message varchar (100),
		dummy_total_amount float,
		gal_dummy_total_amount float
	)
	
-- Get the container profile recipe assigned to this batch
INSERT #tmp_recipe (location, tracking_num, receipt_id, line_id, container_id)
SELECT distinct  @location,@tracking_num,
	ContainerDestination.receipt_id,
	ContainerDestination.line_id,
	ContainerDestination.container_id
FROM Receipt (NOLOCK)
INNER JOIN ContainerDestination (NOLOCK) ON Receipt.company_id = ContainerDestination.company_id
	AND Receipt.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Receipt.receipt_id = ContainerDestination.receipt_id
	--AND Receipt.line_id = ContainerDestination.line_id
WHERE 1=1
AND Receipt.trans_type = 'D'
AND Receipt.trans_mode = 'I'
AND Receipt.receipt_status IN ('N','L','U','A')
AND Receipt.fingerpr_status = 'A'
AND ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND ( ContainerDestination.tracking_num = @tracking_num  OR ContainerDestination.tracking_num IS Null )
AND ( ContainerDestination.cycle <=  @cycle  OR ContainerDestination.cycle IS Null )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
UNION
SELECT DISTINCT @location,@tracking_num,
    ContainerDestination.receipt_id,
	ContainerDestination.line_id,
	ContainerDestination.container_id
FROM  ContainerDestination
where  ContainerDestination.status = 'C'
AND ContainerDestination.location = @location
AND ( ContainerDestination.tracking_num = @tracking_num   OR ContainerDestination.tracking_num IS Null )
AND ( ContainerDestination.cycle <= @cycle  OR ContainerDestination.cycle IS Null )
AND ContainerDestination.profit_ctr_id = @profit_ctr_id
AND ContainerDestination.company_id = @company_id
AND ContainerDestination.container_type = 'S'

--IF @debug = 1 print 'SELECTING RESULTS'
--IF @debug = 1 SELECT DISTINCT @company_id, @profit_ctr_id, @location, @tracking_num, @receipt_id, @line_id, @container_id FROM #tmp_recipe

DECLARE Approval_Cursor CURSOR FOR
		SELECT location, tracking_num,  receipt_id, line_id, container_id 
		FROM #tmp_recipe
		
		OPEN Approval_Cursor
		FETCH NEXT FROM Approval_Cursor INTO @location, @tracking_num, @receipt_id, @line_id, @container_id
                       
		WHILE @@FETCH_STATUS = 0
		BEGIN
   
   IF @receipt_id = 0 
   BEGIN
     	INSERT INTO  #tmp_result 
    	SELECT Distinct 
			  par.recipe_id,
			  dbo.fn_container_stock(containers.line_id, containers.company_id, containers.profit_ctr_id) as source_container,
			    '' as approval_code,
			   null,
			   null,
			   null,
			   null,
			   null,
			   null,
			   null,
			   null
			FROM dbo.fn_container_source_receipt(@company_id, @profit_ctr_id, @receipt_id, @line_id , @container_id) containers
			JOIN Receipt r (nolock)
				ON r.company_id = @company_id
				AND r.profit_ctr_id = @profit_ctr_id
				AND r.receipt_id = containers.receipt_id
			INNER JOIN ProfileApprovalRecipe par (NOLOCK) ON @profit_ctr_id = par .profit_ctr_id
				AND r.company_id = par.company_id
				AND r.profile_id   = par.profile_id
				AND par.primary_flag = 'Y'
			INNER JOIN  RecipeDetail rd (NOLOCK) ON rd.profit_ctr_id = par .profit_ctr_id
				AND rd.company_id = par.company_id
				AND rd.recipe_id   = par.recipe_id 
				AND par.primary_flag = 'Y'

				 IF @@ROWCOUNT = 0
			   BEGIN 
				 SET @no_row = 99999
			   END	 
	END
   ELSE
    BEGIN
	  	INSERT INTO  #tmp_result 
		  	SELECT Distinct 
			  par.recipe_id,
			  CASE WHEN containers.container_type = 'R' THEN right('00' + convert(varchar(2), containers.company_id), 2) + '-' + right('00' + convert(varchar(2), containers.profit_ctr_id), 2) + '-' + CONVERT(varchar(15),containers.receipt_id) + '-' + CONVERT(varchar(5),containers.line_id) 
					 ELSE dbo.fn_container_stock(containers.line_id, containers.company_id, containers.profit_ctr_id)
				END as source_container,
			   r.approval_code,
			   '',
			   null,
			   null,
			   null,
			   null,
			   null,
			   null,
			   null
			FROM dbo.fn_container_source_receipt(@company_id, @profit_ctr_id, @receipt_id, @line_id , @container_id) containers
			JOIN Receipt r (nolock)
				ON r.company_id = @company_id
				AND r.profit_ctr_id = @profit_ctr_id
				AND r.receipt_id = @receipt_id
				--AND r.line_id = containers.line_id
			INNER JOIN ProfileApprovalRecipe par (NOLOCK) ON r.profit_ctr_id = par .profit_ctr_id
				AND r.company_id = par.company_id
				AND r.profile_id  = par.profile_id
				AND par.primary_flag = 'Y'
			INNER JOIN  RecipeDetail rd (NOLOCK) ON rd.profit_ctr_id = par .profit_ctr_id
				AND rd.company_id = par.company_id
				AND rd.recipe_id   = par.recipe_id 
				AND par.primary_flag = 'Y'
				AND rd.step_status <> 'V'
				-- no recipe
			  IF @@ROWCOUNT = 0
			   BEGIN 
				 SET @no_row = 99999
			   END	
	END
            SELECT  @reagent_uid = RecipeDetail.reagent_uid, @lab_reagent_percentage = RecipeDetail.lab_reagent_percentage,
                    @mix_order_sequence_id =  RecipeDetail.mix_order_sequence_id
            FROM RecipeDetail 
            JOIN #tmp_result ON RecipeDetail.recipe_id = #tmp_result.recipe_id 
            AND company_id = @company_id 
            AND profit_ctr_id = @profit_ctr_id 
            
             UPDATE #tmp_result 
             SET reagent_desc =  ( Select  reagent_desc from Reagent where reagent_uid = @reagent_uid )
              
             UPDATE #tmp_result
             SET lab_percentage = @lab_reagent_percentage              
                   
			FETCH NEXT FROM Approval_Cursor INTO @location, @tracking_num, @receipt_id, @line_id, @container_id
			
		END		-- WHILE @@FETCH_STATUS = 0

		CLOSE Approval_Cursor
		DEALLOCATE Approval_Cursor	

		 SELECT Distinct @ret = count (recipe_id) FROM #tmp_result

		 IF @ret >= 1 AND (@no_row = 99999 ) 
		    begin
		    SELECT Distinct 0,null,null,null,null,null,null,null,@message,null,null FROM #tmp_result
		    end
		 ELSE IF  @ret = 0
		 begin
		    SELECT Distinct 0,null,null,null,null,null,null,null,@message,null,null
		    end 
	     ELSE
	     BEGIn
		     SELECT Distinct RecipeDetail.recipe_id,null,null,Reagent.reagent_desc,lab_reagent_percentage,
		            RecipeDetail.mix_order_sequence_id,calc_amount,user_calc_amount,null,null,null
		     FROM RecipeDetail  
		     join #tmp_result on #tmp_result.recipe_id = RecipeDetail.recipe_id and RecipeDetail.company_id = @company_id 
		      and RecipeDetail.profit_ctr_id = @profit_ctr_id  
		     join Reagent on RecipeDetail.reagent_uid = Reagent.reagent_uid
		     where RecipeDetail.step_status <> 'V'
		     ORDER BY RecipeDetail.mix_order_sequence_id
		     END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_recipe] TO [EQAI]
    AS [dbo];
GO

