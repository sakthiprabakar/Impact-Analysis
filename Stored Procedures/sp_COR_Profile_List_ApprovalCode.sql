CREATE  PROCEDURE [dbo].[sp_COR_Profile_List_ApprovalCode]
    @web_userid			varchar(100),
    @status_list		varchar(max) = 'all',
    @search				varchar(100) = '',
    @adv_search			varchar(max) = '',
	@generator_size		varchar(75) = '',
	@generator_name		varchar(75) = '',
	@generator_site_type	varchar(max) = '',
	@profile_id			varchar(max) = '',	-- Can take a CSV list
	@approval_code		varchar(max) = '',	-- Can take a CSV list
	@waste_common_name	varchar(50) = '',
	@epa_waste_code		varchar(max) = '',	-- Can take a CSV list
	@facility_search	varchar(max) = '',  -- Seaches/limits any part of facility name, city, state
	@facility_id_list	varchar(max) = '',  -- Seaches/limits by company_id|profit_ctr_id csv input
    @copy_status		varchar(10) = '',
    @sort				varchar(20) = 'Modified Date',
    @page				int = 1,
    @perpage			int = 20,
    @excel_output		int = 0, -- or 1
	@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
	@owner			varchar(5) = 'all', /* 'mine' or 'all' */
	@period			varchar(4) = '', /* WW, MM, QQ, YY, 30 or 60 days */
	@tsdf_type			varchar(10) = 'All',  /* 'USE' or 'Non-USE' or 'ALL' */
	@haz_filter			varchar(20) = 'All',  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */
	@under_review		char(1) = 'N' /* 'N'ot under review, 'U'nder review, 'A'ny  */
	
AS
/***********************************************************************************

	Author		: Prabhu
	Create date	: 30-Oct-2019
	Description	: Procedure to split the approval code column list and call on another sp [dbo].[sp_COR_Profile_List]
	
 
   EXEC [dbo].[sp_COR_Profile_List_ApprovalCode]
    @web_userid			= 'nyswyn100',
    @status_list		 = 'all',
    @search				= '',
    @adv_search			= '',
	@generator_size		 = '',
	@generator_name		= '',
	@generator_site_type	 = '',
	@profile_id			= '',	-- Can take a CSV list
	@approval_code		 = '',	-- Can take a CSV list
	@waste_common_name	 = '',
	@epa_waste_code		 = '',	-- Can take a CSV list
	@facility_search	 = '',  -- Seaches/limits any part of facility name, city, state
	@facility_id_list	 = '',  -- Seaches/limits by company_id|profit_ctr_id csv input
    @copy_status		 = '',
    @sort				 = 'Modified Date',
    @page				 = 1,
    @perpage			 = 20,
    @excel_output		 = 0, -- or 1
	@customer_id_list ='',  /* Added 2019-07-19 by AA */
    @generator_id_list ='',  /* Added 2019-07-19 by AA */
	@owner			 = 'all', /* 'mine' or 'all' */
	@period			 = '',
	@tsdf_type       ='USE',
	@haz_filter      ='All',
	@under_review='N'

	
			
5/24/2021
	DO-20902 - add profile.inactive_flag to output

*************************************************************************************/


--SELECT * INTO #tmp FROM myTable
BEGIN
CREATE TABLE #tempTable(
	profile_id int
	, approval_code_list varchar(max)
	, pro_name varchar(50)
	, generator_id int
	, gen_by varchar(75)
	, Generator_EPA_ID varchar(12)
	, site_type varchar(40)
	, RCRA_status varchar(20)
	, updated_date datetime
	, customer_id int
	, updated_by varchar(75)
	, expired_date datetime
	, profile varchar(100)
	, status varchar(40)
	, reapproval_allowed char(1)
	, inactive_flag char(1)
	, waste_code_list varchar(max)
	, document_update_status char(1)
	, tsdf_type varchar(10)
	, totalcount int
)

  INSERT INTO #tempTable
  EXEC [sp_COR_Profile_List] 
-- [sp_COR_Profile_Count] 
    @web_userid,
    @status_list,		
    @search	,			
    @adv_search	,		
	@generator_size,		
	@generator_name	,	
	@generator_site_type,	
	@profile_id	,
	@approval_code	,
	@waste_common_name,
	@epa_waste_code	,
	@facility_search,
	@facility_id_list,
    @copy_status,
    @sort,
	@page,
    @perpage,
    @excel_output,
	@customer_id_list,
    @generator_id_list,
	@owner,
	@period,
	@tsdf_type,
	@haz_filter,
	@under_review
  --SELECT * FROM #tempTable

 

 IF (@tsdf_type!='non-use')	
begin
select 
		     isnull(pqa.approval_code, '') as approvalcodelist ,
			 case when t.tsdf_type = 'use'
			 then
				isnull(use_pc.name, '')	
			 else 
				isnull((select tsdf_name from tsdf (nolock) where ta.tsdf_code = tsdf.tsdf_code), '')
			 end facility,
			 t.*
			 FROM #tempTable t 
			 left join profilequoteapproval pqa (nolock)
			 on t.profile_id=pqa.profile_id
			 join USE_ProfitCenter use_pc (nolock)
			 on pqa.company_id = use_pc.company_id
			 and pqa.profit_ctr_id = use_pc.profit_ctr_id
			 
			 left join tsdfapproval ta  (nolock)
				on ta.tsdf_approval_id=t.profile_id
			 	
			where (t.tsdf_type='use' and pqa.profile_id = t.profile_id
			and pqa.status = 'A') or t.tsdf_type  <> 'use'	 
			 --where 
			 --pqa.status = 'A' 
			 --and t.profile_id
			  --in (select profile_id from #tempTable)
			  --where t.tsdf_type<>'non-use'
			  order by t.profile_id desc
			  end


			  
IF (@tsdf_type='non-use')	
begin
	
select
         isnull(ta.tsdf_approval_code, '') as approvalcodelist ,
		 isnull((select tsdf_name from tsdf (nolock) where ta.tsdf_code = tsdf.tsdf_code), '') as facility,ts.*
		 from #tempTable ts
		join tsdfapproval ta  (nolock)
		on ta.tsdf_approval_id=ts.profile_id
		--join tsdf (nolock)
		--	on ta.tsdf_code = tsdf.tsdf_code
		--	and tsdf.tsdf_status = 'A'
		--	and isnull(tsdf.eq_flag, 'F') ='F'
		--WHERE ta.tsdf_approval_id = @profile_id
	end
END

GO

GRANT EXECUTE ON [dbo].[sp_COR_Profile_List_ApprovalCode] TO COR_USER;

GO