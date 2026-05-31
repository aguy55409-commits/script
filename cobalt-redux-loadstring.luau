-- Cobalt Redux loader — join a game first, then execute (Potassium / Synapse / etc.)
-- Private repo: set GITHUB_TOKEN below (classic PAT or fine-grained with Contents: Read on this repo)

local GITHUB_TOKEN = "" -- e.g. "ghp_xxxxxxxx" or "github_pat_xxxxxxxx"

local REPO = "aguy55409-commits/script"
local BRANCH = "main"
local FILE = "cobalt-redux.luau"

local function httpFetch(url, headers)
	headers = headers or {}

	if syn and syn.request then
		return syn.request({ Url = url, Method = "GET", Headers = headers })
	end
	if http and http.request then
		return http.request({ Url = url, Method = "GET", Headers = headers })
	end
	if request then
		return request({ Url = url, Method = "GET", Headers = headers })
	end
	return nil
end

local function fetchScript()
	local rawUrl = ("https://raw.githubusercontent.com/%s/%s/%s"):format(REPO, BRANCH, FILE)
	local apiUrl = ("https://api.github.com/repos/%s/contents/%s?ref=%s"):format(REPO, FILE, BRANCH)

	if GITHUB_TOKEN ~= "" then
		local auth = { Authorization = "Bearer " .. GITHUB_TOKEN }

		local apiResp = httpFetch(apiUrl, {
			Authorization = auth.Authorization,
			Accept = "application/vnd.github.raw",
			["User-Agent"] = "CobaltReduxLoader",
		})
		if apiResp and apiResp.Body and #apiResp.Body > 1000 then
			return apiResp.Body
		end

		local rawResp = httpFetch(rawUrl, {
			Authorization = auth.Authorization,
			["User-Agent"] = "CobaltReduxLoader",
		})
		if rawResp and rawResp.Body and #rawResp.Body > 1000 then
			return rawResp.Body
		end
	end

	local ok, body = pcall(function()
		return game:HttpGet(rawUrl, true)
	end)
	if ok and body and #body > 1000 then
		return body
	end

	error(
		"Download failed. Private repo needs GITHUB_TOKEN in loader, "
			.. "or make the repo public, or paste cobalt-redux.luau from your PC."
	)
end

local ok, err = pcall(function()
	local body = fetchScript()
	local fn = loadstring(body)
	if not fn then
		error("loadstring returned nil")
	end
	fn()
end)

if not ok then
	warn("[Cobalt Redux] Load failed:\n" .. tostring(err))
end
