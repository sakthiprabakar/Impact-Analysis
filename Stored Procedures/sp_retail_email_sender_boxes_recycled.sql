CREATE PROCEDURE sp_retail_email_sender_boxes_recycled 
AS
/***************************************************************
Loads to:	Plt_AI

Calls sp_retail_email_boxes_recycled for all email addresses that have boxes that need emails.

05/21/2008 JPB	Created
sp_retail_email_sender_boxes_recycled

select top 5 * from message order by message_id desc
delete from message where message_id > 254

**** WAITING ON GEM:9649 for fields in Outbound
We do not need an additional field on the outbound receipt, we added a document type of COR.  
If it is present on an outbound of Retail orders we will send the COR (EQ text not this image) to the customers.
Source is not required either - just add two datawindows to select items assigned to this receipt.

The only open issue is the selection of items to assign to the outbound and to update the 
outbound fields on the order item table.  Outbound receipt, outbound line and outbound date.

03/17/2009 - RJG - Modified to separate out emails by LOCATION rather than ORDER

04/17/2009 - RJG - Added testing code / code for setting up test data

06/02/2009 - RJG - Updated debug code.  It should not send out emails if in debug mode

-- Examples:
exec sp_retail_email_boxes_recycled 1, 'rgrenwick+EQCUST@gmail.com', '1191'
 

/*  RESETTING RECORDS FOR TESTING
-- this query will give you order ids that may need to be reset
	select DISTINCT
	   oi.order_id,
	   oh.email
	from OrderHeader oh
	inner join OrderItem oi
		on oi.order_id = oh.order_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
	inner join product p 
		on od.product_id = p.product_id 
		and od.company_id = p.company_id 
		and od.profit_ctr_id = p.profit_ctr_id
	where 1=1
		--oi.outbound_receipt_id is not null
		--and oi.date_cor_sent is null
		and od.cor_flag = 'T'  
		and exists (
			select s.image_id 
				from Plt_Image..Scan s 
				inner join Plt_Image..ScanDocumentType sdt 
					on s.type_id = sdt.type_id
					and sdt.document_Type = 'COR' 
				inner join Receipt r
					on s.receipt_id = r.receipt_id
					and s.company_id = r.company_id
					and s.profit_ctr_id = r.profit_ctr_id
					and r.trans_mode = 'O'
				where
					s.receipt_id = oi.outbound_receipt_id
					and s.company_id = od.company_id
					and s.profit_ctr_id = od.profit_ctr_id
					and s.document_source = 'receipt'
					and s.status = 'A'
		)

-- this query will reset the order item record for the given order id
-- this record must have an outbound receipt id and a receipt record in 
-- the plt_image scan table
UPDATE OrderItem SET date_cor_sent = NULL WHERE order_id = [my order id to reset]


*/

****************************************************************/
DECLARE 
	@email      varchar(60),
	@order_id_list varchar(8000),
	@order_id	int,
	@ship_customer_name	varchar(100),
	@ship_address1		varchar(100),
	@ship_address2		varchar(100),
	@ship_address3		varchar(100),
	@ship_address4		varchar(100),
	@ship_address5		varchar(100),
	@ship_city			varchar(100),
	@ship_state			varchar(50),
	@ship_zip_code		varchar(50),
	@order_ids_csv nvarchar(3000),
	@debugging_level	int  = 0 -- 0 for off, 1 or higher for different debug options

SET NOCOUNT ON

-- Abort if they're already processed, or none to process
if not exists (
	select distinct
		oh.email
	from OrderHeader oh
	inner join OrderItem oi
		on oi.order_id = oh.order_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
	inner join Plt_Image..Scan s 
		on oi.outbound_receipt_id = s.receipt_id
		and od.company_id = s.company_id
		and od.profit_ctr_id = s.profit_ctr_id
		and s.document_source = 'receipt'
		and s.status = 'A'
	inner join Plt_Image..ScanDocumentType sdt 
		on s.type_id = sdt.type_id
		and sdt.document_Type = 'COR' 
	inner join Receipt r
		on s.receipt_id = r.receipt_id
		and s.company_id = r.company_id
		and s.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'O'
	where
		oi.outbound_receipt_id is not null
		and oi.date_cor_sent is null
		and od.cor_flag = 'T'
) return

DECLARE @tbl_work table (
	order_id int,
	email varchar(100),
	ship_cust_name varchar(100),
	ship_addr1 varchar(100),
	ship_addr2 varchar(100),
	ship_addr3 varchar(100),
	ship_addr4 varchar(100),
	ship_addr5 varchar(100),
	ship_city varchar(50) ,
	ship_state  varchar(50),
	ship_zip_code  varchar(50)
)

INSERT INTO @tbl_work
	select
	   oi.order_id,
	   oh.email,
	   oh.ship_cust_name,
	   oh.ship_addr1,
	   oh.ship_addr2,
	   oh.ship_addr3,
	   oh.ship_addr4,
	   oh.ship_addr5,
	   oh.ship_city,
	   oh.ship_state,
	   oh.ship_zip_code
	from OrderHeader oh
	inner join OrderItem oi
		on oi.order_id = oh.order_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
	inner join product p 
		on od.product_id = p.product_id 
		and od.company_id = p.company_id 
		and od.profit_ctr_id = p.profit_ctr_id
	where
		oi.outbound_receipt_id is not null
		and oi.date_cor_sent is null
		and od.cor_flag = 'T'  
		and exists (
			select s.image_id 
				from Plt_Image..Scan s 
				inner join Plt_Image..ScanDocumentType sdt 
					on s.type_id = sdt.type_id
					and sdt.document_Type = 'COR' 
				inner join Receipt r
					on s.receipt_id = r.receipt_id
					and s.company_id = r.company_id
					and s.profit_ctr_id = r.profit_ctr_id
					and r.trans_mode = 'O'
				where
					s.receipt_id = oi.outbound_receipt_id
					and s.company_id = od.company_id
					and s.profit_ctr_id = od.profit_ctr_id
					and s.document_source = 'receipt'
					and s.status = 'A'
		)
	group by 
		p.product_id,
		p.description,
		oh.email,
		oi.order_id,
		oh.ship_cust_name,
		oh.ship_addr1,
		oh.ship_addr2,
		oh.ship_addr3,
		oh.ship_addr4,
		oh.ship_addr5,
		oh.ship_city,
		oh.ship_state,
		oh.ship_zip_code




DECLARE cur_order_addresses CURSOR FOR 
	SELECT 	
		order_id,
	    email,
		ship_cust_name,
		ship_addr1 ,
		ship_addr2 ,
		ship_addr3 ,
		ship_addr4 ,
		ship_addr5 ,
		ship_city ,
		ship_state,
		ship_zip_code  
	FROM @tbl_work
	ORDER BY order_id DESC

	   
OPEN cur_order_addresses

FETCH cur_order_addresses INTO 
	@order_id,
	@email,
	@ship_customer_name	,
	@ship_address1		,
	@ship_address2		,
	@ship_address3		,
	@ship_address4		,
	@ship_address5		,
	@ship_city			,
	@ship_state			,
	@ship_zip_code	

-- loop through each address
WHILE @@FETCH_STATUS = 0

BEGIN
	if @order_id IS NOT NULL
	BEGIN
		-- select out all of the order ids with matching addresses and create a CSV out of them
		Select @order_ids_csv = NULL
		SELECT @order_ids_csv = Coalesce(@order_ids_csv + ',', '') + cast(order_id as varchar(20))
		from 
			(
				SELECT 
					DISTINCT order_id
				FROM @tbl_work
				WHERE
					ship_cust_name = @ship_customer_name
					AND isnull(ship_addr1, '') = isnull(@ship_address1, '')
					AND isnull(ship_addr2, '') = isnull(@ship_address2, '')
					AND isnull(ship_addr3, '') = isnull(@ship_address3, '')
					AND isnull(ship_addr4, '') = isnull(@ship_address4, '')
					AND isnull(ship_addr5, '') = isnull(@ship_address5, '')
					AND ship_city = @ship_city
					AND ship_state = @ship_state
					AND ship_zip_code = @ship_zip_code
			) distinct_order_ids

		-- remove order ids with the same address from the work table
		DELETE FROM @tbl_work WHERE
					ship_cust_name = @ship_customer_name
					AND isnull(ship_addr1, '') = isnull(@ship_address1, '')
					AND isnull(ship_addr2, '') = isnull(@ship_address2, '')
					AND isnull(ship_addr3, '') = isnull(@ship_address3, '')
					AND isnull(ship_addr4, '') = isnull(@ship_address4, '')
					AND isnull(ship_addr5, '') = isnull(@ship_address5, '')
					AND ship_city = @ship_city
					AND ship_state = @ship_state
					AND ship_zip_code = @ship_zip_code

		
		
		IF LEN(@order_ids_csv) > 0
		BEGIN
			-- process order ids that were found
			if @debugging_level > 0
			begin
				print 'exec sp_retail_email_boxes_recycled ' + cast(@debugging_level as varchar(100)) + ', ''' + @email + ''', ''' + @order_ids_csv + ''''
			end	
			else
			begin
				
				SET @debugging_level = 0 -- off
				exec sp_retail_email_boxes_recycled @debugging_level, @email, @order_ids_csv			
			end
			 

		END

	END

	FETCH cur_order_addresses INTO 
		@order_id,
		@email,
		@ship_customer_name	,
		@ship_address1		,
		@ship_address2		,
		@ship_address3		,
		@ship_address4		,
		@ship_address5		,
		@ship_city			,
		@ship_state			,
		@ship_zip_code	
END

CLOSE cur_order_addresses
DEALLOCATE cur_order_addresses


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_retail_email_sender_boxes_recycled] TO [EQAI]
    AS [dbo];

