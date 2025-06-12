/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

CREATE PROCEDURE sp_Gemini_ToDo (
	@debug	int = 0
) AS
/-***************************************************************
Loads to:	EQ_IT

Sends an email to IT about Gemini issues ready for handling.

02/03/2010 JPB	Created

sp_Gemini_ToDo 1
select * from Message where message_id = 26017
select * from MessageAddress where message_id = 26017
****************************************************************-/
SET NOCOUNT ON

DECLARE 
	@email				varchar(100),
	@deploy_detail		varchar(8000),
	@test_detail		varchar(8000),
	@pos				int,
	@email_text			varchar(8000),
	@email_html			varchar(8000),
	@crlf				varchar(4),
	@crlf2				varchar(8),
	@message_id			int,
	@Tptrval			binary(16),
	@Deployptrval			binary(16),
	@Testptrval			binary(16),
	@TptrvalText		binary(16),
	@DeployptrvalText		binary(16),
	@TestptrvalText		binary(16),
	@thisDate			datetime,
	@issuecode			varchar(200),
	@statusdesc			varchar(200),
	@summary			varchar(255),
	@issue_code			varchar(20),
	@projectid			int,
	@issueid			int,
	@firstname			varchar(60),
	@lastname			varchar(60)

set @email = 'itdept@eqonline.com'
-- testing: set @email = 'jonathan.broome@eqonline.com'
set @crlf = char(13) + char(10)
set @crlf2 = @crlf + @crlf
Set @email_html = '<html><body><table border="0" cellspacing="0" cellpadding="0" style="width:716px;font-size:14px">
<tr><td style="padding:1em"><p><a href="http://support.eqonline.com/">Gemini</a> Status Update:</p>
<p>Status: Ready to Deploy</p>{DEPLOY_DETAIL}
<p>Status: Needs Testing</p>{TEST_DETAIL}
</td></tr></table></body></html>'

Set @email_text = 'Gemini Status Update:' + @crlf2 + 'Status: Ready to Deploy' + @crlf2 + '{DEPLOY_DETAIL}' + @crlf2 + 'Status: Needs Testing' + @crlf2 + '{TEST_DETAIL}' + @crlf2

Set @deploy_detail = '<table border="0" cellspacing="0" cellpadding="6" style="width:100%;border: solid 1px #000">' +
	'<tr><td>' +
	'<table cellspacing="0" cellpadding="3" style="width:100%;font-size:14px">' +
	'<thead><tr>' +
	'<th style="border-bottom:solid 1px #1D9A1A;text-align:left;">Issue</th>' + 
	'<th style="border-bottom:solid 1px #1D9A1A;text-align:left;">Summary</th>' + 
	'<th style="border-bottom:solid 1px #1D9A1A;text-align:left;">Assigned To</th>' + 
	'</tr></thead>'
set @test_detail = @deploy_detail

create table #html (t_desc varchar(40), t_field text)
create table #text (t_desc varchar(40), t_field text)
insert #html (t_desc, t_field) values ('template', @email_html)
insert #html (t_desc, t_field) values ('deploy_detail', @deploy_detail)
insert #html (t_desc, t_field) values ('test_detail', @test_detail)

insert #text (t_desc, t_field) values ('template', @email_text)
insert #text (t_desc, t_field) values ('deploy_detail', '')
insert #text (t_desc, t_field) values ('test_detail', '')
	
SELECT @Tptrval = TEXTPTR(t_field) FROM #html where t_desc = 'template'
SELECT @Deployptrval = TEXTPTR(t_field) FROM #html where t_desc = 'deploy_detail'
SELECT @Testptrval = TEXTPTR(t_field) FROM #html where t_desc = 'test_detail'
SELECT @TptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'template'
SELECT @DeployptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'deploy_detail'
SELECT @TestptrvalText = TEXTPTR(t_field) FROM #text where t_desc = 'test_detail'

DECLARE @ptr_location_token_html binary(16)
DECLARE @ptr_location_token_text binary(16)

DECLARE @tbl_order_info table (
	projectid int,
	issueid int,
	issue_code varchar(20),
	statusdesc varchar(200),
	summary varchar(255),
	firstname varchar(60),
	lastname varchar(60)
)

INSERT INTO @tbl_order_info
	SELECT i.projectid, i.issueid, p.projectcode + ':' + convert(varchar(20), i.issueid) as issue_code, s.statusdesc, summary, u.firstname, u.surname
	FROM NTSQLFinance.gemini.dbo.gemini_issues i 
	INNER JOIN NTSQLFinance.gemini.dbo.gemini_issuestatus s
		ON i.issuestatusid = s.statusid and s.statusdesc LIKE '%ready%'
	INNER JOIN NTSQLFinance.gemini.dbo.gemini_projects p
		ON i.projectid = p.projectid
	LEFT OUTER JOIN NTSQLFinance.gemini.dbo.gemini_issueresources ir
		ON i.issueid = ir.issueid
	LEFT OUTER JOIN NTSQLFinance.gemini.dbo.gemini_users u
		ON ir.userid = u.userid

	UNION all

	SELECT i.projectid, i.issueid, p.projectcode + ':' + convert(varchar(20), i.issueid) as issue_code, s.statusdesc, summary, u.firstname, u.surname
	FROM NTSQLFinance.gemini.dbo.gemini_issues i 
	INNER JOIN NTSQLFinance.gemini.dbo.gemini_issuestatus s
		ON i.issuestatusid = s.statusid and s.statusdesc LIKE '%needs%'
	INNER JOIN NTSQLFinance.gemini.dbo.gemini_projects p
		ON i.projectid = p.projectid
	LEFT OUTER JOIN NTSQLFinance.gemini.dbo.gemini_issueresources ir
		ON i.issueid = ir.issueid
	LEFT OUTER JOIN NTSQLFinance.gemini.dbo.gemini_users u
		ON ir.userid = u.userid
	
-- declare cursor 
DECLARE ord CURSOR FOR 
   SELECT 	
		projectid,
		issueid,
		issue_code,
		statusdesc,
		summary,
		firstname,
		lastname
	FROM @tbl_order_info
	WHERE statusdesc like '%ready%'
	ORDER BY statusdesc, issue_code

OPEN ord

FETCH ord INTO @projectid, @issueid, @issue_code, @statusdesc, @summary, @firstname, @lastname

WHILE @@FETCH_STATUS = 0
BEGIN

	Set @deploy_detail = '<tr>' +
		'<td align="left" width="20%"><a href="http://support.eqonline.com/Default.aspx?p=' + convert(varchar(10), @projectid) + '&i=' + convert(varchar(20), @issueid) + '">' +
		@issue_code + '</a></td>' +
		'<td>' + isnull(@summary, 'no description') + '</td>' +
		'<td width="20%">' + isnull(@firstname, '') + ' ' + isnull(@lastname, '') + '</td>' +
		'</tr>'
		
	UPDATETEXT #html.t_field @Deployptrval NULL 0 @deploy_detail

	Set @deploy_detail = @issue_code + ' : ' + isnull(@summary, 'no description') + ' (' + isnull(@firstname, '') + ' ' + isnull(@lastname, '') + ')' + @crlf

	UPDATETEXT #text.t_field @Deployptrvaltext NULL 0 @deploy_detail
		
	FETCH ord INTO @projectid, @issueid, @issue_code, @statusdesc, @summary, @firstname, @lastname
END

CLOSE ord
DEALLOCATE ord

set @deploy_detail = '</table></td></tr></table>'
UPDATETEXT #html.t_field @Deployptrval NULL 0 @deploy_detail


-- declare cursor 
DECLARE ord CURSOR FOR 
   SELECT
		projectid,
		issueid,
		issue_code,
		statusdesc,
		summary,
		firstname,
		lastname
	FROM @tbl_order_info
	WHERE statusdesc like '%needs%'
	ORDER BY statusdesc, issue_code

OPEN ord

FETCH ord INTO @projectid, @issueid, @issue_code, @statusdesc, @summary, @firstname, @lastname

WHILE @@FETCH_STATUS = 0
BEGIN

	Set @test_detail = '<tr>' +
		'<td align="left" width="20%"><a href="http://support.eqonline.com/Default.aspx?p=' + convert(varchar(10), @projectid) + '&i=' + convert(varchar(20), @issueid) + '">' +
		@issue_code + '</a></td>' +
		'<td>' + isnull(@summary, 'no description') + '</td>' +
		'<td width="20%">' + isnull(@firstname, '') + ' ' + isnull(@lastname, '') + '</td>' +
		'</tr>'
		
	UPDATETEXT #html.t_field @Testptrval NULL 0 @test_detail

	Set @test_detail = @issue_code + ' : ' + isnull(@summary, 'no description') + ' (' + isnull(@firstname, '') + ' ' + isnull(@lastname, '') + ')' + @crlf

	UPDATETEXT #text.t_field @Testptrvaltext NULL 0 @test_detail
		
	FETCH ord INTO @projectid, @issueid, @issue_code, @statusdesc, @summary, @firstname, @lastname
END

CLOSE ord
DEALLOCATE ord

set @test_detail = '</table></td></tr></table>'
UPDATETEXT #html.t_field @Testptrval NULL 0 @test_detail


----  Replace the text in the e-mail

-- Replace {DEPLOY_DETAIL} with the order detail info:
select @pos = PATINDEX('%{DEPLOY_DETAIL}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 15 #html.t_field @Deployptrval
	select @pos = PATINDEX('%{DEPLOY_DETAIL}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{DEPLOY_DETAIL}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @TptrvalText @pos 15 #text.t_field @Deployptrvaltext
	select @pos = PATINDEX('%{DEPLOY_DETAIL}%', t_field) -1 from #text where t_desc = 'template'
END

-- Replace {TEST_DETAIL} with the order detail info:
select @pos = PATINDEX('%{TEST_DETAIL}%', t_field) -1 from #html where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #html.t_field @Tptrval @pos 13 #html.t_field @Testptrval
	select @pos = PATINDEX('%{TEST_DETAIL}%', t_field) -1 from #html where t_desc = 'template'
END
select @pos = PATINDEX('%{TEST_DETAIL}%', t_field) -1 from #text where t_desc = 'template'
WHILE @pos > 0 BEGIN
	UPDATETEXT #text.t_field @TptrvalText @pos 13 #text.t_field @Testptrvaltext
	select @pos = PATINDEX('%{TEST_DETAIL}%', t_field) -1 from #text where t_desc = 'template'
END


if @debug > 0
begin
-- testing only
select 'FROM' = 'donotreply@eqonline.com', 
		'TO' = @email,
		@message_id as MessageID, -- message id
		'N', 
		'E',
		'Gemini', 
		'Gemini Issue Status' as Subject,  -- subject, 
		t.t_field, 
		h.t_field, 
		'EQWEB',
		GetDate()
	from #html h inner join #text t on 1=1 where t.t_desc = h.t_desc and h.t_desc = 'template'	
end

if @debug = 0
begin
--- Prepare the insert into the message table

	EXEC @message_id = sp_sequence_next 'message.message_id'

	INSERT INTO Message (message_id, status, message_type, message_source, subject, message, html, added_by, date_added) 
		select 
			@message_id, 
			'N', 
			'E',
			'Gemini', 
			'Gemini Issue Status', 
			t.t_field, 
			h.t_field, 
			'EQWEB',
			GetDate()
		from #html h 
		inner join #text t on 1=1 
		where t.t_desc = h.t_desc and h.t_desc = 'template'	

	INSERT INTO MessageAddress(message_id, address_type, email) Values
				   (@message_id, 'TO', @email)

	INSERT INTO MessageAddress(message_id, address_type, name, company, email) Values
				   (@message_id, 'FROM', 'EQ Online', 'EQ', 'donotreply@eqonline.com')

end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Gemini_ToDo] TO PUBLIC
    AS [dbo];

*/
