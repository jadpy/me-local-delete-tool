local AST = require('src.ast')

local Transformer = {}

function Transformer.new(options)
  local self = {
    options = options or {},
    in_function = false,
    function_depth = 0
  }
  return setmetatable(self, { __index = Transformer })
end

function Transformer:transform(ast)
  return self:walk_node(ast)
end

function Transformer:walk_node(node)
  if not node then return node end
  
  if node.type == 'Chunk' then
    return self:walk_chunk(node)
  elseif node.type == 'Block' then
    return self:walk_block(node)
  elseif node.type == 'LocalDecl' then
    return self:walk_local_decl(node)
  elseif node.type == 'LocalFunc' then
    return self:walk_local_func(node)
  elseif node.type == 'FunctionDecl' then
    return self:walk_function_decl(node)
  elseif node.type == 'Function' then
    return self:walk_function(node)
  elseif node.type == 'If' then
    return self:walk_if(node)
  elseif node.type == 'While' then
    return self:walk_while(node)
  elseif node.type == 'Repeat' then
    return self:walk_repeat(node)
  elseif node.type == 'For' then
    return self:walk_for(node)
  elseif node.type == 'ForIn' then
    return self:walk_for_in(node)
  elseif node.type == 'Do' then
    return self:walk_do(node)
  elseif node.type == 'Assignment' then
    return self:walk_assignment(node)
  elseif node.type == 'Return' then
    return self:walk_return(node)
  elseif node.type == 'BinaryOp' then
    return self:walk_binary_op(node)
  elseif node.type == 'UnaryOp' then
    return self:walk_unary_op(node)
  elseif node.type == 'FunctionCall' then
    return self:walk_function_call(node)
  elseif node.type == 'MethodCall' then
    return self:walk_method_call(node)
  elseif node.type == 'IndexExpr' then
    return self:walk_index_expr(node)
  elseif node.type == 'PropertyExpr' then
    return self:walk_property_expr(node)
  elseif node.type == 'Table' then
    return self:walk_table(node)
  else
    return node
  end
end

function Transformer:walk_chunk(node)
  local new_body = {}
  local body = node.body
  local statements = body and body.statements or body
  
  for _, stmt in ipairs(statements) do
    local transformed = self:walk_node(stmt)
    if transformed then
      if transformed.type == 'Block' then
        for _, s in ipairs(transformed.statements) do
          table.insert(new_body, s)
        end
      else
        table.insert(new_body, transformed)
      end
    end
  end
  return AST.Chunk(AST.Block(new_body))
end

function Transformer:walk_block(node)
  local new_statements = {}
  for _, stmt in ipairs(node.statements) do
    local transformed = self:walk_node(stmt)
    if transformed then
      if stmt.source_line then
        transformed.source_line = stmt.source_line
      end
      if stmt.type ~= transformed.type then
        transformed.modified = true
      end
      table.insert(new_statements, transformed)
    end
  end
  return AST.Block(new_statements)
end

function Transformer:walk_local_decl(node)
  local delete_mode = self.options.mode or 'remove_function_local'
  
  if delete_mode == 'remove_function_local' then
    if not self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local assignment_targets = {}
      local assignment_values = {}
      
      for i, name in ipairs(node.names) do
        table.insert(assignment_targets, AST.Identifier(name))
        if i <= #node.values then
          table.insert(assignment_values, self:walk_node(node.values[i]))
        else
          table.insert(assignment_values, AST.Nil())
        end
      end
      
      local res = AST.Assignment(assignment_targets, assignment_values)
      if node.source_line then res.source_line = node.source_line end
      res.modified = true
      return res
    else
      return nil
    end
  
  elseif delete_mode == 'remove_global_local' then
    if self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local assignment_targets = {}
      local assignment_values = {}
      
      for i, name in ipairs(node.names) do
        table.insert(assignment_targets, AST.Identifier(name))
        if i <= #node.values then
          table.insert(assignment_values, self:walk_node(node.values[i]))
        else
          table.insert(assignment_values, AST.Nil())
        end
      end
      
      local res = AST.Assignment(assignment_targets, assignment_values)
      if node.source_line then res.source_line = node.source_line end
      res.modified = true
      return res
    else
      return nil
    end
  
  elseif delete_mode == 'remove_all_local' then
    local has_values = #node.values > 0
    
    if has_values then
      local assignment_targets = {}
      local assignment_values = {}
      
      for i, name in ipairs(node.names) do
        table.insert(assignment_targets, AST.Identifier(name))
        if i <= #node.values then
          table.insert(assignment_values, self:walk_node(node.values[i]))
        else
          table.insert(assignment_values, AST.Nil())
        end
      end
      
      local res = AST.Assignment(assignment_targets, assignment_values)
      if node.source_line then res.source_line = node.source_line end
      res.modified = true
      return res
    else
      return nil
    end
  
  elseif delete_mode == 'remove_local_keyword_function' then
    if not self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local assignment_targets = {}
      local assignment_values = {}
      
      for i, name in ipairs(node.names) do
        table.insert(assignment_targets, AST.Identifier(name))
        if i <= #node.values then
          table.insert(assignment_values, self:walk_node(node.values[i]))
        else
          table.insert(assignment_values, AST.Nil())
        end
      end
      
      local res = AST.Assignment(assignment_targets, assignment_values)
      if node.source_line then res.source_line = node.source_line end
      res.modified = true
      return res
    else
      return nil
    end
  
  elseif delete_mode == 'remove_local_keyword_global' then
    if self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local assignment_targets = {}
      local assignment_values = {}
      
      for i, name in ipairs(node.names) do
        table.insert(assignment_targets, AST.Identifier(name))
        if i <= #node.values then
          table.insert(assignment_values, self:walk_node(node.values[i]))
        else
          table.insert(assignment_values, AST.Nil())
        end
      end
      
      local res = AST.Assignment(assignment_targets, assignment_values)
      if node.source_line then res.source_line = node.source_line end
      res.modified = true
      return res
    else
      return nil
    end
  
  elseif delete_mode == 'remove_local_keyword_all' then
    local has_values = #node.values > 0
    
    if has_values then
      local assignment_targets = {}
      local assignment_values = {}
      
      for i, name in ipairs(node.names) do
        table.insert(assignment_targets, AST.Identifier(name))
        if i <= #node.values then
          table.insert(assignment_values, self:walk_node(node.values[i]))
        else
          table.insert(assignment_values, AST.Nil())
        end
      end
      
      local res = AST.Assignment(assignment_targets, assignment_values)
      if node.source_line then res.source_line = node.source_line end
      res.modified = true
      return res
    else
      return nil
    end
  
  elseif delete_mode == 'remove_local_boolean_function' then
    if not self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local is_boolean = false
      for _, value in ipairs(node.values) do
        if value.type == 'Boolean' then
          is_boolean = true
          break
        end
      end
      
      if is_boolean then
        local assignment_targets = {}
        local assignment_values = {}
        
        for i, name in ipairs(node.names) do
          table.insert(assignment_targets, AST.Identifier(name))
          if i <= #node.values then
            table.insert(assignment_values, self:walk_node(node.values[i]))
          else
            table.insert(assignment_values, AST.Nil())
          end
        end
        
        local res = AST.Assignment(assignment_targets, assignment_values)
        if node.source_line then res.source_line = node.source_line end
        res.modified = true
        return res
      else
        return node
      end
    else
      return node
    end
  
  elseif delete_mode == 'remove_local_boolean_global' then
    if self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local is_boolean = false
      for _, value in ipairs(node.values) do
        if value.type == 'Boolean' then
          is_boolean = true
          break
        end
      end
      
      if is_boolean then
        local assignment_targets = {}
        local assignment_values = {}
        
        for i, name in ipairs(node.names) do
          table.insert(assignment_targets, AST.Identifier(name))
          if i <= #node.values then
            table.insert(assignment_values, self:walk_node(node.values[i]))
          else
            table.insert(assignment_values, AST.Nil())
          end
        end
        
        local res = AST.Assignment(assignment_targets, assignment_values)
        if node.source_line then res.source_line = node.source_line end
        res.modified = true
        return res
      else
        return node
      end
    else
      return node
    end
    elseif delete_mode == 'remove_local_string_function' then
    if not self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local is_string = false
      for _, value in ipairs(node.values) do
        if value.type == 'String' then
          is_string = true
          break
        end
      end
      
      if is_string then
        local assignment_targets = {}
        local assignment_values = {}
        
        for i, name in ipairs(node.names) do
          table.insert(assignment_targets, AST.Identifier(name))
          if i <= #node.values then
            table.insert(assignment_values, self:walk_node(node.values[i]))
          else
            table.insert(assignment_values, AST.Nil())
          end
        end
        
        local res = AST.Assignment(assignment_targets, assignment_values)
        if node.source_line then res.source_line = node.source_line end
        res.modified = true
        return res
      else
        return node
      end
    else
      return node
    end
  
  elseif delete_mode == 'remove_local_string_global' then
    if self.in_function then
      return node
    end
    
    local has_values = #node.values > 0
    
    if has_values then
      local is_string = false
      for _, value in ipairs(node.values) do
        if value.type == 'String' then
          is_string = true
          break
        end
      end
      
      if is_string then
        local assignment_targets = {}
        local assignment_values = {}
        
        for i, name in ipairs(node.names) do
          table.insert(assignment_targets, AST.Identifier(name))
          if i <= #node.values then
            table.insert(assignment_values, self:walk_node(node.values[i]))
          else
            table.insert(assignment_values, AST.Nil())
          end
        end
        
        local res = AST.Assignment(assignment_targets, assignment_values)
        if node.source_line then res.source_line = node.source_line end
        res.modified = true
        return res
      else
        return node
      end
    else
      return node
    end
    else
    return node
  end
end


function Transformer:walk_local_func(node)
  local delete_mode = self.options.mode or 'remove_function_local'
  
  if delete_mode == 'remove_function_local' then
    if not self.in_function then
      return node
    end
    
    local func = self:walk_node(node.body)
    local result = AST.FunctionDecl(node.name, func.params, func.body, false)
    if node.source_line then result.source_line = node.source_line end
    result.modified = true
    return result
  
  elseif delete_mode == 'remove_global_local' then
    if self.in_function then
      return node
    end
    
    local func = self:walk_node(node.body)
    local result = AST.FunctionDecl(node.name, func.params, func.body, false)
    if node.source_line then result.source_line = node.source_line end
    result.modified = true
    return result
  
  elseif delete_mode == 'remove_all_local' then
    local func = self:walk_node(node.body)
    local result = AST.FunctionDecl(node.name, func.params, func.body, false)
    if node.source_line then result.source_line = node.source_line end
    result.modified = true
    return result
  
  elseif delete_mode == 'remove_local_keyword_function' then
    if not self.in_function then
      return node
    end
    
    local func = self:walk_node(node.body)
    local result = AST.FunctionDecl(node.name, func.params, func.body, false)
    if node.source_line then result.source_line = node.source_line end
    result.modified = true
    return result
  
  elseif delete_mode == 'remove_local_keyword_global' then
    if self.in_function then
      return node
    end
    
    local func = self:walk_node(node.body)
    local result = AST.FunctionDecl(node.name, func.params, func.body, false)
    if node.source_line then result.source_line = node.source_line end
    result.modified = true
    return result
  
  elseif delete_mode == 'remove_local_keyword_all' then
    local func = self:walk_node(node.body)
    local result = AST.FunctionDecl(node.name, func.params, func.body, false)
    if node.source_line then result.source_line = node.source_line end
    result.modified = true
    return result
  
  else
    return node
  end
end

function Transformer:walk_function_decl(node)
  local prev_in_function = self.in_function
  local prev_depth = self.function_depth
  
  self.in_function = true
  self.function_depth = self.function_depth + 1
  
  local new_body = self:walk_node(node.body)
  
  self.in_function = prev_in_function
  self.function_depth = prev_depth
  
  return AST.FunctionDecl(node.name, node.params, new_body, node.is_local)
end

function Transformer:walk_function(node)
  local prev_in_function = self.in_function
  local prev_depth = self.function_depth
  
  self.in_function = true
  self.function_depth = self.function_depth + 1
  
  local new_body = self:walk_node(node.body)
  
  self.in_function = prev_in_function
  self.function_depth = prev_depth
  
  return AST.Function(node.params, new_body, node.has_varargs)
end

function Transformer:walk_if(node)
  return AST.If(
    self:walk_node(node.condition),
    self:walk_node(node.then_body),
    self:transform_elseif_parts(node.elseif_parts),
    node.else_body and self:walk_node(node.else_body) or nil
  )
end

function Transformer:transform_elseif_parts(parts)
  if not parts then return nil end
  local new_parts = {}
  for _, part in ipairs(parts) do
    table.insert(new_parts, {
      condition = self:walk_node(part.condition),
      body = self:walk_node(part.body)
    })
  end
  return new_parts
end

function Transformer:walk_while(node)
  return AST.While(
    self:walk_node(node.condition),
    self:walk_node(node.body)
  )
end

function Transformer:walk_repeat(node)
  return AST.Repeat(
    self:walk_node(node.body),
    self:walk_node(node.condition)
  )
end

function Transformer:walk_for(node)
  return AST.For(
    node.var,
    self:walk_node(node.start),
    self:walk_node(node.finish),
    node.step and self:walk_node(node.step) or nil,
    self:walk_node(node.body)
  )
end

function Transformer:walk_for_in(node)
  local new_iterators = {}
  for _, iter in ipairs(node.iterators) do
    table.insert(new_iterators, self:walk_node(iter))
  end
  
  return AST.ForIn(
    node.vars,
    new_iterators,
    self:walk_node(node.body)
  )
end

function Transformer:walk_do(node)
  return AST.Do(self:walk_node(node.body))
end

function Transformer:walk_assignment(node)
  local new_targets = {}
  for _, target in ipairs(node.targets) do
    table.insert(new_targets, self:walk_node(target))
  end
  
  local new_values = {}
  for _, value in ipairs(node.values) do
    table.insert(new_values, self:walk_node(value))
  end
  
  return AST.Assignment(new_targets, new_values)
end

function Transformer:walk_return(node)
  local new_values = {}
  for _, value in ipairs(node.values) do
    table.insert(new_values, self:walk_node(value))
  end
  return AST.Return(new_values)
end

function Transformer:walk_binary_op(node)
  return AST.BinaryOp(
    node.op,
    self:walk_node(node.left),
    self:walk_node(node.right)
  )
end

function Transformer:walk_unary_op(node)
  return AST.UnaryOp(node.op, self:walk_node(node.operand))
end

function Transformer:walk_function_call(node)
  local new_args = {}
  for _, arg in ipairs(node.args) do
    table.insert(new_args, self:walk_node(arg))
  end
  return AST.FunctionCall(self:walk_node(node.callee), new_args)
end

function Transformer:walk_method_call(node)
  local new_args = {}
  for _, arg in ipairs(node.args) do
    table.insert(new_args, self:walk_node(arg))
  end
  return AST.MethodCall(self:walk_node(node.object), node.method, new_args)
end

function Transformer:walk_index_expr(node)
  return AST.IndexExpr(
    self:walk_node(node.object),
    self:walk_node(node.index)
  )
end

function Transformer:walk_property_expr(node)
  return AST.PropertyExpr(self:walk_node(node.object), node.property)
end

function Transformer:walk_table(node)
  local new_fields = {}
  for _, field in ipairs(node.fields) do
    table.insert(new_fields, AST.TableField(
      field.key and self:walk_node(field.key) or nil,
      self:walk_node(field.value)
    ))
  end
  return AST.Table(new_fields)
end

return Transformer
