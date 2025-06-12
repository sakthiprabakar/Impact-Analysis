
/***************************************************************************************
Lists Generators for the Pick Generators Popup
Input 	: A list of Customer_ID's, comma separated.
Output 	: Information on the Generators

09/15/2003 JPB	Created
Test Cmd Line: spw_getgenerators_customerlist '2222, 1128, , 1574,'
****************************************************************************************/
create procedure spw_getgenerators_customerlist
	@generatorlist varchar(8000)
as

	set nocount on
	create table #generatorlist (generator_id int)

	declare @separator_position int -- this is used to locate each separator character
	declare @array_value varchar(1000) -- this holds each array value as it is returned

	set @generatorlist = @generatorlist + ','

	while patindex('%' + ',' + '%' , @generatorlist) <> 0
	begin

	 select @separator_position = patindex('%' + ',' + '%' , @generatorlist)
	 select @array_value = ltrim(rtrim(left(@generatorlist, @separator_position - 1)))

	 if len(ltrim(rtrim(@array_value))) > 0
	 	insert into #generatorlist values(@array_value)

	 select @generatorlist = stuff(@generatorlist, 1, @separator_position, '')
	end

	set nocount off

	select
	distinct generator_id, epa_id, generator_name, generator_city, generator_state
	from generator
	where generator_id in (select generator_id from #generatorlist)
	order by generator_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getgenerators_customerlist] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getgenerators_customerlist] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getgenerators_customerlist] TO [EQAI]
    AS [dbo];

