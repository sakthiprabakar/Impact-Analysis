
drop proc if exists sp_emanifest_get_handler 
go

create proc sp_emanifest_get_handler (
	@source		varchar(20)	= null	/* Generator, Transporter, TSDF etc */
	,@source_id	varchar(20)	= null	/* generator_id	transporter_id	tsdf_code */
	,@source_id2	varchar(20)	= null	/* if needed.  Could be a company number, etc.*/
	,@source_id3	varchar(20)	= null	/* if needed.  EQAI only needs @source_id   */
) as 
/******************************************************************************************
Retrieve Handler info, standardized formatting & conversions of countries to EPA countries

2021-02-26 - Modified country handling to try sending Canadian data as-is

sp_emanifest_get_handler	'generator', '102392'
sp_emanifest_get_handler	'transporter', 'eqis'
sp_emanifest_get_handler	'tsdf', 'EQDET'

SELECT * FROM generator WHERE generator_country = 'CAN'
SELECT * FROM transporter WHERE transporter_country = 'CAN'

sp_emanifest_get_handler	'transporter', 'AESINC'

-- Ontario, CA
exec sp_emanifest_get_handler 'generator', '128854', '41', '0'
SELECT  * FROM    generator WHERE generator_id = 128854


SELECT * FROM country

******************************************************************************************/

-- Are we allowed to send fake canadian transporter info?
declare @fake_can_transporters int = 0, @fake_can_generators int = 0

if @source = 'generator' begin

	declare @gen_country varchar(10)
	select @gen_country = (
		select top 1 
		isnull(generator_country, 'USA') 
		from generator 
		where generator_id = convert(int, @source_id)
	)

	--if (@gen_country = 'USA' OR (@gen_country <> 'USA' AND @fake_can_generators = 0)) 
	if 1=1 -- Let's try sending CA data now
	begin

		select top 1
			case when isnull(g.generator_country, 'USA') = 'USA' then g.epa_id else
				case when left(isnull(g.epa_id, ''), 2) = 'FC' then g.epa_id else null end
			end	epaSiteId
			, generator_name	name

			, null as MailingAddress_streetNumber
			, gen_mail_addr1 as MailingAddress_address1
			, gen_mail_addr2 as MailingAddress_address2
			, gen_mail_city as MailingAddress_city
			, gen_mail_state as MailingAddress_state
			, gen_mail_zip_code as MailingAddress_zip
			, c.epa_code as MailingAddress_country
			
			, null as SiteAddress_streetNumber
			, generator_address_1 as SiteAddress_address1
			, generator_address_2 as SiteAddress_address2
			, generator_city as SiteAddress_city
			, generator_state as SiteAddress_state
			, generator_zip_code as SiteAddress_zip
			, c.epa_code as SiteAddress_country

			, case when isnull(generator_phone, '') <> '' then generator_phone 
				else
					coalesce(
						/* Primary contact */
						(select top 1 ltrim(rtrim(isnull(c.phone,''))) 
							from contactxref cxr join contact c on cxr.contact_id = c.contact_id
							where cxr.generator_id = g.generator_id and cxr.type = 'G' and cxr.status = 'A' and cxr.primary_contact = 'T'
							and isnull(c.phone, '') <> ''
						),
					
						/* Any contact */
						(select top 1 ltrim(rtrim(isnull(c.phone,''))) 
							from contactxref cxr join contact c on cxr.contact_id = c.contact_id
							where cxr.generator_id = g.generator_id and cxr.type = 'G' and cxr.status = 'A'
							and isnull(c.phone, '') <> ''
						)
						/* , other options?*/
					)
				end as contactPhone
			, COALESCE(nullif(ltrim(rtrim(isnull(g.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone) as emergencyPhone
			, emergency_phone_number as emergencyPhone
			
			from generator g
			left join Country c
				on g.generator_country = c.country_code
			left join ProfitCenter
				on ProfitCenter.company_id = @source_id2
				and ProfitCenter.profit_ctr_id = @source_id3
			where generator_id = convert(int, @source_id)
	end
	else
	begin -- fake non USA generator
	
		select top 1
			case when isnull(g.generator_country, 'USA') = 'USA' then g.epa_id else
				case when left(isnull(g.epa_id, ''), 2) = 'FC' then g.epa_id else null end
			end	epaSiteId
			, generator_name	name

			, null as MailingAddress_streetNumber
			, 'Not Required' as MailingAddress_address1
			, '' as MailingAddress_address2
			, 'Not Required' as MailingAddress_city
			, 'VA' as MailingAddress_state
			, '00000' as MailingAddress_zip
			, c.epa_code as MailingAddress_country
			
			, null as SiteAddress_streetNumber
			, 'Not Required' as SiteAddress_address1
			, '' as SiteAddress_address2
			, 'Not Required' as SiteAddress_city
			, 'VA' as SiteAddress_state
			, '00000' as SiteAddress_zip
			, c.epa_code as SiteAddress_country

			, case when isnull(generator_phone, '') <> '' then generator_phone 
				else
					/* coalesce( */
						(select top 1 ltrim(rtrim(isnull(c.phone,''))) 
							from contactxref cxr join contact c on cxr.contact_id = c.contact_id
							where cxr.generator_id = g.generator_id and cxr.type = 'G' and cxr.status = 'A'
							and isnull(c.phone, '') <> ''
						)
						/* , other options? ) */
				end as contactPhone
			, COALESCE(nullif(ltrim(rtrim(isnull(g.emergency_phone_number, ''))), ''), ProfitCenter.emergency_contact_phone) as emergencyPhone
			, emergency_phone_number as emergencyPhone
			
			from generator g
			left join Country c
				on g.generator_country = c.country_code
			left join ProfitCenter
				on ProfitCenter.company_id = @source_id2
				and ProfitCenter.profit_ctr_id = @source_id3
			where generator_id = convert(int, @source_id)
			
	end
end

if @source = 'transporter' begin

	declare @trans_country varchar(10)
	select @trans_country = (
		select top 1 
		isnull(transporter_country, 'USA') 
		from transporter t
		where transporter_code = @source_id
	)
	
	-- if (@trans_country = 'USA' OR (@trans_country <> 'USA' AND @fake_can_transporters = 0)) 
	if 1=1 -- Let's try sending CA data now
	begin

		select top 1
			case when isnull(transporter_country, 'USA') = 'USA' then transporter_EPA_ID else
				case when left(isnull(transporter_EPA_ID, ''), 2) = 'FC' then transporter_EPA_ID else null end
			end	epaSiteId
			, transporter_name	name

			, null as MailingAddress_streetNumber
			, transporter_addr1 as MailingAddress_address1
			, transporter_addr2 as MailingAddress_address2
			, transporter_city as MailingAddress_city
			, transporter_state as MailingAddress_state
			, transporter_zip_code as MailingAddress_zip
			, c.epa_code as MailingAddress_country
			
			, null as SiteAddress_streetNumber
			, transporter_addr1 as SiteAddress_address1
			, transporter_addr2 as SiteAddress_address2
			, transporter_city as SiteAddress_city
			, transporter_state as SiteAddress_state
			, transporter_zip_code as SiteAddress_zip
			, c.epa_code as SiteAddress_country

			, transporter_phone as contactPhone
			, transporter_contact_phone as emergencyPhone
			from transporter t
			left join Country c
				on t.transporter_country = c.country_code
			where transporter_code = @source_id
	end
	else
	begin
		select top 1
			case when isnull(transporter_country, 'USA') = 'USA' then transporter_EPA_ID else
				case when left(isnull(transporter_EPA_ID, ''), 2) = 'FC' then transporter_EPA_ID else null end
			end	epaSiteId
			, transporter_name	name

			, null as MailingAddress_streetNumber
			, 'Not Required' as MailingAddress_address1
			, '' as MailingAddress_address2
			, 'Not Required' as MailingAddress_city
			, 'VA' as MailingAddress_state
			, '00000' as MailingAddress_zip
			, c.epa_code as MailingAddress_country
			
			, null as SiteAddress_streetNumber
			, 'Not Required' as SiteAddress_address1
			, '' as SiteAddress_address2
			, 'Not Required' as SiteAddress_city
			, 'VA' as SiteAddress_state
			, '00000' as SiteAddress_zip
			, c.epa_code as SiteAddress_country

			, transporter_phone as contactPhone
			, transporter_contact_phone as emergencyPhone

			from transporter t
			left join Country c
				on t.transporter_country = c.country_code
			where transporter_code = @source_id
	end	

end

if @source = 'tsdf' begin

	select top 1
		case when isnull(t.TSDF_country_code, 'USA') = 'USA' then TSDF_EPA_ID else
			case when left(isnull(TSDF_EPA_ID, ''), 2) = 'FC' then TSDF_EPA_ID else null end
		end	epaSiteId
		, TSDF_name	name

		, null as MailingAddress_streetNumber
		, TSDF_addr1 as MailingAddress_address1
		, TSDF_addr2 as MailingAddress_address2
		, TSDF_city as MailingAddress_city
		, TSDF_state as MailingAddress_state
		, TSDF_zip_code as MailingAddress_zip
		, c.epa_code as MailingAddress_country
		
		, null as SiteAddress_streetNumber
		, TSDF_addr1 as SiteAddress_address1
		, TSDF_addr2 as SiteAddress_address2
		, TSDF_city as SiteAddress_city
		, TSDF_state as SiteAddress_state
		, TSDF_zip_code as SiteAddress_zip
		, c.epa_code as SiteAddress_country

		, tsdf_contact_phone as contactPhone
		, emergency_contact_phone as emergencyPhone
		from tsdf t
		left join Country c
			on t.TSDF_country_code = c.country_code
		where TSDF_code = @source_id

end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_get_handler] TO [ATHENA_SVC]
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_emanifest_get_handler] TO [EQAI]
    AS [dbo];


