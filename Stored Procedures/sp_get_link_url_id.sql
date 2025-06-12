/************************************************************
Procedure    : sp_get_link_url_id
Database     : PLT_AI*
Created      : Wed May 04 09:34:48 EDT 2005 - Jonathan Broome
Description  : Returns a random # that is unique in the Link
				table's url_id field.  This value can then be
				used for future inserts.
************************************************************/
CREATE PROCEDURE sp_get_link_url_id
AS
	DECLARE @length as int
	DECLARE @JulianDay as bigint
	DECLARE @mseconds_of_day float
	DECLARE @MicroJulianTime as float
	DECLARE @longstring as varchar(255)
	DECLARE @count as int
	SET NOCOUNT ON
	SET @length = 15
	SET @count = 1
	WHILE @count > 0
	BEGIN
		SELECT @JulianDay = DATEDIFF(D,'12/31/2000',GETDATE())+730485
		select @mseconds_of_day = DATEDIFF(MS,convert(varchar(4),DATEPART(yyyy, GETDATE())) + '-' + convert(varchar(2),DATEPART(mm, GETDATE())) + '-' + convert(varchar(2),DATEPART(dd, GETDATE())) + ' 00:00:00.000', GETDATE()) + 1
		select @MicroJulianTime = @mseconds_of_day / 86400000
		SELECT @longstring = replace(convert(varchar(100),@JulianDay,2) + convert(varchar(155),@MicroJulianTime,2),'.','')
		SELECT @count = count(*) from link where url_id = convert(bigint,left(@longstring,@length))
		SET NOCOUNT OFF
	END
	SELECT left(@longstring,@length) as url_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_link_url_id] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_link_url_id] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_link_url_id] TO [EQAI]
    AS [dbo];

