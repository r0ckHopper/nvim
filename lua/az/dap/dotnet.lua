-- HOWTO: Set up .NET MAUI Android debugging from scratch on Fedora Linux
--
-- Prerequisites:
--   .NET 10 SDK + maui-android workload, Android device via ADB, nvim-dap + dap-ui
--
-- 1. Build mono-debug DAP server (from vscode-mono-debug source):
--    cd /tmp
--    git clone --depth 1 https://github.com/microsoft/vscode-mono-debug.git
--    cd vscode-mono-debug
--    git submodule update --init --depth 1
--    sed -i 's|net472|net10.0|' src/csharp/mono-debug.csproj
--    for f in external/debugger-libs/Mono.Debugger.Soft/Mono.Debugger.Soft.csproj \
--             external/debugger-libs/Mono.Debugging/Mono.Debugging.csproj \
--             external/debugger-libs/Mono.Debugging.Soft/Mono.Debugging.Soft.csproj; do
--      sed -i 's|<SignAssembly>True</SignAssembly>|<SignAssembly>false</SignAssembly>|' "$f"
--      sed -i '/<AssemblyOriginatorKeyFile>/d' "$f"
--    done
--    dotnet build src/csharp/mono-debug.csproj -c Release
--    mkdir -p ~/mono-debug && cp -r bin/Release/* ~/mono-debug/
--
-- 2. Patch the plugin's monovsdbg adapter (~/.local/.../dotnet-debug/init.lua):
--    After build succeeds, replace the on_config(...) call with:
--      vim.uv.spawn("~/mono-debug/mono-debug", { args = {"--server"}, detached = true })
--      config.request = "attach"
--      config.address = "localhost"
--      config.port = 50703
--      on_config({ id = "mono", type = "server", port = 4711 })
--
-- 3. Add dap configuration (dap.lua):
--    { type = "monovsdbg", name = "Launch MAUI Android", request = "launch",
--      projectPath = "${workspaceFolder}/YourProject.csproj" }
--
-- Flow: nvim-dap → plugin builds+t:Run (deploys app, starts Mono debug server :50703)
--       → mono-debug --server (:4711) → nvim-dap connects → attach(localhost:50703)
--       → Mono Soft Debugger Protocol over ADB → breakpoints work

vim.pack.add({
	"https://github.com/kmiterror/dotnet-debug.nvim",
})

require("dotnet-debug").setup({
	debugger_path = vim.fn.expand("~/vsdbg/vsdbg"),  -- Microsoft vsdbg (for coreclr debugging)
})
