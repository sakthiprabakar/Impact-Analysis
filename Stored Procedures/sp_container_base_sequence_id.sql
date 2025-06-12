



/***********************************************************************
The purpose of this SP is to retrieve the containerdestination line or
lines for selection by the user for which container to consolidate into

11/15/06 SCC	Created
06/12/2014 AM - Moved from plt_xx_ai to plt_ai and added company_id to fn_container_stock.

sp_container_base_sequence_id 0, 653915, 1, 3
***********************************************************************/
CREATE PROCEDURE sp_container_base_sequence_id 
    @company_id	int,
	@profit_ctr_id	int,
	@receipt_id	int,
	@line_id	int,
	@container_id	int
AS

SELECT  0 as include,
	CASE WHEN ContainerDestination.container_type = 'R'
	THEN dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id)
	ELSE dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
	END 
 AS Container,
	ContainerDestination.container_id,   
	ContainerDestination.sequence_id,   
	ContainerDestination.container_percent,   
	ContainerDestination.treatment_id,   
	ContainerDestination.location_type,   
	ContainerDestination.location,  
	ContainerDestination.status,  
	Treatment.treatment_desc 
FROM ContainerDestination 
	LEFT OUTER JOIN Treatment ON ContainerDestination.treatment_id = Treatment.treatment_id
		AND ContainerDestination.profit_ctr_id = Treatment.profit_ctr_id
		AND ContainerDestination.company_id = Treatment.company_id
WHERE ContainerDestination.profit_ctr_id = @profit_ctr_id
    AND ContainerDestination.company_id =  @company_id
	AND ContainerDestination.receipt_id = @receipt_id   
	AND ContainerDestination.line_id = @line_id  
	AND ContainerDestination.container_id = @container_id
ORDER BY ContainerDestination.sequence_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_container_base_sequence_id] TO [EQAI]
    AS [dbo];

