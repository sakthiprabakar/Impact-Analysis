USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_radioactive_isotopes_received]    Script Date: 4/28/2025 5:27:44 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER   PROCEDURE [dbo].[sp_radioactive_isotopes_received]             
    @company_id   int ,           
 @profit_ctr_id  int ,          
    @StartDate DATE,                      
    @EndDate DATE                      
AS              
/*************************************************************************************************            
Loads to : PLT_AI            
PowerBuilder object(s): r_radioactive_isotopes_received use this procedure AS data source.           
          
25-03-2025 - Created For this User Story US142261 - Develop Radioactive Isotopes Received Report in EQAI   
11 - 04 -2025 - US149473 - Update the ‘Radioactive Isotopes Received’ Report in EQAI with the correct spelling for "Plutonium-242".
          
Exec sp_radioactive_isotopes_received 44 ,0, '2025-03-01', '2025-03-31';          
*************************************************************************************************/            
BEGIN                      
    SET NOCOUNT ON;                      
                      
    -- Create a temporary table to store sample data                      
    CREATE TABLE #TempTable (                          
        Sample_ID INT PRIMARY KEY,                          
        Actinium227 DECIMAL(18,6) ,                            
        Actinium228 DECIMAL(18,6) ,                            
        Americium241 DECIMAL(18,6) ,                            
        Antimony124 DECIMAL(18,6) ,                            
        Antimony125 DECIMAL(18,6) ,                            
        Barium133 DECIMAL(18,6) ,                            
        Beryllium07 DECIMAL(18,6) ,                            
        Bismuth212 DECIMAL(18,6) ,                            
        Bismuth214 DECIMAL(18,6) ,                            
        Cadmium109 DECIMAL(18,6),                            
        Carbon14 DECIMAL(18,6) ,                            
        Cesium134 DECIMAL(18,6),                            
        Cesium137 DECIMAL(18,6),                            
        Chlorine36 DECIMAL(18,6) ,                      
        --- Cobalt56 DECIMAL(18,6),   -- Removed in prod                   
        Cobalt57 DECIMAL(18,6),                            
        Cobalt60 DECIMAL(18,6),                            
        Curium243 DECIMAL(18,6),                            
        Curium244 DECIMAL(18,6),                            
        Europium152 DECIMAL(18,6),                            
        Europium154 DECIMAL(18,6),                            
        Europium155 DECIMAL(18,6),                            
        Gadolinium153 DECIMAL(18,6),                            
        Germanium68 DECIMAL(18,6),                            
        Hydrogen3 DECIMAL(18,6),                            
        Indium114m DECIMAL(18,6),                            
        Iodine129 DECIMAL(18,6),                            
        Iridium192 DECIMAL(18,6),                            
        Iron55 DECIMAL(18,6),                            
        Iron59 DECIMAL(18,6),                            
        Potassium40 DECIMAL(18,6),                            
        Krypton85 DECIMAL(18,6),                            
        Lead212 DECIMAL(18,6),                            
        Lead210 DECIMAL(18,6),                            
        Lead214 DECIMAL(18,6),                            
        Manganese54 DECIMAL(18,6),                            
        Mercury203 DECIMAL(18,6),                            
        Nickel59 DECIMAL(18,6),                            
        Nickel63 DECIMAL(18,6),                            
        Niobium94 DECIMAL(18,6),                            
        Plutonium238 DECIMAL(18,6),                            
        Plutonium239 DECIMAL(18,6),                            
        Plutonium240 DECIMAL(18,6),                            
        Plutonium241 DECIMAL(18,6),                            
        Polonium210 DECIMAL(18,6),                            
        Promethium147 DECIMAL(18,6),                            
        Protactinium234m DECIMAL(18,6),                            
        Protactinium234 DECIMAL(18,6),         
        Plutonium242 DECIMAL(18,6),                            
        Radium226 DECIMAL(18,6),                            
        Radium228 DECIMAL(18,6),                            
        Rhenium187 DECIMAL(18,6),                            
        Samarium151 DECIMAL(18,6),                          
        Scandium46 DECIMAL(18,6),                            
        Silver108m DECIMAL(18,6),                            
        Silver110m DECIMAL(18,6),                            
        Sodium22 DECIMAL(18,6),                            
        Strontium90 DECIMAL(18,6),                            
        Tantalum182 DECIMAL(18,6),                            
        Technetium99 DECIMAL(18,6),                            
        Thallium204 DECIMAL(18,6),                            
        Thallium208 DECIMAL(18,6),                            
        Thorium228 DECIMAL(18,6),                            
        Thorium230 DECIMAL(18,6),                            
        Thorium232 DECIMAL(18,6),                            
        Thorium234 DECIMAL(18,6), 
		Thoriumnat DECIMAL(18,6),-- newly added after production update
        Tin121m DECIMAL(18,6),   
		Tritium DECIMAL(18,6), --name updated in  production update
        Tungsten181 DECIMAL(18,6),                            
        Uranium234 DECIMAL(18,6),                            
        Uranium235 DECIMAL(18,6),                            
        Uranium238 DECIMAL(18,6),  
		Uraniumdepleted DECIMAL(18,6), -- newly added after production update
        UraniumNatural DECIMAL(18,6),                            
        Yttrium88 DECIMAL(18,6),                            
        Zinc65 DECIMAL(18,6)
    );                        
      
    --Insert receipt IDs into the temp table                      
    INSERT INTO #TempTable (Sample_ID)                      
    SELECT DISTINCT receipt_id                      
    FROM dbo.Receipt                      
    WHERE receipt_id > 0 and receipt_id is not NULL      
   and receipt_date BETWEEN @StartDate and  @EndDate;            
                      
    -- Declare variables for dynamic SQL                      
    DECLARE @sql NVARCHAR(MAX);                      
    DECLARE @column_name NVARCHAR(255);                      
    DECLARE @const_id INT;                      
    DECLARE @const_desc NVARCHAR(255);                      
                      
    -- Cursor to iterate through all reportable constituents                      
    DECLARE const_cursor CURSOR FOR                      
    SELECT c.Const_ID, c.const_desc                      
    FROM dbo.Constituents c                      
    WHERE c.reportable_nuclide = 'T';                      
                      
    OPEN const_cursor;                      
    FETCH NEXT FROM const_cursor INTO @const_id, @const_desc;                      
                      
    WHILE @@FETCH_STATUS = 0                      
    BEGIN                      
        -- Format column name                      
        SET @column_name = REPLACE(REPLACE(REPLACE(LEFT(@const_desc,                       
            CASE                       
                WHEN CHARINDEX('(' , @const_desc) > 0                       
                THEN CHARINDEX('(' , @const_desc) - 1                       
                ELSE LEN(@const_desc)                       
            END), '-', ''), ' ', ''), '(', '');                      
        SET @column_name = REPLACE(@column_name, ')', '');                      
                      
        -- Check if the column exists in #TempTable                      
        IF COL_LENGTH('tempdb..#TempTable', @column_name) IS NOT NULL                      
        BEGIN                      
            -- Build dynamic SQL for updating the column                      
            SET @sql = 'UPDATE tt            
        SET ' + @column_name + ' = COALESCE(            
          ri.concentration,             
          pc.typical_concentration,             
          (pc.min_concentration + pc.concentration) / 2        
         )            
        FROM #TempTable tt       
        INNER JOIN dbo.Receipt r             
         ON tt.Sample_ID = r.receipt_id            
        LEFT JOIN dbo.receipt_isotope ri             
         ON r.receipt_id = ri.receipt_id            
         AND r.line_id = ri.line_id            
         AND r.company_id = ri.company_id            
         AND r.profit_ctr_id = ri.profit_ctr_id            
         AND ri.const_id = @const_id  -- Ensure correct match for constituent            
        LEFT JOIN dbo.ProfileConstituent pc             
         ON r.profile_id = pc.profile_id            
         AND pc.const_id = @const_id -- Match ProfileConstituent with same const_id            
        WHERE  r.receipt_date BETWEEN @StartDate AND @EndDate;';                      
                      
            -- Execute the dynamic SQL                      
            BEGIN TRY                      
                EXEC sp_executesql @sql, N'@StartDate DATE, @EndDate DATE, @const_id INT', @StartDate ,  @EndDate, @const_id;                      
            END TRY                      
            BEGIN CATCH                      
                PRINT 'Error updating column ' + @column_name + ': ' + ERROR_MESSAGE();                      
            END CATCH                      
        END                      
               
        FETCH NEXT FROM const_cursor INTO @const_id, @const_desc;                      
    END                      
                      
    CLOSE const_cursor;                      
    DEALLOCATE const_cursor;      
                      
   -- Select and return the final result                        
    SELECT Distinct                       
        r.company_id,                               
        r.profit_ctr_id,                               
        r.receipt_id,                               
        r.profile_id,                    
        r.approval_code AS Approval_ID,                               
        r.receipt_date AS Received_Date,                            
        r.manifest_page_num,                          
        r.manifest_line,                              
        r.manifest_unit,                              
        r.manifest_quantity AS Manifest_Qty_LBS,                              
        r.manifest_quantity / 2000.0 AS Manifest_Qty_TONS,                
  CASE                               
   WHEN ri.const_id IS NOT NULL THEN 'Receipt'                               
   ELSE 'Profile'                               
  END AS Data_Source,              
  tt.*              
  FROM dbo.Receipt r                              
  LEFT JOIN dbo.receipt_isotope ri ON r.receipt_id = ri.receipt_id AND r.line_id = ri.line_id   AND  r.company_id = ri.company_id  AND r.profit_ctr_id=ri.profit_ctr_id                          
  LEFT JOIN dbo.ProfileConstituent pc ON r.profile_id = pc.profile_id                             
  LEFT JOIN dbo.Constituents c ON c.const_id = ISNULL(ri.const_id, pc.const_id)                        
  LEFT JOIN #TempTable tt ON r.receipt_id = tt.Sample_ID                      
  WHERE             
   r.company_id = @company_id           
   AND r.trans_type = 'D' -- To Exclude Receipt created with SRVC/product              
   AND r.profit_ctr_id  = @profit_ctr_id           
   AND r.receipt_date BETWEEN @StartDate AND @EndDate;               
                        
    -- Drop the Temp Table                      
    DROP TABLE #TempTable;                      
                    
END 
GO

-- Grant execution permissions to users
GRANT EXECUTE ON [dbo].[sp_radioactive_isotopes_received] TO EQAI
GO