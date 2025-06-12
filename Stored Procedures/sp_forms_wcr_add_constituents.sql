
CREATE PROCEDURE sp_forms_wcr_add_constituents(
 @form_id		int,
 @revision_id	int,
 @uhc			char(1)			= NULL,
 @const_desc	nvarchar(max)	= NULL,
 @min_concentration	float		= NULL,
 @max_concentration	float		= NULL,
 @unit			nvarchar(250)	= NULL,
 @const_id		int				= NULL
)
AS
/****************
11/23/2011 CRG Created
sp_forms_wcr_add_constituents
Adds a constituent from the web form to the db
*****************/

INSERT INTO dbo.FormXConstituent
        ( form_id ,
          revision_id ,
          page_number ,
          line_item ,
          const_id ,
          const_desc ,
          min_concentration ,
          concentration,
          unit ,
          uhc ,
          specifier
        )
VALUES  ( @form_id , -- form_id - int
          @revision_id , -- revision_id - int
          NULL , -- page_number - int
          NULL , -- line_item - int
          @const_id , -- const_id - int
          @const_desc , -- const_desc - varchar(50)
          @min_concentration, -- min_concentration - float
          @max_concentration, -- concentration - float
          @unit , -- unit - char(10)
          @uhc , -- uhc - char(1)
          'WCR'  -- specifier - varchar(30)
        )

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_constituents] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_constituents] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_constituents] TO [EQAI]
    AS [dbo];

