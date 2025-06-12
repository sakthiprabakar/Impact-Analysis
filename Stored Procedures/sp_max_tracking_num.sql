CREATE PROCEDURE sp_max_tracking_num
	@company_id int,
	@profit_ctr_id	int,
	@location	varchar(15),
	@tracking_num   varchar(15) OUTPUT
AS
/***************************************************************************************
03/11/2005 SCC	Created
01/18/2010 KAM  Updated the procedure to use company_id as well after moving the tables
				down to PLT_AI

sp_max_tracking_num 21, 0, '701', ''

****************************************************************************************/
DECLARE 
@tracking_num_int int

	SELECT @tracking_num_int = MAX(CONVERT(int, tracking_num)) FROM Batch 
	WHERE location = @location
	AND profit_ctr_id = @profit_ctr_id
	AND company_id = @company_id
	AND IsNumeric(tracking_num) = 1

	IF @tracking_num_int IS NULL
		SET @tracking_num_int = 0
	SET @tracking_num_int = @tracking_num_int + 1
	SELECT @tracking_num = CONVERT(varchar(15), @tracking_num_int)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_max_tracking_num] TO [EQAI]
    AS [dbo];

