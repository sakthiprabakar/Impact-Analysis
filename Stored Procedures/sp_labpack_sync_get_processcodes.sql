USE [PLT_AI]
GO

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_get_processcodes')
	drop procedure sp_labpack_sync_get_processcodes
go

CREATE PROCEDURE [dbo].[sp_labpack_sync_get_processcodes]
	@last_sync_dt datetime = '01/01/2000'
AS
-- =============================================
-- Author:		Senthil Kumar
-- Create date: 26-05-2020
-- Description:	To fetch labpack process codes
--
-- EXEC sp_labpack_sync_get_processcodes
-- EXEC sp_labpack_sync_get_processcodes '03/01/2021 11:56:32'
--
-- 06/10/2021 - rwb - Added date_added and date_modified so LPx can determine new/modified 
-- =============================================
BEGIN
	set transaction isolation level read uncommitted

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   SELECT 
   process_code_uid,
   process_code,
   process_code_definition,
   LTRIM(ISNULL(UN_NA_flag,'')+UN_NA_Number) as NoS,
   constituents_decription AS ChemId,
   LDR_subcategory_1 AS subcategory_id_1,
   (SELECT short_desc from ldrsubcategory where status='A' and subcategory_id=LDR_subcategory_1)LDR_short_desc_1,
   LDR_subcategory_2 AS subcategory_id_2, 
   (SELECT short_desc from ldrsubcategory where status='A' and subcategory_id=LDR_subcategory_2)LDR_short_desc_2,
   RCRA_Code_1 AS waste_code_uid_1,
   (select display_name from wastecode where status='A' and waste_code_uid=RCRA_Code_1)wastecode_1,
   RCRA_Code_2 AS waste_code_uid_2,
   (select display_name from wastecode where status='A' and waste_code_uid=RCRA_Code_2)wastecode_2,
   RCRA_Code_3 AS waste_code_uid_3,
   (select display_name from wastecode where status='A' and waste_code_uid=RCRA_Code_3)wastecode_3,
   RCRA_Code_4 AS waste_code_uid_4,
   (select display_name from wastecode where status='A' and waste_code_uid=RCRA_Code_4)wastecode_4,
   LDR_flag,
   consistency,
   bill_unit_code,
   (select bill_unit_desc from billunit  bu where bu.manifest_unit is not null and bu.bill_unit_code=lbpc.bill_unit_code)bill_unit_desc,
   label,
   packing_group,
   EPA_Form_Code,
   EPA_Source_code,
   management_code,
   TIN,
   date_added,
   date_modified
   FROM labpackprocesscode lbpc
   WHERE  [status]='A'
   AND (date_added > @last_sync_dt or date_modified > @last_sync_dt)
END
GO

grant execute on sp_labpack_sync_get_processcodes to eqai
go
