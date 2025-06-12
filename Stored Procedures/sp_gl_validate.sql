
create procedure sp_gl_validate
	@gl_account_code varchar(32),
	@validation_type char(1),
	@create_flag int,
	@create_legacy_flag int = 0
as

/****************************************
 *
 * created in NTSQL1.Plt_ai
 *
 *	Validation Types:	G - Epicor GL Chart / Income Summary
 *						P - Product (addl checks for sys products)
 *						T - Treatment (addl checks for sys products)
 *						W - Workorder Type (loops through natural segs from
 *							WorkOrderResourceType and checks for sys products)
 *
 * 01/25/2012 rb - Created
 *
 ****************************************/
declare @rc int,
		@err varchar(255)

-- collect error and information messages
create table #gl_validate (msg_type char(1), msg_text varchar(255), msg_dt datetime default getdate())

-- check validation type argument
if ISNULL(@validation_type,'') not in ('G','P','T','W')
begin
	insert #gl_validate (msg_type, msg_text)
	values ('E', 'Invalid Validation Type Argument "' + ISNULL(@validation_type,'') + '": Valid arguments are G, P, T, and W.')
	goto END_OF_PROC
end

-- if a WorkorderType validation, make sure natural segment is 'XXXXX'
if @validation_type = 'W'
begin
	if LEFT(ltrim(@gl_account_code),5) <> 'XXXXX' or ISNUMERIC(RIGHT(@gl_account_code,7)) < 1
	begin
		insert #gl_validate (msg_type, msg_text)
		values ('E', 'GL Account Code ' + ISNULL(@gl_account_code,'') + ' is invalid for WorkOrderType validation. It should constist of XXXXX followed by valid segments 2, 3, and 4.')

		goto END_OF_PROC
	end	
end

-- for all validation types other than WorkorderType, validation against GL Chart and GL Inc Sum
else
begin
	-- validate against Epicor GL Chart
	exec dbo.sp_gl_validate_glchart @gl_account_code, @create_flag

	-- validate against Epicor GL Inc Sum
	exec dbo.sp_gl_validate_glincsum @gl_account_code, @create_flag, @create_legacy_flag
end

-- if this was a GL Chart validation only, return results
if @validation_type = 'G'
	goto END_OF_PROC

-- else if this was a WorkOrderType validation, validate system products for WorkOrderResourceType natural segs
else if @validation_type = 'W'
	exec dbo.sp_gl_validate_wo_resource_types @gl_account_code, @create_flag

-- else if this was a Product or Treatment validation, validate system products
else if @validation_type in ('P', 'T')
	exec dbo.sp_gl_validate_system_products @gl_account_code, @validation_type, @create_flag


END_OF_PROC:
-- return results (need distinct list of type/message ordered by msg_dt, hence odd where clause)
select msg_type, msg_text from #gl_validate t1
where not exists (select 1 from #gl_validate t2 where t2.msg_dt < t1.msg_dt and t2.msg_text = t1.msg_text)
order by msg_dt

drop table #gl_validate

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gl_validate] TO PUBLIC
    AS [dbo];

