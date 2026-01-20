local CodeGen = {}

function CodeGen.new(source)
  local self = {
    source = source or '',
    source_lines = {},
    indent_level = 0,
    indent_str = '  '
  }
  if source then
    for line in source:gmatch('[^\n]*') do
      table.insert(self.source_lines, line)
    end
  end
  
  return setmetatable(self, { __index = CodeGen })
end

function CodeGen:get_indent()
  return string.rep(self.indent_str, self.indent_level)
end

function CodeGen:get_original_indent(line_content)
  local indent = line_content:match('^(%s*)')
  return indent or ''
end

function CodeGen:preserve_indent_for_line(generated_line)
  if #self.source_lines == 0 then
    return generated_line
  end
  local trimmed = generated_line:gsub('^%s+', '')
  
  if trimmed == '' then
    return generated_line
  end
  for _, src_line in ipairs(self.source_lines) do
    local src_trimmed = src_line:gsub('^%s+', '')
    if src_trimmed == trimmed then
      local src_indent = src_line:match('^(%s*)')
      return src_indent .. trimmed
    end
  end
  return generated_line
end

function CodeGen:generate(ast)
  if not ast then return '' end
  
  if ast.type == 'Chunk' then
    return self:generate_chunk(ast)
  elseif ast.type == 'Block' then
    return self:generate_block(ast)
  elseif ast.type == 'LocalDecl' then
    return self:generate_local_decl(ast)
  elseif ast.type == 'LocalFunc' then
    return self:generate_local_func(ast)
  elseif ast.type == 'FunctionDecl' then
    return self:generate_function_decl(ast)
  elseif ast.type == 'Function' then
    return self:generate_function(ast)
  elseif ast.type == 'If' then
    return self:generate_if(ast)
  elseif ast.type == 'While' then
    return self:generate_while(ast)
  elseif ast.type == 'Repeat' then
    return self:generate_repeat(ast)
  elseif ast.type == 'For' then
    return self:generate_for(ast)
  elseif ast.type == 'ForIn' then
    return self:generate_for_in(ast)
  elseif ast.type == 'Do' then
    return self:generate_do(ast)
  elseif ast.type == 'Assignment' then
    return self:generate_assignment(ast)
  elseif ast.type == 'Return' then
    return self:generate_return(ast)
  elseif ast.type == 'Break' then
    return self:get_indent() .. 'break'
  elseif ast.type == 'BinaryOp' then
    return self:generate_binary_op(ast)
  elseif ast.type == 'UnaryOp' then
    return self:generate_unary_op(ast)
  elseif ast.type == 'FunctionCall' then
    return self:generate_function_call(ast)
  elseif ast.type == 'MethodCall' then
    return self:generate_method_call(ast)
  elseif ast.type == 'IndexExpr' then
    return self:generate_index_expr(ast)
  elseif ast.type == 'PropertyExpr' then
    return self:generate_property_expr(ast)
  elseif ast.type == 'Identifier' then
    return ast.name
  elseif ast.type == 'Number' then
    return tostring(ast.value)
  elseif ast.type == 'String' then
    return string.format('%q', ast.value)
  elseif ast.type == 'Boolean' then
    return ast.value and 'true' or 'false'
  elseif ast.type == 'Nil' then
    return 'nil'
  elseif ast.type == 'VarArgs' then
    return '...'
  elseif ast.type == 'Table' then
    return self:generate_table(ast)
  else
    return ''
  end
end

function CodeGen:generate_chunk(node)
  local body = node.body
  if not body or not body.statements then
    return ''
  end
  local replacements = {}
  local function collect(node)
    if not node or type(node) ~= 'table' then return end
    if node.modified and node.source_line and self.source_lines then
      local generated = self:generate(node)
      local trimmed = generated:gsub('^%s+', '')
      replacements[node.source_line] = { text = trimmed, type = node.type }
    end
    if node.body and node.body.statements then
      for _, s in ipairs(node.body.statements) do collect(s) end
    end
    if node.then_body then collect(node.then_body) end
    if node.else_body then collect(node.else_body) end
    if node.elseif_parts then
      for _, p in ipairs(node.elseif_parts) do collect(p.body) end
    end
    if node.type == 'FunctionDecl' or node.type == 'Function' then
      if node.body and node.body.statements then
        for _, s in ipairs(node.body.statements) do collect(s) end
      end
    end
    if node.statements then
      for _, s in ipairs(node.statements) do collect(s) end
    end
  end
  collect(node)
  local out_lines = {}
  for i, src_line in ipairs(self.source_lines) do
    local rep = replacements[i]
    if rep then
      local indent = src_line:match('^(%s*)') or ''
      if rep.type == 'FunctionDecl' or rep.type == 'Function' then
        local first_line = rep.text:match('([^\n]*)') or rep.text
        table.insert(out_lines, indent .. first_line)
      else
        table.insert(out_lines, indent .. rep.text)
      end
    else
      table.insert(out_lines, src_line)
    end
  end

  return table.concat(out_lines, '\n')
end

function CodeGen:generate_block(node)
  local lines = {}
  for _, stmt in ipairs(node.statements) do
    local code
    if stmt.modified and stmt.source_line and self.source_lines then
      local original_line = self.source_lines[stmt.source_line]
      local original_indent = original_line:match('^(%s*)')
      local generated = self:generate(stmt)
      local trimmed = generated:gsub('^%s+', '')
      code = original_indent .. trimmed
    elseif stmt.source_line and self.source_lines then
      code = self.source_lines[stmt.source_line]
    else
      code = self:generate(stmt)
    end
    
    if code ~= '' then
      table.insert(lines, code)
    end
  end
  
  return table.concat(lines, '\n')
end


function CodeGen:generate_local_decl(node)
  local names = table.concat(node.names, ', ')
  local line = self:get_indent() .. 'local ' .. names
  
  if #node.values > 0 then
    local values = {}
    for _, value in ipairs(node.values) do
      table.insert(values, self:generate(value))
    end
    line = line .. ' = ' .. table.concat(values, ', ')
  end
  
  return self:preserve_indent_for_line(line)
end

function CodeGen:generate_local_func(node)
  local func = self:generate(node.body)
  local lines = self:split_code(func)
  
  if #lines > 0 then
    lines[1] = self:get_indent() .. 'local function ' .. node.name .. lines[1]:sub(#self:get_indent() + 1)
  end
  
  return table.concat(lines, '\n')
end

function CodeGen:generate_function_decl(node)
  local function_keyword = 'function'
  local line = self:get_indent() .. function_keyword .. ' ' .. node.name .. '('
  
  if #node.params > 0 then
    line = line .. table.concat(node.params, ', ')
  end
  
  line = line .. ')'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'end'
end

function CodeGen:generate_function(node)
  local line = 'function('
  
  if #node.params > 0 then
    line = line .. table.concat(node.params, ', ')
  end
  
  if node.has_varargs then
    if #node.params > 0 then
      line = line .. ', ...'
    else
      line = line .. '...'
    end
  end
  
  line = line .. ')'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'end'
end

function CodeGen:generate_if(node)
  local line = self:get_indent() .. 'if ' .. self:generate(node.condition) .. ' then'
  
  self.indent_level = self.indent_level + 1
  local then_body = self:generate(node.then_body)
  self.indent_level = self.indent_level - 1
  
  local result = line .. '\n' .. then_body
  
  if node.elseif_parts then
    for _, part in ipairs(node.elseif_parts) do
      result = result .. '\n' .. self:get_indent() .. 'elseif ' .. self:generate(part.condition) .. ' then'
      
      self.indent_level = self.indent_level + 1
      local elseif_body = self:generate(part.body)
      self.indent_level = self.indent_level - 1
      
      result = result .. '\n' .. elseif_body
    end
  end
  
  if node.else_body then
    result = result .. '\n' .. self:get_indent() .. 'else'
    
    self.indent_level = self.indent_level + 1
    local else_body = self:generate(node.else_body)
    self.indent_level = self.indent_level - 1
    
    result = result .. '\n' .. else_body
  end
  
  result = result .. '\n' .. self:get_indent() .. 'end'
  
  return result
end

function CodeGen:generate_while(node)
  local line = self:get_indent() .. 'while ' .. self:generate(node.condition) .. ' do'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'end'
end

function CodeGen:generate_repeat(node)
  local line = self:get_indent() .. 'repeat'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'until ' .. self:generate(node.condition)
end

function CodeGen:generate_for(node)
  local line = self:get_indent() .. 'for ' .. node.var .. ' = ' .. self:generate(node.start) .. ', ' .. self:generate(node.finish)
  
  if node.step then
    line = line .. ', ' .. self:generate(node.step)
  end
  
  line = line .. ' do'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'end'
end

function CodeGen:generate_for_in(node)
  local vars = table.concat(node.vars, ', ')
  local iterators = {}
  for _, iter in ipairs(node.iterators) do
    table.insert(iterators, self:generate(iter))
  end
  
  local line = self:get_indent() .. 'for ' .. vars .. ' in ' .. table.concat(iterators, ', ') .. ' do'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'end'
end

function CodeGen:generate_do(node)
  local line = self:get_indent() .. 'do'
  
  self.indent_level = self.indent_level + 1
  local body = self:generate(node.body)
  self.indent_level = self.indent_level - 1
  
  return line .. '\n' .. body .. '\n' .. self:get_indent() .. 'end'
end

function CodeGen:generate_assignment(node)
  local targets = {}
  for _, target in ipairs(node.targets) do
    table.insert(targets, self:generate(target))
  end
  
  local values = {}
  for _, value in ipairs(node.values) do
    table.insert(values, self:generate(value))
  end
  
  local line = self:get_indent() .. table.concat(targets, ', ') .. ' = ' .. table.concat(values, ', ')
  return self:preserve_indent_for_line(line)
end

function CodeGen:generate_return(node)
  if #node.values == 0 then
    return self:get_indent() .. 'return'
  else
    local values = {}
    for _, value in ipairs(node.values) do
      table.insert(values, self:generate(value))
    end
    return self:get_indent() .. 'return ' .. table.concat(values, ', ')
  end
end

function CodeGen:generate_binary_op(node)
  return '(' .. self:generate(node.left) .. ' ' .. node.op .. ' ' .. self:generate(node.right) .. ')'
end

function CodeGen:generate_unary_op(node)
  return node.op .. self:generate(node.operand)
end

function CodeGen:generate_function_call(node)
  local callee = self:generate(node.callee)
  local args = {}
  for _, arg in ipairs(node.args) do
    table.insert(args, self:generate(arg))
  end
  return callee .. '(' .. table.concat(args, ', ') .. ')'
end

function CodeGen:generate_method_call(node)
  local object = self:generate(node.object)
  local args = {}
  for _, arg in ipairs(node.args) do
    table.insert(args, self:generate(arg))
  end
  return object .. ':' .. node.method .. '(' .. table.concat(args, ', ') .. ')'
end

function CodeGen:generate_index_expr(node)
  return self:generate(node.object) .. '[' .. self:generate(node.index) .. ']'
end

function CodeGen:generate_property_expr(node)
  return self:generate(node.object) .. '.' .. node.property
end

function CodeGen:generate_table(node)
  if #node.fields == 0 then
    return '{}'
  end
  
  local fields = {}
  for _, field in ipairs(node.fields) do
    if field.key then
      if field.key.type == 'String' then
        table.insert(fields, field.key.value .. ' = ' .. self:generate(field.value))
      else
        table.insert(fields, '[' .. self:generate(field.key) .. '] = ' .. self:generate(field.value))
      end
    else
      table.insert(fields, self:generate(field.value))
    end
  end
  
  return '{' .. table.concat(fields, ', ') .. '}'
end

function CodeGen:split_code(code)
  local lines = {}
  for line in code:gmatch('[^\n]+') do
    table.insert(lines, line)
  end
  return lines
end

return CodeGen
