CREATE PROCEDURE sp_resources_available
	@company_id		int
AS
/***************************************************************************************
This SP returns resources that have never been assigned to resourceclass BOXDROP or 
FRACDROP, or that have not been assigned to BOXDROP or FRACDROP later than they have
been assigned to resourceclass BOXPICK or FRACPICK

PB Object:	r_resources_available

02/15/2002 JDB	Created
11/11/2004 MK	Changed generator_code to generator_id
05/05/2005 MK	Added epa_id and generator_name to final select
12/10/2010 SK	Added company_id as input arg, added joins to company_id
				Moved to Plt_AI

sp_resources_available 14
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	
@workorder_id 			int,
@workorder_id_max 		int,
--@profit_ctr_id 			int,
--@profit_ctr_id_max 		int,
--@profit_ctr_name		varchar(50),
@resource_assigned 		varchar(10),
@resource_assigned_max 	varchar(10),
@resource_class_code 	varchar(10),
@generator_id	 		int,
@start_date_dropped 	datetime,
@start_date_picked 		datetime,
@date_difference 		int,
@count_dropped 			int,
@count_picked 			int,
@company_name 			varchar(35),
@customer_id 			int

SET NOCOUNT ON

CREATE TABLE #resource_picked (
company_name 			varchar(35) 	NULL,
workorder_id 			int 			NULL,
--profit_ctr_id 			int 			NULL,
--profit_ctr_name			varchar(50)		NULL,
resource_code 			varchar(10) 	NULL,
resource_class_code 	varchar(10) 	NULL,
generator_id 			int 			NULL,
start_date 				datetime 		NULL,
customer_id 			int 			NULL )

SELECT @company_name = company_name FROM company WHERE company_id = @company_id

SELECT DISTINCT Resource.resource_code 
INTO #resource_code
FROM resource , ResourceXResourceClass rxrc
WHERE resource.resource_code = rxrc.resource_code
AND rxrc.resource_class_code IN ('FRACDROP', 'BOXDROP', 'FRACPICK', 'BOXPICK')
AND resource_status = 'A'
AND resource.company_id = rxrc.resource_company_id

--SELECT @profit_ctr_id = -1
--SELECT @profit_ctr_id_max = MAX(profit_ctr_id) FROM ProfitCenter WHERE company_ID = @company_id
/********************************************************************************************/
--ProfitCenter:
--SELECT @profit_ctr_id = MIN(profit_ctr_id) 
--FROM ProfitCenter
--WHERE profit_ctr_id > @profit_ctr_id
-- AND company_ID = @company_id

--SELECT @profit_ctr_name = profit_ctr_name FROM ProfitCenter 
--WHERE profit_ctr_ID = @profit_ctr_id AND company_ID = @company_id

SELECT @resource_assigned = ''
SELECT @resource_assigned_max = MAX(resource_code) FROM #resource_code

/********************************************************************************************/
ResourceAssigned:
SELECT @resource_assigned = MIN(resource_code) FROM #resource_code
WHERE resource_code > @resource_assigned

IF @resource_assigned IS NULL GOTO NextResource

SELECT 
	@count_dropped = COUNT(woh.workorder_id) 
FROM workorderheader woh 
INNER JOIN workorderdetail wod 
	ON woh.workorder_id = wod.workorder_id 
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP')
	AND wod.resource_assigned = @resource_assigned
WHERE woh.company_id = @company_id

IF @count_dropped > 0
    SELECT @start_date_dropped = MAX(woh.start_date) 
	FROM workorderheader woh 
	INNER JOIN workorderdetail wod 
		ON woh.workorder_id = wod.workorder_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND woh.company_id = wod.company_id
		AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP')
		AND wod.resource_assigned = @resource_assigned
	WHERE woh.company_id = @company_id
ELSE 
BEGIN
    --INSERT #resource_picked
    --VALUES(@company_name, NULL, NULL, NULL, @resource_assigned, NULL, NULL, NULL, NULL)
    INSERT #resource_picked
    VALUES(@company_name, NULL, @resource_assigned, NULL, NULL, NULL, NULL)
    GOTO NextResource
END

SELECT @count_picked = COUNT(woh.workorder_id) 
FROM workorderheader woh 
INNER JOIN workorderdetail wod 
	ON woh.workorder_id = wod.workorder_id 
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND wod.resource_class_code IN ('BOXPICK', 'FRACPICK')
	AND wod.resource_assigned = @resource_assigned
WHERE woh.company_id = @company_id

IF @count_picked > 0
    SELECT @start_date_picked = MAX(woh.start_date) 
	FROM workorderheader woh 
	INNER JOIN workorderdetail wod 
		ON woh.workorder_id = wod.workorder_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND woh.company_id = wod.company_id
		AND wod.resource_class_code IN ('BOXPICK', 'FRACPICK')
		AND wod.resource_assigned = @resource_assigned
	WHERE woh.company_id = @company_id
ELSE
    GOTO NextResource

SELECT @date_difference = DATEDIFF(DAY, @start_date_dropped, @start_date_picked) /* @start_date_picked - @start_date_dropped */
IF @date_difference >= 0
BEGIN
	SELECT 
		@workorder_id = woh.workorder_id,
		@resource_class_code = wod.resource_class_code,
		@generator_id = woh.generator_id,
		@customer_id = woh.customer_id
	FROM workorderheader woh 
	INNER JOIN workorderdetail wod 
		ON woh.workorder_id = wod.workorder_id 
		AND woh.profit_ctr_id = wod.profit_ctr_id
		AND wod.company_id = woh.company_id
		AND wod.resource_class_code IN ('BOXPICK', 'FRACPICK')
	WHERE woh.company_id = @company_id
		--AND woh.profit_ctr_id = @profit_ctr_id
		AND wod.resource_assigned = @resource_assigned
		AND woh.start_date = @start_date_picked
	
	--INSERT #resource_picked
	--VALUES(@company_name, @workorder_id, @profit_ctr_id, @profit_ctr_name, @resource_assigned, @resource_class_code, @generator_id, @start_date_dropped,
	--	@customer_id)
		
	INSERT #resource_picked
	VALUES(@company_name, @workorder_id, @resource_assigned, @resource_class_code, @generator_id, @start_date_dropped,
		@customer_id)
END

NextResource:
IF @resource_assigned < @resource_assigned_max GOTO ResourceAssigned
/********************************************************************************************/

--IF @profit_ctr_id < @profit_ctr_id_max GOTO ProfitCenter
/********************************************************************************************/

SELECT 
	company_name,
	workorder_id,
	--profit_ctr_id,
	--profit_ctr_name,
	resource_code,
	resource_class_code,
	#resource_picked.generator_id,
	start_date,
	customer_id,
	g.epa_id,
	g.generator_name
FROM #resource_picked, generator g
WHERE #resource_picked.generator_id = g.generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_resources_available] TO [EQAI]
    AS [dbo];

