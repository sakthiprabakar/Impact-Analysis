CREATE PROCEDURE [dbo].[sp_pcb_insert_update]
       @Data XML,			
	   @form_id int,
	   @revision_id int
AS


/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 26th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_pcb_insert_update]


	Procedure to insert update PCB supplementry forms

inputs 
	
	@Data
	@form_id
	@revision_id


Samples:
 EXEC [sp_pcb_insert_update] @Data,@formId,@revisionId
 EXEC [sp_pcb_insert_update] '<PCB>
	<IsEdited>PB</IsEdited>
   <pcbContentration>T</pcbContentration>
   <pcb_article_decontaminated>T</pcb_article_decontaminated>
   <pcb_article_for_TSCA_landfill>T</pcb_article_for_TSCA_landfill>
   <pcb_concentration_0_9>T</pcb_concentration_0_9>
   <pcb_concentration_10_49 />
   <pcb_concentration_500 />
   <pcb_concentration_50_499 />
   <pcb_manufacturer>T</pcb_manufacturer>
   <pcb_regulated_for_disposal_under_TSCA>T</pcb_regulated_for_disposal_under_TSCA>
   <pcb_source_contamination_gr_50>T</pcb_source_contamination_gr_50>
   <processd_into_nonlqd_prior_pcb>50</processd_into_nonlqd_prior_pcb>
   <processed_into_non_liquid>T</processed_into_non_liquid>
</PCB>',428416,1

***********************************************************************/

  print 'Insert Update PCB'

    BEGIN
       UPDATE  FormWCR 
       SET        
              pcb_concentration_0_9 = p.v.value('pcb_concentration_0_9[1]','char(1)'),
              pcb_concentration_10_49 = p.v.value('pcb_concentration_10_49[1]','char(1)'),
              pcb_concentration_50_499 = p.v.value('pcb_concentration_50_499[1]','char(1)'),
			  pcb_concentration_500 = p.v.value('pcb_concentration_500[1]','char(1)'),
              pcb_source_concentration_gr_50 = p.v.value('pcb_source_concentration_gr_50[1]','char(1)'),
              pcb_regulated_for_disposal_under_TSCA = p.v.value('pcb_regulated_for_disposal_under_TSCA[1]','char(1)'),
              processed_into_non_liquid = p.v.value('processed_into_non_liquid[1]','char(1)'),
			  processd_into_nonlqd_prior_pcb = p.v.value('processd_into_nonlqd_prior_pcb[1]','VARCHAR(10)'),
			  pcb_manufacturer = p.v.value('pcb_manufacturer[1]','char(1)'),
			  pcb_article_for_TSCA_landfill = p.v.value('pcb_article_for_TSCA_landfill[1]','char(1)'),
			  pcb_article_decontaminated = p.v.value('pcb_article_decontaminated[1]','char(1)')
        FROM

        @Data.nodes('PCB')p(v) WHERE form_id = @form_id and revision_id =  @revision_id

       END

--	   exec sp_FormWCR_insert_update_pcb '<PCB>
--	<IsEdited>PB</IsEdited>
--   <pcbContentration>T</pcbContentration>
--   <pcb_article_decontaminated>T</pcb_article_decontaminated>
--   <pcb_article_for_TSCA_landfill>T</pcb_article_for_TSCA_landfill>
--   <pcb_concentration_0_9>T</pcb_concentration_0_9>
--   <pcb_concentration_10_49 />
--   <pcb_concentration_500 />
--   <pcb_concentration_50_499 />
--   <pcb_manufacturer>T</pcb_manufacturer>
--   <pcb_regulated_for_disposal_under_TSCA>T</pcb_regulated_for_disposal_under_TSCA>
--   <pcb_source_contamination_gr_50>T</pcb_source_contamination_gr_50>
--   <processd_into_nonlqd_prior_pcb>50</processd_into_nonlqd_prior_pcb>
--   <processed_into_non_liquid>T</processed_into_non_liquid>
--</PCB>',428416,1

	   -- Orgininal
--	   EXEC sp_FormWCR_insert_update_pcb '<PCB>
--<pcb_article_decontaminated>T</pcb_article_decontaminated>
--<pcb_article_for_TSCA_landfill>F</pcb_article_for_TSCA_landfill>
--<pcb_concentration_0_9>T</pcb_concentration_0_9>
--<pcb_concentration_10_49>T</pcb_concentration_10_49>
--<pcb_concentration_500>T</pcb_concentration_500>
--<pcb_concentration_50_499>T</pcb_concentration_50_499>
--<pcb_manufacturer>T</pcb_manufacturer>
--<pcb_regulated_for_disposal_under_TSCA>T</pcb_regulated_for_disposal_under_TSCA>
--<processd_into_nonlqd_prior_pcb>F</processd_into_nonlqd_prior_pcb>
--<processed_into_non_liquid>F</processed_into_non_liquid>
--</PCB>', 427534 , 1

--SELECT pcb_concentration_0_9,
--pcb_concentration_10_49,
--pcb_concentration_50_499,
--pcb_concentration_500,
--pcb_regulated_for_disposal_under_TSCA,
--processed_into_non_liquid,
--processd_into_nonlqd_prior_pcb,
--pcb_manufacturer,
--pcb_article_for_TSCA_landfill,
--pcb_article_decontaminated FROM FORMWCR WHERE form_id = 428416 and revision_id = 1
GO
	GRANT EXEC ON [dbo].[sp_pcb_insert_update] TO COR_USER;
GO