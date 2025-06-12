
CREATE PROCEDURE sp_GeneratorSelect
	@generator_id int,
	@customer_list varchar(500) = NULL
AS
BEGIN
	IF @customer_list IS NULL
	BEGIN
		SELECT * FROM Generator where generator_id = @generator_id AND status='A'
	END
	ELSE
	BEGIN
	
		CREATE TABLE #tmp_generator_list(
			[customer_id] [int] NULL,
			[generator_id] [int] NOT NULL,
			[generator_name] [varchar](40) NULL,
			[epa_id] [varchar](12) NULL,
			[generator_address_1] [varchar](40) NULL,
			[generator_city] [varchar](40) NULL,
			[generator_state] [varchar](2) NULL,
			[generator_zip_code] [varchar](15) NULL,
			[site_code] [varchar](16) NULL,
			[site_type] [varchar](40) NULL,
			[ord_gs] [varchar](2) NULL,
			[ord_gc] [varchar](40) NULL
		)
		
		INSERT INTO #tmp_generator_list
			exec sp_generator_list_by_customer_list @customer_list
	
		SELECT * FROM #tmp_generator_list tmp
			INNER JOIN Generator g ON tmp.generator_id = g.generator_id
			where tmp.generator_id = @generator_id AND g.status='A'
	END

	
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

