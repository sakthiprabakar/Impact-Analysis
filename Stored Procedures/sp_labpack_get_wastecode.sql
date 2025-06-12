-- =============================================
-- Author:		SENTHIL KUMAR
-- Create date: 25-08-2020
-- Description:	To Get waste details by searchText
-- EXEC sp_labpack_get_wastecode 'D001'
-- =============================================
CREATE PROCEDURE sp_labpack_get_wastecode
			@searchText varchar(200)
AS
BEGIN
	set transaction isolation level read uncommitted

	SELECT * FROM WasteCode WHERE Status='A' AND waste_code = @searchText
END
GO