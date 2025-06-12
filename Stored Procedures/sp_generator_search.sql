/***************************************************************************************
Searches for a Generator

10/08/2003 JPB	Created
01/06/2004 JPB	Altered to handle Generator_id
01/27/2006 JPB	Altered to handle apostrophe's in input correctly

Loads on plt_ai*
Test Cmd Line: sp_generator_search 'basf'
sp_generator_search 'welch''s'

****************************************************************************************/
create procedure sp_generator_search
	@input varchar(40)
AS
	set nocount on
	create table #inputlist (strinput varchar(40))

	declare @separator_position int
	declare @array_value varchar(100)
	declare @tmpinput varchar(40)
	set @tmpinput = replace(@input, '''', '''''')
	set @input = replace(@input, '''', '''''') + ' '

	while patindex('%' + ' ' + '%' , @input) <> 0
	begin

	 select @separator_position = patindex('%' + ' ' + '%' , @input)
	 select @array_value = ltrim(rtrim(left(@input, @separator_position - 1)))

	 insert into #inputlist values (@array_value)

	 select @input = stuff(@input, 1, @separator_position, '')
	end

	declare @thisInput varchar(40)
	declare @SearchSQL varchar(5000)
	declare @SubSQL1 varchar(5000)
	declare @SubSQL3 varchar(5000)

	declare @SubSQL4 varchar(5000)
	declare @SubSQL6 varchar(5000)

	declare @SubSQL7 varchar(5000)
	declare @SubSQL9 varchar(5000)

	set @SubSQL1 = ''
	set @SubSQL3 = ''

	set @SubSQL4 = ''
	set @SubSQL6 = ''

	set @SubSQL7 = ''
	set @SubSQL9 = ''

	declare @intCount int
	declare cursor_tmprows cursor for select replace(strinput, '''', '''''') from #inputlist
	open cursor_tmprows
	fetch next from cursor_tmprows into @thisInput
	while @@fetch_status = 0
	begin
		select @SubSQL1 = @SubSQL1 + '[CONJ] generator_name like ''' + @thisInput + '%'' '
		if @thisInput <> '000' select @SubSQL3 = @SubSQL3 + '[CONJ] epa_id like ''' + @thisInput + '%'' '

		select @SubSQL4 = @SubSQL4 + '[CONJ] generator_name like ''%' + @thisInput + ''' '
		if @thisInput <> '000' select @SubSQL6 = @SubSQL6 + '[CONJ] epa_id like ''%' + @thisInput + ''' '

		select @SubSQL7 = @SubSQL7 + '[CONJ] generator_name like ''%' + @thisInput + '%'' '
		if @thisInput <> '000' select @SubSQL9 = @SubSQL9 + '[CONJ] epa_id like ''%' + @thisInput + '%'' '
		fetch next from cursor_tmprows into @thisInput
	end
	close cursor_tmprows
	deallocate cursor_tmprows

	create table #Results (Results_ID int NOT NULL IDENTITY(1,1), generator_id int NOT NULL, generator_name varchar(40), epa_id varchar(12), relevance int)

	set @SearchSQL = 'insert #Results select generator_id, generator_name, epa_id, 1 as relevance
		from generator where
		generator_name = ''' + @tmpinput + '''
		or epa_id = ''' + @tmpinput + '''
		union
		select generator_id, generator_name, epa_id, 2 as relevance
		from generator where (1=1 and generator_name like ''%' + @tmpinput + '%'' )
		or (1=1 and epa_id like ''%' + @tmpinput + '%'')
		union
		select generator_id, generator_name, epa_id, 3 as relevance
		from generator where (1=1 ' + REPLACE(@SubSQL1, '[CONJ]', 'and') + ')
		or (1=1 ' + REPLACE(@SubSQL3, '[CONJ]', 'and') + ')
		union
		select generator_id, generator_name, epa_id, 4 as relevance
		from generator where (1=1 ' + REPLACE(@SubSQL7, '[CONJ]', 'and') + ')
		or (1=1 ' + REPLACE(@SubSQL9, '[CONJ]', 'and') + ')'

	exec(@SearchSQL)

	select @intCount = count(*) from #Results
	if @intCount < 30
	begin
		set @SearchSQL = 'insert #Results select generator_id, generator_name, epa_id, 5 as relevance
			from generator where (1=1 ' + REPLACE(@SubSQL4, '[CONJ]', 'and') + ')
			or (1=1 ' + REPLACE(@SubSQL6, '[CONJ]', 'and') + ')
			union
			select generator_id, generator_name, epa_id, 6 as relevance
			from generator where (1=0 ' + REPLACE(@SubSQL4, '[CONJ]', 'or') + ')
			or (1=0 ' + REPLACE(@SubSQL6, '[CONJ]', 'or') + ')'

		exec(@SearchSQL)
	end
	select @intCount = count(*) from #Results
	if @intCount < 30
	begin
		set @SearchSQL = 'insert #Results select generator_id, generator_name, epa_id, 7 as relevance
			from generator where (1=1 ' + REPLACE(@SubSQL7, '[CONJ]', 'and') + ')
			or (1=1 ' + REPLACE(@SubSQL9, '[CONJ]', 'and') + ')
			union
			select generator_id, generator_name, epa_id, 8 as relevance
			from generator where (1=0 ' + REPLACE(@SubSQL7, '[CONJ]', 'or') + ')
			or (1=0 ' + REPLACE(@SubSQL9, '[CONJ]', 'or') + ')'

		exec(@SearchSQL)
	end
	delete from #Results where Results_ID not in
	(select Results_ID from #Results y
		where
		relevance = (
			select min(z.relevance)
			from #Results z
			where z.generator_id = y.generator_id))
	set nocount off

	select generator_id, generator_name, epa_id, relevance from #Results order by relevance, generator_name, epa_id
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generator_search] TO [EQAI]
    AS [dbo];

