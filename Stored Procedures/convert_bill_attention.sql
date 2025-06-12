


create procedure convert_bill_attention as

create table #contacts ( contact_id int null,
                         contact_name varchar(40)null,
                         contact_title varchar(20) null,
			contact_phone varchar(20) null,
			contact_fax varchar(20) null,
  			contact_addr_1 varchar(40) null,
			contact_addr_2 varchar(40) null,
			contact_addr_3 varchar(40) null,
			contact_addr_4 varchar(40) null,
			contact_city varchar(40) null,
			contact_state varchar(2) null,
			contact_zipcode varchar(15) null,
                         customer_id int null,
                         customer_name varchar(40) null,
			prefix varchar(10) null,
			firstname varchar(20) null,
			midname varchar(20) null,
			lastname varchar(20) null,
			suffix varchar(25) null,
			primary_contact char(1),
            contact_exists char(1),
            custbillcontact_exists char(1),
            attn_name_flag char(1)			)

create table #custbillxcontact ( customer_id int, contact_id int , attn_flag char(1) )

declare @contact_id int,
        @contact_name varchar(40),
        @contact_title varchar(20),
        @customer_id int ,
        @customer_name varchar(40),
        @more_rows char(1),
        @next_key int,
        @rows_to_convert int,
        @rows_loaded_contact int,
        @rows_loaded_xref int,
        @rows_loaded_custbillcontact int,
        @rows_updated_attn_flag int,
        @dupes_contact_mail int,
        @rows_updated int,
	@prefix varchar(10),
	@fname varchar(20),
	@mname varchar(20),
	@lname varchar(20),
	@suffix varchar(20),
	@contact_exists char(1),
	@custbillcontact_exists char(1),
	@attn_name_flag char(1),
	@existing_contact_id int,
	@billing_contact_id int

-- prime the skip accounts

insert #custbillxcontact 
select customer_id , contact_id , attn_name_flag from Customerbillingxcontact where billing_project_id = 0
and attn_name_flag = 'T'



-- prime conversion table

insert #contacts
select null as contact_id,
       ltrim(upper(a.[attention name])),
      a.title as title,
      a.attention_phone,
	null as fax,
       null as address_1,
	null as address_2,
	null as address_3,
	null as address_4,
	null as city,
	null as state,
    null as zip_code,
    a.[Customer ID] as customer_id ,
       a.[customer name] as customer_name,
       null,
       null,
       null,
       null,
       null,
       'F',
       'F',
        'F',
        'T'

-- from armaster
from attentionnames a 
where a.[attention name] is not null 
and not exists ( select 1 from #custbillxcontact x where x.customer_id = a.[customer id] )



if @@rowcount <= 0 
begin
    raiserror ('No contacts found to convert',16,1)
    return 2
end

select @rows_to_convert = count(*) from #contacts

-- prime up next key


select @more_rows = 'Y'

select @next_key = next_value from Sequence
where name = 'Contact.contact_id'


update Sequence 
set next_value = next_value + (@rows_to_convert + 1)
where name = 'Contact.contact_id'


select @next_key = @next_key + 1 



-- declare cursor for sequencing

declare gen_contact cursor for 
select contact_id,
       contact_name ,
       contact_title ,
       customer_id ,
       customer_name,
       prefix,
	firstname,
        midname,
        lastname,
	suffix
from #contacts
for update

open gen_contact


if @@error <> 0 
begin 
    print 'unable to open cursor for sequencing'
    return 0
end

-- priming fetch

fetch gen_contact into @contact_id,
       @contact_name ,
       @contact_title ,
       @customer_id ,
       @customer_name,
       @prefix,
	@fname,
	@mname,
	@lname,
	@suffix


	
while @more_rows = 'Y'
begin
	select @next_key = @next_key + 1 

        select @contact_id = @next_key
		select @contact_exists = 'N',
            @custbillcontact_exists  = 'N',
            @attn_name_flag = 'T'	

--      set the name parts
        exec sp_nameparts @namestring = @contact_name,
		@name_prefix = @prefix out,
		@first_name = @fname out,
		@middle_name = @mname out,
                @last_name = @lname out,
		@name_suffix = @suffix out		 
		 


		 


-- now update the temp table 

        update #contacts 
		set contact_id = @contact_id,
        firstname = @fname,
	    midname = @mname,
            lastname = @lname,
            prefix = @prefix,
            suffix = @suffix,
			contact_exists = @contact_exists,
			custbillcontact_exists = @custbillcontact_exists,
			attn_name_flag = @attn_name_flag
        where current of gen_contact

	if @@rowcount <> 1 
	begin
		print 'Update failed for contact id'
                select @more_rows = 'N'
        end
                
--   check to see if the contact already exists

	fetch gen_contact into @contact_id,
       @contact_name ,
       @contact_title ,
       @customer_id ,
       @customer_name,
       @prefix,
	@fname,
	@mname,
	@lname,
	@suffix

        if @@fetch_status <> 0
        begin
            select @more_rows = 'N'
        end
end

close gen_contact
deallocate gen_contact



-- now insert these rows into the contact table
-- get rid of duplicates ??? one per customer or one per name ????????????
-- 
insert Contact
( contact_id,
  contact_status,
  contact_type,
  contact_company,
  name,
  title,
  comments,
  modified_by,
  date_added,
  date_modified,
   salutation,
   first_name,
   middle_name,
   last_name,
   suffix,
   contact_addr1,
   contact_addr2,
   contact_addr3,
   contact_addr4,
   contact_city,
   contact_state,
   contact_zip_code,
   phone,
   fax )

select contact_id as 'contact_id',
       'A' as 'contact_status',
       'attention name' as 'contact_type',
       customer_name as 'contact_company',
       contact_name as 'name',
       contact_title as 'title',
       'Converted from ARmaster' as 'comments',
       'SACONV' as 'modified_by',
       getdate() as 'date_added',
       getdate() as 'date_modified',
	prefix as salutation,
	firstname as first_name,
	midname as middle_name,
	lastname as last_name,
	suffix	as suffix,
	  contact_addr_1 as contact_addr1,
   	contact_addr_2 as contact_addr2,
   	contact_addr_3 as contact_addr3,
   	contact_addr_4 as contact_addr4,
   	contact_city as contact_city,
   	contact_state as contact_state,
   	contact_zipcode as contact_zip_code,
   	contact_phone as phone,
   	contact_fax as fax 
from #contacts
where contact_id is not null

select @rows_loaded_contact = @@rowcount



-- now laod the contactxref table as primary
-- 
insert ContactXRef
( contact_id, 
  type,
 customer_id, 
  web_access, 
  status,
  primary_contact,
  added_by,
  date_added,
  modified_by,
  date_modified )

select contact_id as 'contact_id',
       'C' as 'type',
       customer_id as 'customer_id',
       'I' as 'web_access',
       'A' as 'status',
       'F'  as 'primary_contact',
       'SACONV' as 'added_by',
       getdate() as 'date_added',
       'SACONV' as 'modified_by',
       getdate()as 'date_modified'
from #contacts
where contact_id is not null 

select @rows_loaded_xref = @@rowcount

-- create customerbilling contact for the zero billing project id
-- 
insert CustomerBillingXContact (
	customer_id,
	billing_project_id,
	contact_id,
	invoice_copy_flag ,
	distribution_method ,
	added_by ,
	date_added ,
	modified_by,
	date_modified ,
	rowguid,
	attn_name_flag,
	invoice_package_content 
)
select c.customer_id as customer_id,
	0 as billing_project_id,
	c.contact_id as contact_id,
	'F' as invoice_copy_flag ,
	distribution_method = ( select b.distribution_method from Customerbilling b where b.customer_id = c.customer_id and b.billing_project_id = 0) ,
	'SACONV' as added_by ,
	getdate() as  date_added ,
	'SACONV' as modified_by,
	getdate() as date_modified ,
	newid() as rowguid,
	c.attn_name_flag as attn_name_flag,
	null as invoice_package_content 
	from #contacts c where c.contact_id is not null 
	
	
select @rows_loaded_custbillcontact = @@rowcount
	
-- unset all attn_flags for the customers in the cotnacts table


select @rows_updated_attn_flag = @@rowcount






end_result:



-- back up table
select * into CentralInv_AttentionName_2007 from #contacts  

-- seelct ou tthe counts
select @rows_loaded_contact as 'contacts_loaded_in_contact',
        @rows_loaded_xref as 'contacts_loaded_in_contactxref',
        @rows_loaded_custbillcontact as 'contacts_loaded_in_custbillcontact',
        @rows_updated_attn_flag as 'custbillcontacts_upd_attn_flag'
		


