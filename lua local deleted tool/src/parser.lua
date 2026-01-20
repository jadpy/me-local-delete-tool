local AST = require('src.ast')

local Parser = {}

function Parser.new(tokens)
  local self = {
    tokens = tokens,
    pos = 1,
    current_token = tokens[1]
  }
  return setmetatable(self, { __index = Parser })
end

function Parser:advance()
  self.pos = self.pos + 1
  self.current_token = self.tokens[self.pos]
end

function Parser:peek(offset)
  offset = offset or 1
  return self.tokens[self.pos + offset]
end

function Parser:expect(token_type)
  if self.current_token.type ~= token_type then
    error(string.format("Expected %s but got %s at line %d", token_type, self.current_token.type, self.current_token.line))
  end
  local token = self.current_token
  self:advance()
  return token
end

function Parser:match(...)
  local types = {...}
  for _, t in ipairs(types) do
    if self.current_token.type == t then
      return true
    end
  end
  return false
end

function Parser:parse()
  return self:parse_chunk()
end

function Parser:parse_chunk()
  local statements = {}
  
  while self.current_token.type ~= 'EOF' do
    local stmt = self:parse_statement()
    if stmt then
      table.insert(statements, stmt)
    end
    if self:match('SEMICOLON') then
      self:advance()
    end
  end
  
  return AST.Chunk(AST.Block(statements))
end

function Parser:parse_statement()
  local stmt_line = (self.current_token and self.current_token.line) or self.current_line or 1

  local stmt
  if self:match('LOCAL') then
    stmt = self:parse_local()
  elseif self:match('FUNCTION') then
    stmt = self:parse_function_decl()
  elseif self:match('IF') then
    stmt = self:parse_if()
  elseif self:match('WHILE') then
    stmt = self:parse_while()
  elseif self:match('REPEAT') then
    stmt = self:parse_repeat()
  elseif self:match('FOR') then
    stmt = self:parse_for()
  elseif self:match('DO') then
    stmt = self:parse_do()
  elseif self:match('BREAK') then
    self:advance()
    stmt = AST.Break()
  elseif self:match('RETURN') then
    stmt = self:parse_return()
  else
    stmt = self:parse_expr_statement()
  end

  if stmt and stmt_line then
    stmt.source_line = stmt_line
  end
  return stmt
end

function Parser:parse_local()
  self:expect('LOCAL')
  
  if self:match('FUNCTION') then
    self:advance()
    local name = self:expect('IDENT').value
    local func = self:parse_function_body()
    return AST.LocalFunc(name, func)
  else
    local names = {}
    table.insert(names, self:expect('IDENT').value)
    
    while self:match('COMMA') do
      self:advance()
      table.insert(names, self:expect('IDENT').value)
    end
    
    local values = {}
    if self:match('ASSIGN') then
      self:advance()
      table.insert(values, self:parse_expression())
      
      while self:match('COMMA') do
        self:advance()
        table.insert(values, self:parse_expression())
      end
    end
    
    return AST.LocalDecl(names, values)
  end
end

function Parser:parse_function_decl()
  self:expect('FUNCTION')
  
  local name = self:expect('IDENT').value
  
  while self:match('DOT') do
    self:advance()
    name = name .. '.' .. self:expect('IDENT').value
  end
  
  if self:match('COLON') then
    self:advance()
    name = name .. ':' .. self:expect('IDENT').value
  end
  
  local func = self:parse_function_body()
  return AST.FunctionDecl(name, func.params, func.body, false)
end

function Parser:parse_function_body()
  self:expect('LPAREN')
  
  local params = {}
  local has_varargs = false
  
  if not self:match('RPAREN') then
    if self:match('ELLIPSIS') then
      self:advance()
      has_varargs = true
    else
      table.insert(params, self:expect('IDENT').value)
      
      while self:match('COMMA') do
        self:advance()
        if self:match('ELLIPSIS') then
          self:advance()
          has_varargs = true
          break
        else
          table.insert(params, self:expect('IDENT').value)
        end
      end
    end
  end
  
  self:expect('RPAREN')
  
  local body = self:parse_block()
  self:expect('END')
  
  return AST.Function(params, body, has_varargs)
end

function Parser:parse_block()
  local statements = {}
  
  while not self:match('END', 'ELSEIF', 'ELSE', 'UNTIL', 'EOF') do
    local stmt = self:parse_statement()
    if stmt then
      table.insert(statements, stmt)
    end
    if self:match('SEMICOLON') then
      self:advance()
    end
  end
  
  return AST.Block(statements)
end

function Parser:parse_if()
  self:expect('IF')
  
  local condition = self:parse_expression()
  self:expect('THEN')
  local then_body = self:parse_block()
  
  local elseif_parts = {}
  while self:match('ELSEIF') do
    self:advance()
    local elseif_cond = self:parse_expression()
    self:expect('THEN')
    local elseif_body = self:parse_block()
    table.insert(elseif_parts, { condition = elseif_cond, body = elseif_body })
  end
  
  local else_body = nil
  if self:match('ELSE') then
    self:advance()
    else_body = self:parse_block()
  end
  
  self:expect('END')
  
  return AST.If(condition, then_body, elseif_parts, else_body)
end

function Parser:parse_while()
  self:expect('WHILE')
  local condition = self:parse_expression()
  self:expect('DO')
  local body = self:parse_block()
  self:expect('END')
  return AST.While(condition, body)
end

function Parser:parse_repeat()
  self:expect('REPEAT')
  local body = self:parse_block()
  self:expect('UNTIL')
  local condition = self:parse_expression()
  return AST.Repeat(body, condition)
end

function Parser:parse_for()
  self:expect('FOR')
  local is_for_in = false
  local pos = self.pos
  local current = self.current_token
  while current and current.type == 'IDENT' do
    current = self.tokens[pos + 1]
    pos = pos + 1
    if current and current.type == 'COMMA' then
      current = self.tokens[pos + 1]
      pos = pos + 1
    elseif current and current.type == 'IN' then
      is_for_in = true
      break
    else
      break
    end
  end
  
  if is_for_in then
    local vars = {}
    table.insert(vars, self:expect('IDENT').value)
    
    while self:match('COMMA') do
      self:advance()
      table.insert(vars, self:expect('IDENT').value)
    end
    
    self:expect('IN')
    
    local iterators = {}
    table.insert(iterators, self:parse_expression())
    while self:match('COMMA') do
      self:advance()
      table.insert(iterators, self:parse_expression())
    end
    
    self:expect('DO')
    local body = self:parse_block()
    self:expect('END')
    
    return AST.ForIn(vars, iterators, body)
  else
    local var = self:expect('IDENT').value
    self:expect('ASSIGN')
    local start = self:parse_expression()
    self:expect('COMMA')
    local finish = self:parse_expression()
    
    local step = nil
    if self:match('COMMA') then
      self:advance()
      step = self:parse_expression()
    end
    
    self:expect('DO')
    local body = self:parse_block()
    self:expect('END')
    
    return AST.For(var, start, finish, step, body)
  end
end

function Parser:parse_do()
  self:expect('DO')
  local body = self:parse_block()
  self:expect('END')
  return AST.Do(body)
end

function Parser:parse_return()
  self:expect('RETURN')
  
  local values = {}
  if not self:match('EOF', 'END', 'ELSEIF', 'ELSE', 'UNTIL', 'SEMICOLON') then
    table.insert(values, self:parse_expression())
    
    while self:match('COMMA') do
      self:advance()
      table.insert(values, self:parse_expression())
    end
  end
  
  if self:match('SEMICOLON') then
    self:advance()
  end
  
  return AST.Return(values)
end

function Parser:parse_expr_statement()
  local expr = self:parse_expression()
  
  if self:match('ASSIGN') then
    self:advance()
    local values = {}
    table.insert(values, self:parse_expression())
    
    while self:match('COMMA') do
      self:advance()
      table.insert(values, self:parse_expression())
    end
    
    local targets = {}
    if expr.type == 'Identifier' then
      table.insert(targets, expr)
    elseif expr.type == 'IndexExpr' or expr.type == 'PropertyExpr' then
      table.insert(targets, expr)
    end
    
    while expr.type == 'Identifier' or expr.type == 'IndexExpr' or expr.type == 'PropertyExpr' do
      if self:match('COMMA') then
        break
      else
        break
      end
    end
    
    return AST.Assignment(targets, values)
  elseif self:match('COMMA') then
    local targets = { expr }
    while self:match('COMMA') do
      self:advance()
      table.insert(targets, self:parse_expression())
    end
    
    self:expect('ASSIGN')
    
    local values = {}
    table.insert(values, self:parse_expression())
    
    while self:match('COMMA') do
      self:advance()
      table.insert(values, self:parse_expression())
    end
    
    return AST.Assignment(targets, values)
  end
  
  if self:match('SEMICOLON') then
    self:advance()
  end
  
  return expr
end

function Parser:parse_expression()
  return self:parse_or()
end

function Parser:parse_or()
  local left = self:parse_and()
  
  while self:match('OR') do
    local op = self.current_token.value
    self:advance()
    local right = self:parse_and()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_and()
  local left = self:parse_not()
  
  while self:match('AND') do
    local op = self.current_token.value
    self:advance()
    local right = self:parse_not()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_not()
  if self:match('NOT') then
    local op = self.current_token.value
    self:advance()
    local operand = self:parse_not()
    return AST.UnaryOp(op, operand)
  end
  
  return self:parse_comparison()
end

function Parser:parse_comparison()
  local left = self:parse_concat()
  
  while self:match('LT', 'LE', 'GT', 'GE', 'EQ', 'NE') do
    local op = self.current_token.value
    self:advance()
    local right = self:parse_concat()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_concat()
  local left = self:parse_additive()
  
  while self:match('CONCAT') do
    local op = self.current_token.value
    self:advance()
    local right = self:parse_additive()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_additive()
  local left = self:parse_multiplicative()
  
  while self:match('PLUS', 'MINUS') do
    local op = self.current_token.value
    self:advance()
    local right = self:parse_multiplicative()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_multiplicative()
  local left = self:parse_unary()
  
  while self:match('MUL', 'DIV', 'IDIV', 'MOD') do
    local op = self.current_token.value
    self:advance()
    local right = self:parse_unary()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_unary()
  if self:match('MINUS', 'NOT', 'LEN') then
    local op = self.current_token.value
    self:advance()
    local operand = self:parse_unary()
    return AST.UnaryOp(op, operand)
  end
  
  return self:parse_power()
end

function Parser:parse_power()
  local left = self:parse_postfix()
  
  if self:match('POW') then
    local op = self.current_token.value
    self:advance()
    local right = self:parse_power()
    left = AST.BinaryOp(op, left, right)
  end
  
  return left
end

function Parser:parse_postfix()
  local expr = self:parse_primary()
  
  while true do
    if self:match('LPAREN') then
      self:advance()
      local args = {}
      if not self:match('RPAREN') then
        table.insert(args, self:parse_expression())
        while self:match('COMMA') do
          self:advance()
          table.insert(args, self:parse_expression())
        end
      end
      self:expect('RPAREN')
      expr = AST.FunctionCall(expr, args)
    elseif self:match('LBRACE') then
      self:advance()
      local fields = {}
      if not self:match('RBRACE') then
        table.insert(fields, self:parse_table_field())
        while self:match('COMMA') do
          self:advance()
          if self:match('RBRACE') then break end
          table.insert(fields, self:parse_table_field())
        end
      end
      self:expect('RBRACE')
      expr = AST.FunctionCall(expr, { AST.Table(fields) })
    elseif self:match('STRING') then
      expr = AST.FunctionCall(expr, { AST.String(self.current_token.value) })
      self:advance()
    elseif self:match('LBRACKET') then
      self:advance()
      local index = self:parse_expression()
      self:expect('RBRACKET')
      expr = AST.IndexExpr(expr, index)
    elseif self:match('DOT') then
      self:advance()
      local property = self:expect('IDENT').value
      expr = AST.PropertyExpr(expr, property)
    elseif self:match('COLON') then
      self:advance()
      local method = self:expect('IDENT').value
      self:expect('LPAREN')
      local args = {}
      if not self:match('RPAREN') then
        table.insert(args, self:parse_expression())
        while self:match('COMMA') do
          self:advance()
          table.insert(args, self:parse_expression())
        end
      end
      self:expect('RPAREN')
      expr = AST.MethodCall(expr, method, args)
    else
      break
    end
  end
  
  return expr
end

function Parser:parse_primary()
  if self:match('NIL') then
    self:advance()
    return AST.Nil()
  elseif self:match('TRUE') then
    self:advance()
    return AST.Boolean(true)
  elseif self:match('FALSE') then
    self:advance()
    return AST.Boolean(false)
  elseif self:match('NUMBER') then
    local value = self.current_token.value
    self:advance()
    return AST.Number(value)
  elseif self:match('STRING') then
    local value = self.current_token.value
    self:advance()
    return AST.String(value)
  elseif self:match('ELLIPSIS') then
    self:advance()
    return AST.VarArgs()
  elseif self:match('FUNCTION') then
    self:advance()
    return self:parse_function_body()
  elseif self:match('LBRACE') then
    return self:parse_table()
  elseif self:match('LPAREN') then
    self:advance()
    local expr = self:parse_expression()
    self:expect('RPAREN')
    return expr
  elseif self:match('IDENT') then
    local name = self.current_token.value
    self:advance()
    return AST.Identifier(name)
  else
    error(string.format("Unexpected token: %s at line %d", self.current_token.type, self.current_token.line))
  end
end

function Parser:parse_table()
  self:expect('LBRACE')
  
  local fields = {}
  if not self:match('RBRACE') then
    table.insert(fields, self:parse_table_field())
    while self:match('COMMA', 'SEMICOLON') do
      self:advance()
      if self:match('RBRACE') then break end
      table.insert(fields, self:parse_table_field())
    end
  end
  
  self:expect('RBRACE')
  
  return AST.Table(fields)
end

function Parser:parse_table_field()
  if self:match('LBRACKET') then
    self:advance()
    local key = self:parse_expression()
    self:expect('RBRACKET')
    self:expect('ASSIGN')
    local value = self:parse_expression()
    return AST.TableField(key, value)
  elseif self:match('IDENT') and self:peek() and self:peek().type == 'ASSIGN' then
    local key = self:expect('IDENT').value
    self:expect('ASSIGN')
    local value = self:parse_expression()
    return AST.TableField(AST.String(key), value)
  else
    local value = self:parse_expression()
    return AST.TableField(nil, value)
  end
end

return Parser
