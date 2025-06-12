Create PROCEDURE [dbo].[sp_rpt_profiles_linked_to_treatment_recipe] 
	@company_id			int
,	@profit_ctr_id		int
,   @exp_date_from      datetime
,   @exp_date_to        datetime
,   @recipe_id          int

AS

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_rpt_profiles_linked_to_treatment_recipe.sql
PB Object(s):	r_profiles_linked_to_treatment_recipe 
	
10/30/2018 JAG	Created on Plt_AI

r_profiles_linked_to_treatment_recipe 44, 0, '10/01/18', '10/31/18'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

select 
    pqa.company_id 
  ,	Company.company_name
  , pqa.profit_ctr_id
  ,	ProfitCenter.profit_ctr_name

  , rh.recipe_id
  , rh.recipe_name
  , rh.effective_date 
  , rh.expiration_date
  
  , par.profile_id
  , pqa.approval_code
  , pr.ap_start_date profile_start_dte
  , pr.ap_expiration_date profile_expiration_dte
  
from 
ProfileQuoteApproval pqa
join ProfileApprovalRecipe par on pqa.profile_id = par.profile_id 
      and par.company_id = pqa.company_id 
      and par.company_id = @company_id
      and par.profit_ctr_id = pqa.profit_ctr_id 
      and par.profit_ctr_id = @profit_ctr_id 
      and par.primary_flag = 'Y'
join RecipeHeader rh on rh.recipe_id = par.recipe_id 
      and par.company_id = rh.company_id 
      and par.company_id = @company_id 
      and par.profit_ctr_id = rh.profit_ctr_id 
      and par.profit_ctr_id = @profit_ctr_id 
JOIN Company
	ON Company.company_id = pqa.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = pqa.company_id
	AND ProfitCenter.profit_ctr_ID = pqa.profit_ctr_id 
join profile pr on pr.profile_id = par.profile_id
--where pr.ap_expiration_date between @exp_date_from and @exp_date_to
where  rh.expiration_date between @exp_date_from and @exp_date_to and
   rh.recipe_id =   
    case 
       when (@recipe_id is null) or (@recipe_id = 0) then
           rh.recipe_id
    else
         @recipe_id
    end
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_profiles_linked_to_treatment_recipe] TO [EQAI]
    AS [dbo];
GO

