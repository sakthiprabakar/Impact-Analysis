create procedure [dbo].[sp_eqai_login]
	@user_id			varchar(15),
	@password			varchar(30),
	@connect_type		varchar(10),
	@eqai_server		varchar(100),
	@finance_server		varchar(30)
as
/***************************************************************************************
 this procedure replaces many round-trip calls in PB with a single stored procedure call

 loads to Plt_ai
 
 12/15/2010 - rb created
 06/16/2011 - rb increased variable lengths for @user_name and @user_email (emails were being truncated)
 08/10/2018 - rb GEM:52907 - login fails if a password is too long (most likely > 18 characters)
 01/15/2019 RWB	GEM-57612 Add ability to connect to new MSS 2016 servers (dbo.fn_encode() moved from master to to Plt_ai)
 02/25/2020 AM modified @eqai_server varchar(30 ) to @eqai_server varchar(100).
 06/03/2020 MPM  DevOps 16147 - Increased "printer" variables to varchar(200).
 04/28/2025	Sailaja	Rally # DE38864 - Default Printer - Printing to incorrect printer
****************************************************************************************/

declare @user_2_id					varchar(15),
		@user_2_password			varchar(100), -- rb GEM:52907 used to be varchar(60)
		@avail_eqai_prod			varchar(3),
		@avail_eqai_test			varchar(3),
		@avail_eqai_dev				varchar(3),
		@avail_finance_prod			varchar(3),
		@avail_finance_test			varchar(3),
		@avail_finance_dev			varchar(3),
		@image_server_name			varchar(100),
		@image_write_path			varchar(255),
		@image_write_path_citrix	varchar(255),
		@image_transfer_path		varchar(255),
		@image_transfer_path_citrix	varchar(255),
		@image_scan_path			varchar(255),
		@image_scan_path_citrix		varchar(255),
		@database_eqai				varchar(30),
		@database_finance			varchar(30),
		@printer_container_label varchar(200),
		@printer_lab_label varchar(200),
		@printer_manifest varchar(200),
		@printer_continuation varchar(200),
		@printer_wo varchar(200),
		@printer_wo_label varchar(200),
		@printer_container_label_mini varchar(200),
		@printer_haz_label varchar(200),
		@printer_nonhaz_label varchar(200),
		@printer_fax varchar(200),
		@printer_pdf varchar(200),
		@change_password char(1),
		@default_company_id int,
		@group_id int,
		@printer_nonrcra_label varchar(200),
		@printer_universal_label varchar(200),
		@user_name					varchar(60),  -- rb 06/16/2011
		@user_email					varchar(80), -- rb 06/16/2011
		@user_first_name			varchar(30),
		@user_last_name				varchar(30),
		@count						int,
		@printer_default	varchar(200)

--		
-- from connection to PROD
--
-- if first connection, not connecting as (2) user
if right(@user_id,3) <> '(2)'
begin
	-- populate variables to return
	select @user_2_id = @user_id + '(2)',
			@user_2_password = dbo.fn_encode (@password)

	-- retrieve server availabilities
	-- EQAI Servers
	select @avail_eqai_prod = server_avail
	from EQServer
	where server_type = 'EQAIProd'
			
	select @avail_eqai_test = server_avail
	from EQServer
	where server_type = 'EQAITest'
			
	select @avail_eqai_dev = server_avail
	from EQServer
	where server_type = 'EQAIDev'

	-- Finance Servers
	select @avail_finance_prod = server_avail
	from EQServer
	where server_type = 'EpicorProd'

	select @avail_finance_test = server_avail
	from EQServer
	where server_type = 'EpicorTest'

	select @avail_finance_dev = server_avail
	from EQServer
	where server_type = 'EpicorDev'

	/* rb 11.28/2018 MSS 2016 - If we want to update the table, we need to grow the column
	select @image_server_name = server_name
	from EQDatabase
	where database_name = 'PLT_IMAGE'
	and db_type = @connect_type
	*/
	select @image_server_name = @eqai_server
end
--
-- end of code from connection to PROD
--

--
-- this is from wf_connect
--
else
begin
	select @user_2_id = @user_id,
		@user_2_password = @password

	select @user_id = left(@user_id,datalength(@user_id) - 3)

	-- get image/scan paths for local/citrix connections		
	select @image_write_path = image_write_path,
			@image_write_path_citrix = image_write_path_citrix,
			@image_transfer_path = image_transfer_exe_path,
			@image_transfer_path_citrix = image_transfer_exe_path_citrix,
			@image_scan_path = image_scan_path,
			@image_scan_path_citrix = image_scan_path_citrix
	from Plt_Image..EQAIImage
end
	/* rb 11.28/2018 MSS 2016 - If we want to update the table, we need to grow the column
	select @image_server_name = server_name
	from EQDatabase
	where database_name = 'PLT_IMAGE'
	and db_type = @connect_type
	*/
	select @image_server_name = @eqai_server

	select @database_eqai = MIN(database_name)
	from EQDatabase
	where server_name = @eqai_server
	and db_type = @connect_type
	and database_name like 'PLT%'

	select @database_finance = MIN(database_name)
	from EQDatabase
	where server_name = @finance_server
	and db_type = @connect_type

	-- EQFax
	if isnull(lower(@password),'') <> 'password'
	begin
		select @count = COUNT(*)
		from EQFax
		where user_code = @user_id
		and password = @password

		if @count = 0
		begin
/*** rb temp while testing in production
			update EQFax
			set status = 'C'
			where user_code = @user_id
***/
			select @user_name = isnull(user_name,'')
			from EQFAX
			where user_code = @user_id

			if @user_name = ''
			begin
				select @user_name = isnull(user_name,'')
				from users
				where user_code = @user_id

/*** rb temp while testing in production
				insert EQFax (user_code, password, user_name, status, date_added)
				values (@user_id, @user_2_password, @user_name, 'I', GETDATE())
***/
			end
		end
	end

	-- return user's information
	select @user_name = ISNULL(user_name, ''),
			@user_email = ISNULL(email, ''),
			@user_first_name = ISNULL(CASE WHEN CHARINDEX(' ', user_name) = 0 THEN user_name
										ELSE LEFT(user_name, CHARINDEX(' ', user_name) - 1 ) END, ''),
			@user_last_name = ISNULL(CASE WHEN CHARINDEX(' ', user_name) = 0 THEN ''
									ELSE RIGHT(user_name, LEN(user_name) - CHARINDEX(' ', user_name)) END, '')
	from Users
	where user_code = @user_id

	-- return printer information
	select @printer_container_label = printer_container_label,
		@printer_lab_label = printer_lab_label,
		@printer_manifest = printer_manifest,
		@printer_continuation = printer_continuation,
		@printer_wo = printer_wo,
		@printer_wo_label = printer_wo_label,
		@printer_container_label_mini = printer_container_label_mini,
		@printer_haz_label = printer_haz_label,
		@printer_nonhaz_label = printer_nonhaz_label,
		@printer_fax = printer_fax,
		@printer_pdf = printer_pdf,
		@change_password = change_password,
		@default_company_id = default_company_id,
		@group_id = group_id,
		@printer_nonrcra_label = printer_nonrcra_label,
		@printer_universal_label = printer_universal_label,
		@printer_default = printer_default,
		@user_name = isnull(user_name,''),
		@user_email = isnull(email,''),
		@user_first_name = ISNULL(CASE WHEN CHARINDEX(' ', user_name) = 0 THEN user_name
									ELSE LEFT(user_name, CHARINDEX(' ', user_name) - 1 ) END, ''),
		@user_last_name = ISNULL(CASE WHEN CHARINDEX(' ', user_name) = 0 THEN ''
								ELSE RIGHT(user_name, LEN(user_name) - CHARINDEX(' ', user_name)) END, '')
	from users
	where user_code = @user_id

-- return values
select @user_2_id as user_2_id,
	@user_2_password as user_2_password,
	@avail_eqai_prod as avail_eqai_prod,
	@avail_eqai_test as avail_eqai_test,
	@avail_eqai_dev as avail_eqai_dev,
	@avail_finance_prod as avail_finance_prod,
	@avail_finance_test as avail_finance_test,
	@avail_finance_dev as avail_finance_dev,
	@image_server_name as image_server_name,
	@image_write_path as image_write_path,
	@image_write_path_citrix as image_write_path_citrix,
	@image_transfer_path as image_transfer_path,
	@image_transfer_path_citrix as image_transfer_path_citrix,
	@image_scan_path as image_scan_path,
	@image_scan_path_citrix as image_scan_path_citrix,
	@database_eqai as database_eqai,
	@database_finance as database_finance,
	@printer_container_label as printer_container_label,
	@printer_lab_label as printer_lab_label,
	@printer_manifest as printer_manifest,
	@printer_continuation as printer_continuation,
	@printer_wo as printer_wo,
	@printer_wo_label as printer_wo_label,
	@printer_container_label_mini as printer_container_label_mini,
	@printer_haz_label as printer_haz_label,
	@printer_nonhaz_label as printer_nonhaz_label,
	@printer_fax as printer_fax,
	@printer_pdf as printer_pdf,
	@change_password as change_password,
	@default_company_id as default_company_id,
	@group_id as group_id,
	@printer_nonrcra_label as printer_nonrcra_label,
	@printer_universal_label as printer_universal_label,
	@user_name as user_name,
	@user_email as email,
	@user_first_name as user_first_name,
	@user_last_name as user_last_name,
	@printer_default as printer_default
go

grant execute on sp_eqai_login to public
go
