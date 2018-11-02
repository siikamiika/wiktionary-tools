local ustring = require("ustring")

local export = {}

function export.make_weak(before, strong, after, check)
	local weak = strong
	
	if strong == "pp" then
		weak = "p"
	elseif strong == "tt" then
		weak = "t"
	elseif strong == "kk" then
		weak = "k"
	elseif strong == "bb" then
		weak = "b"
	elseif strong == "dd" then
		weak = "d"
	elseif strong == "gg" then
		weak = "g"
	elseif strong == "p" then
		if ustring.find(before, "p$") then
			weak = ""
		elseif ustring.find(before, "m$") then
			weak = "m"
		else
			weak = "v"
		end
	elseif strong == "t" then
		if ustring.find(before, "t$") then
			weak = ""
		elseif ustring.find(before, "[lnr]$") then
			weak = ustring.sub(before, -1)
		else
			weak = "d"
		end
	elseif strong == "k" then
		if ustring.find(before, "k$") then
			weak = ""
		elseif ustring.find(before, "n$") then
			weak = "g"
		elseif ustring.find(before, "[hlr]$") and ustring.find(after, "^e") then
			weak = "j"
		elseif ustring.find(before .. "|" .. after, "[^aeiouyäö]([uy])|%1") then
			weak = "v"
		else
			weak = ""
		end
	elseif strong == "ik" then
		weak = "j"
	elseif strong == "mp" then
		weak = "mm"
	elseif strong == "lt" then
		weak = "ll"
	elseif strong == "nt" then
		weak = "nn"
	elseif strong == "rt" then
		weak = "rr"
	elseif strong == "nk" then
		weak = "ng"
	end
	
	if weak ~= check then
		-- require("debug").track("fi-utilities/make weak mismatch")
	end
end

return export
