
create procedure sp_gl_validate_wo_resource_types
	@gl_account_code varchar(32),
	@create_flag int
as
/****************************************
 *
 * created in NTSQL1.Plt_ai
 *
 * 01/25/2012 rb - Created
 *
 ****************************************/
declare @sql nvarchar(1024),
		@rc int,
		@gl_seg_1 varchar(5),
		@company varchar(2),
		@profit_ctr varchar(2),
		@gl_seg_4 varchar(3),
		@wo_type_seg_1 varchar(5),
		@alt_gl_account varchar(32),
		@err varchar(255),
		@dt datetime,
		@return_results int

-- collect error and information messages
if not exists (select 1 from tempdb..sysobjects (nolock) where type = 'U' and name like '#gl_validate%')
begin
	create table #gl_validate (msg_type char(1), msg_text varchar(255), msg_dt datetime default getdate())
	select @return_results = 1
end

-- validate account code and extract segments (get rid of 'XXXXX' prefix for account validation)
select @gl_account_code = REPLACE (@gl_account_code, 'XXXXX', '00000')
exec @rc = dbo.sp_gl_validate_account @gl_account_code,
				@gl_seg_1 OUTPUT, @company OUTPUT, @profit_ctr OUTPUT, @gl_seg_4 OUTPUT, @err OUTPUT
if @rc < 0
begin
	insert #gl_validate (msg_type, msg_text) values ('E', @err)
	goto END_OF_PROC
end

--
-- validate: all system products of interest exist in Epicor GL Chart
--
declare c_wotypes cursor forward_only static read_only for
select distinct gl_seg_1
from WorkOrderResourceType

open c_wotypes
fetch c_wotypes into @wo_type_seg_1

while @@FETCH_STATUS = 0
begin
	select @dt = GETDATE()

	--
	-- build SQL accomodating XXX suffix, and XXXXX prefix (although no such prefix is currently used)
	--
	select @alt_gl_account = @wo_type_seg_1 + @company + @profit_ctr + @gl_seg_4

	exec dbo.sp_gl_validate_glchart @alt_gl_account, @create_flag

	update #gl_validate set msg_text = REPLACE(msg_text, 'GL Account', 'WO RES TYPE GL Account')
	where msg_dt > @dt

	exec dbo.sp_gl_validate_glincsum @alt_gl_account, @create_flag
	
	exec @rc = dbo.sp_gl_validate_system_products @alt_gl_account, 'W', @create_flag

	fetch c_wotypes into @wo_type_seg_1
end
close c_wotypes
deallocate c_wotypes

END_OF_PROC:
-- return results if not called from other stored procedure
if ISNULL(@return_results,0) = 1
begin
	select msg_type, msg_text from #gl_validate t1
	where not exists (select 1 from #gl_validate t2 where t2.msg_dt < t1.msg_dt and t2.msg_text = t1.msg_text)
	order by msg_dt

	drop table #gl_validate
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gl_validate_wo_resource_types] TO PUBLIC
    AS [dbo];

