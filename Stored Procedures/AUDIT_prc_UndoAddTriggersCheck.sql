CREATE PROC dbo.AUDIT_prc_UndoAddTriggersCheck
@TabName nvarchar(4000),
@action int,
@script nvarchar(4000),
@result_script nvarchar(4000) output
as
begin
	declare @trigger_name nvarchar(4000)
	declare @use_disable bit
	set @use_disable = 0
	if @action=1 --update trigger
	begin
		set @trigger_name='[tr_u_AUDIT_'+PARSENAME(@TabName,1)+']'
		if(OBJECTPROPERTY(OBJECT_ID(@trigger_name), 'ExecIsUpdateTrigger')=1)
		if(OBJECTPROPERTY(OBJECT_ID(@trigger_name), 'ExecIsTriggerDisabled')=0)
			set @use_disable = 1
	end
	else if @action=2 --insert trigger
	begin
		set @trigger_name='[tr_i_AUDIT_'+PARSENAME(@TabName,1)+']'
		if(OBJECTPROPERTY(OBJECT_ID(@trigger_name), 'ExecIsInsertTrigger')=1)
		if(OBJECTPROPERTY(OBJECT_ID(@trigger_name), 'ExecIsTriggerDisabled')=0)
			set @use_disable = 1
	end
	else if @action=3 --delete trigger
	begin
		set @trigger_name='[tr_d_AUDIT_'+PARSENAME(@TabName,1)+']'
		if(OBJECTPROPERTY(OBJECT_ID(@trigger_name), 'ExecIsDeleteTrigger')=1)
		if(OBJECTPROPERTY(OBJECT_ID(@trigger_name), 'ExecIsTriggerDisabled')=0)
			set @use_disable = 1
	end
	if @use_disable=1
	begin
		set @result_script = 'ALTER TABLE '+@TabName+'
  DISABLE TRIGGER '+@trigger_name+' 
' + @script +'
ALTER TABLE '+@TabName+'
  ENABLE TRIGGER '+@trigger_name+' 
'
	end
	else
	begin
		set @result_script=@script
	end
end
