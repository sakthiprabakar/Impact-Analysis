
Create proc sp_transporter_search (
	@transporter_code_list		varchar(max) = null
	, @search_mode				varchar(20) = null
	, @search_term				varchar(40) = null
	, @transporter_name			varchar(40) = null
	, @transporter_epa_id		varchar(15) = null
	, @Transporter_city			varchar(40) = null
	, @Transporter_state		varchar(2) = null
	, @transporter_contact		varchar(40) = null
)
as
/********************************************************************************
sp_transporter_search

	Find/return Transporters.

History:
	2014-01-23	JPB	Created.

Example:
	sp_transporter_search null, 'OR', 'eqis'
	
********************************************************************************/

declare @sql varchar(max)

create table #Transporter (
	transporter_code varchar(max)
)

if isnull(@transporter_code_list, '') <> ''
	insert #Transporter (transporter_code) select row from dbo.fn_splitxsvText(',', 1, @transporter_code_list) where row is not null


set @sql = 'select * from transporter where transporter_status = ''A'' and( 1=1 '

if isnull(@transporter_code_list, '') <> ''
	set @sql = @sql + ' and (transporter_code in (select transporter_code from #transporter))'
		
if isnull(@transporter_name, '') <> ''
	set @sql = @sql + ' and ( transporter_name like ''%' + replace(@transporter_name, ' ', '%') + '%'' ) '
	
if isnull(@search_term, '') <> ''
	set @sql = @sql + ' and ( isnull(transporter_name, '''') + '' '' + isnull(transporter_code, '''') + '' '' + isnull(transporter_epa_id, '''') + '' '' + isnull(transporter_city, '''') + '' '' + isnull(transporter_state, '''') + '' '' + isnull(transporter_contact, '''') + '' '' + isnull(transporter_contact_phone, '''') + '' '' + isnull(transporter_phone, '''') like ''%' + replace(@search_term, ' ', '%') + '%'' ) '

if isnull(@transporter_epa_id, '') <> ''
	set @sql = @sql + ' and ( transporter_epa_id like ''%' + replace(@transporter_epa_id, ' ', '%') + '%'' ) '
		
if isnull(@Transporter_city, '') <> ''
	set @sql = @sql + ' and ( transporter_city like ''%' + replace(@Transporter_city, ' ', '%') + '%'' ) '

if isnull(@Transporter_state, '') <> ''
	set @sql = @sql + ' and ( transporter_state like ''%' + replace(@Transporter_state, ' ', '%') + '%'' ) '

if isnull(@transporter_contact, '') <> ''
	set @sql = @sql + ' and ( transporter_contact like ''%' + replace(@transporter_contact, ' ', '%') + '%'' ) '

set @sql = @sql + ')'

if @search_mode = 'OR' set @sql= replace(replace(@sql, '1=1', '1=0'), ' and ', ' or ' )

exec(@sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_transporter_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_transporter_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_transporter_search] TO [EQAI]
    AS [dbo];

