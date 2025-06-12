


create procedure sp_nameparts (@namestring varchar(60),
                               @name_prefix varchar(10) out,
                               @first_name varchar(20) out,
                               @middle_name varchar(20) out,
                               @last_name varchar(20) out,
                               @name_suffix varchar(20) out )

as 


/***************************************************************************************
This proecedure does not return anything.  You have to pass in parameters that are assigned
by the procedure.

06/06/06	RG created

Loads on any DB where required refers to no tables
Test Cmd Line: 
declare @prefix varchar(10),
        @first varchar(20),
        @mid varchar(20),
	@last varchar(20),
	@suffix varchar(20)

exec sp_nameparts @namestring = 'Jim Restock x 20',
                  @name_prefix = @prefix out,
                  @first_name = @first out,
                  @middle_name = @mid out,
                  @last_name = @last out,
                  @name_suffix = @suffix out

select @prefix as 'prefix',@first as 'first',@mid as 'mid',@last as 'last',@suffix as 'suffix'
 
****************************************************************************************/

declare @length int,
        @pos int,
	@pos2 int,
        @name_part_1 varchar(20),
	@name_part_2 varchar(20),
	@name_part_3 varchar(20),
	@name_part_4 varchar(20),
	@name_part_5 varchar(20),
      	@name_part_6 varchar(20),
	@name_part_7 varchar(20),
	@name_part_8 varchar(20),
	@name_part_9 varchar(20),
	@name_part_10 varchar(20),
        @part_1 bit,
	@part_2 bit,
	@part_3 bit,
	@part_4 bit,
	@part_5 bit,
	@part_6 bit,
	@part_7 bit,
	@part_8 bit,
	@part_9 bit,
	@part_10 bit,
        @name_suffix_temp varchar(255),
        @last_name_temp varchar(255)

-- initialize

select @part_1 = 0, 
	@part_2 = 0,
	@part_3 = 0,
	@part_4 = 0,
	@part_5 = 0,
	@part_6 = 0, 
	@part_7 = 0,
	@part_8 = 0,
	@part_9 = 0,
	@part_10 = 0

-- clean namestring of bad data

if @namestring is null
begin
     return
end

--print 'passed nul test'

-- space on end
select @namestring = rtrim(@namestring)

-- preceding spaces
select @namestring = ltrim(@namestring)

-- remove period at end 

select @name_part_1 = right(@namestring,1)

if @name_part_1 = '.' or @name_part_1 = ','
begin
	select @namestring = left(@namestring,(len(@namestring)- 1))
end

-- convert period to space for part parsing

select @namestring = replace(@namestring,'.','')

if charindex(', ',@namestring) > 0
begin
	select @namestring = replace(@namestring,',','')
end 
else
begin
	select @namestring = replace(@namestring,',',' ')
end

-- anded anmes bob & Jimmy smith

select @pos = charindex('&',@namestring)
if @pos > 0  
begin
	select @namestring = replace(@namestring,' & ','-')
	select @namestring = replace(@namestring,'&','-')
end

-- get rid of extensions

select @pos = charindex(' ext',@namestring)
if @pos > 0 
begin
	select @namestring = left(@namestring,@pos - 2)
end

select @pos = charindex(' x ',@namestring)
if @pos > 0 
begin
	select @namestring = left(@namestring,@pos - 2)
end

select @pos = charindex(' x. ',@namestring)
if @pos > 0 
begin
	select @namestring = left(@namestring,@pos - 2)
end


-- dual names

select @pos = charindex('/',@namestring)
if @pos > 0 
begin
	select @namestring = left(@namestring,@pos - 1)
end

-- remove the stuff in parens
select @pos = charindex('(',@namestring),
       @length = len(@namestring)
if @pos > 0 
begin
        select @pos2 = charindex(')',@namestring)
	if @pos2 > 0 and @pos2 < @length
	  begin
		select @namestring = left(@namestring,@pos - 1) + right(@namestring, (@length - @pos2) )
          end
	else if @pos2 = len(@namestring)
	  begin
		select @namestring = left(@namestring,@pos - 1) 
          end
	else 
	  begin
		select @namestring =  replace(@namestring,'(', '')
	  end
end

-- remove comments
select @pos = charindex(' - ',@namestring)
if @pos > 0 
begin
	select @namestring = left(@namestring,@pos - 1) 
end

select @namestring = replace(@namestring, '  ', ' ')





--print 'trimmed left/right value=' + @namestring

-- get the prefix
select @length = len(@namestring)

--print 'passed length test ' + convert(varchar(10),@length)

-- afte fixing trim again
select @namestring = rtrim(@namestring)
select @namestring = ltrim(@namestring)

select @pos = charindex(' ',@namestring)


--print 'parsing part 1 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_1 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
        select @part_1 = 1
end
else
begin
	select @name_part_1 = @namestring
	select @part_1 = 1
	goto parse_end
end



-- part 2

select @pos = charindex(' ',@namestring)

--print 'parsing part 2 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_2 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_2 = 1
end
else
begin
	select @name_part_2 = @namestring
	select @part_2 = 1
	goto parse_end
end

-- part 3

select @pos = charindex(' ',@namestring)
--print 'parsing part 3 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_3 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_3 = 1
end
else
begin
	select @name_part_3 = @namestring
	select @part_3 = 1
	goto parse_end
end

-- part 4

select @pos = charindex(' ',@namestring)
--print 'parsing part 4 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_4 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_4 = 1
end
else
begin
	select @name_part_4 = @namestring
	select @part_4 = 1
	goto parse_end
end

-- part 5

select @pos = charindex(' ',@namestring)
--print 'parsing part 5 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_5 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_5 = 1
end
else
begin
	select @name_part_5 = @namestring
	select @part_5 = 1
	goto parse_end
end


-- part 6

select @pos = charindex(' ',@namestring)
--print 'parsing part 6 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_6 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_6 = 1
end
else
begin
	select @name_part_6 = @namestring
	select @part_6 = 1
	goto parse_end
end


-- part 77

select @pos = charindex(' ',@namestring)
--print 'parsing part 7 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_7 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_7 = 1
end
else
begin
	select @name_part_7 = @namestring
	select @part_7 = 1
	goto parse_end
end


-- part 8

select @pos = charindex(' ',@namestring)
--print 'parsing part 8 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_8 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_8 = 1
end
else
begin
	select @name_part_8 = @namestring
	select @part_8 = 1
	goto parse_end
end


-- part 9

select @pos = charindex(' ',@namestring)
--print 'parsing part 9 pos = ' + convert(varchar(5),@pos)

if @pos > 0 
begin
	select @name_part_9 = left(@namestring, @pos -1)
        select @namestring = right(@namestring,(len(@namestring) - @pos))
	select @part_9 = 1
end
else
begin
	select @name_part_9 = @namestring
	select @part_9 = 1
	goto parse_end
end



-- part 10

select @name_part_10 = @namestring
select @part_10 = 1

parse_end:

-- we have all the parts pased off so test for the values

--print 'part 1  = ' + isnull(@name_part_1,'') + ',' +
--      'part 2  = ' + isnull(@name_part_2,'') + ',' +
--	'part 3  = ' + isnull(@name_part_3,'') + ',' +
--	'part 4  = ' + isnull(@name_part_4,'') + ',' +
--	'part 5  = ' + isnull(@name_part_5,'') 

-- start at teh back and go forward

if exists ( select 1 where upper(@name_part_10) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    select @name_suffix = @name_part_10
	end
if exists ( select 1 where upper(@name_part_9) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_9 
			end
		else
			begin
				select @name_suffix = @name_part_9 + ',' + @name_suffix
			end
	end
if exists ( select 1 where upper(@name_part_8) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_8 
			end
		else
			begin
				select @name_suffix = @name_part_8 + ',' + @name_suffix
			end
	end
	
if exists ( select 1 where upper(@name_part_7) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_7 
			end
		else
			begin
				select @name_suffix = @name_part_7 + ',' + @name_suffix
			end
	end
-- part 6 is is the ealiest a last name could be
if exists ( select 1 where upper(@name_part_6) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_6 
			end
		else
			begin
				select @name_suffix = @name_part_6 + ',' + @name_suffix
			end
	end
else
	begin
		select @last_name_temp = @name_part_6
	end
	
-- part 5 is is the ealiest a last name could be
if exists ( select 1 where upper(@name_part_5) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_5 
			end
		else
			begin
				select @name_suffix = @name_part_5 + ',' + @name_suffix
			end
	end
else if @last_name_temp is null
	begin
		select @last_name_temp = @name_part_5
	end
else
	begin
		select @last_name_temp = @name_part_5 + ' ' + @last_name_temp
	end

-- part 4 is is the ealiest a last name could be
if exists ( select 1 where upper(@name_part_4) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_4 
			end
		else
			begin
				select @name_suffix = @name_part_4 + ',' + @name_suffix
			end
	end
else if @last_name_temp is null
	begin
		select @last_name_temp = @name_part_4
	end
else
	begin
		select @last_name_temp = @name_part_4 + ' ' + @last_name_temp
	end
		

-- part 3 is is the ealiest a middle name could be
if exists ( select 1 where upper(@name_part_3) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_3 
			end
		else
			begin
				select @name_suffix = @name_part_3 + ',' + @name_suffix
			end
	end
else if @last_name_temp is null
	begin
		select @last_name_temp = @name_part_3
	end
else if exists ( select 1 where upper(@name_part_3) in ( 'VON', 'DU', 'ST','LE', 'VAN', 'DE', 'DER' ))
	begin
		select @last_name_temp = @name_part_3 + ' ' + @last_name_temp
	end
else
	begin
		select @middle_name = @name_part_3
	end


-- part 2 is is the ealiest a middle name could be
if exists ( select 1 where upper(@name_part_2) in ( 'JR', 'SR', 'II', 'III', 'IV', 'V', 'PE', 'INC', 'CPG', 'CIH', 'BSC', 'CHMM', 'REHS', 'PHD' ))
	begin
	    if @name_suffix is null
			begin
				select @name_suffix = @name_part_2 
			end
		else
			begin
				select @name_suffix = @name_part_2 + ',' + @name_suffix
			end
	end
else if @last_name_temp is null
	begin
		select @last_name_temp = @name_part_2
	end
else if exists ( select 1 where upper(@name_part_2) in ( 'VON', 'DU', 'ST','LE', 'VAN', 'DE' ))
	begin
		select @last_name_temp = @name_part_2 + ' ' + @last_name_temp
	end
else if exists (select 1 where upper(@name_part_1) in ( 'MR', 'MRS', 'MS', 'DR', 'ATTNY', 'REV', 'PROF', 'HON', 'GOV', 'SEN'))
	begin
		select @first_name = @name_part_2
	end
else
	begin
		select @middle_name = @name_part_2
	end
	

-- part 1 is the ealiest that the first name can be
if exists ( select 1 where upper(@name_part_1) in ( 'MR', 'MRS', 'MS', 'DR', 'ATTNY', 'REV', 'PROF', 'HON', 'GOV', 'SEN')) 
	begin
	    select @name_prefix = left(@name_part_1,10)
	end
else if @last_name_temp is null 
	begin
		select @last_name_temp = @name_part_1 
	end
else
	begin
		select @first_name = @name_part_1
	end
		


standardize:

select @name_suffix = left(@name_suffix_temp,20)
select @last_name = left(@last_name_temp,20)


return 
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_nameparts] TO [EQAI]
    AS [dbo];

