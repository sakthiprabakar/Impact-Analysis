

create procedure sp_format_address ( 	@addr1 varchar(40),
					    	@addr2 varchar(40),
						@addr3 varchar(40),
                                                @addr4 varchar(40),
						@addr5 varchar(40),
                                                @city  varchar(40),
                                                @state varchar(2) ,
                                                @zipcode varchar(20),
                                                @country varchar(40),
                                                
						@ot_addr1 varchar(40) out,
						@ot_addr2 varchar(40) out,
						@ot_addr3 varchar(40) out,
						@ot_addr4 varchar(40) out,
						@ot_addr5 varchar(40) out ) as 

declare @lb_done bit,
	@li_citystatezip_line int,
        @ls_null varchar(40), 
        @ls_tmp varchar(40),
        @ls_addr1 varchar(40),
	@ls_addr2 varchar(40),
	@ls_addr3 varchar(40),
	@ls_addr4 varchar(40),
	@ls_addr5 varchar(40),
	@ls_city varchar(40),
	@ls_state varchar(2),
	@ls_zip varchar(20),
        @ls_country varchar(40),
	@ls_citystatezip varchar(40)

-- This function takes the input bill_to address lines from the customer screen and
-- formats them into 5 display lines that are used to:
--	display formatted lines on the customer screen
--		export into Epicor
--		print on a customer invoice

Set @ls_null = null

-- Get the input
select
	@ls_addr1		= ltrim(rtrim(@addr1)),
	@ls_addr2		= ltrim(rtrim(@addr2)),
	@ls_addr3		= ltrim(rtrim(@addr3)),
	@ls_addr4		= ltrim(rtrim(@addr4)),
        @ls_addr5		= ltrim(rtrim(@addr5)),
	@ls_city		= ltrim(rtrim(@city)),
	@ls_state		= ltrim(rtrim(@state)),
	@ls_zip		= ltrim(rtrim(@zipcode)),
	@ls_country	= ltrim(rtrim(@country))
	
	--Set NULL lines to blanks
	IF @ls_addr1 is null  set @ls_addr1 = ''
	IF @ls_addr2 is null  set @ls_addr2 = ''
	IF @ls_addr3 is null  set @ls_addr3 = ''
	IF @ls_addr4 is null  set @ls_addr4 = ''
	IF @ls_addr5 is null  set @ls_addr5 = ''
	
	-- Setup city, state, zip
	IF @ls_city is null  set @ls_city = ''
        IF @ls_state is null  set @ls_state = ''
        IF @ls_zip is null  set @ls_zip = ''
        
	select @ls_citystatezip = case when @ls_city = '' then @ls_state + ' ' + @ls_zip
                                   else @ls_city + ', ' + @ls_state + ' ' + @ls_zip end


	
	-- Country is included ONLY if it is not the United States
	-- AND we can assign it to a line OR fit it on the end of Line 5
	set @ls_country = lTrim(rtrim(@ls_country))
	-- If country is NULL, set it blank
	IF @ls_country is null set @ls_country = ''
	
	IF @ls_country is not null
        begin
		IF UPPER(@ls_country) =	'U.S.A' OR 
			UPPER(@ls_country) =	'U.S.' OR 
			UPPER(@ls_country) =	'USA' OR 
			UPPER(@ls_country) =	'US' OR 
			UPPER(@ls_country) =	'UNITED STATES' OR 
			UPPER(@ls_country) =	'UNITED STATES OF AMERICA'
                 BEGIN  
			SET @ls_country = ''
		 END
	END

	-- Find the last most significant address line, working backward
	SET @lb_done = 0
	
	-- check line 4
	IF @lb_done = 0 
        BEGIN
		IF @ls_addr4 <> '' 
                BEGIN
			SET @ls_addr5 = rtrim(@ls_citystatezip + ' ' + @ls_country)
			SET @lb_done = 1
		END
	END
	
	-- check line 3
	IF @lb_done = 0
        BEGIN
		IF @ls_addr3 <> ''
                BEGIN
			SET @ls_addr4 = @ls_citystatezip
			SET @ls_addr5 = @ls_country
			SET @lb_done = 1
		END
	END
	
	-- check line 2
	IF  @lb_done = 0
        BEGIN
		IF @ls_addr2 <> '' 
                BEGIN
			SET @ls_addr3 = @ls_citystatezip
			SET @ls_addr4 = @ls_country
			SET @lb_done = 1
		END
	END
	
	-- check line 1
	IF  @lb_done = 0
        BEGIN
		IF @ls_addr1 <> '' 
                BEGIN
			SET @ls_addr2 = @ls_citystatezip
			SET @ls_addr3 = @ls_country
			SET @lb_done = 1
		END
	END
	
	-- No lines?  Put city, state, and zip on line 1
	IF  @lb_done = 0
        BEGIN
		SET @ls_addr1 = @ls_citystatezip
		SET @ls_addr2 = @ls_country
	END
	
	-- Assign the lines for return
	select @ot_addr1  = @ls_addr1,
		@ot_addr2  = @ls_addr2,
		@ot_addr3  = @ls_addr3,
		@ot_addr4  = @ls_addr4,
		@ot_addr5  = @ls_addr5



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_format_address] TO [EQAI]
    AS [dbo];

