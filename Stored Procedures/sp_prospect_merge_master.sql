
CREATE PROCEDURE sp_prospect_merge_master
	@debug int, 
	@prospect_ID int,
	@customer_ID int,
	@connect_type varchar(10),
	@merge_rc int OUTPUT
AS
/***************************************************************************************************
The purpose of this SP is to merge a duplicate prospect INTO the customer record the user wants to keep
the prospect id is the source and the customer id is the target of the merge

LOAD TO PLT_AI, PLT_AI_DEV, PLT_AI_TEST

02/03/2006 MK	created based on sp_contact_merge_master
05/06/06   rg   modfied for contactxref and note
05/02/2007 rg   changed for central invoicing 
10/04/2007 WAC	Renamed EQAIConnect to EQConnect

sp_prospect_merge_master 1, 90002823, 777888, 'DEV', 0
***************************************************************************************************/
DECLARE @contact_id int,
	@database varchar(30),
	@db_count int,
	@no_db_count int,
	@pos int,
	@process_count int,
	@execute_sql varchar(8000),
	@server varchar(10),
	@server_avail varchar(3),
	@submerge_rc int,
	@xref_exists int,
	@err_msg varchar(255)

-- Create a temp table to hold the databases
SELECT company_id, db_name_eqai, 0 as process_flag INTO #tmp_database FROM EQConnect WHERE db_type = @connect_type

-- Control the merge
BEGIN TRANSACTION MERGE_TO_CUSTOMER

	-------------------------------------
	-- ContactXRef table
	-------------------------------------
	-- Check to see if a cross reference record already exists for this contact, per customer
	SELECT customer_ID, contact_ID, 0 as process_flag INTO #tmp_custXcontact 
		FROM ContactXRef WHERE customer_ID = @prospect_ID
                AND type = 'C'
	SELECT @process_count = count(*) FROM #tmp_custXcontact
	SET @merge_rc = 0
	SET ROWCOUNT 1
	WHILE @process_count > 0 AND @merge_rc = 0
	BEGIN
		SELECT @contact_id = contact_ID FROM #tmp_custXcontact WHERE process_flag = 0
		SELECT @xref_exists = count(*) FROM ContactXRef 
                                     WHERE contact_ID = @contact_id 
                                       AND customer_ID = @customer_ID
                                       AND type = 'C'
		IF @xref_exists > 0 
		BEGIN
			-- Remove the merge contact's record
			DELETE FROM ContactXRef 
                              WHERE contact_ID = @contact_id 
                                AND customer_ID = @prospect_ID
                                AND type = 'C'
			SET @merge_rc = @@ERROR
			IF @merge_rc <> 0
                           begin 
				select @err_msg ='Error deleting ContactXRef record: ' + convert(varchar(10), @merge_rc)
                                raiserror (@err_msg,16,1)
                                if @debug = 1 print @err_msg
                           end
		END
		ELSE
		BEGIN
			if exists ( select 1 from ContactXRef where customer_id = @customer_id 
                                    and type = 'C' and primary_contact = 'T' )
                         begin
				-- Change contact ID to merge ID
				UPDATE ContactXRef 
	                           SET customer_ID = @customer_ID,
                                       primary_contact = 'F' 
	                         WHERE contact_ID = @contact_id 
	                           AND customer_ID = @prospect_ID
	                           AND type = 'C'
				SET @merge_rc = @@ERROR
				IF @merge_rc <> 0
	                           begin
					select @err_msg ='Error updating ContactXRef record: ' + convert(varchar(10), @merge_rc)
	                                raiserror(@err_msg,16,1)
	                                if @debug = 1 print @err_msg
	                           end
			end
                        else
                        begin
				-- Change contact ID to merge ID
				UPDATE ContactXRef 
	                           SET customer_ID = @customer_ID 
	                         WHERE contact_ID = @contact_id 
	                           AND customer_ID = @prospect_ID
	                           AND type = 'C'
				SET @merge_rc = @@ERROR
				IF @merge_rc <> 0
	                           begin
					select @err_msg ='Error updating ContactXRef record: ' + convert(varchar(10), @merge_rc)
	                                raiserror(@err_msg,16,1)
	                                if @debug = 1 print @err_msg
	                           end
                        end
		END
		UPDATE #tmp_custXcontact SET process_flag = 1 WHERE process_flag = 0
		SELECT @process_count = @process_count - 1
	END 
	SET ROWCOUNT 0

	-------------------------------------
	-- CustomerXCompany table
	-------------------------------------
	-- is no more


	-------------------------------------
	-- CustomerNote table
	-------------------------------------
	IF @merge_rc = 0
	BEGIN
	UPDATE Note 
           SET customer_ID = @customer_ID 
          WHERE customer_ID IS NOT NULL 
            AND customer_ID = @prospect_ID
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
            begin
		select @err_msg ='Error updating Customer Note record: ' + convert(varchar(10), @merge_rc)
                raiserror(@err_msg,16,1)
                if @debug = 1 print @err_msg
            end
	END
	IF @merge_rc = 0

	-------------------------------------
	-- CustomerFunnel table
	-------------------------------------
	IF @merge_rc = 0
	BEGIN
	UPDATE CustomerFunnel SET customer_ID = @customer_ID WHERE customer_ID IS NOT NULL AND customer_ID = @prospect_ID
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg ='Error updating CustomerNote record: ' + convert(varchar(10), @merge_rc)
                raiserror(@err_msg,16,1)
                if @debug = 1 print @err_msg
           end
	END
	IF @merge_rc = 0

	
	-------------------------------------
	-- Customer table
        -- rg051606 we will be delting this to be consistent with contact merge
	-------------------------------------
	IF @merge_rc = 0
	BEGIN
	DELETE Customer 
        WHERE customer_ID = @prospect_ID
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg ='Error deactivating Prospect record: ' + convert(varchar(10), @merge_rc)
                raiserror(@err_msg,16,1)
                if @debug = 1 print @err_msg
           end
	END

-- Commit or Rollback
IF @merge_rc = 0
BEGIN
	COMMIT TRANSACTION MERGE_TO_CUSTOMER
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg ='Error COMMITTING changes: ' + convert(varchar(10), @merge_rc)
                raiserror(@err_msg,16,1)
                if @debug = 1 print @err_msg
           end
END
else
BEGIN
	ROLLBACK TRANSACTION MERGE_TO_CUSTOMER
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg ='Error ROLLBACKING changes: ' + convert(varchar(10), @merge_rc)
                raiserror(@err_msg,16,1)
                if @debug = 1 print @err_msg
           end
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_prospect_merge_master] TO [EQAI]
    AS [dbo];

