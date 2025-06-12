-- drop proc sp_cor_msg_documents 
go

create proc [dbo].[sp_cor_msg_documents]  (
	@web_userid		varchar(100)
	, @customer_id_list varchar(max)=''
    , @generator_id_list varchar(max)=''
    , @display_mode varchar(1) = 'C' /* 'C'ustomer (default) or 'G'enerator */
)
as
/* ****************************************************************************
sp_cor_msg_documents 


6.3. COR2: Displaying the MSG Related Data

6.3.1. COR2: MSG Dashboard à Documents Box

Notes:

· SOW: These are sometimes per customer and sometimes per generator location

· MSA: Per customer account

· Org Chart: Per customer account

6.3.1.1. Use the chart below to determine where to display the related documents from:

Case	Customer Access		Generator Access			Document Links

1		1 or more			No specific generators		SOW from Customer 
														MSA from Customer 
														Org Chart from Customer

2		1 or more			1 generator					SOW from CustomerXGenerator relationship, if exists. 
															If not,
																SOW from Customer 
																MSA from Customer 
																Org Chart from Customer

3		1 or more			2 or more generators		SOW -> Statement saying “See Generator List” 
														MSA from Customer 
														Org Chart from Customer

4		0 customers			1 or more generators		Don’t show the Documents box at all


6.3.1.2. If any document type does not have a related document to show, do not 
	show the document label. For example, if no MSA exists linked to the customer, 
	don’t show “MSA:” with no document.

6.3.1.3. If there are no documents located for the SOW, MSA or Org Chart, don’t show 
	the documents box at all.

6.3.2. COR2: Generator List Page

6.3.2.1. For the MSG generator locations, if the user logged in has Customer 
	account access

6.3.2.1.1. For each Generator that has a SOW file uploaded, display a link 
	to open the file when opening the Generator location details.

6.3.2.1.2. Only show the SOW files if the user has access to the customer id 
	on the CustomerXGenerator relationship to the SOW file.



sp_cor_msg_documents 
	@web_userid = 'nyswyn100'
	, @customer_id_list = ''

SELECT  *  FROM    customer where msg_customer_flag = 'T'
SELECT  *  FROM    MSGManagerType
SELECT  *  FROM    CustomerXMSGManager
SELECT  *  FROM    users where group_id = 1099
sp_columns CustomerXMSGManager


sp_cor_msg_documents 
	@web_userid = 'jodi_g'
	, @customer_id_list = '15128'

sp_cor_msg_documents 
	@web_userid = 'jamieb'
	, @customer_id_list = '10877'

sp_columns contact

select distinct contact.contact_id,contact.web_userid, cb.customer_id--, cg.generator_id
from contact
join ContactCORCustomerBucket cb on contact.contact_id = cb.contact_id
join Customer on cb.customer_id = customer.customer_id
left join ContactCORGeneratorBucket cg on contact.contact_id = cg.contact_id 
left join generator g on cg.generator_id = g.generator_id and g.msg_generator_flag = 'T'
join plt_image..scan on customer.customer_id = scan.customer_id
join plt_image..ScanDocumentType sdt on scan.type_id = sdt.type_id
	and sdt.type_code in ('MSGCUSTMSA', 'MSGCUSTORG', 'MSGCUSTSOW', 'CUSTCONTP')
join plt_image..scanimage on scan.image_id = scanimage.image_id
where customer.msg_customer_flag = 'T'
-- and cg.generator_id is null
ORDER BY contact.web_userid, cb.customer_id

SELECT  * FROM    contactxref WHERE contact_id = 215094

SELECT  * FROM    plt_image..scan where image_id = 13546706

-- convert an existing doc to pricing
update plt_image..scan set type_id = 154, customer_id = 15128 where image_id = 13546706 -- was 122 / 10877

SELECT  * FROM    plt_image..ScanDocumentType WHERE type_id = 154



**************************************************************************** */


--declare
--	@web_userid varchar(100) = 'nyswyn100'
--	, @customer_id_list varchar(max) = ''
--	, @generator_id_list varchar(max) = '' -- '169109, 168770, 169225, 183049' 
--	, @display_mode varchar(1) = 'C'

set nocount on

declare @i_contact_id	int
	, @i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')
	, @i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')
	, @i_display_mode	varchar(1)			= isnull(@display_mode, 'C')
	, @debug int = 0 -- usually 0.
	
select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

	if @debug = 1 PRINT 'Contact ID: ' + convert(varchar(10), @i_contact_id)


declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null


/*
			select 
				b.customer_id
				, null generator_id
				, sdt.document_type
				, isnull(s.document_name, convert(varchar(20), s.image_id))
				, s.image_id
			from ContactCORCustomerBucket b
			join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
			join plt_image..Scan s on c.customer_id = s.customer_id and s.status = 'A' and s.view_on_web = 'T'
			join plt_image..ScanImage si on s.image_id = si.image_id
			join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
				and sdt.type_code in ('MSGCUSTMSA', 'MSGCUSTORG', 'MSGCUSTSOW')
				and sdt.view_on_web = 'T'
			where b.contact_id = @i_contact_id
			and (
				@i_customer_id_list = ''
				or (
					b.customer_id in (select customer_id from @customer)
				)
			)
*/			

declare @output table (
	customer_id	int
	, generator_id	int
	, document_type	varchar(100)
	, document_name	varchar(100)
	, image_id	int
)

/*
6.3.1.1. Use the chart below to determine where to display the related documents from:

Case	Customer Access		Generator Access			Document Links

1		1 or more			No specific generators		SOW from Customer 
														MSA from Customer 
														Org Chart from Customer

2		1 or more			1 generator					SOW from CustomerXGenerator relationship, if exists. 
															If not,
																SOW from Customer 
																MSA from Customer 
																Org Chart from Customer

3		1 or more			2 or more generators		SOW -> Statement saying “See Generator List” 
														MSA from Customer 
														Org Chart from Customer

4		0 customers			1 or more generators		Don’t show the Documents box at all

*/

--------------------------------------------------------------------------------------------------------


/*
1		1 or more			No specific generators		SOW from Customer 
														MSA from Customer 
														Org Chart from Customer
*/

if 1 <= (
	select count(b.customer_id)
	from ContactCORCustomerBucket b
	join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	)
	and 0 = (
	select count(b.generator_id)
	from ContactCORgeneratorBucket b
	join generator g on b.generator_id = g.generator_id and b.direct_flag = 'D' and g.msg_generator_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_generator_id_list = ''
			or (
				b.generator_id in (select generator_id from @generator)
			)
		)
	)
	begin
	
		if @debug = 1 PRINT 'In Condition 1'
	
		insert @output
		select 
			b.customer_id
			, null generator_id
			, sdt.document_type
			, isnull(s.document_name, convert(varchar(20), s.image_id))
			, s.image_id
		from ContactCORCustomerBucket b
		join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T' and c.cust_status = 'A' and c.terms_code <> 'NOADMIT'
		join plt_image..Scan s on c.customer_id = s.customer_id and s.status = 'A' and s.view_on_web = 'T'
		join plt_image..ScanImage si on s.image_id = si.image_id
		join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
			and sdt.type_code in ('MSGCUSTMSA', 'MSGCUSTORG', 'MSGCUSTSOW')
			and sdt.view_on_web = 'T'
		where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	end
	
/*
2		1 or more			1 generator					SOW from CustomerXGenerator relationship, if exists. 
															If not,
																SOW from Customer 
																MSA from Customer 
																Org Chart from Customer
*/

if 1 <= (
	select count(b.customer_id)
	from ContactCORCustomerBucket b
	join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	)
	and 1 = (
	select count(b.generator_id)
	from ContactCORgeneratorBucket b
	join customergenerator cg on b.generator_id = cg.generator_id   
	-- and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
		and cg.customer_id in (
			select b.customer_id
			from ContactCORCustomerBucket b
			join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
			where b.contact_id = @i_contact_id
				and (
					@i_customer_id_list = ''
					or (
						b.customer_id in (select customer_id from @customer)
					)
				)
			)
	join generator g on b.generator_id = g.generator_id and b.direct_flag = 'D' and g.msg_generator_flag = 'T' and g.status = 'A'
	where b.contact_id = @i_contact_id
		and (
			@i_generator_id_list = ''
			or (
				b.generator_id in (select generator_id from @generator)
			)
		)
	)
	begin
	
		if @debug = 1 PRINT 'In Condition 2'
	
		insert @output
		select 
			b.customer_id
			, cg.generator_id
			, sdt.document_type
			, isnull(s.document_name, convert(varchar(20), s.image_id))
			, s.image_id
		from ContactCORCustomerBucket b
		join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
		join customergenerator cg on b.customer_id = cg.customer_id
			and cg.generator_id in (select generator_id from @generator)
			   -- and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
		join plt_image..Scan s on c.customer_id = s.customer_id and s.status = 'A' and s.view_on_web = 'T'
		join plt_image..ScanImage si on s.image_id = si.image_id
		join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
			and sdt.type_code in ('MSGCUSTSOW')
			and sdt.view_on_web = 'T'
		where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
		--and 1=0
		-- This document should belong to the ASSIGNMENT of this generator to this customer.
		-- I don't recognize a SQL structure or description of how this is document assignment
		-- is noted/stored.  So I'm intentionally failing this part of the query so it returns nothing
		-- and continuing with the "if not" logic.
		
		if @@rowcount = 0
		begin		
			insert @output
			select 
				b.customer_id
				, null generator_id
				, sdt.document_type
				, isnull(s.document_name, convert(varchar(20), s.image_id))
				, s.image_id
			from ContactCORCustomerBucket b
			join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
			join plt_image..Scan s on c.customer_id = s.customer_id and s.status = 'A' and s.view_on_web = 'T'
			join plt_image..ScanImage si on s.image_id = si.image_id
			join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
				and sdt.type_code in ('MSGCUSTMSA', 'MSGCUSTORG', 'MSGCUSTSOW')
				and sdt.view_on_web = 'T'
			where b.contact_id = @i_contact_id
			and (
				@i_customer_id_list = ''
				or (
					b.customer_id in (select customer_id from @customer)
				)
			)
		end
	end

/*
3		1 or more			2 or more generators		SOW -> Statement saying “See Generator List” 
														MSA from Customer 
														Org Chart from Customer
*/
if 1 <= (
	select count(b.customer_id)
	from ContactCORCustomerBucket b
	join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	)
	and 1 < (
	select count(b.generator_id)
	from ContactCORgeneratorBucket b
	join customergenerator cg on b.generator_id = cg.generator_id
		and cg.customer_id in (select customer_id from @customer)
		   -- and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
	join generator g on b.generator_id = g.generator_id and b.direct_flag = 'D' and g.msg_generator_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_generator_id_list = ''
			or (
				g.generator_id in (select generator_id from @generator)
			)
		)
	)
	begin
	
		if @debug = 1 PRINT 'In Condition 3'
	
		insert @output
		select
			null customer_id
			, null generator_id
			, 'Statement of Work (SOW)'
			, 'See Generator List'
			, null
		union
		select 
			b.customer_id
			, null generator_id
			, sdt.document_type
			, isnull(s.document_name, convert(varchar(20), s.image_id))
			, s.image_id
		from ContactCORCustomerBucket b
		join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
		join plt_image..Scan s on c.customer_id = s.customer_id and s.status = 'A' and s.view_on_web = 'T'
		join plt_image..ScanImage si on s.image_id = si.image_id
		join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
			and sdt.type_code in ('MSGCUSTMSA', 'MSGCUSTORG', 'MSGCUSTSOW')
			and sdt.view_on_web = 'T'
		where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	end

/*
4		0 customers			1 or more generators		Don’t show the Documents box at all

*/

if 0 = (
	select count(b.customer_id)
	from ContactCORCustomerBucket b
	join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	)
	begin
		-- insert nothing.  You lose.  Good Day Sir.
		if @debug = 1 PRINT 'In Condition 4'
		RETURN 
	end
	
	

if @display_mode = 'G'
begin

/*
6.3.2.1. For the MSG generator locations, if the user logged in has Customer 
	account access

*/

	if 1 <= (
		select count(b.customer_id)
		from ContactCORCustomerBucket b
		join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
		where b.contact_id = @i_contact_id
			and (
				@i_customer_id_list = ''
				or (
					b.customer_id in (select customer_id from @customer)
				)
			)
		)
	begin

/*
6.3.2.1.1. For each Generator that has a SOW file uploaded, display a link 
	to open the file when opening the Generator location details.
	
6.3.2.1.2. Only show the SOW files if the user has access to the customer id 
	on the CustomerXGenerator relationship to the SOW file.
	
*/

		insert @output
		select 
			b.customer_id
			, cg.generator_id
			, sdt.document_type
			, s.document_name
			, s.image_id
		from ContactCORCustomerBucket b
		join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
		join CustomerGenerator cg on b.customer_id = cg.customer_id
		join Generator g on cg.generator_id = g.generator_id and g.msg_generator_flag = 'T'
		join plt_image..Scan s on g.generator_id = s.generator_id and s.status = 'A' and s.view_on_web = 'T'
		join plt_image..ScanImage si on s.image_id = si.image_id
		join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
			and sdt.type_code in ('MSGGENRSOW')
			and sdt.view_on_web = 'T'
		where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
		and (
			@i_generator_id_list = ''
			or (
				g.generator_id in (select generator_id from @generator)
			)
		)
	

/*

6.3.2. COR2: Generator List Page

6.3.2.1. For the MSG generator locations, if the user logged in has Customer 
	account access

6.3.2.1.1. For each Generator that has a SOW file uploaded, display a link 
	to open the file when opening the Generator location details.

6.3.2.1.2. Only show the SOW files if the user has access to the customer id 
	on the CustomerXGenerator relationship to the SOW file.

*/

	end
	
end

-- End...
/*
6.3.1.3. If there are no documents located for the SOW, MSA or Org Chart, don’t show 
	the documents box at all.
*/




/*
DO-18802:
	In the MSG Dashboard's Document box:
	On the MSG Dashboard, if the user logged in is linked to a customer account 
	that meets the following criteria, display a link to the “Contract Pricing” document.
	* Customer is marked as a MSG Customer
	* AND A non-voided scan exists with a Document Type set to ‘Contract Pricing’
	* If no document exists for “Contract Pricing”, do not display the link or label.
	* Do not display the “Contract Pricing” for Generators.   Only display for Customers.
*/
-- 1+ Customers, No Generators (copied section from above)
if 1 <= (
	select count(b.customer_id)
	from ContactCORCustomerBucket b
	join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	)
	and 0 = (
	select count(b.generator_id)
	from ContactCORgeneratorBucket b
	join generator g on b.generator_id = g.generator_id and g.msg_generator_flag = 'T'
	where b.contact_id = @i_contact_id
		and (
			@i_generator_id_list = ''
			or (
				b.generator_id in (select generator_id from @generator)
			)
		)
	)
	begin
	
		if @debug = 1 PRINT 'In Condition 1 for DO-18802'
	
		insert @output
		select 
			b.customer_id
			, null generator_id
			, sdt.document_type
			, isnull(s.document_name, convert(varchar(20), s.image_id))
			, s.image_id
		from ContactCORCustomerBucket b
		join Customer c on b.customer_id = c.customer_id and c.msg_customer_flag = 'T' and c.cust_status = 'A' and c.terms_code <> 'NOADMIT'
		join plt_image..Scan s on c.customer_id = s.customer_id and s.status = 'A' and s.view_on_web = 'T'
		join plt_image..ScanImage si on s.image_id = si.image_id
		join plt_image..ScanDocumentType sdt on s.type_id = sdt.type_id
			and sdt.type_code in ('CUSTCONTP')
			and sdt.view_on_web = 'T'
		where b.contact_id = @i_contact_id
		and (
			@i_customer_id_list = ''
			or (
				b.customer_id in (select customer_id from @customer)
			)
		)
	end


if 0 = (select count(*) from @output)
	RETURN 

set nocount off

select * from @output

RETURN 


GO

GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_msg_documents  TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_msg_documents  TO [COR_USER]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_msg_documents  TO [EQAI]
    AS [dbo];

