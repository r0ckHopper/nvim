local M = {}

M.state = {
  proc = nil,
  filepath = nil,
  recording = false,
}

local function timestamp()
  return os.date("%Y-%m-%d_%H-%M-%S")
end

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "wf-recorder" })
end

vim.api.nvim_create_autocmd("User", {
  pattern = "WfRecorderStop",
  callback = function()
    M.state.recording = false
    M.state.proc = nil
    M.state.filepath = nil
  end,
})

function M.start()
  if M.state.recording and M.state.proc then
    notify("Already recording: " .. M.state.filepath, vim.log.levels.WARN)
    return
  end

  local dir = vim.fn.getcwd()
  M.state.filepath = dir .. "/" .. timestamp() .. ".mp4"

  M.state.proc = vim.system(
    { "wf-recorder", "-f", M.state.filepath },
    { detach = true },
    function(obj)
      if obj.code == 0 then
        notify("Recording saved: " .. M.state.filepath)
      else
        notify("Recording stopped (code " .. obj.code .. ")", vim.log.levels.WARN)
      end
      vim.schedule(function()
        vim.api.nvim_exec_autocmds("User", { pattern = "WfRecorderStop" })
      end)
    end
  )

  M.state.recording = true
  notify("Recording started: " .. M.state.filepath)
end

function M.save()
  if not M.state.recording or not M.state.proc then
    notify("No active recording", vim.log.levels.WARN)
    return
  end

  local path = M.state.filepath
  notify("Saving recording...")
  M.state.proc:kill("sigint")
  M.state.recording = false
end

function M.discard()
  if not M.state.recording or not M.state.proc then
    notify("No active recording", vim.log.levels.WARN)
    return
  end

  local path = M.state.filepath
  M.state.proc:kill("sigkill")
  M.state.recording = false
  M.state.proc = nil
  M.state.filepath = nil

  vim.schedule(function()
    if path and vim.fn.filereadable(path) == 1 then
      vim.fn.delete(path)
      notify("Recording discarded")
    end
  end)
end

function M.discard_restart()
  if M.state.recording then
    M.discard()
    vim.wait(200)
  end
  M.start()
end

function M.status()
  if M.state.recording then
    return " REC"
  end
  return ""
end

vim.api.nvim_create_user_command("Wfr", function()
  M.start()
end, { desc = "wf-recorder: start recording" })

vim.api.nvim_create_user_command("Wfs", function()
  M.save()
end, { desc = "wf-recorder: save recording" })

vim.api.nvim_create_user_command("Wfd", function()
  M.discard()
end, { desc = "wf-recorder: discard recording" })

vim.api.nvim_create_user_command("Wfdr", function()
  M.discard_restart()
end, { desc = "wf-recorder: discard and restart" })

return M
