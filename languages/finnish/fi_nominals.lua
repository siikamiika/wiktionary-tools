local ustring = require("ustring")
local make_weak = require("fi_utilities").make_weak

local export = {}

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
	
	if args["nocheck"] then
		table.insert(data.categories, "fi-decl with nocheck")
	end
	
	if args["nosg"] then
		table.insert(data.categories, "fi-decl with nosg")
	end
	
	if args["nopl"] then
		table.insert(data.categories, "fi-decl with nopl")
	end
	
	if args["type"] then
		table.insert(data.categories, "fi-decl with type")
	end

    return data
end

function get_params(args, num, invert_grades)
	local params = {}
	
	if num == 5 then
		params.base = args[1]
		params.strong = args[2]
		params.weak = args[3]
		params.final = args[4]
		params.a = args[5]
	elseif num == 4 then
		params.base = args[1]
		params.strong = args[2]
		params.weak = args[3]
		params.a = args[4]
	elseif num == 2 then
		params.base = args[1]
		params.a = args[2]
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

stem_endings["nom_sg"] = {
	["nom_sg"] = "",
}

stem_endings["sg"] = {
	["ess_sg"] = "na",
}

stem_endings["sg_weak"] = {
	["gen_sg"] = "n",
	["ine_sg"] = "ssa",
	["ela_sg"] = "sta",
	["ade_sg"] = "lla",
	["abl_sg"] = "lta",
	["all_sg"] = "lle",
	["tra_sg"] = "ksi",
	["ins_sg"] = "n",
	["abe_sg"] = "tta",
	["nom_pl"] = "t",
}

stem_endings["par_sg"] = {
	["par_sg"] = "a",
}

stem_endings["ill_sg"] = {
	["ill_sg"] = "Vn",
}

stem_endings["pl"] = {
	["ess_pl"] = "na",
	["com_pl"] = "ne",
}

stem_endings["pl_weak"] = {
	["ine_pl"] = "ssa",
	["ela_pl"] = "sta",
	["ade_pl"] = "lla",
	["abl_pl"] = "lta",
	["all_pl"] = "lle",
	["tra_pl"] = "ksi",
	["ins_pl"] = "n",
	["abe_pl"] = "tta",
}

stem_endings["par_pl"] = {
	["par_pl"] = "a",
}

stem_endings["gen_pl"] = {
	["gen_pl"] = "en",
}

stem_endings["ill_pl"] = {
	["ill_pl"] = "Vn",
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
	if not stems["nom_sg"] and stems["sg"] then
		stems["nom_sg"] = clone(stems["sg"])
	end
	
	if not stems["par_sg"] and stems["sg"] then
		stems["par_sg"] = clone(stems["sg"])
	end
	
	if not stems["ill_sg"] and stems["sg"] then
		stems["ill_sg"] = {}
		
		for _, stem in ipairs(stems["sg"]) do
			-- If the stem ends in a long vowel or diphthong, then add -h
			if ustring.find(stem, "([aeiouyäö])%1$") or ustring.find(stem, "[aeiouyäö][iyü]$") then
				table.insert(stems["ill_sg"], stem .. "h")
			else
				table.insert(stems["ill_sg"], stem)
			end
		end
	end
	
	if not stems["par_pl"] and stems["pl"] then
		stems["par_pl"] = {}
		
		for _, stem in ipairs(stems["pl"]) do
			table.insert(stems["par_pl"], stem)
		end
	end
	
	if not stems["gen_pl"] and stems["par_pl"] then
		stems["gen_pl"] = {}
		
		for _, stem in ipairs(stems["par_pl"]) do
			-- If the partitive plural stem ends in -it, then replace the t with d or tt
			if ustring.find(stem, "it$") then
				table.insert(stems["gen_pl"], (ustring.gsub(stem, "t$", "d")))
				table.insert(stems["gen_pl"], stem .. "t")
			else
				table.insert(stems["gen_pl"], stem)
			end
		end
	end
	
	if not stems["ill_pl"] and stems["pl"] then
		stems["ill_pl"] = {}
		
		for _, stem in ipairs(stems["pl"]) do
			table.insert(stems["ill_pl"], stem)
		end
	end
end

-- Create forms based on each stem, by adding endings to it
local function process_stems(data, stems, vh)
	if not stems["sg_weak"] and stems["sg"] then
		stems["sg_weak"] = clone(stems["sg"])
	end
	
	if not stems["pl_weak"] and stems["pl"] then
		stems["pl_weak"] = clone(stems["pl"])
	end
	
	-- Go through each of the stems given
	for stem_key, substems in pairs(stems) do
		for _, stem in ipairs(substems) do
			-- Attach the endings to the stem
			for form_key, ending in pairs(stem_endings[vh][stem_key]) do
				if not data.forms[form_key] then
					data.forms[form_key] = {}
				end
				
				-- "V" is a copy of the last vowel in the stem
				if ustring.find(ending, "V") then
					local vowel = ustring.match(stem, "([aeiouyäö])[^aeiouyäö]*$")
					ending = ustring.gsub(ending, "V", vowel or "?")
				end
				
				table.insert(data.forms[form_key], stem .. ending)
			end
		end
	end
	
	data["stems"] = stems
end


inflections["valo"] = function(args, data)
	data.title = "[[Kotus]] type 1/[[Appendix:Finnish nominal inflection/valo|valo]]"
	table.insert(data.categories, "Finnish valo-type nominals")
	
	local params = get_params(args, 5)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local wk_sg = params.weak
	local wk_pl = params.weak
	
	if ustring.sub(params.base, -1) == params.final then
		if wk_sg == "" and (ustring.find(params.base, "[aeiouyäö][iuy]$") or ustring.find(params.base, "[iuy][eoö]$")) then
			wk_sg = "’"
		end
		
		if wk_pl == "" then
			wk_pl = "’"
		end
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.final}
	stems["sg_weak"] = {params.base .. wk_sg .. params.final}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["pl_weak"] = {params.base .. wk_pl .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "j"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["palvelu"] = function(args, data)
	data.title = "[[Kotus]] type 2/[[Appendix:Finnish nominal inflection/palvelu|palvelu]], no gradation"
	table.insert(data.categories, "Finnish palvelu-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "j", params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["valtio"] = function(args, data)
	data.title = "[[Kotus]] type 3/[[Appendix:Finnish nominal inflection/valtio|valtio]], no gradation"
	table.insert(data.categories, "Finnish valtio-type nominals")
	
	local params = get_params(args, 2)
	local final = ustring.sub(params.base, -1)
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["laatikko"] = function(args, data)
	data.title = "[[Kotus]] type 4/[[Appendix:Finnish nominal inflection/laatikko|laatikko]]"
	table.insert(data.categories, "Finnish laatikko-type nominals")
	
	local params = get_params(args, 5, false, "kk", "k", "o")
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.final}
	stems["sg_weak"] = {params.base .. params.weak .. params.final}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "j", params.base .. params.weak .. params.final .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "ih", params.base .. params.weak .. params.final .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["risti"] = function(args, data)
	data.title = "[[Kotus]] type 5/[[Appendix:Finnish nominal inflection/risti|risti]]"
	table.insert(data.categories, "Finnish risti-type nominals")
	
	local params = get_params(args, 4)
	local i = args["i"]; if i == "0" then i = "" else i = "i" end
	
	make_weak(params.base, params.strong, "i", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.strong .. i}
	stems["sg"]      = {params.base .. params.strong .. "i"}
	stems["sg_weak"] = {params.base .. params.weak .. "i"}
	stems["pl"]      = {params.base .. params.strong .. "ei"}
	stems["pl_weak"] = {params.base .. params.weak .. "ei"}
	stems["gen_pl"]  = {params.base .. params.strong .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. "ej"}
	stems["ill_pl"]  = {params.base .. params.strong .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["paperi"] = function(args, data)
	data.title = "[[Kotus]] type 6/[[Appendix:Finnish nominal inflection/paperi|paperi]], no gradation"
	table.insert(data.categories, "Finnish paperi-type nominals")
	
	local params = get_params(args, 2)
	local i = args["i"]; if i == "0" then i = "" else i = "i" end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. i}
	stems["sg"]      = {params.base .. "i"}
	stems["pl"]      = {params.base .. "ei"}
	stems["par_pl"]  = {params.base .. "eit", params.base .. "ej"}
	stems["gen_pl"]  = {params.base .. "i", params.base .. "eid", params.base .. "eitt"}
	stems["ill_pl"]  = {params.base .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["ovi"] = function(args, data)
	data.title = "[[Kotus]] type 7/[[Appendix:Finnish nominal inflection/ovi|ovi]]"
	table.insert(data.categories, "Finnish ovi-type nominals")
	
	local params = get_params(args, 4)
	local nom_sg = args["nom_sg"]; if nom_sg == "" then nom_sg = nil end
	
	make_weak(params.base, params.strong, "e", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. params.strong .. "i"}
	stems["sg"]      = {params.base .. params.strong .. "e"}
	stems["sg_weak"] = {params.base .. params.weak .. "e"}
	stems["pl"]      = {params.base .. params.strong .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["nalle"] = function(args, data)
	data.title = "[[Kotus]] type 8/[[Appendix:Finnish nominal inflection/nalle|nalle]]"
	table.insert(data.categories, "Finnish nalle-type nominals")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, "e", params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. "e"}
	stems["sg_weak"] = {params.base .. params.weak .. "e"}
	stems["pl"]      = {params.base .. params.strong .. "ei"}
	stems["pl_weak"] = {params.base .. params.weak .. "ei"}
	stems["par_pl"]  = {params.base .. params.strong .. "ej"}
	stems["ill_pl"]  = {params.base .. params.strong .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.strong .. "ein"}
end

inflections["kala"] = function(args, data)
	data.title = "[[Kotus]] type 9/[[Appendix:Finnish nominal inflection/kala|kala]]"
	table.insert(data.categories, "Finnish kala-type nominals")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local wk_sg = params.weak
	
	if wk_sg == "" and ustring.sub(params.base, -2) == params.a .. params.a then
		wk_sg = "’"
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.a}
	stems["sg_weak"] = {params.base .. wk_sg .. params.a}
	stems["pl"]      = {params.base .. params.strong .. params.o .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.o .. "j"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.strong .. params.a .. "in"}
end

inflections["koira"] = function(args, data)
	data.title = "[[Kotus]] type 10/[[Appendix:Finnish nominal inflection/koira|koira]]"
	table.insert(data.categories, "Finnish koira-type nominals")
	
	local params = get_params(args, 4)
	local nom_sg = args["nom_sg"]; if nom_sg == "" then nom_sg = nil end
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local wk_sg = params.weak
	local wk_pl = params.weak
	
	if wk_sg == "" and ustring.sub(params.base, -2) == params.a .. params.a then
		wk_sg = "’"
	end
	
	if wk_pl == "" and ustring.sub(params.base, -1) == "i" then
		wk_pl = "’"
	end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. params.strong .. params.a}
	stems["sg"]      = {params.base .. params.strong .. params.a}
	stems["sg_weak"] = {params.base .. wk_sg .. params.a}
	stems["pl"]      = {params.base .. params.strong .. "i"}
	stems["pl_weak"] = {params.base .. wk_pl .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.strong .. params.a .. "in"}
end

inflections["omena"] = function(args, data)
	data.title = "[[Kotus]] type 11/[[Appendix:Finnish nominal inflection/omena|omena]], no gradation"
	table.insert(data.categories, "Finnish omena-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["pl"]      = {params.base .. params.o .. "i", params.base .. "i"}
	stems["par_pl"]  = {params.base .. "i", params.base .. params.o .. "it"}
	stems["ill_pl"]  = {params.base .. "i", params.base .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.o .. "jen", params.base .. params.a .. "in"}
	-- data.forms["par_pl"].rare = {params.base .. params.o .. "j" .. params.a}
end

inflections["kulkija"] = function(args, data)
	data.title = "[[Kotus]] type 12/[[Appendix:Finnish nominal inflection/kulkija|kulkija]], no gradation"
	table.insert(data.categories, "Finnish kulkija-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["pl"]      = {params.base .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.o .. "it"}
	stems["ill_pl"]  = {params.base .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.a .. "in"}
end

inflections["katiska"] = function(args, data)
	data.title = "[[Kotus]] type 13/[[Appendix:Finnish nominal inflection/katiska|katiska]], no gradation"
	table.insert(data.categories, "Finnish katiska-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["pl"]      = {params.base .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.o .. "it", params.base .. params.o .. "j"}
	stems["ill_pl"]  = {params.base .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.a .. "in"}
end

inflections["solakka"] = function(args, data)
	data.title = "[[Kotus]] type 14/[[Appendix:Finnish nominal inflection/solakka|solakka]]"
	table.insert(data.categories, "Finnish solakka-type nominals")
	
	local params = get_params(args, 4)
	
	make_weak(params.base, params.strong, params.a, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["sg"]      = {params.base .. params.strong .. params.a}
	stems["sg_weak"] = {params.base .. params.weak .. params.a}
	stems["pl"]      = {params.base .. params.strong .. params.o .. "i"}
	stems["pl_weak"] = {params.base .. params.weak .. params.o .. "i"}
	stems["par_pl"]  = {params.base .. params.weak .. params.o .. "it", params.base .. params.strong .. params.o .. "j"}
	stems["ill_pl"]  = {params.base .. params.weak .. params.o .. "ih", params.base .. params.strong .. params.o .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.strong .. params.a .. "in"}
end

inflections["korkea"] = function(args, data)
	data.title = "[[Kotus]] type 15/[[Appendix:Finnish nominal inflection/korkea|korkea]], no gradation"
	table.insert(data.categories, "Finnish korkea-type nominals")
	
	local params = get_params(args, 2)
	local final = ustring.sub(params.base, -1)
	
	local stems = {}
	stems["sg"]      = {params.base .. params.a}
	stems["par_sg"]  = {params.base .. params.a, params.base .. params.a .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "isi", params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. params.a .. "in"}
end

inflections["vanhempi"] = function(args, data)
	data.title = "[[Kotus]] type 16/[[Appendix:Finnish nominal inflection/vanhempi|vanhempi]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish vanhempi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "mpi"}
	stems["sg"]      = {params.base .. "mp" .. params.a}
	stems["sg_weak"] = {params.base .. "mm" .. params.a}
	stems["pl"]      = {params.base .. "mpi"}
	stems["pl_weak"] = {params.base .. "mmi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "mp" .. params.a .. "in"}
end

inflections["vapaa"] = function(args, data)
	data.title = "[[Kotus]] type 17/[[Appendix:Finnish nominal inflection/vapaa|vapaa]], no gradation"
	table.insert(data.categories, "Finnish vapaa-type nominals")
	
	local params = get_params(args, 2)
	local final = ustring.sub(params.base, -1)
	
	local stems = {}
	stems["sg"]      = {params.base .. final}
	stems["par_sg"]  = {params.base .. final .. "t"}
	stems["ill_sg"]  = {params.base .. final .. "se"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["ill_pl"].rare = {params.base .. "ihin"}
end

inflections["maa"] = function(args, data)
	data.title = "[[Kotus]] type 18/[[Appendix:Finnish nominal inflection/maa|maa]], no gradation"
	table.insert(data.categories, "Finnish maa-type nominals")
	
	local params = get_params(args, 2)
	local nom_sg = args["nom_sg"]; if nom_sg == "" then nom_sg = nil end
	
	local pl_stem = ustring.sub(params.base, 1, -2)
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {pl_stem .. "i"}
	stems["par_pl"]  = {pl_stem .. "it"}
	stems["ill_pl"]  = {pl_stem .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["suo"] = function(args, data)
	data.title = "[[Kotus]] type 19/[[Appendix:Finnish nominal inflection/suo|suo]], no gradation"
	table.insert(data.categories, "Finnish suo-type nominals")
	
	local params = get_params(args, 2)
	local final = ustring.sub(params.base, -1)
	local plural = ustring.sub(params.base, 1, -3) .. final
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["ill_sg"]  = {params.base .. "h"}
	stems["pl"]      = {plural .. "i"}
	stems["par_pl"]  = {plural .. "it"}
	stems["ill_pl"]  = {plural .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["filee"] = function(args, data)
	data.title = "[[Kotus]] type 20/[[Appendix:Finnish nominal inflection/filee|filee]], no gradation"
	table.insert(data.categories, "Finnish filee-type nominals")
	
	local params = get_params(args, 2)
	local pl_stem = ustring.sub(params.base, 1, -2)
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["ill_sg"]  = {params.base .. "h", params.base .. "se"}
	stems["pl"]      = {pl_stem .. "i"}
	stems["par_pl"]  = {pl_stem .. "it"}
	stems["ill_pl"]  = {pl_stem .. "ih", pl_stem .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["rosé"] = function(args, data)
	data.title = "[[Kotus]] type 21/[[Appendix:Finnish nominal inflection/rosé|rosé]], no gradation"
	table.insert(data.categories, "Finnish rosé-type nominals")
	
	local params = get_params(args, 2)
	local ill_sg_vowel = args["ill_sg_vowel"]; if ill_sg_vowel == "" then error("Parameter \"ill_sg_vowel=\" cannot be empty.") end
	local ill_sg_vowel2 = args["ill_sg_vowel2"]; if ill_sg_vowel2 == "" then error("Parameter \"ill_sg_vowel2=\" cannot be empty.") end
	
	local stems = {}
	stems["sg"]      = {params.base}
	stems["par_sg"]  = {params.base .. "t"}
	stems["ill_sg"]  = {params.base .. "h"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	if ill_sg_vowel then
		data.forms["ill_sg"] = {params.base .. "h" .. ill_sg_vowel .. "n"}
	end
	
	if ill_sg_vowel2 then
		table.insert(data.forms["ill_sg"], params.base .. "h" .. ill_sg_vowel2 .. "n")
	end
end

inflections["parfait"] = function(args, data)
	data.title = "[[Kotus]] type 22/[[Appendix:Finnish nominal inflection/parfait|parfait]], no gradation"
	table.insert(data.categories, "Finnish parfait-type nominals")
	
	local params = get_params(args, 2)
	local ill_sg_vowel = args["ill_sg_vowel"] --or --(mw.title.getCurrentTitle().nsText == "Template" and "e"); if not ill_sg_vowel or ill_sg_vowel == "" then error("Parameter \"ill_sg_vowel=\" is missing.") end
	local ill_sg_vowel2 = args["ill_sg_vowel2"]; if ill_sg_vowel2 == "" then error("Parameter \"ill_sg_vowel2=\" cannot be empty.") end
	
	local stems = {}
	stems["nom_sg"]  = {params.base}
	stems["sg"]      = {params.base .. "’"}
	stems["par_sg"]  = {params.base .. "’t"}
	stems["pl"]      = {params.base .. "’i"}
	stems["par_pl"]  = {params.base .. "’it"}
	stems["ill_pl"]  = {params.base .. "’ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	data.forms["ill_sg"] = {params.base .. "’h" .. ill_sg_vowel .. "n"}
	
	if ill_sg_vowel2 then
		table.insert(data.forms["ill_sg"], params.base .. "h" .. ill_sg_vowel2 .. "n")
	end
end

inflections["tiili"] = function(args, data)
	data.title = "[[Kotus]] type 23/[[Appendix:Finnish nominal inflection/tiili|tiili]], no gradation"
	table.insert(data.categories, "Finnish tiili-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "i"}
	stems["sg"]      = {params.base .. "e"}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["uni"] = function(args, data)
	data.title = "[[Kotus]] type 24/[[Appendix:Finnish nominal inflection/uni|uni]], no gradation"
	table.insert(data.categories, "Finnish uni-type nominals")
	
	local params = get_params(args, 2)
	local par_sg_a = args["par_sg_a"]; if par_sg_a and par_sg_a ~= "a" and par_sg_a ~= "ä" then error("Parameter \"par_sg_a=\" must be \"a\" or \"ä\".") end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "i"}
	stems["sg"]      = {params.base .. "e"}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["gen_pl"]  = {params.base .. "i", params.base .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	if par_sg_a then
		data.forms["par_sg"] = {}
		
		for _, stem in ipairs(stems["par_sg"]) do
			table.insert(data.forms["par_sg"], stem .. par_sg_a)
		end
	end
end

inflections["toimi"] = function(args, data)
	data.title = "[[Kotus]] type 25/[[Appendix:Finnish nominal inflection/toimi|toimi]], no gradation"
	table.insert(data.categories, "Finnish toimi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "mi"}
	stems["sg"]      = {params.base .. "me"}
	stems["par_sg"]  = {params.base .. "nt", params.base .. "me"}
	stems["pl"]      = {params.base .. "mi"}
	stems["gen_pl"]  = {params.base .. "mi", params.base .. "nt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["pieni"] = function(args, data)
	data.title = "[[Kotus]] type 26/[[Appendix:Finnish nominal inflection/pieni|pieni]], no gradation"
	table.insert(data.categories, "Finnish pieni-type nominals")
	
	local params = get_params(args, 2)
	local par_sg_a = args["par_sg_a"]; if par_sg_a and par_sg_a ~= "a" and par_sg_a ~= "ä" then error("Parameter \"par_sg_a=\" must be \"a\" or \"ä\".") end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "i"}
	stems["sg"]      = {params.base .. "e"}
	stems["par_sg"]  = {params.base .. "t"}
	stems["pl"]      = {params.base .. "i"}
	stems["gen_pl"]  = {params.base .. "t", params.base .. "i"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	if par_sg_a then
		data.forms["par_sg"] = {}
		
		for _, stem in ipairs(stems["par_sg"]) do
			table.insert(data.forms["par_sg"], stem .. par_sg_a)
		end
	end
end

inflections["käsi"] = function(args, data)
	data.title = "[[Kotus]] type 27/[[Appendix:Finnish nominal inflection/käsi|käsi]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish käsi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "si"}
	stems["sg"]      = {params.base .. "te"}
	stems["sg_weak"] = {params.base .. "de"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "si"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "tten"}
end

inflections["kynsi"] = function(args, data)
	data.title = "[[Kotus]] type 28/[[Appendix:Finnish nominal inflection/kynsi|kynsi]]"
	table.insert(data.categories, "Finnish kynsi-type nominals")
	
	local params = get_params(args, 2, false, "n")
	local cons = ustring.match(params.base, "([lnr]?)$")
	
	-- if mw.title.getCurrentTitle().nsText ~= "Template" and cons == "" then
	-- 	error("Stem must end in \"l\", \"n\" or \"r\".")
	-- end
	
	data.title = data.title .. ", ''" .. cons .. "t-" .. cons .. cons .. "'' gradation"
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "si"}
	stems["sg"]      = {params.base .. "te"}
	stems["sg_weak"] = {params.base .. cons .. "e"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "si"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "tten"}
end

inflections["lapsi"] = function(args, data)
	data.title = "[[Kotus]] type 29/[[Appendix:Finnish nominal inflection/lapsi|lapsi]], no gradation"
	table.insert(data.categories, "Finnish lapsi-type nominals")
	
	local params = get_params(args, 2, false, "p")
	local syncopated_stem, cons = ustring.match(params.base, "^(.-)([kp]?)$")
	
	-- if mw.title.getCurrentTitle().nsText ~= "Template" and cons == "" then
	-- 	error("Stem must end in \"k\" or \"p\".")
	-- end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "si"}
	stems["sg"]      = {params.base .. "se"}
	stems["par_sg"]  = {syncopated_stem .. "st"}
	stems["pl"]      = {params.base .. "si"}
	stems["gen_pl"]  = {params.base .. "si", syncopated_stem .. "st"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["veitsi"] = function(args, data)
	data.title = "[[Kotus]] type 30/[[Appendix:Finnish nominal inflection/veitsi|veitsi]], no gradation"
	table.insert(data.categories, "Finnish veitsi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "tsi"}
	stems["sg"]      = {params.base .. "tse"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "tsi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "sten"}
end

inflections["kaksi"] = function(args, data)
	data.title = "[[Kotus]] type 31/[[Appendix:Finnish nominal inflection/kaksi|kaksi]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish kaksi-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "ksi"}
	stems["sg"]      = {params.base .. "hte"}
	stems["sg_weak"] = {params.base .. "hde"}
	stems["par_sg"]  = {params.base .. "ht"}
	stems["pl"]      = {params.base .. "ksi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["sisar"] = function(args, data)
	data.title = "[[Kotus]] type 32/[[Appendix:Finnish nominal inflection/sisar|sisar]]"
	table.insert(data.categories, "Finnish sisar-type nominals")
	
	local params = get_params(args, 5, true)
	local nom_sg = args["nom_sg"]; if nom_sg == "" then nom_sg = nil end
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.strong == params.weak then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. params.weak .. params.final}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "e"}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "t"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["gen_pl"]  = {params.base .. params.strong .. params.final .. "i", params.base .. params.weak .. params.final .. "t"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kytkin"] = function(args, data)
	data.title = "[[Kotus]] type 33/[[Appendix:Finnish nominal inflection/kytkin|kytkin]]"
	table.insert(data.categories, "Finnish kytkin-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "n"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "me"}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "nt"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "mi"}
	stems["gen_pl"]  = {params.base .. params.strong .. params.final .. "mi", params.base .. params.weak .. params.final .. "nt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["onneton"] = function(args, data)
	data.title = "[[Kotus]] type 34/[[Appendix:Finnish nominal inflection/onneton|onneton]], ''tt-t'' gradation"
	table.insert(data.categories, "Finnish onneton-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "t" .. params.o .. "n"}
	stems["sg"]      = {params.base .. "tt" .. params.o .. "m" .. params.a}
	stems["par_sg"]  = {params.base .. "t" .. params.o .. "nt"}
	stems["pl"]      = {params.base .. "tt" .. params.o .. "mi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "t" .. params.o .. "nten"}
end

inflections["lämmin"] = function(args, data)
	data.title = "[[Kotus]] type 35/[[Appendix:Finnish nominal inflection/lämmin|lämmin]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish lämmin-type nominals")
	
	local params = get_params(args, 1)
	params.base = params.base .. "lä"
	params.a = "ä"
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "mmin"}
	stems["sg"]      = {params.base .. "mpim" .. params.a}
	stems["par_sg"]  = {params.base .. "mmint"}
	stems["pl"]      = {params.base .. "mpimi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "mpim" .. params.a .. "in"}
end

inflections["sisin"] = function(args, data)
	data.title = "[[Kotus]] type 36/[[Appendix:Finnish nominal inflection/sisin|sisin]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish sisin-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "in"}
	stems["sg"]      = {params.base .. "imp" .. params.a}
	stems["sg_weak"] = {params.base .. "imm" .. params.a}
	stems["par_sg"]  = {params.base .. "int"}
	stems["pl"]      = {params.base .. "impi"}
	stems["pl_weak"] = {params.base .. "immi"}
	stems["gen_pl"]  = {params.base .. "impi", params.base .. "int"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "imp" .. params.a .. "in"}
end

inflections["vasen"] = function(args, data)
	data.title = "[[Kotus]] type 37/[[Appendix:Finnish nominal inflection/vasen|vasen]], ''mp-mm'' gradation"
	table.insert(data.categories, "Finnish vasen-type nominals")
	
	local params = get_params(args, 1)
	params.base = params.base .. "vase"
	params.a = "a"
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "n"}
	stems["sg"]      = {params.base .. "mp" .. params.a}
	stems["sg_weak"] = {params.base .. "mm" .. params.a}
	stems["par_sg"]  = {params.base .. "nt", params.base .. "mp" .. params.a}
	stems["pl"]      = {params.base .. "mpi"}
	stems["pl_weak"] = {params.base .. "mmi"}
	stems["gen_pl"]  = {params.base .. "mpi", params.base .. "nt"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "mp" .. params.a .. "in"}
end

inflections["nainen"] = function(args, data)
	data.title = "[[Kotus]] type 38/[[Appendix:Finnish nominal inflection/nainen|nainen]], no gradation"
	table.insert(data.categories, "Finnish nainen-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "nen"}
	stems["sg"]      = {params.base .. "se"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "si"}
	stems["gen_pl"]  = {params.base .. "st", params.base .. "si"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["vastaus"] = function(args, data)
	data.title = "[[Kotus]] type 39/[[Appendix:Finnish nominal inflection/vastaus|vastaus]], no gradation"
	table.insert(data.categories, "Finnish vastaus-type nominals")
	
	local params = get_params(args, 2)
	local nom_sg = args["nom_sg"]; if nom_sg == "" then nom_sg = nil end
	
	local stems = {}
	stems["nom_sg"]  = {nom_sg or params.base .. "s"}
	stems["sg"]      = {params.base .. "kse"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "ksi"}
	stems["gen_pl"]  = {params.base .. "st", params.base .. "ksi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kalleus"] = function(args, data)
	data.title = "[[Kotus]] type 40/[[Appendix:Finnish nominal inflection/kalleus|kalleus]], ''t-d'' gradation"
	table.insert(data.categories, "Finnish kalleus-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "s"}
	stems["sg"]      = {params.base .. "te"}
	stems["sg_weak"] = {params.base .. "de"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "ksi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["vieras"] = function(args, data)
	data.title = "[[Kotus]] type 41/[[Appendix:Finnish nominal inflection/vieras|vieras]]"
	table.insert(data.categories, "Finnish vieras-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "s"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. params.final}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "st"}
	stems["ill_sg"]  = {params.base .. params.strong .. params.final .. params.final .. "se"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["ill_pl"].rare = {params.base .. params.strong .. params.final .. "ihin"}
end

inflections["mies"] = function(args, data)
	data.title = "[[Kotus]] type 42/[[Appendix:Finnish nominal inflection/mies|mies]], no gradation"
	table.insert(data.categories, "Finnish mies-type nominals")
	
	local params = get_params(args, 1)
	params.base = params.base .. "mie"
	params.a = "ä"
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "s"}
	stems["sg"]      = {params.base .. "he"}
	stems["par_sg"]  = {params.base .. "st"}
	stems["pl"]      = {params.base .. "hi"}
	stems["gen_pl"]  = {params.base .. "st", params.base .. "hi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["ohut"] = function(args, data)
	data.title = "[[Kotus]] type 43/[[Appendix:Finnish nominal inflection/ohut|ohut]]"
	table.insert(data.categories, "Finnish ohut-type nominals")
	
	local params = get_params(args, 5, true)
	
	make_weak(params.base, params.strong, params.final, params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. params.final .. "t"}
	stems["sg"]      = {params.base .. params.strong .. params.final .. "e"}
	stems["par_sg"]  = {params.base .. params.weak .. params.final .. "tt"}
	stems["pl"]      = {params.base .. params.strong .. params.final .. "i"}
	stems["par_pl"]  = {params.base .. params.strong .. params.final .. "it"}
	stems["ill_pl"]  = {params.base .. params.strong .. params.final .. "isi", params.base .. params.strong .. params.final .. "ih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["kevät"] = function(args, data)
	data.title = "[[Kotus]] type 44/[[Appendix:Finnish nominal inflection/kevät|kevät]], no gradation"
	table.insert(data.categories, "Finnish kevät-type nominals")
	
	local params = get_params(args, 2)
	local vowel = ustring.sub(params.base, -1)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "t"}
	stems["sg"]      = {params.base .. vowel}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["ill_sg"]  = {params.base .. vowel .. "se"}
	stems["pl"]      = {params.base .. "i"}
	stems["par_pl"]  = {params.base .. "it"}
	stems["ill_pl"]  = {params.base .. "isi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["ill_pl"].rare = {params.base .. "ihin"}
end

inflections["kahdeksas"] = function(args, data)
	data.title = "[[Kotus]] type 45/[[Appendix:Finnish nominal inflection/kahdeksas|kahdeksas]], ''nt-nn'' gradation"
	table.insert(data.categories, "Finnish kahdeksas-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "s"}
	stems["sg"]      = {params.base .. "nte"}
	stems["sg_weak"] = {params.base .. "nne"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "nsi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["tuhat"] = function(args, data)
	data.title = "[[Kotus]] type 46/[[Appendix:Finnish nominal inflection/tuhat|tuhat]], ''nt-nn'' gradation"
	table.insert(data.categories, "Finnish tuhat-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. "t"}
	stems["sg"]      = {params.base .. "nte"}
	stems["sg_weak"] = {params.base .. "nne"}
	stems["par_sg"]  = {params.base .. "tt"}
	stems["pl"]      = {params.base .. "nsi"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
	
	-- data.forms["gen_pl"].rare = {params.base .. "nten"}
end

inflections["kuollut"] = function(args, data)
	data.title = "[[Kotus]] type 47/[[Appendix:Finnish nominal inflection/kuollut|kuollut]], no gradation"
	table.insert(data.categories, "Finnish kuollut-type nominals")
	
	local params = get_params(args, 2)
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.u .. "t"}
	stems["sg"]      = {params.base .. "ee"}
	stems["par_sg"]  = {params.base .. params.u .. "tt"}
	stems["ill_sg"]  = {params.base .. "eese"}
	stems["pl"]      = {params.base .. "ei"}
	stems["par_pl"]  = {params.base .. "eit"}
	stems["ill_pl"]  = {params.base .. "eisi", params.base .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end

inflections["hame"] = function(args, data)
	data.title = "[[Kotus]] type 48/[[Appendix:Finnish nominal inflection/hame|hame]]"
	table.insert(data.categories, "Finnish hame-type nominals")
	
	local params = get_params(args, 4, true)
	
	make_weak(params.base, params.strong, "e", params.weak)
	
	if params.weak == params.strong then
		data.title = data.title .. ", no gradation"
	else
		data.title = data.title .. ", ''" .. params.strong .. "-" .. params.weak .. "'' gradation"
	end
	
	local stems = {}
	stems["nom_sg"]  = {params.base .. params.weak .. "e"}
	stems["sg"]      = {params.base .. params.strong .. "ee"}
	stems["par_sg"]  = {params.base .. params.weak .. "ett"}
	stems["ill_sg"]  = {params.base .. params.strong .. "eese"}
	stems["pl"]      = {params.base .. params.strong .. "ei"}
	stems["par_pl"]  = {params.base .. params.strong .. "eit"}
	stems["ill_pl"]  = {params.base .. params.strong .. "eisi", params.base .. params.strong .. "eih"}
	
	make_stems(data, stems)
	process_stems(data, stems, params.a)
end


-- Helper functions

function postprocess(args, data)
	local pos = args["pos"]; if not pos or pos == "" then pos = "noun" end
	local nosg = args["nosg"]; if nosg == "" then nosg = nil end
	local nopl = args["nopl"]; if nopl == "" then nopl = nil end
	local n = args["n"]; if n == "" then n = nil end
	local suffix = args["suffix"]; if suffix == "" then suffix = nil end
	local appendix = args["appendix"]; if appendix == "" then appendix = nil end
	local has_ins_sg = args["has_ins_sg"]; if has_ins_sg == "" then has_ins_sg = nil end
	
	-- Add the possessive suffix to the comitative plural, if the word is a noun
	if pos == "noun" and data.forms["com_pl"] then
		for key, subform in ipairs(data.forms["com_pl"]) do
			data.forms["com_pl"][key] = subform .. "en"
		end
	end
	
	if nosg or n == "pl" then
		table.insert(data.categories, "Finnish pluralia tantum")
	end
	
	-- TODO: This says "nouns", but this module is also used for adjectives!
	if nopl or n == "sg" then
		table.insert(data.categories, "Finnish uncountable nouns")
	end
	
	if not has_ins_sg then
		data.forms["ins_sg"] = nil
	end
	
	for key, form in pairs(data.forms) do
		-- Add suffix to forms
		for i, subform in ipairs(form) do
			subform = subform .. (suffix or "")
			form[i] = subform
		end
		
		if form.rare then
			for i, subform in ipairs(form.rare) do
				subform = subform .. (suffix or "")
				form.rare[i] = subform
			end
		end
		
		-- Do not show singular or plural forms for nominals that don't have them
		if ((nosg or n == "pl") and key:find("_sg$")) or ((nopl or n == "sg") and key:find("_pl$")) then
			form = nil
		end
		
		data.forms[key] = form
	end
	
	-- Check if the lemma form matches the page name
	-- if not appendix and lang:makeEntryName(data.forms[(nosg or n == "pl") and "nom_pl" or "nom_sg"][1]) ~= mw.title.getCurrentTitle().text then
	-- 	table.insert(data.categories, "Finnish entries with inflection not matching pagename")
	-- end
end

export.inflections = inflections
return export
