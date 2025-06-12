
CREATE PROCEDURE sp_biennial_report_source_overlay_manual
	@biennial_id int
AS

/*
	This is used to do manual updates to the source data (not in overlay)
	Usage: sp_biennial_report_source_overlay_manual;	
*/
BEGIN
	
	
declare @tbl_transporters table
(
transporter_EPA_ID varchar(15),
transporter_name varchar(40),
transporter_addr1 varchar(40),
transporter_addr2 varchar(40),
transporter_city varchar(40),
transporter_state varchar(2),
transporter_zip_code varchar(15)
)
INSERT INTO @tbl_transporters VALUES  ('NCD986232221','A&D Environmental Services, Inc.','2718 Uwharrie Road','','Archdale','NC','27263')
INSERT INTO @tbl_transporters VALUES  ('INR000127621','Advanced Waste Services','5625 Old Porter Rd.','','Portage','IN','46368')
INSERT INTO @tbl_transporters VALUES  ('FLD982105884','AR Paquette & Company, Inc.','1400 E INTERNATIONAL SPEEDWAY','','DELAND','FL','32724')
INSERT INTO @tbl_transporters VALUES  ('OHD981000557','COUSINS WASTE','1701 MATZINGER ROAD','','TOLEDO','OH','43612')
INSERT INTO @tbl_transporters VALUES  ('LAR000045963','DUPRE LOGISTICS LLC','TOBY MOUTON ROAD','','DUSON','LA','70529')
INSERT INTO @tbl_transporters VALUES  ('PAR000504068','ECS&R, INC.','3237 US Highway 19','','Cochranton','PA','16314')
INSERT INTO @tbl_transporters VALUES  ('OHR000102053','EMERALD ENVIRONMENTAL','1621 SAINT CLAIRE AVE','','KENT','OH','44240')
INSERT INTO @tbl_transporters VALUES  ('NCR000003186','HAZ-MAT TRANSPORTATION & DISPOSAL','DALTON AVENUE','','CHARLOTTE','NC','28206')
INSERT INTO @tbl_transporters VALUES  ('INR000124370','HINER TRANSPORT, INC.','1350 S. JEFFERSON  ST','','HUNTINGTON','IN','46750')
INSERT INTO @tbl_transporters VALUES  ('OHD987036423','Inland Waters of Ohio, Inc.','2195 Drydock Avenue','','Cleveland','OH','44113')
INSERT INTO @tbl_transporters VALUES  ('MIK588964676','LAIDLAW CARRIERS VAN GP INC.','1170 RIDGEWAY ROAD','','WOODSTOCK','ON','NA50A0')
INSERT INTO @tbl_transporters VALUES  ('MNS000136671','Little H Trucking','PO 343 Vernon Cntr.','','Vernon Center','MN','56090')
INSERT INTO @tbl_transporters VALUES  ('PAD013826847','MCCUTCHEON ENTERPRISES','250 PARK ROAD','','APOLLO','PA','15613')
INSERT INTO @tbl_transporters VALUES  ('NC0000942144','SHAMROCK ENVIRONMENTAL CORPORATION','CORPORATE PARK DRIVE','','BROWNS SUMMIT','NC','27214')
INSERT INTO @tbl_transporters VALUES  ('OHR000028837','THE PENNOHIO CORPORATION','4813 N. WOODMAN AVE','','ASTHABULA','OH','44004')
INSERT INTO @tbl_transporters VALUES  ('NYF006000053','TRANSPORT ROLLEX LTEE','910, BOUL. LIONEL-BOULET','','VARENNNES','QC','J3X 1P7')
INSERT INTO @tbl_transporters VALUES  ('OKD981588791','TRIAD TRANSPORT, INC.','1630 DIESEL AVE','PO Box 818','MCALESTER','OK','74502')
INSERT INTO @tbl_transporters VALUES  ('PAD086214574','Univar USA, Inc.','328 Bunola River Road','','Bunola','PA','15020')
INSERT INTO @tbl_transporters VALUES  ('PAD980707442','WEAVERTOWN','206 WEAVERTOWN ROAD','','CANONSBURG','PA','15317')
INSERT INTO @tbl_transporters VALUES  ('OKD981588791','TRIAD TRANSPORT, INC.','1630 DIESEL','','MCALESTER','OK','74502')
						
	
UPDATE EQ_Extract..BiennialReportSourceData SET 
transporter_name = t.transporter_name,
transporter_addr1 = t.transporter_addr1,
transporter_addr2 = t.transporter_addr2,
transporter_city = t.transporter_city,
transporter_state = t.transporter_state,
transporter_zip_code = t.transporter_zip_code
FROM @tbl_transporters t
	INNER JOIN EQ_Extract..BiennialReportSourceData src ON t.transporter_EPA_ID = src.transporter_EPA_ID
WHERE biennial_id = @biennial_id
	
	
/* update for MXI */
declare @tbl_mxi_transporter table
(
ew_doc varchar(100),
ew_doc_line int,
transporter_EPA_ID varchar(15),
transporter_name varchar(40),
transporter_addr1 varchar(40),
transporter_addr2 varchar(40),
transporter_city varchar(40),
transporter_state varchar(2),
transporter_zip_code varchar(15)
)
INSERT INTO @tbl_mxi_transporter VALUES  ('D32408','1','NJD986607380','MXI (MAUMEE EXPRESS INC)','SUTTON ROAD','','LEBANON','NJ','08833')
INSERT INTO @tbl_mxi_transporter VALUES  ('D32413','1','NJD986607380','MXI (MAUMEE EXPRESS INC)','SUTTON ROAD','','LEBANON','NJ','08833')
INSERT INTO @tbl_mxi_transporter VALUES  ('D32409','1','NJD986607380','MXI (MAUMEE EXPRESS INC)','SUTTON ROAD','','LEBANON','NJ','08833')
INSERT INTO @tbl_mxi_transporter VALUES  ('D31757','1','NJD986607380','MXI (MAUMEE EXPRESS INC)','SUTTON ROAD','','LEBANON','NJ','08833')

	
	UPDATE EQ_Extract..BiennialReportSourceData SET 
	transporter_epa_id = t.transporter_epa_id,
	transporter_name = t.transporter_name,
	transporter_addr1 = t.transporter_addr1,
	transporter_addr2 = t.transporter_addr2,
	transporter_city = t.transporter_city,
	transporter_state = t.transporter_state,
	transporter_zip_code = t.transporter_zip_code
	FROM @tbl_mxi_transporter t
		INNER JOIN EQ_Extract..BiennialReportSourceData src ON 
		t.ew_doc = src.enviroware_manifest_document
		and t.ew_doc_line = src.enviroware_manifest_document_line
		and src.biennial_id = @biennial_id

/* update transporter info for items with new epa ids */
	UPDATE EQ_Extract..BiennialReportSourceData SET 
	transporter_epa_id = 'INR000127621',
	transporter_name = 'Advanced Waste Services',
	transporter_addr1 = '5625 Old Porter Rd.',
	transporter_addr2 = '',
	transporter_city = 'Portage',
	transporter_state = 'IN',
	transporter_zip_code = '46368'
	where transporter_name = 'Advanced Waste Services'
	and biennial_id = @biennial_id
	and enviroware_manifest_document = 'D30773'
	and enviroware_manifest_document_line = 1


declare @valley_city table (
	ew_doc varchar(20),
	ew_doc_line int
)

INSERT INTO @valley_city VALUES  ('D29299','1')
INSERT INTO @valley_city VALUES  ('D29456','1')
INSERT INTO @valley_city VALUES  ('D29914','1')
INSERT INTO @valley_city VALUES  ('D30406','1')
INSERT INTO @valley_city VALUES  ('D31155','1')
INSERT INTO @valley_city VALUES  ('D31251','1')
INSERT INTO @valley_city VALUES  ('D32309','1')
INSERT INTO @valley_city VALUES  ('D32570','1')
INSERT INTO @valley_city VALUES  ('D33793','1')
INSERT INTO @valley_city VALUES  ('D33795','1')
INSERT INTO @valley_city VALUES  ('D34400','1')
INSERT INTO @valley_city VALUES  ('D29776','1')
INSERT INTO @valley_city VALUES  ('D30138','1')
INSERT INTO @valley_city VALUES  ('D32485','1')
INSERT INTO @valley_city VALUES  ('D32641','1')
INSERT INTO @valley_city VALUES  ('D33192','1')
INSERT INTO @valley_city VALUES  ('D33518','1')
INSERT INTO @valley_city VALUES  ('D34339','1')
INSERT INTO @valley_city VALUES  ('D29844','1')
INSERT INTO @valley_city VALUES  ('D30467','1')
INSERT INTO @valley_city VALUES  ('D30520','1')
INSERT INTO @valley_city VALUES  ('D30876','1')
INSERT INTO @valley_city VALUES  ('D31047','1')
INSERT INTO @valley_city VALUES  ('D31994','1')
INSERT INTO @valley_city VALUES  ('D32172','1')
INSERT INTO @valley_city VALUES  ('D34443','1')
INSERT INTO @valley_city VALUES  ('D34762','1')
INSERT INTO @valley_city VALUES  ('D29010','1')
INSERT INTO @valley_city VALUES  ('D29458','1')
INSERT INTO @valley_city VALUES  ('D30024','1')
INSERT INTO @valley_city VALUES  ('D30144','1')
INSERT INTO @valley_city VALUES  ('D31443','1')
INSERT INTO @valley_city VALUES  ('D33847','1')


UPDATE EQ_Extract..BiennialReportSourceData SET 
	transporter_epa_id = 'MID981956063',
	transporter_name = 'Valley City Environmental Services',
	transporter_addr1 = '1040 Market Street',
	transporter_addr2 = '',
	transporter_city = 'Grand Rapids',
	transporter_state = 'MI',
	transporter_zip_code = '49501'
FROM EQ_Extract..BiennialReportSourceData src
	INNER JOIN @valley_city vc ON src.enviroware_manifest_document = vc.ew_doc
		and src.enviroware_manifest_document_line = vc.ew_doc_line
		and src.biennial_id = @biennial_id	
		

declare @tbl table (
	ew_doc varchar(20),
	ew_doc_id int,
	transporter_epa_id varchar(20)
)

INSERT INTO @tbl VALUES  ('D33391','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D32919','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D32990','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D31387','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D31336','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D31336','2','PAD980707442')
INSERT INTO @tbl VALUES  ('D31336','3','PAD980707442')
INSERT INTO @tbl VALUES  ('D31336','4','PAD980707442')
INSERT INTO @tbl VALUES  ('D31336','5','PAD980707442')
INSERT INTO @tbl VALUES  ('D31336','6','PAD980707442')
INSERT INTO @tbl VALUES  ('D34549','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33852','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D31520','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33863','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D30448','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D30447','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33943','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33944','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33616','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33623','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D33392','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D31952','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D32814','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D32826','1','PAD980707442')
INSERT INTO @tbl VALUES  ('D30372','1','OKD981588791')
INSERT INTO @tbl VALUES  ('D29798','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D31030','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D32840','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D33786','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D34192','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D30440','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D34881','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D32044','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D30585','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D30868','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D31039','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D30069','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D29949','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D29961','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D32247','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D31659','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D30015','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D30249','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D33824','1','PAD013826847')
INSERT INTO @tbl VALUES  ('D33788','1','INR000124370')
INSERT INTO @tbl VALUES  ('D33397','1','INR000124370')
INSERT INTO @tbl VALUES  ('D32549','1','INR000124370')
INSERT INTO @tbl VALUES  ('D32229','1','INR000124370')
INSERT INTO @tbl VALUES  ('D32993','1','INR000124370')
INSERT INTO @tbl VALUES  ('D34660','1','INR000124370')
INSERT INTO @tbl VALUES  ('D34705','1','INR000124370')
INSERT INTO @tbl VALUES  ('D29124','1','INR000124370')
INSERT INTO @tbl VALUES  ('D29179','1','INR000124370')
INSERT INTO @tbl VALUES  ('D29389','1','INR000124370')
INSERT INTO @tbl VALUES  ('D34070','1','INR000124370')
INSERT INTO @tbl VALUES  ('D34374','1','INR000124370')
INSERT INTO @tbl VALUES  ('D33549','1','INR000124370')
INSERT INTO @tbl VALUES  ('D30423','1','INR000124370')
INSERT INTO @tbl VALUES  ('D30664','1','INR000124370')
INSERT INTO @tbl VALUES  ('D29596','1','INR000124370')
INSERT INTO @tbl VALUES  ('D29835','1','INR000124370')
INSERT INTO @tbl VALUES  ('D30016','1','INR000124370')
INSERT INTO @tbl VALUES  ('D32693','1','INR000124370')
INSERT INTO @tbl VALUES  ('D33252','1','INR000124370')
INSERT INTO @tbl VALUES  ('D32095','1','INR000124370')
INSERT INTO @tbl VALUES  ('D31070','1','INR000124370')
INSERT INTO @tbl VALUES  ('D33108','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D31796','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D31257','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D33011','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29459','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29827','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29842','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D30022','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D30023','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29722','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D30017','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D34330','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D33029','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29307','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D32711','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D30437','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29256','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29169','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29009','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29721','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D29733','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D32701','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D33248','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D34280','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D32310','1','OHR000102053')
INSERT INTO @tbl VALUES  ('D33668','1','OHR000102053')	
INSERT INTO @tbl VALUES  ('D32918','1','OHD981000557')	

	UPDATE EQ_Extract..BiennialReportSourceData SET 
	transporter_epa_id = tbl.transporter_epa_id,
	transporter_name = trans.transporter_name,
	transporter_addr1 = trans.transporter_addr1,
	transporter_addr2 = trans.transporter_addr2,
	transporter_city = trans.transporter_city,
	transporter_state = trans.transporter_state,
	transporter_zip_code = trans.transporter_zip_code
FROM EQ_Extract..BiennialReportSourceData src
	INNER JOIN @tbl tbl ON src.enviroware_manifest_document = tbl.ew_doc
	and src.enviroware_manifest_document_line = tbl.ew_doc_id
	INNER JOIN @tbl_transporters trans ON trans.transporter_EPA_ID = tbl.transporter_epa_id
	where src.biennial_id = @biennial_id

--SELECT * FROM EQ_Extract..BiennialReportSourceData src
--where src.biennial_id = @biennial_id
--and src.enviroware_manifest_document = 'D33668'
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_overlay_manual] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_overlay_manual] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_report_source_overlay_manual] TO [EQAI]
    AS [dbo];

