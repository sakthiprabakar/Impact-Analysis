 
 CREATE PROCEDURE sp_biennial_report_source_overlay
	@biennial_id int,
	@debug int = 0-- 1 = debug, 2 = print what is going to be updated
 AS
 
 /*
	The purpose of this procedure is to overlay data from the BiennialReportSourceDataOverlay table
	on top of the BiennialReportSourceData
	
 	exec sp_biennial_report_source_overlay 180
 */
 BEGIN
	-- with EQAI, we are only updating weights (gal/yard)
 	-- with EW, we are updating everything they told us to change in the spreadsheet
 	-- L:\Apps\SQL\Special Manual Requests\Biennial Reporting\Biennial Reporting 2010\2010 Files\Drafts and Validations
 	
 	--declare @biennial_id int = 187
 	SET NOCOUNT on
 	
 	if object_id('tempdb..#tmp_process') is not null drop table #tmp_process
 	if object_id('tempdb..#tmp_log') is not null drop table #tmp_log
 	
 	
 	create table #tmp_log
 	(
 		rowguid uniqueidentifier NULL,
 		data_source varchar(20) NULL,
 		enviroware_manifest_document varchar(20) NULL,
 		enviroware_manifest_document_line int NULL,
 		company_id int NULL,
 		profit_ctr_id int NULL,
 		receipt_id int NULL,
 		line_id int NULL,
 		container_id int NULL,
 		sequence_id int NULL,
 		action_column varchar(100) NULL,
 		action_name varchar(100) NULL,
 		new_value varchar(100) NULL
 	)
 	
 	declare @sql varchar(max) = '',
 		@column varchar(50) 
 		,@action_name varchar(50) 
 		,@value varchar(50) 
 		,@value_sql varchar(max) 
 	
 	SELECT *, 
 		0 as processed
 	INTO #tmp_process 
 	FROM EQ_Extract..BiennialReportSourceDataOverlay WITH (NOLOCK)

	
 	
 	CREATE UNIQUE CLUSTERED INDEX Idx1 ON #tmp_process(rowguid);
	
	declare @id uniqueidentifier
	SET @id = (SELECT TOP 1 rowguid FROM #tmp_process where processed = 0)
	
	create table #tmp_hack_for_getting_value (val varchar(100))
	
	declare @record_count_sql varchar(max) = ''
	declare @record_count int =0
	declare @action_sql varchar(max) = ''
	declare @processed_count int = 0
	declare @record_type varchar(20)=''
	
	
	WHILE @id IS NOT NULL
	BEGIN
		set @sql = ''
		SET @record_count_sql = ''
		set @action_sql = ''
			
		SELECT @column = action_column FROM #tmp_process WITH (NOLOCK) where rowguid = @id
		SELECT @action_name = action_name FROM #tmp_process WITH (NOLOCK) where rowguid = @id
		
		SET @record_type = CASE WHEN (SELECT receipt_id FROM #tmp_process where rowguid = @id) IS NOT NULL THEN 'EQAI'
			ELSE 'ENVIROWARE'
		END
		
		SET @value_sql = '
			declare @v varchar(100)
			SELECT @v = (SELECT TOP 1 ' + @column + ' FROM EQ_Extract..BiennialReportSourceDataOverlay WHERE rowguid = ''' + cast(@id as varchar(50))+ ''')
			INSERT INTO #tmp_hack_for_getting_value (val) values (@v)
		'
		exec(@value_sql)
		
		SELECT @value = val FROM #tmp_hack_for_getting_value WITH (NOLOCK)
		

		
		truncate table #tmp_hack_for_getting_value
		
		set @record_count_sql = ' SELECT COUNT(*)  '
		
		if @action_name = 'delete' 
		begin
			SET @action_sql = 'DELETE FROM EQ_Extract..BiennialReportSourceData '
			SET @sql = @sql + ' FROM EQ_Extract..BiennialReportSourceDataOverlay tp 
			INNER JOIN EQ_Extract..BiennialReportSourceData src ON '
			
			IF @record_type = 'EQAI' 
			BEGIN
				
				
				SET @sql = @sql + ' src.data_source = ''EQAI'' 
							AND src.receipt_id = tp.receipt_id
							AND src.line_id = tp.line_id
							AND src.company_id = tp.company_id
							AND src.profit_ctr_id = tp.profit_ctr_id
							AND src.container_id = tp.container_id
							AND src.sequence_id = tp.sequence_id '
			END
			ELSE
			BEGIN
			SET @sql = @sql + ' src.enviroware_manifest_document = tp.enviroware_manifest_document
								AND src.enviroware_manifest_document_line = tp.enviroware_manifest_document_line'
			END
				
				SET @sql = @sql + ' WHERE tp.rowguid = ''' + cast(@id as varchar(50))+ '''
				AND src.biennial_id = ''' + cast(@biennial_id as varchar(50))+ ''' '
		end
		
		if @action_name = 'overwrite'
		begin
		
				
		--set @record_count_sql = @record_count_sql + ' SELECT COUNT(*)  '
		SET @action_sql = 'UPDATE EQ_Extract..BiennialReportSourceData SET ' + @column + ' = ''' + @value + ''''
		SET @sql = @sql + ' FROM EQ_Extract..BiennialReportSourceDataOverlay tp 
		INNER JOIN EQ_Extract..BiennialReportSourceData src ON'
		
		IF @record_type = 'EQAI' 
			BEGIN
				SET @sql = @sql + ' src.data_source = ''EQAI'' 
							AND src.receipt_id = tp.receipt_id
							AND src.line_id = tp.line_id
							AND src.company_id = tp.company_id
							AND src.profit_ctr_id = tp.profit_ctr_id
							AND src.container_id = tp.container_id
							AND src.sequence_id = tp.sequence_id '
			END
			ELSE
			BEGIN
			SET @sql = @sql + ' src.enviroware_manifest_document = tp.enviroware_manifest_document
								AND src.enviroware_manifest_document_line = tp.enviroware_manifest_document_line'
			END
			
			SET @sql = @sql + ' WHERE tp.rowguid = ''' + cast(@id as varchar(50))+ '''
			AND src.biennial_id = ''' + cast(@biennial_id as varchar(50))+ ''' '
			
		end
		
		
		SET @sql = @sql + char(13)+char(10)+char(13)+char(10)
		
		--if @debug = 2
		--begin
		--	if LEN(@value) = 0 or isnull(@value,'') = ''
		--	begin
		--	print ISNULL(@action_sql,'action empty') + ISNULL(@sql,'sql empty')
		--	print ISNULL(@value,'empty')
		--	end
		--end
		
		set @action_sql = @action_sql + @sql
		set @record_count_sql = isnull(@record_count_sql,'') + @sql
		
		if @debug = 1
			print @action_sql

		if @processed_count % 100 = 0 
		begin
			print '/* Processed: ' + cast(@processed_count as varchar(100)) + ' records (' + CAST(CONVERT(TIME, getdate()) AS VARCHAR(20)) + '). */'
		end			

		if @debug = 2
		begin
				-- execute the count sql, to see if any affected records
				--print @record_count_sql
				
			-- store the new value of the changed data
			declare @new_value varchar(100)
			SELECT @new_value = @value			
			
			truncate table #tmp_hack_for_getting_value
			
			
			SET @value_sql = '
				truncate table #tmp_hack_for_getting_value
				declare @v varchar(100)
				SELECT @v = (' + ISNULL(@record_count_sql,'0') + ')
				INSERT INTO #tmp_hack_for_getting_value (val) values (@v)
			'
			--print 'record: ' + @record_count_sql
			
			--if len(@record_count_sql) = 0
			--	print 'foo'
			
			--print 'value: ' + @value_sql
			exec(@value_sql)
			
			SELECT @value = val FROM #tmp_hack_for_getting_value WITH (NOLOCK)
			truncate table #tmp_hack_for_getting_value
			
			if (cast(@value as int) > 0 OR @action_name = 'DELETE')
				INSERT #tmp_log 
				SELECT @id,
				@record_type,
				enviroware_manifest_document,
				enviroware_manifest_document_line,
				company_id,
				profit_ctr_id,
				receipt_id,
				line_id,
				container_id,
				sequence_id,
				action_column,
				@action_name,
				@new_value
				FROM #tmp_process WHERE rowguid = @id
				
		end
		else
		begin
			exec(@action_sql)
		end
			
		-- go to next iteration
		update #tmp_process set processed = 1 where rowguid = @id
		SET @id = (SELECT TOP 1 rowguid FROM #tmp_process where processed = 0)
		
		set @processed_count = @processed_count + 1
	END
 	
 	
 	if @debug = 2
 	begin
		SELECT @biennial_id as biennial_id, * FROM #tmp_log	
		
 	end
 	
 	--SELECT * FROM #tmp_process
 	
 END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_overlay] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_overlay] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_overlay] TO [EQAI]
    AS [dbo];

