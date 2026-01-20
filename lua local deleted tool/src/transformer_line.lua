local TransformerLine = {}
function TransformerLine.new(source, tokens, options)
  local self = {
    source = source,
    lines = {},
    tokens = tokens,
    options = options or {},
    replacements = {},
  }
  for l in source:gmatch('([^\n]*)\n?') do table.insert(self.lines, l) end
  return setmetatable(self, { __index = TransformerLine })
end

function TransformerLine:apply()
  local t = self.tokens
  local mode = self.options.mode or 'remove_function_local'
  
  if mode == 'outcode' then
    local out_lines = {}
    local i = 1

    local function strip_inline_comment(line)
      local res = {}
      local in_str = false
      local qchar = nil
      local esc = false
      local n = #line
      local idx = 1
      while idx <= n do
        local ch = line:sub(idx,idx)
        if in_str then
          if esc then
            esc = false
            table.insert(res, ch)
          elseif ch == '\\' then
            esc = true
            table.insert(res, ch)
          elseif ch == qchar then
            in_str = false
            qchar = nil
            table.insert(res, ch)
          else
            table.insert(res, ch)
          end
          idx = idx + 1
        else
          if ch == '"' or ch == "'" then
            in_str = true
            qchar = ch
            table.insert(res, ch)
            idx = idx + 1
          else
            local two = line:sub(idx, idx+1)
            if two == '--' then
              break
            else
              table.insert(res, ch)
              idx = idx + 1
            end
          end
        end
      end
      return table.concat(res)
    end

    while i <= #self.lines do
      local line = self.lines[i]
      local s = line:match('^(%s*)%-%-%[%[')
      if s then
        local j = i
        local found = false
        while j <= #self.lines do
          if self.lines[j]:find('%]%]') then found = true; break end
          j = j + 1
        end
        if found then
          i = j + 1
        else
          break
        end
      else
        local trimmed = line:match('^%s*(.*)') or ''
        if trimmed:sub(1,2) == '--' then
        else
          local newl = strip_inline_comment(line)
          newl = newl:gsub('%s+$','')
          table.insert(out_lines, newl)
        end
        i = i + 1
      end
    end

    return table.concat(out_lines, '\n')
  end
  local i = 1
  local function_depth = 0

  while i <= #t do
    local tok = t[i]
    if tok.type == 'FUNCTION' then
      function_depth = function_depth + 1
      i = i + 1
    elseif tok.type == 'END' then
      if function_depth > 0 then function_depth = function_depth - 1 end
      i = i + 1
    elseif tok.type == 'LOCAL' then
      local in_function = function_depth > 0
      local remove = false
      local is_func_decl = false
      local nexttok = t[i+1] or {type='EOF'}
      if nexttok.type == 'FUNCTION' then
        is_func_decl = true
      end

      if mode == 'remove_function_local' or mode == 'remove_function_local_all' then
        remove = is_func_decl
      elseif mode == 'remove_function_local_function' then
        remove = is_func_decl and in_function
      elseif mode == 'remove_function_local_global' then
        remove = is_func_decl and not in_function
      elseif mode == 'remove_global_local' then
        remove = not in_function
      elseif mode == 'remove_all_local' then
        remove = true
      elseif mode == 'remove_local_keyword_function' then
        remove = in_function
      elseif mode == 'remove_local_keyword_global' then
        remove = not in_function
      elseif mode == 'remove_local_keyword_all' then
        remove = true
      elseif mode == 'remove_local_boolean_function' or mode == 'remove_local_boolean_global' or mode == 'remove_local_boolean_all' then
        local scope_ok = false
        if mode == 'remove_local_boolean_all' then scope_ok = true end
        if mode == 'remove_local_boolean_function' then scope_ok = in_function end
        if mode == 'remove_local_boolean_global' then scope_ok = not in_function end
        if scope_ok then
          local j = i+1
          while j <= #t and t[j].type ~= 'ASSIGN' and t[j].type ~= 'SEMICOLON' and t[j].type ~= 'EOF' do j = j + 1 end
          if t[j] and t[j].type == 'ASSIGN' and t[j+1] then
            local valtok = t[j+1]
            if valtok.type == 'TRUE' or valtok.type == 'FALSE' then remove = true end
          end
        end
      elseif mode == 'remove_local_string_function' or mode == 'remove_local_string_global' or mode == 'remove_local_string_all' then
        local scope_ok = false
        if mode == 'remove_local_string_all' then scope_ok = true end
        if mode == 'remove_local_string_function' then scope_ok = in_function end
        if mode == 'remove_local_string_global' then scope_ok = not in_function end
        if scope_ok then
          local j = i+1
          while j <= #t and t[j].type ~= 'ASSIGN' and t[j].type ~= 'SEMICOLON' and t[j].type ~= 'EOF' do j = j + 1 end
          if t[j] and t[j].type == 'ASSIGN' and t[j+1] then
            local valtok = t[j+1]
            if valtok.type == 'STRING' then remove = true end
          end
        end
      elseif mode == 'remove_local_table_function' or mode == 'remove_local_table_global' or mode == 'remove_local_table_all' then
        local scope_ok = false
        if mode == 'remove_local_table_all' then scope_ok = true end
        if mode == 'remove_local_table_function' then scope_ok = in_function end
        if mode == 'remove_local_table_global' then scope_ok = not in_function end
        if scope_ok then
          local j = i+1
          while j <= #t and t[j].type ~= 'ASSIGN' and t[j].type ~= 'SEMICOLON' and t[j].type ~= 'EOF' do j = j + 1 end
          if t[j] and t[j].type == 'ASSIGN' and t[j+1] then
            local valtok = t[j+1]
            if valtok.type == 'LBRACE' then remove = true end
          end
        end
      else
        remove = false
      end
      local assigned_function = false
      do
        local j = i+1
        while j <= #t and t[j].type ~= 'SEMICOLON' and t[j].type ~= 'EOF' do
          if t[j].type == 'ASSIGN' then
            local k = j+1
            while k <= #t and t[k].type ~= 'SEMICOLON' and t[k].type ~= 'COMMA' and t[k].type ~= 'EOF' do
              if t[k].type == 'FUNCTION' then assigned_function = true; break end
              k = k + 1
            end
            break
          end
          if t[j].type == 'FUNCTION' then assigned_function = true; break end
          j = j + 1
        end
      end
      if assigned_function then
        is_func_decl = true
      end
      if remove then
        local line = tok.line
        local col = tok.col
        if type(line) ~= 'number' or line < 1 or line > #self.lines then
          line = nil
        end
        if line then
          local orig = (self.replacements[line] or self.lines[line] or '')
          if orig == '' then
            line = nil
          else
            if type(col) ~= 'number' then col = 1 end
            col = math.max(1, math.min(#orig+1, col))
            local before = orig:sub(1, col-1)
            local rest = orig:sub(col)
            local newrest, n = rest:gsub('^%s*local%s*', '', 1)
            if n == 0 then
              newrest, n = rest:gsub('\flocal\f', '', 1)
            end
            local replaced = before .. (newrest ~= '' and newrest or rest:gsub('^%s*local%s*', '', 1))
            if replaced:sub(1,1) == ' ' then replaced = replaced:sub(2) end
            self.replacements[line] = replaced
          end
          end

          end

          i = i + 1
    else
      i = i + 1
    end
  end
  local out = {}
  for idx, ln in ipairs(self.lines) do
    if self.replacements[idx] then
      table.insert(out, self.replacements[idx])
    else
      table.insert(out, ln)
    end
  end
  return table.concat(out, '\n')
end

return TransformerLine