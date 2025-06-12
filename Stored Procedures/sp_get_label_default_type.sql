
CREATE PROCEDURE sp_get_label_default_type
	@source_type		char(1),	-- 'W', 'R', 'P', 'T'
	@source_id			int,		-- workorder_id, receipt_id, profile_id, tsdf_approval_id
	@company_id			int,
	@profit_ctr_id		int,
	@sequence_id		int,			-- workorder sequence_id, receipt line_id
	@generator_id		int,			-- allow Profile with various generator to pass in argument from Manifest Builder
	@label_type			char(1) output			
AS
/***************************************************************************************

08/25/2015 SK Created	Returns default label type, one of --  'H', 'U', 'R', 'N'
SELECT dbo.fn_get_label_default_type('P', 343473, 0, 0, NULL, 0)
sp_get_label_default_type 'P', 343473, 0, 0, NULL, 0, ''
***************************************************************************************/

--DECLARE  @return_label_type char(1)

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT @label_type = dbo.fn_get_label_default_type(@source_type, @source_id, @company_id, @profit_ctr_id, @sequence_id, @generator_id)

SELECT @label_type


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_label_default_type] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_label_default_type] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_label_default_type] TO [EQAI]
    AS [dbo];

