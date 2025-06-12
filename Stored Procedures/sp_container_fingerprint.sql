CREATE PROCEDURE sp_container_fingerprint
	@base_company_id int,
	@base_profit_ctr_id int,
	@base_receipt_id int,
	@base_line_id int,
	@base_container_id int
AS
/****************
This SP controls populating historical data to store waste codes and constituents with base containers

07/21/2009 KAM	Created
08/19/2015 RWB	This was never migrated from Plt_XX_ai, and barcode scanner has been display false errors
		Added @base_company_id argument

sp_container_fingerprint 21,0,727123,1,1
sp_container_fingerprint 21,0,0,2837,2837
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	@return_status char(1),
		@other_count int

set @other_count = (Select Count(*) 
from Container
where company_id = @base_company_id
	and profit_ctr_id = @base_profit_ctr_id
	and line_id = @base_line_id
	and container_id = @base_container_id)

If @other_count > 0
Begin
	CREATE TABLE #included_in_base (
		company_id int,
		profit_ctr_id int,
		receipt_id int,
		line_id int,
		container_id int)
	
	
	EXEC sp_container_fingerprint_populate @base_company_id, @base_profit_ctr_id, @base_receipt_id, @base_line_id, @base_container_id
	
	
	SET @other_count = (SELECT COUNT(DISTINCT fingerpr_status) FROM #included_in_base JOIN receipt ON receipt.company_id = #included_in_base.company_id AND
																								receipt.profit_ctr_id = #included_in_base.profit_ctr_id AND
	 																							receipt.receipt_id = #included_in_base.receipt_id AND
																								receipt.line_id = #included_in_base.line_id)
--	print 'Disinct status count ' + cast(@other_count as Varchar(10))
	
	IF @other_count > 1 
		SET @return_status = 'M'  -- Mixed
	ELSE
		SET @return_status = (SELECT DISTINCT fingerpr_status FROM #included_in_base JOIN receipt ON receipt.company_id = #included_in_base.company_id AND
																								receipt.profit_ctr_id = #included_in_base.profit_ctr_id AND
																								receipt.receipt_id = #included_in_base.receipt_id AND
																								receipt.line_id = #included_in_base.line_id)

-- SELECT * FROM #included_in_base

-- print 'Temp table Rowcount = ' + cast(@@rowcount as varchar(10))

END
Else
	Set @return_status = 'X'


SELECT @return_status
RETURN 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_fingerprint] TO [EQAI]
    AS [dbo];

