CREATE PROCEDURE sp_ElvsContainerDetailInsert (													
	@detail_id			int,									
	@container_id		int,										
	@vin				varchar(20),								
	@abs_assemblies		int,										
	@light_switches		int,										
	@date_removed		varchar(20),										
	@added_by			varchar(10)									
)													
AS													
--======================================================
-- Description: Inserts a record in ElvsContainerDetail
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/29/2006  Jonathan Broome   Initial Development
-- 08/25/2008  Chris Allen       Formatted
--
--
--             Testing
-- 										sp_ElvsContainerDetailInsert NULL, 19, 'asdfasdf', 0, 0, '34', 'jonathan'													
--======================================================
BEGIN													
	SET nocount on												
													
	DECLARE @valid_vin_flag	 char(1),											
			@valid_vin_date	 datetime,									
			@error varchar(40),										
			@year int,										
			@make varchar(20),										
			@switches_per_abs int,										
			@max_switches_per_vin int,										
			@passed_validation char(1)										
													
	SET @max_switches_per_vin = 4												
													
	SET @error = ''												
	SET @passed_validation = 'F'												
	IF @vin is not NULL AND Len(@vin) > 0												
		BEGIN 											
			SELECT @error = result, @year = year, @make = make, @switches_per_abs = switches_per_abs FROM dbo.fn_elvs_validate(@vin)										
			IF @error = 'pass'										
				BEGIN 									
					IF (@switches_per_abs * @abs_assemblies) + @light_switches > @max_switches_per_vin								
						BEGIN 							
							SET @error = 'Invalid number of switches for this VIN'						
							SET @valid_vin_flag = 'U'						
							SET @valid_vin_date = NULL						
						end							
					else								
						BEGIN 							
							SET @passed_validation = 'T'						
							SET @valid_vin_flag = 'T'						
							SET @valid_vin_date = GetDate()						
							SET @error = ''						
						end							
				end									
			IF (@error = 'Invalid number of characters in VIN' or @error = 'Invalid VIN number')										
				BEGIN 									
					SET @valid_vin_flag = 'U'								
					SET @valid_vin_date = NULL								
				end									
			else										
				IF @error <> ''									
				BEGIN 									
					SET @valid_vin_flag = 'F'								
					SET @valid_vin_date = NULL								
				end									
		end											
	else												
		BEGIN 											
			SET @passed_validation = 'F'										
			SET @valid_vin_flag = NULL										
			SET @valid_vin_date = NULL										
			SET @error = 'Invalid VIN number'										
		end											
													
	IF IsDate(@date_removed) = 0												
		BEGIN 											
			SET @passed_validation = 'F'										
			SET @date_removed = '1/1/1900'										
			SET @error = 'Invalid Removal Date'										
		end											
													
	IF @detail_id is NULL OR NOT EXISTS (SELECT detail_id FROM ElvsContainerDetail WHERE detail_id = @detail_id)												
		BEGIN 											
			EXEC @detail_id = sp_sequence_next 'ElvsContainerDetail.detail_id', 0										
			INSERT INTO ElvsContainerDetail (										
				detail_id		,							
				container_id	,								
				vin				,					
				valid_vin_flag	,								
				vin_test_result	,								
				valid_vin_date	,								
				make			,						
				year			,						
				bounty_paid_date,									
				abs_assemblies	,								
				abs_switches	,								
				light_switches	,								
				date_removed	,								
				passed_validation,									
				added_by		,							
				date_added		,							
				modified_by		,							
				date_modified									
			) VALUES (										
				@detail_id		,							
				@container_id	,								
				@vin			,						
				@valid_vin_flag	,								
				@error			,						
				@valid_vin_date	,								
				@make			,						
				@year			,						
				NULL			,						
				@abs_assemblies	,								
				(@abs_assemblies * @switches_per_abs),									
				@light_switches	,								
				@date_removed	,								
				@passed_validation,									
				@added_by		,							
				GetDate()		,							
				@added_by		,							
				GetDate()									
			)										
		end											
	else												
		BEGIN 											
			UPDATE ElvsContainerDetail SET										
				vin					 = @vin				    ,
				valid_vin_flag		 = @valid_vin_flag	    ,						
				vin_test_result		 = @error				,			
				valid_vin_date		 = @valid_vin_date	    ,						
				make				 = @make			    ,		
				year				 = @year			    ,		
				abs_assemblies		 = @abs_assemblies		,					
				abs_switches		 = (@abs_assemblies * @switches_per_abs),							
				light_switches		 = @light_switches		,					
				date_removed		 = @date_removed	    ,						
				passed_validation	 = @passed_validation	,							
				modified_by			 = @added_by		    ,				
				date_modified   	 = GetDate()								
			WHERE container_id = @container_id										
				AND detail_id = @detail_id									
			SELECT @container_id AS container_id, @detail_id AS detail_id, @error AS result										
		end											
	SET nocount OFF												
													
	IF @error = '' SET @error = Convert(varchar(4), @year) + ' ' + @make												
	SELECT @container_id AS container_id, @detail_id AS detail_id, @error AS result, @make AS make, @year AS year, @passed_validation AS passed_validation, (@abs_assemblies * @switches_per_abs) AS abs_switches												
END -- CREATE PROCEDURE sp_ElvsContainerDetailInsert

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetailInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetailInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetailInsert] TO [EQAI]
    AS [dbo];

