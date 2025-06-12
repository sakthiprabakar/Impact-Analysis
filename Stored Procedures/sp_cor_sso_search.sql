drop proc if exists sp_cor_sso_search
go

create proc sp_cor_sso_search (
	@issuer		varchar(max) = '',	/* Issuer URL - used to identify our customer */
	@NameID		varchar(max) = '',	/* Partner SSO's identifier for this user. Could be Name, Email, Phone, UID, etc */
	@Location	varchar(max) = ''	/* Partner SSO's identifier for a specific location/store. May be blank/null */
)
as
/* ************************************************************************	
sp_cor_sso_search

	Used to find a match in COR2 user data for the identity confirmed via partner SSO

Returns
	Normal return: 
		contact_id int
		web_userid varchar(100)
		is_default_contact char(1)
		generator_id int
		
	If a match on @issuer, @NameID and (optional) @Location is found, the 3 fields above are returned.
	
	Error Cases:
		'@Issuer (SAML Issuer) is required.'
			@Issuer input was not provided, is required.

		'@NameID (SAML NameID) is required.'
			@NameID input was not provided, is required.
			
		'No matches found for Issuer.'
			@Issuer input was not matched in the CORSSO table
			search logic is: @Issuer like '%' + CORSSO.issuer_match + '%' 
			
		'Multiple customer matches found for Issuer.'
			More than 1 customer_id matched the @Issuer input.
			Cannot proceed with multiple matches.
			search logic is: @Issuer like '%' + CORSSO.issuer_match + '%' 
			
		'Multiple contact matches found for NameID.'
			A single @Issuer match was found, but @NameID matched multiple possible Contacts for that Customer, for COR login
			Cannot proceed with multiple matches.
			search logic is: @NameId = Contact.web_userid or @NameId = Contact.email
			
		'No contact matches found for NameID, and No Default.'
			A single @Issuer match was found, but @NameID did not match any possible Contacts for that Customer, for COR login
			AND the CORSSO record that matched @Issuer does not specify a default contact_id for unmatched @NameID logins.
			Cannot proceed without a COR login.
			
		'Generic login without filter match is not allowed for this customer.'
			A single @Issuer match was found, and @NameID did not match any possible Contacts for that Customer, for COR Login
			BUT the default contact_id for unmatched @NameID logins is being used,
			HOWEVER, the @Location input did not match a Generator for the default user
			(search logic is @Location = Generator.site_code or @Location = Generator.generator_market_code)
			AND the CORSSO record that matched @Issuer does not allow logins without a Location match to a single generator
	

History
	2021-06-24	JPB	Created

Samples:

	sp_cor_sso_search 
		@issuer = 'https://devsaml.homedepot.com', 
		@nameid = 'QAT9900', 
		@location = '9100'
			-- returns a default 'thehomedepot' user
			--- but 9100 has no match in generators for Home Depot, so no generator_id to filter on.

	sp_cor_sso_search 
		@issuer = 'https://devsaml.homedepot.com', 
		@nameid = 'QAT9900', 
		@location = '1127'
			-- returns a default 'thehomedepot' user
			--- but 1127 matches a generators for Home Depot, that generator_id is returned to be the user's default filter.

	sp_cor_sso_search 
		@issuer = 'https://devsaml.homedepot.com', 
		@nameid = 'QAT9900', 
		@location = ''
			-- returns a default 'thehomedepot' user
			--- no location provided, so no generator_id output.

	sp_cor_sso_search 
		@issuer = 'https://fake.costco.com', 
		@nameid = 'ssaknit', 
		@location = ''

-- update CORSSO set allow_login_without_filter = 'N' where customer_id = 602502
-- update CORSSO set allow_login_without_filter = 'Y' where customer_id = 602502 -- default
	
************************************************************************ */

-- avoid query plan caching/handle inputs
declare
	@i_issuer		varchar(max) = isnull(@issuer,''),	/* Issuer URL - used to identify our customer */
	@i_NameID		varchar(max) = isnull(@nameid, ''),	/* Partner SSO's identifier for this user. Could be Name, Email, Phone, UID, etc */
	@i_Location		varchar(max) = isnull(@location, ''),	/* Partner SSO's identifier for a specific location/store. May be blank/null */
	@customer_id	int, /* The customer ID we'll identify as matching this request */
	@default_contact_id		int, /* The default contact ID for this customer (assuming a match is found) */
	@allow_login_without_filter char(1), /* 'Y'es - a login without a matching store will see ALL data (no filter) or 'N'o, do not allow a login if there's no store match */
	@i_contact_id		int, /* The contact ID we'll identify as matching this request */
	@i_web_userid		varchar(100), /* The web_userid of the found contact_id */
	@generator_id	varchar(max),	 /* The CSV generator IDs we _may_ identify as matching this @location for this user & customer */
	@sp_status		varchar(100) = 'OK',
	@contact_id		int, /* The contact ID we'll identify as matching this request */
	@web_userid		varchar(100), /* The web_userid of the found contact_id */
	@is_default_contact char(1)  /* Is the contact info returned the default for the customer? */

-- validate inputs	
if @i_issuer = '' 
begin 
	set @sp_status = '@Issuer (SAML Issuer) is required.'
	goto output
end

if @i_NameID = '' 
begin 
	set @sp_status = '@NameID (SAML NameID) is required.'
	goto output
end

-- validate customer match counts
if (
	select count(customer_id)
	FROM corsso (nolock)
	WHERE @i_issuer like '%' + issuer_match + '%' 
	and status = 'A'
) = 0 begin
	set @sp_status = 'No matches found for Issuer.'
	goto output
end

if (
	select count(distinct customer_id)
	FROM corsso (nolock)
	WHERE @i_issuer like '%' + issuer_match + '%' 
	and status = 'A'
) > 1 begin
	set @sp_status = 'Multiple customer matches found for Issuer.'
	goto output
end

-- capture customer_id & default contact_id

SELECT top 1 @customer_id = customer_id, 
	@default_contact_id = default_contact_id, 
	@allow_login_without_filter = isnull(allow_login_without_filter, 'Y')
FROM corsso (nolock)
WHERE @i_issuer like '%' + issuer_match + '%' 
and status = 'A'

-- validate contact match counts (0 or 1 is ok, 2+ is bad. 1 = match.  0 = default.)
if (
	select count(distinct c.contact_id)
	from contact c (nolock)
	join ContactCORCustomerBucket b (nolock)
		on c.contact_id = b.contact_id
	WHERE b.customer_id = @customer_id
	and (
		@i_NameId = c.web_userid
		or
		@i_NameId = c.email
	)
	and c.web_userid <> 'all_customers'
) > 1 begin
	set @sp_status = 'Multiple contact matches found for NameID.'
	goto output
	end

-- capture specific contact_id, if possible, require that it match either the customer, or a generator that belongs to the customer.
select @i_contact_id = c.contact_id
from contact c (nolock)
join ContactCORCustomerBucket b (nolock)
	on c.contact_id = b.contact_id
WHERE b.customer_id = @customer_id
and (
	@i_NameId = c.web_userid
	or
	@i_NameId = c.email
)

if @i_contact_id is null select @i_contact_id = @default_contact_id

if @i_contact_id is /* still */ null begin
	set @sp_status = 'No contact matches found for NameID, and No Default.'
	goto output
	end

-- Get the matching web_userid
select @i_web_userid = web_userid
from contact (nolock)
where contact_id = @i_contact_id

-- If we're still here, we have a @customer_id and a @i_contact_id, now just try and set a @location default if one was given
-- TODO: multiple generator matches would fail here. Fix it to return CSV generator_id values.
if @i_Location <> '' begin
	select @generator_id = substring(
	(select distinct 
		',' + convert(varchar(20),b.generator_id)
	from ContactCORGeneratorBucket b (nolock)
	join generator g (nolock)
		on b.generator_id = g.generator_id
	where b.contact_id = @i_contact_id
	and (
		g.site_code = @i_Location
		or
		g.generator_market_code = @i_Location -- Sometimes we store a generator's own version of their store # in this field
	)
	for xml path, TYPE).value('.[1]','nvarchar(max)'
	),2,20000)
end

if @i_contact_id = @default_contact_id and @allow_login_without_filter = 'N' and @generator_id is null begin
	set @sp_status = 'Generic login without filter match is not allowed for this customer.'
	goto output
	end


if @i_contact_id = @default_contact_id set @is_default_contact = 'T'
else set @is_default_contact = 'F'

if left(@sp_status, 2) = 'OK' 
	select @contact_id = @i_contact_id
	, @web_userid = @i_web_userid

output:

select 
	@contact_id contact_id
	, @web_userid web_userid
	, @is_default_contact is_default_contact
	, @generator_id generator_id
	, @sp_status [status]

go

grant execute on sp_cor_sso_search to cor_user
go
grant execute on sp_cor_sso_search to eqai
go
grant execute on sp_cor_sso_search to eqweb
go


