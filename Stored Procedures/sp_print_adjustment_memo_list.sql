
DROP PROCEDURE IF EXISTS sp_print_adjustment_memo_list 
GO


CREATE PROCEDURE sp_print_adjustment_memo_list 
	@cust_id int,
	@invoice_code_from varchar(16), 
	@invoice_code_to varchar(16),
	@invoice_date_from date, 
	@invoice_date_to date, 
	@adj_date_from date, 
	@adj_date_to date,
	@adjustment_id_from int,
	@debug int = 0
AS
/***********************************************************************
This procedure returns the proper result set for datawindows d_creditmemo_print, d_creditmemo_list
and d_creditmemo_header.

This sp is loaded to Plt_AI.

08/02/2007 RG	Created
10/19/2007 WAC	Modified to return original invoice due amount (rev 1) and latest revision
		invoice due amount.  Datawindow will compute the difference between the
		two amounts and published as total adjustment amount.  In addition, if the 
		latest rev of the invoice has a status of "O"bsolete then a flag will be 
		set and returned to tell the datawindow that the credit memo is not
		official yet until pending adjustments are created.
		Now returning records at the AdjustmentDetail level.
01/15/2008 WAC	Modified to handle multiple customers and invoice codes in the result set.
		Before this modification this procedure assumed that there would be a single
		customer_id in the result set.  Since the user can select adjustments for
		printing by specifying an invoice date range, adjustment date range, and 
		invoice code range then most likely multiple invoices/customers will be 
		in the result set.  Added cust_name and customer_id to order by for the
		returned result set.
06/07/2021 MPM	DevOps 20760 - Increased width of #invoices.cust_name and
				@cust_name to varchar(75).
08/13/2024 Subhrajyoti - Rally #US116662 - SP Update: "sp_print_adjustment_memo" - Elimination of SQL injection through where clause

sp_print_adjustment_memo_list 'and adjustmentheader.adjustment_id = 6838', 0
sp_print_adjustment_memo_list 'and invoiceheader.customer_id = 2492',1
sp_print_adjustment_memo_list 'and invoiceheader.invoice_code = ''10000611''',1

***********************************************************************/
DECLARE @execute_sql	varchar(8000),
@addr1 varchar(40),
@addr2 varchar(40),
@addr3 varchar(40),
@addr4 varchar(40),
@addr5 varchar(40),
@city  varchar(40),
@state varchar(2) ,
@zipcode varchar(20),
@country varchar(40),
@ot_addr1 varchar(40),
@ot_addr2 varchar(40),
@ot_addr3 varchar(40),
@ot_addr4 varchar(40),
@ot_addr5 varchar(40),
@customer_id int,
@cust_name varchar(75),
@where_clause varchar(1024)

create table #invoices (
	 adjustment_id int null,   
         invoice_id int null,   
         company_id int null,
         profit_ctr_id int null,
         trans_source char(1) null,
         receipt_id int null,
         line_id int null,
         price_id int null,
         unsubmitted_billing char(1) null,   
         adj_amt money null,
         adj_date datetime null,   
         hdr_adj_amt money null,   
         memo_comments varchar(255) null,   
         print_memo_comments char(1) null,   
         hdr_added_by varchar(10) null,   
         hdr_date_added datetime null,   
         invoice_code varchar(16) null,   
         invoice_date datetime null,   
         customer_id int null,   
         cust_name varchar(75) null,   
         addr1 varchar(40) null,   
         addr2 varchar(40) null,   
         addr3 varchar(40) null,   
         addr4 varchar(40) null,   
         addr5 varchar(40) null,   
         city varchar(40) null,   
         state varchar(2) null,   
         zip_code varchar(15) null, 
         country varchar(40) null,  
         customer_po varchar(20) null,   
         customer_release varchar(20) null,   
         attention_name varchar(40) null,   
         attention_phone varchar(30) null,   
         rev1_total_amt_due money null,   
         max_rev_total_amt_due money null,   
         max_rev_status varchar(1) null,
         adj_comments varchar(255) null,
         terms_code varchar(8) null,
         due_date datetime null,
         added_by varchar(10)null,
         date_added datetime null,
         modified_by varchar(10) null,
         date_modified datetime null,
         export_status char(1) null )

create table #export ( adjustment_id int null, invoice_id int, export_status char(1) null )

  -- Forming where clause for customer code
 IF @cust_id Is Not NULL
	SET @where_clause = ' AND invoiceheader.customer_id = ' + Convert(Varchar,@cust_id)

 -- Forming where clause for Invoice Code
 IF @invoice_code_from IS NULL 
	SET @invoice_code_from = ''

 IF @invoice_code_to IS NULL 
	SET @invoice_code_to = ''

 IF (@invoice_code_from > '') AND (@invoice_code_to = '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND invoiceheader.invoice_code = ''' + @invoice_code_from + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND invoiceheader.invoice_code = ''' + @invoice_code_from + '''' 
	END
 END
 IF (@invoice_code_from = '') AND (@invoice_code_to > '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND invoiceheader.invoice_code = ''' + @invoice_code_to + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND invoiceheader.invoice_code = ''' + @invoice_code_to + ''''
	END
 END
 IF (@invoice_code_from > '') AND (@invoice_code_to > '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND invoiceheader.invoice_code BETWEEN ''' + @invoice_code_from + ''' AND ''' + @invoice_code_to + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND invoiceheader.invoice_code BETWEEN ''' + @invoice_code_from + ''' AND ''' + @invoice_code_to + ''''
	END
 END 

 --Forming where clause for Invoice date

 IF @invoice_date_from IS NULL 
	SET @invoice_date_from = ''

 IF @invoice_date_to IS NULL 
	SET @invoice_date_to = ''

 IF (@invoice_date_from > '') AND (@invoice_date_to = '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND invoiceheader.invoice_date = ''' + Convert(Varchar,@invoice_date_from) + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND invoiceheader.invoice_date = ''' + Convert(Varchar,@invoice_date_from) + ''''
	END
 END
 IF (@invoice_date_from = '') AND (@invoice_date_to > '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND invoiceheader.invoice_date = ''' + Convert(Varchar,@invoice_date_to) + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND invoiceheader.invoice_date = ''' + Convert(Varchar,@invoice_date_to) + ''''
	END
 END
 IF (@invoice_date_from > '') AND (@invoice_date_to > '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND invoiceheader.invoice_date BETWEEN ''' + Convert(Varchar,@invoice_date_from) + ''' AND ''' + Convert(Varchar,@invoice_date_to) + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND invoiceheader.invoice_date BETWEEN ''' + Convert(Varchar,@invoice_date_from) + ''' AND ''' + Convert(Varchar,@invoice_date_to) + ''''
	END
 END

 --Forming where clause for adjustment date

 IF @adj_date_from IS NULL 
	SET @adj_date_from = ''

 IF @adj_date_to IS NULL 
	SET @adj_date_to = ''

 IF (@adj_date_from > '') AND (@adj_date_to = '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND AdjustmentHeader.adj_date = ''' + Convert(Varchar,@adj_date_from) + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND AdjustmentHeader.adj_date = ''' + Convert(Varchar,@adj_date_from) + ''''
	END
 END
 IF (@adj_date_from = '') AND (@adj_date_to > '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND AdjustmentHeader.adj_date = ''' + Convert(Varchar,@adj_date_to) + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND AdjustmentHeader.adj_date = ''' + Convert(Varchar,@adj_date_to) + ''''
	END
 END
 IF (@adj_date_from > '') AND (@adj_date_to > '')
 BEGIN
	IF @where_clause > ''
	BEGIN
		SET @where_clause = @where_clause + ' AND AdjustmentHeader.adj_date BETWEEN ''' + Convert(Varchar,@adj_date_from) + ''' AND ''' + Convert(Varchar,@adj_date_to) + ''''
	END
	ELSE 
	BEGIN
		SET @where_clause = ' AND AdjustmentHeader.adj_date BETWEEN ''' + Convert(Varchar,@adj_date_from) + ''' AND ''' + Convert(Varchar,@adj_date_to) + ''''
	END
 END
 
 --Forming where clause for adjustment ID

 IF @adjustment_id_from Is Not NULL
 BEGIN
	IF @where_clause > ''
		SET @where_clause = @where_clause + ' AND AdjustmentDetail.adjustment_id = ' + Convert(Varchar,@adjustment_id_from)
	ELSE
		SET @where_clause = ' AND AdjustmentDetail.adjustment_id = ' + Convert(Varchar,@adjustment_id_from)
 END           
            
    
if @where_clause is null 
begin 
	set @where_clause = ''
end

--	Create a record in the temp table for each adjustment detail record encountered for the
--	given invoice (where clause).
SET @execute_sql = 
'INSERT #Invoices 
 SELECT  AdjustmentDetail.adjustment_id,    
         AdjustmentDetail.invoice_id,   
         AdjustmentDetail.company_id,
         AdjustmentDetail.profit_ctr_id,
         AdjustmentDetail.trans_source,
         AdjustmentDetail.receipt_id,
         AdjustmentDetail.line_id,
         AdjustmentDetail.price_id,
         AdjustmentDetail.unsubmitted_billing,   
         isnull(AdjustmentDetail.adj_amt,0),   
         null as adj_date,   
         null as adj_amt,   
         null as memo_comments,   
         null as print_memo_comments,   
         null as added_by,   
         null as date_added,   
         InvoiceHeader.invoice_code,   
         InvoiceHeader.invoice_date,   
         InvoiceHeader.customer_id,   
         null as cust_name,   
         null as cust_addr1,   
         null as cust_addr2,   
         null as cust_addr3,   
         null as cust_addr4,   
         null as cust_addr5,   
         null as cust_city,   
         null as cust_state,   
         null as cust_zip_code,
	 null as country,   
         null as customer_po,   
         null as customer_release,   
         null as attention_name,   
         null as attention_phone,   
         null as rev1_total_amt_due,   
         null as max_rev_total_amt_due,
         ''O'' as max_rev_status,
         null as adj_comments,
         null as terms_code,
         null as due_date,
         null as added_by,
         null as date_added,
         null as modified_by,
         null as date_modified,
         AdjustmentDetail.export_required as export_status
    FROM AdjustmentDetail,   
         AdjustmentHeader,   
         InvoiceHeader
   WHERE ( AdjustmentDetail.adjustment_id = AdjustmentHeader.adjustment_id ) and  
         ( AdjustmentDetail.invoice_id = InvoiceHeader.invoice_id )and
         ( InvoiceHeader.revision_id = 1 )
    ' + @where_clause 

IF @debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + @execute_sql
EXEC (@execute_sql)

-- now update 
-- 
update #invoices
set adj_date = AdjustmentHeader.adj_date,   
    hdr_adj_amt =  AdjustmentHeader.adj_amt,   
   memo_comments =  AdjustmentHeader.memo_comments,   
  print_memo_comments =  AdjustmentHeader.print_memo_comments,   
  hdr_added_by =  AdjustmentHeader.added_by,   
  hdr_date_added =  AdjustmentHeader.date_added,
 adj_comments =  AdjustmentHeader.adj_comments,
  added_by =  AdjustmentHeader.added_by,
   date_added =  AdjustmentHeader.date_added,
   modified_by =  AdjustmentHeader.modified_by,
  date_modified =  AdjustmentHeader.date_modified
from #invoices i , AdjustmentHeader 
where i.adjustment_id = AdjustmentHeader.adjustment_id

-- now update rev1 invoice amount from the REV 1 invoice
update #invoices
set rev1_total_amt_due = InvoiceHeader.total_amt_due 
from #invoices i, InvoiceHeader
where i.invoice_id = InvoiceHeader.invoice_id
and   InvoiceHeader.revision_id = 1

-- Use the latest revision invoice to update the following invoice information
update #invoices
set customer_po =  ih.customer_po,   
    customer_release =  ih.customer_release,   
    attention_name =  ih.attention_name,   
    attention_phone =  ih.attention_phone,   
    max_rev_total_amt_due =  ih.total_amt_due,   
    max_rev_status = ih.status,
    terms_code = ih.terms_code,
    due_date =  ih.due_date
from #invoices i, InvoiceHeader ih
where i.invoice_id = ih.invoice_id
and   ih.revision_id = (SELECT Max(revision_id) FROM InvoiceHeader ih2 WHERE ih2.invoice_id = ih.invoice_id GROUP BY invoice_id)

-- now update the status 

-- for now ignore export_required for now
--insert #export
--select d.adjustment_id , d.invoice_id, Max(d.export_required) from AdjustmentDetail d, #invoices i
--where d.export_required is not null and d.export_required <> 'N'
--and i.adjustment_id = d.adjustment_id
--and i.invoice_id = d.invoice_id
--group by d.adjustment_id,d.invoice_id

-- Because we are returning detail records status is loaded straight up from AdjustmentDetail
-- insert #export
-- select d.adjustment_id , d.invoice_id, Max(d.export_required) 
-- from AdjustmentDetail d, #invoices i
-- where i.adjustment_id = d.adjustment_id
-- and i.invoice_id = d.invoice_id
-- group by d.adjustment_id,d.invoice_id
-- 
-- if @debug = 1
-- begin
-- 	select * from #export
-- end
-- 
-- update #invoices
-- set export_status = e.export_status
-- from #invoices i, #export e
-- where i.adjustment_id = e.adjustment_id
-- and i.invoice_id = e.invoice_id

-- get the customer info and format the address.  Should only need to act upon a single customer.
--  Could have multiple customers in the temp table for which we only want to process
--  each customer a single time.
DECLARE Customer_Cursor CURSOR FOR
SELECT DISTINCT customer_id FROM #invoices
OPEN Customer_Cursor
--	prime the pump
FETCH NEXT FROM Customer_Cursor INTO @customer_id

--	loop through and process all customers
WHILE @@FETCH_STATUS = 0
BEGIN
	-- Get the customer address from the customer table so it can be formatted properly
	SELECT	@addr1 = c.bill_to_addr1,
		@addr2 = c.bill_to_addr2,
		@addr3 = c.bill_to_addr3,
		@addr4 = c.bill_to_addr4,
		@addr5 = c.bill_to_addr5,
		@city = c.bill_to_city,
		@state = c.bill_to_state,
		@zipcode = c.bill_to_zip_code,
		@country = c.bill_to_country,
		@cust_name = c.bill_to_cust_name
	FROM Customer c
	WHERE c.customer_id = @customer_id

	-- use the stored procedure to get the address fields formatted for printing
	execute sp_format_address 	@addr1 = @addr1,
					@addr2 = @addr2,
					@addr3 = @addr3,
					@addr4 = @addr4,
					@addr5 = @addr5,
					@city = @city,
					@state = @state,
					@zipcode = @zipcode,
					@country = @country,
                                                
					@ot_addr1 = @ot_addr1 out,
					@ot_addr2 = @ot_addr2 out,
					@ot_addr3 = @ot_addr3 out,
					@ot_addr4 = @ot_addr4 out,
					@ot_addr5 = @ot_addr5 out 

	if @debug = 1
	begin
	    select @addr1 as addr1,
		@addr2 as addr2,
		@addr3 as addr3,
	        @addr4 as addr4,
		@addr5 as addr5,
	        @city as city,
	        @state  as state,
	        @zipcode as zipcode,
	        @country as country,
	        @ot_addr1 as otaddr1,
		@ot_addr2 as otaddr2,
		@ot_addr3 as otaddr3,
		@ot_addr4 as otaddr4,
		@ot_addr5 as otaddr5,
	        @cust_name as custname
	end

	-- update the table with the formatted address for this customer
	UPDATE #invoices
	SET addr1 = @ot_addr1,
	    addr2 = @ot_addr2,
	    addr3 = @ot_addr3,
	    addr4 = @ot_addr4,
	    addr5 = @ot_addr5,
	    city  = @city,
	    state = @state,
	    zip_code = @zipcode,
	    country = @country,
	    cust_name = @cust_name
	FROM #invoices
	WHERE customer_id = @customer_id
	
   --  Get the next customer from the temp file, if any
   FETCH NEXT FROM Customer_Cursor INTO @customer_id
END

CLOSE Customer_Cursor
DEALLOCATE Customer_Cursor

-- reset the memo comment if the comment is not to print
--  If the user didn't specify a memo comment at the time the adjustment
--  was created then we won't print anything on the customer statement either.
--update #invoices
--set memo_comments = 'Invoice Adjustment'
--where isnull(print_memo_comments,'F') = 'F'

-- now select off the keep records

if @debug = 1
begin

	select * from #invoices
	
end

select adjustment_id,   
         invoice_id ,   
         company_id ,
         profit_ctr_id ,
         trans_source ,
         receipt_id ,
         line_id ,
         price_id ,
         unsubmitted_billing ,
         adj_amt ,   
         adj_date ,   
         hdr_adj_amt ,   
         memo_comments ,   
         print_memo_comments ,   
         hdr_added_by ,   
         hdr_date_added ,   
         invoice_code ,   
         invoice_date ,   
         customer_id ,   
         cust_name ,   
         addr1 ,   
         addr2 ,   
         addr3 ,   
         addr4 ,   
         addr5 ,   
         city ,   
         state ,   
         zip_code ,
         country,   
         customer_po ,   
         customer_release ,   
         attention_name ,   
         attention_phone ,   
         rev1_total_amt_due ,   
         max_rev_total_amt_due ,   
         max_rev_status ,
         adj_comments ,
         terms_code ,
         due_date,
	 added_by ,
         date_added ,
         modified_by ,
         date_modified ,
         export_status
from #invoices 
order by cust_name, customer_id, invoice_code, adjustment_id, company_id, profit_ctr_id, trans_source, receipt_id, line_id, price_id

GO


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_print_adjustment_memo_list] TO [EQAI]
    AS [dbo];

