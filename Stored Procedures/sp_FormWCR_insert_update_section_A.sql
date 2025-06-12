USE [PLT_AI]
GO
/**********************************************************************************************************/
DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update_section_A] 
GO 
CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update_section_A]

       @Data XML,		
	   @form_id int,
	   @revision_id int
AS
/* ******************************************************************
Updated By   : Ranjini C
Updated On   : 08-AUGUST-2024
Ticket       : 93217
Decription   : This procedure is used to assign web_userid to created_by and modified_by columns
****************************************************************** */
    BEGIN
	 BEGIN TRY 
	 
	 CREATE TABLE #various_generators
	(
		gen_name nvarchar(40)
	)
	insert into #various_generators values
	 ('VARIOUS SITES FOR THIS CUSTOMER'), ('VARIOUS')
	   
        UPDATE  FormWCR SET
              generator_id = 			  
			  case when p.v.value('generator_name[1]','varchar(40)') in (select gen_name from #various_generators) 
						then 0  
					when p.v.value('generator_id[1]','int') > 0 
						then p.v.value('generator_id[1]','int') 
					else  -1 end,
              generator_name = p.v.value('generator_name[1]','varchar(40)'),
              generator_address1 = p.v.value('generator_address1[1]','varchar(40)'),
			  generator_address2 = p.v.value('generator_address2[1]','varchar(40)'),
			  generator_address3 = p.v.value('generator_address3[1]','varchar(40)'),
			  generator_address4 = p.v.value('generator_address4[1]','varchar(40)'),
			  generator_phone = p.v.value('generator_phone[1]','varchar(20)'),
			  generator_country = p.v.value('generator_country[1]','varchar(3)'),
              generator_city = p.v.value('generator_city[1]','varchar(40)'),
              generator_state = p.v.value('generator_state[1]','char(2)'),
              generator_zip = p.v.value('generator_zip[1]','varchar(10)'),
			  gen_mail_name = case when p.v.value('generator_id[1]','int') = 0 then p.v.value('generator_name[1]','varchar(40)') else (SELECT gen_mail_name FROM Generator WHERE generator_id in(p.v.value('generator_id[1]','int'))) end,
              gen_mail_address1 = p.v.value('gen_mail_address1[1]','varchar(40)'),
			  gen_mail_address2 = p.v.value('gen_mail_address2[1]','varchar(40)'),
			  gen_mail_address3 = p.v.value('gen_mail_address3[1]','varchar(40)'),
			  gen_mail_address4 = p.v.value('gen_mail_address4[1]','varchar(40)'),
              gen_mail_city = p.v.value('gen_mail_city[1]','varchar(40)'),
              gen_mail_state = p.v.value('gen_mail_state[1]','char(2)'),
              gen_mail_zip = p.v.value('gen_mail_zip[1]','varchar(10)'),
			  gen_mail_country = p.v.value('gen_mail_country[1]','varchar(3)'),
			  tech_contact_id = p.v.value('tech_contact_id[1]','int'),
              tech_contact_name = p.v.value('tech_contact_name[1]','varchar(40)'),
              tech_contact_phone = p.v.value('tech_contact_phone[1]','varchar(20)'),
              tech_cont_email = p.v.value('tech_cont_email[1]','varchar(50)'),
			  generator_type_ID = p.v.value('generator_type_ID[1]','int'),
              EPA_ID = p.v.value('EPA_ID[1]','varchar(12)'),
              NAICS_code = p.v.value('NAICS_code[1][not(@xsi:nil = "true")]','int'),
              state_id = p.v.value('state_id[1]','varchar(40)'),
              po_required = p.v.value('po_required[1]','char(1)'),
			  purchase_order = p.v.value('purchase_order[1]','varchar(20)'),
			  customer_id = case when p.v.value('customer_id[1]','int') = 0 then null else p.v.value('customer_id[1]','int') end,
              inv_contact_name = p.v.value('inv_contact_name[1]','varchar(40)'),
              inv_contact_phone = p.v.value('inv_contact_phone[1]','varchar(20)'),
              inv_contact_email = p.v.value('inv_contact_email[1]','varchar(50)'),
			  inv_contact_id = p.v.value('inv_contact_id[1]','int'),
              cust_name = p.v.value('cust_name[1]','varchar(40)'),
              cust_addr1 = p.v.value('cust_addr1[1]','varchar(40)'),
			  cust_addr2 = p.v.value('cust_addr2[1]','varchar(40)'),
			  cust_addr3 = p.v.value('cust_addr3[1]','varchar(40)'),
			  cust_addr4 = p.v.value('cust_addr4[1]','varchar(40)'),
              cust_city = p.v.value('cust_city[1]','varchar(40)'),
              cust_state = p.v.value('cust_state[1]','char(2)'),
              cust_zip = p.v.value('cust_zip[1]','varchar(10)'),
			  cust_country = p.v.value('cust_country[1]','varchar(3)')
        FROM
        @Data.nodes('SectionA')p(v) WHERE form_id = @form_id and revision_id=  @revision_id;
		DROP TABLE #various_generators;
		END TRY
		BEGIN CATCH				
				declare @mailTrack_userid nvarchar(60) = 'COR'
				INSERT INTO [COR_DB].[DBO].ErrorLogs(ErrorDescription, [Object_Name],Web_user_id, CreatedDate) 
				VALUES(Error_Message(), ERROR_PROCEDURE(),@mailTrack_userid,GetDate())
				declare @procedure nvarchar(150) 
				set @procedure = ERROR_PROCEDURE()
				declare @error nvarchar(4000) = ERROR_MESSAGE()
				declare @error_description nvarchar(4000) = 'Form ID: ' + convert(nvarchar(15), @form_id) + '-' +  convert(nvarchar(15), @revision_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@error, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(4000),@Data)
														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error_description

		END CATCH
       END

GO

	GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update_section_A] TO COR_USER;

GO
/**********************************************************************************************************/