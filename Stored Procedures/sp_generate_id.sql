
CREATE Procedure sp_generate_id (
	@company_id	int,
	@profit_ctr_id	int,
	@type	varchar(10),
	@qty	int= 1)

AS
/***************************************************************************************
Function	: sp_generate_id
Database	: PLT_AI
Created		: 01/27/2009 - Keith Miller
Description	: returns the next available ID based on what is in the profitCenter table

01/27/2009 KAM  Created
04/22/2011 RWB	Generation of IDs was using TABLOCK to issue a full table lock, changed to UPDLOCK. Added
				error checking, so a failed update will no longer return next ID as valid.

sp_generate_id 22,0,'W',2
****************************************************************************************/
BEGIN
	begin transaction sequence_next
	Declare	@nxt	int

	IF Upper(@type) = 'R'
	Begin
		Select @nxt = next_receipt_id
		From ProfitCenter
		With (UPDLOCK) --rb (TABLOCK)
		Where company_id = @company_id and
				profit_ctr_id = @profit_ctr_id

		--rb 04/22/2011
		if (@@ERROR <> 0)
			goto ON_ERROR

		If IsNull(@nxt,0) = 0 
			Set @nxt = 1
	
		Update ProfitCenter 
		--rb With (TABLOCK)
		Set next_receipt_id = (@nxt + @qty)
		Where company_id = @company_id and
			profit_ctr_id = @profit_ctr_id

		--rb 04/22/2011
		if (@@ERROR <> 0)
			goto ON_ERROR
	End
	
	If Upper(@type) = 'W'
	Begin
		Select @nxt = next_workorder_id
		From ProfitCenter
		With (UPDLOCK) --rb (TABLOCK)
		Where company_id = @company_id and
				profit_ctr_id = @profit_ctr_id

		-- rb 04/22/2011
		if (@@ERROR <> 0)
			goto ON_ERROR

		If IsNull(@nxt,0) = 0 
			Set @nxt = 1
	
		Update ProfitCenter 
		--rb With (TABLOCK)
		Set next_workorder_id = (@nxt + @qty)
		Where company_id = @company_id and
				profit_ctr_id = @profit_ctr_id
	
		-- rb 04/22/2011
		if (@@ERROR <> 0)
			goto ON_ERROR

		Set @nxt =	@nxt * 100	
	End

	If Upper(@type) = 'WT'
	Begin
		Select @nxt = next_template_id
		From ProfitCenter
		With (UPDLOCK) --rb (TABLOCK)
		Where company_id = @company_id and
				profit_ctr_id = @profit_ctr_id

		-- rb 04/22/2011
		if (@@ERROR <> 0)
			goto ON_ERROR

		If IsNull(@nxt,0)= 0 
			Set @nxt = -1

		Update ProfitCenter 
		--rb With (TABLOCK)
		Set next_template_id = (@nxt - @qty)
		Where company_id = @company_id and
				profit_ctr_id = @profit_ctr_id
	
		-- rb 04/22/2011
		if (@@ERROR <> 0)
			goto ON_ERROR
	End

	commit transaction sequence_next
	Return @nxt

-- rb 04/22/2011
ON_ERROR:
	rollback transaction sequence_next
	return -1

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_generate_id] TO [EQAI]
    AS [dbo];

