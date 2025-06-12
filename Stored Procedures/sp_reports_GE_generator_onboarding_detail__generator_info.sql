
create proc sp_reports_GE_generator_onboarding_detail__generator_info (
	@generator_id		int
)
as
/* ****************************************************************************
sp_reports_GE_generator_onboarding_detail__generator_info

Shell for calling sp_reports_GE_generator_onboarding_detail with varying arguments
This is because SSRS won't let me have multiple different recordsets in multiple different
calls of the same stored procedure: that is to say, it is stupid.

sp_reports_GE_generator_onboarding_detail__generator_info 169151

SELECT * FROM Generator WHERE generator_id = 169151
SELECT * FROM GeneratorType
**************************************************************************** */

	-----Generator contact information
	select 
		g.generator_name, 
		dbo.fn_format_epa_id(g.epa_id) epa_id, 
		g.generator_id, 
		isnull(g.generator_address_1, '') generator_address_1, 
		isnull(g.generator_address_2,  '') generator_address_2, 
		isnull(g.generator_address_3,  '') generator_address_3, 
		isnull(g.generator_address_4,  '') generator_address_4, 
		isnull(g.generator_address_5,  '') generator_address_5, 
		g.generator_city, 
		g.generator_state, 
		g.generator_zip_code, 
		g.generator_country, 
		isnull(g.generator_phone, '') generator_phone, 
		gt.generator_type,
		g.site_type
	--	,* 
	from generator g 
		left join generatortype gt on g.generator_type_id = gt.generator_type_id
	where g.generator_id = @generator_id
 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__generator_info] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__generator_info] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_GE_generator_onboarding_detail__generator_info] TO [EQAI]
    AS [dbo];

