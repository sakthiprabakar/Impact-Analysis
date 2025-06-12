CREATE PROCEDURE [dbo].[sp_cor_ldr_builder]
(
   
   @LDR_builder_id  int
)

AS

/* ******************************************************************

	Author		: Prabhu
	Updated On	: 18-Feb-2021
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_cor_ldr_builder]

	Description	: Procedure to LDR Builder Report Details

	Input		:  @LDR_builder_id
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_cor_ldr_builder]  2

****************************************************************** */

BEGIN

Select		
 		lb.cust_id,
		lb.cust_name,
		lb.facility_id,
		lb.profit_ctr_id,
		lb.generator_name,
		lb.generator_id,
		lb.facility_name,
		lb.manifest,
		lbl.created_date,
		lbl.created_by,
		lbl.modified_date,
		lbl.modified_by,
		lbl.page,
		lbl.line,
		lbl.ldrbuilder_line_id,
		lbl.approval_code,
		lbl.profile_id,
		lbl.waste_common_name,
		lbl.description,
		lbl.waste_managed_id,
		lbl.Waste_Water_Flag,
		lbl.underlined_text,
		g.EPA_ID,
		g.generator_address_1,
		g.generator_city,
		g.generator_state,
		g.generator_county,
		g.generator_zip_code,


STUFF(
		 (SELECT ',' +lbws.waste_code
		 FROM LDRBuilderWasteCodes lbws
		 where lbws.Ldrbuilder_line_id=lbl.Ldrbuilder_line_id
		 FOR XML PATH(''))
		 ,1, 1, '') AS WasteCodes,

		 STUFF(
		 (SELECT ',' +lbc.const_desc
		 FROM LDRBuilderConstituents lbc
		 where lbc.Ldrbuilder_line_id=lbl.Ldrbuilder_line_id
		 FOR XML PATH(''))
		 ,1, 1, '') AS constituents,

		  STUFF(
		 (SELECT ',' +lbs.short_desc
		 FROM LDRBuilderSubcategory lbs
		 where lbs.Ldrbuilder_line_id=lbl.Ldrbuilder_line_id
		 FOR XML PATH(''))
		 ,1, 1, '') AS categories


	from LDRBuilder lb
	join ldrbuilderlines lbl on lbl.ldr_builder_id =lb.ldr_builder_id
	left join generator g on g.generator_id=lb.generator_id
	where lb.ldr_builder_id =@ldr_builder_id
	
	END

	GO

	GRANT EXECUTE ON [dbo].[sp_cor_ldr_builder] TO COR_USER;

    GO
