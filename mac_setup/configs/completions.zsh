# =============================================================================
# Custom zsh completions for CLIs missing from carapace/oh-my-zsh
# =============================================================================

# ---------------------------------------------------------------------------
# claude
# ---------------------------------------------------------------------------
_claude() {
  local -a commands=(
    'agents:List configured agents'
    'auth:Manage authentication'
    'doctor:Check auto-updater health'
    'install:Install Claude Code native build'
    'mcp:Configure and manage MCP servers'
    'plugin:Manage Claude Code plugins'
    'setup-token:Set up a long-lived authentication token'
    'update:Check for updates and install'
    'upgrade:Check for updates and install'
  )

  local -a options=(
    '--add-dir[Additional directories to allow tool access to]:directories:_files -/'
    '--agent[Agent for the current session]:agent:'
    '--agents[JSON object defining custom agents]:json:'
    '--allow-dangerously-skip-permissions[Enable bypassing all permission checks as an option]'
    '--allowed-tools[Comma or space-separated list of tool names to allow]:tools:'
    '--append-system-prompt[Append a system prompt]:prompt:'
    '--betas[Beta headers to include in API requests]:betas:'
    '--chrome[Enable Claude in Chrome integration]'
    '(-c --continue)'{-c,--continue}'[Continue the most recent conversation]'
    '--dangerously-skip-permissions[Bypass all permission checks]'
    '(-d --debug)'{-d,--debug}'[Enable debug mode with optional category filtering]::filter:'
    '--debug-file[Write debug logs to a specific file path]:path:_files'
    '--disable-slash-commands[Disable all skills]'
    '--disallowed-tools[Comma or space-separated list of tool names to deny]:tools:'
    '--effort[Effort level for the current session]:level:(low medium high)'
    '--fallback-model[Enable automatic fallback to specified model]:model:'
    '--file[File resources to download at startup]:specs:'
    '--fork-session[Create a new session ID when resuming]'
    '--from-pr[Resume a session linked to a PR]::pr:'
    '(-h --help)'{-h,--help}'[Print usage]'
    '--ide[Automatically connect to IDE on startup]'
    '--include-partial-messages[Include partial message chunks]'
    '--input-format[Input format]:format:(text stream-json)'
    '--json-schema[JSON Schema for structured output validation]:schema:'
    '--max-budget-usd[Maximum dollar amount to spend]:amount:'
    '--mcp-config[Load MCP servers from JSON files or strings]:configs:_files'
    '--model[Model for the current session]:model:(sonnet opus haiku)'
    '--no-chrome[Disable Claude in Chrome integration]'
    '--no-session-persistence[Disable session persistence]'
    '--output-format[Output format]:format:(text json stream-json)'
    '--permission-mode[Permission mode]:mode:(acceptEdits bypassPermissions default dontAsk plan auto)'
    '--plugin-dir[Load plugins from directories]:paths:_files -/'
    '(-p --print)'{-p,--print}'[Print response and exit]'
    '--replay-user-messages[Re-emit user messages from stdin]'
    '(-r --resume)'{-r,--resume}'[Resume a conversation by session ID]::session:'
    '--session-id[Use a specific session ID]:uuid:'
    '--setting-sources[Comma-separated list of setting sources]:sources:'
    '--settings[Path to settings JSON file or JSON string]:file:_files'
    '--strict-mcp-config[Only use MCP servers from --mcp-config]'
    '--system-prompt[System prompt for the session]:prompt:'
    '--tmux[Create a tmux session for the worktree]'
    '--tools[Specify the list of available tools]:tools:'
    '--verbose[Override verbose mode setting from config]'
    '(-v --version)'{-v,--version}'[Output the version number]'
    '(-w --worktree)'{-w,--worktree}'[Create a new git worktree]::name:'
  )

  _arguments -s -S \
    '1: :->cmd_or_prompt' \
    '*: :->args' && return 0

  case "$state" in
    cmd_or_prompt)
      _describe 'command' commands
      _arguments -s -S $options
      ;;
    args)
      _arguments -s -S $options
      ;;
  esac
}
compdef _claude claude

# ---------------------------------------------------------------------------
# cursor agent
# ---------------------------------------------------------------------------
_cursor() {
  local -a options=(
    '(-d --diff)'{-d,--diff}'[Compare two files]:file1:_files:file2:_files'
    '(-m --merge)'{-m,--merge}'[Perform a three-way merge]:path1:_files:path2:_files:base:_files:result:_files'
    '(-a --add)'{-a,--add}'[Add folder to last active window]:folder:_files -/'
    '--remove[Remove folder from last active window]:folder:_files -/'
    '(-g --goto)'{-g,--goto}'[Open a file at line\:character]:file\:line\:char:_files'
    '(-n --new-window)'{-n,--new-window}'[Force open a new window]'
    '(-r --reuse-window)'{-r,--reuse-window}'[Force open in existing window]'
    '(-w --wait)'{-w,--wait}'[Wait for files to be closed]'
    '--locale[The locale to use]:locale:'
    '--user-data-dir[User data directory]:dir:_files -/'
    '--profile[Open with a given profile]:profileName:'
    '(-h --help)'{-h,--help}'[Print usage]'
    '--add-mcp[Add MCP server definition]:json:'
    '--chat[Open a standalone chat window]'
    '--extensions-dir[Set root path for extensions]:dir:_files -/'
    '--list-extensions[List installed extensions]'
    '--show-versions[Show versions of installed extensions]'
    '--install-extension[Install or update an extension]:ext-id:'
    '--uninstall-extension[Uninstall an extension]:ext-id:'
    '--update-extensions[Update installed extensions]'
    '(-v --version)'{-v,--version}'[Print version]'
    '--verbose[Print verbose output]'
    '--log[Log level]:level:(critical error warn info debug trace off)'
    '(-s --status)'{-s,--status}'[Print process usage and diagnostics]'
    '--disable-extensions[Disable all installed extensions]'
    '--disable-extension[Disable provided extension]:ext-id:'
    '--disable-gpu[Disable GPU hardware acceleration]'
    '--telemetry[Show all telemetry events]'
  )

  local -a subcommands=(
    'tunnel:Make machine accessible through a secure tunnel'
    'serve-web:Run a server that displays the editor UI in browsers'
    'agent:Start the Cursor agent in your terminal'
  )

  local -a agent_options=(
    '(-v --version)'{-v,--version}'[Output the version number]'
    '--api-key[API key for authentication]:key:'
    '(-H --header)'{-H,--header}'[Add custom header]:header:'
    '(-p --print)'{-p,--print}'[Print responses to console]'
    '--output-format[Output format]:format:(text json stream-json)'
    '--stream-partial-output[Stream partial output as individual text deltas]'
    '(-c --cloud)'{-c,--cloud}'[Start in cloud mode]'
    '--mode[Execution mode]:mode:(plan ask)'
    '--plan[Start in plan mode]'
    '--resume[Resume a session]::chatId:'
    '--continue[Continue previous session]'
    '--model[Model to use]:model:(gpt-5 sonnet-4 sonnet-4-thinking)'
    '--list-models[List available models and exit]'
    '(-f --force)'{-f,--force}'[Force allow commands unless explicitly denied]'
    '--yolo[Alias for --force]'
    '--sandbox[Enable or disable sandbox mode]:mode:(enabled disabled)'
    '--approve-mcps[Automatically approve all MCP servers]'
    '--trust[Trust the current workspace without prompting]'
    '--workspace[Workspace directory]:path:_files -/'
    '(-w --worktree)'{-w,--worktree}'[Start in an isolated git worktree]::name:'
    '--worktree-base[Branch or ref to base the worktree on]:branch:'
    '--skip-worktree-setup[Skip running worktree setup scripts]'
    '(-h --help)'{-h,--help}'[Display help]'
  )

  local -a agent_subcommands=(
    'install-shell-integration:Install shell integration to ~/.zshrc'
    'uninstall-shell-integration:Remove shell integration from ~/.zshrc'
    'login:Authenticate with Cursor'
    'logout:Sign out and clear stored authentication'
    'mcp:Manage MCP servers'
    'status:View authentication status'
    'whoami:View authentication status'
    'models:List available models'
    'about:Display version, system, and account information'
    'update:Update Cursor Agent to the latest version'
    'create-chat:Create a new empty chat'
    'generate-rule:Generate a new Cursor rule'
    'rule:Generate a new Cursor rule'
    'agent:Start the Cursor Agent'
    'ls:Resume a chat session'
    'resume:Resume the latest chat session'
  )

  local curcontext="$curcontext" state line
  _arguments -C \
    '1:command:->first' \
    '*::arg:->rest' && return 0

  case "$state" in
    first)
      _describe 'command' subcommands
      _arguments -s -S $options
      ;;
    rest)
      case "${line[1]}" in
        agent)
          _arguments -C \
            '1:agent command:->agent_cmd' \
            '*::agent arg:->agent_rest' && return 0
          case "$state" in
            agent_cmd)
              _describe 'agent command' agent_subcommands
              _arguments -s -S $agent_options
              ;;
            agent_rest)
              _arguments -s -S $agent_options
              ;;
          esac
          ;;
        *)
          _arguments -s -S $options
          ;;
      esac
      ;;
  esac
}
compdef _cursor cursor

# ---------------------------------------------------------------------------
# gemini
# ---------------------------------------------------------------------------
_gemini() {
  local -a commands=(
    'extensions:Manage extensions (install, uninstall, update, enable, disable)'
    'mcp:Configure MCP servers (add, remove, list)'
    'skills:Manage agent skills (list, install, link, uninstall)'
    'update:Update to latest version'
  )

  local -a options=(
    '(-d --debug)'{-d,--debug}'[Run in debug mode with verbose logging]'
    '(-e --extensions)'{-e,--extensions}'[Specify extensions to use]:extensions:'
    '(-h --help)'{-h,--help}'[Show help]'
    '(-i --prompt-interactive)'{-i,--prompt-interactive}'[Execute prompt then remain in interactive mode]:prompt:'
    '(-l --list-extensions)'{-l,--list-extensions}'[Display all available extensions]'
    '--list-sessions[Show available sessions for current project]'
    '--delete-session[Remove a session by index]:index:'
    '(-m --model)'{-m,--model}'[Model to use]:model:'
    '(-o --output-format)'{-o,--output-format}'[Output format]:format:(text json stream-json)'
    '(-p --prompt)'{-p,--prompt}'[Prompt text (non-interactive mode)]:prompt:'
    '(-r --resume)'{-r,--resume}'[Resume a previous session]:session:'
    '(-s --sandbox)'{-s,--sandbox}'[Run in sandboxed environment]'
    '--approval-mode[Approval mode]:mode:(default auto_edit yolo plan)'
    '(-y --yolo)'{-y,--yolo}'[Auto-accept all actions (YOLO mode)]'
    '--include-directories[Additional workspace directories]:dirs:'
    '--policy[Additional policy files]:files:'
    '(-v --version)'{-v,--version}'[Show version]'
  )

  _arguments -s -S \
    '1: :->cmd_or_prompt' \
    '*: :->args' && return 0

  case "$state" in
    cmd_or_prompt)
      _describe 'command' commands
      _arguments -s -S $options
      ;;
    args)
      _arguments -s -S $options
      ;;
  esac
}
compdef _gemini gemini

# ---------------------------------------------------------------------------
# codex (OpenAI)
# ---------------------------------------------------------------------------
_codex() {
  local -a commands=(
    'exec:Run non-interactively without human input'
    'resume:Continue an interactive session'
    'fork:Fork a previous session into a new thread'
    'mcp:Manage MCP servers (list, add, remove)'
    'mcp-server:Run Codex as an MCP server over stdio'
    'cloud:Submit and manage Codex Cloud tasks'
    'apply:Apply diff from cloud task to local repo'
    'login:Authenticate via OAuth or API key'
    'logout:Remove stored credentials'
    'features:List, enable, or disable feature flags'
    'completion:Generate shell completion scripts'
    'sandbox:Run commands under sandbox policy'
  )

  local -a options=(
    '(-a --ask-for-approval)'{-a,--ask-for-approval}'[Approval mode]:mode:(untrusted on-request never)'
    '(-C --cd)'{-C,--cd}'[Working directory]:dir:_files -/'
    '(-c --config)'{-c,--config}'[Override config value]:key=value:'
    '--full-auto[On-request approvals + workspace-write sandbox]'
    '(-h --help)'{-h,--help}'[Show help]'
    '(-i --image)'{-i,--image}'[Attach image files]:images:_files'
    '(-m --model)'{-m,--model}'[Override model]:model:'
    '--no-alt-screen[Disable alternate screen for TUI]'
    '--oss[Use local open source provider (Ollama)]'
    '(-p --profile)'{-p,--profile}'[Load config profile]:profile:'
    '(-s --sandbox)'{-s,--sandbox}'[Sandbox policy]:policy:(read-only workspace-write danger-full-access)'
    '--search[Enable live web search]'
    '(-v --version)'{-v,--version}'[Show version]'
    '--dangerously-bypass-approvals-and-sandbox[Run without approvals or sandboxing]'
    '--full-auto[Low-friction sandboxed automatic execution]'
    '--add-dir[Grant additional directory write access]:dir:_files -/'
  )

  _arguments -s -S \
    '1: :->cmd_or_prompt' \
    '*: :->args' && return 0

  case "$state" in
    cmd_or_prompt)
      _describe 'command' commands
      _arguments -s -S $options
      ;;
    args)
      _arguments -s -S $options
      ;;
  esac
}
compdef _codex codex

# ---------------------------------------------------------------------------
# pi (coding agent)
# ---------------------------------------------------------------------------
_pi() {
  local -a commands=(
    'install:Install a package (npm, git, or URL)'
    'remove:Remove an installed package'
    'list:List installed packages'
    'update:Update non-pinned packages'
  )

  local -a options=(
    '--api-key[API key override]:key:'
    '--append-system-prompt[Append to system prompt]:text:'
    '(-c --continue)'{-c,--continue}'[Continue most recent session]'
    '(-e --extension)'{-e,--extension}'[Load extension]:source:_files'
    '--export[Export session to HTML]:file:_files'
    '(-h --help)'{-h,--help}'[Show help]'
    '--list-models[List available models]::search:'
    '(-m --model)'{-m,--model}'[Model to use]:model:'
    '--models[Comma-separated model patterns for cycling]:patterns:'
    '--mode[Output mode]:mode:(json rpc)'
    '--no-extensions[Disable extension discovery]'
    '--no-session[Ephemeral mode]'
    '--no-skills[Disable skill discovery]'
    '--no-tools[Disable all built-in tools]'
    '--offline[Disable network operations]'
    '(-p --print)'{-p,--print}'[Print mode (non-interactive)]'
    '--prompt-template[Load prompt template]:path:_files'
    '--provider[Select provider]:provider:(anthropic openai google)'
    '(-r --resume)'{-r,--resume}'[Browse and select past sessions]'
    '--session[Use specific session file]:path:_files'
    '--session-dir[Custom session storage]:dir:_files -/'
    '--skill[Load skill]:path:_files'
    '--system-prompt[Replace system prompt]:text:'
    '--theme[Load theme]:path:_files'
    '--thinking[Reasoning level]:level:(off minimal low medium high xhigh)'
    '--tools[Enable specific tools]:tools:'
    '--verbose[Verbose startup]'
    '(-v --version)'{-v,--version}'[Show version]'
  )

  _arguments -s -S \
    '1: :->cmd_or_prompt' \
    '*: :->args' && return 0

  case "$state" in
    cmd_or_prompt)
      _describe 'command' commands
      _arguments -s -S $options
      ;;
    args)
      _arguments -s -S $options
      ;;
  esac
}
compdef _pi pi

# ---------------------------------------------------------------------------
# kiro-cli (AWS/Kiro)
# ---------------------------------------------------------------------------
_kiro_cli() {
  local -a commands=(
    'chat:Start or resume a conversation'
    'agent:Manage custom agents (list, create, edit, validate)'
    'translate:Convert natural language to shell commands'
    'mcp:Manage MCP servers'
    'login:Authenticate with Kiro'
    'logout:Remove stored credentials'
    'doctor:Diagnose configuration issues'
    'settings:Configure CLI preferences'
  )

  local -a options=(
    '--agent[Use specific agent configuration]:agent:'
    '(-h --help)'{-h,--help}'[Show help]'
    '--help-all[Print help for all subcommands]'
    '(-v --verbose)'{-v,--verbose}'[Increase logging verbosity]'
    '(-V --version)'{-V,--version}'[Show version]'
  )

  local -a chat_options=(
    '--no-interactive[Print first response to stdout without interactive mode]'
    '(-r --resume)'{-r,--resume}'[Restore previous conversation]'
    '--resume-picker[Interactive session selection]'
    '--list-sessions[List saved sessions]'
    '--delete-session[Remove session by ID]:id:'
    '--trust-all-tools[Enable all tools without confirmation]'
    '--trust-tools[Allow specific tools]:tools:'
    '--wrap[Line wrapping]:mode:(always never auto)'
    '--agent[Use specific agent]:agent:'
  )

  local curcontext="$curcontext" state line
  _arguments -C \
    '1:command:->cmd' \
    '*::arg:->rest' && return 0

  case "$state" in
    cmd)
      _describe 'command' commands
      _arguments -s -S $options
      ;;
    rest)
      case "${line[1]}" in
        chat) _arguments -s -S $chat_options $options '::input:' ;;
        agent) _arguments '1:subcommand:(list create edit validate set-default)' '*::arg:' ;;
        *) _arguments -s -S $options ;;
      esac
      ;;
  esac
}
compdef _kiro_cli kiro-cli

# ---------------------------------------------------------------------------
# opencode (uses built-in yargs completions)
# ---------------------------------------------------------------------------
_opencode_yargs_completions() {
  local reply
  local si=$IFS
  IFS=$'\n' reply=($(COMP_CWORD="$((CURRENT-1))" COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" opencode --get-yargs-completions "${words[@]}"))
  IFS=$si
  if [[ ${#reply} -gt 0 ]]; then
    _describe 'values' reply
  else
    _default
  fi
}
compdef _opencode_yargs_completions opencode

# ---------------------------------------------------------------------------
# difft (difftastic)
# ---------------------------------------------------------------------------
_difft() {
  _arguments -s -S \
    '--context[Lines of context]:lines:' \
    '--width[Max display width]:columns:' \
    '--tab-width[Spaces per tab]:spaces:' \
    '--display[Display mode]:mode:(side-by-side-show-both side-by-side inline)' \
    '--color[When to use color]:when:(always never auto)' \
    '--background[Background color assumption]:bg:(dark light)' \
    '--syntax-highlight[Enable syntax highlighting]:toggle:(on off)' \
    '--exit-code[Set exit code based on diff result]' \
    '--strip-cr[Strip carriage returns]:toggle:(on off)' \
    '--check-only[Report if files differ without showing diff]' \
    '--ignore-comments[Ignore comments when diffing]' \
    '--skip-unchanged[Skip files with no changes]' \
    '--override[Override language for files matching glob]:glob\:name:' \
    '--override-binary[Treat files matching glob as binary]:glob:' \
    '--list-languages[List supported languages]' \
    '--byte-limit[Max bytes to diff per file]:limit:' \
    '--graph-limit[Max graph nodes]:limit:' \
    '--parse-error-limit[Max parse errors]:limit:' \
    '--sort-paths[Sort files by path]' \
    '--dump-syntax[Dump parsed syntax tree]:path:_files' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-v --version)'{-v,--version}'[Show version]' \
    '*:file:_files'
}
compdef _difft difft

# ---------------------------------------------------------------------------
# duf
# ---------------------------------------------------------------------------
_duf() {
  _arguments -s -S \
    '-all[Include pseudo, duplicate, inaccessible file systems]' \
    '-hide[Hide specific devices]:devices:(local network fuse special loops binds)' \
    '-hide-fs[Hide specific filesystems]:filesystems:' \
    '-hide-mp[Hide specific mount points]:mountpoints:' \
    '-inodes[List inode information instead of block usage]' \
    '-json[Output all devices in JSON format]' \
    '-only[Show only specific devices]:devices:(local network fuse special loops binds)' \
    '-only-fs[Only specific filesystems]:filesystems:' \
    '-only-mp[Only specific mount points]:mountpoints:' \
    '-output[Output fields]:fields:' \
    '-sort[Sort output]:field:(mountpoint size used avail usage inodes inodes_used inodes_avail inodes_usage type filesystem)' \
    '-style[Output style]:style:(unicode ascii)' \
    '-theme[Color theme]:theme:(dark light ansi)' \
    '-version[Display version]' \
    '-warnings[Output all warnings to STDERR]' \
    '-width[Max output width]:width:'
}
compdef _duf duf

# ---------------------------------------------------------------------------
# grpcurl
# ---------------------------------------------------------------------------
_grpcurl() {
  _arguments -s -S \
    '-H[Add request header]:header:' \
    '-allow-unknown-fields[Allow unknown fields in JSON input]' \
    '-authority[Value of :authority pseudo-header]:authority:' \
    '-cacert[CA certificate file]:file:_files' \
    '-cert[Client certificate file]:file:_files' \
    '-connect-timeout[Connection timeout in seconds]:seconds:' \
    '-d[Data for request body]:data:' \
    '-emit-defaults[Emit default values in JSON output]' \
    '-expand-headers[Expand environment variables in headers]' \
    '-format[Input format]:format:(json text)' \
    '-format-error[Format error output as JSON]' \
    '-help[Show help]' \
    '-import-path[Proto import path]:path:_files -/' \
    '-insecure[Skip server certificate verification]' \
    '-keepalive-time[Keepalive interval in seconds]:seconds:' \
    '-key[Client private key file]:file:_files' \
    '-max-msg-sz[Maximum message size in bytes]:bytes:' \
    '-max-time[Maximum time for operation]:seconds:' \
    '-msg-template[Print message template]' \
    '-plaintext[Use plain-text HTTP/2]' \
    '-proto[Proto source file]:file:_files' \
    '-protoset[Protoset file]:file:_files' \
    '-reflect-header[Reflection request header]:header:' \
    '-rpc-header[RPC request header]:header:' \
    '-servername[Override server name for TLS]:name:' \
    '-v[Enable verbose output]' \
    '-vv[Enable very verbose output]' \
    '*:address:'
}
compdef _grpcurl grpcurl

# ---------------------------------------------------------------------------
# sshuttle
# ---------------------------------------------------------------------------
_sshuttle() {
  _arguments -s -S \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-l --listen)'{-l,--listen}'[Listen on address and port]:[ip\:]port:' \
    '(-H --auto-hosts)'{-H,--auto-hosts}'[Continuously scan for remote hostnames]' \
    '(-N --auto-nets)'{-N,--auto-nets}'[Automatically determine subnets to route]' \
    '--dns[Capture local DNS requests and forward]' \
    '--ns-hosts[DNS servers to capture]:ip:' \
    '--to-ns[DNS server to forward to]:ip\:port:' \
    '--method[Forwarding method]:type:(auto nft nat tproxy pf ipfw)' \
    '--python[Path to remote python]:path:_files' \
    '(-r --remote)'{-r,--remote}'[SSH hostname of remote server]:user@host:' \
    '(-x --exclude)'{-x,--exclude}'[Exclude subnet]:ip/mask:' \
    '(-X --exclude-from)'{-X,--exclude-from}'[Exclude subnets from file]:file:_files' \
    '(-v --verbose)'{-v,--verbose}'[Increase verbosity]' \
    '(-V --version)'{-V,--version}'[Show version]' \
    '(-e --ssh-cmd)'{-e,--ssh-cmd}'[SSH command to use]:cmd:' \
    '--seed-hosts[Hostnames for initial scan]:hosts:' \
    '--no-latency-control[Sacrifice latency for bandwidth]' \
    '--disable-ipv6[Disable IPv6 support]' \
    '(-D --daemon)'{-D,--daemon}'[Run as daemon]' \
    '(-s --subnets)'{-s,--subnets}'[File with subnets]:file:_files' \
    '--pidfile[PID file path]:file:_files' \
    '--user[Apply rules to this user]:user:_users' \
    '*:subnets:'
}
compdef _sshuttle sshuttle

# ---------------------------------------------------------------------------
# tre (tre-command)
# ---------------------------------------------------------------------------
_tre() {
  _arguments -s -S \
    '(-a --all)'{-a,--all}'[Include hidden files and directories]' \
    '(-c --color)'{-c,--color}'[When to color output]:when:(automatic always never)' \
    '(-d --directories)'{-d,--directories}'[Only list directories]' \
    '(-e --editor)'{-e,--editor}'[Create aliases for results]::command:' \
    '(-E --exclude)'{-E,--exclude}'[Exclude paths matching pattern]:pattern:' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-j --json)'{-j,--json}'[Output JSON]' \
    '(-l --limit)'{-l,--limit}'[Limit depth]:depth:' \
    '(-p --portable)'{-p,--portable}'[Generate portable paths for aliases]' \
    '(-s --simple)'{-s,--simple}'[Use normal print despite gitignore]' \
    '(-V --version)'{-V,--version}'[Show version]' \
    '*:path:_files -/'
}
compdef _tre tre

# ---------------------------------------------------------------------------
# yamllint
# ---------------------------------------------------------------------------
_yamllint() {
  _arguments -s -S \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-c --config-file)'{-c,--config-file}'[Path to configuration file]:file:_files' \
    '(-d --config-data)'{-d,--config-data}'[Custom configuration as YAML]:data:' \
    '--list-files[List files to lint and exit]' \
    '(-f --format)'{-f,--format}'[Output format]:format:(parsable standard colored github auto)' \
    '(-s --strict)'{-s,--strict}'[Return non-zero on warnings too]' \
    '--no-warnings[Output only errors]' \
    '(-v --version)'{-v,--version}'[Show version]' \
    '*:file:_files'
}
compdef _yamllint yamllint

# ---------------------------------------------------------------------------
# virtualenv
# ---------------------------------------------------------------------------
_virtualenv() {
  _arguments -s -S \
    '--version[Display version]' \
    '--with-traceback[Show stacktrace on failure]' \
    '(-v --verbose)'{-v,--verbose}'[Increase verbosity]' \
    '(-q --quiet)'{-q,--quiet}'[Decrease verbosity]' \
    '--read-only-app-data[Use app data in read-only mode]' \
    '--app-data[App data folder path]:path:_files -/' \
    '--reset-app-data[Start with empty app data]' \
    '--upgrade-embed-wheels[Update embedded wheels]' \
    '--discovery[Interpreter discovery method]:method:(builtin)' \
    '(-p --python)'{-p,--python}'[Python interpreter]:interpreter:' \
    '--try-first-with[Try these interpreters first]:interpreter:' \
    '--creator[Environment creator]:creator:(builtin cpython3-mac-brew venv)' \
    '--seeder[Seed package method]:seeder:(app-data pip)' \
    '--no-seed[Do not install seed packages]' \
    '--activators[Activators to generate]:list:' \
    '--clear[Remove destination before creating]' \
    '--no-vcs-ignore[Skip VCS ignore directive]' \
    '--system-site-packages[Access system site-packages]' \
    '--symlinks[Use symlinks instead of copies]' \
    '--no-download[Disable downloading latest packages]' \
    '--download[Enable downloading latest packages]' \
    '--extra-search-dir[Extra wheel search directory]:dir:_files -/' \
    '--pip[Pip version to install]:version:' \
    '--setuptools[Setuptools version to install]:version:' \
    '--no-pip[Do not install pip]' \
    '--no-setuptools[Do not install setuptools]' \
    '--no-periodic-update[Disable periodic wheel updates]' \
    '--symlink-app-data[Symlink packages from app-data]' \
    '--prompt[Alternative prompt prefix]:prompt:' \
    '(-h --help)'{-h,--help}'[Show help]' \
    '1:destination:_files -/'
}
compdef _virtualenv virtualenv

# ---------------------------------------------------------------------------
# meldr (multi-repo workspace manager)
# ---------------------------------------------------------------------------
_meldr() {
  local -a commands=(
    'init:Initialize workspace in current directory'
    'create:One-shot init + add packages + create worktree'
    'package:Manage packages (add, remove, list)'
    'pkg:Manage packages (add, remove, list)'
    'worktree:Manage worktrees (add, remove, list)'
    'wt:Manage worktrees (add, remove, list)'
    'status:Show workspace dashboard'
    'st:Show workspace dashboard'
    'sync:Sync worktree with upstream'
    'exec:Run command in all packages'
    'config:Manage configuration (set, get, list)'
  )

  local -a global_options=(
    '--no-agent[Skip launching AI agents in tmux panes]'
    '--no-tabs[Skip tmux window/pane creation]'
    '--verbose[Verbose output]'
    '--quiet[Suppress non-error output]'
    '(-h --help)'{-h,--help}'[Show help]'
    '(-V --version)'{-V,--version}'[Show version]'
  )

  local -a create_options=(
    '(-r --repo)'{-r,--repo}'[Repository URL to add]:url:'
    '(-b --branch)'{-b,--branch}'[Branch to create worktree on]:branch:'
    '(-a --agent)'{-a,--agent}'[AI agent to use]:agent:(claude cursor gemini codex opencode pi kiro none)'
  )

  local -a sync_options=(
    '--merge[Use merge instead of rebase]'
    '--strategy[Merge strategy]:strategy:(theirs ours manual)'
  )

  local -a wt_commands=(
    'add:Create worktrees for all packages on a branch'
    'remove:Remove worktrees'
    'list:List active worktrees'
  )

  local -a pkg_commands=(
    'add:Clone and register repositories'
    'remove:Remove packages from workspace'
    'list:List registered packages'
  )

  local -a config_commands=(
    'set:Set configuration value'
    'get:Get configuration value'
    'list:Show effective configuration'
  )

  local curcontext="$curcontext" state line
  _arguments -C \
    $global_options \
    '1:command:->cmd' \
    '*::arg:->rest' && return 0

  case "$state" in
    cmd)
      _describe 'command' commands
      ;;
    rest)
      case "${line[1]}" in
        create)
          _arguments -s -S $global_options $create_options '1:name:'
          ;;
        worktree|wt)
          _arguments -C '1:subcommand:->wt_cmd' '*::arg:->wt_rest' && return 0
          case "$state" in
            wt_cmd) _describe 'subcommand' wt_commands ;;
            wt_rest)
              case "${line[1]}" in
                add) _arguments $global_options '1:branch:' ;;
                remove) _arguments '--force[Force removal even if dirty]' '1:branch:' ;;
                *) ;;
              esac
              ;;
          esac
          ;;
        package|pkg)
          _arguments -C '1:subcommand:->pkg_cmd' '*::arg:->pkg_rest' && return 0
          case "$state" in
            pkg_cmd) _describe 'subcommand' pkg_commands ;;
            pkg_rest) ;;
          esac
          ;;
        config)
          _arguments -C '1:subcommand:->cfg_cmd' '*::arg:->cfg_rest' && return 0
          case "$state" in
            cfg_cmd) _describe 'subcommand' config_commands ;;
            cfg_rest)
              case "${line[1]}" in
                set) _arguments '1:key:(agent mode sync_method sync_strategy)' '2:value:' ;;
                get) _arguments '1:key:(agent mode sync_method sync_strategy)' ;;
                *) ;;
              esac
              ;;
          esac
          ;;
        sync)
          _arguments -s -S $global_options $sync_options '::branch:'
          ;;
        exec)
          _arguments '*:command:'
          ;;
        status|st)
          _arguments $global_options
          ;;
        *)
          _arguments $global_options
          ;;
      esac
      ;;
  esac
}
compdef _meldr meldr
