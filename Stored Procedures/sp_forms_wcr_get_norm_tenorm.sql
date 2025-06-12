
CREATE PROCEDURE sp_forms_wcr_get_norm_tenorm
	@wcr_form_id INT,
	@wcr_rev_id INT
AS
BEGIN


/****************
05/31/2012	RJG Created
sp_forms_wcr_get_norm_tenorm
Given a WCR form/revision id, return the Norm/Tenorm form id and norm/tenorm capable facilities
*****************/



DECLARE @tbl_wcr_to_tenorm_map TABLE
    (
      form_id INT ,
      revision_id INT ,
      wcr_id INT ,
      wcr_rev_id INT
    )
    
DECLARE @tbl_tenorm_facilities TABLE
    (
      company_id INT ,
      profit_ctr_id INT
    )    

INSERT  INTO @tbl_wcr_to_tenorm_map
        SELECT  ftn.form_id ,
                ftn.revision_id ,
                ftn.wcr_id ,
                ftn.wcr_rev_id
        FROM    FormNORMTENORM ftn
        WHERE   wcr_id = @wcr_form_id
                AND wcr_rev_id = @wcr_rev_id
        ORDER BY form_id

-- return the norm/tenorm form ids for this wcr
SELECT  t.*
FROM    FormNORMTENORM ftn
        JOIN @tbl_wcr_to_tenorm_map t ON ftn.form_id = t.form_id
                                         AND ftn.revision_id = t.revision_id

-- first, see if the wcr is associated with any facilities that take norm/tenorm
INSERT  INTO @tbl_tenorm_facilities
        SELECT  DISTINCT
                ff.company_id ,
                ff.profit_ctr_id
        FROM    @tbl_wcr_to_tenorm_map t
                JOIN FormXApproval fx ON fx.form_id = t.wcr_id
                                         AND fx.revision_id = t.wcr_rev_id
                JOIN FormFacility ff ON fx.company_id = ff.company_id
                                        AND fx.profit_ctr_id = ff.profit_ctr_id
        WHERE   ff.norm_applicable_flag = 'T'                                

-- no facilities for norm/tenorm were selected, by default select ones that can accept this type of waste
-- if this revision still is norm/tenorm
IF ( SELECT COUNT(*)
     FROM   @tbl_tenorm_facilities
   ) = 0 
    BEGIN
        INSERT  INTO @tbl_tenorm_facilities
                SELECT  DISTINCT
                        ff.company_id ,
                        ff.profit_ctr_id
                FROM    FormFacility ff
                WHERE   ff.norm_applicable_flag = 'T'    
                AND EXISTS(SELECT 1 FROM FormWCR tmp_wcr
					JOIN @tbl_wcr_to_tenorm_map tmp_wcr_map ON tmp_wcr.form_id = tmp_wcr_map.wcr_id
					AND tmp_wcr.revision_id = tmp_wcr_map.wcr_rev_id
					WHERE ISNULL(tmp_wcr.TENORM,'F') = 'T')
					
    END                                

SELECT * FROM @tbl_tenorm_facilities

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_get_norm_tenorm] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_get_norm_tenorm] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_get_norm_tenorm] TO [EQAI]
    AS [dbo];

