local Lexer = {}

local Token = {}
function Token.new(type, value, line, col)
  return {
    type = type,
    value = value,
    line = line,
    col = col
  }
end

function Lexer.new(source)
  local self = {
    source = source,
    pos = 1,
    line = 1,
    col = 1,
    tokens = {},
    current_char = source:sub(1, 1)
  }
  return setmetatable(self, { __index = Lexer })
end

function Lexer:char_col()
  local s = self.source
  local bytepos = math.max(1, math.min(#s+1, self.pos))
  local start = 1
  for i = bytepos-1, 1, -1 do
    if s:byte(i) == 10 then
      start = i + 1
      break
    end
  end
  local substr = s:sub(start, bytepos-1)
  local count = 0
  if type(utf8) == 'table' and utf8.charpattern then
    for _ in substr:gmatch(utf8.charpattern) do count = count + 1 end
  else
    count = #substr
  end
  return count + 1
end

function Lexer:advance()
  if self.current_char == '\n' then
    self.line = self.line + 1
    self.col = 1
  else
    self.col = self.col + 1
  end
  self.pos = self.pos + 1
  self.current_char = self.source:sub(self.pos, self.pos)
end

function Lexer:peek(offset)
  offset = offset or 1
  return self.source:sub(self.pos + offset, self.pos + offset)
end

function Lexer:skip_whitespace()
  while self.current_char:match('%s') do
    self:advance()
  end
end

function Lexer:skip_comment()
  if self.current_char == '-' and self:peek() == '-' then
    self:advance()
    self:advance()

    if self.current_char == '[' and self:peek() == '[' then
      self:advance()
      self:advance()
      while not (self.current_char == ']' and self:peek() == ']') do
        if self.current_char == '' then break end
        self:advance()
      end
      if self.current_char == ']' then
        self:advance()
        self:advance()
      end
    else
      while self.current_char ~= '\n' and self.current_char ~= '' do
        self:advance()
      end
    end
    return true
  end
  return false
end

function Lexer:read_string(quote)
  local start_line = self.line
  local start_col = self:char_col()
  local value = ''
  self:advance()

  while self.current_char ~= quote and self.current_char ~= '' do
    if self.current_char == '\\' then
      self:advance()
      if self.current_char == 'n' then value = value .. '\n'
      elseif self.current_char == 't' then value = value .. '\t'
      elseif self.current_char == 'r' then value = value .. '\r'
      elseif self.current_char == '\\' then value = value .. '\\'
      elseif self.current_char == quote then value = value .. quote
      else value = value .. self.current_char
      end
    else
      value = value .. self.current_char
    end
    self:advance()
  end

  if self.current_char == quote then
    self:advance()
  end

  return Token.new('STRING', value, start_line, start_col)
end

function Lexer:read_number()
  local start_line = self.line
  local start_col = self:char_col()
  local value = ''

  while self.current_char:match('[0-9a-fxA-FX.]') do
    value = value .. self.current_char
    self:advance()
  end

  if self.current_char:match('[eE]') then
    value = value .. self.current_char
    self:advance()
    if self.current_char:match('[+-]') then
      value = value .. self.current_char
      self:advance()
    end
    while self.current_char:match('[0-9]') do
      value = value .. self.current_char
      self:advance()
    end
  end

  return Token.new('NUMBER', tonumber(value), start_line, start_col)
end

function Lexer:read_identifier()
  local start_line = self.line
  local start_col = self:char_col()
  local value = ''
  while true do
    local ch = self.source:match('(' .. utf8.charpattern .. ')', self.pos) or ''
    if ch == '' then break end
    local ok = false
    if #ch == 1 and ch:match('[a-zA-Z0-9_]') then ok = true end
    if not ok and #ch > 1 then ok = true end
    if not ok then break end
    value = value .. ch
    self.pos = self.pos + #ch
    self.current_char = self.source:sub(self.pos, self.pos)
    if ch == '\n' then
      self.line = self.line + 1
      self.col = 1
    else
      self.col = self.col + 1
    end
  end

  local keywords = {
    ['and'] = 'AND',
    ['break'] = 'BREAK',
    ['do'] = 'DO',
    ['else'] = 'ELSE',
    ['elseif'] = 'ELSEIF',
    ['end'] = 'END',
    ['false'] = 'FALSE',
    ['for'] = 'FOR',
    ['function'] = 'FUNCTION',
    ['if'] = 'IF',
    ['in'] = 'IN',
    ['local'] = 'LOCAL',
    ['nil'] = 'NIL',
    ['not'] = 'NOT',
    ['or'] = 'OR',
    ['repeat'] = 'REPEAT',
    ['return'] = 'RETURN',
    ['then'] = 'THEN',
    ['true'] = 'TRUE',
    ['until'] = 'UNTIL',
    ['while'] = 'WHILE'
  }

  local token_type = keywords[value] or 'IDENT'
  return Token.new(token_type, value, start_line, start_col)
end

function Lexer:tokenize()
  while self.current_char ~= '' do
    self:skip_whitespace()

    if self.current_char == '' then
      break
    end

    if self:skip_comment() then
    else
      local char = self.current_char
      local line = self.line
      local col = self:char_col()

      if char == "'" or char == '"' then
        table.insert(self.tokens, self:read_string(char))
      elseif char:match('[0-9]') then
        table.insert(self.tokens, self:read_number())
      elseif char:match('[a-zA-Z_]') or (char and char:byte() and char:byte() >= 0xC0) then
        table.insert(self.tokens, self:read_identifier())
      elseif char == '(' then
        table.insert(self.tokens, Token.new('LPAREN', '(', line, col))
        self:advance()
      elseif char == ')' then
        table.insert(self.tokens, Token.new('RPAREN', ')', line, col))
        self:advance()
      elseif char == '{' then
        table.insert(self.tokens, Token.new('LBRACE', '{', line, col))
        self:advance()
      elseif char == '}' then
        table.insert(self.tokens, Token.new('RBRACE', '}', line, col))
        self:advance()
      elseif char == '[' then
        table.insert(self.tokens, Token.new('LBRACKET', '[', line, col))
        self:advance()
      elseif char == ']' then
        table.insert(self.tokens, Token.new('RBRACKET', ']', line, col))
        self:advance()
      elseif char == ',' then
        table.insert(self.tokens, Token.new('COMMA', ',', line, col))
        self:advance()
      elseif char == ';' then
        table.insert(self.tokens, Token.new('SEMICOLON', ';', line, col))
        self:advance()
      elseif char == ':' then
        table.insert(self.tokens, Token.new('COLON', ':', line, col))
        self:advance()
      elseif char == '.' then
        if self:peek() == '.' then
          if self:peek(2) == '.' then
            table.insert(self.tokens, Token.new('ELLIPSIS', '...', line, col))
            self:advance()
            self:advance()
            self:advance()
          else
            table.insert(self.tokens, Token.new('CONCAT', '..', line, col))
            self:advance()
            self:advance()
          end
        else
          table.insert(self.tokens, Token.new('DOT', '.', line, col))
          self:advance()
        end
      elseif char == '=' then
        if self:peek() == '=' then
          table.insert(self.tokens, Token.new('EQ', '==', line, col))
          self:advance()
          self:advance()
        else
          table.insert(self.tokens, Token.new('ASSIGN', '=', line, col))
          self:advance()
        end
      elseif char == '<' then
        if self:peek() == '=' then
          table.insert(self.tokens, Token.new('LE', '<=', line, col))
          self:advance()
          self:advance()
        elseif self:peek() == '<' then
          table.insert(self.tokens, Token.new('LSHIFT', '<<', line, col))
          self:advance()
          self:advance()
        else
          table.insert(self.tokens, Token.new('LT', '<', line, col))
          self:advance()
        end
      elseif char == '>' then
        if self:peek() == '=' then
          table.insert(self.tokens, Token.new('GE', '>=', line, col))
          self:advance()
          self:advance()
        elseif self:peek() == '>' then
          table.insert(self.tokens, Token.new('RSHIFT', '>>', line, col))
          self:advance()
          self:advance()
        else
          table.insert(self.tokens, Token.new('GT', '>', line, col))
          self:advance()
        end
      elseif char == '~' then
        if self:peek() == '=' then
          table.insert(self.tokens, Token.new('NE', '~=', line, col))
          self:advance()
          self:advance()
        end
      elseif char == '+' then
        table.insert(self.tokens, Token.new('PLUS', '+', line, col))
        self:advance()
      elseif char == '-' then
        table.insert(self.tokens, Token.new('MINUS', '-', line, col))
        self:advance()
      elseif char == '*' then
        table.insert(self.tokens, Token.new('MUL', '*', line, col))
        self:advance()
      elseif char == '/' then
        if self:peek() == '/' then
          table.insert(self.tokens, Token.new('IDIV', '//', line, col))
          self:advance()
          self:advance()
        else
          table.insert(self.tokens, Token.new('DIV', '/', line, col))
          self:advance()
        end
      elseif char == '%' then
        table.insert(self.tokens, Token.new('MOD', '%', line, col))
        self:advance()
      elseif char == '^' then
        table.insert(self.tokens, Token.new('POW', '^', line, col))
        self:advance()
      elseif char == '#' then
        table.insert(self.tokens, Token.new('LEN', '#', line, col))
        self:advance()
      else
        error(string.format("Unknown character: '%s' at line %d, col %d", char, line, col))
      end
    end
  end

  table.insert(self.tokens, Token.new('EOF', '', self.line, self:char_col()))
  return self.tokens
end

return Lexer