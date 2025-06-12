CREATE PROCEDURE sp_fix_profile_broker_flag
AS
/***************************************************************************************
Filename:	L:\Apps\SQL-Deploy\EQAI\sp_fix_profile_broker_flag.sql
PB Object(s):	None

06/12/2009 JDB	Created

--Gemini 10190
EXEC sp_fix_profile_broker_flag
****************************************************************************************/
DECLARE @count	int
SET @count = 0

SET NOCOUNT ON
--SELECT p.profile_id, p.broker_flag, customer_eq_flag = c.eq_flag, generator_eq_flag = g.eq_flag, p.customer_id, c.cust_name, p.generator_id, g.generator_name, p.added_by, p.date_added
--FROM Profile p
--INNER JOIN Customer c ON p.customer_id = c.customer_id
--INNER JOIN Generator g ON p.generator_id = g.generator_id
--WHERE 1=1
--AND c.eq_flag = 'T' AND g.eq_flag = 'T' AND p.broker_flag <> 'I'


INSERT INTO ProfileAudit SELECT p.profile_id, 'Profile', 'broker_flag', p.broker_flag, 'I', NULL, 'SA', GETDATE(), NEWID()
FROM Profile p
INNER JOIN Customer c ON p.customer_id = c.customer_id
INNER JOIN Generator g ON p.generator_id = g.generator_id
WHERE 1=1
AND c.eq_flag = 'T' AND g.eq_flag = 'T' AND p.broker_flag <> 'I'


UPDATE Profile SET broker_flag = 'I'
FROM Profile p
INNER JOIN Customer c ON p.customer_id = c.customer_id
INNER JOIN Generator g ON p.generator_id = g.generator_id
WHERE 1=1
AND c.eq_flag = 'T' AND g.eq_flag = 'T' AND p.broker_flag <> 'I'

SELECT @count = @count + @@ROWCOUNT


--SELECT p.profile_id, p.broker_flag, customer_eq_flag = c.eq_flag, generator_eq_flag = g.eq_flag, p.customer_id, c.cust_name, p.generator_id, g.generator_name, p.added_by, p.date_added
--FROM Profile p
--INNER JOIN Customer c ON p.customer_id = c.customer_id
--INNER JOIN Generator g ON p.generator_id = g.generator_id
--WHERE 1=1
--AND c.eq_flag = 'T' AND g.eq_flag = 'F' AND p.broker_flag <> 'O'


INSERT INTO ProfileAudit SELECT p.profile_id, 'Profile', 'broker_flag', p.broker_flag, 'O', NULL, 'SA', GETDATE(), NEWID()
FROM Profile p
INNER JOIN Customer c ON p.customer_id = c.customer_id
INNER JOIN Generator g ON p.generator_id = g.generator_id
WHERE 1=1
AND c.eq_flag = 'T' AND g.eq_flag = 'F' AND p.broker_flag <> 'O'


UPDATE Profile SET broker_flag = 'O'
FROM Profile p
INNER JOIN Customer c ON p.customer_id = c.customer_id
INNER JOIN Generator g ON p.generator_id = g.generator_id
WHERE 1=1
AND c.eq_flag = 'T' AND g.eq_flag = 'F' AND p.broker_flag <> 'O'

SELECT @count = @count + @@ROWCOUNT





--SELECT p.profile_id, p.broker_flag, customer_eq_flag = c.eq_flag, generator_eq_flag = g.eq_flag, p.customer_id, c.cust_name, p.generator_id, g.generator_name, p.added_by, p.date_added
--FROM Profile p
--INNER JOIN Customer c ON p.customer_id = c.customer_id
--INNER JOIN Generator g ON p.generator_id = g.generator_id
--WHERE 1=1
--AND c.eq_flag = 'F' AND p.broker_flag <> 'D'


INSERT INTO ProfileAudit SELECT p.profile_id, 'Profile', 'broker_flag', p.broker_flag, 'D', NULL, 'SA', GETDATE(), NEWID()
FROM Profile p
INNER JOIN Customer c ON p.customer_id = c.customer_id
INNER JOIN Generator g ON p.generator_id = g.generator_id
WHERE 1=1
AND c.eq_flag = 'F' AND p.broker_flag <> 'D'


UPDATE Profile SET broker_flag = 'D'
FROM Profile p
INNER JOIN Customer c ON p.customer_id = c.customer_id
INNER JOIN Generator g ON p.generator_id = g.generator_id
WHERE 1=1
AND c.eq_flag = 'F' AND p.broker_flag <> 'D'

--SELECT @count = @count + @@ROWCOUNT
--SELECT count = @count

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_fix_profile_broker_flag] TO [EQAI]
    AS [dbo];

