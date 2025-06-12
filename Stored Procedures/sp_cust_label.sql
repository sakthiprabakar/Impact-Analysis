
CREATE PROCEDURE sp_cust_label 
	@customer_type		varchar(10),
	@customer_name		varchar(75), 
	@customer_id_from	int, 
	@customer_id_to		int,
	@territory_code		varchar(8),
	@mail_flag		char(1),
	@cust_prospect_flag	char(1)
AS

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_cust_label.sql
PB Object(s):	d_rpt_cust_label_form
		d_rpt_cust_label_merge

09-28-2000 LJT	Changed = NULL to is NULL and <> null to is not null
02-25-2002 SCC	Send city, state, and zip in first available address line
03-08-2004 JDB	Include prospect contacts if requested
12/09/2005 MK	Pointed fn_contact_name to local version and away from plt_ai
04/24/2007 RG   modified for central invoice changes
06/23/2014 AM   Moved to plt_ai db
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
07/14/2024 KS	Rally DE34276 - Modified input argument @customer_name and #label_tmp.customer_name to VARCHAR(75)

sp_cust_label '%', '%', 1, 99999, '%', 'T', 'C'
sp_cust_label '%', '%', 1, 99999999, '%', 'T', 'P'
sp_cust_label '%', '%', 1, 99999999, '%', '%', 'P'
***********************************************************************/
DECLARE	@company_ID int,
	@ws_cust int,
	@maxcust int,
	@nextcust int,
	@customer_id int,   
	@contact varchar(40),
	@cust_contact varchar(40),
	@addr1 varchar(40),
    @addr2 varchar(40),
    @addr3 varchar(40),
	@addr4 varchar(40),
    @addr5 varchar(40),
    @city  varchar(40),
   @state varchar(2) ,
   @zipcode varchar(20),
   @zip varchar(20),
   @country varchar(40),
   @ot_addr1 varchar(40),
   @ot_addr2 varchar(40),
   @ot_addr3 varchar(40),
   @ot_addr4 varchar(40),
   @ot_addr5 varchar(40),
   @cust_id int,
   @cust_name varchar(75),
	@tmp_idx int,
	@tmp_len int
 
CREATE TABLE #label_tmp (
	customer_id		int		NULL, 
	customer_contact	varchar(40)	NULL, 
	customer_name		varchar(75)	NULL, 
	addr1			varchar(40)	NULL, 
	addr2			varchar(40)	NULL, 
	addr3			varchar(40)	NULL, 
	addr4			varchar(40)	NULL, 
	addr5			varchar(40)	NULL,
    city            varchar(40) null,
    state           varchar(2) null,	
	zip_code		varchar(15)	NULL,
	country         varchar(40) null)

SET NOCOUNT ON

SELECT @company_ID = company_ID FROM company


set @zip = ''
-- we dont want the zipcode on the city state line for labels .



-- first identify the customer
-- always select customers that match criteria 
 
insert #label_tmp
select c.customer_id, 
	null as customer_contact, 
	c.cust_name, 
	c.cust_addr1, 
	c.cust_addr2, 
	c.cust_addr3, 
	c.cust_addr4, 
	c.cust_addr5, 
	c.cust_city,
	c.cust_state,
	c.cust_zip_code,
	c.cust_country
	
from customer c
 inner join customerbilling cb on c.customer_id = cb.customer_id
where c.customer_id between @customer_id_from and @customer_id_to
	AND c.customer_type LIKE @customer_type
	AND c.cust_name LIKE @customer_name
	AND ( cb.territory_code = @territory_code or @territory_code = '%' )
	AND c.mail_flag LIKE @mail_flag 
	and c.cust_prospect_flag = 'C'

-- if you want to include prospect then add them to the temp table

--select * from #label_tmp

if @cust_prospect_flag = 'P'
begin
	insert #label_tmp
	select c.customer_id, 
		null as customer_contact, 
		c.cust_name, 
		c.cust_addr1, 
		c.cust_addr2, 
		c.cust_addr3, 
		c.cust_addr4, 
		c.cust_addr5, 
		c.cust_city,
		c.cust_state,
		c.cust_zip_code,
		c.cust_country
		
	from customer c
         where c.customer_id between @customer_id_from and @customer_id_to
          and c.cust_prospect_flag = 'P'
		
end

--select * from #label_tmp
-- now process the addresses and format address and contact name

declare custinfo cursor for 
select customer_id, 
	customer_contact, 
	customer_name, 
	addr1, 
	addr2, 
	addr3, 
	addr4, 
	addr5, 
	city,
	state,
	zip_code,
	country
from #label_tmp

open custinfo

fetch custinfo into @customer_id,   
	@cust_contact,
	@cust_name,
	@addr1 ,
    @addr2 ,
    @addr3 ,
	@addr4 ,
    @addr5 ,
    @city ,
   @state  ,
   @zipcode ,
   @country 

while @@fetch_status = 0
begin
    -- format address
	execute sp_format_address @addr1 = @addr1,
			@addr2 = @addr2,
			@addr3 = @addr3,
                        @addr4 = @addr4,
			@addr5 = @addr5,
                        @city = @city,
                        @state = @state,
                       @zipcode = @zip,
                         @country = @country,
                       @ot_addr1 = @ot_addr1 out,
			@ot_addr2 = @ot_addr2 out,
			@ot_addr3 = @ot_addr3 out,
			@ot_addr4 = @ot_addr4 out,
			@ot_addr5 = @ot_addr5 out 
			
	-- get teh contact name
	
	select @cust_contact =ISNULL(dbo.fn_contact_name(@customer_ID, @company_ID),'')
	
		IF (@cust_contact IS  NULL OR @cust_contact = '') 
		begin
			SET @cust_contact = 'Environmental Manager' 
                end
		

		IF @cust_name  IS  NULL SET @cust_name  = ''
		IF @ot_addr1 IS  NULL SET @addr1 = ''
		IF @ot_addr2 IS  NULL SET @addr2 = ''
		IF @ot_addr3 IS  NULL SET @addr3 = ''
		IF @ot_addr4 IS  NULL SET @addr4 = ''
		IF @ot_addr5 IS  NULL SET @addr5 = ''
		IF @zipcode   IS  NULL SET @zipcode   = ''
			
	-- now updte the record
	
	update #label_tmp
	set customer_name = @cust_name, 
		addr1 = @ot_addr1, 
		addr2 = @ot_addr2,
		addr3 = @ot_addr3, 
		addr4 = @ot_addr4, 
		addr5 = @ot_addr5 ,
		zip_code = @zipcode, 
               customer_contact = @cust_contact
		where customer_id = @customer_id
		
	
	fetch custinfo into @customer_id,   
	@cust_contact,
	@cust_name,
	@addr1 ,
    @addr2 ,
    @addr3 ,
	@addr4 ,
    @addr5 ,
    @city ,
   @state  ,
   @zipcode ,
   @country 
	

end

close custinfo

deallocate custinfo


SELECT
customer_id, 
customer_contact, 
customer_name, 
addr1, 
addr2, 
addr3, 
addr4, 
addr5, 
zip_code
FROM #label_tmp


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cust_label] TO [EQAI]
    AS [dbo];

