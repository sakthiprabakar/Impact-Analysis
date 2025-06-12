Go

DROP PROCEDURE IF EXISTS sp_labpack_sync_report_label 
GO


CREATE PROCEDURE [dbo].[sp_labpack_sync_report_label]
    @Trip_Id INT,
    @WorkOrder_Id INT,
    @Company_Id INT,
    @Profit_Ctr_Id INT,
    @Manifest_State CHAR(2),
    @TSDF_code VARCHAR(15),
    @Manifest VARCHAR(15)
AS

/* ******************************************************************

 Author  : Ranjini
 Updated On : 29-Sep-2023
 Type  : Store Procedure
 Object Name : [dbo].[sp_labpack_sync_report_label]

 Description : Procedure to get label report details

 Input  :  @Trip_Id INT,
   @WorkOrder_Id  INT,
   @Company_Id  INT,
   @Profit_Ctr_Id  INT,
   @Manifest_State CHAR(2),
   @TSDF_code VARCHAR(15),
   @Manifest VARCHAR(15)

 Execution Statement : EXEC [plt_ai].[dbo].[sp_labpack_sync_report_label]  126337,26901000,14,4,'H','EQPA','100'

****************************************************************** */

BEGIN
    CREATE TABLE #TempResult1 (
        Sno INT,
        work_order_id INT,
        company_id INT,
        profit_ctr_id INT,
        sequence_id INT,
        bill_unit_code VARCHAR(10),
        quantity INT,
        ERG_number INT,
        generator_name VARCHAR(75),
        generator_address_1 VARCHAR(85),
        generator_city VARCHAR(40),
        generator_state VARCHAR(2),
        generator_zip_code VARCHAR(15),
        EPA_ID VARCHAR(12),
        manifest VARCHAR(15),
        container_code VARCHAR(15),
        approval_code VARCHAR(15),
        UN_NA_Number VARCHAR(30),
        manual_entry_desc VARCHAR(50),
        UNNA_Description VARCHAR(MAX),
        container_weight VARCHAR(50),
        waste_codes VARCHAR(MAX),
        manifest_line INT,
        label_description VARCHAR(MAX),
        label_uid INT,
        label_type CHAR(1),
        inventoryconstituent_name VARCHAR(50),
        notes VARCHAR(255),
        epa_rcra_codes VARCHAR(MAX),
        size VARCHAR(50),
        phase VARCHAR(50)
    );

    DECLARE @Sno INT;
    DECLARE @sequence_ID INT;
    DECLARE @bill_unit_code VARCHAR(10);
    DECLARE @quantity INT;
    DECLARE @ERG_number INT;
    DECLARE @generator_name VARCHAR(75);
    DECLARE @generator_address_1 VARCHAR(85);
    DECLARE @generator_city VARCHAR(40);
    DECLARE @generator_state VARCHAR(2);
    DECLARE @generator_zip_code VARCHAR(15);
    DECLARE @EPA_ID VARCHAR(12);
    DECLARE @container_code VARCHAR(15);
    DECLARE @UNNA_Description VARCHAR(MAX);
    DECLARE @Container_Weight VARCHAR(50);
    DECLARE @WasteCodes VARCHAR(MAX);
    DECLARE @approval_code VARCHAR(15);
    DECLARE @UN_NA_Number VARCHAR(30);
    DECLARE @manual_entry_desc VARCHAR(50);
    DECLARE @manifest_line INT;
    DECLARE @LabelDescription VARCHAR(MAX);
    DECLARE @label_Uid INT;
    DECLARE @label_type CHAR(1);
    DECLARE @inventoryconstituent_name VARCHAR(50);
    DECLARE @notes VARCHAR(255);
    DECLARE @epa_rcra_codes VARCHAR(MAX);
    DECLARE @size VARCHAR(50);
    DECLARE @phase VARCHAR(50);

    DECLARE curTempResult CURSOR FOR
    SELECT DISTINCT
        ROW_NUMBER() OVER(ORDER BY wd.workorder_ID ASC) AS Row,
        wd.workorder_ID,
        wd.company_id,
        wd.profit_ctr_ID,
        wd.sequence_ID,
        wdu.bill_unit_code,
        wdu.quantity,
        wd.ERG_number,
        g.generator_name,
        g.generator_address_1,
        g.generator_city,
        generator_state,
        g.generator_zip_code,
        g.EPA_ID,
        wd.container_code,
        pqa.approval_code,
        (SELECT CONCAT(wd.un_na_flag, wd.un_na_number)) AS UN_NA_Number,
        woditm.manual_entry_desc,
        (SELECT CONCAT(wd.UN_NA_flag, wd.UN_NA_Number, ',', wd.DOT_shipping_name, wd.hazmat_class, ',', 'PG ', wd.package_group, ' ', wd.manifest_dot_sp_number, ' ERG No. ', wd.ERG_number)) AS UNNA_Description,
        (SELECT CONCAT(woditm.pounds, ' ', p.bill_unit_code)) AS Container_Weight,
        STUFF((SELECT DISTINCT TOP 6 ' ' + wowc.waste_code FROM workorderwastecode wowc
               WHERE wowc.workorder_id = wd.workorder_id AND wd.company_id = wowc.company_id AND wd.profit_ctr_id = wowc.profit_ctr_id AND wd.sequence_id = wowc.workorder_sequence_id
               FOR XML PATH('')), 1, 1, '') AS WasteCodes,
        wd.manifest_line,
        CASE
            WHEN lh.label_type = 'H' THEN
                CASE
                    WHEN g.generator_state = 'WA' THEN
                        'Federal law prohibits improper disposal. If found, contact the nearest police or public safety Authority, or the U.S. Environmental Protection Agency and the Washington State Department of Ecology or the Environmental Protection Agency'
                    WHEN g.generator_state = 'NJ' THEN
                        'Federal law prohibits improper disposal. If found, contact the nearest police or public safety Authority, or the U.S. Environmental Protection Agency or the New Jersey Department of Environmental Protection'
                    WHEN g.generator_state = 'CA' THEN
                        'Federal law prohibits improper disposal. If found, contact the nearest police or public safety Authority, or the U.S. Environmental Protection Agency or the California Department of Toxic Substances Control'
                    ELSE
                        'Federal law prohibits improper disposal. If found, contact the nearest police or public safety Authority, or the U.S. Environmental Protection Agency'
                END
            WHEN lh.label_type = 'N' THEN
                'This waste is not regulated by 40CFR part 261 or 49CFR part 171'
            WHEN lh.label_type = 'R' THEN
                'This waste is not regulated by 40CFR Part 2626 but may be subject to Department of Transportation Regulations'
        END AS LabelDescription,
        lh.label_uid,
        lh.label_type,
        ln.inventoryconstituent_name,
        ln.notes,
        ln.epa_rcra_codes,
        ln.size,
        ln.phase
    FROM
        workorderdetail wd
    JOIN WorkOrderHeader woh ON wd.WorkOrder_Id = woh.WorkOrder_Id
        AND woh.Company_Id = wd.Company_Id
        AND woh.Profit_Ctr_Id = wd.Profit_Ctr_Id
    JOIN
        workorderdetailunit wdu ON wd.sequence_ID = wdu.sequence_ID
        AND wd.workorder_ID = wdu.workorder_id
        AND wd.company_id = wdu.company_id
        AND wd.profit_ctr_ID = wdu.profit_ctr_id
    JOIN WorkorderManifest wom ON wom.workorder_ID = wd.workorder_ID
        AND wom.Company_Id = wd.Company_Id
        AND wom.Profit_Ctr_Id = wd.Profit_Ctr_Id
        AND wom.manifest = wd.manifest
   
    JOIN generator g ON g.generator_id = woh.generator_id
    JOIN profile p ON p.profile_id = wd.profile_id
    JOIN WorkOrderDetailItem woditm ON woditm.workorder_id = wd.workorder_id
        AND woditm.company_id = wd.company_id
        AND woditm.profit_ctr_id = wd.profit_ctr_id
        AND woditm.sequence_id = wd.sequence_id
        AND woditm.sub_sequence_id = 0
    JOIN ProfileQuoteApproval pqa ON pqa.profile_id = wd.profile_id
    JOIN LabPackLabel lh ON lh.workorder_id = wd.workorder_ID
        AND lh.company_id = wd.company_id
        AND lh.profit_ctr_id = wd.profit_ctr_ID
        AND lh.TSDF_code = wd.TSDF_code
        AND lh.sequence_id = wd.sequence_id
    JOIN LabpackLabelXInventory ln ON ln.label_uid = lh.label_uid
    WHERE
        woh.trip_id = @Trip_Id
        AND wd.workorder_ID = @WorkOrder_Id
        AND wd.company_id = @Company_Id
        AND wd.profit_ctr_ID = @Profit_Ctr_Id
        AND wom.manifest_state = @Manifest_State
        AND wd.TSDF_code = @TSDF_code
        AND wd.manifest = @Manifest
        AND wdu.quantity > 0
        AND wdu.billing_flag = 'T'
        AND wdu.sequence_id = wd.sequence_ID;

    OPEN curTempResult;

    FETCH NEXT FROM curTempResult INTO @Sno, @workorder_ID, @company_id, @profit_ctr_ID, @sequence_ID, @bill_unit_code, @quantity, @ERG_number,
        @generator_name,
        @generator_address_1,
        @generator_city,
        @generator_state,
        @generator_zip_code,
        @EPA_ID,
        @container_code,
        @approval_code,
        @UN_NA_Number,
        @manual_entry_desc,
        @UNNA_Description,
        @Container_Weight,
        @WasteCodes,
        @manifest_line,
        @LabelDescription,
        @label_Uid,
        @label_type,
        @inventoryconstituent_name,
        @notes,
        @epa_rcra_codes,
        @size,
        @phase;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @counter INT;
        SET @counter = 1;

        WHILE @counter <= @quantity
        BEGIN

            INSERT INTO #TempResult1 (
                Sno,
                work_order_id,
                company_id,
                profit_ctr_id,
                sequence_id,
                bill_unit_code,
                quantity,
                ERG_number,
                generator_name,
                generator_address_1,
                generator_city,
                generator_state,
                generator_zip_code,
                EPA_ID,
                manifest,
                container_code,
                approval_code,
                UN_NA_Number,
                manual_entry_desc,
                UNNA_Description,
                container_weight,
                waste_codes,
                manifest_line,
                label_description,
                label_uid,
                label_type,
                inventoryconstituent_name,
                notes,
                epa_rcra_codes,
                size,
                phase
            )
            VALUES (
                @Sno,
                @workorder_ID,
                @company_id,
                @profit_ctr_ID,
                @sequence_ID,
                @bill_unit_code,
                @quantity,
                @ERG_number,
                @generator_name,
                @generator_address_1,
                @generator_city,
                @generator_state,
                @generator_zip_code,
                @EPA_ID,
                @manifest,
                @container_code,
                @approval_code,
                @UN_NA_Number,
                @manual_entry_desc,
                @UNNA_Description,
                @Container_Weight,
                @WasteCodes,
                @manifest_line,
                @LabelDescription,
                @label_Uid,
                @label_type,
                @inventoryconstituent_name,
                @notes,
                @epa_rcra_codes,
                @size,
                @phase
            );

            SET @counter = @counter + 1;
        END;

        FETCH NEXT FROM curTempResult INTO @Sno, @workorder_ID, @company_id, @profit_ctr_ID, @sequence_ID, @bill_unit_code, @quantity, @ERG_number,
            @generator_name,
            @generator_address_1,
            @generator_city,
            @generator_state,
            @generator_zip_code,
            @EPA_ID,
            @container_code,
            @approval_code,
            @UN_NA_Number,
            @manual_entry_desc,
            @UNNA_Description,
            @Container_Weight,
            @WasteCodes,
            @manifest_line,
            @LabelDescription,
            @label_Uid,
            @label_type,
            @inventoryconstituent_name,
            @notes,
            @epa_rcra_codes,
            @size,
            @phase;

    END;

    CLOSE curTempResult;
    DEALLOCATE curTempResult;
    SELECT * FROM #TempResult1;

    DROP TABLE #TempResult1;
END;

GO

GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_label] TO LPSERV;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_label] TO COR_USER;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_label] TO EQWEB;
GO
GRANT EXECUTE ON [dbo].[sp_labpack_sync_report_label] TO EQAI;
GO