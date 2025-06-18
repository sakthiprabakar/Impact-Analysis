

USE PLT_AI
GO

CREATE OR ALTER PROCEDURE dbo.sp_GeneratorSelect
	  @generator_id INTEGER
	, @customer_list VARCHAR(500) = NULL
AS
BEGIN
	/*
	IF @customer_list IS NULL
		BEGIN
			SELECT * FROM Generator where generator_id = @generator_id AND status='A'
		END
	ELSE
		BEGIN
			CREATE TABLE #tmp_generator_list(
				   customer_id INTEGER NULL
				 , generator_id INTEGER NOT NULL
				 , generator_name VARCHAR(40) NULL
				 , epa_id VARCHAR(12) NULL
				 , generator_address_1 VARCHAR(40) NULL
				 , generator_city VARCHAR(40) NULL
				 , generator_state VARCHAR(2) NULL
				 , generator_zip_code VARCHAR(15) NULL
				 , site_code VARCHAR(16) NULL
				 , site_type VARCHAR(40) NULL
				 , ord_gs VARCHAR(2) NULL
				 , ord_gc VARCHAR(40) NULL
				 );
		
		INSERT INTO #tmp_generator_list
			EXEC sp_generator_list_by_customer_list @customer_list
	
		SELECT customer_id, generator_id, generator_name, epa_id
			 , generator_address_1, generator_city, generator_state, generator_zip_code
			 , site_code, site_type, ord_gs, ord_gc
		  FROM #tmp_generator_list tmp
		       JOIN Generator g ON tmp.generator_id = g.generator_id
		 WHERE tmp.generator_id = @generator_id
		   AND g.[status]='A';
	END
	*/
	RETURN 0
	
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_GeneratorSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_GeneratorSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_GeneratorSelect] TO [EQAI]
    AS [dbo];

