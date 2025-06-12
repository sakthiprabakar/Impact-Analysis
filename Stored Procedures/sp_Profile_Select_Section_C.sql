
CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_C]
     @profileid int
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_C]

	Description	: 
                  Procedure to get SECTION C profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_C] 414507

*************************************************************************************/

-- Bill unit code and volume
Declare @quantity varchar(255)
Declare @bill_unit_code varchar(4)

SELECT top 1  @quantity=quantity,@bill_unit_code=bill_unit_code from ProfileShippingUnit where profile_id=@profileid

	SELECT 
	ISNULL(SectionC.hazmat,'') AS hazmat_flag,
	ISNULL(SectionC.DOT_waste_flag,'') AS DOT_waste_flag,
	ISNULL(SectionC.DOT_shipping_name,'') AS dot_shipping_name,
	ISNULL(SectionC.DOT_sp_permit_text,'') AS DOT_sp_permit_text,
	ISNULL(SectionC.DOT_sp_permit_flag,'') AS DOT_sp_permit_flag,
	ISNULL(SectionC.DOT_shipping_desc_additional,'') AS DOT_shipping_desc_additional,
	ISNULL(SectionC.reportable_quantity_flag,'') AS reportable_quantity_flag,
	ISNULL(SectionC.RQ_reason,'') AS RQ_reason,
	ISNULL(CONVERT(nvarchar(50),CONVERT(numeric(16,0),CAST(SectionC.RQ_threshold AS FLOAT))),'') AS RQ_threshold,
	--ISNULL(SectionC.UN_NA_flag,'') AS UN_NA_flag,
	--ISNULL(SectionC.UN_NA_number,'') AS UN_NA_number ,
	ISNULL(SectionC.UN_NA_flag,'')+CAST(ISNULL(SectionC.UN_NA_number,'')AS VARCHAR) AS [description] ,
	ISNULL(SectionC.UN_NA_flag,'') as UN_NA_flag, CAST(ISNULL(SectionC.UN_NA_number,'')AS VARCHAR) AS UN_NA_number ,
	ISNULL(SectionC.hazmat_class,'') AS hazmat_class ,
	ISNULL(SectionC.subsidiary_haz_mat_class,'') AS subsidiary_haz_mat_class ,
	ISNULL(SectionC.package_group,'') AS package_group ,
	ISNULL(SectionC.ERG_number ,'') AS ERG_number,
	ISNULL(SectionC.ERG_number ,'') AS ERG_suffix,
	Case
		When (SectionC.emergency_phone_number ='' or SectionC.emergency_phone_number is null) Then GN.emergency_phone_number
		ELSE  SectionC.emergency_phone_number
	END  AS emergency_phone_number,
	--ISNULL(SectionC.emergency_phone_number,'') AS emergency_phone_number ,
	ISNULL(SectionC.DOT_inhalation_haz_flag ,'') AS DOT_inhalation_haz_flag,
	ISNULL(SectionC.container_type_bulk,'') AS container_type_bulk ,
	ISNULL(SectionC.container_type_totes,'') AS container_type_totes ,
	ISNULL(SectionC.container_type_pallet,'') AS container_type_pallet ,
	ISNULL(SectionC.container_type_boxes ,'') AS container_type_boxes,
	ISNULL(SectionC.container_type_drums,'') AS container_type_drums ,
	ISNULL(SectionC.container_type_cylinder,'') AS container_type_cylinder ,
	ISNULL(SectionC.container_type_labpack,'') AS container_type_labpack ,
	ISNULL(SectionC.container_type_combination,'') AS container_type_combination ,
	ISNULL(SectionC.container_type_combination_desc,'') AS container_type_combination_desc ,
	ISNULL(SectionC.container_type_other,'') AS container_type_other ,
	ISNULL(SectionC.container_type_other_desc,'') AS container_type_other_desc ,
	ISNULL(SectionC.shipping_frequency_other,'') AS  frequency_other,
	ISNULL(SectionC.shipping_frequency ,'') AS frequency ,
	ISNULL(@quantity,'') AS quantity,
	ISNULL(@bill_unit_code,'') AS UnitSize,
	(SELECT ps.bill_unit_code,
 ISNULL((SELECT TOP 1 B.bill_unit_desc FROM BillUnit B WHERE  B.bill_unit_code = ps.bill_unit_code),ps.bill_unit_code) bill_unit_desc,
		ps.is_bill_unit_table_lookup 
	FROM ProfileContainerSize ps 
WHERE  ps.profile_id=@profileid FOR XML PATH('container_size'), TYPE)
	FROM Profile AS SectionC
	LEFT JOIN  Generator AS GN ON SectionC.generator_id=GN.generator_id
	--LEFT JOIN  ProfileQuoteHeader AS PQH ON SectionC.profile_id= PQH.profile_id

	 Where SectionC.profile_id =  @profileid
	 FOR XML RAW ('SectionC'), ROOT ('ProfileModel'), ELEMENTS

	GO

GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_C] TO COR_USER;

GO


