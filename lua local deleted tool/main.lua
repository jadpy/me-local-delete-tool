#!/usr/bin/env lua

local Lexer = require('src.lexer')
local Parser = require('src.parser')
local Analyzer = require('src.analyzer')
local Transformer = require('src.transformer')
local CodeGen = require('src.codegen')
local TransformerLine = require('src.transformer_line')

function read_file(filepath)
  local file = io.open(filepath, 'r')
  if not file then
    error('Cannot open file: ' .. filepath)
  end
  local content = file:read('*a')
  file:close()
  return content
end

function write_file(filepath, content)
  local file = io.open(filepath, 'w')
  if not file then
    error('Cannot write file: ' .. filepath)
  end
  file:write(content)
  file:close()
end

function ensure_dir(dirpath)
  os.execute('if not exist "' .. dirpath .. '" mkdir "' .. dirpath .. '"')
end

function process_file(input_filepath, mode, engine)
  local source = read_file(input_filepath)
  local lexer = Lexer.new(source)
  local tokens = lexer:tokenize()

  if engine == 'line' then
    local transformer = TransformerLine.new(source, tokens, { mode = mode })
    local output_code = transformer:apply()
    local analyzer = { all_locals = {} }
    return output_code, analyzer
  end

  local parser = Parser.new(tokens)
  local ast = parser:parse()

  local analyzer = Analyzer.new()
  analyzer:analyze(ast)

  local transformer = Transformer.new({ mode = mode })
  local transformed_ast = transformer:transform(ast)

  local codegen = CodeGen.new(source)
  local output_code = codegen:generate(transformed_ast)

  return output_code, analyzer
end

function show_usage()
  print('Usage:')
  print('  lua54 main.lua functionlocal [scope] <inputfile>')
  print('  lua54 main.lua localkw [scope] <inputfile>')
  print('  lua54 main.lua localte <scope> <inputfile>')
  print('  lua54 main.lua localc <scope> <inputfile>')
  print('  lua54 main.lua localcyt [scope] <inputfile>')
  print('  lua54 main.lua outcode <inputfile>')
  print()
  print('Modes:')
  print('  functionlocal        - Remove `local` from function declarations (`local function` or `local name = function`)')
  print('  localkw [scope]      - Remove only "local" keyword (preserve scope)')
  print('  localte <scope>      - Remove "local" from boolean assignments')
  print('  localc <scope>       - Remove "local" from string assignments')
  print('  localcyt [scope]     - Remove "local" for string assignments (alias of localc; default: both scopes)')
  print('  localtabke [scope]   - Remove "local" from table assignments (default: both scopes)')
  print('  outcode              - Remove commented-out code blocks/lines')
  print()
  print('Scope options (for localkw):')
  print('  function             - Remove "local" from function scope only')
  print('  global               - Remove "local" from global scope only')
  print('  (default: both)      - Remove "local" from both scopes')
  print()
  print('Scope options (for localte/localc/localcyt):')
  print('  function             - Remove "local" from function assignments')
  print('  global               - Remove "local" from global assignments')
  print()
  print('Examples:')
  print('  lua main.lua functionlocal test.lua')
  print('  lua main.lua functionlocal function test.lua')
  print('  lua main.lua functionlocal global test.lua')
  print('  lua main.lua localkw test.lua')
  print('  lua main.lua localkw function test.lua')
  print('  lua main.lua localte global test.lua')
  print('  lua main.lua localc function test.lua')
  print('  lua main.lua localcyt test.lua')
end

function main()
  local raw_args = arg
  local args = {}
  local engine = 'line'
  local idx = 1
  if raw_args[1] and raw_args[1]:match('^%-%-engine=') then
    engine = raw_args[1]:match('^%-%-engine=(.+)')
    idx = 2
  end
  for i = idx, #raw_args do table.insert(args, raw_args[i]) end

  if #args < 1 then
    show_usage()
    return
  end

  local mode_name = args[1]
  local scope = nil
  local input_file = nil
  
  if mode_name == 'functionlocal' then
    if #args == 1 then
      show_usage()
      return
    end

    if #args >= 3 then
      local potential_scope = args[2]
      if potential_scope == 'function' or potential_scope == 'global' then
        scope = potential_scope
        input_file = args[3]
      else
        input_file = args[2]
      end
    else
      input_file = args[2]
    end
  elseif mode_name == 'localkw' then
    if #args == 1 then
      show_usage()
      return
    end
    
    if #args >= 3 then
      local potential_scope = args[2]
      if potential_scope == 'function' or potential_scope == 'global' then
        scope = potential_scope
        input_file = args[3]
      else
        input_file = args[2]
      end
    else
      input_file = args[2]
    end
  elseif mode_name == 'localcyt' then
    if #args == 1 then
      show_usage()
      return
    end

    if #args >= 3 then
      local potential_scope = args[2]
      if potential_scope == 'function' or potential_scope == 'global' then
        scope = potential_scope
        input_file = args[3]
      else
        input_file = args[2]
      end
    else
      input_file = args[2]
    end
  elseif mode_name == 'localtur' then
    if #args == 1 then
      show_usage()
      return
    end

    if #args >= 3 then
      local potential_scope = args[2]
      if potential_scope == 'function' or potential_scope == 'global' then
        scope = potential_scope
        input_file = args[3]
      else
        input_file = args[2]
      end
    else
      input_file = args[2]
    end
  elseif mode_name == 'localte' then
    if #args < 3 then
      show_usage()
      return
    end
    scope = args[2]
    if scope ~= 'function' and scope ~= 'global' then
      show_usage()
      return
    end
    input_file = args[3]
  elseif mode_name == 'localc' then
    if #args < 3 then
      show_usage()
      return
    end
    scope = args[2]
    if scope ~= 'function' and scope ~= 'global' then
      show_usage()
      return
    end
    input_file = args[3]
  elseif mode_name == 'localtabke' then
    if #args == 1 then
      show_usage()
      return
    end
    
    if #args >= 3 then
      local potential_scope = args[2]
      if potential_scope == 'function' or potential_scope == 'global' then
        scope = potential_scope
        input_file = args[3]
      else
        input_file = args[2]
      end
    else
      input_file = args[2]
    end
  elseif mode_name == 'outcode' then
    if #args == 1 then show_usage(); return end
    input_file = args[2]
  else
    show_usage()
    return
  end
  if not input_file then
    show_usage()
    return
  end
  
  local f = io.open(input_file, 'r')
  if not f then
    print('Error: File not found: ' .. input_file)
    return
  end
  f:close()
  
  local mode = 'remove_function_local'
  
  if mode_name == 'functionlocal' then
    if scope == 'function' then
      mode = 'remove_function_local_function'
    elseif scope == 'global' then
      mode = 'remove_function_local_global'
    else
      mode = 'remove_function_local_all'
    end
  elseif mode_name == 'localcyt' then
    if scope == 'function' then
      mode = 'remove_local_string_function'
    elseif scope == 'global' then
      mode = 'remove_local_string_global'
    else
      mode = 'remove_local_string_all'
    end
  elseif mode_name == 'localtur' then
    if scope == 'function' then
      mode = 'remove_local_boolean_function'
    elseif scope == 'global' then
      mode = 'remove_local_boolean_global'
    else
      mode = 'remove_local_boolean_all'
    end
  elseif mode_name == 'localkw' then
    if scope == 'function' then
      mode = 'remove_local_keyword_function'
    elseif scope == 'global' then
      mode = 'remove_local_keyword_global'
    else
      mode = 'remove_local_keyword_all'
    end
  elseif mode_name == 'localte' then
    if scope == 'function' then
      mode = 'remove_local_boolean_function'
    elseif scope == 'global' then
      mode = 'remove_local_boolean_global'
    end
  elseif mode_name == 'localc' then
    if scope == 'function' then
      mode = 'remove_local_string_function'
    elseif scope == 'global' then
      mode = 'remove_local_string_global'
    end
  elseif mode_name == 'localtabke' then
    if scope == 'function' then
      mode = 'remove_local_table_function'
    elseif scope == 'global' then
      mode = 'remove_local_table_global'
    else
      mode = 'remove_local_table_all'
    end
  elseif mode_name == 'outcode' then
    mode = 'outcode'
  end
  
  io.stderr:write('loading ' .. input_file .. '\n')
  io.stderr:write('mode: ' .. mode .. '\n')
  if scope then
    io.stderr:write('scope:  ' .. scope .. '\n')
  end
  io.stderr:write('\n')

  local output_code, analyzer
  output_code, analyzer = process_file(input_file, mode, engine)
  
  ensure_dir('output')
  
  local filename = input_file:match('([^/\\]+)$')
  local output_filepath = 'output/' .. filename

  if output_code then output_code = output_code:gsub('\n+$', '') end
  write_file(output_filepath, output_code)

  io.stderr:write('complete: ' .. output_filepath .. '\n\n')
  local total = 0
  local func_count = 0
  local global_count = 0
  for _, entry in ipairs(analyzer.all_locals) do
    total = total + 1
    if entry.is_in_function then
      func_count = func_count + 1
    else
      global_count = global_count + 1
    end
  end
  io.stderr:write('total local variables: ' .. total .. '\n')
  io.stderr:write('in functions: ' .. func_count .. '\n')
  io.stderr:write('global: ' .. global_count .. '\n')
end

main()
