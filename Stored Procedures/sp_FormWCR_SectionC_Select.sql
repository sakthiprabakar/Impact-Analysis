
CREATE PROCEDURE [dbo].[sp_FormWCR_SectionC_Select]
     @formId int = 0,
	 @revision_Id INT 
AS

/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionC_Select]


	Procedure to select Section C related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionC_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionC_Select] 513247, 1

****************************************************************** */
--declare
--     @formId int = 427645,
--	 @revision_Id INT =1

BEGIN

--declare      @formId int = 0,
--	 @revision_Id INT ;

DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND section='SC' 
	
	--FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS; 


		SELECT
	    (SELECT ISNULL(SectionC.hazmat_flag,'') AS hazmat_flag,	   
	    ISNULL(SectionC.DOT_waste_flag,'') AS DOT_waste_flag,
		case when EXISTS(select REPLACE(SectionC.dot_shipping_name, 'waste', '') WHERE SectionC.dot_shipping_name like 'waste%') 
			then 
			ltrim(ISNULL((select REPLACE(SectionC.dot_shipping_name, 'waste', '') WHERE SectionC.dot_shipping_name like 'waste%'), ''))
			else 
			ltrim(ISNULL(SectionC.dot_shipping_name, ''))
		end  AS dot_shipping_name,
		ISNULL(SectionC.DOT_sp_permit_text,'') AS DOT_sp_permit_text,
		ISNULL(SectionC.DOT_sp_permit_flag,'') AS DOT_sp_permit_flag,
		ISNULL(SectionC.DOT_shipping_desc_additional,'') AS DOT_shipping_desc_additional,ISNULL(SectionC.reportable_quantity_flag,'') AS reportable_quantity_flag,
		ISNULL(SectionC.RQ_reason,'') AS RQ_reason ,
		@section_status AS IsCompleted,
		--CAST(CAST(ISNULL(SectionC.RQ_threshold,0)   AS FLOAT) AS bigint) AS RQ_threshold,
		ISNULL(convert(varchar(10),RQ_threshold),'') as RQ_threshold,
		--ISNULL(SectionC.UN_NA_flag,'') AS UN_NA_flag ,
		ISNULL(SectionC.UN_NA_flag,'')+CAST(ISNULL(SectionC.UN_NA_number,'')AS VARCHAR) AS [description] ,
		ISNULL(SectionC.UN_NA_flag,'') as UN_NA_flag, ISNULL(CAST(SectionC.UN_NA_number AS VARCHAR),'') AS UN_NA_number ,
		ISNULL(SectionC.ERG_suffix ,'') AS ERG_suffix,
		(select ISNULL([row],'') from [dbo].[fn_SplitXsvText](',',1,SectionC.subsidiary_haz_mat_class)  ORDER BY Idx OFFSET (0) ROWS FETCH NEXT (1) ROWS ONLY) AS sub_hazmat_class,
		(select ISNULL([row],'') from [dbo].[fn_SplitXsvText](',',1,SectionC.subsidiary_haz_mat_class)  ORDER BY Idx OFFSET (1) ROWS FETCH NEXT (1) ROWS ONLY) AS subsidiary_haz_mat_class,
		-- ISNULL(SectionC.subsidiary_haz_mat_class,'') AS sub_hazmat_class ,
		--ISNULL(SectionC.subsidiary_haz_mat_class,'') AS subsidiary_haz_mat_class ,
		--ISNULL(SectionC.UN_NA_number,'') AS UN_NA_number ,
		concat(SectionC.ERG_number,SectionC.ERG_suffix) AS ERG_number,ISNULL(SectionC.hazmat_class,'') AS hazmat_class ,ISNULL(SectionC.package_group,'') AS package_group ,ISNULL(SectionC.emergency_phone_number,'') AS emergency_phone_number ,
		ISNULL(SectionC.DOT_inhalation_haz_flag ,'') AS DOT_inhalation_haz_flag,ISNULL(SectionC.container_type_bulk,'') AS container_type_bulk ,ISNULL(SectionC.container_type_totes,'') AS container_type_totes ,ISNULL(SectionC.container_type_pallet,'') AS container_type_pallet ,ISNULL(SectionC.container_type_boxes ,'') AS container_type_boxes,ISNULL(SectionC.container_type_drums,'') AS container_type_drums ,ISNULL(SectionC.container_type_cylinder,'') AS container_type_cylinder ,ISNULL(SectionC.container_type_labpack,'') AS container_type_labpack ,ISNULL(SectionC.container_type_combination,'') AS container_type_combination ,ISNULL(SectionC.container_type_combination_desc,'') AS container_type_combination_desc ,ISNULL(SectionC.container_type_other,'') AS container_type_other ,ISNULL(SectionC.container_type_other_desc,'') AS container_type_other_desc ,ISNULL(SectionC.frequency ,'') AS frequency ,ISNULL(SectionC.frequency_other,'') AS  frequency_other,
		ISNULL((SELECT top 1 ISNULL(Units.bill_unit_code,'')
		FROM FormXUnit as Units
		WHERE  Units.form_id = SectionC.form_id and Units.revision_id = SectionC.revision_id),'') as UnitSize,
		ISNULL((SELECT top 1 ISNULL(Qty.quantity,'')
		FROM FormXUnit as Qty
		WHERE  Qty.form_id = SectionC.form_id and Qty.revision_id = SectionC.revision_id),'') as quantity
	 

	FROM FormWCR AS SectionC
	Where SectionC.form_id =  @formId AND revision_id = @revision_Id  FOR XML PATH(''), TYPE) ,
	   (SELECT cs.bill_unit_code,
	   ISNULL((SELECT TOP 1 B.bill_unit_desc FROM BillUnit B WHERE  container_flag = 'T' AND disposal_flag = 'T' AND cs.is_bill_unit_table_lookup='T' AND B.bill_unit_code = cs.bill_unit_code),cs.bill_unit_code) bill_unit_desc,cs.is_bill_unit_table_lookup FROM FormXWCRContainerSize cs --BillUnit B
--JOIN FormXWCRContainerSize cs ON cs	.bill_unit_code=B.bill_unit_code
WHERE  cs.form_id=@formId AND cs.revision_id = @revision_Id FOR XML PATH('container_size'), TYPE) 
		FOR XML PATH('SectionC'), ROOT('ProfileModel') 

END

GO

	GRANT EXEC ON [dbo].[sp_FormWCR_SectionC_Select] TO COR_USER;

GO


