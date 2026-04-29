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

---@param text string
---@param area ui.Rect
---
---@return Renderable
local function error_widget(text, area)
  return ui.Text(text):wrap(ui.Wrap.YES):area(area) ---@type ui.Text
end

---@param job PeekJob
function M:peek(job)
  local uid = ya.uid()
  local vfs = Url("/run/user"):join(tostring(uid)):join("ratarmount")

  ---@diagnostic disable-next-line: undefined-field
  assert(job.file.url.is_absolute) -- Field is missing from types.yazi

  -- Make sure not to join an absolute path or the left hand side will be
  -- replaced
  local path_suffix = job.file.url:strip_prefix("/")
  local dir = vfs:join(tostring(path_suffix))
  assert(dir:starts_with(vfs))

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

  local raw_dir = tostring(dir)
  local child, err = Command("tree")
    :arg({ "--noreport", raw_dir })
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
    end

    -- Normally, the first line output from `tree` is the target folder.
    -- Replace this with the archive name to make it more readable.
    if line:gsub("\n$", "") == raw_dir then line = job.file.name end

    if skips >= job.skip then
      table.insert(lines, ui.Line({ " ", line })) -- One space padding
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

return M
