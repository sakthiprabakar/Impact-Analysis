/*

create procedure convert_generator_contact as

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
                         generator_id int null,
                         generator_name varchar(40) null,
			prefix varchar(10) null,
			firstname varchar(20) null,
			midname varchar(20) null,
			lastname varchar(20) null,
			suffix varchar(25) null,
			primary_contact char(1) )

create table #mails ( contact_id int null,
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
                         generator_id int null,
                         generator_name varchar(40) null,
			prefix varchar(10) null,
			firstname varchar(20) null,
			midname varchar(20) null,
			lastname varchar(20) null,
			suffix varchar(25) null,
			primary_contact char(1) )


declare @contact_id int,
        @contact_name varchar(40),
        @contact_title varchar(20),
        @generator_id int ,
        @generator_name varchar(40),
        @more_rows char(1),
        @next_key int,
        @rows_to_convert int,
        @rows_loaded_contact int,
        @rows_loaded_xref int,
        @mail_rows_to_convert int,
        @mail_rows_loaded_contact int,
        @mail_rows_loaded_xref int,
        @dupes_contact_mail int,
        @rows_updated int,
	@prefix varchar(10),
	@fname varchar(20),
	@mname varchar(20),
	@lname varchar(20),
	@suffix varchar(20)


-- prime conversion table

insert #contacts
select null as contact_id,
       generator_contact,
       generator_contact_title,
       generator_phone,
	generator_fax,
       generator_address_1,
	generator_address_2,
	generator_address_3,
	generator_address_4,
	generator_city,
	generator_state,
        generator_zip_code,
       generator_id,
       generator_name,
       null,
       null,
       null,
       null,
       null,
       'F'
-- from Generator 
from CustServ_2006_Generator 
where generator_contact is not null
and   generator_contact <> gen_mail_contact


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
       generator_id ,
       generator_name,
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
       @generator_id ,
       @generator_name,
       @prefix,
	@fname,
	@mname,
	@lname,
	@suffix

while @more_rows = 'Y'
begin
	select @next_key = @next_key + 1 

        select @contact_id = @next_key

--      set teh name parts
        exec sp_nameparts @namestring = @contact_name,
		@name_prefix = @prefix out,
		@first_name = @fname out,
		@middle_name = @mname out,
                @last_name = @lname out,
		@name_suffix = @suffix out

        update #contacts 
	set contact_id = @contact_id,
            firstname = @fname,
	    midname = @mname,
            lastname = @lname,
            prefix = @prefix,
            suffix = @suffix
        where current of gen_contact

	if @@rowcount <> 1 
	begin
		print 'Update failed for contact id'
                select @more_rows = 'N'
        end
                

	fetch gen_contact into @contact_id,
       @contact_name ,
       @contact_title ,
       @generator_id ,
       @generator_name,
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



-- now go back and porcess mail contacts

-- prime conversion table

insert #mails
select null as contact_id,
       gen_mail_contact,
       gen_mail_contact_title,
       generator_phone,
	generator_fax,
       isnull(gen_mail_addr1,generator_address_1),
	isnull(gen_mail_addr2,generator_address_2),
	isnull(gen_mail_addr3,generator_address_3),
	isnull(gen_mail_addr4,generator_address_4),
	isnull(gen_mail_city,generator_city),
	isnull(gen_mail_state,generator_state),
        isnull(gen_mail_zip_code,generator_zip_code),
       generator_id,
       generator_name,
       null,
       null,
       null,
       null,
       null,
       'T'
-- from Generator 
FROM CustServ_2006_Generator
where gen_mail_contact is not null
and gen_mail_contact = generator_contact


if @@rowcount <= 0 
begin
    goto end_result
end

select @mail_rows_to_convert = count(*) from #mails

-- prime up next key


select @more_rows = 'Y'

select @next_key = next_value from Sequence
where name = 'Contact.contact_id'


update Sequence 
set next_value = next_value + (@mail_rows_to_convert + 1)
where name = 'Contact.contact_id'


select @next_key = @next_key + 1 



-- declare cursor for sequencing

declare gen_mail_contact cursor for 
select contact_id,
       contact_name ,
       contact_title ,
       generator_id ,
       generator_name,
	 prefix,
	firstname,
        midname,
        lastname,
	suffix
from #mails
for update

open gen_mail_contact


if @@error <> 0 
begin 
    print 'unable to open mail cursor for sequencing'
    return 0
end

-- priming fetch

fetch gen_mail_contact into @contact_id,
       @contact_name ,
       @contact_title ,
       @generator_id ,
       @generator_name,
       @prefix,
	@fname,
	@mname,
	@lname,
	@suffix

while @more_rows = 'Y'
begin
	select @next_key = @next_key + 1 

        select @contact_id = @next_key

	--      set teh name parts
        exec sp_nameparts @namestring = @contact_name,
		@name_prefix = @prefix out,
		@first_name = @fname out,
		@middle_name = @mname out,
                @last_name = @lname out,
		@name_suffix = @suffix out

        update #mails 
	set contact_id = @contact_id,
            firstname = @fname,
	    midname = @mname,
            lastname = @lname,
            prefix = @prefix,
            suffix = @suffix
	 where current of gen_mail_contact

	if @@rowcount <> 1 
	begin
		print 'Update failed for contact id'
                select @more_rows = 'N'
        end
                

	fetch gen_mail_contact into @contact_id,
       @contact_name ,
       @contact_title ,
       @generator_id ,
       @generator_name,
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

close gen_mail_contact
deallocate gen_mail_contact


-- now insert these rows into the contact table

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
       'gen mail conv' as 'contact_type',
       generator_name as 'contact_company',
       contact_name as 'name',
       contact_title as 'title',
       'Converted from Generator Mail contact field' as 'comments',
       'Converted' as 'modified_by',
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
from #mails
where contact_id is not null

select @mail_rows_loaded_contact = @@rowcount

if @mail_rows_loaded_contact <> @mail_rows_to_convert
begin
	raiserror ('Unable to load all mail contacts', 16,1)
         rollback transaction
        return 4
end


-- now laod the contactxref table as primary

insert ContactXRef
( contact_id, 
  type,
  generator_id, 
  web_access, 
  status,
  primary_contact,
  added_by,
  date_added,
  modified_by,
  date_modified )

select contact_id as 'contact_id',
       'G' as 'type',
       generator_id as 'generator_id',
       'I' as 'web_access',
       'A' as 'status',
       primary_contact as 'primary_contact',
       'Converted' as 'added_by',
       getdate() as 'date_added',
       'Converted' as 'modified_by',
       getdate()as 'date_modified'
from #mails
where contact_id is not null

select @mail_rows_loaded_xref = @@rowcount

if @mail_rows_loaded_xref <> @mail_rows_to_convert
begin
	raiserror ('Unable to load all mail xrefs',16,1)
        rollback transaction
        return 6
end

-- get rid of duplicates

--delete #contacts from #contacts c, #mails m
--where c.contact_name = m.contact_name
--and   c.generator_id = m.generator_id

--select @dupes_contact_mail = @@rowcount

update #contacts
set primary_contact = 'T'
from #contacts c
where c.generator_id not in ( select generator_id from #mails )

-- make contact primary if no mail contact present

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
   fax  )

select contact_id as 'contact_id',
       'A' as 'contact_status',
       'generator convert' as 'contact_type',
       generator_name as 'contact_company',
       contact_name as 'name',
       contact_title as 'title',
       'Converted from Generator' as 'comments',
       'Converted' as 'modified_by',
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

if @rows_loaded_contact <> @rows_to_convert
begin
	raiserror ('Unable to load all contacts', 16,1)
         rollback transaction
        return 4
end


insert ContactXRef
( contact_id, 
  type,
  generator_id, 
  web_access, 
  status,
  primary_contact,
  added_by,
  date_added,
  modified_by,
  date_modified )

select contact_id as 'contact_id',
       'G' as 'type',
       generator_id as 'generator_id',
       'I' as 'web_access',
       'A' as 'status',
       primary_contact as 'primary_contact',
       'Converted' as 'added_by',
       getdate() as 'date_added',
       'Converted' as 'modified_by',
       getdate()as 'date_modified'
from #contacts
where contact_id is not null 

select @rows_loaded_xref = @@rowcount





end_result:

select @next_key = @next_key + 10


update Sequence 
set next_value = @next_key 
where name = 'Contact.contact_id'




select @next_key as 'last_key',
       @rows_to_convert as 'generator_contacts',
       @rows_loaded_contact as 'rows_loaded_contact',
       @Rows_updated as 'nonprimary_contact_updated',
       @rows_loaded_xref as 'rows_loaded_xref',
       @mail_rows_to_convert as 'generator_mail_contacts',
       @mail_rows_loaded_contact as 'mail_rows_loaded_contact',
       @mail_rows_loaded_xref as 'mail_rows_loaded_xref',
       @dupes_contact_mail as 'duplecate_contact_mail_names'

select * into dbo.CustServ_2006_Gen_Contacts from #contacts 

select * into dbo.CustServ_2006_Gen_Contacts_Mail from #mails
*/
