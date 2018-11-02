local ustring = require("ustring")
local make_weak = require("fi_utilities").make_weak

local export = {}

-- local lang = require("Module:languages").getByCode("fi")

-- Functions that do the actual inflecting by creating the forms of a basic term.
local inflections = {}

-- The main entry point.
-- This is the only function that can be invoked from a template.
function export.show(frame)
	local infl_type = frame.args[1] or error("Inflection type has not been specified. Please pass parameter 1 to the module invocation")
	local args = frame:getParent().args
	
	if not inflections[infl_type] then
		error("Unknown inflection type '" .. infl_type .. "'")
	end
	
	local data = {forms = {}, title = nil, categories = {}}
	
	-- Generate the forms
	inflections[infl_type](args, data)
	
	-- Postprocess
	postprocess(args, data)
	
	if args["appendix"] then
		table.insert(data.categories, "fi-conj with appendix")
	end
	
	if args["noagent"] then
		table.insert(data.categories, "fi-conj with noagent")
	end
	
	if args["qual"] or
		args["q1sg"] or args["q2sg"] or args["q1pl"] or args["q2pl"] or args["q3p"] or args["qpass"] or
		args["q1sgp"] or args["q2sgp"] or args["q1plp"] or args["q2plp"] or args["q3pp"] or args["qpassp"] then
		table.insert(data.categories, "fi-conj with qual")
	end

    return data
	
	-- return make_table(data) .. m_utilities.format_categories(data.categories, lang)
end

-- Get parameters from the template, in standard order and numbering
local function get_params(args, num, invert_grades)
	local params = {}
	
	if num == 5 then
		params.base = args[1] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}"); if not params.base or params.base == "" then error("Parameter 1 (base stem) may not be empty.") end
		params.strong = args[2] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{2}}}"); if not params.strong then error("Parameter 2 (infinitive grade) may not be omitted.") end
		params.weak = args[3] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{3}}}"); if not params.weak then error("Parameter 3 (other grade) may not be omitted.") end
		params.final = args[4] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{4}}}"); if not params.final or params.final == "" then error("Parameter 4 (final letter(s)) may not be empty.") end
		params.a = args[5] or (mw.title.getCurrentTitle().nsText == "Template" and "a"); if params.a ~= "a" and params.a ~= "ä" then error("Parameter 5 must be \"a\" or \"ä\".") end
		
		if args[6] or args[7] then
			error("Parameters 6 and 7 are deprecated.")
		end
	elseif num == 4 then
		params.base = args[1] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}"); if not params.base or params.base == "" then error("Parameter 1 (base stem) may not be empty.") end
		params.strong = args[2] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{2}}}"); if not params.strong then error("Parameter 2 (infinitive grade) may not be omitted.") end
		params.weak = args[3] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{3}}}"); if not params.weak then error("Parameter 3 (other grade) may not be omitted.") end
		params.a = args[4] or (mw.title.getCurrentTitle().nsText == "Template" and "a"); if params.a ~= "a" and params.a ~= "ä" then error("Parameter 4 must be \"a\" or \"ä\".") end
		
		if args[5] or args[6] then
			error("Parameters 5 and 6 are deprecated.")
		end
	elseif num == 2 then
		params.base = args[1] or (mw.title.getCurrentTitle().nsText == "Template" and "{{{1}}}"); if not params.base or params.base == "" then error("Parameter 1 (base stem) may not be empty.") end
		params.a = args[2] or (mw.title.getCurrentTitle().nsText == "Template" and "a"); if params.a ~= "a" and params.a ~= "ä" then error("Parameter 2 must be \"a\" or \"ä\".") end
		
		if args[3] or args[4] then
			error("Parameters 3 and 4 are deprecated.")
		end
	elseif num == 1 then
		params.base = args[1] or ""
	end
	
	-- Swap the grades
	if invert_grades then
		params.strong, params.weak = params.weak, params.strong
	end
	
	if params.a then
		params.o = params.a == "ä" and "ö" or "o"
		params.u = params.a == "ä" and "y" or "u"
	end
	
	return params
end


--[=[
	Inflection functions
]=]--

local stem_endings = {}

stem_endings["inf1"] = {
	["inf1"] = "a",
	["inf1_long"] = "akseen",
}

stem_endings["inf2"] = {
	["inf2_ine"] = "essa",
	["inf2_ins"] = "en",
}

stem_endings["pres"] = {
	["pres_3sg"] = "V",
	["pres_3pl"] = "vat",
	["inf3_ine"] = "massa",
	["inf3_ela"] = "masta",
	["inf3_ill"] = "maan",
	["inf3_ade"] = "malla",
	["inf3_abe"] = "matta",
	["inf3_ins"] = "man",
	["inf4_nom"] = "minen",
	["inf4_par"] = "mista",
	["inf5"] = "maisillaan",
	["pres_part"] = "va",
	["agnt_part"] = "ma",
	["nega_part"] = "maton",
}

stem_endings["pres_weak"] = {
	["pres_1sg"] = "n",
	["pres_2sg"] = "t",
	["pres_1pl"] = "mme",
	["pres_2pl"] = "tte",
	["pres_conn"] = "",
	["impr_2sg"] = "",
}

stem_endings["past"] = {
	["past_3sg"] = "",
	["past_3pl"] = "vat",
}

stem_endings["past_weak"] = {
	["past_1sg"] = "n",
	["past_2sg"] = "t",
	["past_1pl"] = "mme",
	["past_2pl"] = "tte",
}

stem_endings["cond"] = {
	["cond_1sg"] = "sin",
	["cond_2sg"] = "sit",
	["cond_3sg"] = "si",
	["cond_1pl"] = "simme",
	["cond_2pl"] = "sitte",
	["cond_3pl"] = "sivat",
	["cond_conn"] = "si",
}

stem_endings["impr"] = {
	["impr_3sg"] = "oon",
	["impr_1pl"] = "aamme",
	["impr_2pl"] = "aa",
	["impr_3pl"] = "oot",
	["impr_conn"] = "o",
}

stem_endings["potn"] = {
	["potn_1sg"] = "en",
	["potn_2sg"] = "et",
	["potn_3sg"] = "ee",
	["potn_1pl"] = "emme",
	["potn_2pl"] = "ette",
	["potn_3pl"] = "evat",
	["potn_conn"] = "e",
	["past_part"] = "ut",
	["past_part_pl"] = "eet",
}

stem_endings["pres_pasv"] = {
	["pres_pasv"] = "aan",
	["pres_pasv_conn"] = "a",
}

stem_endings["past_pasv"] = {
	["past_pasv"] = "iin",
	["cond_pasv"] = "aisiin",
	["cond_pasv_conn"] = "aisi",
	["impr_pasv"] = "akoon",
	["impr_pasv_conn"] = "ako",
	["potn_pasv"] = "aneen",
	["potn_pasv_conn"] = "ane",
	["inf2_pasv_ine"] = "aessa",
	["inf3_pasv_ins"] = "aman",
	["pres_pasv_part"] = "ava",
	["past_pasv_part"] = "u",
}


--- Do a "deep copy" of a table or other value.
function clone( val )
	local tableRefs = {}
	local function recursiveClone( val )
		if type( val ) == 'table' then
			-- Encode circular references correctly
			if tableRefs[val] ~= nil then
				return tableRefs[val]
			end

			local retVal
			retVal = {}
			tableRefs[val] = retVal

			-- Copy metatable
			if getmetatable( val ) then
				setmetatable( retVal, recursiveClone( getmetatable( val ) ) )
			end

			for key, elt in pairs( val ) do
				retVal[key] = recursiveClone( elt )
			end
			return retVal
		else
			return val
		end
	end
	return recursiveClone( val )
end

-- Make a copy of the endings, with front vowels
stem_endings = {["a"] = stem_endings, ["ä"] = clone(stem_endings)}

for stem_key, endings in pairs(stem_endings["ä"]) do
	for key, ending in pairs(endings) do
		endings[key] = ustring.gsub(endings[key], "([aou])", {["a"] = "ä", ["o"] = "ö", ["u"] = "y"})
	end
end

-- Create any stems that were not given
local function make_stems(data, stems)
	if not stems["inf1"] and stems["pres"] then
		stems["inf1"] = clone(stems["pres"])
	end
	
	if not stems["cond"] and stems["pres"] then
		stems["cond"] = {}
		
		for _, stem in ipairs(stems["pres"]) do
			table.insert(stems["cond"], ustring.gsub(stem, "[ei]$", "") .. "i")
		end
	end
	
	if not stems["impr"] and stems["pres"] then
		stems["impr"] = {}
		
		for _, stem in ipairs(stems["pres"]) do
			table.insert(stems["impr"], stem .. "k")
		end
	end
	
	if not stems["potn"] and stems["pres"] then
		stems["potn"] = {}
		
		for _, stem in ipairs(stems["pres"]) do
			table.insert(stems["potn"], stem .. "n")
		end
	end
end

-- Create forms based on each stem, by adding endings to it
local function process_stems(data, stems, vh)
	if not stems["inf2"] and stems["inf1"] then
		stems["inf2"] = {}
		
		for _, stem in ipairs(stems["inf1"]) do
			table.insert(stems["inf2"], (ustring.gsub(stem, "e$", "i")))
		end
	end
	
	if not stems["pres_weak"] and stems["pres"] then
		stems["pres_weak"] = clone(stems["pres"])
	end
	
	if not stems["past_weak"] and stems["past"] then
		stems["past_weak"] = clone(stems["past"])
	end
	
	-- Go through each of the stems given
	for stem_key, substems in pairs(stems) do
		for _, stem in ipairs(substems) do
			-- Attach the endings to the stem
			for form_key, ending in pairs(stem_endings[vh][stem_key]) do
				if not data.forms[form_key] then
					data.forms[form_key] = {}
				end
				
				-- If the ending is "V" then it is a copy of the preceding vowel...
				if ending == "V" then
					-- ...but not if the stem ends in a long vowel or diphthong.
					if ustring.find(stem, "([aeiouyäö])%1$") or ustring.find(stem, "([aeiouyäö])[iuy]$") or ustring.find(stem, "ie$") or ustring.find(stem, "uo$") or ustring.find(stem, "yö$") then
						ending = ""
					else
						ending = ustring.match(stem, "([aeiouyäö])$") or ""
					end
				end
				
				table.insert(data.forms[form_key], stem .. ending)
			end
		end
	end
end


inflections["sanoa"] = function(args, data)
	data.title = "[[Kotus]] type 52/[[Appendix:Finnish conjugation/sanoa|sanoa]]"
	table.insert(data.categories, "Finnish sanoa-type verbs")
	
	local params = get_params(args, 5)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local apo = (params.weak == "" and ustring.sub(params.base, -1) == params.final) and "’" or ""
	
	local stems = {}
	stems["pres"]      = {params.base .. params.strong .. params.final}
	stems["pres_weak"] = {params.base .. params.weak .. apo .. params.final}
	stems["past"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["past_weak"] = {params.base .. params.weak .. apo .. params.final .. "i"}
	stems["pres_pasv"] = {params.base .. params.weak .. apo .. params.final .. "t"}
	stems["past_pasv"] = {params.base .. params.weak .. apo .. params.final .. "tt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["muistaa"] = function(args, data)
	data.title = "[[Kotus]] type 53/[[Appendix:Finnish conjugation/muistaa|muistaa]]"
	table.insert(data.categories, "Finnish muistaa-type verbs")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["pres"]      = {params.base .. params.strong .. params.a}
	stems["pres_weak"] = {params.base .. params.weak .. params.a}
	stems["past"]      = {params.base .. params.strong .. "i"}
	stems["past_weak"] = {params.base .. params.weak .. "i"}
	stems["pres_pasv"] = {params.base .. params.weak .. "et"}
	stems["past_pasv"] = {params.base .. params.weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["huutaa"] = function(args, data)
	data.title = "[[Kotus]] type 54/[[Appendix:Finnish conjugation/huutaa|huutaa]]"
	table.insert(data.categories, "Finnish huutaa-type verbs")
	
	local params = get_params(args, 2)
	local weak = ustring.match(params.base, "([lnr])$") or "d"
	
	if weak == "d" then
		data.title = data.title .. ", ''t-d'' gradation"
	else
		data.title = data.title .. ", ''" .. weak .. "t-" .. weak .. weak .. "'' gradation"
	end
	
	make_weak(params.base, "t", params.a, weak)
	
	local stems = {}
	stems["pres"]      = {params.base .. "t" .. params.a}
	stems["pres_weak"] = {params.base .. weak .. params.a}
	stems["past"]      = {params.base .. "si"}
	stems["pres_pasv"] = {params.base .. weak .. "et"}
	stems["past_pasv"] = {params.base .. weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["soutaa"] = function(args, data)
	data.title = "[[Kotus]] type 55/[[Appendix:Finnish conjugation/soutaa|soutaa]]"
	table.insert(data.categories, "Finnish soutaa-type verbs")
	
	local params = get_params(args, 2)
	local weak = ustring.match(params.base, "([lnr])$") or "d"
	
	if weak == "d" then
		data.title = data.title .. ", ''t-d'' gradation"
	else
		data.title = data.title .. ", ''" .. weak .. "t-" .. weak .. weak .. "'' gradation"
	end
	
	make_weak(params.base, "t", params.a, weak)
	
	local stems = {}
	stems["pres"]      = {params.base .. "t" .. params.a}
	stems["pres_weak"] = {params.base .. weak .. params.a}
	stems["past"]      = {params.base .. "ti", params.base .. "si"}
	stems["past_weak"] = {params.base .. weak .. "i", params.base .. "si"}
	stems["pres_pasv"] = {params.base .. weak .. "et"}
	stems["past_pasv"] = {params.base .. weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kaivaa"] = function(args, data)
	data.title = "[[Kotus]] type 56/[[Appendix:Finnish conjugation/kaivaa|kaivaa]]"
	table.insert(data.categories, "Finnish kaivaa-type verbs")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["pres"]      = {params.base .. params.strong .. params.a}
	stems["pres_weak"] = {params.base .. params.weak .. params.a}
	stems["past"]      = {params.base .. params.strong .. params.o .. "i"}
	stems["past_weak"] = {params.base .. params.weak .. params.o .. "i"}
	stems["pres_pasv"] = {params.base .. params.weak .. "et"}
	stems["past_pasv"] = {params.base .. params.weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["virkkaa"] = function(args, data)
	data.title = "[[Kotus]] type 56/[[Appendix:Finnish conjugation/kaivaa|kaivaa]] and 53/[[Appendix:Finnish conjugation/muistaa|muistaa]], ''kk-k'' gradation, irregular vowel harmony"
	table.insert(data.categories, "Finnish kaivaa-type verbs")
	table.insert(data.categories, "Finnish muistaa-type verbs")
	
	local stems = {}
	stems["inf1"]      = {"virkka"}
	stems["pres"]      = {"virkka"}
	stems["pres_weak"] = {"virka"}
	stems["past"]      = {"virkkoi"}
	stems["past_weak"] = {"virkoi"}
	stems["cond"]      = {"virkkai"}
	stems["impr"]      = {"virkkak"}
	stems["potn"]      = {"virkkan"}
	
	process_stems(data, stems, "a")
	
	local stems = {}
	
	stems["pres_pasv"] = {"virket"}
	stems["past_pasv"] = {"virkett"}
	
	process_stems(data, stems, "ä")
end

inflections["saartaa"] = function(args, data)
	data.title = "[[Kotus]] type 57/[[Appendix:Finnish conjugation/saartaa|saartaa]]"
	table.insert(data.categories, "Finnish saartaa-type verbs")
	
	local params = get_params(args, 2)
	local weak = ustring.match(params.base, "([lnr])$") or "d"
	
	if weak == "d" then
		data.title = data.title .. ", ''t-d'' gradation"
	else
		data.title = data.title .. ", ''" .. weak .. "t-" .. weak .. weak .. "'' gradation"
	end
	
	make_weak(params.base, "t", params.a, weak)
	
	local stems = {}
	stems["pres"]      = {params.base .. "t" .. params.a}
	stems["pres_weak"] = {params.base .. weak .. params.a}
	stems["past"]      = {params.base .. "si", params.base .. "t" .. params.o .. "i"}
	stems["past_weak"] = {params.base .. "si", params.base .. weak .. params.o .. "i"}
	stems["pres_pasv"] = {params.base .. weak .. "et"}
	stems["past_pasv"] = {params.base .. weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["laskea"] = function(args, data)
	data.title = "[[Kotus]] type 58/[[Appendix:Finnish conjugation/laskea|laskea]]"
	table.insert(data.categories, "Finnish laskea-type verbs")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, "e", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["pres"]      = {params.base .. params.strong .. "e"}
	stems["pres_weak"] = {params.base .. params.weak .. "e"}
	stems["past"]      = {params.base .. params.strong .. "i"}
	stems["past_weak"] = {params.base .. params.weak .. "i"}
	stems["pres_pasv"] = {params.base .. params.weak .. "et"}
	stems["past_pasv"] = {params.base .. params.weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["tuntea"] = function(args, data)
	data.title = "[[Kotus]] type 59/[[Appendix:Finnish conjugation/tuntea|tuntea]]"
	table.insert(data.categories, "Finnish tuntea-type verbs")
	
	local params = get_params(args, 2)
	local weak = ustring.match(params.base, "([lnr])$") or "d"
	
	if weak == "d" then
		data.title = data.title .. ", ''t-d'' gradation"
	else
		data.title = data.title .. ", ''" .. weak .. "t-" .. weak .. weak .. "'' gradation"
	end
	
	make_weak(params.base, "t", "e", weak)
	
	local stems = {}
	stems["pres"]      = {params.base .. "te"}
	stems["pres_weak"] = {params.base .. weak .. "e"}
	stems["past"]      = {params.base .. "si"}
	stems["pres_pasv"] = {params.base .. weak .. "et"}
	stems["past_pasv"] = {params.base .. weak .. "ett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["lähteä"] = function(args, data)
	data.title = "[[Kotus]] type 60/[[Appendix:Finnish conjugation/lähteä|lähteä]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish lähteä-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["pres"]      = {params.base .. "hte"}
	stems["pres_weak"] = {params.base .. "hde"}
	stems["past"]      = {params.base .. "hti", params.base .. "ksi"}
	stems["past_weak"] = {params.base .. "hdi", params.base .. "ksi"}
	stems["pres_pasv"] = {params.base .. "hdet"}
	stems["past_pasv"] = {params.base .. "hdett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["sallia"] = function(args, data)
	data.title = "[[Kotus]] type 61/[[Appendix:Finnish conjugation/sallia|sallia]]"
	table.insert(data.categories, "Finnish sallia-type verbs")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, "i", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local apo = (params.weak == "" and ustring.sub(params.base, -1) == "i") and "’" or ""
	
	local stems = {}
	stems["pres"]      = {params.base .. params.strong .. "i"}
	stems["pres_weak"] = {params.base .. params.weak .. apo .. "i"}
	stems["past"]      = {params.base .. params.strong .. "i"}
	stems["past_weak"] = {params.base .. params.weak .. apo .. "i"}
	stems["pres_pasv"] = {params.base .. params.weak .. apo .. "it"}
	stems["past_pasv"] = {params.base .. params.weak .. apo .. "itt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["voida"] = function(args, data)
	data.title = "[[Kotus]] type 62/[[Appendix:Finnish conjugation/voida|voida]], no gradation"
	table.insert(data.categories, "Finnish voida-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["inf1"]      = {params.base .. "d"}
	stems["pres"]      = {params.base}
	stems["past"]      = {params.base}
	stems["pres_pasv"] = {params.base .. "d"}
	stems["past_pasv"] = {params.base .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["saada"] = function(args, data)
	data.title = "[[Kotus]] type 63/[[Appendix:Finnish conjugation/saada|saada]], no gradation"
	table.insert(data.categories, "Finnish saada-type verbs")
	
	local params = get_params(args, 2)
	local vowel = ustring.sub(params.base, -1)
	
	local stems = {}
	stems["inf1"]      = {params.base .. vowel .. "d"}
	stems["pres"]      = {params.base .. vowel}
	stems["past"]      = {params.base .. "i"}
	stems["cond"]      = {params.base .. "i"}
	stems["pres_pasv"] = {params.base .. vowel .. "d"}
	stems["past_pasv"] = {params.base .. vowel .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["juoda"] = function(args, data)
	data.title = "[[Kotus]] type 64/[[Appendix:Finnish conjugation/juoda|juoda]], no gradation"
	table.insert(data.categories, "Finnish juoda-type verbs")
	
	local params = get_params(args, 2)
	local past_cond_stem = ustring.sub(params.base, 1, -3) .. ustring.sub(params.base, -1)
	
	local stems = {}
	stems["inf1"]      = {params.base .. "d"}
	stems["pres"]      = {params.base}
	stems["past"]      = {past_cond_stem .. "i"}
	stems["cond"]      = {past_cond_stem .. "i"}
	stems["pres_pasv"] = {params.base .. "d"}
	stems["past_pasv"] = {params.base .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["käydä"] = function(args, data)
	data.title = "[[Kotus]] type 65/[[Appendix:Finnish conjugation/käydä|käydä]], no gradation"
	table.insert(data.categories, "Finnish käydä-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.u .. "d"}
	stems["pres"]      = {params.base .. params.u}
	stems["past"]      = {params.base .. "vi"}
	stems["cond"]      = {params.base .. "vi"}
	stems["pres_pasv"] = {params.base .. params.u .. "d"}
	stems["past_pasv"] = {params.base .. params.u .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["rohkaista"] = function(args, data)
	data.title = "[[Kotus]] type 66/[[Appendix:Finnish conjugation/rohkaista|rohkaista]]"
	table.insert(data.categories, "Finnish rohkaista-type verbs")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.weak .. params.final .. "st"}
	stems["pres"]      = {params.base .. params.strong .. params.final .. "se"}
	stems["past"]      = {params.base .. params.strong .. params.final .. "si"}
	stems["impr"]      = {params.base .. params.weak .. params.final .. "sk"}
	stems["potn"]      = {params.base .. params.weak .. params.final .. "ss"}
	stems["pres_pasv"] = {params.base .. params.weak .. params.final .. "st"}
	stems["past_pasv"] = {params.base .. params.weak .. params.final .. "st"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["seistä"] = function(args, data)
	data.title = "[[Kotus]] type 52/[[Appendix:Finnish conjugation/sanoa|sanoa]] and 66/[[Appendix:Finnish conjugation/rohkaista|rohkaista]], no gradation"
	table.insert(data.categories, "Finnish sanoa-type verbs")
	table.insert(data.categories, "Finnish rohkaista-type verbs")
	
	local stems = {}
	stems["inf1"]      = {"seist"}
	stems["impr"]      = {"seisk"}
	stems["potn"]      = {"seiss"}
	stems["pres_pasv"] = {"seist"}
	stems["past_pasv"] = {"seist"}
	
	process_stems(data, stems, "ä")
	
	local stems = {}
	stems["pres"]      = {"seiso"}
	stems["past"]      = {"seisoi"}
	stems["cond"]      = {"seisoi"}
	
	process_stems(data, stems, "a")
end

inflections["tulla"] = function(args, data)
	data.title = "[[Kotus]] type 67/[[Appendix:Finnish conjugation/tulla|tulla]]"
	table.insert(data.categories, "Finnish tulla-type verbs")
	
	local params = get_params(args, 5, true)
	local cons = ustring.sub(params.final, -1)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.weak .. params.final .. cons}
	stems["pres"]      = {params.base .. params.strong .. params.final .. "e"}
	stems["past"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["impr"]      = {params.base .. params.weak .. params.final .. "k"}
	stems["potn"]      = {params.base .. params.weak .. params.final .. cons}
	stems["pres_pasv"] = {params.base .. params.weak .. params.final .. cons}
	stems["past_pasv"] = {params.base .. params.weak .. params.final .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["olla"] = function(args, data)
	data.title = "[[Kotus]] type 67/[[Appendix:Finnish conjugation/tulla|tulla]] and 64/[[Appendix:Finnish conjugation/juoda|juoda]], no gradation, irregular"
	table.insert(data.categories, "Finnish tulla-type verbs")
	table.insert(data.categories, "Finnish juoda-type verbs")
	
	local stems = {}
	stems["inf1"]      = {"oll"}
	stems["pres"]      = {"ole"}
	stems["past"]      = {"oli"}
	stems["impr"]      = {"olk"}
	stems["potn"]      = {"oll"}
	stems["pres_pasv"] = {"oll"}
	stems["past_pasv"] = {"olt"}
	
	make_stems(data, stems)
	process_stems(data, stems, "a")
	
	data.forms["pres_3sg"] = {"on"}
	data.forms["pres_3pl"] = {"ovat"}
	
	data.forms["potn_1sg"] = {"lienen"}
	data.forms["potn_2sg"] = {"lienet"}
	data.forms["potn_3sg"] = {"lienee"}
	data.forms["potn_1pl"] = {"lienemme"}
	data.forms["potn_2pl"] = {"lienette"}
	data.forms["potn_3pl"] = {"lienevät"}
	data.forms["potn_conn"] = {"liene"}
end

inflections["tupakoida"] = function(args, data)
	data.title = "[[Kotus]] type 68/[[Appendix:Finnish conjugation/tupakoida|tupakoida]], no gradation"
	table.insert(data.categories, "Finnish tupakoida-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["inf1"]      = {params.base .. "d"}
	stems["pres"]      = {params.base, params.base .. "tse"}
	stems["past"]      = {params.base, params.base .. "tsi"}
	stems["impr"]      = {params.base .. "k"}
	stems["potn"]      = {params.base .. "n"}
	stems["pres_pasv"] = {params.base .. "d"}
	stems["past_pasv"] = {params.base .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["valita"] = function(args, data)
	data.title = "[[Kotus]] type 69/[[Appendix:Finnish conjugation/valita|valita]], no gradation"
	table.insert(data.categories, "Finnish valita-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["inf1"]      = {params.base .. "t"}
	stems["pres"]      = {params.base .. "tse"}
	stems["past"]      = {params.base .. "tsi"}
	stems["impr"]      = {params.base .. "tk"}
	stems["potn"]      = {params.base .. "nn"}
	stems["pres_pasv"] = {params.base .. "t"}
	stems["past_pasv"] = {params.base .. "tt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["juosta"] = function(args, data)
	data.title = "[[Kotus]] type 70/[[Appendix:Finnish conjugation/juosta|juosta]], no gradation"
	table.insert(data.categories, "Finnish juosta-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["inf1"]      = {params.base .. "st"}
	stems["pres"]      = {params.base .. "kse"}
	stems["past"]      = {params.base .. "ksi"}
	stems["impr"]      = {params.base .. "sk"}
	stems["potn"]      = {params.base .. "ss"}
	stems["pres_pasv"] = {params.base .. "st"}
	stems["past_pasv"] = {params.base .. "st"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["nähdä"] = function(args, data)
	data.title = "[[Kotus]] type 71/[[Appendix:Finnish conjugation/nähdä|nähdä]], ''k-ø'' gradation"
	table.insert(data.categories, "Finnish nähdä-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["inf1"]      = {params.base .. "hd"}
	stems["pres"]      = {params.base .. "ke"}
	stems["pres_weak"] = {params.base .. "e"}
	stems["past"]      = {params.base .. "ki"}
	stems["past_weak"] = {params.base .. "i"}
	stems["impr"]      = {params.base .. "hk"}
	stems["potn"]      = {params.base .. "hn"}
	stems["pres_pasv"] = {params.base .. "hd"}
	stems["past_pasv"] = {params.base .. "ht"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["vanheta"] = function(args, data)
	data.title = "[[Kotus]] type 72/[[Appendix:Finnish conjugation/vanheta|vanheta]]"
	table.insert(data.categories, "Finnish vanheta-type verbs")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.weak .. params.final .. "t"}
	stems["pres"]      = {params.base .. params.strong .. params.final .. "ne"}
	stems["past"]      = {params.base .. params.strong .. params.final .. "ni"}
	stems["impr"]      = {params.base .. params.weak .. params.final .. "tk"}
	stems["potn"]      = {params.base .. params.weak .. params.final .. "nn"}
	stems["pres_pasv"] = {params.base .. params.weak .. params.final .. "t"}
	stems["past_pasv"] = {params.base .. params.weak .. params.final .. "tt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["salata"] = function(args, data)
	data.title = "[[Kotus]] type 73/[[Appendix:Finnish conjugation/salata|salata]]"
	table.insert(data.categories, "Finnish salata-type verbs")
	
	local params = get_params(args, 4, true)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.weak .. params.a .. "t"}
	stems["pres"]      = {params.base .. params.strong .. params.a .. params.a}
	stems["past"]      = {params.base .. params.strong .. params.a .. "si"}
	stems["cond"]      = {params.base .. params.strong .. params.a .. "i"}
	stems["impr"]      = {params.base .. params.weak .. params.a .. "tk"}
	stems["potn"]      = {params.base .. params.weak .. params.a .. "nn"}
	stems["pres_pasv"] = {params.base .. params.weak .. params.a .. "t"}
	stems["past_pasv"] = {params.base .. params.weak .. params.a .. "tt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["katketa"] = function(args, data)
	data.title = "[[Kotus]] type 74/[[Appendix:Finnish conjugation/katketa|katketa]]"
	table.insert(data.categories, "Finnish katketa-type verbs")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.weak .. params.final .. "t"}
	stems["pres"]      = {params.base .. params.strong .. params.final .. params.a}
	stems["past"]      = {params.base .. params.strong .. params.final .. "si"}
	stems["cond"]      = {params.base .. params.strong .. params.final .. params.a .. "i", params.base .. params.strong .. params.final .. "i"}
	stems["impr"]      = {params.base .. params.weak .. params.final .. "tk"}
	stems["potn"]      = {params.base .. params.weak .. params.final .. "nn"}
	stems["pres_pasv"] = {params.base .. params.weak .. params.final .. "t"}
	stems["past_pasv"] = {params.base .. params.weak .. params.final .. "tt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["selvitä"] = function(args, data)
	data.title = "[[Kotus]] type 75/[[Appendix:Finnish conjugation/selvitä|selvitä]]"
	table.insert(data.categories, "Finnish selvitä-type verbs")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["inf1"]      = {params.base .. params.weak .. params.final .. "t"}	
	stems["pres"]      = {params.base .. params.strong .. params.final .. params.a}
	stems["past"]      = {params.base .. params.strong .. params.final .. "si"}
	stems["impr"]      = {params.base .. params.weak .. params.final .. "tk"}
	stems["potn"]      = {params.base .. params.weak .. params.final .. "nn"}
	stems["pres_pasv"] = {params.base .. params.weak .. params.final .. "t"}
	stems["past_pasv"] = {params.base .. params.weak .. params.final .. "tt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["taitaa"] = function(args, data)
	data.title = "[[Kotus]] type 76/[[Appendix:Finnish conjugation/taitaa|taitaa]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish taitaa-type verbs")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["pres"]      = {params.base .. "t" .. params.a}
	stems["pres_weak"] = {params.base .. "d" .. params.a}
	stems["past"]      = {params.base .. "si"}
	stems["potn"]      = {params.base .. "t" .. params.a .. "n", params.base .. "nn"}
	stems["pres_pasv"] = {params.base .. "det"}
	stems["past_pasv"] = {params.base .. "dett"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end


-- Helper functions

function postprocess(args, data)
	local appendix = args["appendix"]; if appendix == "" then appendix = nil end
	local qual = args["qual"]; if qual == "" then qual = nil end
	
	-- Create the periphrastic forms (negative and perfect)
	local function make_forms(aux, forms)
		if not forms then
			return nil
		end
		
		local ret = {}
		
		for _, form in ipairs(forms) do
			table.insert(ret, aux .. " [[" .. form .. "]]")
		end
		
		return ret
	end
	
	-- Present
	data.forms["pres_1sg_neg"] = make_forms("en", data.forms["pres_conn"])
	data.forms["pres_2sg_neg"] = make_forms("et", data.forms["pres_conn"])
	data.forms["pres_3sg_neg"] = make_forms("ei", data.forms["pres_conn"])
	data.forms["pres_1pl_neg"] = make_forms("emme", data.forms["pres_conn"])
	data.forms["pres_2pl_neg"] = make_forms("ette", data.forms["pres_conn"])
	data.forms["pres_3pl_neg"] = make_forms("eivät", data.forms["pres_conn"])
	data.forms["pres_pasv_neg"] = make_forms("ei", data.forms["pres_pasv_conn"])
	
	data.forms["pres_perf_1sg"] = make_forms("olen", data.forms["past_part"])
	data.forms["pres_perf_2sg"] = make_forms("olet", data.forms["past_part"])
	data.forms["pres_perf_3sg"] = make_forms("on", data.forms["past_part"])
	data.forms["pres_perf_1pl"] = make_forms("olemme", data.forms["past_part_pl"])
	data.forms["pres_perf_2pl"] = make_forms("olette", data.forms["past_part_pl"])
	data.forms["pres_perf_3pl"] = make_forms("ovat", data.forms["past_part_pl"])
	data.forms["pres_perf_pasv"] = make_forms("on", data.forms["past_pasv_part"])
	
	data.forms["pres_perf_1sg_neg"] = make_forms("en ole", data.forms["past_part"])
	data.forms["pres_perf_2sg_neg"] = make_forms("et ole", data.forms["past_part"])
	data.forms["pres_perf_3sg_neg"] = make_forms("ei ole", data.forms["past_part"])
	data.forms["pres_perf_1pl_neg"] = make_forms("emme ole", data.forms["past_part_pl"])
	data.forms["pres_perf_2pl_neg"] = make_forms("ette ole", data.forms["past_part_pl"])
	data.forms["pres_perf_3pl_neg"] = make_forms("eivät ole", data.forms["past_part_pl"])
	data.forms["pres_perf_pasv_neg"] = make_forms("ei ole", data.forms["past_pasv_part"])
	
	-- Past
	data.forms["past_1sg_neg"] = make_forms("en", data.forms["past_part"])
	data.forms["past_2sg_neg"] = make_forms("et", data.forms["past_part"])
	data.forms["past_3sg_neg"] = make_forms("ei", data.forms["past_part"])
	data.forms["past_1pl_neg"] = make_forms("emme", data.forms["past_part_pl"])
	data.forms["past_2pl_neg"] = make_forms("ette", data.forms["past_part_pl"])
	data.forms["past_3pl_neg"] = make_forms("eivät", data.forms["past_part_pl"])
	data.forms["past_pasv_neg"] = make_forms("ei", data.forms["past_pasv_part"])
	
	data.forms["past_perf_1sg"] = make_forms("olin", data.forms["past_part"])
	data.forms["past_perf_2sg"] = make_forms("olit", data.forms["past_part"])
	data.forms["past_perf_3sg"] = make_forms("oli", data.forms["past_part"])
	data.forms["past_perf_1pl"] = make_forms("olimme", data.forms["past_part_pl"])
	data.forms["past_perf_2pl"] = make_forms("olitte", data.forms["past_part_pl"])
	data.forms["past_perf_3pl"] = make_forms("olivat", data.forms["past_part_pl"])
	data.forms["past_perf_pasv"] = make_forms("oli", data.forms["past_pasv_part"])
	
	data.forms["past_perf_1sg_neg"] = make_forms("en ollut", data.forms["past_part"])
	data.forms["past_perf_2sg_neg"] = make_forms("et ollut", data.forms["past_part"])
	data.forms["past_perf_3sg_neg"] = make_forms("ei ollut", data.forms["past_part"])
	data.forms["past_perf_1pl_neg"] = make_forms("emme olleet", data.forms["past_part_pl"])
	data.forms["past_perf_2pl_neg"] = make_forms("ette olleet", data.forms["past_part_pl"])
	data.forms["past_perf_3pl_neg"] = make_forms("eivät olleet", data.forms["past_part_pl"])
	data.forms["past_perf_pasv_neg"] = make_forms("ei ollut", data.forms["past_pasv_part"])
	
	-- Conditional
	data.forms["cond_1sg_neg"] = make_forms("en", data.forms["cond_conn"])
	data.forms["cond_2sg_neg"] = make_forms("et", data.forms["cond_conn"])
	data.forms["cond_3sg_neg"] = make_forms("ei", data.forms["cond_conn"])
	data.forms["cond_1pl_neg"] = make_forms("emme", data.forms["cond_conn"])
	data.forms["cond_2pl_neg"] = make_forms("ette", data.forms["cond_conn"])
	data.forms["cond_3pl_neg"] = make_forms("eivät", data.forms["cond_conn"])
	data.forms["cond_pasv_neg"] = make_forms("ei", data.forms["cond_pasv_conn"])
	
	data.forms["cond_perf_1sg"] = make_forms("olisin", data.forms["past_part"])
	data.forms["cond_perf_2sg"] = make_forms("olisit", data.forms["past_part"])
	data.forms["cond_perf_3sg"] = make_forms("olisi", data.forms["past_part"])
	data.forms["cond_perf_1pl"] = make_forms("olisimme", data.forms["past_part_pl"])
	data.forms["cond_perf_2pl"] = make_forms("olisitte", data.forms["past_part_pl"])
	data.forms["cond_perf_3pl"] = make_forms("olisivat", data.forms["past_part_pl"])
	data.forms["cond_perf_pasv"] = make_forms("olisi", data.forms["past_pasv_part"])
	
	data.forms["cond_perf_1sg_neg"] = make_forms("en olisi", data.forms["past_part"])
	data.forms["cond_perf_2sg_neg"] = make_forms("et olisi", data.forms["past_part"])
	data.forms["cond_perf_3sg_neg"] = make_forms("ei olisi", data.forms["past_part"])
	data.forms["cond_perf_1pl_neg"] = make_forms("emme olisi", data.forms["past_part_pl"])
	data.forms["cond_perf_2pl_neg"] = make_forms("ette olisi", data.forms["past_part_pl"])
	data.forms["cond_perf_3pl_neg"] = make_forms("eivät olisi", data.forms["past_part_pl"])
	data.forms["cond_perf_pasv_neg"] = make_forms("ei olisi", data.forms["past_pasv_part"])
	
	-- Imperative
	data.forms["impr_2sg_neg"] = make_forms("älä", data.forms["impr_2sg"])
	data.forms["impr_3sg_neg"] = make_forms("älköön", data.forms["impr_conn"])
	data.forms["impr_1pl_neg"] = make_forms("älkäämme", data.forms["impr_conn"])
	data.forms["impr_2pl_neg"] = make_forms("älkää", data.forms["impr_conn"])
	data.forms["impr_3pl_neg"] = make_forms("älkööt", data.forms["impr_conn"])
	data.forms["impr_pasv_neg"] = make_forms("älköön", data.forms["impr_pasv_conn"])
	
	data.forms["impr_perf_2sg"] = make_forms("ole", data.forms["past_part"])
	data.forms["impr_perf_3sg"] = make_forms("olkoon", data.forms["past_part"])
	data.forms["impr_perf_1pl"] = make_forms("olkaamme", data.forms["past_part_pl"])
	data.forms["impr_perf_2pl"] = make_forms("olkaa", data.forms["past_part_pl"])
	data.forms["impr_perf_3pl"] = make_forms("olkoot", data.forms["past_part_pl"])
	data.forms["impr_perf_pasv"] = make_forms("olkoon", data.forms["past_pasv_part"])
	
	data.forms["impr_perf_2sg_neg"] = make_forms("älä ole", data.forms["past_part"])
	data.forms["impr_perf_3sg_neg"] = make_forms("älköön olko", data.forms["past_part"])
	data.forms["impr_perf_1pl_neg"] = make_forms("älkäämme olko", data.forms["past_part_pl"])
	data.forms["impr_perf_2pl_neg"] = make_forms("älkää olko", data.forms["past_part_pl"])
	data.forms["impr_perf_3pl_neg"] = make_forms("älkööt olko", data.forms["past_part_pl"])
	data.forms["impr_perf_pasv_neg"] = make_forms("älköön olko", data.forms["past_pasv_part"])
	
	-- Potential
	data.forms["potn_1sg_neg"] = make_forms("en", data.forms["potn_conn"])
	data.forms["potn_2sg_neg"] = make_forms("et", data.forms["potn_conn"])
	data.forms["potn_3sg_neg"] = make_forms("ei", data.forms["potn_conn"])
	data.forms["potn_1pl_neg"] = make_forms("emme", data.forms["potn_conn"])
	data.forms["potn_2pl_neg"] = make_forms("ette", data.forms["potn_conn"])
	data.forms["potn_3pl_neg"] = make_forms("eivät", data.forms["potn_conn"])
	data.forms["potn_pasv_neg"] = make_forms("ei", data.forms["potn_pasv_conn"])
	
	data.forms["potn_perf_1sg"] = make_forms("lienen", data.forms["past_part"])
	data.forms["potn_perf_2sg"] = make_forms("lienet", data.forms["past_part"])
	data.forms["potn_perf_3sg"] = make_forms("lienee", data.forms["past_part"])
	data.forms["potn_perf_1pl"] = make_forms("lienemme", data.forms["past_part_pl"])
	data.forms["potn_perf_2pl"] = make_forms("lienette", data.forms["past_part_pl"])
	data.forms["potn_perf_3pl"] = make_forms("lienevät", data.forms["past_part_pl"])
	data.forms["potn_perf_pasv"] = make_forms("lienee", data.forms["past_pasv_part"])
	
	data.forms["potn_perf_1sg_neg"] = make_forms("en liene", data.forms["past_part"])
	data.forms["potn_perf_2sg_neg"] = make_forms("et liene", data.forms["past_part"])
	data.forms["potn_perf_3sg_neg"] = make_forms("ei liene", data.forms["past_part"])
	data.forms["potn_perf_1pl_neg"] = make_forms("emme liene", data.forms["past_part_pl"])
	data.forms["potn_perf_2pl_neg"] = make_forms("ette liene", data.forms["past_part_pl"])
	data.forms["potn_perf_3pl_neg"] = make_forms("eivät liene", data.forms["past_part_pl"])
	data.forms["potn_perf_pasv_neg"] = make_forms("ei liene", data.forms["past_pasv_part"])
	
	-- Add qualifier
	for key, form in pairs(data.forms) do
		-- Add qual
		-- for participles, qual is before, while for others it is after
		if string.sub(key, -5) == "_part" then
			for i, subform in ipairs(form) do
				subform = (qual and qual .. " " or "") .. subform
				form[i] = subform
			end
			if form.rare then
				for i, subform in ipairs(form.rare) do
					subform = (qual and qual .. " " or "") .. subform
					form.rare[i] = subform
				end
			end
		else
			for i, subform in ipairs(form) do
				subform = subform .. (qual and " " .. qual or "")
				form[i] = subform
			end
			if form.rare then
				for i, subform in ipairs(form.rare) do
					subform = subform .. (qual and " " .. qual or "")
					form.rare[i] = subform
				end
			end
		end
		
		data.forms[key] = form
	end
end

return export
