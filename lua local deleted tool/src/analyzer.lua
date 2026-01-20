local Analyzer = {}

local Scope = {}
function Scope.new(parent)
  local self = {
    parent = parent,
    locals = {},
    children = {}
  }
  return setmetatable(self, { __index = Scope })
end

function Scope:declare(name)
  if self.locals[name] then
    return false
  end
  self.locals[name] = {
    name = name,
    references = 0,
    is_in_function = false
  }
  return true
end

function Scope:reference(name)
  if self.locals[name] then
    self.locals[name].references = self.locals[name].references + 1
    return true
  elseif self.parent then
    return self.parent:reference(name)
  end
  return false
end

function Scope:get_local(name)
  if self.locals[name] then
    return self.locals[name]
  elseif self.parent then
    return self.parent:get_local(name)
  end
  return nil
end

function Scope:mark_function_locals()
  for name, info in pairs(self.locals) do
    info.is_in_function = true
  end
end

function Analyzer.new()
  local self = {
    global_scope = Scope.new(nil),
    current_scope = nil,
    function_scopes = {},
    all_locals = {}
  }
  return setmetatable(self, { __index = Analyzer })
end

function Analyzer:analyze(ast)
  self.current_scope = self.global_scope
  self.all_locals = {}
  self:walk_node(ast)
  return self.global_scope
end

function Analyzer:walk_node(node)
  if not node then return end
  
  if node.type == 'Chunk' then
    self:walk_chunk(node)
  elseif node.type == 'Block' then
    self:walk_block(node)
  elseif node.type == 'LocalDecl' then
    self:walk_local_decl(node)
  elseif node.type == 'LocalFunc' then
    self:walk_local_func(node)
  elseif node.type == 'FunctionDecl' then
    self:walk_function_decl(node)
  elseif node.type == 'Function' then
    self:walk_function(node)
  elseif node.type == 'If' then
    self:walk_if(node)
  elseif node.type == 'While' then
    self:walk_while(node)
  elseif node.type == 'Repeat' then
    self:walk_repeat(node)
  elseif node.type == 'For' then
    self:walk_for(node)
  elseif node.type == 'ForIn' then
    self:walk_for_in(node)
  elseif node.type == 'Do' then
    self:walk_do(node)
  elseif node.type == 'Assignment' then
    self:walk_assignment(node)
  elseif node.type == 'Return' then
    self:walk_return(node)
  elseif node.type == 'BinaryOp' then
    self:walk_binary_op(node)
  elseif node.type == 'UnaryOp' then
    self:walk_unary_op(node)
  elseif node.type == 'Identifier' then
    self:walk_identifier(node)
  elseif node.type == 'FunctionCall' then
    self:walk_function_call(node)
  elseif node.type == 'MethodCall' then
    self:walk_method_call(node)
  elseif node.type == 'IndexExpr' then
    self:walk_index_expr(node)
  elseif node.type == 'PropertyExpr' then
    self:walk_property_expr(node)
  elseif node.type == 'Table' then
    self:walk_table(node)
  end
end

function Analyzer:walk_chunk(node)
  for _, stmt in ipairs(node.body) do
    self:walk_node(stmt)
  end
end

function Analyzer:walk_block(node)
  for _, stmt in ipairs(node.statements) do
    self:walk_node(stmt)
  end
end

function Analyzer:walk_local_decl(node)
  for _, name in ipairs(node.names) do
    self.current_scope:declare(name)
  end
  
  for _, name in ipairs(node.names) do
    if self.all_locals[name] == nil then
      self.all_locals[name] = {
        name = name,
        references = 0,
        is_in_function = self.current_scope ~= self.global_scope
      }
    end
  end
  
  for _, value in ipairs(node.values) do
    self:walk_node(value)
  end
end

function Analyzer:walk_local_func(node)
  self.current_scope:declare(node.name)
  self:walk_node(node.body)
end

function Analyzer:walk_function_decl(node)
  local parent_scope = self.current_scope
  local new_scope = Scope.new(parent_scope)
  self.current_scope = new_scope
  
  self:walk_node(node.body)
  
  for name, info in pairs(new_scope.locals) do
    info.is_in_function = true
  end
  
  self.current_scope = parent_scope
end

function Analyzer:walk_function(node)
  local parent_scope = self.current_scope
  local new_scope = Scope.new(parent_scope)
  self.current_scope = new_scope
  
  for _, param in ipairs(node.params) do
    new_scope:declare(param)
  end
  
  self:walk_node(node.body)
  
  for name, info in pairs(new_scope.locals) do
    info.is_in_function = true
  end
  
  self.current_scope = parent_scope
  return new_scope
end

function Analyzer:walk_if(node)
  self:walk_node(node.condition)
  self:walk_node(node.then_body)
  
  if node.elseif_parts then
    for _, part in ipairs(node.elseif_parts) do
      self:walk_node(part.condition)
      self:walk_node(part.body)
    end
  end
  
  if node.else_body then
    self:walk_node(node.else_body)
  end
end

function Analyzer:walk_while(node)
  self:walk_node(node.condition)
  self:walk_node(node.body)
end

function Analyzer:walk_repeat(node)
  self:walk_node(node.body)
  self:walk_node(node.condition)
end

function Analyzer:walk_for(node)
  self:walk_node(node.start)
  self:walk_node(node.finish)
  if node.step then
    self:walk_node(node.step)
  end
  
  self.current_scope:declare(node.var)
  self:walk_node(node.body)
end

function Analyzer:walk_for_in(node)
  for _, iter in ipairs(node.iterators) do
    self:walk_node(iter)
  end
  
  for _, var in ipairs(node.vars) do
    self.current_scope:declare(var)
  end
  
  self:walk_node(node.body)
end

function Analyzer:walk_do(node)
  self:walk_node(node.body)
end

function Analyzer:walk_assignment(node)
  for _, value in ipairs(node.values) do
    self:walk_node(value)
  end
  
  for _, target in ipairs(node.targets) do
    self:walk_node(target)
  end
end

function Analyzer:walk_return(node)
  for _, value in ipairs(node.values) do
    self:walk_node(value)
  end
end

function Analyzer:walk_binary_op(node)
  self:walk_node(node.left)
  self:walk_node(node.right)
end

function Analyzer:walk_unary_op(node)
  self:walk_node(node.operand)
end

function Analyzer:walk_identifier(node)
  if self.all_locals[node.name] then
    self.all_locals[node.name].references = self.all_locals[node.name].references + 1
  end
  self.current_scope:reference(node.name)
end

function Analyzer:walk_function_call(node)
  self:walk_node(node.callee)
  for _, arg in ipairs(node.args) do
    self:walk_node(arg)
  end
end

function Analyzer:walk_method_call(node)
  self:walk_node(node.object)
  for _, arg in ipairs(node.args) do
    self:walk_node(arg)
  end
end

function Analyzer:walk_index_expr(node)
  self:walk_node(node.object)
  self:walk_node(node.index)
end

function Analyzer:walk_property_expr(node)
  self:walk_node(node.object)
end

function Analyzer:walk_table(node)
  for _, field in ipairs(node.fields) do
    if field.key then
      self:walk_node(field.key)
    end
    self:walk_node(field.value)
  end
end

function Analyzer:get_local_info()
  local result = {}
  
  for name, info in pairs(self.all_locals) do
    table.insert(result, {
      name = name,
      references = info.references,
      is_in_function = info.is_in_function
    })
  end
  
  return result
end

return Analyzer
