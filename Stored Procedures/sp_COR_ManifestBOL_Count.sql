USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_COR_ManifestBOL_Count] 
GO 

CREATE PROCEDURE [dbo].[sp_COR_ManifestBOL_Count] (
	@web_userid		varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
    , @customer_search	varchar(max) = null
	, @document_type	varchar(20) = null -- Manifest, BOL, All default = manifest
    , @manifest			varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
	, @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
    , @approval_code	varchar(max) = null
	, @sort				varchar(20) = ''
	, @page				bigint = 1
	, @perpage			bigint = 20 
    , @excel_output		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @export_images	bit = 0 /* Export Images option */
	, @image_id_list	varchar(max) = '' -- list of image_ids to export
    , @export_email	varchar(100) = ''
) 
AS
BEGIN
/* **************************************************************
sp_COR_ManifestBOL_Count

	Return search results for manifest/bol searches
	
10/14/2019 MPM  DevOps 11575: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.

 sp_COR_ManifestBOL_Count 
	@web_userid		= 'iceman'
	, @date_start		 = '1/1/2018'
	, @date_end			 = '02/28/2021'
    , @customer_search	= null
	, @document_type	= '' -- Manifest, BOL, All default = manifest
    , @manifest			 = null
    , @generator_name	 = null
    , @epa_id			 = null -- can take CSV list
    , @store_number		 = null -- can take CSV list
	, @site_type		 = null -- can take CSV list
	, @generator_district  = null -- can take CSV list
    , @generator_region	 = null -- can take CSV list
    , @approval_code	 = null
	, @sort				 = ''
	, @page				= 1
	, @perpage			= 2000 
    , @excel_output		= 0

 sp_COR_ManifestBOL_Count 
	@web_userid		= 'amber'
	, @date_start		 = '1/1/2018'
	, @date_end			 = '12/31/2018'
    , @customer_search	= null
	, @document_type	= '' -- Manifest, BOL, All default = manifest
    , @manifest			 = null
    , @generator_name	 = null
    , @epa_id			 = null -- can take CSV list
    , @store_number		 = null -- can take CSV list
	, @site_type		 = null -- can take CSV list
	, @generator_district  = null -- can take CSV list
    , @generator_region	 = null -- can take CSV list
    , @approval_code	 = null
	, @sort				 = ''
	, @page				= 1
	, @perpage			= 2000 
    , @excel_output		= 0
	, @customer_id_list ='15622'  
    , @generator_id_list ='155581, 155586'  

************************************************************** */
/*
-- DEBUG:
declare 	@web_userid		varchar(100) = 'zachery.wright'
	, @date_start		datetime = null
	, @date_end			datetime = null
    , @customer_search	varchar(max) = null
	, @document_type	varchar(20) = null -- Manifest, BOL, All default = manifest
    , @manifest			varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
	, @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
    , @approval_code	varchar(max) = null
	, @sort				varchar(20) = ''
	, @page				bigint = 1
	, @perpage			bigint = 20 
    , @excel_output		int = 0
*/

declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= @date_start			
	, @i_date_end				datetime		= @date_end				
    , @i_customer_search		varchar(max)	= isnull(@customer_search, '')
	, @i_document_type			varchar(20)		= isnull(@document_type, 'manifest')		
    , @i_manifest				varchar(max)	= isnull(@manifest, '')
    , @i_generator_name			varchar(max)	= isnull(@generator_name, '')
    , @i_epa_id					varchar(max)	= isnull(@epa_id, '')
    , @i_store_number			varchar(max)	= isnull(@store_number, '')
	, @i_site_type				varchar(max)	= isnull(@site_type, '')
	, @i_generator_district		varchar(max)	= isnull(@generator_district, '')
    , @i_generator_region		varchar(max)	= isnull(@generator_region, '')
    , @i_approval_code			varchar(max)	= isnull(@approval_code, '')
	, @i_sort					varchar(20)		= isnull(@sort, '')
	, @i_page					bigint			= isnull(@page,1)
	, @i_perpage				bigint			= isnull(@perpage,20)
    , @i_excel_output			int				= isnull(@excel_output,0)
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

	declare @out table (
	trans_source	char(1)
	, receipt_id	int
	, company_id	int
	, profit_ctr_id	int
	, service_date	datetime
	, cutsomer_id	int
	, generator_id	int
	, type_id		int
	, document_type	varchar(30)
	, upload_date datetime
	, description	varchar(255)
	, image_id_file_type_page_number_list	varchar(max)
	, cust_name		varchar(80)
	, generator_name	varchar(80)
	, epa_id		varchar(20)
	, generator_city	varchar(40)
	, generator_state	varchar(2)
	, generator_country	varchar(3)
	, site_code		varchar(16)
	, site_type		varchar(40)
	, generator_region_code	varchar(40)
	, generator_division	varchar(40)
	, name			varchar(55)
	, _row int
)  

insert @out
exec sp_COR_ManifestBOL_List 
	@web_userid			= @i_web_userid
	, @date_start		= @i_date_start
	, @date_end			= @i_date_end
	, @customer_search	= @i_customer_search
	, @document_type	= @i_document_type
	, @manifest			= @i_manifest
	, @generator_name	= @i_generator_name
	, @epa_id			= @i_epa_id
	, @store_number		= @i_store_number
	, @site_type		= @i_site_type
	, @generator_district = @i_generator_district
	, @generator_region	= @i_generator_region
	, @approval_code	= @i_approval_code
	, @sort				= @i_sort
	, @page				= 1
	, @perpage			= 99999999
	, @excel_output		= 0
	, @customer_id_list = @i_customer_id_list
    , @generator_id_list = @i_generator_id_list


	select count(*) from @out

return 0
END

GO

GRANT EXEC ON sp_COR_ManifestBOL_Count TO EQAI;
GO
GRANT EXEC ON sp_COR_ManifestBOL_Count TO EQWEB;
GO
GRANT EXEC ON sp_COR_ManifestBOL_Count TO COR_USER;
GO
