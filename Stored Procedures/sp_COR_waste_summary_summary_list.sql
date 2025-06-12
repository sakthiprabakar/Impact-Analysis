USE plt_ai
GO

--
DROP PROCEDURE IF EXISTS sp_COR_waste_summary_summary_list 
GO

	CREATE PROCEDURE sp_COR_waste_summary_summary_list (
		@web_userid VARCHAR(100)
		,@date_start DATETIME = NULL
		,@date_end DATETIME = NULL
		,@date_specifier VARCHAR(20) = NULL -- COR2 mockups indicate ONLY using Service dates.  So use NULL (defaults to 'service')
		-- Receipts don't use a specifier, so this field does not apply to Receipts
		,@customer_search VARCHAR(max) = NULL
		,@generator_name VARCHAR(max) = NULL
		,@epa_id VARCHAR(max) = NULL -- can take CSV list
		,@store_number VARCHAR(max) = NULL -- can take CSV list
		,@site_type VARCHAR(max) = NULL -- can take CSV list
		,@generator_district VARCHAR(max) = NULL -- can take CSV list
		,@generator_region VARCHAR(max) = NULL -- can take CSV list
		,@approval_code VARCHAR(max) = NULL
		,@page BIGINT = 1
		,@perpage BIGINT = 20
		,@customer_id_list VARCHAR(max) = '' /* Added 2019-07-17 by AA */
		,@generator_id_list VARCHAR(max) = '' /* Added 2019-07-17 by AA */
		)
	AS
	/* *******************************************************************
sp_COR_waste_summary_summary_list

This is basically the same selection logic as sp_cor_schedule_Services_receipt*
but a different output.  Easier to adapt the output from the existing code
than rewrite sp_reports_waste_summary

COMBINATION OF sp_cor_schedule_service_list
AND				sp_cor_receipt_list

Samples:

exec sp_COR_waste_summary_summary_list
	@web_userid = 'dcrozier@riteaid.com'
	, @date_start = '11/1/2015'
	, @date_end = '12/31/2015'

exec sp_COR_waste_summary_summary_list
	@web_userid = 'nyswyn100'
	, @date_start = '11/1/2000'
	, @date_end = '12/31/2022'
	, @perpage = 20
	, @page = 4
	
exec sp_COR_waste_summary_summary_list
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
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

	-- Avoid query plan caching:
	DECLARE @i_web_userid VARCHAR(100) = isnull(@web_userid, '')
		,@i_date_start DATETIME = convert(DATE, isnull(@date_start, '1/1/1999'))
		,@i_date_end DATETIME = convert(DATE, isnull(@date_end, '1/1/1999'))
		,@i_date_specifier VARCHAR(20) = isnull(@date_specifier, 'service')
		,@i_customer_search VARCHAR(max) = isnull(@customer_search, '')
		-- , @i_manifest			varchar(max) = replace(isnull(@manifest, ''), ' ', ',')
		,@i_schedule_type VARCHAR(max) = '' -- @schedule_type
		,@i_service_type VARCHAR(max) = '' -- @service_type
		,@i_generator_name VARCHAR(max) = isnull(@generator_name, '')
		,@i_epa_id VARCHAR(max) = isnull(@epa_id, '')
		,@i_store_number VARCHAR(max) = isnull(@store_number, '')
		,@i_site_type VARCHAR(max) = isnull(@site_type, '')
		,@i_generator_district VARCHAR(max) = isnull(@generator_district, '')
		,@i_generator_region VARCHAR(max) = isnull(@generator_region, '')
		,@i_approval_code VARCHAR(max) = isnull(@approval_code, '')
		,@i_transaction_id VARCHAR(max) = '' -- isnull(@transaction_id, '')
		-- , @i_transaction_type	varchar(20) = @transaction_type 
		,@i_facility VARCHAR(max) = '' -- isnull(@facility, '')
		-- , @i_status				varchar(max) = isnull(@status, '')
		,@i_search VARCHAR(max) = '' -- dbo.fn_CleanPunctuation(isnull(@search, ''))
		,@i_adv_search VARCHAR(max) = '' -- @adv_search
		-- , @i_sort				varchar(20) = isnull(@sort, '')
		,@i_page BIGINT = isnull(@page, 1)
		,@i_perpage BIGINT = isnull(@perpage, 20)
		,@i_debug INT = 0
		,@i_starttime DATETIME = getdate()
		,@i_contact_id INT = 0
		,@i_customer_id_list VARCHAR(max) = isnull(@customer_id_list, '')
		,@i_generator_id_list VARCHAR(max) = isnull(@generator_id_list, '')

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
	INSERT INTO #detail
	EXEC sp_COR_waste_summary_detail_list @web_userid = @i_web_userid
		,@date_start = @i_date_start
		,@date_end = @i_date_end
		,@date_specifier = @i_date_specifier
		,@customer_search = @i_customer_search
		,@generator_name = @i_generator_name
		,@epa_id = @i_epa_id
		,@store_number = @i_store_number
		,@site_type = @i_site_type
		,@generator_district = @i_generator_district
		,@generator_region = @i_generator_region
		,@approval_code = @i_approval_code
		,@page = 1
		,@perpage = 9999999
		,@customer_id_list = @i_customer_id_list
		,@generator_id_list = @i_generator_id_list

	---------------------------------------------------------------
	----------------------- RETURN RESULTS ------------------------
	---------------------------------------------------------------
	returnresults:

	SET NOCOUNT OFF

	BEGIN
		BEGIN -- Summary, Group by Approval
			SELECT * FROM (
				SELECT 
				Facility
					,Facility_EPA_ID
					,Customer_Name
					,Customer_ID
					,Generator_Name
					,EPA_ID
					,Generator_State
					,Generator_City
					,Generator_Site_Code
					,Approval
					,Waste_Description
					,[Hazardous?]
					,Waste_Code_List
					,Management_Code
					,EPA_Form_Code
					,EPA_Source_Code
					,
					-- Line_Quantity,
					Weight_Method
					,Total_Pounds
					,_row = row_number() OVER (
						ORDER BY facility
							,customer_name
							,generator_name
							,epa_id
							,approval --,
							-- line_quantity
						)
					,_profile_id
					,DOT_Shipping_Desc
					,Generator_Address
					,Generator_Zip_Code
					,Generator_County
					,State_Waste_Code_List
				FROM (
					SELECT facility
						,customer_id
						,customer_name
						,epa_id
						,generator_name
						,generator_state
						,generator_city
						,generator_site_code
						,approval
						,_profile_id
						,waste_code_list
						,waste_description
						,[hazardous?]
						,
						-- line_quantity,
						management_code
						,epa_form_code
						,epa_source_code
						,SUM(isnull(total_pounds, 0)) AS total_pounds
						,weight_method
						,facility_epa_id
						,DOT_Shipping_Desc
						,Generator_Address
						,Generator_Zip_Code
						,Generator_County
						,State_Waste_Code_List
					FROM #detail
					GROUP BY facility
						,customer_id
						,customer_name
						,epa_id
						,generator_name
						,generator_state
						,generator_city
						,generator_site_code
						,approval
						,_profile_id
						,waste_code_list
						,waste_description
						,[hazardous?]
						,
						-- line_quantity,
						management_code
						,epa_form_code
						,epa_source_code
						,weight_method
						,facility_epa_id
						,DOT_Shipping_Desc
						,Generator_Address
						,Generator_Zip_Code
						,Generator_County
						,State_Waste_Code_List
					) x
				) y
			WHERE _row BETWEEN ((@i_page - 1) * @i_perpage) + 1
					AND (@i_page * @i_perpage)
			ORDER BY _row

			DROP TABLE #detail
		END
	END

	IF @i_debug >= 1
		PRINT 'End Elapsed time: ' + convert(VARCHAR(20), datediff(ms, @i_starttime, getdate())) + 'ms'

	RETURN 0
GO

GRANT EXECUTE ON sp_COR_waste_summary_summary_list TO eqweb,eqai,cor_user
GO


