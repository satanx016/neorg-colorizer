local neorg = require("neorg.core")
local module = neorg.modules.create("external.neorg-colorizer")

module.private = {
  namespace = vim.api.nvim_create_namespace("neorg-colorizer"),
}

module.public = {
  highlight_line = function(clr, ln_num)
    vim.api.nvim_set_hl(module.private.namespace, "ColorHlFor_" .. tostring(clr), { fg = "#" .. clr })
    vim.api.nvim_set_hl_ns(module.private.namespace) -- activate the created highlight group above

    vim.api.nvim_buf_add_highlight(0, module.private.namespace, "ColorHlFor_" .. tostring(clr), ln_num - 1, 0, -1)
  end,

  conceal_line = function(match, ln_num, ln_txt, offset)
    local start_col, end_col = string.find(ln_txt, match)
    offset = not offset and 0 or offset

    -- NOTE: remove white space to have conceals that respects indentations (e.i, "&color:#ffffff " <--)
    local white_space = string.sub(ln_txt, end_col + offset + 1, end_col + offset + 1) == " "
    offset = offset + (white_space and 1 or 0)

    vim.api.nvim_buf_set_extmark(0, module.private.namespace, ln_num - 1, start_col - 1, {
      end_line = ln_num - 1,
      end_col = end_col + offset,
      conceal = "",
    })
  end,

  colorize = function()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local is_colorizing = false
    local clr = "ffffff"

    for ln_num, ln_txt in ipairs(lines) do
      if is_colorizing then
        vim.api.nvim_buf_clear_namespace(0, module.private.namespace, ln_num, ln_num + 1)
        module.public.highlight_line(clr, ln_num)

        local end_colorizing = string.match(ln_txt, "&color_end")
        if end_colorizing then
          is_colorizing = false
          module.public.conceal_line("&color_end", ln_num, ln_txt)
        end

        goto continue
      end

      local line_colorizing = string.match(ln_txt, "&color:#(%x%x%x%x%x%x)")
      if line_colorizing then
        module.public.highlight_line(line_colorizing, ln_num)
        module.public.conceal_line("&color:", ln_num, ln_txt, 7)

        goto continue
      end

      local start_colorizing = string.match(ln_txt, "&color_start:#(%x%x%x%x%x%x)")
      if start_colorizing then
        is_colorizing = true
        clr = start_colorizing
        module.public.conceal_line("&color_start:", ln_num, ln_txt, 7)
        module.public.highlight_line(clr, ln_num)

        goto continue
      end

      vim.api.nvim_buf_clear_namespace(0, module.private.namespace, ln_num, ln_num + 1)

      ::continue::
    end
  end,
}

module.load = function()
  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
    group = vim.api.nvim_create_augroup("neorg_colorizer", {}),
    pattern = "*.norg",
    callback = function()
      module.public.colorize()
    end,
  })
end

return module
