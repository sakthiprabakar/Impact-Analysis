
/***************************************************************************************
Returns generators with similar names to an input name.
The city, state and zipcodes aren't used at this time.
Requires: dbo.Levenshtein function

3/15/2005 MK	Created - modeled after sp_customersimilar
Test Cmd Line: sp_generatorsimilar 'MID980991566',''
****************************************************************************************/
Create  procedure sp_generatorsimilar
	@epa_id varchar(12),
	@name varchar(40)

AS
	set nocount on
	select generator_id, generator_name, generator_phone, generator_city, generator_state, generator_zip_code, 5 as diff from Generator where epa_id = @epa_id and generator_name like '%' + @name + '%' order by generator_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generatorsimilar] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generatorsimilar] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generatorsimilar] TO [EQAI]
    AS [dbo];

