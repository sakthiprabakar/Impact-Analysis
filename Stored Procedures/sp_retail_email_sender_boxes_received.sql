CREATE PROCEDURE sp_retail_email_sender_boxes_received 
AS
/***************************************************************
Loads to:	Plt_AI

Calls sp_retail_email_boxes_received for all email addresses that have boxes that need emails.

05/21/2008 JPB	Created
03/17/2009 RJG	Modified to separate out emails by LOCATION rather than ORDER
				It will grab a CSV list of orders for a given location and pass it to the proc that queues up emails

select top 5 * from message order by message_id desc
delete from message where message_id > 254

sp_retail_email_sender_boxes_received
****************************************************************/
SET NOCOUNT On

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
	@debugging_level	int -- 0 for off, 1 or higher for different debug options


DECLARE @date_retrieval_window int
set @date_retrieval_window = -7 -- negative number.  amount of DAYS in the past to scan for emails that should be sent out.  Usually 7

-- Abort if they're already processed, or none to process
if not exists (
   select distinct
   oh.email
   from orderheader oh
   inner join orderdetail od on oh.order_id = od.order_id
   inner join orderitem oi on od.order_id = oi.order_id and od.line_id = oi.line_id
   inner join product p on od.product_id = p.product_id and od.company_id = p.company_id and od.profit_ctr_id = p.profit_ctr_id
   where oi.date_returned is not null
   and oi.date_return_ack_sent is null
   and oh.send_email_flag = 'Y'
   and dateadd(dd, @date_retrieval_window, getdate()) < oi.date_returned
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
	   from orderheader oh
   inner join orderdetail od on oh.order_id = od.order_id
   inner join orderitem oi on od.order_id = oi.order_id and od.line_id = oi.line_id
   inner join product p on od.product_id = p.product_id and od.company_id = p.company_id and od.profit_ctr_id = p.profit_ctr_id
   where oi.date_returned is not null
   and oi.date_return_ack_sent is null
   and oh.send_email_flag = 'Y'
   and dateadd(dd, @date_retrieval_window, getdate()) < oi.date_returned
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
			exec sp_retail_email_boxes_received 0, @email, @order_ids_csv
			--print 'sp_retail_email_boxes_received 0, ''' + @email + ''', ''' + @order_ids_csv + ''''
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
    ON OBJECT::[dbo].[sp_retail_email_sender_boxes_received] TO [EQAI]
    AS [dbo];

