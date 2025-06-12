
create procedure sp_gl_validate_system_products
	@gl_account_code varchar(32),
	@validation_type char(1),
	@create_flag int
as
/****************************************
 *
 * created in NTSQL1.Plt_ai
 *
 * 01/24/2012 rb - Created
 *
 ****************************************/
declare @sql nvarchar(1024),
		@rc int,
		@gl_seg_1 varchar(5),
		@company varchar(2),
		@profit_ctr varchar(2),
		@gl_seg_4 varchar(3),
		@product_code varchar(15),
		@alt_gl_account varchar(32),
		@err varchar(255),
		@dt datetime,
		@return_results int

-- collect error and informational messages
if not exists (select 1 from tempdb..sysobjects (nolock) where type = 'U' and name like '#gl_validate%')
begin
	create table #gl_validate (msg_type char(1), msg_text varchar(255), msg_dt datetime default getdate())
	select @return_results = 1
end

-- check validation type argument
if ISNULL(@validation_type,'') not in ('P', 'T', 'W')
begin
	insert #gl_validate (msg_type, msg_text)
	values ('E', 'Invalid Validation Type Argument "' + ISNULL(@validation_type,'') + '": Valid arguments are P, T and W.')
	goto END_OF_PROC
end

-- validate account code and extract segments
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
declare c_sysprod cursor forward_only static read_only for
select product_code, gl_account_code
from Product
where company_id = convert(int,@company)
and profit_ctr_id = convert(int,@profit_ctr)
and product_type = 'X'
and status = 'A'
-- replace this part of where clause with new flag on Product table to 'Validate GL Account'
and ((@validation_type = 'P' and product_code in ('INSR', 'CTTAXSALES', 'NYTAXSALES'))
	or (@validation_type in ('T','W') and (product_code in ('INSR', 'ENSR', 'CTTAXSALES', 'NYTAXSALES')
		or (company_id in (2, 3, 21) and product_code in ('MITAXHAZ', 'MITAXPERP')))))

open c_sysprod
fetch c_sysprod into @product_code, @alt_gl_account

while @@FETCH_STATUS = 0
begin
	select @dt = GETDATE()

	--
	-- build SQL accomodating XXX suffix, and XXXXX prefix (although no such prefix is currently used)
	--
	select @alt_gl_account = case when LEFT(@alt_gl_account,5) = 'XXXXX' then @gl_seg_1 else LEFT(@alt_gl_account,5) end
							+ SUBSTRING(@alt_gl_account,6,4)
							+ case when RIGHT(@alt_gl_account,3) = 'XXX' then @gl_seg_4 else RIGHT(@alt_gl_account,3) end

	exec dbo.sp_gl_validate_glchart @alt_gl_account, @create_flag

	update #gl_validate set msg_text = REPLACE(msg_text, 'GL Account', @product_code + ' GL Account')
	where msg_dt > @dt

	exec dbo.sp_gl_validate_glincsum @alt_gl_account, @create_flag

	fetch c_sysprod into @product_code, @alt_gl_account
end
close c_sysprod
deallocate c_sysprod

END_OF_PROC:
if ISNULL(@return_results,0) = 1
begin
	-- return results (need distinct list of type/message ordered by msg_dt, hence odd where clause)
	select msg_type, msg_text from #gl_validate t1
	where not exists (select 1 from #gl_validate t2 where t2.msg_dt < t1.msg_dt and t2.msg_text = t1.msg_text)
	order by msg_dt

	drop table #gl_validate
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_gl_validate_system_products] TO PUBLIC
    AS [dbo];

