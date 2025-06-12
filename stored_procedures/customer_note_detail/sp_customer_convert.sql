CREATE PROCEDURE sp_customer_convert
	@debug int, 
	@prospect_ID int,
	@customer_id int,
	@convert_rc int		OUTPUT
AS
/***************************************************************************************************
The purpose of this SP is to convert a prospect into a customer using a controlled transaction

LOAD TO PLT_AI, PLT_AI_DEV, PLT_AI_TEST

09/26/2003 SCC	Created
11/15/2004 JPB  Changed CustomerContact -> Contact
03/23/2006 MK   Modified to delete the CustomerXCompany record rather than modify it (customer does not use company 0)
05/06/06   RG   Modified for contactxref
04/23/2007 SCC	Central Invoicing changes
08/25/2014 JPB	Updated to include all tables that currently contain prospect id information
				Commented out the CustomerTree tables

sp_customer_convert 1, 75, 90000006, 0
sp_customer_convert 1, 90015111, 15730, 0
	
SELECT * FROM CustomerAudit where before_value = '90015111' 
***************************************************************************************************/
-- Control the conversion
BEGIN TRANSACTION CONVERT_TO_CUSTOMER

-- Track affected tables so we can create audits at the end
create table #Audit (
	table_name		varchar(60)
	, column_name		varchar(60)
)

-- Customer table
UPDATE Customer 
SET customer_ID = @customer_ID, 
    cust_prospect_flag = 'C' 
WHERE customer_ID = @prospect_ID

SET @convert_rc = @@ERROR
IF @debug = 1 AND @convert_rc <> 0
	Print 'Error converting Customer Table: ' + convert(varchar(10), @convert_rc)

IF @convert_rc = 0
	INSERT #Audit values ('Customer', 'customer_id')


-- ContactXRef table
IF @convert_rc = 0 
BEGIN
	UPDATE ContactXRef 
           SET customer_ID = @customer_ID 
         WHERE customer_ID = @prospect_ID
           and type = 'C'
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting ContactXRef Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('ContactXRef', 'customer_id')
		
END

-- Note table
IF @convert_rc = 0 
BEGIN
	UPDATE Note 
           SET customer_ID = @customer_ID 
         WHERE customer_ID = @prospect_ID

	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting Note Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('Note', 'customer_id')
		
END

/*

-- CustomerTree table
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerTree SET customer_ID = @customer_ID WHERE customer_ID = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerTree Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerTree', 'customer_id')
		
END

-- CustomerTreeWork table
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerTreeWork SET customer_ID = @customer_ID WHERE customer_ID = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerTreeWork Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerTreeWork', 'customer_id')
		
END

*/

-- Customer Parent reference
IF @convert_rc = 0 
BEGIN
	UPDATE Customer SET cust_parent_ID = @customer_ID WHERE cust_parent_ID = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting Customer Parent Reference: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('Customer', 'cust_parent_ID')
		
END

-- MerchandiseLoad table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE MerchandiseLoad SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting MerchandiseLoad Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('MerchandiseLoad', 'customer_id')
		
END

-- OppNote table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE OppNote SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting OppNote Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('OppNote', 'customer_id')
		
END

-- FormWCR table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE FormWCR SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting FormWCR Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('FormWCR', 'customer_id')
		
END

-- CustomerNoteDetail table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerNoteDetail SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerNoteDetail Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerNoteDetail', 'customer_id')
		
END

-- work_CustomerSearch table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE work_CustomerSearch SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting work_CustomerSearch Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('work_CustomerSearch', 'customer_id')
		
END

-- CustomerGeneratorAssigned table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerGeneratorAssigned SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerGeneratorAssigned Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerGeneratorAssigned', 'customer_id')
		
END

-- OppNoteXEQContact table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE OppNoteXEQContact SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting OppNoteXEQContact Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('OppNoteXEQContact', 'customer_id')
		
END

-- CustomerBillingDocument table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerBillingDocument SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerBillingDocument Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerBillingDocument', 'customer_id')
		
END

-- CustomerFunnel table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerFunnel SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerFunnel Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerFunnel', 'customer_id')
		
END

-- CustomerXCompany table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerXCompany SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerXCompany Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerXCompany', 'customer_id')
		
END

-- CustomerAudit table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE CustomerAudit SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting CustomerAudit Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('CustomerAudit', 'customer_id')
		
END

-- Opp table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE Opp SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting Opp Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('Opp', 'customer_id')
		
END

-- CustomerBilling table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	IF not exists (select 1 from CustomerBilling where customer_id = @customer_ID) BEGIN
		UPDATE CustomerBilling SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
		SET @convert_rc = @@ERROR
		IF @debug = 1 AND @convert_rc <> 0
			Print 'Error converting CustomerBilling Table: ' + convert(varchar(10), @convert_rc)
	END
	
	IF @convert_rc = 0
		INSERT #Audit values ('CustomerBilling', 'customer_id')
		
END

-- ProfileQuoteHeader table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE ProfileQuoteHeader SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting ProfileQuoteHeader Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('ProfileQuoteHeader', 'customer_id')
		
END

-- FormLDR table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE FormLDR SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting FormLDR Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('FormLDR', 'customer_id')
		
END

-- WorkOrderQuoteHeader table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE WorkOrderQuoteHeader SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting WorkOrderQuoteHeader Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('WorkOrderQuoteHeader', 'customer_id')
		
END

-- Profile table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE Profile SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting Profile Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('Profile', 'customer_id')
		
END

-- Link table (8/25/2014)
IF @convert_rc = 0 
BEGIN
	UPDATE Link SET customer_id = @customer_ID WHERE customer_id = @prospect_ID
	SET @convert_rc = @@ERROR
	IF @debug = 1 AND @convert_rc <> 0
		Print 'Error converting Link Table: ' + convert(varchar(10), @convert_rc)

	IF @convert_rc = 0
		INSERT #Audit values ('Link', 'customer_id')
		
END



-- Adding an Audit (8/25/2014)
IF @convert_rc = 0 
BEGIN
	declare @sysuser varchar(256) = system_user
	set @sysuser = replace(@sysuser, '(2)', '')
	INSERT CustomerAudit (customer_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified, rowguid)
	select @customer_id, a.table_name, a.column_name, convert(varchar(20), @prospect_id), convert(varchar(20), @customer_id), 'sp_customer_convert', left(@sysuser, 10), null, getdate(), newid()
	from #audit a
END

-- Commit or Rollback
IF @convert_rc = 0
	COMMIT TRANSACTION CONVERT_TO_CUSTOMER
else
	ROLLBACK TRANSACTION CONVERT_TO_CUSTOMER

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_convert] TO [EQAI]
    AS [dbo];

