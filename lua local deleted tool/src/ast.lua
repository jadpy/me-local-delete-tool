local AST = {}

function AST.Chunk(body)
  return { type = 'Chunk', body = body }
end

function AST.Block(statements)
  return { type = 'Block', statements = statements }
end

function AST.LocalDecl(names, values)
  return { type = 'LocalDecl', names = names, values = values }
end

function AST.LocalFunc(name, body)
  return { type = 'LocalFunc', name = name, body = body }
end

function AST.FunctionDecl(name, params, body, is_local)
  return { type = 'FunctionDecl', name = name, params = params, body = body, is_local = is_local or false }
end

function AST.Identifier(name)
  return { type = 'Identifier', name = name }
end

function AST.BinaryOp(op, left, right)
  return { type = 'BinaryOp', op = op, left = left, right = right }
end

function AST.UnaryOp(op, operand)
  return { type = 'UnaryOp', op = op, operand = operand }
end

function AST.Number(value)
  return { type = 'Number', value = value }
end

function AST.String(value)
  return { type = 'String', value = value }
end

function AST.Boolean(value)
  return { type = 'Boolean', value = value }
end

function AST.Nil()
  return { type = 'Nil' }
end

function AST.Table(fields)
  return { type = 'Table', fields = fields }
end

function AST.TableField(key, value)
  return { type = 'TableField', key = key, value = value }
end

function AST.IndexExpr(object, index)
  return { type = 'IndexExpr', object = object, index = index }
end

function AST.PropertyExpr(object, property)
  return { type = 'PropertyExpr', object = object, property = property }
end

function AST.FunctionCall(callee, args)
  return { type = 'FunctionCall', callee = callee, args = args }
end

function AST.MethodCall(object, method, args)
  return { type = 'MethodCall', object = object, method = method, args = args }
end

function AST.Assignment(targets, values)
  return { type = 'Assignment', targets = targets, values = values }
end

function AST.If(condition, then_body, elseif_parts, else_body)
  return { type = 'If', condition = condition, then_body = then_body, elseif_parts = elseif_parts, else_body = else_body }
end

function AST.While(condition, body)
  return { type = 'While', condition = condition, body = body }
end

function AST.Repeat(body, condition)
  return { type = 'Repeat', body = body, condition = condition }
end

function AST.For(var, start, finish, step, body)
  return { type = 'For', var = var, start = start, finish = finish, step = step, body = body }
end

function AST.ForIn(vars, iterators, body)
  return { type = 'ForIn', vars = vars, iterators = iterators, body = body }
end

function AST.Return(values)
  return { type = 'Return', values = values }
end

function AST.Break()
  return { type = 'Break' }
end

function AST.Goto(label)
  return { type = 'Goto', label = label }
end

function AST.Label(name)
  return { type = 'Label', name = name }
end

function AST.VarArgs()
  return { type = 'VarArgs' }
end

function AST.Function(params, body, has_varargs)
  return { type = 'Function', params = params, body = body, has_varargs = has_varargs or false }
end

function AST.Do(body)
  return { type = 'Do', body = body }
end

return AST
