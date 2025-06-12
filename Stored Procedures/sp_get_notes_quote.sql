USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_get_notes_quote]    Script Date: 4/18/2023 1:05:13 PM ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE procedure [dbo].[sp_get_notes_quote] ( @quote_id int)
as


/***************************************************************************************
Returns notes for a given quote record
Requires: sp_get_notes (parent procedure that calls this)

04/12/2023 Venu created


Loads on PLT_AI*
Test Cmd Line: sp_get_notes_quote 300 
****************************************************************************************/

Begin         
	insert #notes
	SELECT  Note.note_id  ,
		Note.note_source ,
		Note.company_id,
		Note.profit_ctr_id,
		Note.note_date,
		Note.subject,
		Note.status ,
		Note.note_type ,
		Note.note ,
		Note.customer_id,
		Note.contact_id,
		Note.generator_id,
		Note.approval_code,
		Note.profile_id,
		Note.receipt_id,
		Note.workorder_id,
		Note.merchandise_id,
		Note.batch_location,
		Note.batch_tracking_num,
		Note.project_id,
		Note.project_record_id,
		Note.project_sort_id,
		Note.contact_type,
		Note.added_by,
		Note.date_added,
		Note.modified_by,
		Note.date_modified,
		Note.app_source,
		null,
		0 as editable,
		1 as sort,
			 Contact.name,
		Note.tsdf_approval_id,
		Note.quote_id
		FROM Note
		 LEFT OUTER JOIN Contact ON Note.contact_id = Contact.contact_id
	   WHERE Note.quote_id = @quote_id 
end

              
GO


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_quote] TO EQAI
    
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_notes_quote] TO svc_CORAppUser