
  CREATE PROCEDURE sp_rpt_territory_sales_customer_summary
    @date_from DATETIME ,
    @date_to DATETIME ,
    @user_id VARCHAR(8) ,
    @filter_field VARCHAR(20) ,		-- one of: 'NAM_ID', 'REGION_ID','TERRITORY_CODE'
    @filter_list VARCHAR(MAX) ,
    @debug INT
  AS --------------------------------------------------------------------------------------------------------------------
/*
-- Rajeswari Nori

3/18/13 RN Created 

Created 3 new reports to displays a list of details for territory sales customer summary by Base and Event category for each EQ company grouped by customer and category.
        1 - Sales Customer Summary  by AE
		2 - Sales Customer Summary  by NAM
		3 - Sales Customer Summary  by REGION
		
 EXECUTE dbo.sp_rpt_territory_sales_customer_Summary
	  @date_from = '01-01-2011',
	  @date_to = '01-31-2011',
	  @user_id = 'RAJESWAR',	
	  @filter_field = 'NAM_ID',
	  @filter_list = 'ALL',--'UN, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 51, 71, 76',
	  @debug = 1
		
EXEC sp_rpt_territory_sales_customer_Summary '1/01/2011', '1/11/2011',
    'RAJESWAR', 'territory_code', 'all', 0	
    
 EXEC sp_rpt_territory_sales_customer_Summary '1/01/2011', '1/11/2011',
    'RAJESWAR', 'region_id', '6', 0	
    
    
 EXEC sp_rpt_territory_sales_customer_Summary '1/01/2011', '1/11/2011',
    'RAJESWAR', 'nam_id', '8', 0	 
-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51		
*/
----------------------------------------------------------------------------------
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

    DECLARE @execute_sql VARCHAR(1000) ,
        @b_rate_0 DECIMAL(6, 5) ,
        @b_rate_1 DECIMAL(6, 5) ,
        @b_rate_2 DECIMAL(6, 5) ,
        @b_rate_3 DECIMAL(6, 5) ,
        @b_rate_4 DECIMAL(6, 5) ,
        @b_rate_5 DECIMAL(6, 5) ,
        @e_rate_0 DECIMAL(6, 5) ,
        @e_rate_1 DECIMAL(6, 5) ,
        @e_rate_2 DECIMAL(6, 5) ,
        @e_rate_3 DECIMAL(6, 5) ,
        @e_rate_4 DECIMAL(6, 5) ,
        @e_rate_5 DECIMAL(6, 5) ,
        @company_id SMALLINT ,
        @db_count INT ,
        @unassigned_territory VARCHAR(8) 

    CREATE TABLE #Output
        (
          report_by_id INT NULL ,
          report_by_code VARCHAR(8) NULL ,
          report_by_name VARCHAR(50) NULL ,
          base0 FLOAT NULL ,
          base1 FLOAT NULL ,
          base2 FLOAT NULL ,
          base3 FLOAT NULL ,
          base4 FLOAT NULL ,
          base5 FLOAT NULL ,
          event0 FLOAT NULL ,
          event1 FLOAT NULL ,
          event2 FLOAT NULL ,
          event3 FLOAT NULL ,
          event4 FLOAT NULL ,
          event5 FLOAT NULL ,
          customer_id INT NULL ,
          cust_name VARCHAR(40) NULL,
          total_amt FLOAT null
     
    )
        

-- create #TerritoryWork
    CREATE TABLE #TerritoryWork
        (
          company_id INT NULL ,
          profit_ctr_id INT NULL ,
          trans_source CHAR(1) NULL ,
          receipt_id INT NULL ,
          line_id INT NULL ,
          price_id INT NULL ,
          trans_type CHAR(1) NULL ,
          ref_line_id INT NULL ,
          workorder_sequence_id VARCHAR(15) NULL ,
          workorder_resource_item VARCHAR(15) NULL ,
          workorder_resource_type VARCHAR(15) NULL ,
          Workorder_resource_category VARCHAR(40) NULL ,
          billing_type VARCHAR(20) NULL ,
          dist_company_id INT NULL ,
          dist_profit_ctr_id INT NULL ,
          extended_amt FLOAT NULL ,
          territory_code VARCHAR(8) NULL ,
          job_type CHAR(1) NULL ,
          category INT NULL ,
          category_reason INT NULL ,
          commissionable_flag CHAR(1) NULL ,
          invoice_date DATETIME NULL ,
          month INT NULL ,
          year INT NULL ,
          customer_id INT NULL ,
          cust_name VARCHAR(40) NULL ,
          treatment_id INT NULL ,
          bill_unit_code VARCHAR(4) NULL ,
          waste_code VARCHAR(10) NULL ,
          profile_id INT NULL ,
          quote_id INT NULL ,
          approval_code VARCHAR(40) NULL ,
          TSDF_code VARCHAR(15) NULL ,
          TSDF_EQ_FLAG CHAR(1) NULL ,
          date_added DATETIME NULL ,
          tran_flag CHAR(1) NULL ,
          bulk_flag CHAR(1) NULL ,
          Orig_extended_amt FLOAT NULL ,
          split_flag CHAR(1) NULL ,
          Split_extended_amt FLOAT NULL ,
          WOD_Manifest VARCHAR(15) NULL ,
          WOD_Line INT NULL ,
          EQ_Equip_Flag CHAR(1) NULL ,
          product_id INT NULL ,
          nam_id INT NULL ,
          nam_user_name VARCHAR(40) NULL ,
          region_id INT NULL ,
          region_desc VARCHAR(50) NULL ,
          billing_project_id INT NULL ,
          billing_project_name VARCHAR(40) NULL ,
          territory_user_name VARCHAR(40) NULL ,
          territory_desc VARCHAR(40) NULL
        ) 

    CREATE INDEX approval_code ON #TerritoryWork (approval_code)
    CREATE INDEX trans_type ON #TerritoryWork (trans_type)
    CREATE INDEX waste_code ON #TerritoryWork (waste_code)
    CREATE INDEX company_id ON #TerritoryWork (company_id)
    CREATE INDEX line_id ON #TerritoryWork (line_id)
    CREATE INDEX receipt_id ON #TerritoryWork (receipt_id)
    CREATE INDEX woresitem ON #TerritoryWork (workorder_resource_item)
    CREATE INDEX tsdfcode ON #TerritoryWork (tsdf_code)
    CREATE INDEX category ON #TerritoryWork (category) 
    CREATE INDEX treatment_id ON #TerritoryWork (treatment_id)
    CREATE INDEX ix_tw07 ON #TerritoryWork (customer_id, category, job_type, bill_unit_code, waste_code)
    CREATE INDEX nam_id ON #TerritoryWork (nam_id)
    CREATE INDEX region_id ON #TerritoryWork (region_id)
    CREATE INDEX billing_project_id ON #TerritoryWork (billing_project_id)

-- create #tmp_copc with all active companies/profitcenters
    CREATE TABLE #tmp_copc
        (
          [company_id] INT ,
          profit_ctr_id INT
        )
    INSERT  #tmp_copc
            SELECT  ProfitCenter.company_ID ,
                    ProfitCenter.profit_ctr_ID
            FROM    dbo.ProfitCenter
            WHERE   status = 'A'
  
--IF @debug = 1 print 'SELECT * FROM #tmp_copc'
--IF @debug = 1 SELECT * FROM #tmp_copc

--The sp_rpt_territory_calc_ai relies on the existence of #TerritoryWork, #tmp_copc and #tmp_territory 
    EXEC sp_rpt_territory_calc_ai @date_from, @date_to, @filter_field,
        @filter_list, @debug
        
    IF @debug = 1 
        BEGIN
            PRINT ' select * from #TerritoryWork'
     --select * from #TerritoryWork
            SELECT  SUM(extended_amt) ,
                    customer_id ,
                    category
            FROM    #TerritoryWork
            GROUP BY category ,
                    customer_id ,
                    territory_code
        END

    IF @filter_field = 'territory_code' 
        BEGIN

            INSERT  INTO #Output
                    SELECT  NULL AS report_by_id ,
                            territory_code AS report_by_code ,
                            territory_user_name AS report_by_name ,
                            0.00 AS base0 ,
                            0.00 AS base1 ,
                            0.00 AS base2 ,
                            0.00 AS base3 ,
                            0.00 AS base4 ,
                            0.00 AS base5 ,
                            0.00 AS event0 ,
                            0.00 AS event1 ,
                            0.00 AS event2 ,
                            0.00 AS event3 ,
                            0.00 AS event4 ,
                            0.00 AS event5 ,
                             customer_id ,
                            cust_name,
                           0.00 as total_amt 						
			          FROM   #TerritoryWork A
                    GROUP BY territory_code ,
                            territory_user_name ,
                            customer_id ,
                            cust_name 
        END								
					
    IF @filter_field = 'region_id' 
        BEGIN

            INSERT  INTO #Output
                    SELECT  region_id AS report_by_id ,
                            NULL AS report_by_code ,
                            region_desc AS report_by_name ,
                            0.00 AS base0 ,
                            0.00 AS base1 ,
                            0.00 AS base2 ,
                            0.00 AS base3 ,
                            0.00 AS base4 ,
                            0.00 AS base5 ,
                            0.00 AS event0 ,
                            0.00 AS event1 ,
                            0.00 AS event2 ,
                            0.00 AS event3 ,
                            0.00 AS event4 ,
                            0.00 AS event5 ,
                            customer_id ,
                            cust_name,
                           0.00 as total_amt
                    FROM    #TerritoryWork A
                    GROUP BY region_id ,
                            region_desc ,
                            customer_id ,
                            cust_name 
								
        END

    IF @filter_field = 'nam_id' 
        BEGIN
    
            INSERT  INTO #Output
                    SELECT  nam_id AS report_by_id ,
                            NULL AS report_by_code ,
                            nam_user_name AS report_by_name ,
                            0.00 AS base0 ,
                            0.00 AS base1 ,
                            0.00 AS base2 ,
                            0.00 AS base3 ,
                            0.00 AS base4 ,
                            0.00 AS base5 ,
                            0.00 AS event0 ,
                            0.00 AS event1 ,
                            0.00 AS event2 ,
                            0.00 AS event3 ,
                            0.00 AS event4 ,
                            0.00 AS event5 ,
                            customer_id ,
                            cust_name,
                           0.00 as total_amt
                    FROM    #TerritoryWork A
                    GROUP BY nam_id ,
                            nam_user_name ,
                            customer_id ,
                            cust_name 
	 			
				 											
        END
    IF @debug = 1 
        BEGIN
            PRINT 'Select * from #Output'
            SELECT  *
            FROM    #Output
        END
    UPDATE  #output
    SET     base0 = ( SELECT    SUM(TW.extended_amt)
                      FROM      #TerritoryWork TW
                      WHERE     TW.Customer_id = #output.Customer_id
                                AND TW.category = 0
                                AND TW.job_type = 'B'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                         )
                                      OR ( @filter_field = 'nam_id'
                                           AND ( ISNULL(tw.nam_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                         )
                                    )
                    )

    UPDATE  #output
    SET     base1 = ( SELECT    SUM(TW.extended_amt)
                      FROM      #TerritoryWork TW
                      WHERE     TW.Customer_id = #output.Customer_id
                                AND TW.category = 1
                                AND TW.job_type = 'B'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                         )
                                      OR ( @filter_field = 'nam_id'
                                           AND ( ISNULL(tw.nam_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                         )
                                    )
                    )	
								

    UPDATE  #output
    SET     base2 = ( SELECT    SUM(TW.extended_amt)
                      FROM      #TerritoryWork TW
                      WHERE     TW.Customer_id = #output.Customer_id
                                AND TW.category = 2
                                AND TW.job_type = 'B'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                    )

    UPDATE  #output
    SET     base3 = ( SELECT    SUM(TW.extended_amt)
                      FROM      #TerritoryWork TW
                      WHERE     TW.Customer_id = #output.Customer_id
                                AND TW.category = 3
                                AND TW.job_type = 'B'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                    )

    UPDATE  #output
    SET     base4 = ( SELECT    SUM(TW.extended_amt)
                      FROM      #TerritoryWork TW
                      WHERE     TW.Customer_id = #output.Customer_id
                                AND TW.category = 4
                                AND TW.job_type = 'B'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                    )																	
    UPDATE  #output
    SET     base5 = ( SELECT    SUM(TW.extended_amt)
                      FROM      #TerritoryWork TW
                      WHERE     TW.Customer_id = #output.Customer_id
                                AND TW.category = 5
                                AND TW.job_type = 'B'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )	
									       OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                    )
    UPDATE  #output
    SET     event0 = ( SELECT   SUM(TW.extended_amt)
                       FROM     #TerritoryWork TW
                       WHERE    TW.Customer_id = #output.Customer_id
                                AND TW.category = 0
                                AND TW.job_type = 'E'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                     )								
									
    UPDATE  #output
    SET     event1 = ( SELECT   SUM(TW.extended_amt)
                       FROM     #TerritoryWork TW
                       WHERE    TW.Customer_id = #output.Customer_id
                                AND TW.category = 1
                                AND TW.job_type = 'E'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                     )
									
    UPDATE  #output
    SET     event2 = ( SELECT   SUM(TW.extended_amt)
                       FROM     #TerritoryWork TW
                       WHERE    TW.Customer_id = #output.Customer_id
                                AND TW.category = 2
                                AND TW.job_type = 'E'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                     )
									
    UPDATE  #output
    SET     event3 = ( SELECT   SUM(TW.extended_amt)
                       FROM     #TerritoryWork TW
                       WHERE    TW.Customer_id = #output.Customer_id
                                AND TW.category = 3
                                AND TW.job_type = 'E'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                     )
									
    UPDATE  #output
    SET     event4 = ( SELECT   SUM(TW.extended_amt)
                       FROM     #TerritoryWork TW
                       WHERE    TW.Customer_id = #output.Customer_id
                                AND TW.category = 4
                                AND TW.job_type = 'E'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                     )	
						
    UPDATE  #output
    SET     event5 = ( SELECT   SUM(TW.extended_amt)
                       FROM     #TerritoryWork TW
                       WHERE    TW.Customer_id = #output.Customer_id
                                AND TW.category = 5
                                AND TW.job_type = 'E'
                                AND ( @filter_field = 'territory_code'
                                      AND ( ISNULL(tw.territory_code, -99) ) = ( ISNULL(#output.report_by_code,
                                                              -99) )
                                      OR ( @filter_field = 'region_id'
                                           AND ( ISNULL(tw.region_id, -99) ) = ( ISNULL(#output.report_by_id,
                                                              -99) )
                                           OR ( @filter_field = 'nam_id'
                                                AND ISNULL(tw.nam_id, -99) = ISNULL(#output.report_by_id,
                                                              -99)
                                              )
                                         )
                                    )
                     )																																						
     UPDATE #output
     SET    total_amt = ( ISNULL(base0, 0.00) + ISNULL(base1, 0.00)
                          + ISNULL(base2, 0.00) + ISNULL(base3, 0.00)
                          + ISNULL(base4, 0.00) + ISNULL(base5, 0.00)
                          + ISNULL(event0, 0.00) + ISNULL(event1, 0.00)
                          + ISNULL(event2, 0.00) + ISNULL(event3, 0.00)
                          + ISNULL(event4, 0.00) + ISNULL(event5, 0.00) )
     FROM   #Output           																																						
																																																								

/* Select the result set */
    SELECT  report_by_id ,
            report_by_code ,
            report_by_name ,
            ISNULL(base0, 0.00) AS base0 ,
            ISNULL(base1, 0.00) AS base1 ,
            ISNULL(base2, 0.00) AS base2 ,
            ISNULL(base3, 0.00) AS base3 ,
            ISNULL(base4, 0.00) AS base4 ,
            ISNULL(base5, 0.00) AS base5 ,
            ISNULL(event0, 0.00) AS event0 ,
            ISNULL(event1, 0.00) AS event1 ,
            ISNULL(event2, 0.00) AS event2 ,
            ISNULL(event3, 0.00) AS event3 ,
            ISNULL(event4, 0.00) AS event4 ,
            ISNULL(event5, 0.00) AS event5 ,
            customer_id ,
            cust_name,
            total_amt
    FROM    #Output

    DROP TABLE #TerritoryWork
    DROP TABLE #Output

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_sales_customer_summary] TO [EQAI]
    AS [dbo];

