USE [PLT_AI]
GO
CREATE OR ALTER PROCEDURE dbo.sp_FormWCR_insert_update_section_E
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
AS
/************************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
Updated by Blair Christensen for Titan 05/08/2025
**********************************************************************************/      
BEGIN  
	BEGIN TRY
		IF EXISTS (SELECT * FROM FormWCR WHERE form_id = @form_id and revision_id = @revision_id)
			BEGIN    
				DECLARE @state_waste_code_flag CHAR(1) = (SELECT p.v.value('state_waste_code_flag[1]','char(1)') FROM @Data.nodes('SectionE')p(v))	
				
				UPDATE dbo.FormWCR
				   SET texas_waste_material_type = p.v.value('texas_waste_material_type[1]', 'char(1)')
				     , texas_state_waste_code = p.v.value('texas_state_waste_code[1]', 'VARCHAR(8)')
					 , PA_residual_waste_flag = p.v.value('PA_residual_waste_flag[1]', 'char(1)')
					 , rcra_exempt_flag = p.v.value('rcra_exempt_flag[1]', 'char(1)')
					 , rcra_exempt_reason  = p.v.value(' rcra_exempt_reason[1]', 'VARCHAR(255)')
					 , cyanide_plating = p.v.value('cyanide_plating[1]', 'char(1)')
					 , info_basis_analysis = p.v.value('info_basis_analysis[1]', 'char(1)')
					 , info_basis_msds = p.v.value('info_basis_msds[1]', 'char(1)')
					 , info_basis_knowledge = p.v.value('info_basis_knowledge[1]', 'char(1)')
					 , state_waste_code_flag=p.v.value('state_waste_code_flag[1]', 'char(1)')
					 , RCRA_waste_code_flag=p.v.value('RCRA_waste_code_flag[1]', 'char(1)')
				  FROM @Data.nodes('SectionE')p(v)
				 WHERE form_id = @form_id and revision_id = @revision_id;

				IF EXISTS (SELECT form_id FROM dbo.FormXWasteCode WHERE form_id = @form_id and revision_id =  @revision_id)
					BEGIN				
						DELETE FROM dbo.FormXWasteCode WHERE form_id = @form_id and revision_id = @revision_id and specifier <> 'TX';
					END

				INSERT INTO dbo.FormXWasteCode (form_id, revision_id, page_number, line_item
					 , waste_code_uid, waste_code, specifier, lock_flag
				     --, added_by, date_added, modified_by, date_modified
					 )
					SELECT form_id, revision_id, page_number, line_item
					     , waste_code_uid, waste_code, specifier, lock_flag
					  FROM (SELECT ROW_NUMBER() OVER (partition by p.v.value('waste_code_uid[1]', 'int')
									order by p.v.value('waste_code[1]', 'char(4)')) as r
								 , @form_id as form_id
								 , p.v.value('revision_id[1]', 'int') as revision_id
								 , p.v.value('page_number[1]', 'int') as page_number
								 , p.v.value('line_item[1]', 'int') as line_item
								 , p.v.value('waste_code_uid[1]', 'int') as waste_code_uid
								 , p.v.value('waste_code[1]', 'char(4)') as waste_code
								 , p.v.value('specifier[1]', 'VARCHAR(30)') as specifier
								 , 'F' as lock_flag
							  FROM @Data.nodes('SectionE/Pennsylvania_Residual/WasteCodes')p(v)) a
							 WHERE r = 1;

				INSERT INTO dbo.FormXWasteCode (form_id, revision_id, page_number, line_item
					 , waste_code_uid, waste_code, specifier, lock_flag
				     --, added_by, date_added, modified_by, date_modified
					 )
					SELECT form_id, revision_id, page_number, line_item
					     , waste_code_uid, waste_code, specifier, lock_flag
					  FROM (SELECT ROW_NUMBER() OVER (partition by p.v.value('waste_code_uid[1]', 'int')
									ORDER BY p.v.value('waste_code[1]', 'char(4)')) as r
								 , @form_id as form_id
								 , p.v.value('revision_id[1]', 'int') as revision_id
								 , p.v.value('page_number[1]', 'int') as page_number
								 , p.v.value('line_item[1]', 'int') as line_item
								 , p.v.value('waste_code_uid[1]', 'int') as waste_code_uid
								 , p.v.value('waste_code[1]', 'char(4)') as waste_code
								 , p.v.value('specifier[1]', 'VARCHAR(30)') as specifier
								 , 'F' as lock_flag
							  FROM @Data.nodes('SectionE/StateWasteCodes/WasteCodes')p(v)) a
							 WHERE @state_waste_code_flag <> 'T'
							   AND r = 1;

				INSERT INTO dbo.FormXWasteCode (form_id, revision_id, page_number, line_item
					 , waste_code_uid, waste_code, specifier, lock_flag
				     --, added_by, date_added, modified_by, date_modified
					 )
					SELECT form_id, revision_id, page_number, line_item
					     , waste_code_uid, waste_code, specifier, lock_flag
					  FROM (SELECT ROW_NUMBER() OVER (partition by p.v.value('waste_code_uid[1]','int')
									ORDER BY p.v.value('waste_code[1]', 'char(4)')) as r
						         , @form_id as form_id
								 , p.v.value('revision_id[1]','int') as revision_id
								 , p.v.value('page_number[1]','int') as page_number
								 , p.v.value('line_item[1]','int') as line_item
								 , p.v.value('waste_code_uid[1]','int') as waste_code_uid
								 , p.v.value('waste_code[1]','char(4)') as waste_code
								 , p.v.value('specifier[1]','VARCHAR(30)') as specifier
								 , p.v.value('lock_flag[1]','char(1)') as lock_flag
							  FROM @Data.nodes('SectionE/RCRACodes/WasteCodes')p(v)) a
							 WHERE r = 1;

				/* Added 2019-11-07 by Jonathan Broome for creating new Texas Waste Codes as needed */
				-- 1. Create a temp table to contain TX waste codes to insert. They may be new and need new waste_code_uids
				CREATE TABLE #txwastecode (
					   form_id			INTEGER
					 , revision_id		INTEGER
					 , page_number		INTEGER
					 , line_item		INTEGER
					 , waste_code		CHAR(4)
					 , display_name		VARCHAR(20)
					 , waste_code_uid	INTEGER null
					 , specifier		VARCHAR(30)
					 );
				
				-- 2. Insert #txwastecodes from the input
				INSERT INTO #txwastecode (form_id, revision_id, page_number
				     , line_item
					 , display_name
					 , waste_code_uid
					 , specifier)
					SELECT TOP 1 @form_id, @revision_id, p.v.value('page_number[1]', 'int')
					     , p.v.value('line_item[1]','int')
						 , p.v.value('waste_code[1]','char(20)')
						 , p.v.value('waste_code_uid[1]','int')
						 , p.v.value('specifier[1]','VARCHAR(30)')
					  FROM @Data.nodes('SectionE/TexasStateWasteCodes/WasteCodes')p(v);

				UPDATE #txwastecode
				   SET display_name = REPLACE(display_name, 'TX-', '')
				 WHERE display_name like 'TX-%';

				-- 3. Update #txwastecode with any potentially missing wastecode.waste_code_uid values that already exist
				UPDATE #txwastecode
				   SET waste_code_uid = wc.waste_code_uid
					 , waste_code = wc.waste_code
				  FROM #txwastecode t
					   JOIN dbo.WasteCode wc on t.display_name = wc.display_name
				 WHERE wc.waste_code_origin = 'S'
				   AND wc.[state] = 'TX'
				   AND wc.[status] = 'A'
				   AND ISNULL(t.waste_code_uid, 0) = 0;

				UPDATE #txwastecode
				   SET waste_code = wc.waste_code
				  FROM #txwastecode t
					   JOIN dbo.WasteCode wc on t.waste_code_uid = wc.waste_code_uid
				 WHERE wc.waste_code_origin = 'S'
				   AND wc.[state] = 'TX'
				   AND wc.[status] = 'A'
				   AND ISNULL(t.waste_code, '') = '';
				   
				-- 4. Insert each remaining #txwastecode entries that DON'T have a waste_code_uid into WasteCode. This creates a waste_code_uid.
				WHILE EXISTS (SELECT 1 FROM #txwastecode WHERE ISNULL(waste_code_uid, 0) = 0)
					BEGIN
						DECLARE @wastecode VARCHAR(8)
						      , @wastecode4 VARCHAR(4)

						SELECT TOP 1 @wastecode = display_name
						  FROM #txwastecode
						 WHERE ISNULL(waste_code_uid, 0) = 0;
				
						-- Drop the temporary table
						DROP TABLE IF EXISTS #MaxNumericParts;
						
						-- Create a temporary table to store intermediate results
						CREATE TABLE #MaxNumericParts (letter CHAR(1), max_numeric INT);

						-- Find the maximum numeric part for each letter and insert into the temporary table
						INSERT INTO #MaxNumericParts (letter, max_numeric)
							SELECT a.letter
							     , MAX(TRY_CAST(ISNULL(NULLIF(SUBSTRING(w.waste_code, 2, LEN(w.waste_code) - 1), ''), '0') AS INT)) AS max_numeric
							  FROM (
									SELECT DISTINCT UPPER(LEFT(name, 1)) AS letter
									  FROM syscolumns
									 WHERE PATINDEX('[A-Z]', UPPER(LEFT(name, 1))) > 0
									) a
							  LEFT JOIN dbo.WasteCode w ON LEFT(w.waste_code, 1) = a.letter
										AND w.[state] = 'TX'
							 GROUP BY a.letter;

						-- Find the first available waste code for each letter
						WITH AvailableWasteCodes AS (
							SELECT a.letter
								 , MAX(mnp.max_numeric) + 1 AS next_numeric
							  FROM (
									SELECT DISTINCT UPPER(LEFT(name, 1)) AS letter
									  FROM syscolumns
									 WHERE PATINDEX('[A-Z]', UPPER(LEFT(name, 1))) > 0
									) a
							  LEFT JOIN #MaxNumericParts mnp ON a.letter = mnp.letter
							 GROUP BY a.letter
							HAVING MAX(mnp.max_numeric) + 1 < 1000)
						SELECT TOP 1 @wastecode4 = awc.letter + RIGHT('000' + CONVERT(VARCHAR(3), awc.next_numeric), 3)
						  FROM AvailableWasteCodes awc
						 WHERE NOT EXISTS (
								SELECT 1
								  FROM dbo.WasteCode
								 WHERE waste_code = awc.letter + RIGHT('000' + CONVERT(VARCHAR(3), awc.next_numeric), 3)
								)
						 ORDER BY awc.letter;

						-- Output the generated waste code
						IF (@wastecode4 IS NULL)
							BEGIN
								SET @wastecode4 = '0000';
							END

						DECLARE @txAddedBy VARCHAR(100)

						SELECT @txAddedBy = created_by
						  FROM dbo.FormWCR 
						 WHERE form_id = @form_id
						   AND revision_id = @revision_id;
						
						INSERT INTO dbo.WasteCode (waste_code, waste_type_code, waste_code_desc, haz_flag
						     , pcb_flag, waste_code_origin, [state], date_added, added_by, date_modified, modified_by
							 , display_name, sequence_id, [status], steers_reportable_flag, internal_note, added_from_cor_flag) 
						SELECT @wastecode4 as waste_code
							 , 'S' as waste_type_code
							 , display_name as waste_code_desc
							 , CASE WHEN display_name LIKE '%1' or display_name LIKE '%H' THEN 'T'
								    ELSE 'F'
								END as haz_flag
							 , 'F' as pcb_flag
							 , 'S' as waste_code_origin
							 , 'TX' as [state]
							 , GETDATE() as date_added
							 , 'COR' as added_by
							 , GETDATE() as date_modified
							 , 'COR' as modified_by
							 , display_name as display_name
							 , 1 as sequence_id
							 , 'A' as [status]
							 , CASE WHEN display_name like '%1' or display_name like '%H' THEN 'T'
								    ELSE 'F'
								END as steers_reportable_flag
							 , 'Added by COR user ' + ISNULL(@txAddedBy, '(Unknown)') as internal_note
							 , 'T' as added_from_cor_flag
						  FROM #txwastecode
						 WHERE ISNULL(waste_code_uid, 0) = 0
						   AND display_name = @wastecode;

						UPDATE #txwastecode
						   SET waste_code_uid = w.waste_code_uid
							 , waste_code = w.waste_code
						  FROM #txwastecode t
							   JOIN wastecode w on w.display_name = @wastecode
						 WHERE ISNULL(t.waste_code_uid, 0) = 0
						   AND t.display_name = @wastecode
						   and w.[state] = 'TX';
					END

					-- 4. Modified TX Waste Code Insert...
					DELETE FROM dbo.FormXWasteCode
					 WHERE form_id = @form_id
					   AND revision_id =  @revision_id
					   AND specifier = 'TX';

					INSERT INTO dbo.FormXWasteCode (form_id, revision_id, page_number
						 , line_item, waste_code_uid, waste_code, specifier)
						SELECT form_id, revision_id, page_number
						     , line_item, waste_code_uid, waste_code, 'TX' as specifier
						  FROM #txwastecode;

					IF EXISTS (SELECT form_id FROM dbo.FormXConstituent WHERE form_id = @form_id and revision_id = @revision_id)
						BEGIN		
							DELETE FROM dbo.FormXConstituent WHERE form_id = @form_id and revision_id = @revision_id;
						END

					IF NOT EXISTS (SELECT form_id FROM dbo.FormXConstituent WHERE form_id = @form_id and revision_id = @revision_id)
						BEGIN
							INSERT INTO dbo.FormXConstituent (form_id, revision_id, page_number, line_item, const_id, const_desc
							     , min_concentration, concentration, unit, uhc, specifier, TCLP_or_totals, typical_concentration
								 , max_concentration, exceeds_LDR, requiring_treatment_flag, cor_lock_flag
								 --, added_by, date_added, modified_by, date_modified
								 )
								SELECT form_id, revision_id, page_number, line_item, const_id, const_desc
								     , min_concentration, concentration, unit, uhc, specifier, TCLP_or_totals, typical_concentration
									 , max_concentration, exceeds_LDR, requiring_treatment_flag, cor_lock_flag
								  FROM (SELECT ROW_NUMBER() OVER (partition by p.v.value('const_id[1]', 'int')
													order by p.v.value('order[1]', 'int')) as r
											 , @form_id as form_id
											 , @revision_id as revision_id
											 , p.v.value('page_number[1]', 'int') as page_number
											 , p.v.value('line_item[1]', 'int') as line_item
											 , p.v.value('const_id[1]', 'int') as const_id
											 , p.v.value('const_desc[1]','VARCHAR(250)') as const_desc
											 , p.v.value('min_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as min_concentration
											 , p.v.value('concentration[1]', 'FLOAT') as concentration
											 , p.v.value('unit[1]', 'char(10)') as unit
											 , CASE WHEN p.v.value('uhc[1]', 'char(1)') = 'T' THEN 'T'
													ELSE 'F'
												END as uhc
											 , p.v.value('specifier[1]', 'VARCHAR(30)') as specifier
											 , CASE WHEN p.v.value('TCLP_or_totals[1]', 'VARCHAR(10)') = 'T' THEN 'TCLP'
													WHEN p.v.value('TCLP_or_totals[1]', 'VARCHAR(10)') = 'F' THEN 'Totals'
												END as TCLP_or_totals
											 , p.v.value('typical_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as typical_concentration
											 , p.v.value('max_concentration[1][not(@xsi:nil = "true")]', 'FLOAT') as max_concentration
											 , CASE WHEN p.v.value('exceeds_LDR[1]', 'char(1)') = 'T' THEN 'T'
													ELSE 'F'
												END as exceeds_LDR
											 , p.v.value('requiring_treatment_flag[1]', 'char(1)') as requiring_treatment_flag
											 , p.v.value('cor_lock_flag[1]', 'char(1)') as cor_lock_flag
										  FROM @Data.nodes('SectionE/ChemicalComposition/ChemicalComposition')p(v)) a
										 WHERE r = 1
										   AND const_id > 0;
						END	  
			END
	END TRY

	BEGIN CATCH
		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
			VALUES(ERROR_MESSAGE(), ERROR_PROCEDURE(), '', GETDATE());

		DECLARE @procedure NVARCHAR(150) = ERROR_PROCEDURE()
			  , @error NVARCHAR(4000) = ERROR_MESSAGE()

		DECLARE @error_description NVARCHAR(4000) = 'Form ID: '
				+ CONVERT(NVARCHAR(15), @form_id)
				+ '-' +  CONVERT(NVARCHAR(15), @revision_id)
				+ CHAR(13) + CHAR(13) + 'Error Message: ' + ISNULL(@error, '')
				+ CHAR(13) + CHAR(13) + 'Data:  ' + CONVERT(NVARCHAR(4000), @Data)

		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = 'COR', @object = @procedure, @body = @error_description;
	END CATCH
END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_E] TO COR_USER;
GO
/*************************************************************************************************/