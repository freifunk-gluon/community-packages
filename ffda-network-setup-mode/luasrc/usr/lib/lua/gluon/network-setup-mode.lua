local platform = require 'gluon.platform'


local M = {}

function M.supports_networked_activation()
    return
        platform.match('ramips', 'mt7621', {
            'zyxel,nwa55axe',
        })
        or
        platform.match('ath79', 'generic', {
            'sophos,ap15',
        })
end

return M
