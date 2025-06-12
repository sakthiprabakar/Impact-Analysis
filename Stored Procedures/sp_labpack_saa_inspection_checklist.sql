CREATE PROCEDURE [dbo].[sp_labpack_saa_inspection_checklist]
	@SaaInspection_uid INT
AS
-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 01/11/2021
-- Description:	To fetch checklist for SAA inspection
-- EXEC sp_labpack_saa_inspection_checklist 14
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  SELECT * FROM SaainspectionCheckList WHERE SaaInspection_Uid=@SaaInspection_uid
END
GO

