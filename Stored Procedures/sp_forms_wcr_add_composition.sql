
CREATE PROCEDURE sp_forms_wcr_add_composition(
 @form_id		int,
 @revision_id	int,
 @sequence_id	int,
 @desc			nvarchar(max)	= NULL,
 @from_value	float			= NULL,
 @to_value		float			= NULL,
 @unit			varchar(10)		= NULL
)
AS
/****************
sp_forms_wcr_add_composition

11/23/2011 CRG Created
11/06/2013 JPB	Added Unit & Sequence

SELECT * FROM FormXWCRComposition where form_id = 238369 and revision_id = 3

*****************/

INSERT INTO dbo.FormXWCRComposition
        ( form_id ,
          revision_id ,
          sequence_id,
          comp_description ,
          comp_from_pct ,
          comp_to_pct ,
          unit,
          rowguid
        )
VALUES  ( @form_id , -- form_id - int
          @revision_id , -- revision_id - int
          @sequence_id,
          @desc , -- comp_description - varchar(40)
          @from_value, -- comp_from_pct - float
          @to_value , -- comp_to_pct - float
          @unit,
          newid()  -- rowguid - uniqueidentifier
        )


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_composition] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_composition] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_add_composition] TO [EQAI]
    AS [dbo];

