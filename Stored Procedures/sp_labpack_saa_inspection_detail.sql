CREATE PROCEDURE sp_labpack_saa_inspection_detail
	@SaaInspection_uid INT
AS
-- =============================================
-- Author:		Senthil kumar
-- Create date: 01/11/2021
-- Description:	To fetch to SAA inspection details
-- EXEC sp_labpack_saa_inspection_detail 14
-- =============================================
BEGIN

	SET NOCOUNT ON;
SELECT  saaInspection_uid,saaIns.satelliteAccumulationArea_uid,saa.Description,saaIns.customer_id,cst.cust_name,inspection_date,saaIns.added_by,saaIns.date_added,
saaIns.modified_by,saaIns.date_modified,0 total_count,'SAA' type,dbo.fn_labpack_get_saa_score(saaInspection_uid) score  FROM SAAInspection saaIns
LEFT JOIN customer cst on cst.customer_id=saaIns.customer_id
LEFT JOIN satelliteAccumulationArea saa on saa.satelliteAccumulationArea_uid=saaIns.satelliteAccumulationArea_uid
WHERE saaInspection_uid=@SaaInspection_uid
END
GO

