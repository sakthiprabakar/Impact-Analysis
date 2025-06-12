CREATE PROCEDURE [dbo].[sp_labpack_maa_inspection_checklist]
	@MaaInspection_uid INT
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 01/11/2021
-- Description:	To fetch checklist for MAA inspection
-- EXEC sp_labpack_Maa_inspection_checklist 14
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  SELECT * FROM MaainspectionCheckList WHERE MaaInspection_Uid=@MaaInspection_uid
END
GO
