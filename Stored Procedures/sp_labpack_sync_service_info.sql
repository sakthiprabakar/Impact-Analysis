-- =============================================
-- Author:		Senthil Kumar
-- Create date: 27-04-2020
-- Description:	To fetch service info data
-- EXEC sp_labpack_sync_service_info 232932
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_sync_service_info]
	-- Add the parameters for the stored procedure here
	  @trip_connect_log_id int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

   SELECT woh.workorder_ID
,woh.customer_ID,cus.cust_name,	woh.generator_id,gen.generator_name,purchase_order
,woh.trip_id,tph.transporter_code,trans.transporter_name,pc.company_ID,pc.profit_ctr_ID,pc.profit_ctr_name,woh.trip_sequence_id
FROM TripConnectLog tcl
JOIN WorkOrderHeader woh ON woh.trip_id = tcl.trip_id and ISNULL(woh.field_requested_action,'') <> 'D'
JOIN ProfitCenter pc ON pc.company_id = woh.company_id and pc.profit_ctr_ID = woh.profit_ctr_ID
LEFT JOIN customer cus ON woh.customer_ID= cus.customer_ID 
LEFT JOIN generator gen ON woh.generator_id= gen.generator_id 
LEFT JOIN TripHeader tph ON tph.trip_id=tcl.trip_id
LEFT JOIN Transporter trans ON trans.transporter_code=tph.transporter_code and ISNULL(trans.Transporter_status,'I') = 'A'
--left join WorkOrderStop wos on wos.workorder_ID=woh.workorder_ID and wos.company_id=woh.company_id and wos.profit_ctr_id=woh.profit_ctr_id
  WHERE tcl.trip_connect_log_id =@trip_connect_log_id
END