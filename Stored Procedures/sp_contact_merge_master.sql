
CREATE PROCEDURE sp_contact_merge_master
	@debug int, 
	@merge_ID int,
	@contact_ID int,
	@connect_type varchar(10),
	@merge_rc int OUTPUT
AS

/* **************************************************************************************************
The purpose of this SP is to merge a duplicate contact INTO the contact record the user wants to keep
the merge id is the source and the contact id is the target of the merge

LOAD TO PLT_AI

10/08/2003 SCC	Created
11/15/2004 JPB  Changed CustomerContact -> Contact
02/03/2006 MK	Fixed update of CustomerNote to set contact_id = @contact_id
02/23/2006 MK	Changed delete of merging contact to deactivate with status = 'X'
05/06/06   RG   modified for contactxref and Note
07/10/07   JPB  Modified ContactXRef/Generator section from type = 'C' to type = 'G' (line 168, 184)
08/15/2007 JPB	Modified: Generator Contact section was using wrong #table at the end of its loop
					and the Primary_contact queries forgot to exclude the contact you're already using.
10/01/2007 WAC	Changed tables with EQAI prefix to EQ prefix.  Added db_type to WHERE clause for eqdatabase query
					
sp_contact_merge_master 1, 2492, 2767, 'DEV', 0
************************************************************************************************** */

DECLARE 
@customer_id int,
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
@err_msg varchar(255),
@generator_id int

-- Create a temp table to hold the databases
SELECT company_id, db_name_eqai, 0 as process_flag INTO #tmp_database FROM EQConnect WHERE db_type = @connect_type

-- Control the merge
BEGIN TRANSACTION MERGE_TO_CONTACT

	-------------------------------------
	-- ContactXRef table
	-------------------------------------
	-- Check to see if a cross reference record already exists for this contact, per customer
	SELECT customer_ID, contact_ID, 0 as process_flag INTO #tmp_custXcontact 
		FROM ContactXRef WHERE contact_ID = @merge_ID
                and type = 'C'
	SELECT @process_count = count(*) FROM #tmp_custXcontact
	SET @merge_rc = 0
	SET ROWCOUNT 1
	WHILE @process_count > 0 AND @merge_rc = 0
	BEGIN
		SELECT @customer_id = customer_ID FROM #tmp_custXcontact WHERE process_flag = 0
		SELECT @xref_exists = count(*) FROM ContactXRef 
                                      WHERE contact_ID = @contact_ID 
                                        AND customer_ID = @customer_ID
                                        AND type = 'C'
		IF @xref_exists > 0 
		BEGIN
			-- Remove the merge contact's record
			DELETE FROM ContactXRef 
                               WHERE contact_ID = @merge_ID 
                                 AND customer_ID = @customer_ID
                                 AND type = 'C'
			SET @merge_rc = @@ERROR
                        if @merge_rc <> 0
                          begin
                               select @err_msg = 'Error deleting ContactXRef record: ' + convert(varchar(10), @merge_rc)
                               RAISERROR ( @err_msg,16,1)
			       IF @debug = 1 print @err_msg
                          end
		END
		ELSE
		BEGIN
		     if exists ( select 1 from ContactXref where type = 'C' and customer_id = @customer_id and primary_contact = 'T' and contact_id <> @merge_id)
             begin 
				-- Change merge ID to contact ID
				UPDATE ContactXRef 
	                           SET contact_ID = @contact_ID,
                                       primary_contact = 'F' 
	                         WHERE contact_ID = @merge_ID 
	                           AND customer_ID = @customer_ID
	                           and type = 'C'
				SET @merge_rc = @@ERROR
				IF @merge_rc <> 0
	                        begin
					select @err_msg =  'Error updating ContactXRef record: ' + convert(varchar(10), @merge_rc)
	                                RAISERROR ( @err_msg,16,2)
	                                if @debug = 1 print @err_msg
	                         end
             end
             else
 		     begin 
				-- Change merge ID to contact ID
				UPDATE ContactXRef 
	                           SET contact_ID = @contact_ID 
	                         WHERE contact_ID = @merge_ID 
	                           AND customer_ID = @customer_ID
	                           and type = 'C'
				SET @merge_rc = @@ERROR
				IF @merge_rc <> 0
	            begin
					select @err_msg =  'Error updating ContactXRef record: ' + convert(varchar(10), @merge_rc)
	                                RAISERROR ( @err_msg,16,2)
	                                if @debug = 1 print @err_msg
				 end
			 end
		END
		UPDATE #tmp_custXcontact SET process_flag = 1 WHERE process_flag = 0
		SELECT @process_count = @process_count - 1
	END 
	SET ROWCOUNT 0

	-------------------------------------
	-- Contact Generators
	-------------------------------------
	-- Check to see if a cross reference record already exists for this contact, per customer
	SELECT generator_ID, contact_ID, 0 as process_flag INTO #tmp_genXcontact 
		FROM ContactXRef WHERE contact_ID = @merge_ID
                and type = 'G'
	SELECT @process_count = count(*) FROM #tmp_genXcontact
	SET @merge_rc = 0
	SET ROWCOUNT 1
	WHILE @process_count > 0 AND @merge_rc = 0
	BEGIN
		SELECT @generator_id = generator_ID FROM #tmp_genXcontact WHERE process_flag = 0
		SELECT @xref_exists = count(*) FROM ContactXRef 
                                      WHERE contact_ID = @contact_ID 
                                        AND generator_id = @generator_id
                                        AND type = 'G'
		IF @xref_exists > 0 
		BEGIN
			-- Remove the merge contact's record
			DELETE FROM ContactXRef 
                               WHERE contact_ID = @merge_ID 
                                 AND generator_id = @generator_id
                                 AND type = 'G'

			SET @merge_rc = @@ERROR
                        if @merge_rc <> 0
                          begin
                               select @err_msg = 'Error deleting ContactXRef record: ' + convert(varchar(10), @merge_rc)
                               RAISERROR ( @err_msg,16,1)
								IF @debug = 1 print @err_msg
                          end
		END
		ELSE
		BEGIN
		     if exists ( select 1 from ContactXref where type = 'G' and generator_id = @generator_id and primary_contact = 'T' and contact_id <> @merge_id)
			 begin 
				-- Change merge ID to contact ID
				UPDATE ContactXRef 
	                           SET contact_ID = @contact_ID,
                                       primary_contact = 'F' 
	                         WHERE contact_ID = @merge_ID 
	                           AND generator_ID = @generator_id
	                           and type = 'G'
				SET @merge_rc = @@ERROR
				IF @merge_rc <> 0
				begin
					select @err_msg =  'Error updating ContactXRef record: ' + convert(varchar(10), @merge_rc)
					RAISERROR ( @err_msg,16,2)
					if @debug = 1 print @err_msg
				 end
			 end
			 else
 		     begin 
				-- Change merge ID to contact ID
				UPDATE ContactXRef 
	                           SET contact_ID = @contact_ID 
	                         WHERE contact_ID = @merge_ID 
	                           AND generator_ID = @generator_id
	                           and type = 'G'
				SET @merge_rc = @@ERROR
				IF @merge_rc <> 0
				begin
					select @err_msg =  'Error updating ContactXRef record: ' + convert(varchar(10), @merge_rc)
					RAISERROR ( @err_msg,16,2)
					if @debug = 1 print @err_msg
				end
			 end
		END
		UPDATE #tmp_genXcontact SET process_flag = 1 WHERE process_flag = 0
		SELECT @process_count = @process_count - 1
	END 
	SET ROWCOUNT 0

	-------------------------------------
	-- CustomerNote table
	-------------------------------------
	IF @merge_rc = 0
	BEGIN
	UPDATE Note SET contact_ID = @contact_ID 
         WHERE contact_ID IS NOT NULL 
           AND contact_ID = @merge_ID
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
            begin
		select @err_msg =  'Error updating Customer Note record: ' + convert(varchar(10), @merge_rc)
                RAISERROR ( @err_msg,16,1)
                if @debug = 1 print @err_msg
            end
	END
	IF @merge_rc = 0
		

	--------------------------------------------------------------------
	-- Change all merge IDs to the contact ID in each company database
	--------------------------------------------------------------------

	-- Process each database in the list
	select @no_db_count = 0
	select @db_count = count(*) from #tmp_database
	WHILE @db_count > 0 and @merge_rc = 0
	BEGIN
		-- Identify the database and company
		set rowcount 1
		select @database = db_name_eqai FROM #tmp_database WHERE process_flag = 0
		set rowcount 0

		-- Identify the server where this database lives
		SELECT @server = server_name FROM EQDatabase WHERE database_name = @database AND db_type = @connect_type

	   -- Identify if this server is available
	   SELECT @server_avail = server_avail FROM EQServer WHERE server_name = @server

		IF @debug = 1 print (  'Database: ' + @database + ' server: ' + @server + ' server_avail: ' + @server_avail )

	   IF @server_avail = 'yes'
	   BEGIN
	      SELECT @execute_sql = @server + '.' + @database + '.dbo.sp_contact_merge'
			EXECUTE @execute_sql @debug, @merge_ID, @contact_ID, @merge_rc OUTPUT
		END

		-- Update to process the next database
		set rowcount 1
		UPDATE #tmp_database SET process_flag = 1 WHERE process_flag = 0
		set rowcount 0
		SELECT @db_count = @db_count - 1
	END


	-------------------------------------
	-- Contact table (last)
	-------------------------------------
--      rg0512606 changed to move contact to archive table 
--      once marked X no one should have access to contact.
       
	IF @merge_rc = 0
	BEGIN
	
	Delete from Contact
        where contact_id = @merge_id
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg =  'Error deactivating Contact record on delete: ' + convert(varchar(10), @merge_rc)
                RAISERROR ( @err_msg,16,1)
                if @debug = 1 print @err_msg
           end
	END

-- Commit or Rollback
IF @merge_rc = 0
BEGIN
	COMMIT TRANSACTION MERGE_TO_CONTACT
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg =  'Error COMMITTING changes: ' + convert(varchar(10), @merge_rc)
                RAISERROR ( @err_msg,16,1)
                if @debug = 1 print @err_msg
           end
END
else
BEGIN
	ROLLBACK TRANSACTION MERGE_TO_CONTACT
	SET @merge_rc = @@ERROR
	IF @merge_rc <> 0
           begin
		select @err_msg = 'Error ROLLBACKING changes: ' + convert(varchar(10), @merge_rc)
                RAISERROR ( @err_msg,16,1)
                if @debug = 1 print @err_msg
           end
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_merge_master] TO [EQAI]
    AS [dbo];

