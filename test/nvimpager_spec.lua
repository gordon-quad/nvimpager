-- Busted tests for nvimpager

-- Busted defines these objects but luacheck doesn't know them.  So we
-- redefine them and tell luacheck to ignore it.
local describe, it, assert, pending, mock, match =
      describe, it, assert, pending, mock, match  -- luacheck: ignore

-- gloabl varables to set $XDG_CONFIG_HOME and $XDG_DATA_HOME to for the
-- tests.
local confdir = "test/fixtures/no-config"
local datadir = "test/fixtures/no-data"

-- Run a shell command, assert it terminates with return code 0 and return its
-- output.
--
-- command: string -- the shell command to execute
-- returns: string -- the output of the command
local function run(command)
  command = 'XDG_CONFIG_HOME='..confdir..' ' .. command
  command = 'XDG_DATA_HOME='..datadir..' ' .. command
  command = 'env ' .. command
  local proc = io.popen(command)
  local output = proc:read('*all')
  local status = {proc:close()}
  assert.equal(true, status[1])
  return output
end

-- Read contents of a file and return them.
--
-- filename: string -- the name of the file to read
-- returns: string -- the contents of the file
local function read(filename)
  local file = io.open(filename)
  local contents = file:read('*all')
  return contents
end

describe("auto mode", function()
  -- Auto mode only exists during the run of the bash script.  At the end of
  -- the bash script it has to decide if pager or cat mode is used.  This
  -- makes these tests a little more difficult.  We have to inspect the state
  -- of the bash script in some way.

  -- Source the given command line in a bash script with some mocks and print
  -- all set variables at the end.
  --
  -- command: string -- the shell command to execute
  -- returns: string -- the output of the sourced command and all set
  -- variables
  local function bash(command)
    -- Make nvim an alias with a semicolon so potential redirections in the
    -- original nvim execution don't take effect.  Also mock exec and trap.
    local script = [[
      set -e
      set -u
      shopt -s expand_aliases
      alias nvim='return; '
      alias exec=:
      alias trap=:
      source ]] .. command .. "\nset"
    local filename = os.tmpname()
    local file = io.open(filename, "w")
    file:write(script)
    file:close()
    local output = run("bash " .. filename)
    --os.remove(filename)
    return output
  end

  it("selects cat mode for small files", function()
    local output = bash('./nvimpager test/fixtures/makefile')
    -- $mode might still be auto so we check the generated command line.
    local default_args = output:match("\ndefault_args[^\n]*\n")
    assert.truthy(default_args:match('--headless'))
  end)

  it("auto mode selects pager mode for big inputs", function()
    local output = bash('./nvimpager ./README.md ./nvimpager')
    -- $mode might still be auto so we check the generated command line.
    local default_args = output:match("\ndefault_args[^\n]*\n")
    assert.is_nil(default_args:match('--headless'))
  end)
end)

describe("cat mode", function()
  it("displays a small file with syntax highlighting to stdout", function()
    local output = run("./nvimpager -c test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("reads stdin with syntax highlighting", function()
    local output = run("./nvimpager -c -- -c 'set filetype=make' " ..
                       "< test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("returns ansi escape sequences unchanged", function()
    local output = run("./nvimpager -c < test/fixtures/makefile.ansi")
    local expected = read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  it("highlights all files", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
                                      "test/fixtures/help.txt")
    local expected = read("test/fixtures/makefile.ansi") ..
                     read("test/fixtures/help.txt.ansi")
    assert.equal(expected, output)
  end)

  it("concatenates the same file twice", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
                                      "test/fixtures/makefile")
    local expected = read("test/fixtures/makefile.ansi")
    expected = expected .. expected
    assert.equal(expected, output)
  end)

  it("produces no output for empty files", function()
    local tmp = os.tmpname()
    -- This hangs if /dev/null is used instead.
    local output = run("./nvimpager -c "..tmp)
    os.execute('rm '..tmp)
    assert.equal('', output)
  end)

  it("produces no output for empty stdin", function()
    local output = run("./nvimpager -c </dev/null")
    assert.equal('', output)
  end)

  pending("highlights files even after mode line files", function()
    local output = run("./nvimpager -c test/fixtures/conceal.tex " ..
		       "test/fixtures/makefile " ..
		       "--cmd \"let g:tex_flavor='latex'\"")
    local expected = read("test/fixtures/conceal.tex.ansi") ..
                     read("test/fixtures/makefile.ansi")
    assert.equal(expected, output)
  end)

  pending("honors mode lines in later files", function()
    local output = run("./nvimpager -c test/fixtures/makefile " ..
		       "test/fixtures/conceal.tex " ..
		       "--cmd \"let g:tex_flavor='latex'\"")
    local expected = read("test/fixtures/makefile.ansi") ..
                     read("test/fixtures/conceal.tex.ansi")
    assert.equal(expected, output)
  end)

  describe("conceals", function()
    local function test_level(level)
      local output = run("./nvimpager -c test/fixtures/help.txt "..
			 "-c 'set cole="..level.."'")
      local expected = read("test/fixtures/help.txt.cole"..level..".ansi")
      assert.equal(expected, output)
    end
    it("are removed at conceallevel=2", function() test_level(2) end)
    it("are hidden at conceallevel=1", function() test_level(1) end)
    it("are highlighted at conceallevel=0", function() test_level(0) end)
  end)

  describe("conceal replacements", function()
    local function test_replace(level)
      local output = run("./nvimpager -c test/fixtures/conceal.tex "..
			 "--cmd \"let g:tex_flavor='latex'\" "..
			 "-c 'set cole="..level.."'")
      local expected = read("test/fixtures/conceal.tex.cole"..level..".ansi")
      assert.equal(expected, output)
    end
    it("are replaced at conceallevel=2", function() test_replace(2) end)
    it("are replaced at conceallevel=1", function() test_replace(1) end)
    it("are highlighted at conceallevel=0", function() test_replace(0) end)
  end)
end)

describe("pager mode", function()
  it("starts up and quits correctly", function()
    run("./nvimpager -p makefile -c quit")
  end)
end)

describe("backend:", function()
  it("runtimepath doesn't include nvim's user dirs", function()
    local cmd = "RUNTIME=special-test-value " ..
      "nvim --headless " ..
      "--cmd 'set runtimepath+=.' " ..
      "--cmd 'call pager#start()' " ..
      "--cmd 'let rtp = nvim_list_runtime_paths()' " ..
      "--cmd 'if index(rtp, $RUNTIME) == -1 | cquit | endif' " ..
      "--cmd 'if index(rtp, stdpath(\"config\")) != -1 | cquit | endif' " ..
      "--cmd 'if index(rtp, stdpath(\"data\")) != -1 | cquit | endif' " ..
      "--cmd quit"
    run(cmd)
  end)

  it("plugin manifest doesn't contain nvim's value", function()
    -- Nvim writes this message to stderr so we have to redirect this.
    local output = run("./nvimpager -c -- README.md " ..
                       "-c 'echo $NVIM_RPLUGIN_MANIFEST' -c quit 2>&1")
    assert.equal(datadir..'/nvimpager/rplugin.vim', output)
  end)
end)

describe("lua functions", function()

  -- Reload the nvimpager script.
  --
  -- api: table|nil -- a mock for the neovim api table
  -- return: table -- the nvimpager module
  local function load_nvimpager(api)
    -- Create a local mock of the vim module that is provided by neovim.
    local default_api = {
      nvim_get_hl_by_id = function() return {} end,
      -- These can return different types so we just default to nil.
      nvim_call_function = function() end,
      nvim_get_option = function() end,
    }
    if api == nil then
      api = default_api
    else
      for key, value in pairs(default_api) do
	if api[key] == nil then
	  api[key] = value
	end
      end
    end
    local vim = { api = api }
    -- Register the api mock in the globals.
    _G.vim = vim
    -- Reload the nvimpager script
    package.loaded["lua/nvimpager"] = nil
    return require("lua/nvimpager")
  end

  describe("split_rgb_number", function()
    it("handles numbers from 0 to 16777215", function()
      local nvimpager = load_nvimpager()
      local r, g, b = nvimpager.split_rgb_number(0x000000)
      assert.equal(0, r)
      assert.equal(0, g)
      assert.equal(0, b)
      r, g, b = nvimpager.split_rgb_number(0xFFFFFF)
      assert.equal(255, r)
      assert.equal(255, g)
      assert.equal(255, b)
    end)

    it("correctly splits rgb values", function()
      local nvimpager = load_nvimpager()
      local r, g, b = nvimpager.split_rgb_number(0x55AACC)
      assert.equal(0x55, r)
      assert.equal(0xAA, g)
      assert.equal(0xCC, b)
    end)
  end)

  describe("group2ansi", function()
    it("calls nvim_get_hl_by_id with and without termguicolors", function()
      for _, termguicolors in pairs({true, false}) do
	local api = {
	  nvim_get_hl_by_id = function() return {} end,
	  nvim_get_option = function() return termguicolors end,
	  nvim_call_function = function() return 0 end,
	}
	local m = mock(api)
	local nvimpager = load_nvimpager(api)
	nvimpager.init_cat_mode()
	local escape = nvimpager.group2ansi(100)
	assert.stub(m.nvim_get_hl_by_id).was.called_with(100, termguicolors)
	assert.equal('\x1b[0m', escape)
      end
    end)
  end)

  describe("color2escape_24bit", function()
    it("creates foreground escape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_24bit(0xaabbcc, true)
      assert.equal('38;2;170;187;204', e)
    end)

    it("creates background escape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_24bit(0xccbbaa, false)
      assert.equal('48;2;204;187;170', e)
    end)
  end)

  describe("color2escape_8bit", function()
    it("creates 8 colors foreground escaape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_8bit(5, true)
      assert.equal('35', e)
    end)

    it("creates 8 colors background escaape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_8bit(7, false)
      assert.equal('47', e)
    end)

    it("creates 16 colors foreground escaape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_8bit(5 + 8, true)
      assert.equal('95', e)
    end)

    it("creates 16 colors background escaape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_8bit(7 + 8, false)
      assert.equal('107', e)
    end)

    it("creates foreground escape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_8bit(0xaa, true)
      assert.equal('38;5;170', e)
    end)

    it("creates background escape sequences", function()
      local nvimpager = load_nvimpager()
      local e = nvimpager.color2escape_8bit(0xbb, false)
      assert.equal('48;5;187', e)
    end)
  end)

end)

describe("parent detection", function()
  it("handles git", function()
    local output = run("test/fixtures/bin/git ./nvimpager -c test/fixtures/diff")
    local expected = read("test/fixtures/diff.ansi")
    assert.equal(expected, output)
  end)

  it("handles man", function()
    local output = run("test/fixtures/bin/man ./nvimpager -c test/fixtures/man.cat")
    local expected = read("test/fixtures/man.ansi")
    assert.equal(expected, output)
  end)
end)
