--
drop proc if exists sp_cor_api_get_image
go

create proc sp_cor_api_get_image (
	@web_userid	varchar(100),
	@document_id	varchar(max),
	@debug int = 0
)
as
/* ***************************************************************
sp_cor_api_get_image

returns csv list of image_ids if any are valid after comparing
the user information to the data related to the given input image
(which may be a hash or something eventually, but for now will just
be a single image_id)


-- find test rows
SELECT  * FROM    contact WHERE  web_userid = 'court_c'

-- Receipt
select s.receipt_id, s.company_id, s.profit_ctr_id, s.type_id, s.document_name, count(s.image_id)
from contactcorreceiptbucket b
join plt_image..scan s on b.receipt_id = s.receipt_id
and b.company_id = s.company_id
and b.profit_ctr_id = s.profit_ctr_id
join plt_image..scandocumenttype sdt on s.type_id = sdt.type_id
join plt_image..scanimage si on s.image_id = si.image_id
WHERE b.contact_id = 175531 -- Court_C
and s.view_on_web = 'T'
and sdt.view_on_web = 'T'
and s.status = 'A'
GROUP BY s.receipt_id, s.company_id, s.profit_ctr_id, s.type_id, s.document_name
ORDER BY count(s.image_id) desc

SELECT  * FROM    plt_image..scan WHERE receipt_id = 619077 and company_id = 44 and type_id = 1

exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= 14168718

-- Work Order
select s.workorder_id, s.company_id, s.profit_ctr_id, s.type_id, s.document_name, count(distinct s.image_id)
from contactcorworkorderheaderbucket b
join plt_image..scan s on b.workorder_id= s.workorder_id
and b.company_id = s.company_id
and b.profit_ctr_id = s.profit_ctr_id
join plt_image..scandocumenttype sdt on s.type_id = sdt.type_id
join plt_image..scanimage si on s.image_id = si.image_id
WHERE b.contact_id = 175531 -- Court_C
and s.view_on_web = 'T'
and sdt.view_on_web = 'T'
and s.status = 'A'
GROUP BY s.workorder_id, s.company_id, s.profit_ctr_id, s.type_id, s.document_name
ORDER BY count(distinct s.image_id) desc

SELECT  * FROM    plt_image..scan WHERE workorder_id = 19384500 and company_id = 14 and type_id = 28

exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= 9717490 -- works, multi-page result
exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= 97174902 -- bad ID, null result.

-- Profile
select s.profile_id, s.company_id, s.profit_ctr_id, s.type_id, s.document_name, count(s.image_id)
from contactcorprofilebucket b
join plt_image..scan s on b.profile_id= s.profile_id
--and b.company_id = s.company_id
--and b.profit_ctr_id = s.profit_ctr_id
join plt_image..scandocumenttype sdt on s.type_id = sdt.type_id
join plt_image..scanimage si on s.image_id = si.image_id
WHERE b.contact_id = 175531 -- Court_C
and s.view_on_web = 'T'
and sdt.view_on_web = 'T'
and s.status = 'A'
GROUP BY s.profile_id, s.company_id, s.profit_ctr_id, s.type_id, s.document_name
ORDER BY count(s.image_id) desc

SELECT  * FROM    plt_image..scan WHERE profile_id = 477206 and type_id = 8

SELECT  * FROM    plt_image..scan WHERE image_id = 12561452

exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= 12561452

*** And now with encryption ***

declare @passphrase varchar(100)

select top 1 @passphrase = config_value
from configuration where config_key = 'COR2 Image Service Passphrase'
if @passphrase is null set @passphrase = 'default password'

select 	EncryptByPassPhrase(@passphrase, convert(varchar(20), 9717490)  )


exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= 9717490 -- works, multi-page result
becomes
exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= '0x01000000E958D1676E0B775D372974DD347430CA3071421057AF6AA1' -- works, multi-page result
actually the 0x prefix is optional (the sp will add it if missing)
exec sp_cor_api_get_image @web_userid = 'court_c', @document_id	= '01000000E958D1676E0B775D372974DD347430CA3071421057AF6AA1' -- works, multi-page result


*************************************************************** */

/*
-- debuggery:
declare @web_userid varchar(100) = 'court_c'
	, @document_id varchar(max) = '12561452'
	, @debug int = 1
*/

declare @i_web_userid varchar(100) = isnull(@web_userid, '')
	, @i_debug int = isnull(@debug, 0)
	, @i_document_id varchar(max) = isnull(@document_id, '')
	, @i_contact_id int
	, @i_image_id int
	, @document_source varchar(30) -- defined in plt_image..scan
	, @document_name varchar(50) -- defined in plt_image..scan
	, @key_id int /* profile_id, receipt_id, workorder_id, etc from plt_image..scan*/
	, @company_id int -- plt_image..scan
	, @profit_ctr_id int -- plt_image..scan
	, @is_valid int = 0
	, @type_id int
	, @scan_type varchar(30)
	, @passphrase varchar(100)
	

select top 1 @i_contact_id = contact_id 
from corcontact 
WHERE web_userid = @i_web_userid

set @passphrase = 'cor2 launched 5/18/2020'

-- if the @i_document_id value were a hash, convert it to
-- an image_id value here (would take a lookup table or something)
-- until then...
if len(@i_document_id) > 20 begin
if left(@i_document_id,2) <> '0x' set @i_document_id = '0x' + @i_document_id
select @i_image_id = convert(int,
	convert(varchar(20), -- convert back to original datatype and len
		decryptByPassphrase(@passphrase, -- decryption function and password
			convert(varbinary(256), -- convert the varchar saved value back to varbinary.
				@i_document_id, 1 -- saved varchar column and "style" option. Style "1" is required
			) -- end of convert(varbinary)
		) -- end of decryptByPassphrase()
	) -- end of convert(varchar(20)...)
) -- end of convert(int...)
end else begin
	select @i_image_id = convert(int, @i_document_id)
end

-- see if this @i_image_id matches a scan.image_id
-- and identify the kind of doc this image belongs to
-- note: an image_id may identify more than 1 scan row.
-- that's unfortunate: we're only grabbing the top 1.
select top 1
	@document_source = document_source
	, @document_name = document_name
	, @key_id = coalesce(profile_id, receipt_id, workorder_id)
		-- with a few odd exceptions, only 1 of those above is filled in per record.
	, @company_id = company_id
	, @profit_ctr_id = profit_ctr_id
	, @type_id = s.type_id
	, @scan_type = sdt.document_type
from plt_image..scan s
join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
WHERE s.image_id = @i_image_id
and s.view_on_web = 'T'
and sdt.view_on_web = 'T'
and s.status = 'A'

if @i_debug = 1
	select 
	@i_web_userid web_userid
	, @i_contact_id contact_id
	, @i_image_id image_id
	, @document_source document_source
	, @document_name document_name
	, @key_id [key_id]
	, @company_id company_id
	, @profit_ctr_id profit_ctr_id
	, @type_id [type_id]
	, @scan_type scan_type

-- validate the found document(if any) is visible to the user
/*
--  Actually, don't need to do this here.  fn_cor_scan_lookup does it anyway.

if @document_source = 'receipt'
	select top 1 @is_valid = 1 from contactcorreceiptbucket b
	WHERE receipt_id = @key_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and contact_id = @i_contact_id
	

if @document_source = 'workorder'
	select top 1 @is_valid = 1 from contactcorworkorderheaderbucket b
	WHERE workorder_id = @key_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and contact_id = @i_contact_id

if @document_source = 'approval'
	select top 1 @is_valid = 1 from contactcorprofilebucket b
	WHERE profile_id = @key_id
	-- and company_id = @company_id	-- profiles don't have company
	-- and profit_ctr_id = @profit_ctr_id	-- profiles don't have profitctr
	and contact_id = @i_contact_id

if @i_debug = 1
	select @is_valid is_valid
*/

drop table if exists #tmp

select distinct *
into #tmp	
	FROM    dbo.fn_cor_scan_lookup (
		@i_web_userid
		, @document_source
		, @key_id
		, @company_id
		, @profit_ctr_id
		, 0
		, @scan_type) s
where type_id = @type_id

if @i_debug = 1
select *
	FROM    #tmp
	
--if @is_valid = 1
select images = substring(
	(
	select ', ' 
	+ coalesce(s.document_name, s.manifest, convert(varchar(20), @i_image_id))
	+ '|'
	+coalesce(convert(varchar(3),s.page_number), '1') 
	+ '|'
	+coalesce(s.file_type, '') 
	+ '|' 
	+ convert(Varchar(10), s.image_id)
	FROM  #tmp s
	order by 	
	s.page_number
	for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)

go

grant execute on sp_cor_api_get_image to eqweb
go
grant execute on sp_cor_api_get_image to cor_user
go
grant execute on sp_cor_api_get_image to eqai
go

