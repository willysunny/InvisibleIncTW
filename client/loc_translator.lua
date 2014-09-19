-- Integrated from DoNotStarve r83589 11/12/2013.
--
-- Revised version by WrathOf using msgctxt field for po/t file
-- msgctxt is set to the "path" in the table structure which is guaranteed unique
-- versus the string values (msgid) which are not.
--
-- Added a file format field to the po file so can support old format po files
-- and new format po files.  The new format ones will contain all entries from
-- the strings table which the old format cannot support.
--

include( "class" )
local cdefs = include( "client_defs" )

---------------------------------------------------------------------------
--

local Translator = class()

function Translator:init() 
	self.languages = {}
end


function Translator:LoadPOFile(fname,lang)
	log:write( cdefs.LOG_LOC, "Translator:LoadPOFile - loading file: "..fname)

	local file = io.open(fname)
	if not file then
		log:write( "Translator:LoadPOFile - Specified language file '%s' not found.", fname )
		return false
	end

	local strings = {}
	local current_id = false
	local current_str = ""
	local msgstr_flag = false

	for line in file:lines() do

		--Skip lines until find an id using new format
		if not current_id then
			local sidx, eidx, c1, c2 = string.find(line, "^msgctxt(%s*)\"(%S*)\"")
			if c2 then
				current_id = c2
				log:write( cdefs.LOG_LOC, "\tFound new format id: "..tostring(c2) )
			end

		--Gather up parts of translated text (since POedit breaks it up into 80 char strings)
		elseif msgstr_flag then
			local sidx, eidx, c1, c2 = string.find(line, "^(%s*)\"(.*)\"")
			--Found blank line or next entry (assumes blank line after each entry or at least a #. line)
			if not c2 then
				--Store translated text if provided
				if current_str ~= "" then
					strings[current_id] = self:ConvertEscapeCharactersToRaw(current_str)
					log:write( cdefs.LOG_LOC, "\tFound id: "..current_id.."\tFound str: "..current_str )
				end
				msgstr_flag = false
				current_str = ""
				current_id = false
			--Combine text with previously gathered text
			else
				current_str = current_str..c2
			end
		--Have id, so look for translated text
		elseif current_id then
			local sidx, eidx, c1, c2 = string.find(line, "^msgstr(%s*)\"(.*)\"")
			--Found multi-line entry so flag to gather it up
			if c2 and c2 == "" then
				msgstr_flag = true
			--Found translated text so store it
			elseif c2 then
				strings[current_id] = self:ConvertEscapeCharactersToRaw(c2)
				log:write( cdefs.LOG_LOC, "\tFound id: %s\t\t\t%s", tostring(current_id), tostring(c2))
				current_id = false
			end
		else
			--skip line
		end
	end

	file:close()

	self.languages[lang] = strings

	log:write( cdefs.LOG_LOC, "Translator:LoadPOFile Done!" )
	return true
end


--
-- Renamed since more generic now
--
function Translator:ConvertEscapeCharactersToString(str)
	local newstr = string.gsub(str, "\n", "\\n")
	newstr = string.gsub(newstr, "\r", "\\r")
	newstr = string.gsub(newstr, "\"", "\\\"")
	
	return newstr
end

function Translator:ConvertEscapeCharactersToRaw(str)
	local newstr = string.gsub(str, "\\n", "\n")
	newstr = string.gsub(newstr, "\\r", "\r")
	newstr = string.gsub(newstr, "\\\"", "\"")
	
	return newstr
end


--
-- New version
--
function Translator:GetTranslatedString(strid, lang)
	assert( lang and self.languages[lang] )

	log:write( cdefs.LOG_LOC, "\tReqested id: '%s' => '%s'", strid, tostring(self.languages[lang][strid]) )

	if self.languages[lang][strid] then
		return self:ConvertEscapeCharactersToRaw(self.languages[lang][strid])
	else
		return nil
	end
end

--Recursive function to process table structure
function Translator:DoTranslateStringTable( base, tbl, lang )
	
	for k,v in pairs(tbl) do
		local path = base.."."..k
		if type(v) == "table" then
			self:DoTranslateStringTable( path, v, lang )
		else
			local str = self:GetTranslatedString(path, lang)
			if str and str ~= "" then
				tbl[k] = str
			else
				tbl[k] = path -- MISSING
			end
		end
	end
end

--called by strings.lua
function translateStringTable( root, tbl, lang )
	if not lang then
		return -- Use the default locale; whatever already exists in the strings table 'tbl'
	end

	local translator = Translator()
	if translator:LoadPOFile( string.format( "data/locales/%s.po", lang ), lang ) then
		translator:DoTranslateStringTable( root, tbl, lang )
	end
end


return
{
	translateStringTable = translateStringTable
}

