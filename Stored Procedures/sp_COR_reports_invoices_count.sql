-- drop PROCEDURE sp_COR_reports_invoices_count
go

CREATE PROCEDURE sp_COR_reports_invoices_count
	@web_userid		varchar(100) = ''
	, @start_date	datetime = null
	, @end_date		datetime = null
	, @search		varchar(max) = ''
	, @invoice_code		varchar(max)= ''	-- Invoice ID
	, @purchase_order	varchar(max) = ''
	, @adv_search	varchar(max) = ''
	, @manifest		varchar(max) = ''	-- Manifest list
	, @generator	varchar(max) = '' -- Generator Name/Store Number Search
	, @generator_site_code	varchar(max) = '' -- Generator Site Code / Store Number
	, @sort			varchar(20) = ''
	, @page			bigint = 1
	, @perpage		bigint = 20
	, @excel_output int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
AS
/* ***************************************************************************************************
sp_COR_reports_invoices_count:

Returns the data for Invoices.

LOAD TO PLT_AI* on NTSQL1

12/17/2018	JPB	Copy of sp_reports_invoices, modified for COR
07/31/2019	JPB	Added @generator input for searching by generator name/store number, also returning generator name/store num or "multiple" if more than 1 on a record.

exec [sp_COR_reports_invoices_count]
	@web_userid		= 'nyswyn100'
	, @start_date	= '1/1/2000'
	, @end_date		= '12/31/2018'
	, @search		= ''
	, @purchase_order = ''
	, @invoice_code = ''
	, @generator = '345'
	, @adv_search	= ''
	, @sort			= ''
	, @page			= 1
	, @perpage		= 2000
	

select * from invoiceheader where customer_id in (select customer_id from contactxref where contact_id =3682)

select * from invoicedetail where invoice_id = 1266040

1266039
1266040

sp_help invoicedetail
SELECT  *  FROM    invoicedetail where manifest = 'MI8282919'


*************************************************************************************************** */

-- 	declare	@web_userid		varchar(100) = 'Jamie.Huens@wal-mart.com'		
-- declare	@web_userid		varchar(100) = 'customer.demo@usecology.com'		
-- declare	@web_userid		varchar(100) = 'amoser@capitolenv.com'	, @start_date	datetime = '1/1/2000'		, @end_date		datetime = '12/1/2016'		, @search		varchar(max) = 'med'		, @sort			varchar(20) = 'Generator Name'		, @page			bigint = 1	, @perpage		bigint = 20, @purchase_order varchar(max) = '', @invoice_code varchar(max) = '120039664, 120051282', @adv_search varchar(max) = ''

-- Avoid query plan caching:
declare @i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_start_date	datetime = convert(date, isnull(@start_date, '1/1/1990'))
	, @i_end_date		datetime = convert(date, isnull(@end_date, getdate()))
	, @i_search		varchar(max) = isnull(@search, '')
	, @i_purchase_order	varchar(max) = isnull(@purchase_order, '')
	, @i_invoice_code varchar(max) = isnull(@invoice_code, '')
	, @i_adv_search	varchar(max) = isnull(@adv_search, '')
	, @i_manifest varchar(max) = isnull(@manifest, '')
	, @i_generator varchar(max) = isnull(@generator, '')
	, @i_generator_site_code varchar(max) = isnull(@generator_site_code, '')
	, @i_sort			varchar(20) = isnull(@sort, 'Invoice Number')
	, @i_page			bigint = isnull(@page, 1)
	, @i_perpage		bigint = isnull(@perpage, 20)
	, @i_customer_id_list varchar(max)= isnull(@customer_id_list, '')
    , @i_generator_id_list varchar(max)= isnull(@generator_id_list, '')

declare @out table (
	invoice_code	varchar(16),
	invoice_date	datetime,
	customer_id		int,
	cust_name		varchar(75),
	invoice_id		int,
	revision_id		int,
	invoice_image_id	int,
	attachment_image_id	int,
	total_amt_due	money,
	due_date		datetime,
	customer_po		varchar(20),
	customer_release	varchar(20),
	attention_name	varchar(40),
	generator_name	varchar(75),
	generator_site_code varchar(75),
	manifest		varchar(20),
	manifest_list	varchar(max),
	generator_name_list	varchar(max),
	generator_site_code_list varchar(max),
	currency_code char(3),
	manifest_image_list varchar(max),
	_row			bigint
)

insert @out
exec sp_cor_reports_invoices_list
	@web_userid		= @i_web_userid
	, @start_date	= @i_start_date
	, @end_date		= @i_end_date
	, @search		= @i_search
	, @invoice_code		= @i_invoice_code
	, @purchase_order	= @i_purchase_order
	, @adv_search	= @i_adv_search
	, @manifest		= @i_manifest
	, @generator	= @i_generator
	, @generator_site_code	= @i_generator_site_code
	, @sort			= @i_sort
	, @page			= 1
	, @perpage		= 999999999
	, @excel_output	= 0
	, @customer_id_list = @i_customer_id_list
    , @generator_id_list = @i_generator_id_list


select count(*) from @out

RETURN 0

GO

GRANT EXECUTE ON sp_COR_reports_invoices_count TO EQAI, EQWEB, COR_USER
GO
