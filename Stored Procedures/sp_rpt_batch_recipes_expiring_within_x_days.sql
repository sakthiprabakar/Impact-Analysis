create PROCEDURE [dbo].[sp_rpt_batch_recipes_expiring_within_x_days] 
	@company_id			int
,	@profit_ctr_id		int
,   @expiration_start_date  datetime
,   @days               int

AS

Declare 
    @expiration_end_date    datetime

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_batch_rpt_recipes_expiring_within_x_days.sql
PB Object(s):	r_batch_recipes_expiring_within_x_days
	
10/30/2010 JAG	Created on Plt_AI
09/23/2019 MPM	DevOps 8855 - Additional recipe requirements - renamed some
				columns and removed batch_location column in RecipeHeader table.

r_batch_recipes_expiring_within_x_days 44, 0, '10/01/18', '10/31/18'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 
select @expiration_end_date = DATEADD (day , @days , @expiration_start_date )  

select 

    rh.company_id 
  ,	Company.company_name
  , rh.profit_ctr_id
  ,	ProfitCenter.profit_ctr_name
  
  , rh.recipe_id
  , rh.recipe_name
  , rh.effective_date 
  , rh.expiration_date
  , rh.recipe_confirmed_by
  , rh.recipe_confirmed_date
  , rh.recipe_confirmed
  
  , rdt.mix_order_sequence_id
  , ra.reagent_desc
  , rdt.proposed_reagent_percentage
  , rdt.lab_reagent_percentage
  
  , rh.recipe_description
  , rdt.step_description
  , rdt.comment
  
from RecipeHeader rh
JOIN RecipeDetail rdt on rh.recipe_id = rdt.recipe_id
JOIN Company
	ON Company.company_id = rh.company_id
JOIN ProfitCenter ON ProfitCenter.company_ID = rh.company_id
	AND ProfitCenter.profit_ctr_ID = rh.profit_ctr_id 
join Reagent ra on ra.reagent_uid = rdt.reagent_uid
where rh.expiration_date between @expiration_start_date and @expiration_end_date and
    rh.company_id = @company_id and
    rh.profit_ctr_id = @profit_ctr_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_recipes_expiring_within_x_days] TO [EQAI]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_recipes_expiring_within_x_days] TO PUBLIC
    AS [dbo];
GO

