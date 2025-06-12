Create Procedure eqsp_CustomerAudit (
	@customer_id      	int,
	@table_name			varchar(40),
	@column_name		varchar(40),
	@before_value		varchar(255),
	@after_value		varchar(255),
	@audit_reference	varchar(255),
	@modified_from		varchar(10),
	@user_code         	varchar(10)
)
AS
/************************************************************
Procedure    : eqsp_CustomerAudit
Database     : PLT_AI*
Description  : Compares a before & after value as strings.
	If they're the same, sp exits
	if they're different, sp creates a customeraudit record
	then exits.

03/17/2008 - JPB - Created

Execute this block to test/see it work:
select * from customeraudit where customer_id = 888888 order by date_modified desc

declare @res int
exec @res = eqsp_CustomerAudit 888888, 'Customer', 'cust_addr3', NULL, '1', 'customer_id: 888888', 'WEB', 'Jonathan'
select @res

select * from customeraudit where customer_id = 888888 order by date_modified desc
************************************************************/
	set nocount on

	if @customer_id is null return 0
	if @before_value is null set @before_value = '(blank)'
	if @after_value is null set @after_value = '(blank)'
	if @before_value = '(blank)' and @after_value = '(blank)' return 0
	
	insert customeraudit (
		customer_id, 
		table_name, 
		column_name, 
		before_value, 
		after_value, 
		audit_reference, 
		modified_by, 
		modified_from, 
		date_modified
	) values (
		@customer_id,
		@table_name,
		@column_name,
		@before_value,
		@after_value,
		@audit_reference,
		@user_code,
		@modified_from,
		getdate()
	)
	
	return 1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[eqsp_CustomerAudit] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[eqsp_CustomerAudit] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[eqsp_CustomerAudit] TO [EQAI]
    AS [dbo];

