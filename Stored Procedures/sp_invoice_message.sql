DROP PROCEDURE IF EXISTS sp_invoice_message
GO

CREATE OR ALTER PROCEDURE sp_invoice_message
	@message_type		char(1),	-- M	Mail
									-- F	Fax
									-- E	Email Message Only
									-- U	UPS
									-- A	Email with Documents
	@invoice_code		varchar(16),
	@date_to_send		datetime,
	@package_content	char(1),	-- I = Invoice
									-- A = Invoice + Attachments
									-- C = Invoice + Attachments combined as 1 PDF
	@image_id_invoice	int,
	@image_id_attach	int,
	@name_to			varchar(50),
	@company_to			varchar(50),
	@email_to			varchar(100),
	@fax_to				varchar(20),
	@phone_to			varchar(20),
	@user_code 			varchar(10),
	@revision_id		int,
	@credit_memo_image_id int
AS
/**************************************************************************
Load to Plt_AI
PB Object(s):	w_invoice_print_view

12/17/2008 JDB	Created
01/08/2009 JDB	Updated the HTML company name dash to use &ndash;
02/05/2009 JDB	Modified to skip inserting into MessageAttachment if the
				@image_id_attach parameter is NULL
05/20/2013 JPB	Added @special_note* fields for time-limited exra messages to add to the Invoice notifications per GEM:25140
				Rearranged the different message type content sections to avoid repeating code unnecessarily.
06/25/2014 JPB	Added EQ/USEcology attachment logic
12/02/2014 JDB	Added EQ Michigan Regional Office Move/W-9 attachment logic
01/15/2015 JDB	Added US Ecology Rebranding attachment logic.
01/16/2015 JPB	Changed message subject/wording for US Ecology.
12/13/2016 MPM	Changed @special_note fields until 1/15/17 with new remittance info.
06/16/2017 MPM	Changed the message subject and message body if the revision_id > 1.
06/29/2018 AM   GEM:51719 - Added @config_value to add diffrent verbiage for e-manifest
12/06/2018 MPM	GEM 56790 - Removed the changes made under GEM 51719 so that the e-Manifest message is no longer appearing.
08/14/2020 AM   DevOps:17123 - Update to system generated invoice emails from online services to COR
10/26/2020 MPM	DevOps 12258 - Added option to generate 1 file for Invoice and Attachments.
07/18/2023 AM   DevOps:58380 - Update email for system generated invoices
10/25/2023 AGC  DevOps 65577 add credit memo image id
2/15/2024 Prakash Reverted code changes for DevOps 75591 & 75593
04/05/2024 AM DevOps:80655 - Added invoicetemplate_email_subject_line if company has template.
04/14/2024 Dipankar DevOps:80883, 80885, 80886 - Modified email verbiage for Standard Invoices, Revised Invoices & Invoice Package Email.
05/20/2024 Dipankar DevOps: 85673 - Invoice Email Verbiage update for Invoice package with Distribution Method of 'Email Message Only'
06/03/2024 AM DevOps:88351 - Modified invoicetemplate_email_subject_line logic.
08/02/2024 Subhrajyoti Rally# US117903: EQAI - Automated email change for --EQAI billing team
08/28/2024 Subhrajyoti Rally# DE35054: EQAI REVISED Customer or Company invoice subject incorrect

sp_invoice_message 'A', '97277', '11/26/14 16:29', 'A', 1590029, 1590030, 'Jason Boyette', 'Amazon', 'jason.boyette@usecology.com', '', '', 'JASON_B'
sp_invoice_message 'A', '97277', '12/13/16 13:49', 'A', 1590029, 1590030, 'Martha Molchan', 'Amazon', 'martha.molchan@usecology.com', '', '', 'MARTHA_M', 2
sp_invoice_message 'A', '97277', '06/29/18 13:49', 'A', 1590029, 1590030, 'Anitha Maramreddy', 'TEST', 'anitha.maramreddy@usecology.com', '', '', 'ANITHA_M', 2
sp_invoice_message 'A', 'Preview_1350480', '12/06/18 14:00', 'I', 1349509, 1590030, 'Martha Molchan', 'Test', 'martha.molchan@usecology.com', '', '', 'MARTHA_M', 2

select top 10 * from message order by date_added desc	
**************************************************************************/
BEGIN
	DECLARE	@message_id			int,
			@message_table_type	char(1),		-- E = E-mail;	F = Fax
			@subject			varchar(100),
			@status				char(1),
			@message_source		varchar(30),

			@body				varchar(4000),
			@message_greeting	varchar(100),
			@message			varchar(4000),
			@message_close		varchar(2000),
			@body_extn          varchar(2000),
			@html_body_extn     varchar(2000),

			@html_greeting		varchar(100),
			@html				varchar(4000),
			@html_close			varchar(2000),
			@email_from			varchar(100),
			@email_bcc			varchar(100),
			@name_from			varchar(50),
			@company_from		varchar(50),
			@dept_from			varchar(50),
			@fax_from			varchar(20),
			@phone_from			varchar(20),
			@dept_to			varchar(50),
			@attachment_id		tinyint,
			@attachment_type	varchar(10),
			@attachment_source	varchar(32),
			@special_note_text	varchar(1000),
			@special_note_html	varchar(1000),
			@invoice_date		datetime,
			@one_pdf_per_invoice_flag	char(1),
			@invoice_id			int,
			@invoice_template_count int,
			@invoicetemplate_email_subject_line varchar(60)
	--		@config_value		varchar(15)

	EXEC @message_id = sp_sequence_next 'Message.message_id', 0
	IF ISNULL(@message_id, -1) <= 0
		GOTO ErrorLabel

	SET @message_table_type = @message_type
	SET @status = 'N'
	SET @message_source = 'EQAI'

	Select @invoice_date = Invoice_date, @invoice_id = invoice_id
	From InvoiceHeader
	Where invoice_code = @invoice_code
	AND revision_id = @revision_id

	Select @invoice_template_count = dbo.fn_get_invoice_template ( @invoice_id,  @revision_id ) 

	select @invoicetemplate_email_subject_line = 

	 (  select COALESCE(
		(select t.email_subject_line 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = InvoiceHeader.invoice_id
						   AND h.revision_id = InvoiceHeader.revision_id 
					   )
		)
	     ,
		(select t.email_subject_line
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = InvoiceHeader.invoice_id
						   AND d.revision_id = InvoiceHeader.revision_id 
					   )
		)
	   ) ) 
      FROM InvoiceHeader WHERE InvoiceHeader.invoice_id = @invoice_id
			AND InvoiceHeader.revision_id = @revision_id 

	/*select @invoicetemplate_email_subject_line = InvoiceTemplate.email_subject_line from company
		  JOIN InvoiceTemplate  ON InvoiceTemplate.invoice_template_id = company.invoice_template_id
		  where company.company_id = (SELECT Max(company_id) 
		   FROM InvoiceDetail WHERE InvoiceDetail.invoice_id = @invoice_id
			AND InvoiceDetail.revision_id = @revision_id )*/

	IF @revision_id > 1
		IF @invoice_template_count = 1
			SET @subject = 'Revised ' + @invoicetemplate_email_subject_line + ' ' + @invoice_code
		ELSE 
			SET @subject = 'Revised US Ecology Invoice ' + @invoice_code
	ELSE
	  IF @invoice_template_count = 1 
		SET @subject = @invoicetemplate_email_subject_line + ' ' + @invoice_code
	  ELSE 
		SET @subject = 'New US Ecology Invoice ' + @invoice_code

	--Select @config_value = config_value
	--From Configuration 
	--Where config_key  = 'emanifest_validation_date'

	SET @email_from = 'billing@usecology.com'
	SET @email_bcc = 'billing@usecology.com'
	SET @name_from = 'US Ecology'
	SET @company_from = 'US Ecology'
	SET @dept_from = 'Accounts Receivable'
	SET @fax_from = '7343298011'		--Billing's fax number
	SET @phone_from = '7343298083'		--Currently Trish Bono's phone extension
	SET @dept_to = 'Accounts Payable'
	SET @attachment_type = 'Image'
	SET @attachment_source = 'InvoiceImage'


	SET @message_greeting = 'Dear Valued Customer,'

	--DevOps:58380 - AM - Update email for system generated invoices
	IF @package_content = 'A' AND @revision_id <= 1
	 BEGIN
		  SET @message_close = 'Thank you for your continued business!'
		+ CHAR(10) + CHAR(10)
		+ 'Sincerely,'
		+ CHAR(10) + CHAR(10)
		+ 'Republic Services' 
		--+ 'US Ecology'		
	 END
	ELSE
	 BEGIN
	   SET @message_close = 'Thank you for your continued business!'
		+ CHAR(10) + CHAR(10)
		+ 'Sincerely,'
		+ CHAR(10) + CHAR(10)
		+ 'Republic Services'

		/*+ 'US Ecology'
		+ CHAR(10) + CHAR(10)
		+ 'US Ecology - Unequaled service. Solutions you can trust.'
		+ CHAR(10) + CHAR(10)
		+ 'For more information on US Ecology, please visit our website at www.usecology.com or call (800) 592-5489.'*/
	 END

	 --DevOps:58380 - AM - Update email for system generated invoices
	IF @package_content = 'A' AND @revision_id <= 1
	  BEGIN
		SET @html_greeting = '<p>Dear Valued Customer,</p>'
		SET @html_close = '<p>Thank you for your continued business!</p>'
			+ '<p>Sincerely,</p>'
			+ '<p>Republic Services</p>'
			--+ '<p>US Ecology</p>'
			+ '<p>&nbsp;</p>'
			--+ '<p>US Ecology - Unequaled service. Solutions you can trust.</p>'
			--+ '<p>For more information on US Ecology, please visit our website at <a href="http://www.usecology.com">www.usecology.com</a> or call (800) 592-5489.</p>'
	  END
	 ELSE
	  BEGIN
		SET @html_greeting = '<p>Dear Valued Customer,</p>'
		SET @html_close = '<p>Thank you for your continued business!</p>'
			+ '<p>Sincerely,</p>'
			+ '<p>Republic Services</p>'
			--+ '<p>US Ecology</p>'
			+ '<p>&nbsp;</p>'
			--+ '<p>US Ecology - Unequaled service. Solutions you can trust.</p>'
			--+ '<p>For more information on US Ecology, please visit our website at <a href="http://www.usecology.com">www.usecology.com</a> or call (800) 592-5489.</p>'
	 END

	SET @special_note_text = ''
	SET @special_note_html = ''

	/*
	if getdate() between '05/20/2013' and '07/06/2013 23:59:59'
		BEGIN
			SET @special_note_text = CHAR(10) + CHAR(10) + 'Please note: E Q''s email address has changed for submittal of purchase orders.'+ CHAR(10) + 'Please update it to: CreditPurchaseOrders@usecology.com'
			SET @special_note_html = '</p><p>Please note: EQ''s email address has changed for submittal of purchase orders.<br/>Please update it to: CreditPurchaseOrders@usecology.com'
		END
	*/

	if getdate() between '12/13/2016 00:00:00' and '01/15/2017 23:59:59'
		BEGIN
			SET @special_note_text = CHAR(10) + CHAR(10) + 
									 'Effective January 1, 2017, EQ – The Environmental Quality Company dba US Ecology remittance address and banking information will change.  Please see the important information below.' + CHAR(10) + 
									 CHAR(10) + 
									 'Remittance Address:' + CHAR(10) + 
									 'EQ – The Environmental Quality Company dba US Ecology' + CHAR(10) + 
									 'P O Box 936227' + CHAR(10) + 
									 'Atlanta, GA  31193-6227' + CHAR(10) + 
									 CHAR(10) + 
									 'Wire or ACH remittance:' + CHAR(10) + 
									 'EQ – The Environmental Quality Company dba US Ecology' + CHAR(10) + 
									 'Wells Fargo Bank' + CHAR(10) + 
									 'Routing Number:  121000248' + CHAR(10) + 
									 'Bank Account Number:  4140909680'

			SET @special_note_html = '</p><p><strong><big>Effective January 1, 2017,</big></strong> EQ – The Environmental Quality Company dba US Ecology remittance address and banking information will change.  Please see the important information below.<br/><br/>' +
									 '<strong><big>Remittance Address:</big></strong><br/>' + 
									 'EQ – The Environmental Quality Company dba US Ecology<br/>' +  
									 'P O Box 936227<br/>' +  
									 'Atlanta, GA  31193-6227<br/><br/>' + 
									 '<strong><big>Wire or ACH remittance:</big></strong><br/>' +  
									 'EQ – The Environmental Quality Company dba US Ecology<br/>' + 
									 'Wells Fargo Bank<br/>' + 
									 'Routing Number:  121000248<br/>' + 
									 'Bank Account Number:  4140909680<br/>'
   		END


	-----------------------------------------------------------------------
	-- Set up Message and HTML text
	-----------------------------------------------------------------------

		-- DevOps 12258
		IF @message_type = 'A' AND @package_content = 'C'
		BEGIN
			SET @one_pdf_per_invoice_flag = 'T'
		END
		ELSE
		BEGIN
			SET @one_pdf_per_invoice_flag = 'F'
		END
		-----------------------------------
		-- E = Email Message Only
		-----------------------------------

		IF @message_type = 'E'
		BEGIN
			IF @revision_id > 1
			BEGIN
				--SET @body = 'Pursuant to your request, corrections have been made.  Your revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments are now available at www.usecology.com.  Please log on to COR using your online account to view these documents.'
				--SET @body = 'Pursuant to your request, corrections have been made. Your revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments are now available at https://www.republicservices.com/account/login.'
				SET @body = 'Pursuant to your request, your invoice and attachments are now available at https://www.republicservices.com/account/login.'
			END
			ELSE
			BEGIN
				--SET @body = 'Pursuant to your request, your invoice and attachments are now available at www.usecology.com.  Please log on to COR using your online account to view these documents.'
				SET @body = 'Pursuant to your request, your invoice and attachments are now available at https://www.republicservices.com/account/login.'
			END
		END

		-----------------------------------
		-- F = Fax
		-----------------------------------
		IF @message_type = 'F'
		BEGIN
			IF @revision_id > 1
			BEGIN
				SET @body = 'Pursuant to your request, corrections have been made.  Here is your revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ').  If you wish to view your invoices and attachments on line, please visit www.usecology.com and log on to COR.'
			END
			ELSE
			BEGIN
				SET @body = 'Here is your invoice.  If you wish to view your invoices and attachments on line, please visit www.usecology.com and log on to COR.'
			END
		END

		-----------------------------------
		-- A = Email with Documents
		-----------------------------------
		IF @message_type = 'A'
		BEGIN
			SET @message_table_type = 'E'	-- The Message table only takes E(-mail) or F(ax)

			IF @package_content = 'I'		-- I = Invoice
			BEGIN
				IF @revision_id > 1
	--			BEGIN
	--			 IF  Convert(nvarchar(12), @invoice_date, 101)  > Convert(nvarchar(12), @config_value, 101)
	--			   BEGIN			   
	--			     SET @body = 'Pursuant to your request, corrections have been made.  Please see the attached revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ').  Please visit www.usecology.com and log on to Online Services to obtain the corresponding attachments for this invoice. Effective June 30, 2018: Due to the US EPAs e-Manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	--			   END
	--			  ELSE
	--			    BEGIN
					SET @body = 'Pursuant to your request, corrections have been made.  Please see the attached revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ').  Please visit www.usecology.com and log on to COR to obtain the corresponding attachments for this invoice.'
	--				SET @body = 'Pursuant to your request, corrections have been made. Your revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments are now available at https://www.republicservices.com/account/login.'
    --				END
	--			END
		
				ELSE
	--			  IF  Convert(nvarchar(12), @invoice_date, 101)  > Convert(nvarchar(12), @config_value, 101)
	--				BEGIN			   
	--			     SET @body = 'Pursuant to your request, please see the attached invoice.  Please visit www.usecology.com and log on to Online Services to obtain the corresponding attachments for this invoice. Effective June 30, 2018: Due to the US EPAs e-Manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	--				END
	--			  ELSE
	--			    BEGIN
	--				SET @body = 'Pursuant to your request, the attached invoice has been sent to you via e-mail.  Please visit www.usecology.com and log on to Online Services to obtain the corresponding attachments for this invoice.'
					SET @body = 'Pursuant to your request, please see the attached invoice.  Please visit www.usecology.com and log on to COR to obtain the corresponding attachments for this invoice.'
	--				SET @body = 'Pursuant to your request, your invoice and attachments are now available at https://www.republicservices.com/account/login.'
	--			    END
			END

			IF @package_content = 'A'		-- A = Invoice + Attachments
			BEGIN
				IF @revision_id > 1
	--			BEGIN
	--			  IF  Convert(nvarchar(12), @invoice_date, 101)  > Convert(nvarchar(12), @config_value, 101)
	--			   BEGIN			   
	--			     SET @body = 'Pursuant to your request, corrections have been made.  Please see the attached revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments. Effective June 30, 2018: Due to the US EPAs e-Manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	--			   END
	--			  ELSE
	--			    BEGIN
					SET @body = 'Pursuant to your request, corrections have been made. Please see the attached invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments.'
	--			    END 
	--			END
				ELSE
	--			BEGIN
	--			  IF  Convert(nvarchar(12), @invoice_date, 101)  > Convert(nvarchar(12), @config_value, 101)
	--			   BEGIN			   
	--			     SET @body = 'Pursuant to your request, please see the attached invoice and attachments. Effective June 30, 2018: Due to the US EPAs e-Manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	--			   END
	--			  ELSE
	--			    BEGIN
					--SET @body = 'Pursuant to your request, the attached invoice and attachments have been sent to you via e-mail.'
					-- DevOps:58380 - AM - Update email for system generated invoices
					-- SET @body = 'Pursuant to your request, please see the attached invoice and attachments.<br/>For questions please contact your Customer Service Representative or email customer.service@usecology.com<br/><br/>For statements or payment information please contact accounts.receivable@usecology.com<br/>For more information on US Ecology, please visit our website at www.usecology.com or call (800) 592-5489.'
					SET @body = 'Pursuant to your request, please see the attached invoice and attachments.'				
					--END
	--			END	
			END

			IF @package_content = 'C'		-- A = Invoice + Attachments cobmined as 1 PDF
			BEGIN
				IF @revision_id > 1
	--			BEGIN
	--			  IF  Convert(nvarchar(12), @invoice_date, 101)  > Convert(nvarchar(12), @config_value, 101)
	--			   BEGIN			   
	--			     SET @body = 'Pursuant to your request, corrections have been made.  Please see the attached revised invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments. Effective June 30, 2018: Due to the US EPAs e-Manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	--			   END
	--			  ELSE
	--			    BEGIN
					SET @body = 'Pursuant to your request, corrections have been made. Please see the attached invoice (invoice ' + @invoice_code + ' R' + right('00' + cast(@revision_id as varchar(2)), 2) + ') and attachments.'
	--			    END 
	--			END
				ELSE
	--			BEGIN
	--			  IF  Convert(nvarchar(12), @invoice_date, 101)  > Convert(nvarchar(12), @config_value, 101)
	--			   BEGIN			   
	--			     SET @body = 'Pursuant to your request, please see the attached invoice and attachments. Effective June 30, 2018: Due to the US EPAs e-Manifest regulations, a fee will be assessed to all customers for shipments utilizing a hazardous waste manifest.'
	--			   END
	--			  ELSE
	--			    BEGIN
					--SET @body = 'Pursuant to your request, the attached invoice and attachments have been sent to you via e-mail.'
					 SET @body = 'Pursuant to your request, please see the attached invoice and attachments.'
	--				END
	--			END					
			END
		END

	SET @body_extn = ''
	SET @html_body_extn = ''

	IF @message_type IN ('E','A') AND @package_content IN ('A', 'C')
	BEGIN
		SET @body_extn =  'Please do not reply to this message (This is an automated email used for invoice distribution only).'
						+ CHAR(10) + CHAR(10) + 'If you have any questions, please see list of contacts below:'
						+ CHAR(10) + CHAR(10) + 'For general questions, please contact your Customer Service Representative or email: EScustomerservice@republicservices.com'
						+ CHAR(10) + CHAR(10) + 'For billing statements or AR balance questions, please contact: ESAccountsReceivable@republicservices.com'
						+ CHAR(10) + CHAR(10) + 'For W9/New customer setup/ACH payments, please contact: escreditapp@republicservices.com'
						+ CHAR(10) + CHAR(10) + 'For credit card payments, please contact: ccpayments@republicservices.com'
						+ CHAR(10) + CHAR(10) + 'For Purchase Order (PO) related questions, please contact: creditpurchaseorders@republicservices.com'
						+ CHAR(10) + CHAR(10) + 'For Certificate of Insurance (COI) questions, please contact: EScustomerservice@republicservices.com'
						+ CHAR(10) + CHAR(10) + 'For more information on Republic Services, please visit our website at www.republicservices.com/ES or call 800.592.5489'

		SET @html_body_extn = '</p><p><span style="color:red;"><font size="+2">Please do not reply to this message</font></span> (This is an automated email used for invoice distribution only).<br/>'
						+ '<u>If you have any questions, please see list of contacts below:</u><BR/>'
						+ '<ul><li>For general questions, please contact your Customer Service Representative or email: EScustomerservice@republicservices.com</li>'
						+ '<li>For billing statements or AR balance questions, please contact: ESAccountsReceivable@republicservices.com</li>'
						+ '<li>For W9/New customer setup/ACH payments, please contact: escreditapp@republicservices.com</li>'
						+ '<li>For credit card payments, please contact: ccpayments@republicservices.com</li>'
						+ '<li>For Purchase Order (PO) related questions, please contact: creditpurchaseorders@republicservices.com</li>'
						+ '<li>For Certificate of Insurance (COI) questions, please contact: EScustomerservice@republicservices.com</li></ul>'
						+ 'For more information on Republic Services, please visit our website at www.republicservices.com/ES or call 800.592.5489<br/>'

		SET @html_body_extn = REPLACE(@html_body_extn, 'https://www.republicservices.com/account/login', '<a href="https://www.republicservices.com/account/login">https://www.republicservices.com/account/login</a>')
		SET @html_body_extn = REPLACE(@html_body_extn, 'www.republicservices.com/ES', '<a href="https://www.republicservices.com/ES">www.republicservices.com/ES</a>')
	END

	-----------------------------------------------------------------------
	-- Build the Message Content
	-----------------------------------------------------------------------
	SET @message = @message_greeting
		+ CHAR(10) + CHAR(10)
		+ @body	
		+ CHAR(10) + CHAR(10) 
		+ @body_extn
		+ @special_note_text
		+ CHAR(10) + CHAR(10)
		+ @message_close

	SET @html = @html_greeting
		+ '<p>'
		+ REPLACE(@body, 'www.usecology.com', '<a href="http://www.usecology.com">www.usecology.com</a>')
		+ @html_body_extn
		+ @special_note_html
		+ '</p>'
		+ @html_close

	-----------------------------------------------------------------------
	-- Insert into Message table
	-----------------------------------------------------------------------
	INSERT Message (
		message_id,
		status,
		message_type,
		message_source,
		subject,
		message,
		HTML,
		added_by,
		date_added,
		modified_by,
		date_modified,
		date_to_send,
		error_description
		)
	VALUES (
		@message_id,
		@status,
		@message_table_type,
		@message_source,
		@subject,
		@message,
		@html,
		@user_code,
		GETDATE(),
		@user_code,
		GETDATE(),
		@date_to_send,
		NULL
		)




	-----------------------------------------------------------------------
	-- Insert into MessageAttachment table
	-----------------------------------------------------------------------
	IF @message_type = 'A' OR @message_type = 'F'
	BEGIN
		--------------------------------------
		-- Insert Invoice
		--------------------------------------
		SET @attachment_id = 1

		INSERT MessageAttachment (
			message_id,
			attachment_id,
			status,
			attachment_type,
			source,
			image_id,
			filename,
			one_pdf_per_invoice_flag
			)
		VALUES (
			@message_id,
			@attachment_id,
			@status,
			@attachment_type,						-- Image or File
			@attachment_source,						-- ScanImage or InvoiceImage
			@image_id_invoice,
			'Invoice_' + @invoice_code + '.PDF',
			@one_pdf_per_invoice_flag
			)

	
		IF @package_content = 'A' OR @package_content = 'C'
		BEGIN
			------------------------------------------------
			-- Check to see if the invoice has attachments
			------------------------------------------------
			IF ISNULL(@image_id_attach, -1) > 0
			BEGIN
				------------------------------------
				-- Insert Invoice Attachments
				------------------------------------
				SET @attachment_id = @attachment_id + 1

				INSERT MessageAttachment (
					message_id,
					attachment_id,
					status,
					attachment_type,
					source,
					image_id,
					filename,
					one_pdf_per_invoice_flag
					)
				VALUES (
					@message_id,
					@attachment_id,
					@status,
					@attachment_type,						-- Image or File
					@attachment_source,						-- ScanImage or InvoiceImage
					@image_id_attach,
					'Invoice_' + @invoice_code + '_Attachments.PDF',
					@one_pdf_per_invoice_flag
					)

			END		--IF ISNULL(@image_id_attach, -1) > 0

		END		--IF @package_content = 'A'

	END		--IF @message_type = 'A' OR @message_type = 'F'

	--DevOps 65577
	IF IsNull(@credit_memo_image_id,0) > 0
	BEGIN
		SET @attachment_id = IsNull(@attachment_id,0) + 1

		INSERT MessageAttachment (
			message_id,
			attachment_id,
			status,
			attachment_type,
			source,
			image_id,
			filename,
			one_pdf_per_invoice_flag
			)
		VALUES (
			@message_id,
			@attachment_id,
			@status,
			'Image',
			'ScanImage',
			@credit_memo_image_id,
			'Credit_Memo_' + @invoice_code + '.PDF',
			@one_pdf_per_invoice_flag
			)
	END


	-----------------------------------------------------------------------
	-- Insert into MessageAddress table (FROM record)
	-----------------------------------------------------------------------
	INSERT MessageAddress (
		message_id,
		address_type,
		name,
		company,
		department,
		email,
		fax,
		phone
		)
	VALUES (
		@message_id,
		'FROM',
		@name_from,
		@company_from,
		@dept_from,
		@email_from,
		@fax_from,
		@phone_from
		)


	-----------------------------------------------------------------------
	-- Insert into MessageAddress table (BCC to EQ)
	-----------------------------------------------------------------------
	INSERT MessageAddress (
		message_id,
		address_type,
		name,
		company,
		department,
		email,
		fax,
		phone
		)
	VALUES (
		@message_id,
		'BCC',
		@name_from,
		@company_from,
		@dept_from,
		@email_bcc,
		@fax_from,
		@phone_from
		)


	-------------------------------------------------------------------------
	-- Insert into MessageAddress table (TO record)
	-------------------------------------------------------------------------
	INSERT MessageAddress (
		message_id,
		address_type,
		name,
		company,
		department,
		email,
		fax,
		phone
		)
	VALUES (
		@message_id,
		'TO',
		@name_to,
		@company_to,
		@dept_to,
		@email_to,
		@fax_to,
		@phone_to
		)


	DECLARE 
		@onoff_announcement varchar(20)
		, @image_id_announcement int
		, @end_date_announcement datetime
		, @announcement_filename varchar(50)

	-------------------------------------------------------------------------
	-- Insert EQ/USEcology Announcement to MessageAttachment
		-- Commented out on 11/26/14 JDB
	-------------------------------------------------------------------------
		--SET @announcement_filename = 'EQ Acquired by US Ecology.pdf'
	
		---- Get on/off flag.
		--select @onoff_announcement = setting_value 
		--	from ApplicationConfiguration 
		--	where setting_name = 'invoice_announcement_20140624_onoff'

		---- Abort if this is turned off.
		--if isnull(@onoff_announcement, '') not in ('on', '1', 'T') 
		--	GOTO EndofAnnouncement

		---- Get the end date.
		--select @end_date_announcement = convert(datetime, setting_value)
		--	from ApplicationConfiguration
		--	where setting_name = 'invoice_announcement_20140624_enddate'
	
		---- Abort if we're past this date.
		--if getdate() > @end_date_announcement + 0.99999 
		--	GOTO EndofAnnouncement
	
		---- Get image id for attachment
		--select @image_id_announcement = convert(int, setting_value)
		--	from ApplicationConfiguration 
		--	where setting_name = 'invoice_announcement_20140624_image'
	
	
	-----------------------------------------------------------------------------------------------
	-- Insert EQ Michigan Office Relocation and Updated W-9 Announcement to MessageAttachment
		-- Added on 11/26/14 JDB
	-----------------------------------------------------------------------------------------------
		--SET @announcement_filename = 'EQ Office Relocation and Updated W-9.pdf'
	
		---- Get on/off flag.
		--SELECT @onoff_announcement = setting_value 
		--	FROM ApplicationConfiguration 
		--	WHERE setting_name = 'invoice_announcement_20141120_onoff'

		---- Abort if this is turned off.
		--IF ISNULL(@onoff_announcement, '') NOT IN ('on', '1', 'T') 
		--BEGIN
		--	--PRINT 'Announcement is turned off'
		--	GOTO EndofAnnouncement
		--END

		---- Get the end date.
		--SELECT @end_date_announcement = CONVERT(datetime, setting_value)
		--	FROM ApplicationConfiguration
		--	WHERE setting_name = 'invoice_announcement_20141120_enddate'
	
		---- Abort if we're past this date.
		--IF GETDATE() > @end_date_announcement + 0.99999 
		--BEGIN
		--	--PRINT 'Announcement is expired'
		--	GOTO EndofAnnouncement
		--END
	
		---- Get image id for attachment
		--SELECT @image_id_announcement = CONVERT(int, setting_value)
		--	FROM ApplicationConfiguration 
		--	WHERE setting_name = 'invoice_announcement_20141120_image'
	
	
	-----------------------------------------------------------------------------------------------
	-- Insert US Ecology New Brand document to MessageAttachment
		-- Added on 1/15/2015 JDB
	-----------------------------------------------------------------------------------------------
		SET @announcement_filename = 'EQ-US Ecology Rebrand.pdf'
	
		-- Get on/off flag.
		SELECT @onoff_announcement = setting_value 
			FROM ApplicationConfiguration 
			WHERE setting_name = 'invoice_announcement_20150115_onoff'

		-- Abort if this is turned off.
		IF ISNULL(@onoff_announcement, '') NOT IN ('on', '1', 'T') 
		BEGIN
			--PRINT 'Announcement is turned off'
			GOTO EndofAnnouncement
		END

		-- Get the end date.
		SELECT @end_date_announcement = CONVERT(datetime, setting_value)
			FROM ApplicationConfiguration
			WHERE setting_name = 'invoice_announcement_20150115_enddate'
	
		-- Abort if we're past this date.
		IF GETDATE() > @end_date_announcement + 0.99999 
		BEGIN
			--PRINT 'Announcement is expired'
			GOTO EndofAnnouncement
		END
	
		-- Get image id for attachment
		SELECT @image_id_announcement = CONVERT(int, setting_value)
			FROM ApplicationConfiguration 
			WHERE setting_name = 'invoice_announcement_20150115_image'
		
		
		
	-----------------------------------------------------------------------------------------------
		-- Abort if the image is not available
		if isnull(@image_id_announcement, -1) not in (select image_id from plt_image..scan where image_id = @image_id_announcement and status = 'A')
		BEGIN
			--PRINT 'Announcement image is not available'
			GOTO EndofAnnouncement
		END
		
		-- Abort if the recipient of this message has already gotten this announcement
		IF @message_type IN ('E', 'A')
		BEGIN
			IF EXISTS (
				SELECT 1
					FROM Message m1
					INNER JOIN messageaddress m2 ON m1.message_id = m2.message_id
					INNER JOIN messageattachment m3 ON m1.message_id = m3.message_id
					WHERE m1.message_type = 'E'
					AND m1.status <> 'V'
					AND m3.image_id = @image_id_announcement
					AND m2.email = @email_to
			) 
			BEGIN
				--PRINT 'Announcement was already e-mailed to this user'
				GOTO EndOfAnnouncement
			END
		END
	
		IF @message_type IN ('F')
		BEGIN
			IF EXISTS (
				SELECT 1
					FROM Message m1
					INNER JOIN messageaddress m2 ON m1.message_id = m2.message_id
					INNER JOIN messageattachment m3 ON m1.message_id = m3.message_id
					WHERE m1.message_type = 'F'
					AND m1.status <> 'V'
					AND m3.image_id = @image_id_announcement
					AND m2.fax = @fax_to
			)
			BEGIN
				--PRINT 'Announcement was already faxed to this user'
				GOTO EndOfAnnouncement
			END
		END
			
	
		-- Insert Announcement Attachment:

		SET @attachment_id = @attachment_id + 1

		INSERT messageattachment (message_id, attachment_id, status, attachment_type, source, image_id, filename, one_pdf_per_invoice_flag)
		VALUES (@message_id, @attachment_id, 'N', 'Image', 'ScanImage', @image_id_announcement, @announcement_filename,	@one_pdf_per_invoice_flag)


	EndofAnnouncement:	


	ErrorLabel:
END

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_message] TO PUBLIC;
GO
