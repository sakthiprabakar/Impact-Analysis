CREATE OR ALTER PROCEDURE dbo.sp_FormWCR_insert_update_section_C
      @Data XML
	, @form_id INTEGER
	, @revision_id INTEGER
	, @web_userid VARCHAR(100)
AS
/* ******************************************************************

Insert / update Section C form  (Part of form wcr insert / update)
* ******************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns
Updated by Blair Christensen for Titan 05/08/2025
****************************************************************** *

inputs 
	
	Data -- XML data having values for the FormWCR, FormXWCRContainerSize and FormXUnit tables objects
	Form ID
	Revision ID

EXEC sp_FormWCR_insert_update_section_C	'<SectionC>
      <DOTShippingName />
      <DOT_inhalation_haz_flag />
      <DOT_shipping_desc_additional />
      <DOT_sp_permit_flag>T</DOT_sp_permit_flag>
      <DOT_sp_permit_text>US Ecology Information</DOT_sp_permit_text>
      <DOT_waste_flag />
      <ERG />
      <ERG_number />
      <ERG_suffix />
      <IsEdited>C</IsEdited>
      <RQ_reason>US Ecology Information</RQ_reason>
      <RQ_threshold>sdfsdf</RQ_threshold>
      <UNNAObj />
      <UN_NA_flag />
      <UN_NA_number />
      <UnitSize />
      <bill_unit_code />
      <containerType />
      <container_size />
      <container_type_boxes />
      <container_type_bulk />
      <container_type_combination />
      <container_type_combination_desc />
      <container_type_cylinder />
      <container_type_drums />
      <container_type_labpack />
      <container_type_other />
      <container_type_other_desc />
      <container_type_pallet />
      <container_type_totes />
      <dot_shipping_name />
      <emergency_phone_number />
      <formStatus>INVALID</formStatus>
      <frequency />
      <frequency_other />
      <hazmat_class />
      <hazmat_flag />
      <isFormValid>false</isFormValid>
      <package_group />
      <quantity />
      <reportable_quantity_flag>T</reportable_quantity_flag>
      <sub_hazmat_class />
      <subsidiary_haz_mat_class />
      <tab>3</tab>
   </SectionC>',525257,1,'nyswyn100'

****************************************************************** */
BEGIN
	BEGIN TRY
		DECLARE @UN_NA VARCHAR(255)
		      , @ERGVALUE VARCHAR(200);

		SELECT @ERGVALUE = p.v.value('ERG_number[1]','VARCHAR(200)')
		  FROM @Data.nodes('SectionC')p(v);

		DECLARE @Ass_UN_NA_number VARCHAR(1000) = @UN_NA
			  , @Counter INTEGER = 1
			  , @currChar char(1) = ''
			  , @UNNA_flag VARCHAR(1000) = ''
			  , @UNNA_number VARCHAR(1000) = ''
			  , @splitStringLength INTEGER = LEN(@ERGVALUE)
			  , @countnum INTEGER = 0
			  , @getIntDatatype NVARCHAR(10)
			  , @getStringDatatype NVARCHAR(10)

		WHILE (@countnum <= @splitStringLength)
			BEGIN  
				IF (ISNUMERIC(SUBSTRING(@ERGVALUE, @countnum, 1)) = 1) 
					BEGIN
						SET @getIntDatatype = ISNULL(@getIntDatatype,'') + CONVERT(NVARCHAR(10), SUBSTRING(@ERGVALUE, @countnum, 1))
					END
				ELSE
					BEGIN
						SET @getStringDatatype = ISNULL(@getStringDatatype,'') + CONVERT(NVARCHAR(10), SUBSTRING(@ERGVALUE, @countnum, 1))
					END
				SET @countnum = @countnum + 1
			END

		WHILE (@Counter <= LEN(@Ass_UN_NA_number))
			BEGIN
				SET @currChar = SUBSTRING(@Ass_UN_NA_number, @Counter, 1)
				IF isNumeric(@currChar) = 1
					BEGIN
						SET @UNNA_number = @UNNA_number + @currChar
					END
				ELSE
					BEGIN
						SET @UNNA_flag = @UNNA_flag + @currChar
					END

				SET @counter = @counter + 1
			END

		IF EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @form_id AND revision_id = @revision_id)
			BEGIN
				DECLARE @erg_no INTEGER = CONVERT(INT, ISNULL(@getIntDatatype, 0))

				UPDATE dbo.FormWCR
				   SET hazmat_flag = p.v.value('hazmat_flag[1]', 'char(1)')
				     , DOT_waste_flag = p.v.value('DOT_waste_flag[1]', 'char(1)')
					 , dot_shipping_name = p.v.value('dot_shipping_name[1]', 'VARCHAR(255)')
					 , DOT_sp_permit_text = p.v.value('DOT_sp_permit_text[1]', 'VARCHAR(255)')
					 , DOT_sp_permit_flag = p.v.value('DOT_sp_permit_flag[1]', 'char(1)')
					 , DOT_shipping_desc_additional = p.v.value('DOT_shipping_desc_additional[1]','VARCHAR(255)')
					 , reportable_quantity_flag = p.v.value('reportable_quantity_flag[1]', 'char(1)')
					 , RQ_threshold = p.v.value('RQ_threshold[1][not(@xsi:nil = "true")]', 'float')
					 , RQ_reason = p.v.value('RQ_reason[1]', 'VARCHAR(50)')
					 , un_na_number = p.v.value('UN_NA_number[1]', 'int')
					 , un_na_flag = p.v.value('UN_NA_flag[1]', 'char(2)')
					 , ERG_number = CASE WHEN @erg_no > 0 THEN @erg_no ELSE NULL END
					 , ERG_suffix = CONVERT(CHAR(2), ISNULL(@getStringDatatype, ''))
					 , subsidiary_haz_mat_class = CASE WHEN LEN(p.v.value('sub_hazmat_class[1]', 'VARCHAR(15)')) > 0
					                                        OR LEN(p.v.value('subsidiary_haz_mat_class[1]', 'VARCHAR(15)')) > 0
															THEN (CONVERT(NVARCHAR(15), ISNULL(p.v.value('sub_hazmat_class[1]', 'VARCHAR(15)'), '') 
															     + ', ' + ISNULL(p.v.value('subsidiary_haz_mat_class[1]', 'VARCHAR(15)'), '')))
													   ELSE NULL
												   END
					 , hazmat_class = p.v.value('hazmat_class[1]', 'VARCHAR(15)')
					 , package_group = p.v.value('package_group[1]', 'CHAR(3)')
					 , emergency_phone_number = p.v.value('emergency_phone_number[1]', 'VARCHAR(20)')
					 , DOT_inhalation_haz_flag = p.v.value('DOT_inhalation_haz_flag[1]', 'char(1)')
					 , container_type_bulk = p.v.value('container_type_bulk[1]', 'char(1)')
					 , container_type_totes = p.v.value('container_type_totes[1]', 'char(1)')
					 , container_type_pallet = p.v.value('container_type_pallet[1]', 'char(1)')
					 , container_type_boxes = p.v.value('container_type_boxes[1]', 'char(1)')
					 , container_type_drums = p.v.value('container_type_drums[1]', 'char(1)')
					 , container_type_cylinder = p.v.value('container_type_cylinder[1]', 'char(1)')
					 , container_type_labpack = p.v.value('container_type_labpack[1]', 'char(1)')
					 , container_type_combination = p.v.value('container_type_combination[1]', 'char(1)')
					 , container_type_combination_desc = p.v.value('container_type_combination_desc[1]', 'VARCHAR(100)')
					 , container_type_other = p.v.value('container_type_other[1]', 'char(1)')
					 , container_type_other_desc = p.v.value('container_type_other_desc[1]', 'VARCHAR(100)')
					 , frequency = p.v.value('frequency[1]', 'VARCHAR(20)')
					 , frequency_other = p.v.value('frequency_other[1]', 'VARCHAR(20)')
				  FROM @Data.nodes('SectionC')p(v)
				 WHERE form_id = @form_id  AND revision_id = @revision_id;

			IF EXISTS (SELECT 1 FROM dbo.FormXWCRContainerSize WHERE form_id = @form_id AND revision_id = @revision_id)
				BEGIN
					DELETE FROM dbo.FormXWCRContainerSize WHERE form_id = @form_id AND revision_id = @revision_id;
				END

			CREATE TABLE #tmpcontainersize (
				   _row INTEGER NOT NULL
				 , form_id INTEGER NOT NULL
				 , revision_id INTEGER NOT NULL
				 , bill_unit_code VARCHAR(50) NOT NULL
				 , is_bill_unit_table_lookup CHAR(1) NOT NULL
				 , date_created DATETIME NOT NULL
				 , date_modified DATETIME NOT NULL
				 , created_by VARCHAR(60) NOT NULL
				 , modified_by VARCHAR(60) NOT NULL
				 );

			INSERT INTO #tmpcontainersize (_row, form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
				 , date_created, date_modified, created_by, modified_by)
			SELECT ROW_NUMBER() OVER (partition by p.v.value('bill_unit_code[1]', 'VARCHAR(50)')
										order by p.v.value('bill_unit_code[1]', 'VARCHAR(50)')) as _row
				 , @form_id as form_id
				 , @revision_id as revision_id
				 , p.v.value('bill_unit_code[1]','VARCHAR(50)') as bill_unit_code
				 , p.v.value('is_bill_unit_table_lookup[1]','char(1)') as is_bill_unit_table_lookup
				 , GETDATE() as date_created
				 , GETDATE() as date_modified
				 , @web_userid as created_by
				 , @web_userid as modified_by
              FROM @Data.nodes('SectionC/container_size/ContainerSize')p(v);

			INSERT INTO dbo.FormXWCRContainerSize (form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
				 , date_created, date_modified, created_by, modified_by)
				SELECT form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
				     , date_created, date_modified, created_by, modified_by
				  FROM #tmpcontainersize
				 WHERE _row =1;

			DROP TABLE #tmpcontainersize;

			IF EXISTS (SELECT 1 FROM dbo.FormXUnit WHERE form_id = @form_id AND revision_id = @revision_id)
				BEGIN
					DELETE FROM dbo.FormXUnit WHERE form_id = @form_id AND revision_id = @revision_id;
				END

			INSERT INTO dbo.FormXUnit(form_type, form_id, revision_id, bill_unit_code, quantity)
				SELECT form_type = 'WCR'
					 , form_id = @form_id
					 , revision_id = @revision_id
					 , bill_unit_code = (SELECT bill_unit_code
										   FROM BillUnit
										  WHERE disposal_flag = 'T'
										    AND bill_unit_code = p.v.value('UnitSize[1]', 'VARCHAR(50)'))
					 , quantity = p.v.value('quantity[1]', 'VARCHAR(255)')
					 --, added_by, date_added, modified_by, date_modified
				  FROM @Data.nodes('SectionC')p(v);
	   END
	END TRY

	BEGIN CATCH
		DECLARE @procedure VARCHAR(150) = ERROR_PROCEDURE()
			  , @error NVARCHAR(4000) = ERROR_MESSAGE();

		DECLARE @error_description NVARCHAR(4000) = 'Form ID: '
					+ CONVERT(NVARCHAR(15), @form_id) 
					+ '-' + CONVERT(NVARCHAR(15), @revision_id)
					+ CHAR(13) + CHAR(13) + 'Error Message: ' + ISNULL(@error, '')
					+ CHAR(13) + CHAR(13) + 'Data:  ' + CONVERT(NVARCHAR(4000), @Data);
														   
		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = 'COR', @object = @procedure, @body = @error_description
	END CATCH		 
END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_C] TO COR_USER;
GO
/*************************************************************************************************/