
return function (_wbyte)

  -- TODO: I'm using arithmetic because bit operations are not yet
  -- implemented in cobre nor culang

  local function wbyte (...)
    for _, b in ipairs{...} do
      _wbyte(b)
    end
  end

  local function wint (n)
    local function f (n)
      if n > 0 then
        --f(n >> 7)
        --wbyte((n & 0x7f) | 0x80)
        local m = n//128
        f(m)
        wbyte((n - (m*128)) + 128)
      end
    end
    --f(n >> 7)
    --wbyte(n & 0x7f)
    local m = n//128
    f(m)
    wbyte(n - (m*128))
  end

  local function rstr (str) wbyte(str:byte(1, -1)) end

  local function wstr (str)
    wint(#str)
    rstr(str)
  end

  rstr("Auro 0.6\0")
  wint(#modules+1) -- Count the export module, but not the argument module
  wbyte(2, 2) -- Export module is a module definition with 2 items

  wbyte(2) -- First item
  wint(lua_main:id())
  wstr("lua_main")

  wbyte(2) -- First item
  wint(main:id())
  wstr("main")

  for _, mod in ipairs(modules) do
    if mod.items then
      wbyte(2) -- define
      wint(#mod.items)
      for _, item in ipairs(mod.items) do
        if item.fn then
          wbyte(2)
          wint(item.fn:id())
        elseif item.tp then
          wbyte(1)
          wint(item.tp.id)
        else err("Unknown item kind for " .. tostr(item)) end
        wstr(item.name)
      end
    elseif mod.base and mod.argument then
      wbyte(4)-- build
      wint(mod.base.id)
      wint(mod.argument.id)
    elseif mod.from then
      wbyte(3) -- use
      wint(mod.from.id)
      wstr(mod.name)
    else -- import by default
      wbyte(1)
      wstr(mod.name)
    end
  end

  wint(#types)
  for i, tp in ipairs(types) do
    wint(tp.module + 1)
    wstr(tp.name)
  end

  wint(#funcs)
  for _, fn in ipairs(funcs) do
    if fn.code then
      wbyte(1)
    elseif fn.module then
      wint(fn.module + 2)
    else error("???") end
    wint(#fn.ins)
    for _, t in ipairs(fn.ins) do wint(t) end
    wint(#fn.outs)
    for _, t in ipairs(fn.outs) do wint(t) end
    if fn.module then wstr(fn.name) end
  end

  wint(#constants)
  for i, cns in ipairs(constants) do
    if cns.type == "int" then
      wbyte(1)
      wint(cns.value)
    elseif cns.type == "bin" then
      wbyte(2)
      wstr(cns.value)
    elseif cns.type == "call" then
      if #cns.args ~= #cns.f.ins then
        error(cns.f.name .. " expects " .. #cns.f.ins .. " arguments, but got " .. #cns.args)
      end
      wint(cns.f:id() + 16)
      for i, v in ipairs(cns.args) do
        wint(v:id())
      end
    else error("constant " .. cns.type .. " not supported") end
  end

  local function write_code (fn)

    local newcode = {}
    local regcount = 0

    local regs = #fn.regs

    local function getlbl (name, line)
      local lbl = fn.labels[name]
      if not lbl then
        error("no visible label '" .. name .. "' for <goto> at line " .. line)
      end
      return lbl
    end

    wint(#fn.code)
    for i, inst in ipairs(fn.code) do
      --print(tostr(inst,3))
      local f = inst[1]
      if f == "end" then
        if #inst-1 ~= #fn.outs then
          error(fn.name .. " outputs " .. #fn.outs .. " results, but end instrucion has " .. #inst-1)
        end
        wbyte(0)
        for i=2, #inst do
          wint(inst[i].reg)
        end
      elseif f == "dup" then
        wbyte(3)
        wint(inst[2].reg)
        inst.reg, regs = regs, regs+1
      elseif f == "set" then
        wbyte(4)
        wint(inst[2].reg)
        wint(inst[3].reg)
      elseif f == "jmp" then
        wbyte(5)
        wint(getlbl(inst[2], inst.line))
      elseif f == "jif" then
        wbyte(6)
        wint(getlbl(inst[2]))
        wint(inst[3].reg)
      elseif f == "nif" then
        wbyte(7)
        wint(getlbl(inst[2]))
        wint(inst[3].reg)
      elseif type(f) == "table" then
        -- Function call
        wint(f:id() + 16)
        for i = 2, #inst do
          wint(inst[i].reg)
        end
      else error("Unsupported instruction: " .. tostring(f)) end
    end
  end

  -- Code
  for _, fn in ipairs(funcs) do
    if fn.code then write_code(fn) end
  end

  function write_node (value)
    if type(value) == "number" then
      wint(value*2 + 1)--(value << 1 | 1)
    elseif type(value) == "string" then
      wint(#value*4 + 2)--(#value << 2 | 2)
      rstr(value)
    elseif type(value) == "table" then
      wint(#value*4)--(#value << 2)
      for i = 1, #value do
        write_node(value[i])
      end
    else error("wtf: " .. tostring(value)) end
  end
  write_node(metadata)
end