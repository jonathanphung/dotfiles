-- Linting

vim.pack.add { 'https://github.com/mfussenegger/nvim-lint' }

local lint = require 'lint'
lint.linters_by_ft = {
  java = { 'checkstyle' },
  javascript = { 'eslint' },
  javascriptreact = { 'eslint' },
  typescript = { 'eslint' },
  typescriptreact = { 'eslint' },
  svelte = { 'eslint' },
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

-- Create autocommand which carries out the actual linting
-- on the specified events.
local lint_augroup = vim.api.nvim_create_augroup('lint', { clear = true })
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'InsertLeave' }, {
  group = lint_augroup,
  pattern = { '*.java', '*.js', '*.jsx', '*.ts', '*.tsx', '*.svelte', '*.md' },
  callback = function()
    -- Only run the linter in buffers that you can modify in order to
    -- avoid superfluous noise, notably within the handy LSP pop-ups that
    -- describe the hovered symbol using Markdown.
    if vim.bo.modifiable then lint.try_lint() end
  end,
})
