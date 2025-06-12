/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

CREATE PROCEDURE eqsp_aging_oacm_40143617_NTSQL1 
AS
/-***************************************************************
eqsp_aging_oacm_40143617_NTSQL1 
Loads to:	e22

Creates an email summarizing the transactions applied to invoice 40143617 in company 22.

09/12/2011 JDB	Created

eqsp_aging_oacm_40143617_NTSQL1
****************************************************************-/
DECLARE 
	@start_date			datetime,
	@end_date			datetime,
	@order_detail		varchar(8000),
	@pos				int,
	@email_text			varchar(8000),
	@email_html			varchar(8000),
	@header_text     varchar(8000),
	@header_html     varchar(8000),
	@crlf				varchar(4),
	@crlf2				varchar(8),
	@message_id			int,
	@cnt				int,
	@username			varchar(100),
	@transactions		int,
	@balance			money
	

SET @email_text	= ''
SET @email_html	= ''
SET @header_text = ''
SET @header_html = ''

SET @crlf = CHAR(13) + CHAR(10)
SET @crlf2 = @crlf + @crlf
SET @email_html = '<html><body style="font-family:verdana,sans-serif;font-size:14px"><p>Summary of transactions and balance applied to invoice in e22.</p>
<table border="1" cellspacing="0" cellpadding="2" style="font-size:14px">
<tr>
	<th>Invoice</th>
	<th>Transactions</th>
	<th>Balance</th>
</tr>
{header}
</table>
<p>&nbsp;</p>

<p>This is an automated email, run at {current_date}.</p>
</body></html>'
SET @email_text = 'Summary of transactions and balance applied to invoice in e22.' + @crlf



SELECT @balance = SUM(amount) FROM NTSQLFINANCE.e22.dbo.artrxage WHERE apply_to_num LIKE '40143617%'
SELECT @transactions = COUNT(*) FROM NTSQLFINANCE.e22.dbo.artrxage WHERE apply_to_num LIKE '40143617%'

SELECT @transactions AS transactions_applied,
	@balance AS balance
INTO #tmp


-------------------------------------------
-- The header info:
-------------------------------------------
DECLARE ord CURSOR FOR 
	SELECT transactions_applied, balance
	FROM #tmp
OPEN ord

FETCH ord INTO @transactions, @balance

SET @cnt = 0
WHILE @@FETCH_STATUS = 0
BEGIN
	SET @cnt = @cnt + 1

	SET @order_detail = '<tr>' +
		'<td>40143617</td>' +
		'<td>' + CAST( @transactions AS varChar(10)) + '</td>' +
		'<td>' + CAST( @balance AS varChar(10)) + '</td>'
		
	SET @header_html = @header_html + @order_detail

	SET @order_detail = @username + @crlf +
		'Invoice: 40143617' + @crlf +
		'Transactions: ' + CAST( @transactions AS varChar(10)) + @crlf +
		'Balance: ' + CAST( @balance AS varChar(10)) + @crlf2

	SET @header_text = @header_text + @order_detail
	
	FETCH ord INTO @transactions, @balance
END

CLOSE ord
DEALLOCATE ord




-- select 'before replaces' as _status, @email_html as _html, @email_text as _text

-- Replace {header} with the header info:
set @email_html = replace(@email_html, '{header}', isnull(@header_html, ''))
set @email_text = replace(@email_text, '{header}', isnull(@header_text, ''))

-- select 'replaced header' as _status, @email_html as _html, @email_text as _text


-- Replace {current_date} with getdate():
set @email_html = replace(@email_html, '{current_date}', CONVERT(varchar(20), GETDATE()))
set @email_text = replace(@email_text, '{current_date}', CONVERT(varchar(20), GETDATE()))

-- select 'replaced current_date' as _status, @email_html as _html, @email_text as _text



----- Prepare the insert into the message table

EXEC @message_id = sp_sequence_next 'message.message_id'

INSERT INTO Message (
		message_id,
		status,
		message_type,
		message_source,
		subject,
		message,
		html,
		added_by,
		date_added) 
	SELECT @message_id, 
		'N', 
		'E',
		'SchedTask', 
		'WM Invoice 40143617 Report', 
		@email_text, 
		@email_html, 
		'EQWEB',
		GETDATE()

--INSERT INTO MessageAddress(message_id, address_type, email) VALUES
--			   (@message_id, 'TO', 'webmaster@eqonline.com')

INSERT INTO MessageAddress(message_id, address_type, email) VALUES
			   (@message_id, 'TO', 'jason.boyette@eqonline.com')

INSERT INTO MessageAddress(message_id, address_type, email) VALUES
			   (@message_id, 'TO', 'lorraine.tooman@eqonline.com')

INSERT INTO MessageAddress(message_id, address_type, name, company, email) VALUES
			   (@message_id, 'FROM', 'EQ Online', 'EQ', 'itdept@eqonline.com')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[eqsp_aging_oacm_40143617_NTSQL1] TO PUBLIC
    AS [dbo];

*/
