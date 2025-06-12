
CREATE PROCEDURE sp_get_adjustment_memo 
	@where_clause varchar(1024), 
	@debug int = 0
AS
/***********************************************************************
This SP is called from w_invoice_processing to retrieve invoice records when the user
wishes to process invoices with pending adjustments.  A simple select won't return the
proper result set as there could be many revisions of an invoice with many adjustments.
SUMming and MAXing needs to be managed in order to get the proper result set.

This sp is loaded to Plt_AI.


sp_get_adjustment_memo 'and invoiceheader.customer_id = 537',1
08/02/2007 WAC	Created
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
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
@cust_id int,
@cust_name varchar(75)


create table #invoices (adjustment_id int null,   
         		company_id int null,   
         profit_ctr_id int null,   
         trans_source char(1) null,   
         receipt_id int null,   
         line_id int null,   
         price_id int null,   
         invoice_id int null,   
         export_required char(1) null,   
         adj_amt money null,   
         added_by varchar(10) null,   
         date_added datetime null,   
         adj_date datetime null,   
         hdr_adj_amt money null,   
         memo_comments varchar(255) null,   
         print_memo_comments char(1) null,   
         hdr_added_by varchar(10) null,   
         hdr_date_added datetime null,   
         ih_invoice_id int null,   
         revision_id int null,   
         invoice_status char(1) null,   
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
         country  varchar(40) null,		 
         customer_po varchar(20) null,   
         customer_release varchar(20) null,   
         attention_name varchar(40) null,   
         attention_phone varchar(30) null,   
         total_amt_due money null,   
         adj_comments varchar(255) null,
         terms_code varchar(8) null,
         due_date datetime null,
         keep_flag char(1) null )
    
--create table #lastinvoice( invoice_id int null, revision_id int null )

if @where_clause is null 
begin 
	set @where_clause = ''
end

--	Now select invoices that have pending adjustments
SET @execute_sql = 
'INSERT #Invoices 
 SELECT AdjustmentDetail.adjustment_id,   
         AdjustmentDetail.company_id,   
         AdjustmentDetail.profit_ctr_id,   
         AdjustmentDetail.trans_source,   
         AdjustmentDetail.receipt_id,   
         AdjustmentDetail.line_id,   
         AdjustmentDetail.price_id,   
         AdjustmentDetail.invoice_id,   
         AdjustmentDetail.export_required,   
         AdjustmentDetail.adj_amt,   
         AdjustmentDetail.added_by,   
         AdjustmentDetail.date_added,   
         AdjustmentHeader.adj_date,   
         AdjustmentHeader.adj_amt,   
         AdjustmentHeader.memo_comments,   
         AdjustmentHeader.print_memo_comments,   
         AdjustmentHeader.added_by,   
         AdjustmentHeader.date_added,   
         InvoiceHeader.invoice_id,   
         InvoiceHeader.revision_id,   
         InvoiceHeader.status,   
         InvoiceHeader.invoice_code,   
         InvoiceHeader.invoice_date,   
         InvoiceHeader.customer_id,   
         null,   
         null,   
         null,   
         null,   
         null,   
         null,   
         null,   
         null,   
         null, 
         null,		 
         InvoiceHeader.customer_po,   
         InvoiceHeader.customer_release,   
         InvoiceHeader.attention_name,   
         InvoiceHeader.attention_phone,   
         InvoiceHeader.total_amt_due,   
         AdjustmentHeader.adj_comments,
         InvoiceHeader.terms_code,
         InvoiceHeader.due_date,
         ''T'' 
    FROM AdjustmentDetail,   
         AdjustmentHeader,   
         InvoiceHeader
   WHERE ( AdjustmentDetail.adjustment_id = AdjustmentHeader.adjustment_id ) and  
         ( AdjustmentDetail.invoice_id = InvoiceHeader.invoice_id ) and
         ( InvoiceHeader.revision_id = 1 )		 
    ' + @where_clause

IF @debug = 1 PRINT CONVERT(varchar(30), GETDATE(), 14) + @execute_sql
EXEC (@execute_sql)

-- now find the most recent invoices 

--insert #lastinvoice
--select  invoice_id, max(revision_id) from #invoices
--group by invoice_id

-- update the invoices table
--update #invoices 
--set keep_flag = 'T'
--from #invoices i , #lastinvoice l
--where i.invoice_id = l.invoice_id
--and i.revision_id = l.revision_id

-- now select off the keep records

-- get teh customer info and format it

select @cust_id = max(customer_id) from #invoices

select @addr1 = c.bill_to_addr1,
	@addr2 = c.bill_to_addr2,
	@addr3 = c.bill_to_addr3,
	@addr4 = c.bill_to_addr4,
	@addr5 = c.bill_to_addr5,
	@city = c.bill_to_city,
	@state = c.bill_to_state,
	@zipcode = c.bill_to_zip_code,
	@country = c.bill_to_country,
        @cust_name = c.bill_to_cust_name
from Customer c
where c.customer_id = @cust_id

execute sp_format_address @addr1 = @addr1,
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

-- now updat ethe table with the formatted address
update #invoices
set addr1 = @ot_addr1,
    addr2 = @ot_addr2,
    addr3 = @ot_addr3,
    addr4 = @ot_addr4,
    addr5 = @ot_addr5,
    city  = @city,
    state = @state,
    zip_code = @zipcode,
    country = @country,
    cust_name = @cust_name


if @debug = 1
begin

	select * from #invoices
--	select * from #lastinvoice
end

select adjustment_id,   
         company_id,   
         profit_ctr_id ,   
         trans_source ,   
         receipt_id ,   
         line_id ,   
         price_id ,   
         invoice_id ,   
         export_required ,   
         adj_amt ,   
         added_by ,   
         date_added ,   
         adj_date ,   
         hdr_adj_amt ,   
         memo_comments ,   
         print_memo_comments ,   
         hdr_added_by ,   
         hdr_date_added ,   
         ih_invoice_id ,   
         revision_id ,   
         invoice_status ,   
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
         total_amt_due ,   
         adj_comments ,
         terms_code ,
         due_date 
from #invoices 
where keep_flag = 'T' 
order by invoice_code, adjustment_id, company_id, profit_ctr_id, receipt_id



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_adjustment_memo] TO [EQAI]
    AS [dbo];

