

CREATE PROCEDURE [dbo].[sp_customer_search] (
	@Debug			int,
	@SearchMode		varchar(20) = 'AND', -- 'OR' or 'AND'ing search columns
	@SearchModeTerm varchar(50) = '', -- MUST ONLY used when @SearchMode is 'OR'
	@CustIdList		varchar(8000),
	@cust_name		varchar(75),
	@Territory		varchar(8000) = '',
	@City			varchar(40),
	@StateList		varchar(8000),
	@ZipCodeList	varchar(8000),
	@Phone 			varchar(20),
	@Fax 			varchar(10),
	@vcCust_category    varchar (30), --11/21/2008 CMA Added per GID 9480
	@cDesignation      char (1), --11/21/2008 CMA Added per GID 9480
	@CustomerType	varchar(20) = '',
	@GenIdList		varchar(8000),
	@EPAIdList		varchar(8000),
	@GenName		varchar(40),
	@ContactIdList	varchar(80),
	@ContactName	varchar(40),
	@ContactEmail	varchar(60),
	@ContactPhone	varchar(20),
	@ContactFax		varchar(10),
	@CustProspectFlag char(1) = NULL,
	@userkey		varchar(255) = '',
	@rowfrom		int = -1,
	@rowto			int = -1
)
AS
BEGIN
/* ======================================================
Description: Searches for Customers, returns all Customer fields.
             Uses a temp table to hold a list of customer id's and fields from other tables, and a "userkey".
             Userkey is a guid.  The idea is: Perform the expensive, input-matching query only once, and populate
             a temp table with the smallest result set possible.  Then query the full customer table only when
             inner joining to the temp table so there's no need to duplicate the big input-matching part of the query
             and search results can be cached per user-instance (userkey) for re-use.



Parameters : 
Requires   : PLT_AI*
Modified    Author            Notes
----------  ----------------  -----------------------
02/23/2006  Jonathan Broome   Initial Development
04/25/2007	 JPB	             Changed to conform to Central Invoicing Changes (moves some fields from customer to customerbilling)
08/09/2007  JPB               Changed - removed cod_required_flag.
08/20/2007  JPB               Updated per recent Central Invoicing Changes.
05/30/2008  JPB               Modified Zip Code Search syntax so it's treated as a list of char fields, not ints.
09/02/2008  JPB			         Added:  SET @cust_name = replace(@cust_name, ' ', '%') so spaces in a customer name are insignificant.
11/21/2008  Chris Allen       Added category and designation to the search portion; per GID 9480. (The final select already returned these fields.) 
04/25/2011  RJG				Added territory_code, territory_desc, ae_user_code, ae_user_name to output
04/29/2011  RJG				changed the procedure to only return active customers
05/26/2011  RJG				Added @SearchMode and @SearchModeTerm parameters
07/26/2011  RJG				Added Region and NAM information to results (billing project 0)
10/10/2011  JPB            Converted PLT_RPT references to PLT_AI.
11/13/2012	JPB				Added @CustProspectFlag, default to NULL, which makes it ignored.
								Also noticed contact search was refactored to...work better?.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75


                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '2222, 537, 3783', '', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', 'abc', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '1,2,3', '', '', '', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', 'wayne', '', '', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '''NV'',''MA'',''MS''', '', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '''48184'',''12345''', '', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '248', '', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '517', '', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '21208,11018', '', '', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', ' ''mid000724831'' ', '', '', '', '', '', '' -- Only works on full EPA ID's, no partial matching
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', 'ABC', '', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', '', '2,56', '', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', '', '', 'sheav', '', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', '', '', '', 'ewmi-info', '', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '51726', ''
                  sp_customer_search 0, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '51726'
                  sp_customer_search 0, '', 'ford eqo', '', '', '', '', '', '', '', '', '', '', '', '', '', ''
                  

sp_customer_search
@Debug=N'1',
	@SearchMode = 'AND',
	--@CustIdList='jack',
	@CustIdList=NULL,
	@cust_name=N'WTS',
	@Territory='',
	@City=NULL,
	@StateList=NULL,
	@ZipCodeList='',
	@Phone=NULL,
	@Fax=NULL,
	@vcCust_category=NULL,
	@cDesignation=NULL,
	@GenIdList=NULL,
	@EPAIdList=NULL,
	@GenName=NULL,
	@ContactIdList=NULL,
	@ContactName=NULL,
	@ContactEmail=NULL,
	@ContactPhone=NULL,
	@ContactFax=NULL,
	@CustProspectFlag='F',
	@userKey=N'',
	@rowfrom=N'0',
	@rowto=N'25'

                  
exec sp_customer_search
@Debug=N'1',
	@SearchMode = 'OR',
	@SearchModeTerm = '12113',
	@CustIdList=NULL,
	@cust_name=N'',
	@Territory=NULL,
	@City=NULL,
	@StateList=NULL,
	@ZipCodeList=NULL,
	@Phone=NULL,
	@Fax=NULL,
	@vcCust_category=NULL,
	@cDesignation=NULL,
	@GenIdList=NULL,
	@EPAIdList=NULL,
	@GenName=NULL,
	@ContactIdList=NULL,
	@ContactName=NULL,
	@ContactEmail=NULL,
	@ContactPhone=NULL,
	@ContactFax=NULL,
	@userKey=N'',
	@rowfrom=N'0',
	@rowto=N'25'
	
	--SELECT * FROM customer where cust_status = 'A'
	                  
--------------------------------------------------------- */

  -- Variable declaration
  DECLARE @insert	varchar(8000) = '',
	  @sql varchar(8000) = '',
	  @where varchar(8000) = '',
	  @sqlfinal varchar(8000) = '',
	  @intcount int,
	  @order varchar(8000) = ''
  -- End variable declaration

  -- Initialize variables
  SET NOCOUNT ON

	SET @cust_name = replace(@cust_name, ' ', '%')		 	-- Fix spaces in customer name so that partial text matches work better:
  -- End Initializate variables

	
CREATE TABLE #state_list (state_code varchar(20))
INSERT INTO #state_list
	SELECT LTRIM(RTRIM(row)) as row FROM   dbo.fn_splitxsvtext(',', 0, @StateList) WHERE  Isnull(row, '') <> ''
	
	
--	sp_dbtextfind 'xsv'
--sp_helptext sp_rpt_opportunity_data
  ---------------------------------------------------------
  -- Populate the temp table for new userkeys 
  ---------------------------------------------------------
	-- Check for a userkey. IF it exists, we're re-accessing existing rows. IF not, this is new.
	IF @userkey <> ''
	BEGIN    
		SELECT @userkey = CASE WHEN EXISTS (SELECT userkey FROM work_CustomerSearch WHERE userkey = @userkey) THEN @userkey ELSE '' END
	END

	IF @userkey = ''
	  BEGIN    
		  SET @userkey = NewId()
		  IF @rowfrom = -1 SET @rowfrom = 1
		  IF @rowto = -1 SET @rowto = 20
		  
		  SET @INSERT = 'INSERT work_CustomerSearch (customer_id, ins_date, userkey, cust_name) ' 
		  SET @sql = 'SELECT DISTINCT c.customer_id, GetDate(), ''' + @userkey + ''' AS userkey, c.cust_name '
		  SET @sql = @sql + 'FROM customer c INNER JOIN customerbilling cxc on c.customer_id = cxc.customer_id AND cxc.billing_project_id = 0 WHERE 1=1 '
		  --SET @where = ' AND c.cust_status =''A'' '
		  SET @where = ''
		  
		  IF Len(@ContactIdList) > 0
			  SET @where = @where + 'AND EXISTS (SELECT cx.customer_id FROM contactxref cx WHERE cx.customer_id = c.customer_id AND cx.contact_id IN (' + @ContactIdList + ') AND cx.type=''C'' AND cx.status = ''A'' AND cx.web_access = ''A'' ) '

		  
		  SET @order = 'ORDER BY     cust_name, c.customer_id'
		  
		  IF @SearchMode = 'OR'
		  BEGIN
		  
			set @where = @where + ' AND (1=2 '
			if ISNUMERIC(@SearchModeTerm) = 1
			begin
				SET @where = @where + ' OR c.customer_id IN (' + @SearchModeTerm + ') '
				--SET @where = @where + ' OR Convert(int, cxc.territory_code) IN (' + @SearchModeTerm + ') '
			end
			SET @where = @where + ' OR c.cust_name LIKE ''%' + Replace(@SearchModeTerm, '''', '''''') + '%'' '
	      	SET @where = @where + ' OR cust_city LIKE ''%' + Replace(@SearchModeTerm, '''', '''''') + '%'' '
	      	
	      	--SET @where = @where + ' OR cust_zip_code IN (''' + @SearchModeTerm + ''')
	      	SET @where = @where + ' )'
		  END
		  ELSE
		  BEGIN
		  
		  
			  IF Len(@CustIdList) > 0
				SET @where = @where + 'AND  c.customer_id IN (' + @CustIdList + ') '	
	  		
			  IF Len(@cust_name) > 0
				  SET @where = @where + @SearchMode + ' c.cust_name LIKE ''%' + Replace(@cust_name, '''', '''''') + '%'' '

			  IF Len(@Territory) > 0
				  SET @where = @where + @SearchMode + ' Convert(int, cxc.territory_code) IN (' + @Territory + ') '

			  IF Len(@City) > 0
				  SET @where = @where + @SearchMode + ' cust_city LIKE ''%' + Replace(@City, '''', '''''') + '%'' '

			  IF Len(@ZipCodeList) > 0
				  SET @where = @where + @SearchMode + ' cust_zip_code IN (''' + @ZipCodeList + ''') '
				 
			  IF Len(@StateList) > 0
				  SET @where = @where + 'AND cust_state IN (SELECT state_code from #state_list) '			  

			  IF Len(@Phone) > 0
				  SET @where = @where + 'AND cust_phone LIKE ''%' + Replace(@Phone, '''', '''''') + '%'' '

			  IF Len(@Fax) > 0
				  SET @where = @where + 'AND cust_fax LIKE ''%' + Replace(@Fax, '''', '''''') + '%'' '

		  --BEG 11/21/2008 CMA Added per GID 9480
			  IF Len(@vcCust_category) > 0
				  SET @where = @where + 'AND c.cust_category LIKE ''%' + Replace(@vcCust_category, '''', '''''') + '%'' '

			  IF Len(@cDesignation) > 0
				  SET @where = @where + 'AND c.designation LIKE ''%' + Replace(@cDesignation, '''', '''''') + '%'' '
		  --END 11/21/2008 CMA Added per GID 9480
	      
      		  IF Len(@CustomerType) > 0
      				SET @where = @where + 'AND c.customer_type LIKE ''%' + Replace(@CustomerType, '''', '''''') + '%'' '
				
			  IF Len(@GenIdList) > 0
				  SET @where = @where + 'AND EXISTS (
					  SELECT a.orig_customer_id FROM profile a WHERE a.orig_customer_id = c.customer_id AND generator_id in (' + @GenIdList + ')
					  UNION
					  SELECT a.customer_id FROM profile a WHERE a.customer_id = c.customer_id AND generator_id in (' + @GenIdList + ')
					  UNION
					  SELECT w.customer_id FROM workorderheader w WHERE w.customer_id = c.customer_id AND generator_id in (' + @GenIdList + ')
					  )
				  '

			  IF Len(@EPAIdList) > 0
				  SET @where = @where + 'AND EXISTS (
					  SELECT a.orig_customer_id FROM profile a inner join generator g on a.generator_id = g.generator_id WHERE a.orig_customer_id = c.customer_id AND generator_epa_id IN (' + @EPAIdList + ')
					  UNION
					  SELECT a.customer_id FROM profile a inner join generator g on a.generator_id = g.generator_id  WHERE a.customer_id = c.customer_id AND generator_epa_id IN (' + @EPAIdList + ')
					  UNION
					  SELECT w.customer_id FROM workorderheader w inner join generator g on w.generator_id = g.generator_id  WHERE w.customer_id = c.customer_id AND generator_epa_id IN (' + @EPAIdList + ')
					  )
				  '

			  IF Len(@GenName) > 0
				  SET @where = @where + 'AND EXISTS (
					  SELECT a.orig_customer_id FROM profile a  inner join generator g on a.generator_id = g.generator_id WHERE a.orig_customer_id = c.customer_id AND generator_name LIKE ''%' + Replace(@GenName, '''', '''''') + '%''
					  UNION
					  SELECT a.customer_id FROM profile a  inner join generator g on a.generator_id = g.generator_id WHERE a.customer_id = c.customer_id AND generator_name LIKE ''%' + Replace(@GenName, '''', '''''') + '%''
					  UNION
					  SELECT w.customer_id FROM workorderheader w  inner join generator g on w.generator_id = g.generator_id WHERE w.customer_id = c.customer_id AND generator_name LIKE ''%' + Replace(@GenName, '''', '''''') + '%''
					  )
				  '
				
				--IF Len(@ContactIdList) > 0
				--  SET @where = @where + 'AND EXISTS (SELECT cx.customer_id FROM contactxref cx WHERE cx.customer_id = c.customer_id AND cx.contact_id IN (' + @ContactIdList + ') AND cx.type=''C'' AND cx.status = ''A'' ) '

			  IF Len(@ContactName) > 0
				  SET @where = @where + 'AND EXISTS (SELECT cx.customer_id FROM contactxref cx INNER JOIN contact co on cx.contact_id = co.contact_id AND cx.status = ''A'' AND cx.type=''C'' AND cx.customer_id = c.customer_id WHERE co.name LIKE ''%' + Replace(@ContactName, '''', '''''') + '%'') '

			  IF Len(@ContactEmail) > 0
				  SET @where = @where + 'AND EXISTS (SELECT cx.customer_id FROM contactxref cx INNER JOIN contact co on cx.contact_id = co.contact_id AND cx.status = ''A'' AND cx.type=''C'' AND cx.customer_id = c.customer_id  WHERE co.email LIKE ''%' + Replace(@ContactEmail, '''', '''''') + '%'') '
	  		
	  			
			  IF Len(@ContactPhone) > 0
				  SET @where = @where + 'AND EXISTS (SELECT cx.customer_id FROM contactxref cx INNER JOIN contact co on cx.contact_id = co.contact_id AND cx.status = ''A'' AND cx.type=''C'' AND cx.customer_id = c.customer_id  WHERE co.phone LIKE ''%' + Replace(@ContactPhone, '''', '''''') + '%'') '
	  		
			  IF Len(@ContactFax) > 0
				  SET @where = @where + 'AND EXISTS (SELECT cx.customer_id FROM contactxref cx INNER JOIN contact co on cx.contact_id = co.contact_id AND cx.status = ''A'' AND cx.type=''C'' AND cx.customer_id = c.customer_id  WHERE co.fax LIKE ''%' + Replace(@ContactFax, '''', '''''') + '%'') '

			  IF Len(isnull(@CustProspectFlag, '')) > 0
				  SET @where = @where + 'AND c.cust_prospect_flag = ''' + @CustProspectFlag + ''' '
		
		  END -- end @SearchMode = 'AND' section

		  SET @sqlfinal = @INSERT + @sql + @where + @order
  			
		  IF @debug >= 1
			  BEGIN    
				
				  PRINT @sqlfinal
				  SELECT @sqlfinal
			  END

		  -- Load the work_CustomerSearch table with note_id's
		  EXEC (@sqlfinal)

	      DECLARE @mindummy int
	      SELECT @mindummy = Min(dummy) FROM work_CustomerSearch WHERE userkey = @userkey
	      UPDATE work_CustomerSearch SET ins_row = (dummy - @mindummy + 1) WHERE userkey = @userkey

	  END --IF @userkey = ''

	SELECT @intcount = Count(*) FROM work_CustomerSearch WHERE userkey = @userkey
  ---------------------------------------------------------


  ---------------------------------------------------------
  -- SELECT out the full fieldset from customer & temp 
  ---------------------------------------------------------
	SET NOCOUNT OFF

	-- SELECT out the info for the rows requested.
	SELECT 
		c.customer_ID, 
		c.cust_name, 
		c.customer_type, 
		-- cb.COD_required_flag AS cert_flag, -- Removed, not important AND hard to access.
		c.cust_addr1, 
		c.cust_addr2, 
		c.cust_addr3, 
		c.cust_addr4, 
		c.cust_addr5, 
		c.cust_city, 
		c.cust_state, 
		c.cust_zip_code, 
		c.cust_country, 
		c.cust_sic_code, 
		c.cust_phone, 
		c.cust_fax, 
		c.mail_flag, 
		cb.invoice_flag, 
		c.terms_code, 
		c.added_by, 
		c.modified_by, 
		c.date_added, 
		c.date_modified, 
		cb.insurance_surcharge_flag, 
		c.designation, 
		c.generator_flag, 
		c.web_access_flag, 
		c.next_WCR, 
		c.cust_category, 
		c.cust_website, 
		c.cust_parent_ID, 
		c.cust_prospect_flag, 
		c.eq_flag, 
		c.eq_company, 
		c.customer_cost_flag, 
		dbo.fn_customer_territory_list(c.customer_id) AS territory_list, 
		c.cust_naics_code,
		x.userkey,
		@intcount AS record_count,
		dbo.fn_customer_territory_list(c.customer_id) AS territory_code,
		'' AS territory_desc,
		u.user_code as ae_user_code,
		u.user_name as ae_user_name,
		  u_nam.user_name as nam_user_name,
		  u_nam.user_code as nam_user_code,
		  ux_nam.type_id as nam_id		
		  , r.region_id
		  , r.region_desc
		  , c.cust_status
	FROM 
		customer c 
		INNER JOIN customerbilling cb on c.customer_id = cb.customer_id AND cb.billing_project_id = 0
		INNER JOIN work_CustomerSearch x on c.customer_id = x.customer_id
		LEFT JOIN Territory t ON cb.territory_code = t.territory_code
		LEFT JOIN UsersXEQContact uxe ON uxe.territory_code = t.territory_code
			AND uxe.EQcontact_type = 'AE'
		LEFT JOIN users u ON uxe.user_code = u.user_code
		LEFT JOIN UsersXEQContact ux_nam ON ux_nam.type_id = cb.NAM_id
			and ux_nam.EQcontact_type IN ('NAM')		
			and cb.billing_project_id = 0			
		LEFT JOIN Region r ON cb.region_id = r.region_id			
			and cb.billing_project_id = 0
		LEFT JOIN Users u_nam ON ux_nam.user_code = u_nam.user_code
	WHERE	
		x.userkey = @userkey
		AND ins_row between 
				CASE WHEN @rowfrom <> 0 THEN @rowfrom ELSE 0 END
			and
				CASE WHEN @rowto <> 0 THEN @rowto ELSE 999999999 END
	ORDER BY    
		ins_row
		
  ---------------------------------------------------------

	
END	--CREATE PROCEDURE sp_customer_search


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_search] TO [EQAI]
    AS [dbo];

