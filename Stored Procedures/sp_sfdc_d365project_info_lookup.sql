USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_d365project_info_lookup]    Script Date: 2/19/2025 4:47:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO


CREATE OR ALTER           PROC 
[dbo].[sp_sfdc_d365project_info_lookup] 
@d365_customer_id varchar(10),
@company_id int,
@profit_ctr_id int,
@d365_project_id varchar(29),
@response varchar(300) output
AS 

  /*************************************************************************************************************
 Rally# US141921-- Nagaraj M -- Stored Proc - Fetch D365 Project ids for Lookup in Salesforce
  Declare @response varchar(500)
  exec dbo.[sp_sfdc_d365project_info_lookup]  
  @d365_customer_id='C010897',
  @company_id=15,
  @profit_ctr_id=0,
  @d365_project_id='',
  @response=@response output
  print @response
 *************************************************************************************************************/
DECLARE 
@ls_config_value char(1)='F',
@ll_count int

BEGIN 
	Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
	IF @ls_config_value is null or @ls_config_value=''
		Select @ls_config_value='F'
End
If @ls_config_value='T'
Begin

	create table #temp_d365projects (d365_project varchar(30))

	select @ll_count=count(*) 
	from WorkOrderHeader wh
	join Customer c
		on c.customer_id = wh.customer_id
		and c.ax_customer_id = @d365_customer_id
		and wh.company_id=@company_id
		and wh.profit_ctr_id=@profit_ctr_id
	where isnull(AX_Dimension_5_Part_1,'') <> ''

	if @ll_count > 0  
	Begin
	insert into #temp_d365projects
		select distinct AX_Dimension_5_part_1 +
		case when isnull(AX_Dimension_5_part_2,'') = '' then ''
		else '.' + AX_Dimension_5_Part_2
		end d365_project
		from WorkOrderHeader wh
		join Customer c
			on c.customer_id = wh.customer_id
			and c.ax_customer_id = @d365_customer_id
			and wh.company_id=@company_id
			and wh.profit_ctr_id=@profit_ctr_id
			where isnull(AX_Dimension_5_Part_1,'') <> ''
		order by AX_Dimension_5_part_1 +
		case when isnull(AX_Dimension_5_part_2,'') = '' then ''
		else '.' + AX_Dimension_5_Part_2
		end



		select d365_project from #temp_d365projects
		where d365_project like '%' +isnull(@d365_project_id,'') + '%'


		
	End

	IF @ll_count = 0
	Begin
		select @response = 'There are no d365 project ids for this d365customer_id:' + @d365_customer_id +' Company_id: ' + trim(str(@company_id)) + ' Profit_ctr_id: '+ trim(str(@profit_ctr_id))
		INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,
		source_system_details, 
		action,
		Error_description,
		log_date, 
		Added_by) 
		SELECT   @d365_customer_id +trim(str(@company_id)) + trim(str(@profit_ctr_id)),
		'sp_sfdc_365project_info_lookup', 
		'Select', 
		@response,
		GETDATE(), 
		SUBSTRING(USER_NAME(),1,40) 
	End
	drop table #temp_d365projects
END
If @ls_config_value='F'
Begin
	 Print 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'	
	 Return -1
End

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_d365project_info_lookup] TO EQAI  

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_d365project_info_lookup] TO COR_USER

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_d365project_info_lookup] TO svc_CORAppUser

GO