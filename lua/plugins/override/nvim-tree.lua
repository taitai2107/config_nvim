local map = vim.keymap.set

---@type NvPluginSpec
return {
  "nvim-tree/nvim-tree.lua",
  init = function()
    map("n", "<C-n>", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle NvimTree" })
  end,
  config = function()
    dofile(vim.g.base46_cache .. "nvimtree")

    local nvtree = require "nvim-tree"
    local api = require "nvim-tree.api"

    -- Add custom mappings
    local function custom_on_attach(bufnr)
      local function opts(desc)
        return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
      end

      api.config.mappings.default_on_attach(bufnr)
      map("n", "+", api.tree.change_root_to_node, opts "CD")
      map("n", "?", api.tree.toggle_help, opts "Help")
      map("n", "<ESC>", api.tree.close, opts "Close")
    end

    local path_sep = package.config:sub(1, 1)

    local function trim_sep(path)
      return path:gsub(path_sep .. "$", "")
    end

    local function uri_from_path(path)
      return vim.uri_from_fname(trim_sep(path))
    end

    local function is_sub_path(path, folder)
      path = trim_sep(path)
      folder = trim_sep(folder)
      if path == folder then
        return true
      else
        return path:sub(1, #folder + 1) == folder .. path_sep
      end
    end

    local function check_folders_contains(folders, path)
      for _, folder in pairs(folders) do
        if is_sub_path(path, folder.name) then
          return true
        end
      end
      return false
    end

    local function match_file_operation_filter(filter, name, type)
      if filter.scheme and filter.scheme ~= "file" then
        -- we do not support uri scheme other than file
        return false
      end
      local pattern = filter.pattern
      local matches = pattern.matches

      if type ~= matches then
        return false
      end

      local regex_str = vim.fn.glob2regpat(pattern.glob)
      if vim.tbl_get(pattern, "options", "ignoreCase") then
        regex_str = "\\c" .. regex_str
      end
      return vim.regex(regex_str):match_str(name) ~= nil
    end

    -- Automatically open file upon creation
    api.events.subscribe(api.events.Event.FileCreated, function(file)
      vim.cmd("edit " .. file.fname)
    end)

    -- Automatically detect and update renamed paths
    api.events.subscribe(api.events.Event.NodeRenamed, function(data)
      local stat = vim.uv.fs_stat(data.new_name)
      if not stat then
        return
      end
      local type = ({ file = "file", directory = "folder" })[stat.type]
      local clients = vim.lsp.get_clients {}
      for _, client in ipairs(clients) do
        if check_folders_contains(client.workspace_folders, data.old_name) then
          local filters = vim.tbl_get(client.server_capabilities, "workspace", "fileOperations", "didRename", "filters")
            or {}
          for _, filter in pairs(filters) do
            if
              match_file_operation_filter(filter, data.old_name, type)
              and match_file_operation_filter(filter, data.new_name, type)
            then
              client.notify(
                "workspace/didRenameFiles",
                { files = { { oldUri = uri_from_path(data.old_name), newUri = uri_from_path(data.new_name) } } }
              )
            end
          end
        end
      end
    end)

    local SIZES = {
      HEIGHT = 0.8,
      WIDTH = 0.5,
    }

    nvtree.setup {
      update_focused_file = {
        enable = true,
      },
      on_attach = custom_on_attach,
      sync_root_with_cwd = true,
      filters = { custom = { "^.git$" } },
      git = { enable = true },
      renderer = {
        highlight_git = "none",
        icons = {
          glyphs = {
            folder = {
              default = "",
              open = "",
              empty = "",
              empty_open = "",
            },
            git = {
              unstaged = "",
              staged = "",
              unmerged = "",
              renamed = "",
              untracked = "",
              deleted = "",
              ignored = "󰴲",
            },
          },
        },
      },
          view = {
        centralize_selection = false,
        cursorline = true,
        debounce_delay = 15,
        side = "left",
        preserve_window_proportions = false,
        number = false,
        relativenumber = false,
        signcolumn = "yes",
        width = 30,
        float = {
          enable = false,
          quit_on_focus_loss = true,
          open_win_config = {
            relative = "editor",
            border = "rounded",
            width = 30,
            height = 30,
            row = 1,
            col = 1,
          },
        },
      },
      filesystem_watchers = {
        ignore_dirs = {
          "node_modules",
        },
      },
    }
  end,
}
