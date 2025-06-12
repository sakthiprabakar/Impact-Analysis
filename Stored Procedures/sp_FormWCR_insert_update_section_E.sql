USE [PLT_AI]
GO
/********************************************************************************************/
DROP PROCEDURE IF EXISTS [sp_FormWCR_insert_update_section_E]
GO
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_E]

       @Data XML,			
	   @form_id int,
	   @revision_id int

AS
/************************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns. 
**********************************************************************************/      
BEGIN  
	BEGIN TRY
      IF(EXISTS(SELECT * FROM FormWCR WHERE form_id = @form_id  and revision_id=  @revision_id))
    BEGIN    
	DECLARE @state_waste_code_flag CHAR(1) = (SELECT p.v.value('state_waste_code_flag[1]','char(1)') FROM @Data.nodes('SectionE')p(v))	
	  UPDATE  FormWCR
        SET        
            texas_waste_material_type = p.v.value('texas_waste_material_type[1]','char(1)'),
            texas_state_waste_code = p.v.value('texas_state_waste_code[1]','varchar(8)'),
            PA_residual_waste_flag = p.v.value('PA_residual_waste_flag[1]','char(1)'),
            rcra_exempt_flag = p.v.value('rcra_exempt_flag[1]','char(1)'),
			rcra_exempt_reason  = p.v.value(' rcra_exempt_reason[1]','varchar(255)'),
			cyanide_plating = p.v.value('cyanide_plating[1]','char(1)'),
			info_basis_analysis = p.v.value('info_basis_analysis[1]','char(1)'),
			info_basis_msds = p.v.value('info_basis_msds[1]','char(1)'),
			info_basis_knowledge = p.v.value('info_basis_knowledge[1]','char(1)'),
			state_waste_code_flag=p.v.value('state_waste_code_flag[1]','char(1)'),
			RCRA_waste_code_flag=p.v.value('RCRA_waste_code_flag[1]','char(1)')
        FROM
        @Data.nodes('SectionE')p(v) WHERE form_id = @form_id and revision_id=  @revision_id
	IF(EXISTS(SELECT form_id FROM FormXWasteCode WHERE form_id = @form_id and revision_id =  @revision_id))
	BEGIN				
		DELETE FormXWasteCode WHERE form_id = @form_id and revision_id =  @revision_id and specifier<>'TX' 
	END
	/* 65103 - Added 2023-05-17 by Sathiyamoorthi for prevent duplicate Waste Codes entry Start*/
		BEGIN
		INSERT INTO FormXWasteCode		
            SELECT 
			form_id,
			revision_id,
			page_number,
			line_item,
			waste_code_uid,
			waste_code,
			specifier,
			lock_flag
			from (SELECT 
			row_number() over(partition by p.v.value('waste_code_uid[1]','int') order by p.v.value('waste_code[1]','char(4)')) as r,
			form_id =@form_id,
			revision_id = p.v.value('revision_id[1]','int'),
			page_number = p.v.value('page_number[1]','int'),
			line_item = p.v.value('line_item[1]','int'),
			waste_code_uid =  p.v.value('waste_code_uid[1]','int'),
			waste_code = p.v.value('waste_code[1]','char(4)'),
			specifier = p.v.value('specifier[1]','varchar(30)'),
			lock_flag = 'F'  
            FROM
              @Data.nodes('SectionE/Pennsylvania_Residual/WasteCodes')p(v)) a where r = 1
		END
		BEGIN
		INSERT INTO FormXWasteCode		
            SELECT 
			form_id,
			revision_id,
			page_number,
			line_item,
			waste_code_uid,
			waste_code,
			specifier,
			lock_flag
			from (SELECT 
			row_number() over(partition by p.v.value('waste_code_uid[1]','int') order by p.v.value('waste_code[1]','char(4)')) as r,
			form_id =@form_id,
			revision_id = p.v.value('revision_id[1]','int'),
			page_number = p.v.value('page_number[1]','int'),
			line_item = p.v.value('line_item[1]','int'),
			waste_code_uid =  p.v.value('waste_code_uid[1]','int'),
			waste_code = p.v.value('waste_code[1]','char(4)'),
			specifier = p.v.value('specifier[1]','varchar(30)'),
			lock_flag = 'F'  
            FROM
              @Data.nodes('SectionE/StateWasteCodes/WasteCodes')p(v)) a WHERE @state_waste_code_flag <> 'T' AND r = 1
		END

		BEGIN
		INSERT INTO FormXWasteCode		
            SELECT 
			form_id,
			revision_id,
			page_number,
			line_item,
			waste_code_uid,
			waste_code,
			specifier,
			lock_flag
			from (SELECT 
			row_number() over(partition by p.v.value('waste_code_uid[1]','int') order by p.v.value('waste_code[1]','char(4)')) as r,
			form_id =@form_id,
			revision_id = p.v.value('revision_id[1]','int'),
			page_number = p.v.value('page_number[1]','int'),
			line_item = p.v.value('line_item[1]','int'),
			waste_code_uid =  p.v.value('waste_code_uid[1]','int'),
			waste_code = p.v.value('waste_code[1]','char(4)'),
			specifier = p.v.value('specifier[1]','varchar(30)'),
			lock_flag = p.v.value('lock_flag[1]','char(1)')  
            FROM
              @Data.nodes('SectionE/RCRACodes/WasteCodes')p(v)) a where r = 1
		END
		/*65103 - Added 2023-05-17 by Sathiyamoorthi for prevent duplicate Waste Codes entry END*/

/* Added 2019-11-07 by Jonathan Broome for creating new Texas Waste Codes as needed */
	-- 1. Create a temp table to contain TX waste codes to insert. They may be new and need new waste_code_uids
			create table #txwastecode (
				form_id	int
				, revision_id	int
				, page_number	int
				, line_item	int
				, waste_code	char(4)
				, display_name	varchar(20)
				, waste_code_uid	int null
				, specifier	varchar(30)
			)
				
	-- 2. Insert #txwastecodes from the input
			INSERT INTO #txwastecode (
				form_id
				, revision_id
				, page_number
				, line_item
				, display_name
				, waste_code_uid
				, specifier
			)
			SELECT TOP 1
			   @form_id,
			   @revision_id,
			   p.v.value('page_number[1]','int'),
			   p.v.value('line_item[1]','int'),
			   p.v.value('waste_code[1]','char(20)'),
			   p.v.value('waste_code_uid[1]','int'),			  
			   specifier = p.v.value('specifier[1]','varchar(30)')
			FROM
			@Data.nodes('SectionE/TexasStateWasteCodes/WasteCodes')p(v)

		update #txwastecode set display_name = replace(display_name, 'TX-', '') where display_name like 'TX-%'

	-- 3. Update #txwastecode with any potentially missing wastecode.waste_code_uid values that already exist
			update #txwastecode set waste_code_uid = wc.waste_code_uid
			, waste_code = wc.waste_code
			from #txwastecode t join wastecode wc on t.display_name = wc.display_name
			and wc.waste_code_origin = 'S' and wc.state = 'TX' and wc.status = 'A'
			and isnull(t.waste_code_uid, 0) = 0

			update #txwastecode set waste_code = wc.waste_code
			from #txwastecode t join wastecode wc on t.waste_code_uid= wc.waste_code_uid
			and wc.waste_code_origin = 'S' and wc.state = 'TX' and wc.status = 'A'
			and isnull(t.waste_code, '') = ''			
	-- 4. Insert each remaining #txwastecode entries that DON'T have a waste_code_uid into WasteCode. This creates a waste_code_uid.
			while exists (select 1 from #txwastecode where isnull(waste_code_uid, 0) = 0) begin
				declare @wastecode varchar(8), @wastecode4 varchar(4)
				select top 1 @wastecode = display_name from #txwastecode where isnull(waste_code_uid, 0) = 0		
				
		-- Drop the temporary table
		DROP TABLE IF EXISTS #MaxNumericParts;
		-- Create a temporary table to store intermediate results
		CREATE TABLE #MaxNumericParts (
			letter CHAR(1),
			max_numeric INT
		);
		-- Find the maximum numeric part for each letter and insert into the temporary table
		INSERT INTO #MaxNumericParts (letter, max_numeric)
		SELECT
			a.letter,
			MAX(TRY_CAST(ISNULL(NULLIF(SUBSTRING(w.waste_code, 2, LEN(w.waste_code) - 1), ''), '0') AS INT)) AS max_numeric
		FROM
			(
				SELECT DISTINCT UPPER(LEFT(name, 1)) AS letter
				FROM syscolumns
				WHERE PATINDEX('[A-Z]', UPPER(LEFT(name, 1))) > 0
			) a
		LEFT JOIN wastecode w ON LEFT(w.waste_code, 1) = a.letter AND w.state = 'TX'
		GROUP BY a.letter;

		-- Find the first available waste code for each letter
		;WITH AvailableWasteCodes AS (
			SELECT
				a.letter,
				MAX(mnp.max_numeric) + 1 AS next_numeric
			FROM
				(
					SELECT DISTINCT UPPER(LEFT(name, 1)) AS letter
					FROM syscolumns
					WHERE PATINDEX('[A-Z]', UPPER(LEFT(name, 1))) > 0
				) a
			LEFT JOIN #MaxNumericParts mnp ON a.letter = mnp.letter
			GROUP BY a.letter
			HAVING MAX(mnp.max_numeric) + 1 < 1000
		)

		-- Select the first available waste code that does not exist in the 'wastecode' table
		SELECT TOP 1
			@wastecode4 = awc.letter + RIGHT('000' + CONVERT(VARCHAR(3), awc.next_numeric), 3)
		FROM AvailableWasteCodes awc
		WHERE NOT EXISTS (
			SELECT 1
			FROM wastecode
			WHERE waste_code = awc.letter + RIGHT('000' + CONVERT(VARCHAR(3), awc.next_numeric), 3)
		)
		ORDER BY awc.letter;

		-- Output the generated waste code
		IF (@wastecode4 IS NULL)
		   SET @wastecode4 = '0000'

		declare @txAddedBy varchar(100)
		select top 1 @txAddedBy = created_by
		FROM    FormWCR 
		WHERE form_id = @form_id
		and revision_id = @revision_id
						
				insert wastecode (
					waste_code				-- 4 char "old" waste code value. Must be unique. Convention = letter + sequential #
					, waste_type_code		-- 'S'
					, waste_code_desc		-- Waste Code
					, haz_flag				-- Defaulting to 'T'
					, pcb_flag				-- Defaulting to 'F'
					, waste_code_origin		-- 'S' (state)
					, state					-- 'TX'
					, date_added			-- getdate()
					, added_by				-- COR
					, date_modified			-- getdate()
					, modified_by			-- COR
					, display_name			-- Waste Code
					, sequence_id			-- 1
					, status				-- A
					, steers_reportable_flag	-- Defaulting to T
					, internal_note			-- Created by web_userid
					, added_from_cor_flag	-- T
					) 
					select
						@wastecode4 as waste_code
						, 'S' as waste_type_code
						, display_name as waste_code_desc
						, case when display_name like '%1' or display_name like '%H' then 'T' else 'F' end as haz_flag
						, 'F' as pcb_flag
						, 'S' as waste_code_origin
						, 'TX' as state
						, getdate() as date_added
						, 'COR' as added_by
						, getdate() as date_modified
						, 'COR' as modified_by
						, display_name as display_name
						, 1 as sequence_id
						, 'A' as status
						, case when display_name like '%1' or display_name like '%H' then 'T' else 'F' end as steers_reportable_flag
						--, 'T' as steers_reportable_flag
						, 'Added by COR user ' + isnull(@txAddedBy, '(Unknown)') as internal_note
						, 'T' as added_from_cor_flag
						from #txwastecode where isnull(waste_code_uid, 0) = 0
						and display_name = @wastecode

				update #txwastecode set waste_code_uid = w.waste_code_uid
				, waste_code = w.waste_code
				from #txwastecode t join wastecode w on w.display_name = @wastecode
				and isnull(t.waste_code_uid, 0) = 0
				and t.display_name = @wastecode
				and w.state = 'TX'
			end

	-- 4. Modified TX Waste Code Insert...
		DELETE FormXWasteCode WHERE form_id = @form_id and revision_id =  @revision_id and specifier='TX' 	
			INSERT INTO FormXWasteCode 
			(
			form_id,
			revision_id,
			page_number,
			line_item,
			waste_code_uid,		  
			waste_code,
			specifier
			)
			SELECT
			form_id,
			revision_id,
			page_number,
			line_item,
			waste_code_uid,		  
			waste_code,
			'TX' as specifier
			FROM
			#txwastecode

	IF(EXISTS(SELECT form_id FROM FormXConstituent WHERE form_id = @form_id and revision_id =  @revision_id))
	BEGIN		
		DELETE FormXConstituent WHERE form_id = @form_id and revision_id =  @revision_id
	END
		IF(NOT EXISTS(SELECT form_id FROM FormXConstituent WHERE form_id = @form_id and revision_id=  @revision_id))
		BEGIN
		INSERT INTO FormXConstituent		
              select 
		form_id,
		revision_id,
		page_number,
		line_item ,
		const_id ,
		const_desc,
		min_concentration,
		concentration ,
		unit ,
		uhc,
		specifier,
		TCLP_or_totals,
		typical_concentration ,
		max_concentration ,
		exceeds_LDR ,
		requiring_treatment_flag,
		cor_lock_flag
			from (SELECT 
			row_number() over(partition by p.v.value('const_id[1]','int') order by p.v.value('order[1]','int')) as r,			   
			   form_id = @form_id,
			   revision_id = @revision_id,
			   page_number = p.v.value('page_number[1]','int'),
			   line_item = p.v.value('line_item[1]','int'),
			   const_id = p.v.value('const_id[1]','int'),
			   const_desc = p.v.value('const_desc[1]','varchar(50)'),
			   min_concentration = p.v.value('min_concentration[1][not(@xsi:nil = "true")]','FLOAT'),
			   concentration = p.v.value('concentration[1]','FLOAT'),
			   unit =p.v.value('unit[1]','char(10)'),
			   uhc = case when p.v.value('uhc[1]','char(1)') = 'T' then 'T' else 'F' end,
			   specifier = p.v.value('specifier[1]','varchar(30)'),
			   TCLP_or_totals = CASE
				WHEN p.v.value('TCLP_or_totals[1]','varchar(10)')='T' THEN 'TCLP'
				WHEN p.v.value('TCLP_or_totals[1]','varchar(10)')='F' THEN 'Totals' END,
			   typical_concentration = p.v.value('typical_concentration[1][not(@xsi:nil = "true")]','FLOAT'),
			   max_concentration = p.v.value('max_concentration[1][not(@xsi:nil = "true")]','FLOAT'),
			   exceeds_LDR = case when p.v.value('exceeds_LDR[1]','char(1)') = 'T' then 'T' else 'F' end,
			   requiring_treatment_flag=p.v.value('requiring_treatment_flag[1]','char(1)'),
			   cor_lock_flag=p.v.value('cor_lock_flag[1]','char(1)')  
              FROM
              @Data.nodes('SectionE/ChemicalComposition/ChemicalComposition')p(v)) a where r = 1 and const_id > 0
		END	  
	   END
	END TRY
	BEGIN CATCH
		INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                    VALUES(ERROR_MESSAGE(),ERROR_PROCEDURE(),'',GETDATE())

		declare @procedure nvarchar(150), 
				@mailTrack_userid nvarchar(60) = 'COR'
				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000),@Data)														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description
	END CATCH
END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_E] TO COR_USER;
GO
/*************************************************************************************************/