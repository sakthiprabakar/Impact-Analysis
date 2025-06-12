CREATE PROCEDURE sp_renumber_receipt( 
                @company_num    INT, 
                @profit_ctr_num INT, 
                @receipt_old    INT, 
                @receipt_new    INT,
					 @receipt_date   datetime) 
AS 
-- sp_renumber_receipt 12,0,31241, 999999, '07/31/2009'

Declare
@old_rowcount	int,
@new_rowcount	int

Set @old_rowcount = (Select Count(*) from receipt where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Insert into ReceiptAudit Select company_id, profit_ctr_id, receipt_id, line_id ,Null,'receipt','receipt_date',receipt_date,@receipt_date,'DB_SCRIPT','sysadm','db_script','09/04/2009' from receipt where company_id = @company_num and profit_ctr_id = @profit_ctr_num and receipt_id = @receipt_old
Update receipt set receipt_id = @receipt_new, receipt_date = @receipt_date where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('Receipt',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)


Select @old_rowcount = Count(*) from receiptwastecode where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Update receiptwastecode set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values ('ReceiptwasteCode',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptaudit where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptaudit set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptaudit',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptcomment where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptcomment set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptcomment',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptcommingled where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptcommingled set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptcommingled',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptdiscrepancy where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptdiscrepancy set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptdiscrepancy',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptmanifest where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptmanifest set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptmanifest',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptPCB where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptPCB set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptPCB',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptPrice where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptPrice set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptPrice',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptPriceAdjustment where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptPriceAdjustment set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptPriceAdjustment',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptTransporter where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptTransporter set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptTransporter',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from receiptconstituent where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update receiptconstituent set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('receiptconstituent',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)


Set @old_rowcount = (Select Count(*) from BillingLinkLookup where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update BillingLinkLookup set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('BillingLinkLookup',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)


Set @old_rowcount = (Select Count(*) from Note where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update Note set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('Note',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)


Set @old_rowcount = (Select Count(*) from billing where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update billing set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('billing',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from billingComment where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update billingComment set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('billingComment',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from billingAudit where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update billingAudit set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('billingAudit',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from InvoiceDetail where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update InvoiceDetail set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('InvoiceDetail',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from container where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update container set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('container',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from containerdestination where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update containerdestination set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('containerdestination',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

--Update ContainerDestination set tracking_num = Cast(@receipt_new as varchar) + '-' + Substring(tracking_num,CharIndex(tracking_num,'-') + 1,Len(tracking_num)-CharIndex(tracking_num,'-')) where company_id = @company_num and profit_ctr_id = @profit_ctr_num and Left(tracking_num,CharIndex(tracking_num,'-') - 1) = @receipt_old and CharIndex(tracking_num,'-') > 0

Set @old_rowcount = (Select Count(*) from containerwastecode where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update containerwastecode set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('containerwastecode',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from containerconstituent where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update containerconstituent set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('containerconstituent',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from containerwastecode where source_receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update containerwastecode set source_receipt_id = @receipt_new where source_receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('containerwastecode - source',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from containerconstituent where source_receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update containerconstituent set source_receipt_id = @receipt_new where source_receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('containerconstituent - source',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from containerAudit where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update containerAudit set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('containerAudit',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)

Set @old_rowcount = (Select Count(*) from plt_image..scan where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num)
Update plt_image..scan set receipt_id = @receipt_new where receipt_id = @receipt_old and company_id = @company_num and profit_ctr_id = @profit_ctr_num
Set @new_rowcount = @@rowcount
Insert Into Receipt_fix_0809 Values('scan',@company_num, @profit_ctr_num, @receipt_old, @receipt_new, @old_rowcount, @new_rowcount)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_renumber_receipt] TO [EQAI]
    AS [dbo];

