
/* SQL-54615 - 09/24/2018 - AM - EQAI - Remove validation for phone number length in AX customer sync
      Now EQAI supports phone numbers up to 255 characters in length*/

create procedure sp_ax_sync_customer_validate
	@ax_customer_id varchar(20),
	@customer_group varchar(10),
	@customer_name varchar(100),
	@physical_address_1 varchar(250),
	@physical_address_2 varchar(250),
	@physical_address_3 varchar(250),
	@physical_address_4 varchar(250),
	@physical_city varchar(60),
	@physical_state varchar(10),
	@physical_zip_code varchar(10),
	@physical_country varchar(10),
	@billing_name varchar(60),
	@billing_address_1 varchar(250),
	@billing_address_2 varchar(250),
	@billing_address_3 varchar(250),
	@billing_address_4 varchar(250),
	@billing_city varchar(60),
	@billing_state varchar(10),
	@billing_zip_code varchar(10),
	@billing_country varchar(10),
	@phone_number varchar(250),
	@fax_number varchar(250),
	@credit_limit numeric(32,16),
	@terms_code varchar(10),
	@naics_code varchar(10),
	@naics_desc varchar(255),
	@customer_type varchar(20),
	@customer_website varchar(255),
	@invoice_customer_id varchar(20),
	@sub_customers varchar(max),
	@hold_status int
as
declare @msg varchar(max)

if not exists (select 1 from Customer where ax_customer_id = @ax_customer_id)
	goto END_OF_FUNCTION

if DATALENGTH(@customer_group) > 1
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Intercompany flag ''' + @customer_group + ''' cannot be greater than 1 character.'
/*
if DATALENGTH(@customer_name) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company name ''' + replace(@customer_name,'''','''''') + ''' cannot be greater than 40 characters.'
*/
if DATALENGTH(@physical_address_1) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company address line 1 ''' + replace(@physical_address_1,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@physical_address_2) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company address line 2 ''' + replace(@physical_address_2,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@physical_address_3) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company address line 3 ''' + replace(@physical_address_3,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@physical_address_4) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company address line 1 ''' + replace(@physical_address_4,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@physical_city) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company address city ''' + replace(@physical_city,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@physical_state) > 2
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Company address state ''' + replace(@physical_state,'''','''''') + ''' cannot be greater than 2 characters.'
/*
if DATALENGTH(@billing_name) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing name ''' + replace(@billing_name,'''','''''') + ''' cannot be greater than 40 characters.'
*/
if DATALENGTH(@billing_address_1) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing address line 1 ''' + replace(@billing_address_1,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@billing_address_2) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing address line 2 ''' + replace(@billing_address_2,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@billing_address_3) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing address line 3 ''' + replace(@billing_address_3,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@billing_address_4) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing address line 1 ''' + replace(@billing_address_4,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@billing_city) > 40
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing address city ''' + replace(@billing_city,'''','''''') + ''' cannot be greater than 40 characters.'

if DATALENGTH(@billing_state) > 2
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Billing address state ''' + replace(@billing_state,'''','''''') + ''' cannot be greater than 2 characters.'
/*
if DATALENGTH(@phone_number) > 10
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Phone number ''' + replace(@phone_number,'''','''''') + ''' cannot be greater than 10 characters.'
*/
if DATALENGTH(@fax_number) > 10
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Fax number ''' + replace(@fax_number,'''','''''') + ''' cannot be greater than 10 characters.'

if DATALENGTH(@terms_code) > 8
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Terms code ''' + replace(@terms_code,'''','''''') + ''' cannot be greater than 8 characters.'

if DATALENGTH(@customer_type) > 20
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Customer type ''' + replace(@customer_type,'''','''''') + ''' cannot be greater than 20 characters.'

if DATALENGTH(@customer_website) > 50
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Customer website ''' + replace(@customer_website,'''','''''') + ''' cannot be greater than 50 characters.'

if isnull(@hold_status,0) not between 0 and 5
	set @msg = coalesce(@msg,'') + CHAR(13) + CHAR(10)
			+ 'Hold status ''' + convert(varchar(10),isnull(@hold_status,0)) + ''' must be between 0 and 5.'

if DATALENGTH(coalesce(@msg,'')) > 0
	set @msg = 'AX Customer ''' + @ax_customer_id + ''' has data that failed validation:' + @msg
			+ CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) + 'EQAI was not updated. Please make corrections in AX.'

END_OF_FUNCTION:
select coalesce(@msg,'') as validation_errors
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_sync_customer_validate] TO [AX_SERVICE]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_sync_customer_validate] TO [EQAI]
    AS [dbo];

