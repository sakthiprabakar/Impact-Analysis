/***************************************************************************************
sp_ldr_0204_update
Updates the fields in an LDR.

Input:
	the LDR ID to update
	The selected companies, as a string ("0221, 0301, 1200, 1408" etc)
	generator_name
	generator_code
	generator_address1
	generator_city
	generator_state
	generator_zip
	state_manfiest_no
	manifest_doc_no
	ldr_manifest_line_item
	waste_codes
	ww_or_nww
	subcategory
	manage_method
	reference_numbers
	contains_listed
	exhibits_characteristic
	soil_treatment_standards
	generator_signature
	title
	printed_name
	date
	Logon of the calling process (customer id, eqai login name, etc)

Returns:
	Nothing

What it does:
	Updates the values of an LDR Record

02/26/2004 JPB	Created
****************************************************************************************/
CREATE PROCEDURE sp_ldr_0204_update
	@ldr_id int,
	@selected_companies varchar(1000),
	@ldr_generator_name varchar(40),
	@ldr_generator_epa_id varchar(12),
	@ldr_generator_address1 varchar(40),
	@ldr_generator_address2 varchar(40),
	@ldr_generator_address3 varchar(40),
	@ldr_generator_city varchar(40),
	@ldr_generator_state varchar(2),
	@ldr_generator_zip varchar(10),
	@ldr_state_manifest_no varchar(20),
	@ldr_manifest_doc_no varchar(20),
	@ldr_manifest_line_item char(1),
	@ldr_waste_codes text,
	@ldr_ww_or_nww char(3),
	@ldr_subcategory varchar(40),
	@ldr_manage_method varchar(40),
	@ldr_reference_numbers text,
	@ldr_contains_listed char(8),
	@ldr_exhibits_characteristic char(8),
	@ldr_soil_treatment_standards varchar(13),
	@ldr_generator_signature char(10),
	@ldr_title varchar(40) ,
	@ldr_printed_name varchar(40) ,
	@ldr_date datetime ,
	@logon char(10)
AS
	set nocount on
	declare @separator_position int -- this is used to locate each separator character
	declare @array_value varchar(1000) -- this holds each array value as it is returned
	update ldr set
		ldr_generator_name = @ldr_generator_name ,
		ldr_generator_epa_id = @ldr_generator_epa_id ,
		ldr_generator_address1 = @ldr_generator_address1 ,
		ldr_generator_city = @ldr_generator_city ,
		ldr_generator_state = @ldr_generator_state ,
		ldr_generator_zip = @ldr_generator_zip ,
		ldr_state_manifest_no = @ldr_state_manifest_no ,
		ldr_manifest_doc_no = @ldr_manifest_doc_no ,
		ldr_manifest_line_item = @ldr_manifest_line_item,
		ldr_waste_codes = @ldr_waste_codes ,
		ldr_ww_or_nww = @ldr_ww_or_nww ,
		ldr_subcategory = @ldr_subcategory ,
		ldr_manage_method = @ldr_manage_method ,
		ldr_reference_numbers = @ldr_reference_numbers ,
		ldr_contains_listed = @ldr_contains_listed ,
		ldr_exhibits_characteristic = @ldr_exhibits_characteristic ,
		ldr_soil_treatment_standards = @ldr_soil_treatment_standards,
		ldr_generator_signature = @ldr_generator_signature ,
		ldr_title = @ldr_title ,
		ldr_printed_name = @ldr_printed_name ,
		ldr_date = @ldr_date ,
		ldr_logon = @logon 
	where
		ldr_id = @ldr_id

	delete from ldr_companies where ldr_id = @ldr_id
	
	set @selected_companies = @selected_companies + ','

	while patindex('%' + ',' + '%' , @selected_companies) <> 0
	begin

	 select @separator_position = patindex('%' + ',' + '%' , @selected_companies)
	 select @array_value = ltrim(rtrim(left(@selected_companies, @separator_position - 1)))

	 insert ldr_companies (ldr_id, ldrxc_co_pc, logon, date_added)
	 values (@ldr_id, rtrim(ltrim(@array_value)), @logon, getdate())

	 select @selected_companies = stuff(@selected_companies, 1, @separator_position, '')
	end


	set nocount off
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ldr_0204_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ldr_0204_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ldr_0204_update] TO [EQAI]
    AS [dbo];

