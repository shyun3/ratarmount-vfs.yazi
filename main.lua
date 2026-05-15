---@class PeekJob
---
--- Derived from https://yazi-rs.github.io/docs/plugins/overview/#previewer
---
---@field area ui.Rect `Rect` of the available preview area.
---@field args string[] Arguments passed to the previewer.
---@field file File `File` to be previewed.
---@field skip number Number of units to skip. The units depend on your
---  previewer, such as lines for code and percentages for videos.

---@class SeekJob
---
--- Derived from https://yazi-rs.github.io/docs/plugins/overview/#previewer
---
---@field file File `File` being scrolled.
---@field area ui.Rect `Rect` of the available preview area.
---@field units number Number of units to scroll.

local M = {}

--- `entry` helper for gathering selected files
---
---@return Url[]
local get_entry_vfs_targets = ya.sync(function()
  local urls = {}

  local tab = cx.active
  if #tab.selected == 0 then
    local hovered = tab.current.hovered
    if hovered then table.insert(urls, hovered.url) end
  else
    for _, url in pairs(tab.selected) do
      table.insert(urls, url)
    end
  end

  return urls
end)

--- Prepends the default Ratarmount VFS directory to the given location
---
---@param url Url Must be an absolute path
---
---@return Url Corresponding location under the Ratarmount VFS
local function prepend_vfs_dir(url)
  ---@diagnostic disable-next-line: undefined-field
  assert(url.is_absolute) -- Field is missing from types.yazi

  local uid = tostring(ya.uid())
  local vfs = Url("/run/user"):join(uid):join("ratarmount")

  -- Make sure not to join an absolute path or the left hand side will be
  -- replaced
  local path_suffix = url:strip_prefix("/")
  local result = vfs:join(tostring(path_suffix))
  assert(result:starts_with(vfs))

  return result
end

--- Enters the Ratarmount VFS locations corresponding to the given files
---
---@param urls (string | Url)[] Strings must be in URL format
local function goto_vfs(urls)
  for _, url in pairs(urls) do
    ya.emit("tab_create", { prepend_vfs_dir(Url(url)) })
  end
end

---@param text string
---@param area ui.Rect
---
---@return Renderable
local function error_widget(text, area)
  return ui.Text(text):wrap(ui.Wrap.YES):area(area) ---@type ui.Text
end

---@param line string Line output from `tree`. Assumes the `-p` flag was used
---  and the trailing newline was stripped.
---
---@return string prefix Tree branch
---@return string? filename
---@return string filetype See `ls` permissions output
local function split_tree_line(line)
  local pre_start, pre_end = line:find("^[^[]-─ ")
  local prefix = pre_start and line:sub(pre_start, pre_end) or ""

  local _, _, filetype, filename =
    line:find("^(%b[])  (.*)$", pre_end and pre_end + 1 or 1)
  return prefix, filename, filetype and filetype:sub(2, 2) or ""
end

---@param line string Line output from `tree`
---
---@return ui.Line | string
local function parse_tree_line(line)
  local prefix, filename, type = split_tree_line(line)
  if not filename then return line end

  local icon = File({
    url = Url(filename),
    cha = Cha({
      mode = tonumber(type == "d" and "40700" or "100644", 8),
    }),
  }):icon()

  return icon
      and ui.Line({
        prefix,
        ui.Span(icon.text .. " "):style(icon.style),
        filename,
      })
    or line
end

function M:setup() ps.sub_remote("ratarmount-vfs", goto_vfs) end

---@param job PeekJob
function M:peek(job)
  local dir = prepend_vfs_dir(job.file.url)

  ya.preview_widget(
    job,
    ui.Line("Loading..."):align(ui.Align.CENTER):area(job.area)
  )

  local cha = fs.cha(dir)
  if not cha or not cha.is_dir then
    local msg = ("Error reading %s\nCheck ratarmount VFS."):format(dir)
    return ya.preview_widget(job, error_widget(msg, job.area))
  end

  local status = Command("tree"):arg("--version"):status()
  if not status or not status.success then
    local msg = "Error running `tree`. Confirm that it is installed."
    return ya.preview_widget(job, error_widget(msg, job.area))
  end

  local child, err = Command("tree")
    :arg({ "--noreport", "-p", tostring(dir) })
    :stdout(Command.PIPED)
    :stderr(Command.PIPED)
    :spawn()
  if not child or err then
    local msg = ("Error launching `tree`:\n%s"):format(err)
    return ya.preview_widget(job, error_widget(msg, job.area))
  end

  local limit = job.area.h
  local lines = {}
  local skips = 0
  while #lines < job.skip + limit do
    local line, event = child:read_line()
    if not line or event == 2 then break end

    if event == 1 then
      local msg = ("ratarmount-vfs:%s: %s"):format(dir, line)
      ya.err(msg)
    else
      line = line:gsub("\n$", "")

      -- Normally, the first line output from `tree` is the target folder.
      -- Replace this with the archive name to make it more readable.
      if line:sub(1, 1) == "[" then
        line = ("[%s]  %s"):format(job.file.cha.perm, job.file.name)
      end
    end

    if skips >= job.skip then
      table.insert(
        lines,
        ui.Line({ " ", parse_tree_line(line) }) -- One space padding
      )
    else
      skips = skips + 1
    end
  end

  child:start_kill()

  local bound = math.max(0, #lines - limit)
  if job.skip > bound then
    -- `peek` is not in docs, as of v26.1.22
    ya.emit("peek", {
      bound,
      only_if = job.file.url,
      upper_bound = true,
    })
  else
    ya.preview_widget(job, ui.Text(lines):area(job.area))
  end
end

---@param job SeekJob
function M:seek(job) require("code"):seek(job) end

function M:entry() goto_vfs(get_entry_vfs_targets()) end

return M
