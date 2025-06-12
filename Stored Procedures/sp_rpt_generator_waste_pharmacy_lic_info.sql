CREATE PROCEDURE sp_rpt_generator_waste_pharmacy_lic_info
	@date_from		datetime,
	@date_to		datetime
AS
/***************************************************************************************
Loads to:		PLT_AI
PB Object(s):	r_waste_generator_with_pharmacy_lic_info

10/24/2017 AM 	Created - Create a New report for outbounds without a scanned returned manifest

select * from Generator
sp_rpt_generator_waste_pharmacy_lic_info 'CAD981573645','10/01/2017','10/31/2017'
sp_rpt_generator_waste_pharmacy_lic_info '2017-11-16','2017-11-16'
sp_rpt_generator_waste_pharmacy_lic_info '11-16-2017','11-16-2017'
sp_rpt_generator_waste_pharmacy_lic_info '11/16/2017','11/16/2017'
****************************************************************************************/

SELECT	Generator_id,
		Generator_name,
		site_code,
		site_type,
		epa_id,
		pharmacy_license,
		pharmacy_license_expiration_date,
		DEA_ID
FROM Generator
WHERE pharmacy_license_expiration_date between @date_from and @date_to 
--AND (@epa_id = 'ALL' OR Generator.EPA_ID LIKE @epa_id)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generator_waste_pharmacy_lic_info] TO [EQAI]
    AS [dbo];

