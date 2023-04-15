local platform = require 'gluon.platform'


local M = {}

function M.supports_networked_activation()
	if platform.match('ramips', 'mt7621', {
		'zyxel,nwa55axe',
	}) then
		return true
	end
end

return M
