USE [PLT_AI]
GO
/**********************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update_section_C] 
GO 
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_C]

       @Data XML,
	   @form_id int,
	   @revision_id int,
	   @web_userid varchar(100)
AS
/* ******************************************************************

Insert / update Section C form  (Part of form wcr insert / update)
* ******************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns
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
begin try
DECLARE @UN_NA varchar(255),@ERGVALUE VARCHAR(200);
SELECT
@ERGVALUE =p.v.value('ERG_number[1]','VARCHAR(200)')
FROM @Data.nodes('SectionC')p(v)
DECLARE @Ass_UN_NA_number varchar(1000) =@UN_NA;
declare @Counter integer = 1;
declare @currChar char(1) = '';;
declare @UNNA_flag varchar(1000) = '';
declare @UNNA_number varchar(1000) = '';
DECLARE @splitStringLength INT 
SET @splitStringLength = LEN(@ERGVALUE) 
DECLARE @countnum INT
SET @countnum = 0  
DECLARE @getIntDatatype NVARCHAR(10)
DECLARE @getStringDatatype NVARCHAR(10) 
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
while (@Counter <= len(@Ass_UN_NA_number))
begin
 set @currChar = substring(@Ass_UN_NA_number,@Counter,1)
   if isNumeric(@currChar) = 1
          set @UNNA_number = @UNNA_number + @currChar
   else
       set @UNNA_flag = @UNNA_flag + @currChar

  set @counter = @counter + 1
end
IF(EXISTS(SELECT * FROM FormWCR  WITH(NOLOCK)  WHERE form_id = @form_id AND revision_id = @revision_id))
BEGIN
declare @erg_no int = (SELECT CONVERT(INT, ISNULL(@getIntDatatype, 0)))
UPDATE  FormWCR
        SET
			hazmat_flag = p.v.value('hazmat_flag[1]','char(1)'),
			DOT_waste_flag = p.v.value('DOT_waste_flag[1]','char(1)'),
			dot_shipping_name =	p.v.value('dot_shipping_name[1]','varchar(255)'),
			DOT_sp_permit_text = p.v.value('DOT_sp_permit_text[1]','varchar(255)'),
			DOT_sp_permit_flag =  p.v.value('DOT_sp_permit_flag[1]','char(1)'),
			DOT_shipping_desc_additional = p.v.value('DOT_shipping_desc_additional[1]','varchar(255)'),
			reportable_quantity_flag = p.v.value('reportable_quantity_flag[1]','char(8)'),
			RQ_threshold = p.v.value('RQ_threshold[1][not(@xsi:nil = "true")]','float'),
			RQ_reason = p.v.value('RQ_reason[1]','varchar(50)'),
			un_na_number = p.v.value('UN_NA_number[1]','int'),
			un_na_flag = p.v.value('UN_NA_flag[1]','char(2)'),
			ERG_number = case when @erg_no > 0 then @erg_no else null end, -- CONVERT(INT, ISNULL(@getIntDatatype, 0)),
			ERG_suffix = CONVERT(NVARCHAR(100), ISNULL(@getStringDatatype, '')),
			subsidiary_haz_mat_class = 
			case when LEN(p.v.value('sub_hazmat_class[1]','varchar(15)')) > 0 OR LEN(p.v.value('subsidiary_haz_mat_class[1]','varchar(15)')) > 0
			THEN
				(CONVERT(NVARCHAR(15), coalesce(p.v.value('sub_hazmat_class[1]','varchar(15)'), '') +  ', ' + coalesce(p.v.value('subsidiary_haz_mat_class[1]','varchar(15)'), '')))
			ELSE NULL END,
			hazmat_class = p.v.value('hazmat_class[1]','varchar(15)'),
			package_group = p.v.value('package_group[1]','varchar(3)'),
			emergency_phone_number = p.v.value('emergency_phone_number[1]','varchar(20)'),
			DOT_inhalation_haz_flag = p.v.value('DOT_inhalation_haz_flag[1]','char(1)'),
			container_type_bulk = p.v.value('container_type_bulk[1]','char(1)'),
			container_type_totes = p.v.value('container_type_totes[1]','char(1)'),
			container_type_pallet = p.v.value('container_type_pallet[1]','char(1)'),
			container_type_boxes = p.v.value('container_type_boxes[1]','char(1)'),
			container_type_drums = p.v.value('container_type_drums[1]','char(1)'),
			container_type_cylinder = p.v.value('container_type_cylinder[1]','char(1)'),
			container_type_labpack = p.v.value('container_type_labpack[1]','char(1)'),
			container_type_combination = p.v.value('container_type_combination[1]','char(1)'),
			container_type_combination_desc = p.v.value('container_type_combination_desc[1]','varchar(100)'),
			container_type_other = p.v.value('container_type_other[1]','char(1)'),
			container_type_other_desc = p.v.value('container_type_other_desc[1]','varchar(100)'),
			frequency  = p.v.value('frequency[1]','varchar(20)'),
			frequency_other  = p.v.value('frequency_other[1]','varchar(20)')
        FROM
        @Data.nodes('SectionC')p(v) WHERE form_id = @form_id  AND revision_id = @revision_id
		IF(EXISTS(SELECT * FROM FormXWCRContainerSize WHERE  form_id=@form_id AND revision_id= @revision_id))
		BEGIN
			DELETE FROM FormXWCRContainerSize WHERE  form_id=@form_id AND revision_id= @revision_id
		END
		SELECT
			  row_number() over(partition by  p.v.value('bill_unit_code[1]','varchar(50)') order by p.v.value('bill_unit_code[1]','varchar(50)')) as _row,
			   form_id=@form_id,
			   revision_id= @revision_id,
			   bill_unit_code = p.v.value('bill_unit_code[1]','varchar(50)'),
			   is_bill_unit_table_lookup =  p.v.value('is_bill_unit_table_lookup[1]','char(1)'),
			   date_created = GETDATE(),
			   date_modified = GETDATE(),
			   created_by = @web_userid,
			   modified_by = @web_userid
			   into #tmpcontainersize
              FROM
              @Data.nodes('SectionC/container_size/ContainerSize')p(v)
	INSERT INTO FormXWCRContainerSize(form_id,revision_id,bill_unit_code,is_bill_unit_table_lookup,date_created,date_modified,created_by,modified_by)
	SELECT form_id,revision_id,bill_unit_code,is_bill_unit_table_lookup,date_created,date_modified,created_by,modified_by FROM  #tmpcontainersize where _row =1

	IF(EXISTS(SELECT * FROM FormXUnit WHERE  form_id=@form_id AND revision_id= @revision_id))
		BEGIN
			DELETE FROM FormXUnit WHERE  form_id=@form_id AND revision_id= @revision_id
		END
		INSERT INTO FormXUnit(form_id,form_type,revision_id,bill_unit_code,quantity)
              SELECT
			   form_id=@form_id,
			   form_type = 'WCR',--p.v.value('form_type[1]','varchar(10)'),
			   revision_id = @revision_id,
			   bill_unit_code =(SELECT bill_unit_code FROM BillUnit  WITH(NOLOCK)  WHERE disposal_flag = 'T' AND bill_unit_code=p.v.value('UnitSize[1]','varchar(50)')),
			   quantity = p.v.value('quantity[1]','varchar(255)')  
              FROM
              @Data.nodes('SectionC')p(v)
	   END
	end try
	begin catch
				declare @procedure nvarchar(150) 
				declare @mailTrack_userid nvarchar(60) = 'COR'
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
	end catch		 
END
GO
	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_C] TO COR_USER;
GO
/*************************************************************************************************/