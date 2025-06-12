/***************************************************************************************
Returns customers with similar names to an input name.

Note, this isn't a broad "match names LIKE this one" sp... it's looking for specific near matches.

10/1/2003 JPB	Created
9/25/2007 JPB	Rewrote to be faster, more accurate
12/11/2007 JPB  Rewrote. Faster. Cheaper. More accurate... not perfect.
12/18/2018 - AM - Task:8275 - Column Length Increased 40 to 75 To Accommodate AESOP Data


Test Cmd Line: sp_customersimilar '', 'wayne', 'mi', '48184', 'bfi', 'wayne'
sp_customersimilar  '112345678901234567890123456789 01234567890123456789012345678902 34567890123','canton','MI',''
	
****************************************************************************************/
create procedure sp_customersimilar
	@name varchar(75),
	@city varchar(40) = '',
	@state varchar(2) = '',
	@zip varchar(15) = ''
AS

	set nocount on


	declare @cleanname varchar(75), @pname varchar(75), @cleannamecity varchar(100)
	declare @cutoff int, @sql varchar(200)


	select @pname = dbo.fn_cleanPunctuation(@name)
	select @cleanname = dbo.fn_cleanCustomerName(@pname)

--	select @name as name, @pname as pname, @cleanname as clean_name
	select @cleannamecity = @cleanname -- + isnull(' ' + @city, '')
	
	select row as word into #cleanwords from dbo.fn_splitXsvtext(' ', 1, @cleannamecity) 

	select customer_id, cust_name, wordcount as preference into #matches from (
		select customer_id, cust_name, count(word) as wordcount from customer inner join #cleanwords on ' ' + cust_name + ' ' like '% ' + word + ' %'
		group by customer_id, cust_name having count(word) >= convert(int, ((select count(*) from #cleanwords)/2)) 
	) a
	
-- 	select * from #matches order by preference desc
	update #matches set preference = preference + 1 where customer_id in (select customer_id from customer where cust_city = @city)

	select customer_id,
	max(isnull(preference,0)) as preference, 
	(dbo.levenshtein(@name, cust_name) +
		dbo.levenshtein(@pname, dbo.fn_cleanPunctuation(cust_name)) +
		dbo.levenshtein(@cleanname, dbo.fn_cleanCustomerName(cust_name))) / 3 as all_diff
	into #results
	from #matches 
	where preference > 0
	group by customer_id, cust_name

	select c.customer_id,
		c.cust_name,
		c.cust_phone,
		c.cust_city,
		c.cust_state,
		c.cust_zip_code,
		c.cust_prospect_flag as prospect_flag,
		0 as diff 
	from 
		#results r
		inner join customer c on r.customer_id = c.customer_id
	where (
		r.preference > convert(int, ((select count(*) from #cleanwords)/2))
		or
		r.all_diff < (select min(all_diff) * 1.75 from #results where preference < 80 and all_diff > 1)
		)
	order by r.preference desc, r.all_diff, c.cust_name

/*
	select * from #results where (
	preference > convert(int, ((select count(*) from #cleanwords)/2))
	or
	all_diff < (select min(all_diff) * 1.75 from #results where preference < 80 and all_diff > 1)
	)
	order by preference desc, all_diff
*/
	-- select * from #matches order by preference desc
	-- select * from #results order by preference desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customersimilar] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customersimilar] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customersimilar] TO [EQAI]
    AS [dbo];

