
CREATE PROCEDURE sp_rpt_generic_disposal_export (
	@customer_id_list		varchar(max),
    @start_date             datetime,
    @end_date               datetime,
	@generator_id_list varchar(max)  /* Added 2019-07-17 by AA */
)
AS
/* ***********************************************************
Procedure    : sp_rpt_generic_disposal_build
Database     : PLT_AI
Created      : Aug 13 2014 - Jonathan Broome
Description  : Stolen from Wal-Mart, modified for anyone.

SELECT * FROM customer where cust_name like 'harbor%'
 
Examples:
    sp_rpt_generic_disposal_export '12113', '7/1/2013 00:00', '7/31/2013 23:59'

Output Routines:
    declare @extract_id int = 837 -- (returned above)
			-- Disposal Validation output
			sp_rpt_extract_walmart_disposal_output_validation1_jpb 850
			


Notes:
    IMPORTANT: This script is only valid from 2007/03 and later.
        2007-01 and 2007-02 need to exclude company-14, profit-ctr-4 data.
        2007-01 needs to INCLUDE 14/4 data from the state of TN.


History:
    8/14/2014 - JPB - Created from sp_rpt_extract_walmart_disposal


*********************************************************** */
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


--- declare @customer_id_list		varchar(max) = '12113', @start_date             datetime = '5/1/2013 00:00', @end_date               datetime = '05/31/2013 23:59'
    

	CREATE TABLE #DisposalExtract(
		[site_code] [varchar](16) NULL,
		[site_type_abbr] [varchar](10) NULL,
		[generator_city] [varchar](40) NULL,
		[generator_state] [varchar](2) NULL,
		[service_date] [datetime] NULL,
		[epa_id] [varchar](12) NULL,
		[manifest] [varchar](15) NULL,
		[manifest_line] [int] NULL,
		[pounds] [float] NULL,							-- regular weight calculation
		[calculated_pounds] [float] NULL,				-- residue_pounds_factor weight calculation
		[empty_bottle_count] [int] NULL,
		[bill_unit_desc] [varchar](40) NULL,
		[quantity] [float] NULL,
		[waste_desc] [varchar](50) NULL,
		[approval_or_resource] [varchar](60) NULL,
		[dot_description] [varchar](255) NULL,
		[waste_code_1] [varchar](10) NULL,
		[waste_code_2] [varchar](10) NULL,
		[waste_code_3] [varchar](10) NULL,
		[waste_code_4] [varchar](10) NULL,
		[waste_code_5] [varchar](10) NULL,
		[waste_code_6] [varchar](10) NULL,
		[waste_code_7] [varchar](10) NULL,
		[waste_code_8] [varchar](10) NULL,
		[waste_code_9] [varchar](10) NULL,
		[waste_code_10] [varchar](10) NULL,
		[waste_code_11] [varchar](10) NULL,
		[waste_code_12] [varchar](10) NULL,
		[state_waste_code_1] [varchar](10) NULL,
		[state_waste_code_2] [varchar](10) NULL,
		[state_waste_code_3] [varchar](10) NULL,
		[state_waste_code_4] [varchar](10) NULL,
		[state_waste_code_5] [varchar](10) NULL,
		[management_code] [varchar](4) NULL,
		[EPA_source_code] [varchar](10) NULL,
		[EPA_form_code] [varchar](10) NULL,
		[transporter1_name] [varchar](40) NULL,
		[transporter1_epa_id] [varchar](15) NULL,
		[transporter2_name] [varchar](40) NULL,
		[transporter2_epa_id] [varchar](15) NULL,
		[receiving_facility] [varchar](50) NULL,
		[receiving_facility_epa_id] [varchar](50) NULL,
		[receipt_id] [int] NULL,
		[disposal_service_desc] [varchar](20) NULL,
		[company_id] [smallint] NULL,
		[profit_ctr_id] [smallint] NULL,
		[line_sequence_id] [int] NULL,
		[generator_id] [int] NULL,
		[generator_name] [varchar](40) NULL,
		[site_type] [varchar](40) NULL,
		[manifest_page] [int] NULL,
		[item_type] [varchar](9) NULL,
		[tsdf_approval_id] [int] NULL,
		[profile_id] [int] NULL,
		[container_count] [float] NULL,
		[waste_codes] [varchar](2000) NULL,
		[state_waste_codes] [varchar](2000) NULL,
		[transporter1_code] [varchar](15) NULL,
		[transporter2_code] [varchar](15) NULL,
		[date_delivered] [datetime] NULL,
		[source_table] [varchar](20) NULL,
		[receipt_date] [datetime] NULL,
		[receipt_workorder_id] [int] NULL,
		[workorder_start_date] [datetime] NULL,
		[workorder_company_id] [int] NULL,
		[workorder_profit_ctr_id] [int] NULL,
		[customer_id] [int] NULL,
		[cust_name]	[varchar](40) NULL,
		[billing_project_id] int NULL,
		[billing_project_name]	[varchar](40) NULL,
		[purchase_order] 	[varchar](20) NULL,
		[haz_flag] [char](1) NULL,
		[submitted_flag] [char](1) NULL,
		[generator_address_1] [varchar](40) NULL,
		[generator_address_2] [varchar](40) NULL,
		[generator_county] [varchar](30) NULL,
		[generator_zip_code] [varchar](15) NULL,
		[generator_region_code][varchar](40) NULL,
		[generator_division] [varchar](40) NULL,
		[generator_business_unit][varchar](40) NULL,
		[manifest_unit][varchar](15) NULL,
		[manifest_quantity] [float] NULL
	)

exec sp_rpt_generic_disposal_build @customer_id_list, @start_date, @end_date


---------------------------------
-- Export Disposal Data
---------------------------------

   SELECT
      ISNULL(site_code, '') AS 'Facility Number',
      ISNULL(site_type_abbr, '') AS 'Facility Type',
      ISNULL(generator_city, '') AS 'City',
      ISNULL(generator_state, '') AS 'State',
      ISNULL(CONVERT(varchar(20), service_date, 101), '') AS 'Shipment Date',
      ISNULL(epa_id, '') AS 'Generator EPA ID',
      CASE WHEN waste_desc = 'No waste picked up' THEN
          CONVERT(varchar(20), REPLACE(ISNULL(CONVERT(varchar(20), service_date, 101), ''), '/', ''))
      ELSE
          ISNULL(manifest, '')
      END AS 'Manifest Number',
      ISNULL(NULLIF(manifest_line, 0), '') AS 'Manifest Line',
      SUM(ISNULL(pounds, 0)) AS 'Weight',
      SUM(ISNULL(calculated_pounds, 0)) AS 'Calculated Weight',
      SUM(ISNULL(empty_bottle_count, 0)) AS 'Empty Bottle Count',
      ISNULL(bill_unit_desc, '') AS 'Container Type',
      SUM(ISNULL(quantity, 0)) AS 'Container Quantity',
      ISNULL(waste_desc, '') AS 'Waste Description',
      ISNULL(approval_or_resource, '') AS 'Waste Profile Number',
      ISNULL(dot_description, '') AS 'DOT Description',
      ISNULL(waste_code_1, '') AS 'Waste Code 1',
      ISNULL(waste_code_2, '') AS 'Waste Code 2',
      ISNULL(waste_code_3, '') AS 'Waste Code 3',
      ISNULL(waste_code_4, '') AS 'Waste Code 4',
      ISNULL(waste_code_5, '') AS 'Waste Code 5',
      ISNULL(waste_code_6, '') AS 'Waste Code 6',
      ISNULL(waste_code_7, '') AS 'Waste Code 7',
      ISNULL(waste_code_8, '') AS 'Waste Code 8',
      ISNULL(waste_code_9, '') AS 'Waste Code 9',
      ISNULL(waste_code_10, '') AS 'Waste Code 10',
      ISNULL(waste_code_11, '') AS 'Waste Code 11',
      ISNULL(waste_code_12, '') AS 'Waste Code 12',
      ISNULL(state_waste_code_1, '') AS 'State Waste Code 1',
      ISNULL(state_waste_code_2, '') AS 'State Waste Code 2',
      ISNULL(state_waste_code_3, '') AS 'State Waste Code 3',
      ISNULL(state_waste_code_4, '') AS 'State Waste Code 4',
      ISNULL(state_waste_code_5, '') AS 'State Waste Code 5',
      ISNULL(management_code, '') AS 'Management Code',
      ISNULL(epa_source_code, '') AS 'EPA Source Code',
      ISNULL(epa_form_code, '') AS 'EPA Form Code',
      ISNULL(transporter1_name, '') AS 'Transporter Name 1',
      ISNULL(transporter1_epa_id, '') AS 'Transporter 1 EPA ID Number',
      ISNULL(transporter2_name, '') AS 'Transporter Name 2',
      ISNULL(transporter2_epa_id, '') AS 'Transporter 2 EPA ID Number',
      ISNULL(receiving_facility, '') AS 'Receiving Facility',
      ISNULL(receiving_facility_epa_id, '') AS 'Receiving Facility EPA ID Number',
      receipt_id AS 'WorkOrder Number',
      ISNULL(disposal_service_desc, '') AS 'Disposal Method'
      
      , company_id
      , profit_ctr_id
      , receipt_id
      , line_sequence_id
      , generator_id
		, generator_name
		, site_type
		, profile_id
		, container_count
		, date_delivered
		, source_table
		, receipt_date
		, receipt_workorder_id as workorder_id
		, workorder_start_date
		, workorder_company_id
		, workorder_profit_ctr_id
		, customer_id
		, cust_name
		, billing_project_id
		, billing_project_name
		, purchase_order
		, haz_flag
	    , generator_address_1
	    , generator_address_2
		, generator_county
		, generator_zip_code
		, generator_region_code
		, generator_division
		, generator_business_unit
		, manifest_unit
		, manifest_quantity
   FROM #DisposalExtract DisposalExtract
   where isnull(submitted_flag, 'F') = 'T'
   GROUP BY            
      site_code,
      site_type_abbr,
      generator_city,
      generator_state,
      service_date,
      epa_id,
      CASE WHEN waste_desc = 'No waste picked up' THEN
          CONVERT(varchar(20), REPLACE(ISNULL(CONVERT(varchar(20), service_date, 101), ''), '/', ''))
      ELSE
          ISNULL(manifest, '') 
      END,
      ISNULL(NULLIF(manifest_line, 0), ''),
      ISNULL(bill_unit_desc, ''),
      waste_desc,
      approval_or_resource,
      dot_description,
      waste_code_1,
      waste_code_2,
      waste_code_3,
      waste_code_4,
      waste_code_5,
      waste_code_6,
      waste_code_7,
      waste_code_8,
      waste_code_9,
      waste_code_10,
      waste_code_11,
      waste_code_12,
      state_waste_code_1,
      state_waste_code_2,
      state_waste_code_3,
      state_waste_code_4,
      state_waste_code_5,
      management_code,
      epa_source_code,
      epa_form_code,
      transporter1_name,
      transporter1_epa_id,
      transporter2_name,
      transporter2_epa_id,
      receiving_facility,
      receiving_facility_epa_id,
      receipt_id,
      disposal_service_desc,
      DisposalExtract.profile_id,
      DisposalExtract.company_id,
      DisposalExtract.profit_ctr_id,
      DisposalExtract.tsdf_approval_id,
      DisposalExtract.source_table
      
      , company_id
      , profit_ctr_id
      , receipt_id
      , line_sequence_id
      , generator_id
		, generator_name
		, site_type
		, profile_id
		, container_count
		, date_delivered
		, source_table
		, receipt_date
		, receipt_workorder_id
		, workorder_start_date
		, workorder_company_id
		, workorder_profit_ctr_id
		, customer_id
		, cust_name
		, billing_project_id
		, billing_project_name
		, purchase_order
		, haz_flag
	    , generator_address_1
	    , generator_address_2
		, generator_county
		, generator_zip_code
		, generator_region_code
		, generator_division
		, generator_business_unit
		, manifest_unit
		, manifest_quantity
   ORDER BY
      generator_state,
      generator_city,
      site_code,
      service_date,
      receipt_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_export] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_export] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_export] TO [EQAI]
    AS [dbo];

