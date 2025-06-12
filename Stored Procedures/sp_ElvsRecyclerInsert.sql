CREATE PROCEDURE sp_ElvsRecyclerInsert (													
	@recycler_id					int				= NULL,		/* Recycler ID - when non null, UPDATE occurs */	
	@status						char(1)			= 'A',		/* Status (Active/Inactive) */	
	@recycler_name				varchar(40),					/* Recycler's Name */			
	@mailing_address				varchar(40)		= NULL,		/* Recycler's mailing_Address */				
	@mailing_city				varchar(40)		= NULL,		/* Recycler's mailing_City */				
	@county						varchar(40)		= NULL,		/* Recycler's mailing_County */		
	@mailing_state				varchar(2)		= NULL,		/* Recycler's mailing_State */				
	@mailing_zip_code			varchar(15)		= NULL,		/* Recycler's Zip Code */					
	@shipping_address			varchar(40)		= NULL,		/* Recycler's mailing_Address */					
	@shipping_city				varchar(40)		= NULL,		/* Recycler's mailing_City */				
	@shipping_zip_code			varchar(15)		= NULL,		/* Recycler's Zip Code */					
	@shipping_state				varchar(2)		= NULL,		/* Recycler's mailing_State */				
	@phone						varchar(20)		= NULL,		/* Recycler's Phone Number */		
	@toll_free_phone				varchar(20)		= NULL,		/* Recycler's Toll Free Phone Number */				
	@fax							varchar(20)		= NULL,		/* Recycler's Fax Number */	
	@contact_info				varchar(30)		= NULL,		/* Text Contact Info for Recycler (less than a contact_id */				
	@contact_id					int				= NULL,		/* Contact ID of Recycler Contact */	
	@date_joined					datetime			= NULL,		/* Date this recycler joined the program */		
	@website						varchar(100)		= NULL,		/* Reycler's website */		
	@email_address				varchar(100)		= NULL,		/* Reycler's website */				
	@parent_company				varchar(40) 		= NULL,						
	@participation_flag			char(1)			= 'I',	  /* 'A' / 'I' / 'N' */ --08/22/08 CMA Changed; field previously used  /* 'T' / 'F' */  				
	@non_participation_reason		text				= NULL,		/* Reason fOR NOT participating */				
	@vehicles_processed_annually	varchar(100)		= NULL,		/* Number of vehicles processed annually */							
	@added_by					varchar(10)	= NULL		/* Who entered the data */			
)													
AS													
--======================================================
-- Description: Adds a recycler to the ElvsRecycler table. See IMPORTANT NOTE below.
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--              IMPORTANT NOTE: participation_flag (now) relies on trigger (tr_ElvsParticipationFlagUpdate) to maintain proper state					
--                              INSERTs or UPDATEs for participation_flag field only may be overridden.
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 10/30/2006	 JPB	             Added @status field to allow deleting existing entries											
-- 04/10/2007  JPB               Added mailing_* AND shipping_* for address fields													
-- 11/12/2007  JPB               Modified Participation Flag -- Always 'T' (expect it to be removed soon)													
-- 08/20/2008  Chris Allen       Inserts A, I, or N as participation_flag (previously inserted T or F); 
--
--
--													sp_ElvsRecyclerInsert 'Westside Auto', '1900 Tonnelle Ave', 'North Bergen', 'HUDSON', 'NJ', '07047-', '2018658333', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'SA'													
--													sp_ElvsRecyclerInsert 'A-1 Parts Depot', '22 Lafayette St', 'Orange', 'ESSEX', 'NJ', '07050', '9736736600', NULL, NULL, 'Contact: John', NULL, NULL, NULL, NULL, NULL, NULL, 'SA'													
--======================================================
BEGIN
	SET nocount on													
	DECLARE @mode	varchar(10)												
	SET @mode = 'update'													
	IF @recycler_id is null													
	BEGIN 													
		GetRecyclerID:												
		/* Get the next recycler_id to use for inserting */												
		SET @mode = 'insert'												
		EXEC @recycler_id = sp_sequence_next 'ElvsRecycler.recycler_id', 0												
	END													

	/* Clean up the mailing zip code */													
	DECLARE @zip_char char(1), @zip_count int, @zip_clean varchar(15)													
	SET @zip_clean = ''													
	SET @zip_count = Len(IsNull(@mailing_zip_code, ''))													
	IF @zip_count > 0													
	BEGIN 													
		WHILE @zip_count > 0												
		BEGIN 												
			SET @zip_char = substring(@mailing_zip_code,@zip_count,1)											
			IF @zip_char in ('1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-')											
				SET @zip_clean = @zip_char + @zip_clean										
			SET @zip_count = @zip_count -1											
		END												
		IF right(@zip_clean,1) = '-'												
			SET @zip_clean = left(@zip_clean, Len(@zip_clean)-1)											
		SET @mailing_zip_code = @zip_clean												
	END													
														
	/* Clean up the shipping zip code */													
	SET @zip_clean = ''													
	SET @zip_count = Len(IsNull(@shipping_zip_code, ''))													
	IF @zip_count > 0													
	BEGIN 													
		WHILE @zip_count > 0												
		BEGIN 												
			SET @zip_char = substring(@shipping_zip_code,@zip_count,1)											
			IF @zip_char in ('1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-')											
				SET @zip_clean = @zip_char + @zip_clean										
			SET @zip_count = @zip_count -1											
		END												
		IF right(@zip_clean,1) = '-'												
			SET @zip_clean = left(@zip_clean, Len(@zip_clean)-1)											
		SET @shipping_zip_code = @zip_clean												
	END													
														
	/* Clean up the phone number fields */													
	SET @phone = replace(replace(replace(replace(replace(@phone, '.', ''), ' ', ''), '-', ''), ')', ''), '(', '')													
	SET @toll_free_phone = replace(replace(replace(replace(replace(@toll_free_phone, '.', ''), ' ', ''), '-', ''), ')', ''), '(', '')													
	SET @fax = replace(replace(replace(replace(replace(@fax, '.', ''), ' ', ''), '-', ''), ')', ''), '(', '')													
														
	/* IF no toll free phone given, check to see IF the regular phone is toll free */													
	IF IsNull(@toll_free_phone, '') = ''													
		IF left(@phone,3) in ('800', '888', '877', '866', '855', '844', '833', '822')												
			SET @toll_free_phone = @phone											
														
	/* Check AND fix length of Fax # (20 chars allowed AS input, 10 AS data) */													
	IF Len(LTrim(RTrim(IsNull(@fax, '')))) > 10													
		SET @fax = left(@fax, 10)												
														
	/* Default null/blank participation flags to T */													
	-- IF IsNull(@participation_flag, '') = ''													
  -- SET @participation_flag = 'I' --08/22/08 CMA Removed; unecessary; default set in parameter header  												
														
	IF @mode = 'insert'													
		INSERT ElvsRecycler (												
			recycler_id					,	/* Recycler ID */					
			status						,	/* Status */				
			recycler_name				,	/* Recycler's Name */						
			parent_company				,							
			mailing_address				,	/* Recycler's Address */						
			mailing_city					,	/* Recycler's City */					
			county						,	/* Recycler's County */				
			mailing_state				,	/* Recycler's State */						
			mailing_zip_code				,	/* Recycler's Zip Code */						
			shipping_address				,	/* Recycler's Address */						
			shipping_city				,	/* Recycler's City */						
			shipping_state				,	/* Recycler's State */						
			shipping_zip_code			,	/* Recycler's Zip Code */							
			phone						,	/* Recycler's Phone Number */				
			toll_free_phone				,	/* Recycler's Toll Free Phone Number */						
			fax							,	/* Recycler's Fax Number */			
			contact_info					,	/* Text Contact Info for Recycler (less than a contact_id */					
			contact_id					,	/* Contact ID of Recycler Contact */					
			date_joined					,	/* Date this recycler joined the program */					
			website						,	/* Reycler's website */				
			email_address				,	/* Reycler's website */						
			participation_flag			,	/* 'A' / 'I' / 'N' */ --08/22/08 CMA Changed; field previously used  /* 'T' / 'F' */							
			non_participation_reason		,	/* Reason fOR NOT participating */								
			vehicles_processed_annually	,	/* Number of vehicles processed annually */									
			added_by						,	/* Who entered the data */				
			date_added					,	/* When was the data entered */					
			modified_by					,	/* Who modified the data */					
			date_modified					/* When was the data modified */						
		) VALUES (												
			@recycler_id								,	/* Recycler ID */		
			@status									,	/* Status */	
			LTrim(RTrim(@recycler_name))				,	/* Recycler's Name */						
			LTrim(RTrim(@parent_company))				,	/* Recycler's Name */						
			LTrim(RTrim(@mailing_address))			,	/* Recycler's Address */							
			LTrim(RTrim(@mailing_city))				,	/* Recycler's City */						
			LTrim(RTrim(@county))						,	/* Recycler's County */				
			LTrim(RTrim(@mailing_state))				,	/* Recycler's State */						
			LTrim(RTrim(@mailing_zip_code))			,	/* Recycler's Zip Code */							
			LTrim(RTrim(@shipping_address))			,	/* Recycler's Address */							
			LTrim(RTrim(@shipping_city))				,	/* Recycler's City */						
			LTrim(RTrim(@shipping_state))				,	/* Recycler's State */						
			LTrim(RTrim(@shipping_zip_code))			,	/* Recycler's Zip Code */							
			LTrim(RTrim(@phone))						,	/* Recycler's Phone Number */				
			LTrim(RTrim(@toll_free_phone))			,	/* Recycler's Toll Free Phone Number */							
			LTrim(RTrim(@fax))						,	/* Recycler's Fax Number */				
			LTrim(RTrim(@contact_info))				,	/* Text Contact Info for Recycler (less than a contact_id */						
			LTrim(RTrim(@contact_id	))				,	/* Contact ID of Recycler Contact */					
			LTrim(RTrim(@date_joined))				,	/* Date this recycler joined the program */						
			LTrim(RTrim(@website))					,	/* Reycler's website */					
			LTrim(RTrim(@email_address))				,	/* Reycler's website */						
			LTrim(RTrim(@participation_flag))    ,	/* 'A' / 'I' / 'N' */ --08/22/08 CMA Changed; field previously inserted 'T' every time
			@non_participation_reason					,	/* Reason fOR NOT participating */					
			LTrim(RTrim(@vehicles_processed_annually))	,	/* Number of vehicles processed annually */									
			LTrim(RTrim(@added_by))					,	/* Who entered the data */					
			GetDate()								,	/* When was the data entered */		
			LTrim(RTrim(@added_by))					,	/* Who modified the data */					
			GetDate()										/* When was the data modified */	
		)												
	ELSE													
	BEGIN 													
		UPDATE ElvsRecycler SET												
			status						= @status,					
			recycler_name				= @recycler_name,							
			parent_company				= @parent_company,							
			mailing_address				= @mailing_address,							
			mailing_city					= @mailing_city,						
			county						= @county,					
			mailing_state				= @mailing_state,							
			mailing_zip_code				= @mailing_zip_code,							
			shipping_address				= @shipping_address,							
			shipping_city				= @shipping_city,							
			shipping_state				= @shipping_state,							
			shipping_zip_code			= @shipping_zip_code,								
			phone						= @phone,					
			toll_free_phone			    	= @toll_free_phone,							
			fax							= @fax,				
			contact_info					= @contact_info,						
			contact_id					= @contact_id,						
			date_joined					= @date_joined,						
			website						= @website,					
			email_address				= @email_address,							
  		participation_flag			= @participation_flag,		--08/22/08 CMA uncommented; 
			non_participation_reason		= @non_participation_reason,									
			vehicles_processed_annually	= @vehicles_processed_annually,										
			modified_by					= @added_by,						
			date_modified		= GetDate()							
		WHERE												
			recycler_id = @recycler_id											
		SET nocount OFF												
		SELECT 0												
	END													
		SET nocount OFF												
														
	SELECT @recycler_id AS recycler_id													

END -- CREATE PROCEDURE sp_ElvsRecyclerInsert

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsRecyclerInsert] TO [EQAI]
    AS [dbo];

