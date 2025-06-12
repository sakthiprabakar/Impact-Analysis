-- drop proc sp_COR_waste_summary_detail_count
GO

create procedure sp_COR_waste_summary_detail_count (
	@web_userid			varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @date_specifier	varchar(20) = null	-- COR2 mockups indicate ONLY using Service dates.  So use NULL (defaults to 'service')
		-- Receipts don't use a specifier, so this field does not apply to Receipts
    , @customer_search	varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list

    , @approval_code	varchar(max) = null
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */ 
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)	
AS
/* *******************************************************************
sp_COR_waste_summary_detail_count

This is basically the same selection logic as sp_cor_schedule_Services_receipt*
but a different output.  Easier to adapt the output from the existing code
than rewrite sp_reports_waste_summary

COMBINATION OF sp_cor_schedule_service_list
AND				sp_cor_receipt_list

Samples:

exec sp_COR_waste_summary_detail_count
	@web_userid = 'dcrozier@riteaid.com'
	, @date_start = '11/1/2015'
	, @date_end = '12/31/2015'

exec sp_COR_waste_summary_detail_count
	@web_userid = 'nyswyn100'
	, @date_start = '11/1/2000'
	, @date_end = '12/31/2015'
	, @perpage = 20
	, @page = 4
	
exec sp_COR_waste_summary_detail_count
	@web_userid = 'nyswyn100'
	, @date_start = '1/1/2020'
	, @date_end = '1/11/2020'
	, @date_specifier	= 'transaction'	-- 'Requested', 'Scheduled', 'Service' (default = service)
    , @customer_search	= null
 --   -- , @manifest			= null
	--, @schedule_type	= null
	--, @service_type		= null -- 'Distribution Center'
    , @generator_name	= null
    , @epa_id			= null -- can take CSV list
    , @store_number		= null -- can take CSV list
	, @generator_district = null -- can take CSV list
    , @generator_region	= null -- can take CSV list
    , @approval_code = ''
	, @page				= 1
	, @perpage			= 20000
	, @customer_id_list =  ''
	, @generator_id_list = '' --''
	
-- SERVICE_TYPE testing:
-- No filter: 2390
-- Store: 12
-- Dist: 0
SELECT  *  FROM    workorderheader where customer_id = 15551 and generator_sublocation_id is not null and start_date <= '12/31/2015'
-- 12.  All store.  Seems legit.

SELECT  *  FROM    contact where web_userid = 'nyswyn100'
SELECT  *  FROM    contactxref WHERE contact_id = 185547
SELECT  *  FROM    generatorsublocation WHERE customer_id = 15551
-- Store: id = 28
-- Distribution Center: id = 37

-- SCHEDULE_TYPE testing:

SELECT  *  FROM    contact where web_userid = 'zachery.wright'
SELECT  *  FROM    contactxref WHERE contact_id = 184522
SELECT  *  FROM    generatorsublocation WHERE customer_id = 15622

SELECT  *  FROM    workorderheader where customer_id = 15622 and workorderscheduletype_uid is not null and start_date <= '12/31/2015'
-- none to test.

SELECT  *  FROM    workorderdetail WHERE workorder_id = 22445900 and company_id = 14 and profit_ctr_id = 0
	
******************************************************************* */

/*

DECLARE
	@web_userid			varchar(100)	= 'nyswyn100'
	, @date_start		datetime = '1/1/2018'
	, @date_end			datetime = '1/1/2020'
	, @date_specifier	varchar(10) = null	-- 'Requested', 'Scheduled', 'Service' (default = service)
		-- Receipts don't use a specifier, so this field does not apply to Receipts
	
    , @customer_search	varchar(max) = null
    /*
    , @manifest			varchar(max) = null
	*/
	, @schedule_type	varchar(max) = null	-- Ignored for Receipts
	, @service_type		varchar(max) = null	-- Ignored for Receipts

--    , @generator_search	varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
    
    , @approval_code	varchar(max) = null
    
    , @transaction_id	varchar(max) = null
    , @facility			varchar(max) = null
    --, @status			varchar(max) = null	-- Null/ALL, Requested, Scheduled, Completed, Invoiced (any combination)
		-- Ignored for Receipts
		-- Always 'invoiced' for WSR, implemented below.
    
	, @search			varchar(max) = null -- Common search
    , @adv_search		varchar(max) = null
--	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status'
	, @page				bigint = 1
	, @perpage			bigint = 20 

*/

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Avoid query plan caching:
declare
	@i_web_userid			varchar(100) = isnull(@web_userid, '')
	, @i_date_start			datetime = convert(date, isnull(@date_start, '1/1/1999'))
	, @i_date_end			datetime = convert(date, isnull(@date_end, '1/1/1999'))
	, @i_date_specifier		varchar(20) = isnull(@date_specifier, 'service')
    , @i_customer_search	varchar(max) = isnull(@customer_search, '')
    -- , @i_manifest			varchar(max) = replace(isnull(@manifest, ''), ' ', ',')
	, @i_schedule_type		varchar(max) = '' -- @schedule_type
	, @i_service_type		varchar(max) = '' -- @service_type
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
    , @i_approval_code		varchar(max) = isnull(@approval_code, '')
    , @i_transaction_id		varchar(max) = null -- isnull(@transaction_id, '')
    -- , @i_transaction_type	varchar(20) = @transaction_type 
    , @i_facility			varchar(max) = '' -- isnull(@facility, '')
    -- , @i_status				varchar(max) = isnull(@status, '')
	, @i_search				varchar(max) = '' -- dbo.fn_CleanPunctuation(isnull(@search, ''))
    , @i_adv_search			varchar(max) = '' -- @adv_search
	-- , @i_sort				varchar(20) = isnull(@sort, '')
	, @i_page				bigint = isnull(@page, 1)
	, @i_perpage			bigint = isnull(@perpage, 20)
	, @i_debug			int = 0
	, @i_starttime		datetime = getdate()
	, @i_contact_id		int = 0
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')


	CREATE TABLE #detail (
		[facility] [varchar](100) NULL,
		[facility_epa_id] [varchar](12) NULL,
		[customer_name] [varchar](85) NULL,
		[customer_id] [int] NULL,
		[generator_name] [varchar](80) NULL,
		[epa_id] [varchar](12) NULL,
		[generator_state] [varchar](2) NULL,
		[generator_city] [varchar](40) NULL,
		[generator_site_code] [varchar](16) NULL,
		[transporter_name] [varchar](60) NULL,
		[transporter_epa_id] [varchar](20) NULL,
		TSDF_Code varchar(15) NULL,
		TSDF_Name varchar(40) NULL,
		TSDF_Address varchar(max) NULL,
		TSDF_City varchar(40) NULL,
		TSDF_State char(2) NULL,
		TSDF_Zip_Code varchar(15) NULL,
		TSDF_Country_Code varchar(3)  NULL,
		[approval] [varchar](40) NULL,
		[waste_description] [varchar](150) NULL,
		[hazardous?] varchar(20) NULL,
		[waste_code_list] [varchar](max) NULL,
		[management_code] [varchar](4) NULL,
		[epa_form_code] [varchar](20) NULL,
		[epa_source_code] [varchar](10) NULL,
		[transaction_id] [varchar](20) NULL,
		[transaction_date] [datetime] NULL,
		[service_date] [datetime] NULL,
		[manifest] [varchar](20) NULL,
		[manifest_page] [int] NULL,
		[manifest_line] [int] NULL,
		[manifest quantity] [float] NULL,
		[manifest unit] [varchar](4) NULL,
		[Manifest Container Count] [float] NULL,
		[Manifest Container Code] [varchar](15) NULL,
		[line_quantity] [varchar](max) NULL,
		[weight_method] [varchar](40) NULL,
		[total_pounds] [float] NULL,
		[_row] [int] NOT NULL,
		[_profile_id] [int] NULL,
		[DOT_Shipping_Desc] varchar(max) NULL,
		[Generator_Address] varchar(max) NULL,
		[Generator_Zip_Code] varchar(15) NULL,
		[Generator_County] varchar(40) NULL,
		[State_Waste_Code_List] varchar(max) NULL,
		billed int null
		)

-- populate detail
insert #detail
exec sp_COR_waste_summary_detail_list
	@web_userid			= @i_web_userid
	, @date_start		= @i_date_start
	, @date_end			= @i_date_end
	, @date_specifier	= @i_date_specifier
    , @customer_search	= @i_customer_search
    , @generator_name	= @i_generator_name
    , @epa_id			= @i_epa_id
    , @store_number		= @i_store_number
    , @site_type		= @i_site_type
	, @generator_district = @i_generator_district
    , @generator_region	= @i_generator_region
    , @approval_code	= @i_approval_code
	, @page				= 1
	, @perpage			= 9999999
	, @customer_id_list = @i_customer_id_list
	, @generator_id_list = @i_generator_id_list



---------------------------------------------------------------
----------------------- RETURN RESULTS ------------------------
---------------------------------------------------------------

returnresults:

SET NOCOUNT OFF


BEGIN -- Summary, Group by Approval

	select count(*) from #detail

END


if @i_debug >= 1 print 'End Elapsed time: ' + convert(varchar(20), datediff(ms, @i_starttime, getdate())) + 'ms'


RETURN 0

GO

GRANT EXECUTE ON sp_COR_waste_summary_detail_count to eqweb, eqai, cor_user
GO


