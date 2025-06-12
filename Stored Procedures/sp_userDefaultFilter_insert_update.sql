CREATE PROCEDURE [dbo].[sp_userDefaultFilter_insert_update]
	-- Add the parameters for the stored procedure here
	 @Data XML,
	 @Message nvarchar(100) Output
AS
/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 12th Aug 2019
	Type			: Stored Procedure
	Object Name		: [sp_userDefaultFilter_insert_update]


	Procedure to insert update user default filter settings

inputs 
	
	@Data
	
Samples:
 EXEC [sp_userDefaultFilter_insert_update] @Data,@Message

 DECLARE @Message nvarchar(100)
 EXEC [sp_userDefaultFilter_insert_update] 
 '<FilterModel xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
 <GeneratorIds>180669,126414</GeneratorIds>
 <CustomerIds>15622</CustomerIds>
 <WebUserId>manand</WebUserId>
 </FilterModel>',@Message OUT
  SELECT @Message
***********************************************************************/
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	Declare @web_userid NVARCHAR(200) = (SELECT p.v.value('WebUserId[1]','VARCHAR(100)') from @Data.nodes('FilterModel')p(v)),
	@GeneratorIds NVARCHAR(MAX)= (SELECT p.v.value('GeneratorIds[1]','VARCHAR(MAX)') from @Data.nodes('FilterModel')p(v)),
	@CustomerIds NVARCHAR(MAX)= (SELECT p.v.value('CustomerIds[1]','VARCHAR(MAX)') from @Data.nodes('FilterModel')p(v)),
	@filter_JSON NVARCHAR(MAX)= (SELECT p.v.value('filter_JSON[1]','VARCHAR(MAX)') from @Data.nodes('FilterModel')p(v)),

	@GeneratorFilterSettingId INT=(SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings WHERE FilterColumnName='GeneratorName'),
	@CustomerFilterSettingId INT=(SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings WHERE FilterColumnName='CustomerName'),
	@filter_JSON_SettingId int = (SELECT DefaultFilterSettingId FROM COR_DB..DefaultFilterSettings WHERE FilterColumnName='filter_JSON')
	

	-- Generator Name default settings
    IF(NOT EXISTS(SELECT * FROM COR_DB..UserDefaultFilterSettings  WHERE web_userid = @web_userId   AND DefaultFilterSettingId= @GeneratorFilterSettingId))
	BEGIN
		INSERT INTO COR_DB..UserDefaultFilterSettings VALUES (@GeneratorFilterSettingId,@web_userid,@GeneratorIds,@web_userid,GETDATE(),@web_userid,GETDATE(),NULL)
	END
	ELSE
	BEGIN
		UPDATE  COR_DB..UserDefaultFilterSettings SET [FileterValue]=@GeneratorIds,[date_modified]=GETDATE(),[modified_by]=@web_userid WHERE DefaultFilterSettingId=@GeneratorFilterSettingId AND [web_userid]=@web_userid
	END

	-- Customer Name default settings
	IF(NOT EXISTS(SELECT * FROM COR_DB..UserDefaultFilterSettings  WHERE web_userid = @web_userId   AND DefaultFilterSettingId= @CustomerFilterSettingId))
	BEGIN
		INSERT INTO COR_DB..UserDefaultFilterSettings VALUES (@CustomerFilterSettingId,@web_userid,@CustomerIds,@web_userid,GETDATE(),@web_userid,GETDATE(),NULL)
	END
	ELSE
	BEGIN
		UPDATE  COR_DB..UserDefaultFilterSettings SET [FileterValue]=@CustomerIds,[date_modified]=GETDATE(),[modified_by]=@web_userid WHERE DefaultFilterSettingId=@CustomerFilterSettingId AND [web_userid]=@web_userid
	END

	IF(NOT EXISTS(SELECT * FROM COR_DB..UserDefaultFilterSettings  WHERE web_userid = @web_userId  AND DefaultFilterSettingId= @filter_JSON_SettingId))
	BEGIN
		INSERT INTO COR_DB..UserDefaultFilterSettings VALUES (@filter_JSON_SettingId,@web_userid,@filter_JSON,@web_userid,GETDATE(),@web_userid,GETDATE(),NULL)
	END
	ELSE
	BEGIN
		UPDATE  COR_DB..UserDefaultFilterSettings SET [FileterValue]=@filter_JSON,[date_modified]=GETDATE(),[modified_by]=@web_userid WHERE DefaultFilterSettingId=@filter_JSON_SettingId AND [web_userid]=@web_userid
	END

	SET @Message = 'Filter saved successfully';
END

GO
GRANT EXECUTE ON [dbo].sp_userDefaultFilter_insert_update TO COR_USER;

GO