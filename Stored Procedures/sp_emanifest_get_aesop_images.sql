
create proc sp_emanifest_get_aesop_images (
	@loc_code				tinyint 			/* loc_code */
	, @work_order_number 	varchar(11) 		/* work order number */
	, @man_sys_number		varchar(max)		/* man_sys_number */
) as
/******************************************************************************************
Retrieve manifest scans related to a source

exec sp_emanifest_get_aesop_images 7, '18071708640', '558500'

select top 40 s.* from plt_image..scan s (nolock)
join plt_image..scanimage si (nolock) on s.image_id = si.image_id
where document_source = 'receipt' and status = 'A'
and app_source = 'aesop'
order by date_added
 
SELECT * FROM plt_image..scan (nolock) where app_source = 'aesop' and status = 'A' and work_order_number =  18081509568 and man_sys_number = '562262'

******************************************************************************************/

	declare @man_sys_number_set table (man_sys_number bigint)
	insert @man_sys_number_set
	select convert(bigint, row)
	from dbo.fn_splitXsvText(',', 1, @man_sys_number)
	where row is not null

	select s.image_id, isnull(manifest, document_name) filename, s.file_type, isnull(s.page_number, 1) page_number, si.image_blob
	from plt_image..scan s
	join plt_image..scanimage si on s.image_id = si.image_id and s.status = 'A'
	join plt_image..scandocumenttype t on s.type_id = t.type_id
	join @man_sys_number_set msns on msns.man_sys_number = s.man_sys_number
	and t.document_type = 'manifest'
	WHERE s.work_order_number = @work_order_number
	and s.loc_code = @loc_code
	and isnull(s.app_source, '') = 'aesop'
	order by isnull(s.page_number, 1)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_get_aesop_images] TO [ATHENA_SVC]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_get_aesop_images] TO [EQAI]
    AS [dbo];

