
CREATE PROCEDURE sp_forms_add_profit_center(
 @form_id		int,
 @revision_id	int,
 @company_id	int		= NULL,
 @pc_id			int	= NULL
)
AS

/****************
11/23/2011 CRG Created
sp_forms_add_profit_center
Adds a profit center from the web form to the db
*****************/

INSERT INTO dbo.FormXApproval
        ( form_id ,
          revision_id ,
          company_id ,
          profit_ctr_id
        )
VALUES  ( 
		  @form_id , -- form_id - int
          @revision_id , -- revision_id - int
          @company_id , -- company_id - int
          @pc_id -- profit_ctr_id - int
        )

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_profit_center] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_profit_center] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_profit_center] TO [EQAI]
    AS [dbo];

