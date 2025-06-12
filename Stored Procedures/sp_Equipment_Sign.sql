
create proc sp_Equipment_Sign (
	@equipment_set_id		int
	, @sign_user_code		varchar(10)
	, @sign_name			varchar(60)
	, @sign_title			varchar(60)
	, @sign_email			varchar(60)
	, @sign_phone			varchar(20)
	, @sign_fax				varchar(20)
	, @sign_address			varchar(60)
	, @sign_city			varchar(20)
	, @sign_state			varchar(20)
	, @sign_zip_code		varchar(20)
	, @sign_agree			varchar(1)
	, @sign_ip				varchar(60)
	, @sign_date			datetime
	, @proxy_sign_flag		char(1)
	, @added_by				varchar(10)
)
as
/* *******************************************************************
sp_Equipment_Sign
	Insert a record into EquipmentSignature tables (signature & xtable)

	SELECT * FROM EquipmentSignature
	SELECT * FROM EquipmentXEquipmentSignature
	
History:
	2014-03-05	JPB	Created
	
******************************************************************* */

declare @signature_id int

Insert EquipmentSignature (
	sign_user_code		
	, sign_name			
	, sign_title			
	, sign_email			
	, sign_phone			
	, sign_fax			
	, sign_address		
	, sign_city			
	, sign_state			
	, sign_zip_code		
	, sign_agree			
	, sign_ip				
	, sign_date			
	, proxy_sign_flag		
	, date_added			
	, added_by			
	, date_modified		
	, modified_by			
) values (
	@sign_user_code		
	, @sign_name			
	, @sign_title			
	, @sign_email			
	, @sign_phone			
	, @sign_fax			
	, @sign_address		
	, @sign_city			
	, @sign_state			
	, @sign_zip_code		
	, @sign_agree			
	, @sign_ip				
	, @sign_date			
	, @proxy_sign_flag		
	, getdate()
	, @added_by
	, getdate()
	, @added_by
)

set @signature_id = @@identity

insert EquipmentSetXEquipmentSignature(equipment_set_id, signature_id)
select e.equipment_set_id , @signature_id
from EquipmentSet e
where e.equipment_set_id = @equipment_set_id
and not exists (
	select 1 from EquipmentSetXEquipmentSignature s 
	where s.equipment_set_id = e.equipment_set_id
)

-- send a message


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Sign] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Sign] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Sign] TO [EQAI]
    AS [dbo];

