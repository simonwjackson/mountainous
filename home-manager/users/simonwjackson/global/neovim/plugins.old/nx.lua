require('nx').setup {
  -- Base command to run all other nx commands, some other values may be:
  -- - `npm nx`
  -- - `yarn nx`
  -- - `pnpm nx`
  nx_cmd_root = 'nx',

  -- Command running capabilities,
  -- see nx.m.command-runners for more details
  command_runner = require('nx.command-runners').terminal_command_runner(),
  -- Form rendering capabilities,
  -- see nx.m.form-renderers for more detials
  form_renderer = require('nx.form-renderers').telescope_form_renderer(),

  -- Whether or not to load nx configuration,
  -- see nx.loading-and-reloading for more details
  read_init = true,
}
