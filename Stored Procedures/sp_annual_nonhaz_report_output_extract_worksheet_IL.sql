Drop Proc If Exists sp_annual_nonhaz_report_output_extract_worksheet_IL
go

CREATE PROCEDURE sp_annual_nonhaz_report_output_extract_worksheet_IL (
	@biennial_id	int,
	@report_type	varchar(20) -- 'REPORT' or 'HAULERS'
)
AS
/* **********************************************************************************
Selects from the source data, all that was reported for Annual NonHaz Report for Illinois
History:	02/13/2012 SK created
			02/22/2012 SK Modified the select to match the changes on sp_biennial_report_output_IL_GM
			01/08/2013 JPB - Copied from IL_GM1 SP and modified for Annual NonHaz Report
			
sp_annual_nonhaz_report_output_extract_worksheet_IL 1731, 'REPORT'

SELECT * FROM eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL

sp_annual_nonhaz_report_output_extract_worksheet_IL 1731, 'HAULERS'

SELECT * FROM eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL

*********************************************************************************** */

if @report_type = 'REPORT' begin

--	if object_id('eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL') is not null drop table eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL
	delete eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL
	insert eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL
	SELECT DISTINCT
		SD.IL_management_code
	,	generator_name
	,	generator_address_1 
	,	generator_address_2
	,	generator_address_3 
	,	generator_address_4  
	,	generator_address_5
	,	generator_city
	,	generator_state
	,	generator_zip_code
	,	generator_state_id
	,	SD.IL_waste_code

	,	RIGHT(space(10) + ISNULL(convert(varchar(10), convert(numeric(10,1), 
			CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 THEN isnull(sd.yard_haz_actual, 0) -- yards
				 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 THEN isnull(sd.gal_haz_actual, 0) -- gallons
				 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.IL_waste_code = '18' THEN isnull(sd.gal_haz_actual, 0) -- gallons
				 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.IL_waste_code = '19' THEN isnull(sd.yard_haz_actual, 0) -- yards
				 ELSE isnull(sd.lbs_haz_actual, 0) -- pounds
			END
		)),''), 10) as Quantity

	,	CASE WHEN ISNULL(sd.yard_haz_actual,0) <> 0 and ISNULL(sd.gal_haz_actual,0) = 0 THEN 'Cubic Yards' -- 2 -- yards
			 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) = 0 THEN 'Gallons' -- 1 -- gallons
			 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.IL_waste_code = '18' THEN 'Gallons' -- 1 -- gallons
			 WHEN ISNULL(sd.gal_haz_actual,0) <> 0 and ISNULL(sd.yard_haz_actual,0) <> 0 and sd.IL_waste_code = '19' THEN 'Cubic Yards' -- 2 -- yards
			 ELSE 'Pounds' -- pounds
		END AS Unit_Of_Measure
	
		,Company_id				
		,profit_ctr_id			
		,receipt_id				
		,line_id					
		,container_id			
		,sequence_id				
		,treatment_id			
		,lbs_haz_actual			
		,lbs_haz_estimated		
		,gal_haz_actual			
		,gal_haz_estimated		
		,yard_haz_actual			
		,yard_haz_estimated		
		,container_percent		
		,approval_code			
		,waste_density			
		,eq_generator_id			
		
	--INTO eq_temp..sp_annual_nonhaz_report_output_extract_worksheet_IL
	FROM EQ_Extract..ILAnnualNonHazReport SD
	WHERE biennial_id = @biennial_id


END

if @report_type = 'HAULERS' begin

	 --if object_id('eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL') is not null drop table eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL
	delete eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL
	insert eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL
	SELECT DISTINCT
	
		-- Hmm. We have no State of IL 4 digit SWH permit number or their Uniform Program Permit ID number.  Oy.  I *love* IL Formats.  Honest.
		NULL as Hauler_Permit_ID_Number
		
		, T.transporter_name as Hauler_Name
		, T.transporter_addr1
		, T.transporter_addr2
		, T.transporter_addr3
		, T.transporter_city
		, T.transporter_state
		, T.transporter_zip_code

		,SD.Company_id				
		,SD.profit_ctr_id			
		,SD.receipt_id				
		,SD.line_id					
		,SD.container_id			
		,SD.sequence_id				
		, T.transporter_code
		
	--INTO eq_temp..sp_annual_nonhaz_report_output_hauler_worksheet_IL
	FROM EQ_Extract..ILAnnualNonHazReport SD
	INNER JOIN ReceiptTransporter RT on SD.receipt_id = RT.receipt_id
		AND SD.company_ID = RT.company_id
		and SD.profit_ctr_id = RT.profit_ctr_id
	INNER JOIN Transporter T on RT.transporter_code = T.transporter_code
	WHERE biennial_id = @biennial_id


END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_annual_nonhaz_report_output_extract_worksheet_IL] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_annual_nonhaz_report_output_extract_worksheet_IL] TO [COR_USER]


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_annual_nonhaz_report_output_extract_worksheet_IL] TO [EQAI]

