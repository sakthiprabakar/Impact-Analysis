
CREATE PROCEDURE sp_fix_transporter_code
AS

/*
	Usage: sp_fix_transporter_code;	
	Date: 03-05-2011
	Author: Rich Grenwick
	Purpose: Get which records should be migrated from old transporter code	to new transporter code and fix them.
	This should be a temporary measure until we find out where the old transporter code is coming from

*/
BEGIN


IF object_id('tempdb..#tbl') is not null drop table #tbl
	
	
create table #tbl(
--declare #tbl table (
	table_name varchar(50) NULL
	, company_id int NULL
	, profit_ctr_id int NULL
	, old_transporter_code varchar(50) NULL
	, new_transporter_code varchar(50) NULL
)

INSERT INTO  #tbl VALUES  ('WorkOrderManifest','12','5','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','0','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','1','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','4','EQIS','EQISATL')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','5','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','6','EQIS','EQISINDY')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','9','EQ DETROIT','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','9','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','14','10','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','15','1','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','21','2','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','21','3','EQIS','EQISYPSI')
INSERT INTO  #tbl VALUES  ('WorkOrderManifest','22','0','EQIS','EQFL')

/* CREATE AUDIT RECORD */
INSERT INTO WorkorderAudit (workorder_id, company_id, profit_ctr_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
SELECT DISTINCT wot.workorder_ID
                ,wot.company_id
                ,wot.profit_ctr_ID
                ,'M' AS resource_type
                ,0 AS sequence_id
                ,'WorkOrderTransporter' AS table_name
                ,'transporter_code' AS column_name
                ,wot.transporter_code AS before_value
                ,t.new_transporter_code AS after_value
                ,NULL AS audit_reference
                ,'SA_TRANS' AS modified_by
                ,getdate() AS date_modified
FROM   WorkOrderTransporter wot
       INNER JOIN #tbl t
         ON wot.company_id = t.company_id
            AND wot.profit_ctr_ID = t.profit_ctr_id
            AND wot.transporter_code = t.old_transporter_code
            AND t.table_name = 'WorkOrderManifest'
       INNER JOIN WorkOrderHeader woh
         ON wot.workorder_ID = woh.workorder_ID
            AND wot.company_id = woh.company_id
            AND wot.profit_ctr_ID = woh.profit_ctr_ID
WHERE  woh.workorder_status IN ( 'T', 'X' ) -- Workorder Template or Trip Template
        OR WOH.date_added > '1/1/2009' 



/* FIX BAD RECORDS */
    UPDATE WorkOrderTransporter SET transporter_code = t.new_transporter_code
    FROM   WorkOrderTransporter wom
           INNER JOIN #tbl t
             ON wom.company_id = t.company_id
                AND wom.profit_ctr_ID = t.profit_ctr_id
                AND wom.transporter_code = t.old_transporter_code
                AND t.table_name = 'WorkOrderManifest'
           INNER JOIN WorkOrderHeader woh
             ON wom.workorder_ID = woh.workorder_ID
                AND wom.company_id = woh.company_id
                AND wom.profit_ctr_ID = woh.profit_ctr_ID
    WHERE  WOH.date_added >= '1/1/2009'
            OR woh.workorder_status IN ( 'T', 'X' ) -- Workorder Template or Trip Template
		

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_fix_transporter_code] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_fix_transporter_code] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_fix_transporter_code] TO [EQAI]
    AS [dbo];

