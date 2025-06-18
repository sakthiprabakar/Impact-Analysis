CREATE OR ALTER PROCEDURE sp_print_result
	@error INT,				   -- @@error
    @ObjectName NVARCHAR(100), -- sp_name, trg_name, fun_name, table_name so on
	@ObjectType NVARCHAR(100), -- TABLE, PROCEDURE, FUNCTION, TRIGGER, VIEW 
    @ActionName NVARCHAR(100), -- CREATE, ALTER, GRANT, DROP
    @ColumnName NVARCHAR(100)  -- @ColumnName is required if alter or add column for TABLE object type
								-- Provide @ColumnName = '' if Not add or alter column.
AS  
/***********************************************************************************
sp_print_result
Loads to : PLT_AI  
Modifications:  
03/26/2025 Umesh Rally US145986 - Created  
  
-- For Checking if the trigger was created successfully
EXECUTE sp_print_result @@error,'TRG_Access_Audit_Insert', 'TRIGGER', 'CREATE', ''
***********************************************************************************/  

BEGIN
	-- For Create Trigger
	IF UPPER(@ObjectType) = 'TRIGGER' AND UPPER(@ActionName) = 'CREATE'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Trigger '+@ObjectName+' Created.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Trigger '+@ObjectName+' Creation got Failed.';
		END
	END
	-- For Alter Trigger
	IF UPPER(@ObjectType) = 'TRIGGER' AND UPPER(@ActionName) = 'ALTER'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Trigger '+@ObjectName+' Altered.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Trigger '+@ObjectName+' Alteration got Failed.';
		END
	END
	-- For Drop Trigger
	IF UPPER(@ObjectType) = 'TRIGGER' AND UPPER(@ActionName) = 'DROP'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Trigger '+@ObjectName+' Dropped.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Trigger '+@ObjectName+' Drop got Failed.';
		END
	END
	-- For Grant Trigger
	IF UPPER(@ObjectType) = 'TRIGGER' AND UPPER(@ActionName) = 'GRANT'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Trigger '+@ObjectName+' Granted.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Trigger '+@ObjectName+' Grant got Failed.';
		END
	END
	-- For Create Procedure
	IF (UPPER(@ObjectType) = 'PROCEDURE' OR UPPER(@ObjectType) = 'STORED PROCEDURE' OR UPPER(@ObjectType) = 'SP')
		AND UPPER(@ActionName) = 'CREATE'
	BEGIN		
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Stored Procedure '+@ObjectName+' is Created.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Stored Procedure '+@ObjectName+' Creation got Failed.';
		END
	END
	-- For Alter Procedure
	IF (UPPER(@ObjectType) = 'PROCEDURE' OR UPPER(@ObjectType) = 'STORED PROCEDURE' OR UPPER(@ObjectType) = 'SP')
		AND UPPER(@ActionName) = 'ALTER'
	BEGIN		
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Stored Procedure '+@ObjectName+' is Altered Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Stored Procedure '+@ObjectName+' Alteration got Failed.';
		END
	END
	-- For Drop Procedure
	IF (UPPER(@ObjectType) = 'PROCEDURE' OR UPPER(@ObjectType) = 'STORED PROCEDURE' OR UPPER(@ObjectType) = 'SP')
		AND UPPER(@ActionName) = 'DROP'
	BEGIN		
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Stored Procedure '+@ObjectName+' is Dropped Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Stored Procedure '+@ObjectName+' Drop got Failed.';
		END
	END
	-- For Grant Procedure
	IF (UPPER(@ObjectType) = 'PROCEDURE' OR UPPER(@ObjectType) = 'STORED PROCEDURE' OR UPPER(@ObjectType) = 'SP')
		AND UPPER(@ActionName) = 'GRANT'
	BEGIN		
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Stored Procedure '+@ObjectName+' is Granted.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Stored Procedure '+@ObjectName+' Grant got Failed.';
		END
	END
	-- For Create Function
	IF UPPER(@ObjectType) = 'FUNCTION' AND UPPER(@ActionName) = 'CREATE'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Function '+@ObjectName+' is Created.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Function '+@ObjectName+' Creation got Failed.';
		END
	END
	-- For Alter Function
	IF UPPER(@ObjectType) = 'FUNCTION' AND UPPER(@ActionName) = 'ALTER'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Function '+@ObjectName+' is Altered Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Function '+@ObjectName+' Alteration got Failed.';
		END
	END
	-- For Drop Function
	IF UPPER(@ObjectType) = 'FUNCTION' AND UPPER(@ActionName) = 'DROP'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Function '+@ObjectName+' is Dropped Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Function '+@ObjectName+' Drop got Failed.';
		END
	END
	-- For Grant Function
	IF UPPER(@ObjectType) = 'FUNCTION' AND UPPER(@ActionName) = 'GRANT'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Function '+@ObjectName+' is Granted.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Function '+@ObjectName+' Grant got Failed.';
		END
	END
	-- For Create Table
	IF UPPER(@ObjectType) = 'TABLE' AND UPPER(@ActionName) = 'CREATE'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - TABLE '+@ObjectName+' is Created.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - TABLE '+@ObjectName+' Creation got Failed.';
		END
	END
	-- For Alter Table
	IF UPPER(@ObjectType) = 'TABLE' AND @ColumnName = '' AND UPPER(@ActionName) = 'ALTER'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Table '+@ObjectName+' is Altered Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Table '+@ObjectName+' Alteration got Failed.';
		END
	END
	-- For Alter Table for a column
	IF UPPER(@ObjectType) = 'TABLE' AND @ColumnName <> '' AND UPPER(@ActionName) = 'ALTER'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Table '+@ObjectName+' is Altered Successfully for '+@ColumnName+'.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Table '+@ObjectName+' Alteration got Failed for '+@ColumnName+'.';
		END
	END
	-- For Drop Table
	IF UPPER(@ObjectType) = 'TABLE' AND UPPER(@ActionName) = 'DROP'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - Table '+@ObjectName+' is Dropped Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - Table '+@ObjectName+' Drop got Failed.';
		END
	END
	-- For Grant Table
	IF UPPER(@ObjectType) = 'TABLE' AND UPPER(@ActionName) = 'GRANT'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - TABLE '+@ObjectName+' is Granted.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - TABLE '+@ObjectName+' Grant got Failed.';
		END
	END
	--
	-- For Create View
	IF UPPER(@ObjectType) = 'VIEW' AND UPPER(@ActionName) = 'CREATE'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - VIEW '+@ObjectName+' is Created.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - VIEW '+@ObjectName+' Creation got Failed.';
		END
	END
	-- For Alter View
	IF UPPER(@ObjectType) = 'VIEW' AND @ColumnName = '' AND UPPER(@ActionName) = 'ALTER'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - VIEW '+@ObjectName+' is Altered Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - VIEW '+@ObjectName+' Alteration got Failed.';
		END
	END
	-- For Alter View for a column
	IF UPPER(@ObjectType) = 'VIEW' AND @ColumnName <> '' AND UPPER(@ActionName) = 'ALTER'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - VIEW '+@ObjectName+' is Altered Successfully for '+@ColumnName+'.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - VIEW '+@ObjectName+' Alteration got Failed for '+@ColumnName+'.';
		END
	END
	-- For Drop View
	IF UPPER(@ObjectType) = 'VIEW' AND UPPER(@ActionName) = 'DROP'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - VIEW '+@ObjectName+' is Dropped Successfully.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - VIEW '+@ObjectName+' Drop got Failed.';
		END
	END
	-- For Grant Table
	IF UPPER(@ObjectType) = 'VIEW' AND UPPER(@ActionName) = 'GRANT'
	BEGIN
		IF @error = 0
		BEGIN
			PRINT 'SUCCESS - VIEW '+@ObjectName+' is Granted.';
		END
		ELSE
		BEGIN
			PRINT 'FAILED - VIEW '+@ObjectName+' Grant got Failed.';
		END
	END
END