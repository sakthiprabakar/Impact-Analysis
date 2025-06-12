-- drop proc sp_ContactCORInvoiceBucket_Maintain 
go

create proc sp_ContactCORInvoiceBucket_Maintain 
	@contact_id		int = null
	, @account_type	char(1) = null
	, @account_id	int = null
	, @operation	varchar(20) = null
AS
/*

SELECT  COUNT(*)  FROM    ContactCORInvoiceBucket 
WHERE contact_id = 185547

sp_ContactCORInvoiceBucket_Maintain 

sp_ContactCORInvoiceBucket_Maintain 185547

*/

BEGIN


	if exists (select 1 from sysobjects where name = 'xContactCORInvoiceBucket')
		drop table xContactCORInvoiceBucket;

	CREATE TABLE [dbo].[xContactCORInvoiceBucket] (
		[contactcorinvoicebucket_uid]         INT      IDENTITY (1, 1) NOT NULL PRIMARY KEY,
		[contact_id]   INT      NOT NULL,
		[invoice_id]   INT      NOT NULL,
		[revision_id]  INT      NOT NULL,
		[invoice_date] DATETIME NOT NULL
	);

	CREATE INDEX [IX_ContactCORInvoiceBucket_contact_id] ON [dbo].xContactCORInvoiceBucket ([contact_id], [invoice_id])
	grant select on xContactCORInvoiceBucket to COR_USER
	grant select, insert, update, delete on xContactCORInvoiceBucket to EQAI

	insert xContactCORInvoiceBucket
	select distinct x.contact_id, i.invoice_id, i.revision_id, i.invoice_date
	from ContactCORCustomerBucket x (nolock) 
	join invoiceheader i (nolock) on x.customer_id = i.customer_id
	where i.status = 'I'
	and x.contact_id = isnull(@contact_id, x.contact_id)

BEGIN TRY
    BEGIN TRANSACTION

	--if (select count(*) from xContactCORInvoiceBucket) > 0 
	begin

		if @contact_id is null begin

				if  exists (select 1 from sysobjects where name = 'ContactCORInvoiceBucket')
					drop table ContactCORInvoiceBucket
		
				exec sp_rename xContactCORInvoiceBucket, ContactCORInvoiceBucket
	
		end else begin

				delete from ContactCORInvoiceBucket
				where contact_id = @contact_id

				insert ContactCORInvoiceBucket
				select 
					[contact_id]   ,
					[invoice_id]   ,
					[revision_id]  ,
					[invoice_date] 
				from xContactCORInvoiceBucket

				drop table xContactCORInvoiceBucket
	
		end
	end

	update ContactCORInvoiceBucket  set
	invoice_date = dateadd(m, -1, getdate()) + 3 
	FROM    ContactCORInvoiceBucket b
	join invoiceheader h on b.invoice_id = h.invoice_id and b.revision_id = h.revision_id
	WHERE h.customer_id = 888880


	COMMIT TRAN -- Transaction Success!
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN --RollBack in case of Error

    -- you can Raise ERROR with RAISEERROR() Statement including the details of the exception
    -- RAISERROR(ERROR_MESSAGE(), ERROR_SEVERITY(), 1)
END CATCH

return 0

END

GO

GRANT EXEC ON [dbo].[sp_ContactCORInvoiceBucket_Maintain] TO COR_USER;

GO