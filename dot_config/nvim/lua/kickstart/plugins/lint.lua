-- Linting

vim.pack.add { 'https://github.com/mfussenegger/nvim-lint' }

local lint = require 'lint'
lint.linters_by_ft = {
  java = { 'checkstyle' },
  markdown = { 'markdownlint' }, -- Make sure to install `markdownlint` via mason / npm
}

-- Use the CS 314 rules installed on this computer. The source configuration
-- points to its author's Linux home directory, which does not exist here.
lint.linters.checkstyle = {
  cmd = 'checkstyle',
  stdin = false,
  append_fname = true,
  ignore_exitcode = true,
  args = {
    '-c',
    vim.fn.expand '~/repos/cs314-hygiene-checker/checkstyle.xml',
  },
  parser = require('lint.parser').from_pattern('%[(%w+)%]%s+(.-):(%d+):(%d+):%s+(.*)', { 'severity', 'file', 'lnum', 'col', 'message' }, {
    WARN = vim.diagnostic.severity.WARN,
    ERROR = vim.diagnostic.severity.ERROR,
    INFO = vim.diagnostic.severity.INFO,
  }, { source = 'checkstyle' }),
}

-- To allow other plugins to add linters to require('lint').linters_by_ft,
-- instead set linters_by_ft like this:
-- lint.linters_by_ft = lint.linters_by_ft or {}
-- lint.linters_by_ft['markdown'] = { 'markdownlint' }
--
-- However, note that this will enable a set of default linters,
-- which will cause errors unless these tools are available:
-- {
--   clojure = { "clj-kondo" },
--   dockerfile = { "hadolint" },
--   inko = { "inko" },
--   janet = { "janet" },
--   json = { "jsonlint" },
--   markdown = { "vale" },
--   rst = { "vale" },
--   ruby = { "ruby" },
--   terraform = { "tflint" },
--   text = { "vale" }
-- }
--
-- You can disable the default linters by setting their filetypes to nil:
-- lint.linters_by_ft['clojure'] = nil
-- lint.linters_by_ft['dockerfile'] = nil
-- lint.linters_by_ft['inko'] = nil
-- lint.linters_by_ft['janet'] = nil
-- lint.linters_by_ft['json'] = nil
-- lint.linters_by_ft['markdown'] = nil
-- lint.linters_by_ft['rst'] = nil
-- lint.linters_by_ft['ruby'] = nil
-- lint.linters_by_ft['terraform'] = nil
-- lint.linters_by_ft['text'] = nil

-- Select JavaScript/TypeScript linting from the current file's project.
local project_filetypes = {
  javascript = true,
  javascriptreact = true,
  typescript = true,
  typescriptreact = true,
  svelte = true,
}
local eslint_configs = {
  'eslint.config.js', 'eslint.config.mjs', 'eslint.config.cjs',
  'eslint.config.ts', 'eslint.config.mts', 'eslint.config.cts',
  '.eslintrc', '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json',
  '.eslintrc.yaml', '.eslintrc.yml',
}

local function project_linter(filename)
  local directory = vim.fs.dirname(filename)
  while directory do
    if vim.uv.fs_stat(directory .. '/biome.json') or vim.uv.fs_stat(directory .. '/biome.jsonc') then
      return 'biomejs', 'biome', directory
    end
    for _, config in ipairs(eslint_configs) do
      if vim.uv.fs_stat(directory .. '/' .. config) then return 'eslint', 'eslint', directory end
    end
    local package = directory .. '/package.json'
    if vim.uv.fs_stat(package) then
      local ok, data = pcall(function() return vim.json.decode(table.concat(vim.fn.readfile(package), '\n')) end)
      if ok and type(data) == 'table' and data.eslintConfig ~= nil then return 'eslint', 'eslint', directory end
    end
    if vim.uv.fs_stat(directory .. '/.git') then break end
    local parent = vim.fs.dirname(directory)
    if parent == directory then break end
    directory = parent
  end
end

local function lint_buffer()
  if not vim.bo.modifiable or vim.bo.buftype ~= '' then return end
  if not project_filetypes[vim.bo.filetype] then
    lint.try_lint()
    return
  end

  local name, binary, root = project_linter(vim.api.nvim_buf_get_name(0))
  if not name then return end
  local executable = root .. '/node_modules/.bin/' .. binary
  if vim.fn.executable(executable) ~= 1 then executable = vim.fn.exepath(binary) end
  if executable == '' then
    vim.notify_once('Project linter ' .. binary .. ' is missing. Install project dependencies or install it in Mason.', vim.log.levels.WARN)
    return
  end
  lint.try_lint(name, {
    cwd = root,
    wrap_linter = function(linter)
      linter.cmd = executable
      return linter
    end,
  })
end

-- Create autocommand which carries out the actual linting
-- on the specified events.
local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  group = lint_augroup,
  pattern = { '*.java', '*.js', '*.jsx', '*.ts', '*.tsx', '*.svelte', '*.md' },
  callback = lint_buffer,
})
