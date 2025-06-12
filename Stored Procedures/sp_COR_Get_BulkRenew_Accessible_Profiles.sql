USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_COR_Get_BulkRenew_Accessible_Profiles]    Script Date: 26-11-2021 15:26:13 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>


-- =============================================
CREATE PROCEDURE [dbo].[sp_COR_Get_BulkRenew_Accessible_Profiles]
	-- Add the parameters for the stored procedure here
	@web_userid varchar(200),
	@profile_id nvarchar(max) = '',
	@customer_id_list varchar(max) = '',
	@generator_id_list varchar(max) = '',
	@waste_common_name nvarchar(500) = '',
	@approval_code	varchar(max) = '',	-- Can take a CSV list
	@search nvarchar(500) = '',
	@page int = 1,
	@perpage int = 10
AS

/*

	exec [sp_COR_Get_BulkRenew_Accessible_Profiles]
	'manand84'

*/

BEGIN
	
	SET NOCOUNT ON;

		

	declare @profile_id_csv_list nvarchar(max) 
	
    -- Insert statements for procedure here
	SELECT @profile_id_csv_list = COALESCE(@profile_id_csv_list + ', ', '') +  profile_id   FROM BulkRenewProfile b
	WHERE status ='validated' and (isnull(@profile_id, '')='' or b.profile_id = @profile_id)	
	and
	1 = 
	case when 
	 (SELECT count(*) FROM ProfileSectionStatus p WHERE  p.profile_id = b.profile_id and section_status = 'Y') =
	 (SELECT count(*) FROM ProfileSectionStatus p WHERE  p.profile_id = b.profile_id ) 
	 then 1 else 0 end	 

	 if(isnull(@profile_id_csv_list, '') <> '')
	 begin
			 exec 
			 [dbo].[sp_COR_Profile_List]
				@web_userid			= @web_userid,
				@status_list		=  'expired', 
				@search				= '',
				@adv_search			= '',
				@generator_size		= '',
				@generator_name		= '',
				@generator_site_type = '',
				@profile_id			 = @profile_id_csv_list,	-- Can take a CSV list
				@approval_code		= @approval_code,	-- Can take a CSV list
				@waste_common_name	= @waste_common_name,
				@epa_waste_code		= '',	-- Can take a CSV list
				@facility_search	= '',  -- Seaches/limits any part of facility name, city, state
				@facility_id_list	= '',  -- Seaches/limits by company_id|profit_ctr_id csv input
				@copy_status		= '',
				@sort				= '',
				@page				= @page,
				@perpage			= @perpage,
				@excel_output		= 0, -- or 1
				@customer_id_list	= @customer_id_list,  /* Added 2019-07-19 by AA */
				@generator_id_list	= @generator_id_list,  /* Added 2019-07-19 by AA */
				@owner				= 'all', /* 'mine' or 'all' */
				@period				= '', /* WW, MM, QQ, YY, 30 or 60 days */
				@tsdf_type			= 'All',  /* 'USE' or 'Non-USE' or 'ALL' */
				@haz_filter			= 'All',  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */
				@under_review		= 'N' /* 'N'ot under review, 'U'nder review, 'A'ny  */
		end
END

GO
	GRANT EXEC ON [dbo].[sp_COR_Get_BulkRenew_Accessible_Profiles] TO COR_USER;
GO

