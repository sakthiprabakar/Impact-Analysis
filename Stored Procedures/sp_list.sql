


/********************
The purpose of the sp_list procedure is to parse the input list and put each entry into the temp table of the parent stored procedur

sp_list 1, '1/10/2005, 2/10/2005, 3/10/2005', 'DATE', '#tmp_table'
sp_list 1, '1,2,9', 'NUMBER', '#tmp_table'
sp_list 1, '1,2,9', 'STRING', '#tmp_table'
 
11/10/2005 SCC Created
10/04/2012 SK Updated to handle varchar(max) list

**********************/

create procedure sp_list @debug int, @list_in varchar(max), @data_type varchar(10), @table_name varchar(100)
as 

declare

@pos int,
@list_item varchar(100),
@tmp_list varchar(max),
@insert_value varchar(100)

-- Populate the table
SET @tmp_list = @list_in
if @debug = 1 print 'List in: ' + @list_in

SET @pos = 0
WHILE datalength(@tmp_list) > 0
BEGIN
	-- Look for a comma
	select @pos = CHARINDEX(',', @tmp_list)
	if @debug = 1 print 'Pos: ' + convert(varchar(10), @pos)

	-- If we found a comma, there is a more than one item in the list
	if @pos > 0 
	begin
		select @list_item = SUBSTRING(@tmp_list, 1, @pos - 1)
		select @tmp_list = SUBSTRING(@tmp_list, @pos + 1, datalength(@tmp_list) - @pos)
		if @debug = 1 print '@list_item: ' + @list_item
	end

	-- If we did not find a comma, there is only one item in the list or we are at the end of the list
	if @pos = 0
	begin
		select @list_item = @tmp_list
		select @tmp_list = NULL
		if @debug = 1 print '@list_item : ' + @list_item
	end

	-- Insert into table
	IF @data_type = 'NUMBER'
		SET @insert_value = 'INSERT ' + @table_name + ' values (' + LTRIM(RTRIM(@list_item)) + ')'
	ELSE IF @data_type = 'STRING' OR @data_type = 'DATE'
		SET @insert_value = 'INSERT ' + @table_name + ' values (''' + LTRIM(RTRIM(@list_item)) + ''')'

	IF @debug = 1 print @insert_value

	EXECUTE (@insert_value)
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_list] TO [EQAI]
    AS [dbo];

