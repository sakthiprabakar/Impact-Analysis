CREATE PROCEDURE sp_labpack_maa_inspection_detail
	@MaaInspection_uid INT
AS
-- =============================================
-- Author:		Senthil kumar
-- Create date: 01/11/2021
-- Description:	To fetch to MAA inspection details
-- EXEC sp_labpack_maa_inspection_detail 14
-- =============================================
BEGIN

	SET NOCOUNT ON;

   SELECT  maaInspection_uid,maaIns.mainAccumulationArea_uid,maa.Description, maaIns.customer_id,cst.cust_name,inspection_date,
maaIns.added_by,maaIns.date_added,
maaIns.modified_by,maaIns.date_modified,0 total_count,'MAA' type,dbo.fn_labpack_get_maa_score(maaInspection_uid) score FROM MAAInspection maaIns
LEFT JOIN customer cst on cst.customer_id=maaIns.customer_id
LEFT JOIN mainAccumulationArea maa on maa.mainAccumulationArea_uid=maaIns.mainAccumulationArea_uid
WHERE maaInspection_uid=@MaaInspection_uid
END
GO
