
create proc dbo.sp_find_similar_contact 
	@first_name varchar(40) = '',
	@last_name varchar(40) = '',
	@customer_ids varchar(8000) = '',
	@generator_ids varchar(8000) = '',
	@zip_codes varchar(8000) = '',
	@status char(1) = 'A',
	@email varchar(60) = '',
	@debug int = 0
AS
/***************************************************************************************
Returns contacts that are similar to input information
Requires: dbo.Levenshtein function

01/27/2006 	JPB		Created
05/30/2006	JPB		Added Zip Code as a match option
06/05/2006  JPB		Added status option - when not blank/null, returns only contacts where contact_status = @status
08/02/2006	JPB		Public use of this is slow - taking 40+ seconds in many cases.  Working on speeding it up.
09/21/2007	JPB		More accurate name matching rewrite.  Can be slower when a search includes bad records, but
	is generally faster and returns fewer junk results.
02/15/2024 Dipankar #78177 Added Email as a match option

Loads on PLT_AI*

sp_find_similar_contact 'john', 'broom', '2222, 888888', '72, 52461, 39970'
sp_find_similar_contact 'john', 'broom', '2222, 888888', '72, 52461, 39970'

sp_find_similar_contact 'john', 'broom', '2222, 888888', '41192, 10171, 10176, 11292', '48184, 49221, 48187'
sp_find_similar_contact 'jon', 'novak', '', '41192, 10171, 10176, 11292', '48184, 49221, 48187'
sp_find_similar_contact 'alan', 'jensen'
sp_find_similar_contact 'jonathan', 'doe', '', '', '', 'A'
sp_find_similar_contact 'jonathan', 'doe', '', '', '', 'I'
sp_find_similar_contact 'jonathan', 'doe', '', '', '', ''
sp_find_similar_contact 'stacy'
sp_find_similar_contact 'stacey'
sp_find_similar_contact '', 'reynolds'
sp_find_similar_contact 's', 'renolds'
sp_find_similar_contact 's', 'reynolds'
sp_find_similar_contact 'st', 'renolds'
sp_find_similar_contact 'st', 'reynolds'
sp_find_similar_contact 'stacy', 'renolds'
sp_find_similar_contact 'stacy', 'reynolds'
sp_find_similar_contact 'stacey', 'reynolds'
sp_find_similar_contact 'gary', ''
sp_find_similar_contact 'rob', 'weetly'
sp_find_similar_contact 'rob', 'westly'
sp_find_similar_contact '', '', '888888, 1754', ''
sp_find_similar_contact 'john', 'broom', '888888'
sp_find_similar_contact '', '', '', '72, 52461, 39970'
sp_find_similar_contact 'James', 'Williams', '', '', '48184'
sp_find_similar_contact 'James', 'Williams', '', '', '48184'
sp_find_similar_contact 'james', 'davis', '', '', '', 'A', 'usecology.com'

****************************************************************************************/

	set nocount on


	create table #thisname (name varchar(40), dmp varchar(10))
	create index idx_thisname on #thisname (dmp)

	create table #last_name_matches (contact_id	int, first_dmp varchar(10),last_dmp	varchar(10), first_name varchar(40), last_name varchar(40))
	create index idx_ln_match on #last_name_matches (first_dmp)

	create table #first_name_matches (contact_id	int, first_score bigint, last_score bigint, reason varchar(1000), first_name varchar(40), last_name varchar(20), other_id int)
	create index idx_fn_match on #first_name_matches (contact_id)
	create index idx_fn_match_order on #first_name_matches (last_score desc, first_score desc)

	create table #externals (contact_id int, other_id int, reason varchar(1000), source int)
	create index idx_externals on #externals (contact_id)

	declare @run int, @depth int, @above_avg int, @last_dmp varchar(10), @first_dmp varchar(10)
	select @last_dmp = dbo.DoubleMetaPhone(@last_name), @first_dmp = dbo.DoubleMetaPhone(@first_name)


	if len(@last_name) > 0 and len(@first_name) > 0
	begin

		insert #thisname values (@first_name, dbo.DoubleMetaPhone(@first_name))

		select @run = 1, @depth = 1
		while @run > 0 and @depth <= 2 and (@first_name is not null and @first_name <> '')
		begin
			insert #thisname
			select match, dbo.DoubleMetaPhone(match) from nickname where name in (select name from #thisname) and match not in (select name from #thisname)
			union
			select name, dbo.DoubleMetaPhone(name) from nickname where match in (select name from #thisname) and name not in (select name from #thisname)
			select @run = @@rowcount
			select @depth = @depth + 1
		end

		if len(@last_name) > 0 and len(@first_name) > 0 
			begin
				insert #last_name_matches 
					select d.contact_id, case when d.first_dmp = '' then @first_dmp else d.first_dmp end as first_dmp, d.last_dmp, isnull(nullif(c.first_name, ''), @first_name), isnull(nullif(c.last_name, ''), '.') 
					from contactdmp d 
					inner join contact c on d.contact_id = c.contact_id 
					where difference(d.last_dmp, @last_dmp) >= 4

				insert #first_name_matches select distinct m.contact_id, 
					max(dbo.CompareDMP(first_dmp, tn.dmp)) , 
					max(dbo.CompareDMP(last_dmp, @last_dmp)) ,
					'soundalike name' as reason, m.first_name, m.last_name, 0
					from #last_name_matches m 
					inner join #thisname tn on difference(m.first_dmp, tn.dmp) >= 3
					group by m.contact_id, m.first_name, m.last_name

				if @@rowcount = 0 
					insert #first_name_matches select distinct m.contact_id, 
						max(dbo.CompareDMP(first_dmp, tn.dmp)), 
						max(dbo.CompareDMP(last_dmp, @last_dmp)),
						'soundalike name' as reason, first_name, last_name, 0
						from #last_name_matches m, #thisname tn
						group by m.contact_id, first_name, last_name
			end
		else
			begin
				insert #first_name_matches select distinct m.contact_id, 
					100, 
					max(dbo.CompareDMP(last_dmp, @last_dmp)),
					'soundalike name' as reason, isnull(nullif(c.first_name, ''), @first_name), isnull(nullif(c.last_name, ''), '.'), 0
					from contactdmp m 
					inner join contact c on m.contact_id = c.contact_id 
					where difference(last_dmp, @last_dmp) >= 4
					group by m.contact_id, c.first_name, c.last_name
			end

		update #first_name_matches set 
			last_score = case when last_name = @last_name then last_score + 20 else last_score end,
			first_score = case when first_name = @first_name then first_score + 10 else first_score end
			where first_name = @first_name or last_name = @last_name

		if (select count(*) from #first_name_matches) > 15
			select @above_avg = max((first_score + last_score) - (dbo.levenshtein(first_name, @first_name) + dbo.levenshtein(last_name, @last_name))) * 0.70 from #first_name_matches
		else
			select @above_avg = 0
	end
	else
	begin
		declare @above_avg_shill int
		if @above_avg is null
				select @above_avg_shill = 180, @above_avg = 100
	end
			

	if len(@customer_ids) > 0
		insert #externals
		select
			c.contact_id,
			x.customer_id,
			'Matching customer: ' + convert(varchar(20), x.customer_id) as reason,
			9 as source
		from
			contact c inner join contactxref x on c.contact_id = x.contact_id
			where x.customer_id in (select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @customer_ids) where isnull(row, '') <> '')
			and x.type = 'C' and x.status = isnull(nullif(@status, ''), x.status)
			and c.contact_id not in (select contact_id from #first_name_matches)

	if len(@generator_ids) > 0
		insert #externals 
		select
			c.contact_id,
			x.generator_id,
			'Matching generator: ' + convert(varchar(20), x.generator_id) as reason,
			8 as source
		from
			contact c inner join contactxref x on c.contact_id = x.contact_id
			where x.generator_id in (select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @generator_ids) where isnull(row, '') <> '')
			and x.type = 'G' and x.status = isnull(nullif(@status, ''), x.status)
			and c.contact_id not in (select contact_id from #first_name_matches)

	if len(@zip_codes) > 0
		insert #externals 
		select
			c.contact_id,
			0,
			'Matching zipcode' as reason,
			7 as source
		from
			contact c inner join contactxref x on c.contact_id = x.contact_id
			where x.customer_id in (select customer_id from customer where cust_zip_code in (
				select row from dbo.fn_SplitXsvText(',', 1, @zip_codes) where isnull(row, '') <> '')
			) and x.type = 'C' and x.status = isnull(nullif(@status, ''), x.status)
			and c.contact_id not in (select contact_id from #first_name_matches)
	
	if len(@zip_codes) > 0
		insert #externals 
		select
			c.contact_id,
			0,
			'Matching zipcode' as reason,
			7 as source
		from
			contact c inner join contactxref x on c.contact_id = x.contact_id
			where x.generator_id in (select generator_id from generator where generator_zip_code in (
				select row from dbo.fn_SplitXsvText(',', 1, @zip_codes) where isnull(row, '') <> '')
			) and x.type = 'G' and x.status = isnull(nullif(@status, ''), x.status)
			and c.contact_id not in (select contact_id from #first_name_matches)

	-- 78177
	if len(@email) > 0
		insert #externals 
		select
			c.contact_id,
			0,
			'Matching email' as reason,
			6 as source
		from
			contact c
			where  c.email is not null
			and c.email like '%' + @email + '%'
			and c.contact_id not in (select contact_id from #first_name_matches)
		
	select 
		c.contact_id, 
		reason, 
		0 as last_name_difference, 
		r.last_score as last_name_score, 
		0 as first_name_difference, 
		r.first_score as first_name_score,
		c.contact_ID,
		c.contact_status,
		c.contact_type,
		c.contact_company,
		c.name,
		c.title,
		c.phone,
		c.fax,
		c.pager,
		c.mobile,
		c.comments,
		c.email,
		c.email_flag,
		c.added_from_company,
		c.modified_by,
		c.date_added,
		c.date_modified,
		c.web_access_flag,
		c.web_password,
		c.contact_addr1,
		c.contact_addr2,
		c.contact_addr3,
		c.contact_addr4,
		c.contact_city,
		c.contact_state,
		c.contact_zip_code,
		c.contact_country,
		convert(varchar(8000),c.contact_personal_info) as contact_personal_info,
		convert(varchar(8000),c.contact_directions) as contact_directions,
		c.salutation,
		c.first_name,
		c.middle_name,
		c.last_name,
		c.suffix,
		@above_avg as average_score,
		(r.first_score + r.last_score) - (dbo.levenshtein(r.first_name, @first_name) + dbo.levenshtein(r.last_name, @last_name)) as this_score,
		10 as source,
		other_id
	from
		#first_name_matches r inner join contact c on r.contact_id = c.contact_id
	where (r.first_score + r.last_score) - (dbo.levenshtein(r.first_name, @first_name) + dbo.levenshtein(r.last_name, @last_name)) >= @above_avg
	union
	select distinct
		c.contact_id, 
		reason, 
		0 as last_name_difference, 
		0 as last_name_score, 
		0 as first_name_difference, 
		0 as first_name_score,
		c.contact_ID,
		c.contact_status,
		c.contact_type,
		c.contact_company,
		c.name,
		c.title,
		c.phone,
		c.fax,
		c.pager,
		c.mobile,
		c.comments,
		c.email,
		c.email_flag,
		c.added_from_company,
		c.modified_by,
		c.date_added,
		c.date_modified,
		c.web_access_flag,
		c.web_password,
		c.contact_addr1,
		c.contact_addr2,
		c.contact_addr3,
		c.contact_addr4,
		c.contact_city,
		c.contact_state,
		c.contact_zip_code,
		c.contact_country,
		convert(varchar(8000),c.contact_personal_info) as contact_personal_info,
		convert(varchar(8000),c.contact_directions) as contact_directions,
		c.salutation,
		c.first_name,
		c.middle_name,
		c.last_name,
		c.suffix,
		@above_avg as average_score,
		0 as this_score,
		r.source,
		other_id
	from
		#externals r inner join contact c on r.contact_id = c.contact_id
	order by source desc, other_id, (r.first_score + r.last_score) - (dbo.levenshtein(r.first_name, @first_name) + dbo.levenshtein(r.last_name, @last_name)) desc
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_find_similar_contact] TO [EQWEB];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_find_similar_contact] TO [COR_USER];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_find_similar_contact] TO [EQAI];

