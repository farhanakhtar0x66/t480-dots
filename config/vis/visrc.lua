require('vis')

local pending_clipboard_yank = false

vis.events.subscribe(vis.events.INIT, function()
  vis:command('set theme github-dark')
  -- Use the system clipboard for ordinary yanks; explicit registers still work.
  local function system_yank()
    if vis.register == '"' or vis.register == '' then pending_clipboard_yank = true end
    vis:feedkeys('<vis-operator-yank>')
  end
  vis:map(vis.modes.NORMAL, 'y', system_yank, 'Yank to clipboard')
  vis:map(vis.modes.VISUAL, 'y', system_yank, 'Yank to clipboard')
  vis:map(vis.modes.VISUAL_LINE, 'y', system_yank, 'Yank to clipboard')
  vis:map(vis.modes.OPERATOR_PENDING, '<Escape>', function()
    pending_clipboard_yank = false
    vis:feedkeys('<vis-mode-normal-escape>')
  end, 'Cancel operator')
end)

vis.events.subscribe(vis.events.WIN_OPEN, function()
  vis:command('set number')
  vis:command('set relativenumbers')
  vis:command('set cursorline')
  vis:command('set autoindent')
end)

vis.events.subscribe(vis.events.WIN_STATUS, function(win)
  local modes = {[vis.modes.NORMAL]='NORMAL', [vis.modes.INSERT]='INSERT',
    [vis.modes.VISUAL]='VISUAL', [vis.modes.VISUAL_LINE]='V-LINE',
    [vis.modes.REPLACE]='REPLACE', [vis.modes.OPERATOR_PENDING]='NORMAL'}
  local file=win.file
  local name=file.name or '[No Name]'
  local mode=(win == vis.win and (modes[vis.mode] or 'NORMAL') or '')
  local loc=win.selection
  win:status(' ' .. mode .. '  ' .. name .. (file.modified and ' [+]' or '') .. ' ',
    ' ' .. (win.syntax or 'text') .. '  ' .. loc.line .. ':' .. loc.col .. ' ')
end)

-- Mirror a completed default yank while preserving Vis's own paste register.
vis.events.subscribe(vis.events.UI_DRAW, function()
  if pending_clipboard_yank and vis.mode ~= vis.modes.OPERATOR_PENDING then
    pending_clipboard_yank = false
    local copied = vis.registers['"']
    if copied and copied[1] and copied[1] ~= '' then
      local pipe = io.popen('xclip -selection clipboard -i', 'w')
      if pipe then pipe:write((copied[1]:gsub('%z$', ''))); pipe:close() end
    end
  end
end)
