USE [PLT_AI]
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_create_note] (
	@company_id INT, 
	@profit_ctr_id INT, 
	@customer_id INT,
	@generator_id INT,	 
	@note_source VARCHAR (30),
	@note_source_id INT,
	@note_type VARCHAR(15),
	@note_status CHAR(1), 
	@note_subject VARCHAR(50), 
	@note_text VARCHAR(255),
	@app_source VARCHAR(20),
	@contact_type VARCHAR(15),
	@salesforce_json_flag VARCHAR(1))
AS
/***************************************************************************************  
 This procedure creates a Note record
     
 08/28/2024 - Dipankar - DevOps: 94706: Created  
 
****************************************************************************************/  
BEGIN
	DECLARE @note_id INT,
			@today_dttm DATETIME = GETDATE(),
			@modified_by VARCHAR(10) = 'SA'
		
	BEGIN TRANSACTION  
	EXEC @note_id = plt_ai.dbo.sp_sequence_next 'Note.note_id'  
	COMMIT TRANSACTION  
	
	IF IsNull(@note_id,0) > 0  
	BEGIN  
		IF OBJECT_ID('tempdb..#Note') IS NULL
			SELECT * INTO #Note
			FROM Note WHERE 1=0

		IF OBJECT_ID('tempdb..#Note') IS NOT NULL
			INSERT INTO #Note 
			(rowguid, note_id, note_source, company_id, profit_ctr_id, note_date, subject, status, note_type, note, customer_id, generator_id, receipt_id, 
			 contact_type, added_by, date_added, modified_by, date_modified, app_source, salesforce_json_flag)  
			VALUES (NEWID(), @note_id, @note_source, @company_id, @profit_ctr_id, @today_dttm, @note_subject, @note_status, @note_type, @note_text, @customer_id,
			        @generator_id, @note_source_id, @contact_type, @modified_by, @today_dttm, @modified_by, @today_dttm, @app_source, @salesforce_json_flag)  
	END 
END

GO

GRANT EXECUTE ON [dbo].[sp_create_note] TO EQAI
GO