Create PROCEDURE [dbo].sp_rpt_batches_linked_to_treatment_recipe
	@company_id			int
,	@profit_ctr_id		int
,	@batch_from_dt      date
,   @batch_to_date      date
,	@recipe_id          int

AS

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_rpt_batches_linked_to_treatment_recipe.sql
PB Object(s):	r_batch_linked_to_treatment_recipe
	
10/30/2018 JAG	Created on Plt_AI

r_batch_linked_to_treatment_recipe 44, 0, '10/01/18', '10/31/18'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

select distinct

 b.company_id ,
 company.company_name,
 b.profit_ctr_id,
 ProfitCenter.profit_ctr_name,

 b.batch_id, 
 b.location,
 b.tracking_num, 
 b.date_opened,
 b.date_closed,
 b.status,

 rh.recipe_id,
 rh.recipe_name,
 rh.effective_date, 
 rh.expiration_date,

 par.profile_id,
 pqa.approval_code,
 pr.ap_start_date,
 pr.ap_expiration_date

from batch b
join BatchEvent ba on b.company_id = ba.company_id and b.profit_ctr_id = ba.profit_ctr_id 
    and b.location = ba.location and b.tracking_num = ba.tracking_num 
join ProfileApprovalRecipe par on ba.recipe_id = par.recipe_id  
      and par.company_id = b.company_id 
      and par.profit_ctr_id = b.profit_ctr_id 
      and par.profit_ctr_id = @profit_ctr_id 
      and par.primary_flag = 'Y'
join RecipeHeader rh on rh.recipe_id = par.recipe_id 
      and par.company_id = rh.company_id 
      and par.profit_ctr_id = rh.profit_ctr_id
join ProfileQuoteApproval pqa on pqa.profile_id = par.profile_id 
      and pqa.company_id = par.company_id
      and pqa.company_id = @company_id
      and pqa.profit_ctr_id = par.profit_ctr_id 
      and pqa.profit_ctr_id = @profit_ctr_id 
JOIN Company
	ON Company.company_id = pqa.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = pqa.company_id
	AND ProfitCenter.profit_ctr_ID = pqa.profit_ctr_id 
join profile pr on pr.profile_id = par.profile_id
where b.date_opened between @batch_from_dt AND @batch_to_date and
      rh.recipe_id = 
         case
            when @recipe_id = 0 then
               rh.recipe_id
         else
               @recipe_id
         end
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batches_linked_to_treatment_recipe] TO [EQAI]
    AS [dbo];
GO

