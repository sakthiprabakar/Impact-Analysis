USE PLT_AI
GO

--CRM 2025.07,2025.08 & 2025.09 -- Starts

--US146656 & US150784

USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_profile_approval_info_for_lookup]    Script Date: 4/29/2025 5:14:33 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE or ALTER       Proc [dbo].[sp_sfdc_profile_approval_info_for_lookup] 
				    @TSDF_CODE varchar(15) null,
					@salesforce_site_csid varchar(18) null,
					@generator_id int null,
					@d365customer_id varchar(20) null,
					@company_id int null,
					@profit_ctr_id int,
					@description varchar(50),
					@response varchar(8000) OUTPUT
					
 
AS 
/*************************************************************************************************************
Description: 

EQAI profile approval info for salesforce.

Revision History:

US#117943 -- Nagaraj M -- Initial Creation
DE35129   -- Nagaraj M -- Added Facility column in the sql
US#129763 -- Nagaraj M -- Added bill_unit_code and Orig_Customer_Price
US#131090 -- Nagaraj M -- Replaced profile.Manifest_waste_desc with profile.approval_desc
Rally TA47716 -- Nagaraj M -- Addressed DBA review commentes (In class changed to Exists)
Rally DE36979 -- Nagaraj M -- Commented the TSDFApprovalPrice.primary_price_flag to show all the bill unit codes
Rally US141085 -- Nagaraj M -- Added order by Approval ascending order
Rally DE38314 -- Nagaraj M -- Handled null value in the #profile_approval_lookup where clause
Rally US#146656 -- Nagaraj M -- Added Original Customer ID, Original Customer Price, Price, DOT Shipping Name, and Haz Material,cost  columns
Rally US#150784 -- Nagaraj M -- Added RCRA_haz_flag flag in the sql query.

use plt_ai
go
Declare @response varchar(1000)
exec dbo.sp_sfdc_profile_approval_info_for_lookup
@TSDF_CODE='CCLEWIS',
@salesforce_site_csid ='',--'US117943',
@generator_id=289479,
@d365customer_id='C322006',
@company_id=72,
@profit_ctr_id=4,
@description ='',
@response =@response output
print @response

use plt_ai
go
Declare @response varchar(1000)
exec dbo.sp_sfdc_profile_approval_info_for_lookup
@TSDF_CODE='BFICONESTOGA',
@generator_id=327142,
@d365customer_id='C008349',
@company_id=74,
@profit_ctr_id=87,
@salesforce_site_csid ='',--'US117943',
@description ='',
@response =@response output
print @response
***************************************************************************************************************/
DECLARE 
	@key_value varchar (200),
	@ll_count_rec int,
	@ls_config_value char(1)='F',
	--@generator_id int,
	@customer_id int,
	@EQ_FLAG char(1),
	@tsdf_name varchar(40) =null,
	@eq_company int,
	@eq_profit_ctr int,
	@li_tsdf_code_cnt int,
	@validation_req_field varchar(100),
    @validation_req_field_value varchar(500),
	@validation_response varchar(1000),	 
	@ll_validation_ret int,	
	@ll_count int,
	@flag char(1)='I',
	@source_system varchar(100)='sp_sfdc_profile_approval_info_for_lookup'
Begin 
	Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase3'
	IF @ls_config_value is null or @ls_config_value=''
	Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
Begin
Begin Try

    Select @key_Value =  ' company id;' + isnull(TRIM(STR(@company_id)), '') +
						 ' profit_ctr_id;' + isnull(TRIM(STR(@profit_ctr_id)), '') +
						'  TSDF CODE ; ' + ISNULL(TRIM(@TSDF_CODE),'') +
						'  salesforce site csid ; ' + ISNULL(TRIM(@salesforce_site_csid),'') +
						'  d365customer_id ; ' + ISNULL(TRIM(@d365customer_id),'') +
						'  description ; ' + ISNULL(TRIM(@description),'') +
						 ' generator_id;' + isnull(TRIM(STR(@generator_id)), '') 
						
						
	Set @response = 'Integration Successful'

	Begin 
			Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
																 ('company_id',str(@company_id)),
																 ('profit_ctr_id',str(@profit_ctr_id)),
																 ('TSDF_CODE',@TSDF_CODE)
														--		 ('d365customer_id',@d365customer_id)
																-- ('salesforce_site_csid',@salesforce_site_csid)

		If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '' and (@generator_id is null or @generator_id = '' or @generator_id=0 ))
		begin
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values
			('salesforce_site_csid',@salesforce_site_csid)
		end 

		Declare sf_validation CURSOR for
					select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
					Open sf_validation
						fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
						While @@fetch_status=0
						Begin						   
						   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_profile_approval_info_for_lookup',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output
								If @validation_req_field='d365customer_id' and @ll_validation_ret <> -1
								   Begin
								   select @customer_id=customer_id from Customer where ax_customer_id=@d365customer_id and cust_status='A'
								   End
                              
						   If @ll_validation_ret = -1
						   Begin 
								 If @Response = 'Integration Successful'
								 Begin
									Set @Response ='Error: Integration failed due to the following reason;'
								 End
							 Set @Response = @Response + @validation_response+ ';'
							 Set @flag = 'E'
						   End	
						fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
					   End		
				    Close sf_validation
				    DEALLOCATE sf_validation 	 
					Drop table #temp_salesforce_validation_fields
			
		
			if (@salesforce_site_csid is null or @salesforce_site_csid='') and (@generator_id is null or @generator_id = '' or @generator_id=0 )
			begin
				If  @Response <> 'Integration Successful'
				begin
				Set @response = @response +'Please provide salesforce_site_csid / generator_id value to retrieve the profile/tsdf approval lookup values.'
				Set @flag = 'E'
				end
				If  @Response = 'Integration Successful'
				begin
				Set @response = 'Error: Integration failed due to the following reason; Please provide salesforce_site_csid / generator_id value to retrieve the profile/tsdf approval lookup values.'
				Set @flag = 'E'
				end
			end

			 select @EQ_FLAG=EQ_FLAG,@tsdf_name=TSDF_name,@eq_company=eq_company,@eq_profit_ctr=eq_profit_ctr from TSDF WHERE TSDF_CODE=@TSDF_CODE and TSDF_STATUS='A'
			 
		
			 if @EQ_FLAG ='T' 
			 begin
				if @d365customer_id is null or @d365customer_id =''
				begin
					If  @Response <> 'Integration Successful'
					begin
						Set @response = @response +'Please provide d365customer_id value to retrieve the profile approval lookup values.'
						Set @flag = 'E'
					end
					If  @Response = 'Integration Successful'
					begin
						Set @response = 'Error: Integration failed due to the following reason; Please provide d365customer_id value to retrieve the profile approval lookup values.'
						Set @flag = 'E'
					end
				end
			end
			  
			
			 If @flag = 'E'
			   Begin
				   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT
													@key_value,
													@source_system,
													'Insert',
													@Response,
													GETDATE(),
													SUBSTRING(USER_NAME(),1,40)
                Return -1								
				End

		if (@salesforce_site_csid is not null and @salesforce_site_csid <> '') and (@generator_id is null or @generator_id = '' or @generator_id=0 )
		begin
		select @generator_id=generator_id from Generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'
		end
		
		create table #cust (customer_id int)
		insert into #cust 
		(customer_id) select customer_id from customer where ax_customer_id=@d365customer_id and cust_status='A'
	
		CREATE TABLE #profile_approval_lookup ( Profile_ID int,Approval  VARCHAR(40),Waste_Code varchar(4),
												Description varchar(50),Expiration_Date datetime,UOM VARCHAR(4),ORIG_CUSTOMER_PRICE float, Facility varchar(40),orig_customer_id int,hazmat char(2)
												,dot_shipping_name varchar(255),price float,cost float,RCRA_haz_flag char(1))
		IF @EQ_FLAG='T' AND @FLAG <>'E'
		BEGIN
		insert into #profile_approval_lookup
		(Profile_ID,Approval,Waste_Code,Description,Expiration_Date,UOM,Orig_Customer_Price,Facility,orig_customer_id,hazmat,dot_shipping_name,price,RCRA_haz_flag)
		select Distinct
		ProfileQuoteApproval.profile_id,
		ProfileQuoteApproval.approval_code,
		Profile.waste_code,
		--isnull(Profile.Manifest_waste_desc,''),
		isnull(Profile.approval_desc,''),
		Profile.ap_expiration_date,
		ProfileQuoteDetail.bill_unit_code,
		ProfileQuoteDetail.orig_customer_price,
		'' AS facility,
		profile.orig_customer_id,
		profile.hazmat,
		profile.DOT_shipping_name,
		ProfileQuoteDetail.price,
		profile.RCRA_haz_flag
		FROM Profile Left outer join Generator on PROFILE.GENERATOR_ID = GENERATOR.GENERATOR_ID
		LEFT OUTER JOIN Customer ON Customer.customer_id = Profile.customer_id, 
		ProfileQuoteApproval, ProfileQuoteDetail,Wastecode
		WHERE Profile.profile_id = ProfileQuoteApproval.profile_id
		and ProfileQuoteApproval.profile_id = ProfileQuoteDetail.profile_id
		and ProfileQuoteApproval.company_id = ProfileQuoteDetail.company_id
		and ProfileQuoteApproval.profit_ctr_id = ProfileQuoteDetail.profit_ctr_id
		and Profile.waste_code_uid = wastecode.waste_code_uid
		AND ProfileQuoteDetail.record_type = 'D' 
		AND ProfileQuoteDetail.STATUS='A' 
		AND Profile.curr_status_code = 'A' 
		AND (Profile.generator_id = @generator_id OR (Profile.generator_id = 0 AND exists (select customer_id from #cust where #cust.customer_id = Profile.orig_customer_id) OR exists (select customer_id from #cust where Profile.orig_customer_id=#cust.customer_id ) 
		AND not EXISTS(Select ProfileGeneratorSiteType.profile_id from ProfileGeneratorSiteType where ProfileGeneratorSiteType.profile_id = profile.profile_id)
		AND EXISTS (SELECT generator_id FROM CustomerGenerator WHERE 
		EXISTS (select customer_id from #cust WHERE #cust.customer_id = CustomerGenerator.customer_id) AND CustomerGenerator.generator_id = @generator_id))
		OR
		(Profile.generator_id = 0 AND exists (select customer_id from #cust where #cust.customer_id=profile.customer_id) 
		OR EXISTS (select orig_customer_id from #cust where profile.orig_customer_id=#cust.customer_id) 
		AND EXISTS (Select ProfileGeneratorSiteType.profile_id from ProfileGeneratorSiteType where ProfileGeneratorSiteType.profile_id = profile.profile_id)
		AND EXISTS (SELECT CustomerGenerator.generator_id FROM CustomerGenerator Full outer Join 
		Generator on CustomerGenerator.generator_id = Generator.generator_id WHERE 
		CustomerGenerator.generator_id=@generator_id 
		AND EXISTS (select #cust.customer_id from #cust where #cust.customer_id=CustomerGenerator.customer_id ) 
		AND EXISTS (Select ProfileGeneratorSiteType.site_type from ProfileGeneratorSiteType 
		where ProfileGeneratorSiteType.profile_id = Profile.profile_id
		and ProfileGeneratorSiteType.site_type=Generator.site_type))))  
		AND ProfileQuoteApproval.company_id =@eq_company AND ProfileQuoteApproval.profit_ctr_id = @eq_profit_ctr and ProfileQuoteApproval.status = 'A'
	End
	IF @EQ_FLAG='F' AND @FLAG <>'E'
	BEGIN
		insert into #profile_approval_lookup
		(Profile_ID,Approval,Waste_Code,Description,Expiration_Date,UOM,Orig_Customer_Price,Facility,dot_shipping_name,hazmat,price,cost,RCRA_haz_flag)
		SELECT DISTINCT TSDFApproval.TSDF_approval_id,
		TSDFApproval.TSDF_approval_code,
		TSDFApproval.waste_code,
		isnull(TSDFApproval.waste_desc,''),
		TSDFApproval.tsdf_approval_expire_date,
		TSDFApprovalPrice.bill_unit_code,
		'' as orig_customer_price,
		'' AS facility,
		TSDFApproval.DOT_shipping_name,
		TSDFApproval.hazmat,
		TSDFApprovalPrice.price,
		TSDFApprovalPrice.cost,
		 TSDFApproval.RCRA_haz_flag
		FROM TSDFApproval
		INNER JOIN TSDF ON TSDF.TSDF_code = TSDFapproval.TSDF_code
		INNER JOIN TSDFApprovalPrice ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
		INNER JOIN WasteCode ON TSDFApproval.waste_code_uid = WasteCode.waste_code_uid
		LEFT JOIN Customer ON TSDFApproval.customer_id = Customer.customer_ID
		WHERE TSDFApproval.TSDF_approval_status = 'A'
		AND TSDF.TSDF_status = 'A'
		AND TSDFApprovalPrice.record_type = 'D'
		AND TSDFApprovalPrice.status = 'A'
		--AND TSDFApprovalPrice.primary_price_flag = 'T'
		AND TSDFApproval.generator_id <> 2
		AND TSDFApproval.TSDF_code = @TSDF_CODE 
		and generator_id = @generator_id 
		AND TSDFApproval.TSDF_code = @TSDF_CODE
		AND TSDF_approval_start_date <  getdate()+1
		AND TSDF_approval_expire_date >  getdate() 
		AND TSDFApproval.profit_ctr_id = @profit_ctr_id 
		AND TSDFApproval.company_id = @company_id
		UNION
		SELECT DISTINCT TSDFApproval.TSDF_approval_id,
		TSDFApproval.TSDF_approval_code,
		TSDFApproval.waste_code,
		TSDFApproval.waste_desc,
		TSDFApproval.tsdf_approval_expire_date,
		TSDFApprovalPrice.bill_unit_code,
		'' as orig_customer_price,
		'' as facility,
		TSDFApproval.DOT_shipping_name,
		TSDFApproval.hazmat,
		TSDFApprovalPrice.price,
		TSDFApprovalPrice.cost,
		TSDFApproval.RCRA_haz_flag
		FROM TSDFApproval
  			INNER JOIN TSDF ON TSDF.TSDF_code = TSDFapproval.TSDF_code
			INNER JOIN TSDFApprovalPrice ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
			INNER JOIN WasteCode ON TSDFApproval.waste_code_uid = WasteCode.waste_code_uid
            INNER JOIN Customer ON TSDFApproval.customer_id = Customer.customer_ID
		WHERE TSDFApproval.TSDF_approval_status = 'A'
			AND TSDF.TSDF_status = 'A'
			AND TSDFApprovalPrice.record_type = 'D'
			AND TSDFApprovalPrice.status = 'A'
			--AND TSDFApprovalPrice.primary_price_flag = 'T'
			AND TSDFApproval.TSDF_approval_start_date <= GETDATE()
			AND TSDFApproval.TSDF_approval_expire_date > GETDATE()
			AND TSDFApproval.generator_id = 2  
			AND TSDF_approval_start_date < getdate()+1 
			AND TSDF_approval_expire_date >getdate()
			AND TSDFApproval.TSDF_code = @tsdf_code 
			AND TSDFApproval.profit_ctr_id = @profit_ctr_id
			AND TSDFApproval.company_id = @company_id
	END
END

		select @ll_count=count(*) from #profile_approval_lookup	
		IF @ll_count > 0
		BEGIN
			
			update #profile_approval_lookup set facility=@tsdf_name

			IF @EQ_FLAG='T'
			BEGIN
				SELECT Approval,Profile_ID as [Profile ID],Waste_Code as [Waste Code],Description,Expiration_Date as [Expiration Date],
				UOM,orig_customer_price AS [Original Customer Price],Facility, orig_customer_id [Original Customer ID*],hazmat [Haz Material?],dot_shipping_name [DOT Shipping Name],price [Price],@EQ_FLAG [EQ Facility],
				RCRA_haz_flag [RCRA haz flag]
				FROM #profile_approval_lookup 
				--where Description like '%' +isnull(@description,'') + '%'
				where isnull(Description,'') like '%' +isnull(@description,'') + '%'
				order by Approval asc
			END
			IF @EQ_FLAG='F'
			BEGIN
				SELECT Approval,Profile_ID as [Profile ID],Waste_Code as [Waste Code],Description,Expiration_Date as [Expiration Date],
				UOM,Facility,dot_shipping_name [DOT Shipping Name],hazmat [Haz Material?],price [Price],cost [Cost],@EQ_FLAG [EQ Facility],
				RCRA_haz_flag [RCRA haz flag]
				FROM #profile_approval_lookup 
				--where Description like '%' +isnull(@description,'') + '%'
				--where COALESCE([Description],'') like '%' +isnull(@description,'') + '%'
				where isnull(Description,'') like '%' +isnull(@description,'') + '%'
				order by Approval asc
			END
		END
		
		DROP TABLE #profile_approval_lookup
		DROP TABLE #cust
	
	if @ll_count = 0 
	set @Response = 'No profile approval records or tsdf approval records exists.'
	BEGIN
		INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT @key_value,@source_system,'Insert',@Response,GETDATE(),SUBSTRING(USER_NAME(),1,40)
    END
END TRY 
	BEGIN CATCH			
		INSERT INTO Plt_AI_Audit..
		Source_Error_Log 
		(input_params,
		source_system_details, 
		action,
		Error_description,
		log_date, 
		Added_by) 
		SELECT 
		@key_value, 
		@source_system, 
		'Select', 
		ERROR_MESSAGE(), 
		GETDATE(), 
		SUBSTRING(USER_NAME(),1,40) 
	END CATCH 
End
If @ls_config_value='F'
Begin
   Print 'SFDC Data Integration Failed,since CRM Go live flag - Phase3 is off. Hence Store procedure will not execute.'
   Return -1
End
End


GO



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_profile_approval_info_for_lookup] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_profile_approval_info_for_lookup] TO svc_CORAppUser

GO
