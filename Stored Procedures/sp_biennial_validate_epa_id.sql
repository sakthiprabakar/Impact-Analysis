
CREATE PROCEDURE sp_biennial_validate_epa_id
	@biennial_id int,
	@debug		int = 0
AS

/******************************************************************************
sp_biennial_validate_epa_id

History:
	2/8/2012	JPB	Rewrote this to be a LOT faster, skip overlay section
	1/23/2018	JPB	added FC to validEpaIdStates (also broke it out into a 1-instance variable)

Example:
	sp_biennial_validate_epa_id 2034;
	SELECT  * FROM  EQ_Extract..BiennialReportSourceDataValidation WHERE biennial_id = 2034 and validation_message not like '%Bol type%'
	select * FROM  EQ_Extract..BiennialReportSourceDataValidation WHERE biennial_id = 2034 and validation_message like '%EPA ID%'
	delete FROM  EQ_Extract..BiennialReportSourceDataValidation WHERE biennial_id = 2034 and validation_message like '%EPA ID%'

	exec sp_biennial_validate 2034


******************************************************************************/
BEGIN

	declare @newline varchar(5) = char(13)+char(10)

if @debug > 0 select getdate(), 'sp_biennial_validate_epa_id: started'	

if object_id('tempdb..#test') is not null drop table #test
create table #test (
	validation_message	varchar(255),
	epa_validation		varchar(100),
	epa_id_name			varchar(40),
	epa_id_to_test		varchar(20)
)

	declare @validEpaIdChars varchar(100) = ' D R 0 1 2 3 4 5 6 7 8 9 '
		, @validEpaIdStates varchar(1000) = ' AA AE AK AL AP AR AS AZ CA CO CT DC DE FL FM GA GU HI IA ID IL IN KS KY LA MA MD ME MH MI MN MO MP MS MT NC ND NE NH NJ NM NV NY OH OK OR PA PR PW RI SC SD TN TX UT VA VI VT WA WI WV WY FC '

	insert #test
	select 	
		null, 
		null, 
		'TSDF EPA ID' as epa_id_name,
		src.TSDF_EPA_ID as epa_id_to_test	
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
	AND NOT CHARINDEX(' ' + SUBSTRING(TSDF_EPA_ID, 3, 1) + ' ', @validEpaIdChars) = 0
	and (
		CHARINDEX(' ' + left(TSDF_EPA_ID, 2) + ' ', @validEpaIdStates) = 0
		OR
		len(TSDF_EPA_ID) < 3
		OR
		ISNUMERIC(SUBSTRING(TSDF_EPA_ID, 4, 9)) = 0
		OR
		ISNUMERIC(RIGHT(TSDF_EPA_ID, 1)) = 0
	)
	UNION 
	select 	
		null, 
		null, 
		'Generator EPA ID',
		src.generator_epa_id as epa_id_to_test
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
		AND NOT CHARINDEX(' ' + SUBSTRING(generator_epa_id, 3, 1) + ' ', @validEpaIdChars) = 0
		and (
			CHARINDEX(' ' + left(generator_epa_id, 2) + ' ', @validEpaIdStates) = 0
			OR
			len(generator_epa_id) < 3
			OR
			ISNUMERIC(SUBSTRING(generator_epa_id, 4, 9)) = 0
			OR
			ISNUMERIC(RIGHT(generator_epa_id, 1)) = 0
		)
	UNION 
	select 	
		null, 
		null,
		'Transporter EPA ID',
		src.transporter_EPA_ID as epa_id_to_test
	FROM EQ_Extract..BiennialReportSourceData src
	WHERE src.biennial_id = @biennial_id
		AND NOT CHARINDEX(' ' + SUBSTRING(transporter_EPA_ID, 3, 1) + ' ', @validEpaIdChars) = 0
		and (
			CHARINDEX(' ' + left(transporter_EPA_ID, 2) + ' ', @validEpaIdStates) = 0
			OR
			len(transporter_EPA_ID) < 3
			OR
			ISNUMERIC(SUBSTRING(transporter_EPA_ID, 4, 9)) = 0
			OR
			ISNUMERIC(RIGHT(transporter_EPA_ID, 1)) = 0
		)

if @debug > 0 select getdate(), 'sp_biennial_validate_epa_id: finished loading #test'	

	-- select * from #test
	update #test set epa_validation = dbo.fn_epa_id_validate(epa_id_to_test)

if @debug > 0 select getdate(), 'sp_biennial_validate_epa_id: finished running fn_epa_id_validate on #test'	

	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation (validation_message, rowid, biennial_id)
	
	 SELECT 'Possible bad ' + t.epa_id_name + ': ' + t.epa_id_to_test + ' - Reason ' + t.epa_validation
	 , 1, @biennial_id
		FROM EQ_Extract..BiennialReportSourceData src
		INNER JOIN #test t on src.TSDF_EPA_ID = t.epa_id_to_test
		and t.epa_id_name = 'TSDF EPA ID'
	AND src.biennial_id = @biennial_id
	UNION
	 SELECT 'Possible bad ' + t.epa_id_name + ': ' + t.epa_id_to_test + ' - Reason ' + t.epa_validation
	 , 1, @biennial_id
		FROM EQ_Extract..BiennialReportSourceData src
		INNER JOIN #test t on src.generator_epa_id = t.epa_id_to_test
		and t.epa_id_name = 'Generator EPA ID'
	AND src.biennial_id = @biennial_id
	UNION
	 SELECT 'Possible bad ' + t.epa_id_name + ': ' + t.epa_id_to_test + ' - Reason ' + t.epa_validation
		 , 1, @biennial_id
		FROM EQ_Extract..BiennialReportSourceData src
		INNER JOIN #test t on src.transporter_epa_id = t.epa_id_to_test
		and t.epa_id_name = 'Transporter EPA ID'
	AND src.biennial_id = @biennial_id



	INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation (validation_message, rowid, biennial_id)
	select 	distinct
		'Possible Foreign Transporter (check its state+country) EPA ID does not start with ''FC'': ' + src.transporter_epa_id, 
		1, 
		@biennial_id
	FROM EQ_Extract..BiennialReportSourceData src
	LEFT JOIN StateAbbreviation sa on isnull(src.transporter_state, '') = isnull(sa.abbr, 'XX')
	WHERE src.biennial_id = @biennial_id
	and isnull(src.transporter_country, sa.country_code) not like 'US%'
	and src.transporter_epa_id  not like 'FC%'
	union 
	select 	distinct
		'Possible Foreign Generator (check its state+country) EPA ID does not start with ''FC'': ' + src.generator_epa_id, 
		1,
		@biennial_id
	FROM EQ_Extract..BiennialReportSourceData src
	LEFT JOIN StateAbbreviation sa on isnull(src.generator_state, '') = isnull(sa.abbr, 'XX')
	WHERE src.biennial_id = @biennial_id
	and isnull(src.generator_country, sa.country_code) not like 'US%'
	and src.generator_epa_id  not like 'FC%'
	and src.generator_epa_id not like '%CESQG%'
	union
	select 	distinct
		'Possible Foreign TSDF (check its state+country) EPA ID does not start with ''FC'': ' + tsdf_epa_id, 
		1, 
		@biennial_id
	FROM EQ_Extract..BiennialReportSourceData src
	LEFT JOIN StateAbbreviation sa on isnull(src.tsdf_state, '') = isnull(sa.abbr, 'XX')
	WHERE src.biennial_id = @biennial_id
	and isnull(src.tsdf_country, sa.country_code) not like 'US%'
	and src.tsdf_epa_id  not like 'FC%'


if @debug > 0 select getdate(), 'sp_biennial_validate_epa_id: finished inserting to validation table'	


	/* remove items we are going to ignore from validation -- these are items that have been verified OK to ignore */
/*	
2/8/2012 - JPB - No more overlay...

	DELETE FROM EQ_Extract..BiennialReportSourceDataValidation
		WHERE EXISTS(
			SELECT 1 FROM EQ_Extract..BiennialReportSourceDataOverlay overlay
			WHERE EQ_Extract..BiennialReportSourceDataValidation.generator_epa_id = overlay.generator_epa_id
			AND EQ_Extract..BiennialReportSourceDataValidation.biennial_id = @biennial_id
			AND overlay.action_column = 'generator_epa_id'
			AND overlay.action_name = 'ignore'
		)
		
	DELETE FROM EQ_Extract..BiennialReportSourceDataValidation
		WHERE EXISTS(
			SELECT 1 FROM EQ_Extract..BiennialReportSourceDataOverlay overlay
			WHERE EQ_Extract..BiennialReportSourceDataValidation.transporter_EPA_ID = overlay.transporter_EPA_ID
			AND EQ_Extract..BiennialReportSourceDataValidation.biennial_id = @biennial_id
			AND overlay.action_column = 'transporter_EPA_ID'
			AND overlay.action_name = 'ignore'
		)
		
	DELETE FROM EQ_Extract..BiennialReportSourceDataValidation
		WHERE EXISTS(
			SELECT 1 FROM EQ_Extract..BiennialReportSourceDataOverlay overlay
			WHERE EQ_Extract..BiennialReportSourceDataValidation.TSDF_EPA_ID = overlay.TSDF_EPA_ID
			AND EQ_Extract..BiennialReportSourceDataValidation.biennial_id = @biennial_id
			AND overlay.action_column = 'TSDF_EPA_ID'
			AND overlay.action_name = 'ignore'
		)				
*/		
	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_epa_id] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_epa_id] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_epa_id] TO [EQAI]
    AS [dbo];

