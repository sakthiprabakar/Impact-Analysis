CREATE OR ALTER PROCEDURE [dbo].[sp_constituent_search] (
	@search_text	varchar(100) = ''
) AS
/* **************************************************************************
sp_constituent_search

History:
08/21/2012 JPB  Created for use with EQOnline.com WCR
05/29/2025 KS - Rally US116196 - Constituent - Integer data type preventing CAS # entry

Sample:
	sp_constituent_search
	sp_constituent_search 'zinc'
	sp_constituent_search 'vinyl acid'
	sp_constituent_search '79107'
	sp_constituent_search '999'
	sp_constituent_search '218'
	
************************************************************************** */

select const_id, 
	const_alpha_desc
	, case when cas_code is null then '' else 
		substring(right('0000000000' + convert(varchar(20), cas_code), 10), 1, 7) + '-'
		+ substring(right('0000000000' + convert(varchar(20), cas_code), 10), 8, 2) + '-'
		+ substring(right('0000000000' + convert(varchar(20), cas_code), 10), 10, 1)
	  end as cas_code
	, ldr_id  
from constituents 
where 
1 = CASE when @search_text = '' THEN 1 ELSE
		CASE WHEN const_alpha_desc LIKE '%' + replace(@search_text, ' ', '%') + '%' THEN 1 ELSE
			CASE WHEN cas_code is not null AND 
					substring(right('0000000000' + convert(varchar(20), cas_code), 10), 1, 7) + '-'
					+ substring(right('0000000000' + convert(varchar(20), cas_code), 10), 8, 2) + '-'
					+ substring(right('0000000000' + convert(varchar(20), cas_code), 10), 10, 1)
					LIKE '%' + replace(@search_text, ' ', '%') + '%' THEN 1 ELSE
				CASE WHEN IsNumeric(@search_text) = 1 AND cas_code = convert(bigint, @search_text) THEN 1 ELSE
					CASE WHEN IsNumeric(@search_text) = 1 AND ldr_id = convert(int, @search_text) THEN 1 ELSE
					0
					END
				END
			END
		END
	END
and ldr_id is not null
order by const_alpha_desc 
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_constituent_search] TO [EQWEB];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_constituent_search] TO [COR_USER];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_constituent_search] TO [EQAI];
GO