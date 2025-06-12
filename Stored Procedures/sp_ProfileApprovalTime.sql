
CREATE PROCEDURE [sp_ProfileApprovalTime] (
    @iDebugOptions int,                             -- 0: no debug, 1: display SQL only, 2: display and execute SQL  
    @customer_id_list   varchar(max) = '',         -- numeric customer id(s) (e.g., '100','1110,2002,3987')
	@department_id_list   varchar(max) = '',       -- numeric department(s) (e.g., '1','1,2,3,4')
    @vcStartDate    varchar(40) = NULL,
    @vcEndDate    varchar(40) = NULL,
    @fMinHoursPerProfile    float = 0,              -- hours (int)
    @fMaxHoursWoCPerProfile    float = 0,           -- hours (int) (max "Waiting On Customer" hours to include)
    @vcFacility    varchar(5) = '',                 -- company(s)
    @generator_id_list    varchar(max) = '',       -- 
    @vcReportType varchar(30) = '',                 -- how to select (2) report types.
    @profile_id_list    varchar(max) = '',
    @iRowCount          int = NULL,                     -- report type (3) profile ONLY; the number of rows to return from existing data
    @iRowStart          int = NULL,                     -- report type (3) profile ONLY; the row number from which to start
    @vcSessionKey           varchar(255) = NULL,          -- report type (3) profile ONLY; use this identifier to obtain existing data
    @status_list    varchar(max) = '',             -- string status(s) 
    @wastetype_id_list    varchar(max) = '',
    @treatment_process_id_list    varchar(max) = '',
    @disposal_service_id_list   varchar(max) = '',
    @user_code_list   varchar(max) = '',           -- string user(s)
    @waste_code_list    varchar(max) = ''
)
AS
BEGIN
/* ======================================================
 Description: Returns profile approval time* reports; types (1) Summary, (2) Drilldown and (3) Profile
                (1) Summary (a.k.a. Facility): Grouped by Facility 
                (2) Drilldown: Grouped by status, department or user
                (3) Profile (a.k.a. List): Grouped by profile_id; 

 Load To    : PLT_AI
  
 Example    :
      sp_ProfileApprovalTime 0, '', '', '5/1/2018', '5/31/2018', 0, 0, '29|0', '', 'Facility', '', '', '', '', '', '', '', '' --
      sp_ProfileApprovalTime 0, '', '', '1/1/2008', '4/30/2008', 0, 32, '21|1', '', 'profile', '', '0', '0', '', '', '', '', ''
      sp_ProfileApprovalTime 2, '', '', '1/1/2008', '4/30/2008', 0, 32, '21|1', '', 'profileUser', '', '0', '0', '', '', '', 'SHANNON', ''
       sp_ProfileApprovalTime 0, '', '', '3/1/2013', '4/1/2013', 10, 0, 'All', '', 'Facility', '396320', '', '', '', '', '', '', '', '', '' 
       sp_ProfileApprovalTime 0, '', '', '3/1/2013', '4/1/2013', 10, 0, 'All', '', 'Status', '396320', '', '', '', '', '', '', '', '', '' 

 Requires   :
              work_ProfileApprovalTime
              fn_SplitXsvText
              fn_profile_total_days
              fn_profile_business_days      
              fn_approval_code_list
              fn_business_minutes

 History:

 11/10/2006  JPB  Initial Development
 08/01/2007  JPB  Added days fields, changed from/where for efficiency
 08/10/2007  JPB  Removed "and pt.tracking_id = p.profile_tracking_id" from where 
                   - it was omitting records.
 10/23/2007  JPB  Modified Left Outer Join on profilequoteapproval and #tmp to inner joins.
                  GEM:6695.1 - JPB - Modified date criteria method. Used to be:
                        and pt.profile_id in (
                            select profile_id from profiletracking ptc where ptc.tracking_status = ''COMP'' 
                            and ptc.time_out between ''' + @vcStartDate + ''' and  ''' + @vcEndDate + '''
                        ) 
                    Problem was that it included ALL pt records with that profile_id, 
                      not just the ones before the first COMP record.
                    Now a temp table is created containing both the profile_id and 
                      tracking_id for records before the first COMP record
                    and in the date-range specified, and the larger, output queries 
                      must then inner join to it (when dates are given).
                    - Changed temp table inserts from clunky tblStringParser 
                      method to fn_SplitXsvText function.
                    -- Gem:6695.2 - JPB - Modified aggregate of profile.profile_tracking_days 
                      from SUM to MAX.  Sum was multiplying the correct # of days 
                      by the number of profile tracking records returned.  Bad.  
                      Max just brings back the biggest one (the number of days 
                      in the multiple rows is always the same, so max works).
 12/04/2007 JPB     Above Gem: changes deployed.
 02/14/2008 JPB     Wrap comparisons to manual_bypass_tracking_flag with IsNull(,'F')   
                    #Gem:6720   - JPB - Convert from #tmp_database to #profitcenter_list
 03/10/2008 JPB   Modified from tmp_database (sp_reports_list_database) use to generic copc parsing fn

 08/13/2008 CA    Formatted code; delineated; commented
                  Added new parameter to filter by minimum number of hours per profile
                  Remove rows from #data which don't correspond to the data filtered 
                    by @fMinHoursPerProfile (when @fMinHoursPerProfile is specified).

 08/13/2008 CA    Please find all relevant documentation in Gemini (GID 8860).
 12/18/2008 CA    Moved many of the larger comments to header
                  Simplified first paragraph of description to denote its 
                    relationship to the caller (web page)
                  Associated all sections with numbers and web page sections to the 
                    principle datasets: (1) Summary, (2) Drilldown or (3) Profile
                  Denoted all major sections with letter ordinals A, B, C, etc.
                  Improved debugging which allows 1 - print report only, 2 - print 
                    report and execute, or 0 - just execute
                  Improved debugging to print reports for every query necessary to obtain 
                    the result for the supplied parameters. 
                    In other words, you can run with debug = 1 to see just what the 
                      routine will do - all the queries and temp tables it uses. 
                    You can copy and paste the entire report into query analyzer and run it. 
                    There are 2 minor caveats to this simple process: 
                      1. Assure the worker table is initialized. It's created when 
                        the sp is initialized and the code for it is at the top of 
                        the master stored procedure. 
                      2. Replace one tiny subquery with values; e.g., 
                        (SELECT * FROM #status) with ('StatusCodeFromParameterList') 
                        - this is only one line that varies depending on whether 
                          caller sent status, department or user 
                  Verfied all web page sections Summary, Drilldown and Profile display 
                    hidden sql which can generate the report.
                  Performs all calculation. (None performed in web pages.)
                  Denoted business rules clearly so they can be found quickly and 
                    maintained consistently

 03/25/2009  JPB Cleaned up the very long comments that used to be in here.
                 Saved original to L:\IT Dept\Projects\Web\Profile Approval Time

 03/26/2009  JPB Removed use of ProfileTracking.business_days field, and now
                 always use the fn_profile_business_days value instead.

 09/21/2009  JPB Added @fMaxHoursWoCPerProfile input & logic.
 
 01/28/2010  JPB GEM-14068
                 ProfileTreatment table is obsolete.  
                 Changed logic that used it to use new fields/tables.
                 Changed Treatment -> WasteType
                 Added Treatment Process parameter
                 Added Disposal Service parameter

 08/31/2010  JPB Added call to sp_rebuild_profile_tracking at beginning of sp per LT.


 08/01/2013 JPB	Modified for TX Waste Codes
				Also, converted long varchar fields to varchar(max). No sense running out of space in those.
                 
====================================================== */

  --------------------------------------------------------
  --Clear any profile tracking numbering issues preemptively.
  --------------------------------------------------------
  set nocount on

  EXEC('sp_rebuild_profile_tracking 0,50000,0')
  EXEC('sp_rebuild_profile_tracking 50001,100000,0')
  EXEC('sp_rebuild_profile_tracking 100001,150000,0')
  EXEC('sp_rebuild_profile_tracking 150001,200000,0')
  EXEC('sp_rebuild_profile_tracking 200001,250000,0') -- 2 mismatches, 6 dups | 0:22
  EXEC('sp_rebuild_profile_tracking 250001,300000,0') -- 4 mismatches, 145 dups | 0:14
  EXEC('sp_rebuild_profile_tracking 300001,350000,0') -- 29 mismatches, 631 dups | 0:10
  EXEC('sp_rebuild_profile_tracking 350001,400000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 400001,450000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 450001,500000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 500001,550000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 550001,600000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 600001,650000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 650001,700000,0') -- 0 mismatches, 0 dups | 0:
  EXEC('sp_rebuild_profile_tracking 700001,750000,0') -- 0 mismatches, 0 dups | 0:


  --------------------------------------------------------
  --Declare Variables
  --------------------------------------------------------
    DECLARE 
    @intCount int,
        @i int,
        @iPos int,
    @bPreviousSession bit,
        @vcSQL varchar(max),
    @vcInsertTable varchar(max),
    @vcSelect varchar(max),
    @vcSelect_Common varchar(max),
    @vcJoin varchar(max),
    @vcWhere varchar(max),
    @vcGroupBy varchar(max),
    @vcR1SelectList varchar(max),
    @vcWhere_Drilldown varchar(max),
    @vcGroupBy_Drilldown varchar(max),
    @vcOrderBy_Drilldown varchar(max),
    @vcField1 varchar(max),
    @vcField2 varchar(max),
    @vcMinHoursSumField varchar(max),
    @vcWhere_SessionKey varchar(max),  --See Explanation (above) 
    @vcCompanyId varchar (2),     
    @vcProfitCtrId varchar (2),   
    @vcCompanyProfitCtr_Select varchar (max),

    @vcWhere_Rule1 varchar(max),
    @vcWhere_Rule2 varchar(max),
    @vcWhere_Rule3 varchar(max),
    @vcWhere_Rule4 varchar(max),
    @vcWhere_Rule5 varchar(max),
    @vcWhere_Rule6 varchar(max),
    @vcWhere_Rule7 varchar(max),
    @vcWhere_Rule7_1 varchar(max),
    @vcWhere_Rules1Thru7 varchar(max),
    @vcWhere_UserEntered varchar(max),
    @vcWhere_SubQuery varchar(max),
    @vcJoin_SubQuery varchar(max),
    @vcWhere_DeleteFromProfile varchar(max),
    
    @vcIndent varchar(2)
  --------------------------------------------------------


  --------------------------------------------------------
  --A. Initialize Variables
  --------------------------------------------------------
  SET NOCOUNT ON --ON means the count (indicating the number of rows affected by a Transact-SQL statement) is not returned.
    SET ANSI_WARNINGS OFF --Was OFF
  SET @bPreviousSession = 0;                  --Default is 0, there was no previous session.
  SET @vcSQL = '';
  SET @vcSelect = '';
  SET @vcInsertTable = '#data ';              --Default report type (Status) uses this temporary table
  SET @vcMinHoursSumField = 'bus_minutes';    --Default report type (Status) uses this field to remove rows for Minimum Hours filter
  SET @vcWhere_SessionKey = '';               
  SET @vcGroupBy = '';                        
  SET @vcJoin = '';
  SET @vcWhere = '';
    SET @vcWhere_Rules1Thru7 = '';
  SET @vcWhere_UserEntered = '';
  SET @vcIndent = '  ';
  SET @vcCompanyId = '';
  SET @vcProfitCtrId = '';
  SET @vcCompanyProfitCtr_Select = '';
  SET @vcWhere_DeleteFromProfile = '';

  --A.1. Each of these tables hold a parameter named *_list which can be a single value or several values comma separated
    CREATE TABLE #status (code char(4))
    CREATE TABLE #customer (customer_id int)
    CREATE TABLE #generator (generator_id int)
    CREATE TABLE #profile (profile_id int)
    CREATE TABLE #wastetype (wastetype_id int)
    CREATE TABLE #treatmentprocess (treatment_process_id int)
    CREATE TABLE #disposalservice (disposal_service_id int)
    CREATE TABLE #users (user_code varchar(10))
    CREATE TABLE #wastecode (waste_code varchar(10))
    CREATE TABLE #department (department_id int)

  --A.2. Break apart each *_list parameter (comma separated or not) and place in its temporary table. Used as filter (WHERE clause) not JOIN.
    INSERT #status SELECT row from dbo.fn_SplitXsvText(',', 1, @status_list) WHERE IsNull(row, '') <> ''                
    INSERT #department SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @department_id_list) WHERE IsNull(row, '') <> ''               
    INSERT #customer SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @customer_id_list) WHERE IsNull(row, '') <> ''               
    INSERT #generator SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @generator_id_list) WHERE IsNull(row, '') <> ''             
    INSERT #profile SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @profile_id_list) WHERE IsNull(row, '') <> ''             
    INSERT #wastetype SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @wastetype_id_list) WHERE IsNull(row, '') <> ''             
    INSERT #treatmentprocess SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @treatment_process_id_list) WHERE IsNull(row, '') <> ''              
    INSERT #disposalservice SELECT Convert(int, row) from dbo.fn_SplitXsvText(',', 1, @disposal_service_id_list) WHERE IsNull(row, '') <> ''                
    INSERT #users SELECT row from dbo.fn_SplitXsvText(',', 1, @user_code_list) WHERE IsNull(row, '') <> ''              
    INSERT #wastecode SELECT row from dbo.fn_SplitXsvText(',', 1, @waste_code_list) WHERE IsNull(row, '') <> '' 

    --A.3. Split the Co|Pc values into company_id, profit_ctr_id
    IF NOT @vcFacility IN ('','All')    -- means ALL companies, so don't need 
    BEGIN 
      SELECT @iPos = CASE WHEN CharIndex('|', @vcFacility) > 0 THEN CharIndex('|', @vcFacility) ELSE CharIndex('-', @vcFacility) END --CompanyID 1st    
      IF (@iPos > 0)
        BEGIN
          SET @vcCompanyId = Left(@vcFacility,@iPos-1)
          IF ( Len(@vcFacility) > @iPos ) 
            BEGIN
              SET @vcProfitCtrId = Right(@vcFacility,(Len(@vcFacility)-@iPos))
              SET @vcCompanyProfitCtr_Select = '  (SELECT Profit_Ctr_Name FROM ProfitCenter WHERE company_id = ' + CAST(@vcCompanyId AS varchar(2)) + ' AND Profit_Ctr_Id =  ' + CAST(@vcProfitCtrId AS varchar(2)) + ') AS facility,   '       
            END
        END
      ELSE
        SET @vcCompanyId = @vcFacility

      IF ( (Len(@vcCompanyId) > 0) AND (@vcCompanyProfitCtr_Select = '') ) --These are the only companies that will have no profit centers (14| or 14, 21| or 21)
        BEGIN
          SET @vcCompanyProfitCtr_Select = '  (SELECT ''UNKNOWN'') AS facility, '  --Error catching     
          IF (@vcCompanyId = '14') SET @vcCompanyProfitCtr_Select = '  (SELECT ''ALL (EQ Industrial Services, Inc.)'') AS facility, '  --Default is all companies       
          IF (@vcCompanyId = '21') SET @vcCompanyProfitCtr_Select = '  (SELECT ''ALL (EQ Detroit, Inc.)'') AS facility,     '   
        END
    END --IF NOT @vcFacility IN ('','All')  
  ELSE
    SET @vcCompanyProfitCtr_Select = '  (SELECT ''ALL EQ Facilities'') AS facility, '  --Default is all companies       
  --------------------------------------------------------
  --END A. Initialize Variables
  --------------------------------------------------------


  --------------------------------------------------------
  --B. Create temporary/worker tables for all report types.
  --------------------------------------------------------
  --B.1. Initial temp table for (1) Summary and (2) Drilldown reports
  IF @vcReportType IN ('facility','status','department','user') 
    BEGIN
        CREATE TABLE #data (
          --Holds all fields for report types (1) & (2) 
              code char(4) NULL,                            --status report (2)   
              description varchar(40) NULL,                 --status report (2) 

              department_id int NULL,                           --department report (2) 
              department_description varchar(40) NULL,          --department report (2) 

              eq_contact varchar(30) NULL,                  --user report (2) 
              user_name varchar(40) NULL,                         --user report (2)  

              total_days float NULL,                        --report (1) only                               
              business_days float NULL,                     --report (1) only                               

          --These last 4 fields are used by reports (1) & (2)
              profile_id int NULL,                              
              tracking_id int NULL,                             --for visual review of the data 
              pl_bypass_tracking_flag char(1) NULL,         
              bus_minutes float NULL            
          )


      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '------------------- B.1. #data ------------------------'       
          PRINT '----- Holds all fields for report types (1) & (2) -----'
          PRINT '-------------------------------------------------------'       
          PRINT '
                    CREATE TABLE #data (
                          code char(4) NULL,                            --status report (2)   
                          description varchar(40) NULL,                 --status report (2) 

                          department_id int NULL,                           --department report (2) 
                          department_description varchar(40) NULL,          --department report (2) 

                          eq_contact varchar(30) NULL,                  --user report (2) 
                          user_name varchar(40) NULL,                         --user report (2)  

                          total_days float NULL,                        --report (1) only                               
                          business_days float NULL,                     --report (1) only                               

                      --These last 4 fields are used by reports (1) & (2)
                          profile_id int NULL,                              
                          tracking_id int NULL,                             --for visual review of the data 
                          pl_bypass_tracking_flag char(1) NULL,         
                          bus_minutes float NULL            
                      )
                '
          PRINT '-------------------------------------------------------'       
          PRINT ''      
        END
    END --IF @vcReportType IN ('facility','status','department','user')

  --B.2. Worker table for (3) Profile. Keeps results longer for paging. 
  IF (@vcReportType LIKE 'profile%') 
    BEGIN 
      IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[work_ProfileApprovalTime]') AND OBJECTPROPERTY(id, N'IsUserTable') =1)
        BEGIN
          --Clean the holder table of data older than 2 days. 
            DELETE FROM work_ProfileApprovalTime WHERE date_added < DateAdd(d, -2, GetDate());

          --Determine if the current request is related to a previous session
          IF (@vcSessionkey IS NOT NULL AND NOT @vcSessionkey = '') 
            BEGIN
              --Verify the unique identifier (signifying a recent visit) is in fact in the holder table
              IF (SELECT Count(*) FROM work_ProfileApprovalTime WHERE session_key = @vcSessionkey) > 0 
                SET @bPreviousSession = 1;  
            END

          --Get the next page of data from holder table (there from a recent visit) THEN STOP
            IF (@bPreviousSession = 1)  
              BEGIN   
                  IF @iRowStart IS NULL SET @iRowStart = 1
                  IF @iRowCount IS NULL SET @iRowCount= 20

                  SELECT @i = Count(*) FROM work_ProfileApprovalTime WHERE session_key = @vcSessionkey;

                  --SET NOCOUNT OFF
                
              SET @vcSQL = '
                  SELECT *, ' + CAST(@i AS varchar(12)) + ' AS record_count 
                  FROM work_ProfileApprovalTime 
                  WHERE session_key = ''' + @vcSessionkey + '''
                  AND rownum BETWEEN ' + CAST(@iRowStart AS varchar(12)) + ' AND (' + CAST((@iRowStart + @iRowCount) AS varchar(12)) + ')
                  ORDER BY rownum';


              IF @iDebugOptions IN (1,2) 
                BEGIN
                  PRINT '-------------------------------------------------------'       
                  PRINT '------- B.2. Sending previous session rows ------------'       
                  PRINT '------------- work_ProfileApprovalTime ----------------'       
                  PRINT '-------------------------------------------------------'       
                  PRINT 'iRowStart is: ' + CAST(@iRowStart AS varchar(12));  
                  PRINT 'iRowCount is: ' + CAST(@iRowCount AS varchar(12));  
                  PRINT 'i (count of session key ' + @vcSessionkey + ') is ' + CAST(@i AS varchar(12));  
                  PRINT @vcSQL      
                  PRINT '-------------------------------------------------------'       
                  PRINT ''      
                END

              IF @iDebugOptions IN (0,2) 
                  EXEC(@vcSQL); 

                
                  --12/17/2008 CMA Removed. SELECT Max(rownum) FROM work_ProfileApprovalTime WHERE session_key = @vcSessionkey;
                
                RETURN;
              END
        END --IF EXISTS (SELECT * FROM dbo.sysobjects... 

      --ELSE 
      --  BEGIN
          --NOTE: I took out the create table because of permission issues. It's now created manually - as it was before.
          -- If I decide to put back here is the line explaining it  ... --the worker table has not yet been created (meaning it's the first time this routine is being called) so ...
          --IF @iDebugOptions IN (1,2) 
          --  BEGIN
          --    PRINT '-------------------------------------------------------'     
          --    PRINT '- Creating Table - work_ProfileApprovalTime -'       
          --    PRINT '-------------------------------------------------------'     
          --  END
          --END --CREATE TABLE [work_ProfileApprovalTime]
      --  END --ELSE


      IF (@bPreviousSession = 0) --Create a new session id. (See B.2. in Detailed Explanation)
          SET @vcSessionkey = NewId(); 
        
      --At this point we have no choice but to continue on with the time consuming query (assigning the newly created session id to the results).

    END --IF (@vcReportType LIKE 'profile%')  
  --------------------------------------------------------
  --END B. Create temporary/worker tables.
  --------------------------------------------------------



  --------------------------------------------------------
  --C. Initialize dynamic SQL - (various parts). 
  --------------------------------------------------------

  -- Applies to (1) Summary, (2) Drilldown and (3) Profile
  -------------------------------------------
    


  -- Applies to (1) Summary and (2) Drilldown 
  -------------------------------------------
  SET @vcSelect_Common = '
          pt.profile_id,            
          pt.tracking_id AS tracking_id,    
          pl.bypass_tracking_flag AS pl_bypass_tracking_flag,           

          /* Rule:8 */
          CASE WHEN pt.business_minutes is not NULL THEN pt.business_minutes            
            ELSE dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))        
          END AS bus_minutes            
        '   

  SET @vcJoin_SubQuery = '
              INNER JOIN ProfileQuoteApproval pqa ON p.profile_id = pqa.profile_id AND pqa.status = ''A'' 
              INNER JOIN ProfitCenter pc ON pqa.company_id = pc.company_id AND pqa.profit_ctr_id = pc.profit_ctr_id AND pc.status = ''A'' AND pc.waste_receipt_flag = ''T''      '

  IF (Len(@vcCompanyId) > 0)
    SET @vcJoin_SubQuery = @vcJoin_SubQuery + '
                AND pqa.company_id = ' + @vcCompanyId + '          '

  IF (Len(@vcProfitCtrId) > 0)
    SET @vcJoin_SubQuery = @vcJoin_SubQuery + '
                AND pqa.profit_ctr_id = ' + @vcProfitCtrId + '        '


  -- Applies to (1) Summary 
  -------------------------------------------
  IF ( @vcReportType IN ('facility') )
    BEGIN
      SET @vcSelect = '
          '''' AS code,
          '''' AS description,                              
          -2 AS department_id,
          '''' AS department_description,
          '''' AS eq_contact,
          '''' AS user_name, 
          
          /* Rule:9 */
              IsNull(dbo.fn_profile_total_days(pt.profile_id, GetDate()), 0) AS total_days, 

          /* Rule:10 */
            IsNull(dbo.fn_profile_business_days(pt.profile_id, GetDate()), 0) AS business_days,                                                          
      ' 

      SET @vcSelect = @vcSelect + @vcSelect_Common
  
      SET @vcGroupBy =  '
      '
    END --IF ( @vcReportType IN ('facility') )


  -- Applies to (2) Drilldown-Status
  ----------------------------------
  IF ( @vcReportType IN ('status', '') )
    BEGIN --map profile events to status via tbl profilelookup (status field already exists in tbl profiletracking)
      SET @vcSelect = '
          IsNull(pl.code, '''') AS code,
          IsNull(pl.description, ''(none)'') AS description, 
          -2 AS department_id,
          '''' AS department_description,
          '''' AS eq_contact,
          '''' AS user_name,                               
              0 AS total_days,
              0 AS business_days,
      ' 
      SET @vcSelect = @vcSelect + @vcSelect_Common

      --SET @vcGroupBy =  '
      --pl.code, pl.description'

      SET @vcField1 = 'code';
      SET @vcField2 = 'description';

      --Status is the one report type that doesn't need to be joined on another table since its relevant fields (status.code, and status.description) already exist in tbl profiletracking
      SET @vcJoin = '
      '

      SET @vcR1SelectList = ' 
      code,
      description, '                                

      SET @vcWhere_Drilldown = ' dd.code = d.code'

      SET @vcGroupBy_Drilldown = ' code, description'
      SET @vcOrderBy_Drilldown = @vcGroupBy_Drilldown
    END --IF ( @vcReportType IN ('status', '') )


  -- Applies to (2) Drilldown-Department
  --------------------------------------
  IF (@vcReportType = 'department')
    BEGIN --map profile events to department via tbl department
      SET @vcSelect = '
          '''' AS code,
          '''' AS description,
          IsNull(pt.department_id, -1) AS department_id,                                    
          IsNull(d.department_description, ''Unassigned'') AS department_description,       
          '''' AS eq_contact,
          '''' AS user_name, 
              0 AS total_days,
              0 AS business_days,
      ' 
      SET @vcSelect = @vcSelect + @vcSelect_Common

      --SET @vcGroupBy = '
        --pt.department_id, d.department_description'

      SET @vcField1 = 'department_id';
      SET @vcField2 = 'department_description';

      SET @vcJoin = ' 
          LEFT OUTER JOIN department d on pt.department_id = d.department_id    '

      SET @vcJoin_SubQuery = @vcJoin_SubQuery + ' 
              LEFT OUTER JOIN department d on pt.department_id = d.department_id    '


      SET @vcR1SelectList = ' 
      department_id,
      department_description, '                             

      SET @vcWhere_Drilldown = ' dd.department_id = d.department_id'

      SET @vcGroupBy_Drilldown = ' d.department_id, d.department_description'
      SET @vcOrderBy_Drilldown = @vcGroupBy_Drilldown
    END --IF (@vcReportType = 'department')


  -- Applies to (2) Drilldown-User
  --------------------------------
  IF (@vcReportType = 'user')
    BEGIN --map profile events to user via tbl user
      SET @vcSelect = '
          '''' AS code,
          '''' AS description,                              
          -2 AS department_id,
          '''' AS department_description,                               
          IsNull(pt.eq_contact, ''Unknown'') AS eq_contact,                                             
          IsNull(u.user_name, ''Unknown'') AS user_name, 
              0 AS total_days,
              0 AS business_days,
      ' 
      SET @vcSelect = @vcSelect + @vcSelect_Common
        
      --SET @vcGroupBy = '
        --pt.eq_contact, u.user_name'

      SET @vcField1 = 'eq_contact';
      SET @vcField2 = 'user_name';

      SET @vcJoin = ' 
          LEFT OUTER JOIN users u on u.user_code = pt.eq_contact 
      '

      SET @vcJoin_SubQuery = @vcJoin_SubQuery + ' 
              LEFT OUTER JOIN users u on u.user_code = pt.eq_contact '

      SET @vcR1SelectList = ' 
      eq_contact,
      user_name, '                              

      SET @vcWhere_Drilldown = ' dd.eq_contact = d.eq_contact'

      SET @vcGroupBy_Drilldown = ' eq_contact, user_name '
      SET @vcOrderBy_Drilldown = @vcGroupBy_Drilldown
    END --IF (@vcReportType = 'user')



  -- Applies to (3) Profile
  --------------------------------
  IF ( @vcReportType IN ('profile') )
    BEGIN
      SET @vcSelect = '
          '''' AS code,
          '''' AS description,
          -2 AS department_id,
          '''' AS department_description,
          '''' AS eq_contact,
          '''' AS user_name,                               
      ' 

      SET @vcGroupBy =  ''

      SET @vcWhere_DeleteFromProfile =  '
          profile_id IN (-9999)'         
    END

  -- Applies to (3) Profile-Status
  --------------------------------
  IF ( @vcReportType IN ('profileStatus') )
    BEGIN
      SET @vcSelect = '
          IsNull(pl.code, '''') AS code,
          IsNull(pl.description, ''(none)'') AS description, 
          -2 AS department_id,
          '''' AS department_description,
          '''' AS eq_contact,
          '''' AS user_name,                               
      ' 

      SET @vcGroupBy =  '
          pl.code, 
          pl.description,'

      --SET @vcSelect = @vcSelect + @vcSelect_Common
    END

  -- Applies to (3) Profile-Department
  ------------------------------------
  IF ( @vcReportType IN ('profileDepartment') ) 
    BEGIN
      SET @vcSelect = '
          '''' AS code,
          '''' AS description,
          IsNull(pt.department_id, -1) AS department_id,                                    
          IsNull(d.department_description, ''Unassigned'') AS department_description,       
          '''' AS eq_contact,
          '''' AS user_name, 
      ' 

      SET @vcGroupBy = '
            pt.department_id, 
          d.department_description,'

      --SET @vcSelect = @vcSelect + @vcSelect_Common
    END

  -- Applies to (3) Profile-User
  ------------------------------
  IF ( @vcReportType IN ('profileUser') )
    BEGIN
      SET @vcSelect = '
          '''' AS code,
          '''' AS description,                              
          -2 AS department_id,
          '''' AS department_description,                               
          IsNull(pt.eq_contact, ''Unknown'') AS eq_contact,                                             
          IsNull(u.user_name, ''Unknown'') AS user_name, 
      ' 

      SET @vcGroupBy = '
            pt.eq_contact, 
          u.user_name,'

      --SET @vcSelect = @vcSelect + @vcSelect_Common
    END


  --------------------------------------------------------
  --END C. Initialize dynamic SQL - (various parts). 
  --------------------------------------------------------


  --------------------------------------------------------
  --D. Initialize dynamic SQL - (WHERE clause - business rules). 
  --------------------------------------------------------
    SET @vcWhere_Rule1 = '
            /* Rule:1 */ IsNull(pt.manual_bypass_tracking_flag, ''F'') = ''F''  '               
    SET @vcWhere_Rule2 = '
                /* Rule:2 */ AND pt.tracking_id <= (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = ''COMP''), pt.tracking_id))   '             
    SET @vcWhere_Rule3 = '
                /* Rule:3 */ AND pt.tracking_status <> ''COMP''        '                
    SET @vcWhere_Rule4 = '
                /* Rule:4 */ AND EXISTS (SELECT profile_id FROM profiletracking WHERE profile_id = p.profile_id AND tracking_status = ''NEW'')  '               
    SET @vcWhere_Rule5 = '
                /* Rule:5 */ AND p.curr_status_code not IN (''C'', ''V'', ''R'')       '                
    SET @vcWhere_Rule6 = '
              /* Rule:6 */ AND p.date_added >= ''7/24/2006''   '                
    SET @vcWhere_Rule7 = '
                /* Rule:7 */ AND EXISTS (SELECT profile_id FROM profiletracking WHERE profile_id = p.profile_id AND tracking_status = ''COMP'')  '              
/*
    SET @vcWhere_Rule7_1 = '
                /* Rule:7.1 */ (SELECT IsNull(time_out,''1/1/1900'') FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_id = (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = ''COMP''),-1))) '  
*/
-- 2016-01-11 - JPB:
    SET @vcWhere_Rule7_1 = '
                /* Rule:7.1 */ (SELECT Coalesce(time_out, time_in, ''1/1/1900'') FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_id = (IsNull((SELECT Min(tracking_id) FROM profiletracking WHERE profile_id = pt.profile_id AND tracking_status = ''COMP''),-1))) '  

    SET @vcWhere_Rules1Thru7 = @vcWhere_Rule1 + @vcWhere_Rule2 + @vcWhere_Rule3 + @vcWhere_Rule4 + @vcWhere_Rule5 + @vcWhere_Rule6 + @vcWhere_Rule7
  --------------------------------------------------------
  --END D. Initialize dynamic SQL - (WHERE clause - business rules). 
  --------------------------------------------------------


  --------------------------------------------------------
  --E. Initialize dynamic SQL - (WHERE clause - user entered criteria). 
  --------------------------------------------------------
  IF IsDate(@vcStartDate) = 1   
      SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND ' + @vcWhere_Rule7_1 + ' >= ''' + @vcStartDate + ' 00:00:00.000'' ' 

  IF IsDate(@vcEndDate) = 1 
      SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND ' + @vcWhere_Rule7_1 + ' <= ''' + @vcEndDate + ' 23:59:59.998'' ' 

    IF IsNull(@customer_id_list, '') <> ''              
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND p.customer_id IN (SELECT customer_id FROM #customer) '            
                        
    IF IsNull(@generator_id_list, '') <> ''             
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND p.generator_id IN (SELECT generator_id FROM #generator) '         
                    
    IF IsNull(@profile_id_list, '') <> ''               
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND p.profile_id IN (SELECT profile_id FROM #profile) '           
                    
    IF IsNull(@wastetype_id_list, '') <> ''             
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND p.wastetype_id IN (SELECT wastetype_id FROM #wastetype) '

    IF IsNull(@treatment_process_id_list, '') <> ''             
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND pqa.treatment_process_id IN (SELECT treatment_process_id FROM #treatmentprocess) '

    IF IsNull(@disposal_service_id_list, '') <> ''              
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND pqa.disposal_service_id IN (SELECT disposal_service_id FROM #disposalservice) '
              
    IF IsNull(@waste_code_list, '') <> ''               
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND p.profile_id IN (SELECT profile_id FROM profilewastecode pwc INNER JOIN wastecode wc on pwc.waste_code_uid = wc.waste_code_uid inner join #wastecode tw on wc.display_name =  = tw.waste_code) '


    IF IsNull(@status_list, '') <> ''               
    BEGIN
      SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND pl.code IN (SELECT code FROM #status) '       

      SET @vcWhere_DeleteFromProfile =  ' 
          NOT code IN (SELECT code FROM #status) '      
    END 
                    
    IF IsNull(@department_id_list, '') <> ''                
    BEGIN
      IF ( (SELECT Count(*) FROM #department) = (SELECT Count(*) FROM #department WHERE department_id = '-1') )           --Join with NULL in #department doesn't work ==> UPDATE #department SET department_id = NULL WHERE department_id = '-1' 
        BEGIN
            SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND pt.department_id Is Null '

          SET @vcWhere_DeleteFromProfile =  ' 
          NOT department_id IN (SELECT department_id FROM #department) '        
        END 
      ELSE
        BEGIN
            SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND pt.department_id IN (SELECT department_id FROM #department) ' 

          SET @vcWhere_DeleteFromProfile =  ' 
          NOT department_id IN (SELECT department_id FROM #department) '        
        END  
   END

    IF IsNull(@user_code_list, '') <> ''                
    BEGIN
        SET @vcWhere_UserEntered = @vcWhere_UserEntered + ' 
              AND pt.eq_contact IN (SELECT user_code FROM #users) '         

      SET @vcWhere_DeleteFromProfile =  ' 
          NOT eq_contact IN (SELECT user_code FROM #users) '        
    END 
  --------------------------------------------------------
  --END E. Initialize dynamic SQL - (WHERE clause - user entered criteria). 
  --------------------------------------------------------


  --------------------------------------------------------
  --END F. Initialize dynamic SQL - (WHERE clause - SUBQUERY). 
  --------------------------------------------------------
        SET @vcWhere_SubQuery = '
          AND pt.profile_id IN 
          (/* BEG Subquery*/
            SELECT      
              DISTINCT(p.profile_id)            
            FROM                
              profile p
              INNER JOIN profiletracking pt on p.profile_id = pt.profile_id
              LEFT OUTER JOIN profilelookup pl on pt.tracking_status = pl.code AND pl.type = ''TrackingStatus''      '

        SET @vcWhere_SubQuery = @vcWhere_SubQuery + @vcJoin_SubQuery


        SET @vcWhere_SubQuery = @vcWhere_SubQuery +  '
            WHERE '

        SET @vcWhere_SubQuery = @vcWhere_SubQuery + @vcWhere_Rules1Thru7

        SET @vcWhere_SubQuery = @vcWhere_SubQuery + @vcWhere_UserEntered

        SET @vcWhere_SubQuery = @vcWhere_SubQuery +  '
          )/* END Subquery*/
    '
  --------------------------------------------------------
  --END F. Initialize dynamic SQL - (WHERE clause - SUBQUERY). 
  --------------------------------------------------------





  --------------------------------------------------------
  --(1.) or (2.) Create query for (1) Summary or (2) Drilldown dataset (and execute into a temporary table) 
  --------------------------------------------------------
  IF @vcReportType IN ('','status','department','user', 'facility') 
    BEGIN
      --INSERT table 
      SET @vcSQL = ' 
      INSERT ' + @vcInsertTable

      --SELECT clause
        SET @vcSQL = @vcSQL + '   
        SELECT      '     

        SET @vcSQL = @vcSQL + @vcSelect         

      --FROM clause                 
      SET @vcSQL = @vcSQL + '
        FROM                
              profiletracking pt '

      --JOIN clause                 
      SET @vcSQL = @vcSQL + '
              LEFT OUTER JOIN profilelookup pl on pt.tracking_status = pl.code AND pl.type = ''TrackingStatus'' '           
      SET @vcSQL = @vcSQL + @vcJoin  --TODO: Assure this applies here.


      --WHERE clause 
        SET @vcSQL = @vcSQL + '
     
        WHERE        '              
      SET @vcSQL = @vcSQL + @vcWhere_Rule1
      SET @vcSQL = @vcSQL + @vcWhere_Rule2
      SET @vcSQL = @vcSQL + @vcWhere_Rule3

      SET @vcSQL = @vcSQL + @vcWhere_SubQuery


      --GROUP BY clause
      SET @vcSQL = @vcSQL + @vcGroupBy


      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '--- 1. & 2. Query for (1) Summary or (2) Drilldown ----'       
          PRINT '------------- ' + @vcInsertTable + ' ------------------'       
          PRINT '--------------- ALL Profile Events --------------------'       
          PRINT '-------------------------------------------------------'       
          PRINT @vcSQL      
          PRINT '-------------------------------------------------------'       
          PRINT ''      
        END

      IF @iDebugOptions IN (0,2) 
          EXEC(@vcSQL); 

    END --IF @vcReportType IN ('','status','department','user', 'facility')
  --------------------------------------------------------
  --END (1.) Create query for Summary dataset (and execute into a temporary table) 
  --------------------------------------------------------



  --------------------------------------------------------
  --(3.) Create query for (3) Profile dataset (and execute into a worker table) 
  --------------------------------------------------------
  IF (@vcReportType LIKE 'profile%') 
    BEGIN

      --3.A. Initialize Profile SQL - (Misc). 
      -------------------------------------------
      SET @vcInsertTable = 'work_ProfileApprovalTime '; 
      SET @vcMinHoursSumField = 'bus_minutes';
      SET @vcWhere_SessionKey = '
          session_key = ''' + @vcSessionKey + ''' ';


      --3.B. Initialize Profile SQL - (SELECT). 
      -------------------------------------------
      SET @vcSelect =  @vcSelect + '

              p.customer_id AS customer_id,
              c.cust_name AS cust_name,
              p.generator_id AS generator_id,
              g.generator_name AS generator_name,
              g.epa_id AS epa_id,
              dbo.fn_approval_code_list(p.profile_id) AS approval_code,
              p.approval_desc AS approval_desc,

              SUM(
                  CASE WHEN pl.bypass_tracking_flag = ''F'' THEN
                      CASE WHEN pt.business_minutes IS NOT NULL THEN pt.business_minutes 
                          ELSE
                           /* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
							case when pt.tracking_status = ''COMP'' then 
								dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
							else
								dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
							end
                      END
                  ELSE
                      0
                  END) AS eq_minutes,

              SUM(CASE WHEN pl.bypass_tracking_flag = ''T'' THEN
                        CASE WHEN pt.business_minutes IS NOT NULL THEN pt.business_minutes 
                      ELSE
						   /* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
							case when pt.tracking_status = ''COMP'' then 
								dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
							else
								dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
							end
					  END
                    ELSE 
                0 
              END) AS cust_minutes,

          /* Rule:8 */
              SUM(CASE WHEN pt.business_minutes IS NOT NULL THEN pt.business_minutes 
                          ELSE
                           /* 2016-01-11 - JPB:    dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate()))  */
							case when pt.tracking_status = ''COMP'' then 
								dbo.fn_business_minutes(pt.time_in, Coalesce(pt.time_out, pt.time_in, getdate())) 
							else
								dbo.fn_business_minutes(pt.time_in, IsNull(pt.time_out, GetDate())) 
							end
                      END) AS bus_minutes, 

          /* Rule 9 */
              IsNull(dbo.fn_profile_total_days(p.profile_id, GetDate()), 0) AS total_days, 

          /* Rule:10 */
              IsNull(dbo.fn_profile_business_days(p.profile_id, GetDate()), 0) AS business_days,                                                          

              ''' + @vcSessionKey + ''' AS session_key,
              0 AS rownum,
              GetDate() AS date_added,  

          p.profile_id AS profile_id                    
      '                             

      --3.C. Initialize Profile SQL - (JOIN). 
      -------------------------------------------
      SET @vcJoin = ' 
          INNER JOIN profiletracking pt on p.profile_id = pt.profile_id
          LEFT OUTER JOIN profilelookup pl on pt.tracking_status = pl.code AND pl.type = ''TrackingStatus''             
          LEFT OUTER JOIN customer c on p.customer_id = c.customer_id       
          LEFT OUTER JOIN generator g on p.generator_id = g.generator_id            
          LEFT OUTER JOIN department d on pt.department_id = d.department_id    
          LEFT OUTER JOIN users u on pt.eq_contact = u.user_code       '
      SET @vcJoin = @vcJoin --- 12/17/2008 CMA Removed + @vcJoin_SubQuery


      --3.D. Initialize Profile SQL - (WHERE clause). 
      -----------------------------------------------
        SET @vcWhere =  '
     
        WHERE        '              
      SET @vcWhere = @vcWhere + @vcWhere_Rule1
      SET @vcWhere = @vcWhere + @vcWhere_Rule2
      SET @vcWhere = @vcWhere + @vcWhere_Rule3

      SET @vcWhere = @vcWhere + @vcWhere_SubQuery

      --3.D.1. Remove sections of (WHERE clause) that don't apply to (3) List 
      SET @vcWhere = REPLACE(@vcWhere,'AND pl.code IN (SELECT code FROM #status)','');
      SET @vcWhere = REPLACE(@vcWhere,'AND pt.eq_contact IN (SELECT user_code FROM #users)','');
      SET @vcWhere = REPLACE(@vcWhere,'AND pt.department_id IN (SELECT department_id FROM #department)','');
      SET @vcWhere = REPLACE(@vcWhere,'AND pt.department_id Is Null','');
      

      --3.E. Initialize Profile SQL - (GROUP BY & ORDER BY). 
      ------------------------------------------------------
      SET @vcGroupBy = '

        GROUP BY  ' + @vcGroupBy + '
            p.customer_id,
            c.cust_name,
            p.generator_id,
            g.generator_name,
            g.epa_id,
            dbo.fn_approval_code_list(p.profile_id),
            p.approval_desc,
            p.profile_id

        ORDER BY   
          p.profile_id 
          '


      --3.Z. Build & Execute SQL for Profile dataset  
      ------------------------------------------------------
      --INSERT table 
      SET @vcSQL = ' 
      INSERT ' + @vcInsertTable

      --SELECT clause
      SET @vcSQL = @vcSQL + '   
        SELECT      '     

      SET @vcSQL = @vcSQL + @vcSelect           

      --FROM clause                 
      SET @vcSQL = @vcSQL + '
        FROM                
            profile p '

      --JOIN clause                 
      SET @vcSQL = @vcSQL + @vcJoin  

      --WHERE clause 
      SET @vcSQL = @vcSQL + @vcWhere
      /*SET @vcSQL = @vcSQL + '
     
        WHERE        '              
      SET @vcSQL = @vcSQL + @vcWhere_Rules1Thru7
      SET @vcSQL = @vcSQL + @vcWhere_UserEntered*/

      --GROUP BY clause
      SET @vcSQL = @vcSQL + @vcGroupBy



      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '-------------- (3.) Profile report --------------------'       
          PRINT '---------- ' + @vcInsertTable + ' --------------'      
          PRINT '--------------- ALL Profile Events --------------------'       
          PRINT '-------------------------------------------------------'       
          PRINT @vcSQL      
          --PRINT '@vcReportType is: ' + @vcReportType
          --PRINT '@vcSelect is: ' + @vcSelect

          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT ''      
        END

      IF @iDebugOptions IN (0,2) 
          EXEC(@vcSQL); 

    END --IF (@vcReportType LIKE 'profile%')
  --------------------------------------------------------
  --END (3.) Create query for Profile dataset (and execute into a worker table) 
  --------------------------------------------------------



  --------------------------------------------------------
  --G. Filter (1), (2) or (3) dataset again, keeping ONLY those profile_id's whose total business minutes is greater than the minimum specified.
  --------------------------------------------------------
  IF @fMinHoursPerProfile > 0 
    BEGIN
      --Number received is in hours, convert to minutes (per business_minutes)
      SET @fMinHoursPerProfile = @fMinHoursPerProfile * 60

      --Remove rows from dataset that add up to less than the @fMinHoursPerProfile filter. 
        SET @vcSQL = '
      /* Rule:11 */
      DELETE FROM ' + @vcInsertTable + '   
        WHERE ' 

      SET @vcSQL = @vcSQL + ' 
           profile_id IN (SELECT profile_id 
                             FROM ' + @vcInsertTable    

      IF ( Len(RTrim(@vcWhere_SessionKey)) > 0 )
          SET @vcSQL = @vcSQL + '
                             WHERE ' + @vcWhere_SessionKey + ' ' 

      SET @vcSQL = @vcSQL + '
                             GROUP BY profile_id        
                             HAVING SUM(' + @vcMinHoursSumField + ') < ' + CAST(@fMinHoursPerProfile AS varchar(12)) + ')       
          ' 
      --END 12/17/2008 BEG CMA Changed 



      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '-- G. (1),(2)or(3) datasets - Apply MIN HOURS filter --'       
          PRINT '------ ' + @vcInsertTable + ' ------------'        
          PRINT '--------------- ALL Profile Events --------------------'       
          PRINT '-------------------------------------------------------'       
          PRINT @vcSQL      
          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT ''      
        END

      IF @iDebugOptions IN (0,2) 
        EXEC(@vcSQL);       
                
    END --IF @fMinHoursPerProfile > 0
  --------------------------------------------------------
  --END G. Filter (1), (2) or (3) dataset again, ...
  --------------------------------------------------------


  --------------------------------------------------------
  --G2. Filter (1), (2) or (3) dataset again, keeping ONLY those profile_id's whose total business minutes is less than the maximum specified.
  -- Copied from G. above, used here to implement @fMaxHoursWoCPerProfile logic.
  -- 09/21/2009 - JPB
  --------------------------------------------------------
  IF @fMaxHoursWoCPerProfile > 0 
    BEGIN
      --Number received is in hours, convert to minutes (per business_minutes)
      SET @fMaxHoursWoCPerProfile = @fMaxHoursWoCPerProfile * 60

      --Remove rows from dataset that add up to less than the @fMaxHoursWoCPerProfile filter. 
        SET @vcSQL = '
      /* Rule:11 */
      DELETE FROM ' + @vcInsertTable + '   
        WHERE ' 

      SET @vcSQL = @vcSQL + ' 
           profile_id IN (SELECT profile_id 
                             FROM ' + @vcInsertTable    

      IF ( Len(RTrim(@vcWhere_SessionKey)) > 0 )
          SET @vcSQL = @vcSQL + '
                             WHERE ' + @vcWhere_SessionKey + ' ' 

      IF @vcInsertTable = '#data'
          SET @vcSQL = @vcSQL + '
                                 GROUP BY profile_id
                                 HAVING SUM(CASE WHEN pl_bypass_tracking_flag = ''T'' THEN bus_minutes ELSE 0 END) > ' + CAST(@fMaxHoursWoCPerProfile AS varchar(12)) + ')'
      ELSE
          SET @vcSQL = @vcSQL + '
                                 GROUP BY profile_id
                                 HAVING SUM(cust_minutes) > ' + CAST(@fMaxHoursWoCPerProfile AS varchar(12)) + ')'

      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '-- G2. (1),(2)or(3) datasets - Apply MAX WoC HOURS filter --'      
          PRINT '------ ' + @vcInsertTable + ' ------------'        
          PRINT '--------------- ALL Profile Events --------------------'       
          PRINT '-------------------------------------------------------'       
          PRINT @vcSQL      
          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT ''      
        END

      IF @iDebugOptions IN (0,2) 
        EXEC(@vcSQL);       
                
    END --IF @fMaxHoursWoCPerProfile > 0
  --------------------------------------------------------
  --END G2. Filter (1), (2) or (3) dataset again, ...
  --------------------------------------------------------
  


  --------------------------------------------------------
  --(1.1.) Return a single row for entire facility (1) Summary report
  --------------------------------------------------------
  IF @vcReportType IN ('facility') --TODO: Do we need this conditional here? -- '','status','department','user', 
    BEGIN
      IF ( (SELECT COUNT(DISTINCT profile_id) FROM #data) > 0 ) 
        BEGIN
          --1.1.a. Remove duplicate total_days and business_days since our calculation took place on every event whereas the function we used gave a figure (for the entire profile within the business rules).
          IF @iDebugOptions IN (1,2) 
            BEGIN
              PRINT '-------------------------------------------------------'       
              PRINT '------- 1.1.a.(1) Facility - Remove duplicates --------'       
              PRINT '-------------------------------------------------------'       
              PRINT '
          SELECT DISTINCT total_days, business_days, profile_id INTO #data2 FROM #data;
          '
              PRINT '-------------------------------------------------------'       
              PRINT ''      
            END

          IF @iDebugOptions IN (0,2) 
            SELECT DISTINCT total_days, business_days, profile_id INTO #data2 FROM #data;


          --1.1.b. 
            SET @vcSQL = '
          SELECT 
          '

            SET @vcSQL = @vcSQL + @vcCompanyProfitCtr_Select

            SET @vcSQL = @vcSQL +         '
            IsNull(   ( COUNT(DISTINCT d.profile_id)                                                                                                          ) , 0  )    AS profile_count,         

            /* Rule:12 */
            IsNull(   ( SUM(CASE WHEN d.pl_bypass_tracking_flag = ''F'' THEN d.bus_minutes ELSE 0 END)                                                        ) , 0  )    AS eq_minutes,
            IsNull(   ( Round( (SUM(CASE WHEN d.pl_bypass_tracking_flag = ''F'' THEN d.bus_minutes ELSE 0 END) / (COUNT(DISTINCT d.profile_id)) / 60)  , 2 )  ) , 0  )    AS eq_hours_avg,

            IsNull(   ( SUM(CASE WHEN d.pl_bypass_tracking_flag = ''T'' THEN d.bus_minutes ELSE 0 END)                                                        ) , 0  )    AS cust_minutes,          
            IsNull(   ( Round( (SUM(CASE WHEN d.pl_bypass_tracking_flag = ''T'' THEN d.bus_minutes ELSE 0 END) / (COUNT(DISTINCT d.profile_id)) / 60)  , 2 )  ) , 0  )    AS cust_hours_avg,

            IsNull(   ( SUM(bus_minutes) 
                                                                                                                     ) , 0  )    AS all_minutes,            
            /* Rule:12 */
            IsNull(   ( Round( (SUM(bus_minutes) / (COUNT(DISTINCT d.profile_id)) / 60) , 2 )                                                                 ) , 0  )    AS all_hours_avg,         

            /* Rule:12 */
            IsNull(   ( Round( ((SELECT SUM(total_days) FROM #data2)/(SELECT COUNT(DISTINCT profile_id) FROM #data)) , 2 )                                    ) , 0  )    AS total_days,            
            IsNull(   ( Round( ((SELECT SUM(business_days) FROM #data2)/(SELECT COUNT(DISTINCT profile_id) FROM #data)) , 2 )                                 ) , 0  )    AS business_days          

            FROM #data d;
          '


          IF @iDebugOptions IN (1,2) 
            BEGIN
              PRINT '-------------------------------------------------------'       
              PRINT '------- 1.1. RETURN - (1) Facility Total --------------'       
              PRINT '-------------------------------------------------------'       
              PRINT @vcSQL      
              PRINT '-------------------------------------------------------'       
              PRINT ''      
            END

          IF @iDebugOptions IN (0,2) 
            EXEC(@vcSQL)

          RETURN; --there is nothing relevant to report type (1) below this line.
          
        END --IF ( COUNT(DISTINCT d.profile_id) > 0 )
      ELSE
        BEGIN
          --1.1.c. There is NO data to return for report type (1)
          SELECT profile_id FROM #data WHERE 0 = 1; --send back an empty recordset

          IF @iDebugOptions IN (1,2) 
            BEGIN
              PRINT '-------------------------------------------------------'       
              PRINT '------------- 1.1.c. - (1) Facility -------------------'       
              PRINT '-------------------------------------------------------'       
              PRINT ''
              PRINT '     There is NO data to return for report type (1)    '
              PRINT '                     AND/OR                            '
              PRINT '               You ran with debug = 1                  '
              PRINT '   Code logic skips past this section  so if you want  '
              PRINT '        run with debug = 2 to generate dynamic SQL.    '
              PRINT ''
              PRINT '-------------------------------------------------------'       
              PRINT ''      
            END

          RETURN; --there is nothing relevant to report type (1) below this line.
        END 
    END --IF @vcReportType IN ('facility')
  --------------------------------------------------------
  --END (1.1.) Return 
  --------------------------------------------------------



  --------------------------------------------------------
  --(3.1.) Return first 20 rows (for paging) from work_ProfileApprovalTime
  --------------------------------------------------------
  IF (@vcReportType LIKE 'profile%')
    BEGIN
      --3.1.A. Remove any excess rows
      -------------------------------
        SET @vcSQL = '
      DELETE FROM ' + @vcInsertTable + '   
        WHERE ' + @vcWhere_SessionKey 
      IF ( Len(RTrim(@vcWhere_DeleteFromProfile)) > 0 )
          SET @vcSQL = @vcSQL + ' 
          AND ' + @vcWhere_DeleteFromProfile 


      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '------ 3.1.A. Applies to (3) - Remove excess rows -----'       
          PRINT '------ ' + @vcInsertTable + ' ------------'        
          PRINT '-------------------------------------------------------'       
          PRINT @vcSQL      
          PRINT ''      
          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT ''      
        END

      IF @iDebugOptions IN (0,2) 
        EXEC(@vcSQL);       


      --3.1.B. Set ordinals to the results 
      ------------------------------------
      SELECT @i = MIN(dummy_id) FROM work_ProfileApprovalTime WHERE session_key = @vcSessionkey;
      IF OBJECT_ID(N'tempdb..#t', N'U') IS NOT NULL 
        DROP TABLE #t;
      CREATE TABLE #t(rownumnew INT NOT NULL IDENTITY, dummy_id INT, session_key VARCHAR (255));
      INSERT INTO #t (dummy_id,session_key) SELECT dummy_id, session_key FROM work_ProfileApprovalTime rpatl WHERE rpatl.session_key = @vcSessionkey ORDER BY dummy_id;
      UPDATE work_ProfileApprovalTime SET rownum = #t.rownumnew FROM #t INNER JOIN work_ProfileApprovalTime AS rpatl ON #t.dummy_id = rpatl.dummy_id AND #t.session_key = rpatl.session_key;
      IF OBJECT_ID(N'tempdb..#t', N'U') IS NOT NULL 
        DROP TABLE #t;
        
      SET @iRowStart = 0
      SET @iRowCount = 19

      SELECT @i = Count(*) FROM work_ProfileApprovalTime WHERE session_key = @vcSessionkey;


      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '------ 3.1.B. Applies to (3) - Set Row Ordinals -------'       
          PRINT '------ ' + @vcInsertTable + ' ------------'        
          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT '      This short part finds all ' + CONVERT(varchar(30),@i) + ' records     '      
          PRINT '      for session key ' + @vcSessionkey    
          PRINT '      and number ONLY those records from 1 to ' + CONVERT(varchar(30),@i)      
          PRINT ''      
          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT ''      
        END


      --3.1.C. Return first 20 rows 
      -----------------------------
      SET @vcSQL = '
      SELECT *, ' + CAST(@i AS varchar(12)) + ' AS record_count 
      FROM work_ProfileApprovalTime 
      WHERE session_key = ''' + @vcSessionkey + '''
      AND rownum BETWEEN ' + CAST(@iRowStart AS varchar(12)) + ' AND (' + CAST((@iRowStart + @iRowCount) AS varchar(12)) + ')
      ORDER BY rownum';       


      IF @iDebugOptions IN (1,2) 
        BEGIN
          PRINT '-------------------------------------------------------'       
          PRINT '---- 3.1.C. - RETURN first 20 rows for (3) Profile ----'       
          PRINT '------------- work_ProfileApprovalTime ----------------'       
          PRINT '-------------------------------------------------------'       
          PRINT ''      
          PRINT 'iRowStart is: ' + CAST(@iRowStart AS varchar(12));  
          PRINT 'iRowCount is: ' + CAST(@iRowCount AS varchar(12));  
          PRINT 'i (count of session key ' + @vcSessionkey + ') is ' + CAST(@i AS varchar(12));  
          PRINT @vcSQL      
          PRINT ''      
          PRINT '-------------------------------------------------------'       
          PRINT ''      
        END

      IF @iDebugOptions IN (0,2) 
        EXEC(@vcSQL);   

      RETURN; --there is nothing relevant to report type (3) below this line.
    END 
  --------------------------------------------------------


  --------------------------------------------------------
  --H. Create a second temporary table for (2) Drilldown reports (so we can use values in the initial temporary table in mathematical operations.) 
  --------------------------------------------------------
    CREATE TABLE #Drilldown (
          fld1AnyReport varchar(30) NULL,                  
          fld2AnyReport varchar(40) NULL,                          

          profile_count int NULL,                           --the count of all unique profile_ids
          line_item_count int NULL,                       --the count of each unique line item 
          eq_minutes float NULL,                                
          eq_hours_avg float NULL,                              
          cust_minutes float NULL,                            
          cust_hours_avg float NULL,                              
          all_minutes float NULL,                               
          all_hours_avg float NULL                              
      )


  IF @iDebugOptions IN (1,2) 
    BEGIN
      PRINT '-------------------------------------------------------'       
      PRINT '---------------- H. #Drilldown ------------------------'       
      PRINT '-------------------------------------------------------'       
      PRINT ' 
              CREATE TABLE #Drilldown (
                  fld1AnyReport varchar(30) NULL,                  
                  fld2AnyReport varchar(40) NULL,                          

                  profile_count int NULL,                           --the count of all unique profile_ids
                  line_item_count int NULL,                       --the count of each unique line item 
                  eq_minutes float NULL,                                
                  eq_hours_avg float NULL,                              
                  cust_minutes float NULL,                            
                  cust_hours_avg float NULL,                              
                  all_minutes float NULL,                               
                  all_hours_avg float NULL                              
                  )
            '
      PRINT '-------------------------------------------------------'       
      PRINT ''      
    END
  --------------------------------------------------------


  --------------------------------------------------------
  --I. Create second dataset for (2) Drilldown reports with Count & Sum for each row item within top level category.
  --------------------------------------------------------
    --SET NOCOUNT ON;

    SET @vcSQL = '      
  INSERT #Drilldown     
    SELECT '

    SET @vcSQL = @vcSQL + @vcR1SelectList

    SET @vcSQL = @vcSQL + '     
        COUNT(distinct d.profile_id) AS profile_count,          
        COUNT(' + @vcField1 + ') AS line_item_count,            
        SUM(            
            CASE WHEN d.pl_bypass_tracking_flag = ''F'' THEN d.bus_minutes ELSE 0 END       
        ) AS eq_minutes,
      0,            
        SUM(            
            CASE WHEN d.pl_bypass_tracking_flag = ''T'' THEN d.bus_minutes ELSE 0 END       
        ) AS cust_minutes,          
      0,            
        SUM(            
            bus_minutes     
        ) AS all_minutes,   
      0         

    FROM #data d            '   

    SET @vcSQL = @vcSQL + '     
    GROUP BY ' + @vcGroupBy_Drilldown + '
    ORDER BY ' + @vcOrderBy_Drilldown 

            
  IF @iDebugOptions IN (1,2) 
    BEGIN
      PRINT '-------------------------------------------------------'       
      PRINT '------ I. Count/Sum each row for (2) Drilldown --------'       
      PRINT '--------------- #Drilldown ----------------------------'       
      PRINT '-------------------------------------------------------'       
      PRINT @vcSQL      
      PRINT ''      
      PRINT '-------------------------------------------------------'       
      PRINT ''      
    END

  IF @iDebugOptions IN (0,2) 
    EXEC(@vcSQL);       

  --------------------------------------------------------
  --J. AVERAGE of the Counts and Sums of each row item of (2) Drilldown reports; Convert minutes to hours, round to two decimal places. 
  --------------------------------------------------------
    --SET NOCOUNT OFF;
  
    SET @vcSQL = '
  /* Rule:12 */
  UPDATE #Drilldown SET eq_hours_avg =   IsNull(  (  Round(((eq_minutes/profile_count)/60),2)     )  , 0 )  ;           
  UPDATE #Drilldown SET cust_hours_avg = IsNull(  (  Round(((cust_minutes/profile_count)/60),2)   )  , 0 )  ;           
  UPDATE #Drilldown SET all_hours_avg =  IsNull(  (  Round(((all_minutes/profile_count)/60),2)    )  , 0 )  ;
  '

            
  IF @iDebugOptions IN (1,2) 
    BEGIN
      PRINT '-------------------------------------------------------'       
      PRINT '------------ J. Average / Counts / Sums ---------------'       
      PRINT '--------------- #Drilldown ----------------------------'       
      PRINT '-------------------------------------------------------'       
      PRINT @vcSQL      
      PRINT '-------------------------------------------------------'       
      PRINT ''      
    END

  IF @iDebugOptions IN (0,2) 
      EXEC(@vcSQL)      

  --------------------------------------------------------
  --2.1 Return complete dataset for (2) Drilldown reports
  --------------------------------------------------------
    --SET NOCOUNT OFF;

    SET @vcSQL = '
  --Rename the columns to match the report (See Detailed Explanation 2.1.) 
  SELECT  
    fld1AnyReport AS ' + @vcField1 + ',
    fld2AnyReport AS ' + @vcField2 + ',
    profile_count AS profile_count,
    line_item_count AS line_item_count,
    eq_minutes,
    eq_hours_avg,
    cust_minutes,
    cust_hours_avg,
    all_minutes,
    all_hours_avg
  FROM 
    #Drilldown; 
  '

            
  IF @iDebugOptions IN (1,2) 
    BEGIN
      PRINT '-------------------------------------------------------'       
      PRINT '--- 2.1 RETURN Average/Counts/Sums for (2) Drilldown --'       
      PRINT '-------------------------------------------------------'       
      PRINT @vcSQL      
      PRINT '-------------------------------------------------------'       
      PRINT ''      
    END

  IF @iDebugOptions IN (0,2) 
      EXEC(@vcSQL)      


    SET ANSI_WARNINGS ON


END --CREATE PROCEDURE [sp_ProfileApprovalTime]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfileApprovalTime] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfileApprovalTime] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ProfileApprovalTime] TO [EQAI]
    AS [dbo];

