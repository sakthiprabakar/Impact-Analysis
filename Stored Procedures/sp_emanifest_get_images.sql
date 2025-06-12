use plt_ai
go

drop proc if exists sp_emanifest_get_images
go

create proc sp_emanifest_get_images (
	@source_company_id			varchar(2) 				/* company_id */
	, @source_profit_ctr_id 	varchar(2) 				/* profit_ctr_id */
	, @source_table				varchar(40)				/* receipt, workorder, etc */
	, @source_id				int 					/* receipt_id, workorder_id, etc */
	, @type						varchar(40) = 'manifest'
) as
/******************************************************************************************
Retrieve manifest scans related to a source

sp_emanifest_get_images '21', '0', 'receipt', '1091672';
sp_emanifest_get_images '26', '0', 'receipt', '93352';
sp_emanifest_get_images '3', '0', 'receipt', '1297734';

select top 40 s.* from plt_image..scan s (nolock)
join plt_image..scanimage si (nolock) on s.image_id = si.image_id
join plt_ai..receipt r on s.receipt_id = r.receipt_id and s.company_id = r.company_id and s.profit_ctr_id = r.profit_ctr_id and r.trans_mode = 'I' and r.waste_accepted_flag = 'T' and r.receipt_status = 'A'
where document_source = 'receipt' and status = 'A' and s.type_id = 99
and s.date_added <= '10/1/2023'
 order by date_added
 
SELECT * FROM receipt WHERE receipt_id =  632321 and company_id = 2

sp_emanifest_get_images '2', '0', 'receipt', '632321';
sp_emanifest_get_images '2', '0', 'receipt', '632321', 'returned manifest';


insert AthenaQueue (source, source_table, source_id, source_company_id, source_profit_ctr_id	,receipt_date	,record_type	,status	,request	,response	,manifest	,response_warning	,response_error	,date_added	,date_modified)
values ('eqai', 'receipt', '632321', '2', '0', '2023-01-04', 'rejection send', 'New', '', '', '001202164WAS', '', '', getdate()-1.25, getdate())

397809	eqai	receipt	669735	45	0	2023-10-17 00:00:00.000	rejection send	ReadyForSignature	{"manifestTrackingNumber":"025796597JJK","submissionType":"Image","generator":{"epaSiteId":"CAR000295352","name":"ALBERTSONS 2783","mailingAddress":{"address1":"2899 JAMACHA RD","address2":"ATTN: ICC RECEIVING","city":"EL CAJON","state":{"code":"CA"},"country":{"code":"US"},"zip":"92019"},"siteAddress":{"address1":"2899 JAMACHA RD","address2":"","city":"EL CAJON","state":{"code":"CA"},"country":{"code":"US"},"zip":"92019"},"contact":{"phone":{"number":"800-451-8346"}},"emergencyPhone":{"number":"800-451-8346"}},"designatedFacility":{"epaSiteId":"NVT330010000","name":"US ECOLOGY, INC","mailingAddress":{"address1":"HIGHWAY 95, 11 MILES SOUTH OF BEATTY","address2":"","city":"BEATTY","state":{"code":"NV"},"country":{"code":"US"},"zip":"89003"},"siteAddress":{"address1":"HIGHWAY 95, 11 MILES SOUTH OF BEATTY","address2":"","city":"BEATTY","state":{"code":"NV"},"country":{"code":"US"},"zip":"89003"},"contact":{"phone":{"number":"800-590-5220"}},"emergencyPhone":{"number":"800-839-3975"}},"rejection":false,"residue":false,"import":false,"containsPreviousRejectOrResidue":false,"printedDocument":{"name":"025796597JJK-11-7-2023-6-38-53-PM.pdf","size":82153,"mimeType":"APPLICATION_PDF"}}	{   "manifestTrackingNumber" : "025796597JJK",   "reportId" : "cdf26a2b-0c83-45b1-8b15-5799ddabcb9f",   "date" : "2023-11-07T23:39:36.782+00:00",   "operationStatus" : "Updated",   "warnings" : [ {     "field" : "Emanifest.status",     "message" : "Provided Status will be ignored. Emanifest will be assigned ReadyForSignature status"   }, {     "field" : "Emanifest.generator",     "message" : "Not all required Generator site information and/or signature information is provided so system cannot determine which price to charge for this manifest. To ensure that this manifest is billed accurately, please update the manifest with all required generator site and signature information."   } ],   "generatorReport" : {     "entityId" : {       "entityIdField" : "siteId",       "entityIdValue" : "CAR000295352"     },     "warnings" : [ {       "field" : "mailingAddress.address1",       "message" : "Provided Value for mailingAddress.address1 contains the street number that is stored in the latest handler record in RCRAInfo for this site.  Moved the street number from mailingAddress.address1 to mailingAddress.streetNumber. "     } ]   } }	025796597JJK	Manifest Warning: Emanifest.status: "" - Provided Status will be ignored. Emanifest will be assigned ReadyForSignature status | Manifest Warning: Emanifest.generator: "" - Not all required Generator site information and/or signature information is provided so system cannot determine which price to charge for this manifest. To ensure that this manifest is billed accurately, please update the manifest with all required generator site and signature information.	.	2023-11-05 14:01:57.653	2023-11-07 16:40:29.343

SELECT  * FROM    plt_ai..receipt where receipt_id = 2211539 and company_id = 21

SELECT  * FROM    plt_image..scan where receipt_id = 2211539 and company_id = 21

2023-11-08 JPB	Added optional @type input that defaults to 'manifest' (old hard-coded value in use)
	so 'returned manifest' could be opted for Rejection cases.

******************************************************************************************/
	if trim(isnull(@type,'')) = '' set @type = 'manifest'

	select s.image_id, isnull(manifest, document_name) filename, s.file_type, isnull(s.page_number, 1) page_number, si.image_blob
	from plt_image..scan s
	join plt_image..scanimage si 
		on s.image_id = si.image_id 
		and s.status = 'A'
	join plt_image..scandocumenttype t 
		on s.type_id = t.type_id
		and t.scan_type = s.document_source
		-- and t.document_type = 'manifest' 
		-- 2023-11-08 - above modified to:
		and t.document_type = @type
	WHERE s.receipt_id = @source_id
	and s.company_id = @source_company_id
	and s.profit_ctr_id = @source_profit_ctr_id
	and s.document_source = @source_table
	and isnull(s.app_source, '') <> 'aesop'
	order by s.company_id, s.profit_ctr_id, s.receipt_id, isnull(s.page_number, 1)

go

grant execute on sp_emanifest_get_images to eqai, athena_svc
go
