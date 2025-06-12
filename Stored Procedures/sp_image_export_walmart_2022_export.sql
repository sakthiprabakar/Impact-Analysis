use plt_export
go

alter proc sp_image_export_walmart_2022_export
(
	@export_id int
)
as begin

	-- declare @export_id int = 5554 

	declare @iemail varchar(100)

	select top 1 @iemail = email 
	from plt_ai..users u 
	join plt_export..EQIPImageExportHeader e
	on u.user_code = e.added_by
	where export_id = @export_id
	
	-- select 'sp_image_export_walmart_2022_export', @email email

/*	
	select 'sp_image_export_walmart_2022_export EQIPImageExportWalmartMeta contents', 
		[manifest number]
		, [service type]
		, [store number]
		, [city]
		, [state]
		, [zip code]
		, [service date]
		, [service provider]
	from plt_export..EQIPImageExportWalmartMeta
	WHERE export_id = @export_id
	order by row_id
*/

	declare @qry varchar(8000)
	declare @column1name varchar(50)
	-- Create the column name with the instruction in a variable
	SET @Column1Name = '[sep=,' + CHAR(13) + CHAR(10) + 'Manifest Number]'
	 
	-- Create the query, concatenating the column name as an alias
	select @qry='set nocount on;
		select
			''"'' + [manifest number] + ''"'' as ' + @Column1Name + 
			', ''"'' + [service type] + ''"'' as [Service Type]
			 , ''"'' + [store number] + ''"'' as [Store Number]
			 , ''"'' + [city] + ''"'' as [City]
			 , ''"'' + [state] + ''"'' as [State]
			 , ''"'' + [zip code] + ''"'' as [Zip Code]
			 , ''"'' + [service date] + ''"'' as [Service Date]
			 , ''"'' + [service provider] + ''"'' as  [Service Provider]
		from plt_export..EQIPImageExportWalmartMeta
		WHERE export_id = ' + convert(varchar(20), @export_id) + '
		order by row_id
		'

-- SELECT  * FROM    plt_export..EQIPImageExportWalmartMeta
	               
	-- select @qry
	 
	-- exec (@qry)
	 
	-- select 'send email'
	begin try
		-- Send the e-mail with the query results in attach
		exec msdb.dbo.sp_send_dbmail @recipients=@iemail,
		@query=@qry,
		@subject='Wal-Mart Image Export Metafile',
		@attach_query_result_as_file = 1,
		@query_attachment_filename = 'MetaFile.csv',
		@query_result_separator=',',@query_result_width =32767,
		@query_result_no_padding=1
		, @execute_query_database = 'plt_export'
	end try
	begin catch

		declare @m_id bigint;
		declare @mess varchar(max) = '
There was a problem exporting the metadata for your Wal-Mart image extract.

If you contact IT about this failure (you could forward this message) they
can use the following database statement to retrieve your data, copy it to
Excel and email it to you.

select
	[Manifest Number], [Service Type], 
	[Store Number], [City], [State], 
	[Zip Code], [Service Date], [Service Provider]

from plt_export..EQIPImageExportWalmartMeta
WHERE export_id = ' + convert(varchar(20), @export_id) + '
order by row_id

'
		exec @m_id = plt_ai..sp_message_insert 
		@subject = 'Wal-Mart Image Export Metafile Failed.  Whoops.'
		,@message = @mess
		,@html = ''
		,@created_by	= 'ImageExport'
		,@message_source	= 'ImageExport';

		exec plt_ai..sp_messageAddress_insert 
		@message_id = @m_id 
		,@address_type='FROM'
		,@email='webdevgroup@usecology.com'
		,@company='USE IT';

		exec plt_ai..sp_messageAddress_insert 
		@message_id = @m_id 
		,@address_type='TO'
		,@email=@iemail
		,@company='USE';
	
	end catch
	-- select 'after email'

/*
	Exec msdb.dbo.sysmail_help_configure_sp

	select 1024 /* 1 kb */ * 1024 /* 1 mb */ * 20 /* 20mb */
	select 1024 /* 1 kb */ * 1024 /* 1 mb */ * 40 /* 50mb */
	-- was 1000000
	EXECUTE msdb.dbo.sysmail_configure_sp 'MaxFileSize', '41943040' ;

	-- sp_send_dbmail tests ok at 20mb.  
	-- sp_send_dbmail doesn't arrive at 50mb.  

*/

end
go

grant execute on sp_image_export_walmart_2022_export to eqai, eqweb, cor_user
go
