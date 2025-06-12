CREATE PROCEDURE sp_resourceclass_report
	@company_id		int
,	@customer_from	int
,	@customer_to	int
AS
/***************************************************************************************
This SP returns resources that have been assigned to resourceclass BOXDROP or FRACDROP
that have not later been assigned to resourceclass BOXPICK or FRACPICK

PB Object:	r_resourceclass

02/14/2001 JDB	Created
03/15/2001 JDB	Modified to count any BOX or FRAC that is picked up, regardless of the
				profit center it was picked up from.  Also added index
				'resource_assigned' to the workorderdetail table.
05/14/2001 JDB	Modified to change the date difference function from ">= 0" from "> 0"
				to include items that were BOXDROPs and BOXPICKs on the same day.
11/11/2004 MK	Changed generator_code to generator_id
05/05/2005 MK	Added epa_id and generator_name to final select
12/08/2010 SK	Added company_id as input arg and joins to company_id
				Moved to Plt_AI

sp_resourceclass_report 14, 1, 200
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE
@workorder_id 			int,
@workorder_id_max 		int,
@profit_ctr_id 			int,
@profit_ctr_id_max 		int,
@profit_ctr_name		varchar(50),
@resource_assigned 		varchar(10),
@resource_assigned_max 	varchar(10),
@resource_class_code 	varchar(10),
@generator_id 			int,
@start_date_dropped 	datetime,
@start_date_picked 		datetime,
@date_difference 		int,
@count_dropped 			int,
@count_picked 			int,
@company_name 			varchar(35),
@customer_id 			int

SET NOCOUNT ON

CREATE TABLE #resource_dropped (
company_name 			varchar(35) 	NULL,
workorder_id 			int 			NULL,
profit_ctr_id 			int 			NULL,
profit_ctr_name			varchar(50)		NULL,
resource_code 			varchar(10) 	NULL,
resource_class_code 	varchar(10) 	NULL,
generator_id 			int 			NULL,
start_date 				datetime 		NULL,
customer_id 			int 			NULL )

SELECT @company_name = company_name FROM company WHERE company_id = @company_id

SELECT @profit_ctr_id = -1
SELECT @profit_ctr_id_max = MAX(profit_ctr_id) FROM ProfitCenter WHERE company_ID = @company_id
/********************************************************************************************/
ProfitCenter:
SELECT @profit_ctr_id = MIN(profit_ctr_id) 
FROM ProfitCenter
WHERE profit_ctr_id > @profit_ctr_id
 AND company_ID = @company_id
 
 SELECT @profit_ctr_name = profit_ctr_name FROM ProfitCenter 
 WHERE profit_ctr_ID = @profit_ctr_id AND company_ID = @company_id

SELECT @resource_assigned = ''
SELECT @resource_assigned_max = MAX(wod.resource_assigned) 
FROM workorderdetail wod
JOIN workorderheader woh
	ON woh.company_id = wod.company_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.workorder_id = wod.workorder_id
	AND woh.customer_id BETWEEN @customer_from AND @customer_to
WHERE wod.company_id = @company_id
	AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP') 
	AND wod.profit_ctr_id = @profit_ctr_id
	AND wod.resource_assigned IS NOT NULL

/********************************************************************************************/
ResourceAssigned:
SELECT @resource_assigned = MIN(wod.resource_assigned) 
FROM workorderdetail wod
JOIN workorderheader woh
	ON woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND woh.company_id = wod.company_id
	AND woh.customer_id BETWEEN @customer_from AND @customer_to
WHERE wod.resource_class_code IN ('BOXDROP', 'FRACDROP') 
	AND wod.profit_ctr_id = @profit_ctr_id
	AND wod.company_id = @company_id
	AND wod.resource_assigned IS NOT NULL
	AND wod.resource_assigned > @resource_assigned

IF @resource_assigned IS NULL GOTO NextResource

SELECT @count_dropped = COUNT(woh.workorder_id) 
FROM workorderheader woh
JOIN workorderdetail wod
	ON wod.workorder_id = woh.workorder_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.company_id = woh.company_id
	AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP')
	AND wod.resource_assigned = @resource_assigned
WHERE woh.company_id = @company_id
	AND woh.customer_id BETWEEN @customer_from AND @customer_to
	AND woh.profit_ctr_id = @profit_ctr_id
	
IF @count_dropped > 0
    SELECT @start_date_dropped = MAX(woh.start_date) 
    FROM workorderheader woh
    JOIN workorderdetail wod
		ON wod.workorder_id = woh.workorder_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.company_id = woh.company_id
		AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP')
		AND wod.resource_assigned = @resource_assigned
	WHERE woh.company_id = @company_id
		AND woh.customer_id BETWEEN @customer_from AND @customer_to
		AND woh.profit_ctr_id = @profit_ctr_id
		
ELSE GOTO NextResource

SELECT @count_picked = COUNT(woh.workorder_id) 
FROM workorderheader woh
JOIN workorderdetail wod
	ON wod.workorder_id = woh.workorder_id
	AND wod.profit_ctr_id = woh.profit_ctr_id
	AND wod.company_id = woh.company_id
	AND wod.resource_class_code IN ('BOXPICK', 'FRACPICK')
	AND wod.resource_assigned = @resource_assigned
WHERE woh.company_id = @company_id
	AND woh.customer_id BETWEEN @customer_from AND @customer_to
	
IF @count_picked > 0
    SELECT @start_date_picked = MAX(woh.start_date) 
    FROM workorderheader woh
    JOIN workorderdetail wod
		ON wod.workorder_id = woh.workorder_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.company_id = woh.company_id
		AND wod.resource_class_code IN ('BOXPICK', 'FRACPICK')
		AND wod.resource_assigned = @resource_assigned
	WHERE woh.customer_id BETWEEN @customer_from AND @customer_to
		AND woh.company_id = @company_id
	
ELSE
    SELECT @start_date_picked = '01-01-1950'

SELECT @date_difference = DATEDIFF(DAY, @start_date_picked, @start_date_dropped) /* @start_date_dropped - @start_date_picked */
IF @date_difference >= 0
BEGIN
	SELECT @workorder_id = woh.workorder_id,
		@resource_class_code = wod.resource_class_code,
		@generator_id = woh.generator_id,
		@customer_id = woh.customer_id
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.workorder_id = woh.workorder_id
		AND wod.profit_ctr_id = woh.profit_ctr_id
		AND wod.company_id = woh.company_id
		AND wod.resource_class_code IN ('BOXDROP', 'FRACDROP')
	WHERE woh.customer_id BETWEEN @customer_from AND @customer_to
		AND woh.profit_ctr_id = @profit_ctr_id
		AND woh.company_id = @company_id
		AND wod.resource_assigned = @resource_assigned
		AND woh.start_date = @start_date_dropped

	INSERT #resource_dropped
	VALUES(@company_name, @workorder_id, @profit_ctr_id, @profit_ctr_name, @resource_assigned, @resource_class_code, @generator_id, @start_date_dropped,
		@customer_id)
END

NextResource:
IF @resource_assigned < @resource_assigned_max GOTO ResourceAssigned
/********************************************************************************************/

IF @profit_ctr_id < @profit_ctr_id_max GOTO ProfitCenter
/********************************************************************************************/

SELECT 
	company_name,
	workorder_id,
	profit_ctr_id,
	profit_ctr_name,
	resource_code,
	resource_class_code,
	#resource_dropped.generator_id,
	start_date,
	customer_id,
	g.epa_id,
	g.generator_name
FROM #resource_dropped, generator g
WHERE #resource_dropped.generator_id = g.generator_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_resourceclass_report] TO [EQAI]
    AS [dbo];

