	CREATE PROCEDURE [dbo].[sp_ProfitCenterSelect] 
	    @company_id int = NULL,
	    @profit_ctr_id int = NULL,
	    @waste_receipt_flag char(1) = NULL,
	    @workorder_flag char(1) = NULL
/*	
	Description: 
	Returns co/pc information

	Revision History:
	??/01/2009	RJG 	Created
*/			
	AS 
	
	SET NOCOUNT ON
	
	IF @company_id IS NOT NULL AND @profit_ctr_id IS NOT NULL
	BEGIN
		SELECT 
			p.company_id, 
			p.profit_ctr_id, 
			p.profit_ctr_name, 
			p.waste_receipt_flag, 
			p.workorder_flag,
			cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
			RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key		
		FROM Company c
		INNER JOIN ProfitCenter p 
			ON c.company_id = p.company_id 
			and p.status = 'A'	
		WHERE p.company_id = @company_id
		AND p.profit_ctr_id = @profit_ctr_id
		AND p.waste_receipt_flag = COALESCE(@waste_receipt_flag, p.waste_receipt_flag)
		AND p.workorder_flag = COALESCE(@workorder_flag, p.workorder_flag)
		ORDER BY p.company_ID, p.profit_ctr_ID, p.profit_ctr_name
	END
	ELSE
	BEGIN
		SELECT 
			p.company_id, 
			p.profit_ctr_id, 
			p.profit_ctr_name, 
			p.waste_receipt_flag, 
			p.workorder_flag,
			cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
			RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key		
		FROM Company c
		INNER JOIN ProfitCenter p 
			ON c.company_id = p.company_id 
			and p.status = 'A'
		WHERE p.waste_receipt_flag = COALESCE(@waste_receipt_flag, p.waste_receipt_flag)
		AND p.workorder_flag = COALESCE(@workorder_flag, p.workorder_flag)			
		ORDER BY p.company_ID, p.profit_ctr_ID, p.profit_ctr_name
	END	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfitCenterSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfitCenterSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfitCenterSelect] TO [EQAI]
    AS [dbo];

