local uci = require("simple-uci").cursor()

local f = Element("runtime/apply", {
	unsaved = uci:get_bool('gluon', 'core', 'reconfigure'),
}, 'apply')
f.template = "runtime/apply"
f.package = "ffgraz-config-mode-at-runtime"

function f:hasvalue(http, value, fnc)
	if http:getenv("REQUEST_METHOD") == "POST" and http:formvalue(value) ~= nil then
		fnc()
	end
end

function f:reconfigure(msg, cmdname)
	local fcntl = require 'posix.fcntl'
	local unistd = require 'posix.unistd'

	local cmd = io.popen('(gluon-reconfigure) 2>&1')
	if not cmd then
		self.error = translate('Failed to execute reconfigure')
		return
	end
	local lines = cmd:read('*a')
	-- TODO: check exit code
	-- local exit = cmd:close()
	cmd:close()

	self.output = lines
	self.outputmsg = translate(msg)
	self.hidenav = true

	if unistd.fork() == 0 then
		-- Replace stdout with /dev/null
		local null = fcntl.open('/dev/null', fcntl.O_WRONLY)
		unistd.dup2(null, unistd.STDOUT_FILENO)
		unistd.dup2(null, unistd.STDERR_FILENO)

		-- Sleep a little so the browser can fetch everything required to
		-- display the reboot page, then run the command
		unistd.sleep(2)

		unistd.execp(cmdname, {[0] = cmdname})
	end
end

function f:parse(http)
	-- simply sets form valid
	Element.parse(self, http)

	self:hasvalue(http, 'apply_reboot', function()
		self:reconfigure('Applied! Rebooting...', 'reboot')
	end)

	self:hasvalue(http, 'apply_reload', function()
		self:reconfigure('Applied! Reloading...', 'gluon-reload')
	end)
end

return f
