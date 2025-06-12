USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_resourceclass_code_equipment]    Script Date: 1/6/2022 8:51:12 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP procedure IF EXISTS [dbo].[sp_resourceclass_code_equipment]

GO
CREATE PROCEDURE sp_resourceclass_code_equipment
       @company_id                       varchar(3)
,      @profit_ctr_id                    varchar(3)
,      @project_quote_id          varchar(15)
,      @customer_id               varchar(15)
AS 
/****************************************************************************
This stored procedure selects the lsit of resource class codes to show when user clicks on
the "equipment" button on Work Order. It fetches the codes based on following order:
Project quote resource class codes supersedes the same codes defined on customer or base rate quote
Customer quote resource class codes supersedes the same codes defined on base rate quote
If codes are not found in project quote & customer quote then the base rate quote codes are shown.

Filename:           F:\EQAI\SQL\EQAI\sp_resourceclass_code_equipment.sql
PB Object(s): d_quick_select_equipment
Load on PLT_AI
             
12/10/2021 AM   DevOps:20905 - New procedure created
05/26/2022 MPM  DevOps 38903 - Added item_number and pc_use_resource_class_item_flag
                to the result set.

****************************************************************************/

DECLARE @ResourceClass_Codes TABLE(
       qty                                     int
,      resource_class_code        varchar(10)
,      bill_unit_code                    varchar(4)
,      description                       varchar(100)
,      bill_rate                         float
,      cost                             money
,      price                            money
,      quote_id                          int
,      description2               varchar(100)
,      quote_type                        char(1)
,      emanifest_submission_type_uid int
,       item_number                     varchar(10)
,       pc_use_resource_class_item_flag char(1)
)

-- Insert resource_class_codes from the Project Quote if found
IF @project_quote_id > 0
BEGIN
       INSERT INTO @ResourceClass_Codes
       SELECT
             1 AS qty,
             WorkorderQuoteDetail.resource_item_code,
        WorkorderQuoteDetail.bill_unit_code,
        WorkorderQuoteDetail.service_desc AS description,
             ResourceClass.bill_rate,
             WorkorderQuoteDetail.cost,
             WorkorderQuoteDetail.price,
             WorkorderQuoteDetail.quote_id,
        WorkorderQuoteDetail.resource AS description_2,
             WorkOrderQuoteHeader.quote_type,
             ResourceClassHeader.emanifest_submission_type_uid,
             ResourceClassDetail.item_number,
             ProfitCenter.use_resource_class_item_flag
       FROM WorkorderQuoteDetail
       INNER JOIN WorkOrderQuoteHeader 
             ON WorkOrderQuoteHeader.company_id = WorkorderQuoteDetail.company_id
             AND WorkOrderQuoteHeader.quote_id = WorkorderQuoteDetail.quote_id
             AND WorkOrderQuoteHeader.quote_type = 'P'
       INNER JOIN ResourceClass 
             ON WorkorderQuoteDetail.company_id = ResourceClass.company_id
             AND WorkorderQuoteDetail.profit_ctr_id = ResourceClass.profit_ctr_id
             AND WorkorderQuoteDetail.resource_type = ResourceClass.resource_type
             AND WorkorderQuoteDetail.resource_item_code = ResourceClass.resource_class_code
             AND WorkorderQuoteDetail.bill_unit_code = ResourceClass.bill_unit_code
       INNER JOIN ResourceClassHeader 
           ON  ResourceClass.resource_class_code = ResourceClassHeader.resource_class_code
        INNER JOIN ResourceClassDetail 
            ON ResourceClassDetail.company_id = ResourceClass.company_id
            AND ResourceClassDetail.profit_ctr_id = ResourceClass.profit_ctr_id
            AND ResourceClassDetail.resource_class_code = ResourceClassHeader.resource_class_code
            AND ResourceClassDetail.bill_unit_code = WorkorderQuoteDetail.bill_unit_code
        INNER JOIN ProfitCenter
	        ON ProfitCenter.company_id = ResourceClassDetail.company_id
	        AND ProfitCenter.profit_ctr_id = ResourceClassDetail.profit_ctr_id
        WHERE WorkorderQuoteDetail.resource_type = 'E'
             AND ResourceClass.status = 'A'
             AND WorkOrderQuoteDetail.quote_id = @project_quote_id
             AND WorkOrderQuoteDetail.company_id = @company_id
             AND WorkOrderQuoteDetail.profit_ctr_id = @profit_ctr_id
END

-- Insert remaining resource_class_codes from the Customer Quote if found
IF @customer_id > 0
BEGIN
       INSERT INTO @ResourceClass_Codes
       SELECT
             1 AS qty,
             WorkorderQuoteDetail.resource_item_code,
        WorkorderQuoteDetail.bill_unit_code,
        WorkorderQuoteDetail.service_desc AS description,
             ResourceClass.bill_rate,
             WorkorderQuoteDetail.cost,
             WorkorderQuoteDetail.price,
             WorkorderQuoteDetail.quote_id,
        WorkorderQuoteDetail.resource AS description_2,
             WorkOrderQuoteHeader.quote_type,
             ResourceClassHeader.emanifest_submission_type_uid,
             ResourceClassDetail.item_number,
             ProfitCenter.use_resource_class_item_flag
       FROM WorkorderQuoteDetail
       INNER JOIN WorkOrderQuoteHeader 
             ON WorkOrderQuoteHeader.company_id = WorkorderQuoteDetail.company_id
             AND WorkOrderQuoteHeader.quote_id = WorkorderQuoteDetail.quote_id
             AND WorkOrderQuoteHeader.quote_type = 'C'
       INNER JOIN ResourceClass 
             ON WorkorderQuoteDetail.company_id = ResourceClass.company_id
             AND WorkorderQuoteDetail.profit_ctr_id = ResourceClass.profit_ctr_id
             AND WorkorderQuoteDetail.resource_type = ResourceClass.resource_type
             AND WorkorderQuoteDetail.resource_item_code = ResourceClass.resource_class_code
             AND WorkorderQuoteDetail.bill_unit_code = ResourceClass.bill_unit_code
       INNER JOIN ResourceClassHeader 
           ON  ResourceClass.resource_class_code = ResourceClassHeader.resource_class_code
        INNER JOIN ResourceClassDetail 
            ON ResourceClassDetail.company_id = ResourceClass.company_id
            AND ResourceClassDetail.profit_ctr_id = ResourceClass.profit_ctr_id
            AND ResourceClassDetail.resource_class_code = ResourceClassHeader.resource_class_code
            AND ResourceClassDetail.bill_unit_code = WorkorderQuoteDetail.bill_unit_code
        INNER JOIN ProfitCenter
	        ON ProfitCenter.company_id = ResourceClassDetail.company_id
	        AND ProfitCenter.profit_ctr_id = ResourceClassDetail.profit_ctr_id
        WHERE WorkorderQuoteDetail.resource_type = 'E'
             AND ResourceClass.status = 'A'
             AND WorkOrderQuoteDetail.quote_id = @project_quote_id
             AND WorkOrderQuoteDetail.company_id = @company_id
             AND WorkOrderQuoteDetail.profit_ctr_id = @profit_ctr_id
             AND WorkOrderQuoteDetail.resource_item_code NOT IN (SELECT DISTINCT resource_class_code FROM @ResourceClass_Codes )
END 

-- Insert remaining resource_class_codes from the Base Rate Quote
INSERT INTO @ResourceClass_Codes
SELECT 
       1 AS qty,
       ResourceClass.resource_class_code AS resource_item_code,
    ResourceClass.bill_unit_code,
    ResourceClass.description,
       ResourceClass.bill_rate,
       ResourceClass.cost,
       WorkOrderQuoteDetail.price,
       WorkOrderQuoteHeader.quote_id,
       CONVERT(varchar(60), NULL) AS description_2,
       WorkOrderQuoteHeader.quote_type,
       ResourceClassHeader.emanifest_submission_type_uid,
        ResourceClassDetail.item_number,
        ProfitCenter.use_resource_class_item_flag
FROM ResourceClass
INNER JOIN WorkOrderQuoteHeader 
       ON WorkOrderQuoteHeader.company_id = ResourceClass.company_id
       AND WorkOrderQuoteHeader.quote_type = 'B'
INNER JOIN WorkOrderQuoteDetail 
       ON WorkOrderQuoteDetail.quote_id = WorkOrderQuoteHeader.quote_id
       AND WorkOrderQuoteDetail.company_id = ResourceClass.company_id
       AND WorkOrderQuoteDetail.profit_ctr_id = ResourceClass.profit_ctr_id
       AND WorkOrderQuoteDetail.resource_type = ResourceClass.resource_type
       AND WorkOrderQuoteDetail.resource_item_code = ResourceClass.resource_class_code
       AND WorkOrderQuoteDetail.bill_unit_code = ResourceClass.bill_unit_code
INNER JOIN ResourceClassHeader 
           ON  ResourceClass.resource_class_code = ResourceClassHeader.resource_class_code
        INNER JOIN ResourceClassDetail 
            ON ResourceClassDetail.company_id = ResourceClass.company_id
            AND ResourceClassDetail.profit_ctr_id = ResourceClass.profit_ctr_id
            AND ResourceClassDetail.resource_class_code = ResourceClassHeader.resource_class_code
            AND ResourceClassDetail.bill_unit_code = WorkorderQuoteDetail.bill_unit_code
        INNER JOIN ProfitCenter
	        ON ProfitCenter.company_id = ResourceClassDetail.company_id
	        AND ProfitCenter.profit_ctr_id = ResourceClassDetail.profit_ctr_id
     WHERE ResourceClass.resource_type = 'E'
       AND ResourceClass.status = 'A'
       AND ResourceClass.company_id = @company_id
       AND ResourceClass.profit_ctr_id = @profit_ctr_id
       AND WorkOrderQuoteDetail.resource_item_code NOT IN (SELECT DISTINCT resource_class_code FROM @ResourceClass_Codes )

-- Select the result set
SELECT * FROM @ResourceClass_Codes

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_resourceclass_code_equipment] TO [EQAI]
    AS [dbo];

GO
