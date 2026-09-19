{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  pnpmHome = "$HOME/.pnpm";
in
{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  home.username = username;

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Enable direnv for automatic environment loading
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Zsh configuration with Oh My Zsh
  programs.zsh = {
    enable = true;
    sessionVariables = {
      HOMEBREW_NO_ANALYTICS = "1";
      EDITOR = "nvim";
      VISUAL = "$EDITOR";
      BUN_INSTALL = "$HOME/.bun";
      # Not using Bitwarden SSH agent anymore because I don't want to login to Bitwarden so frequently
      # https://bitwarden.com/help/ssh-agent
      # Confirm the file is available. Either in
      # - $HOME/.bitwarden-ssh-agent.sock (official dmg installer)
      # - $HOME/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
      # SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock";
      # Prefer the normal Apple Silicon Homebrew over any stale /usr/local shim from /etc/paths.
      # ADB for android studio old emulator API level 21
      # We add The pnpm home directory to the PATH so that `pnpm install -g $package` doesn't error
      # Orca bundles its CLI in the desktop app.
      PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:$BUN_INSTALL/bin:$HOME/repos/flutter/bin:$HOME/Library/Android/sdk/platform-tools:/Library/Frameworks/GStreamer.framework/Versions/Current/bin:${pnpmHome}:$HOME/.opencode/bin:$HOME/.vite-plus/bin:/Applications/Orca.app/Contents/Resources/bin:$PATH";
      GOOGLE_JAVA_FORMAT_PATH = "/opt/google-java-format-1.13.0-all-deps.jar";
      # We set the PNPM_HOME to ensure pnpm can install global packages
      PNPM_HOME = pnpmHome;
      # Prevent Homebrew's git from traversing into the read-only Nix store
      GIT_CEILING_DIRECTORIES = "/nix";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
      theme = "";
    };

    # Additional zsh configuration
    shellAliases = {
      ll = "ls -la";
      la = "ls -la";
      l = "ls -l";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    # Custom zsh options
    history = {
      size = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
    };

    # Enable syntax highlighting and auto-suggestions
    autosuggestion.enable = true;
    enableCompletion = true;
    initContent = ''
      # This file is managed by Home Manager. Do not edit directly.
      # To make changes, edit ~/.config/dotfiles/home.nix

      # Auto-launch tmux over SSH (attach to existing "ssh" session or create one)
      if [[ -n "$SSH_CONNECTION" && -z "$TMUX" && -z "$VSCODE_INJECTION" && -t 0 && -t 1 ]]; then
        tmux new-session -A -s ssh
      fi

      # Auto-launch tmux in VSCode terminal with the current directory
      if [[ "$TERM_PROGRAM" == "vscode" && -z "$TMUX" ]]; then
        tmux new-session -A -s "vscode-''${PWD##*/}" -c "$PWD"
      fi

      # umask 077: removes group/other permissions (666-077=600 for files, 777-077=700 for dirs)
      # (Debian 13 defaults to 002, macOS to 022 - both allow group/other read access)
      umask 077

      # Secrets / private tokens (values stored in macOS Keychain, never on disk)
      # FORGEJO_TOKEN: auth for the tlduck Forgejo npm registry (referenced as ''${FORGEJO_TOKEN} in .npmrc).
      # Stored with: security add-generic-password -s forgejo-token -a "$USER" -w "<token>"
      # TODO: migrate to age + age-plugin-se (Secure Enclave, Touch ID on decrypt).
      export FORGEJO_TOKEN="$(security find-generic-password -s forgejo-token -w 2>/dev/null)"

      # Git
      alias lg="lazygit"

      # dotfiles
      alias cf='/usr/bin/git --git-dir=$HOME/.cfg --work-tree=$HOME'
      # lazygit for dotfiles
      alias cflg="lazygit --git-dir=$HOME/.cfg --work-tree=$HOME"

      setopt completealiases

      # VSCode, to read from terminal. See https://github.com/cline/cline/wiki/Troubleshooting-%E2%80%90-Shell-Integration-Unavailable#still-having-trouble and https://code.visualstudio.com/docs/terminal/shell-integration#_manual-installation
      [[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

      # Help pages (zsh doesn't enable them by default). See https://superuser.com/questions/1563825/is-there-a-zsh-equivalent-to-the-bash-help-builtin
      if [[ "$TERM_PROGRAM" != "vscode" ]]; then
        unalias run-help 2>/dev/null || true
        autoload run-help
        HELPDIR=/usr/share/zsh/"''${ZSH_VERSION}"/help
        alias help=run-help
      fi

      # fnm
      # Disabled for now. I'm using mise instead.
      # To add it back, add `fnm` to `environment.systemPackages`
      # eval "$(fnm env --use-on-cd)"

      # Rust up (manually installed from https://rustup.rs/)
      [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

      # Vite+ (https://vite.plus)
      [[ -f "$HOME/.vite-plus/env" ]] && . "$HOME/.vite-plus/env"

      # Reset terminal mouse tracking after SSH exits (clean or broken connection)
      # Prevents escape sequence spam when remote app (tmux/vim) enabled mouse reporting
      ssh() {
        command ssh "$@"
        printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l'
      }

      # t to attach onto main session
      alias t='tmux attach -t main 2>/dev/null || tmux new -s main'
      tnew() { tmux new -s "w-$(date +%Y%m%d-%H%M%S)"; }
      tproj() {
        local n="''${1:-main}"
        local dir
        dir=$(zoxide query "$n" 2>/dev/null)
        if [[ -n "$dir" ]]; then
          tmux new -A -s "$n" -c "$dir"
        else
          echo "zoxide: no match for '$n', starting session in current directory"
          tmux new -A -s "$n"
        fi
      }

      # optimize: re-encode video(s) into a small, shareable H.265/HEVC file.
      #   <name>.<ext> -> <name>.opt.mp4   (libx265, capped at 720p, aggressive CRF 32)
      # hvc1 tag + yuv420p keep it playable on Apple apps/browsers; faststart for web.
      # Reveals the optimized file(s) in Finder when done.
      optimize() {
        emulate -L zsh
        if (( $# == 0 )); then
          print -u2 "optimize: shrink video(s) to small H.265 for sharing -> <name>.opt.mp4"
          print -u2 "usage: optimize <video> [more videos...]"
          return 2
        fi
        zmodload -F zsh/stat b:zstat 2>/dev/null
        local in out insize outsize
        local -a outs
        local -i rc=0
        for in in "$@"; do
          if [[ ! -f "$in" ]]; then
            print -u2 "optimize: not found: $in"; rc=1; continue
          fi
          if [[ "$in" == *.opt.mp4 ]]; then
            print -u2 "optimize: already optimized, skipping: $in"; rc=1; continue
          fi
          out="''${in:r}.opt.mp4"
          if [[ -e "$out" ]]; then
            print -u2 "optimize: output exists, skipping: $out"; rc=1; continue
          fi
          print -u2 "optimize: $in -> $out"
          if ! ffmpeg -hide_banner -loglevel warning -stats -n -i "$in" \
              -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease:force_divisible_by=2" \
              -c:v libx265 -preset faster -crf 32 -tag:v hvc1 -pix_fmt yuv420p \
              -c:a aac -b:a 96k -ac 2 \
              -movflags +faststart "$out"; then
            print -u2 "optimize: ffmpeg failed for: $in"
            [[ -f "$out" ]] && rm -f "$out"
            rc=1; continue
          fi
          insize=$(zstat +size -- "$in" 2>/dev/null)
          outsize=$(zstat +size -- "$out" 2>/dev/null)
          if [[ -n "$insize" && -n "$outsize" && "$insize" -gt 0 ]]; then
            print -u2 -- "optimize: done $(awk -v i="$insize" -v o="$outsize" 'BEGIN{printf "%.1fMB -> %.1fMB (%d%% of original)", i/1048576, o/1048576, o*100/i}')"
          fi
          outs+=("$out")
        done
        # Reveal the optimized file(s) in Finder.
        if (( ''${#outs} )); then
          open -R "''${outs[@]}" 2>/dev/null
        fi
        return $rc
      }

      # Use nvim instead of vim. Use \vim to use old vim.
      alias v="vim"
      alias vim="nvim"
      alias vi="nvim"

      alias cl="claude"
      alias clrd="claude remote-control --permission-mode bypassPermissions"
      alias co="codex"
      alias oc="opencode"

      # KeePassXC CLI (bundled inside the .app, not on PATH by default)
      alias keepassxc-cli="/Applications/KeePassXC.app/Contents/MacOS/keepassxc-cli"
      alias kp="keepassxc-cli"

      # nix-darwin
      alias nix-rebuild='sudo NIX_DARWIN_HOST="$(scutil --get LocalHostName)" NIX_DARWIN_USER="$(whoami)" darwin-rebuild switch --flake ~/.config/dotfiles --impure && exec zsh'
      alias nix-rollback='sudo nix-env -p /nix/var/nix/profiles/system --rollback && sudo /nix/var/nix/profiles/system/activate && exec zsh'
      alias nix-gc='nix-collect-garbage -d && exec zsh'

      # for fzf
      source <(fzf --zsh)

      # mise
      [[ -x "$HOME/.local/bin/mise" ]] && eval "$("$HOME/.local/bin/mise" activate zsh)"

      # zoxide (smarter cd)
      eval "$(zoxide init zsh)"
    '';

    # Additional plugins that work well with the setup
    plugins = [
      {
        name = "zsh-syntax-highlighting";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-syntax-highlighting";
          rev = "0.7.1";
          sha256 = "03r6hpb5fy4yaakqm3lbf4xcvd408r44jgpv4lnzl9asp4sb9qc0";
        };
      }
    ];
  };

  fonts.fontconfig.enable = true;

  home.activation.setDefaultEditor = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Register VSCode as the handler for text/code UTIs.
    #
    # Two things Launch Services will not let us do:
    #   * public.data (the abstract root data UTI) is rejected outright with
    #     error -50 (paramErr), so only concrete UTIs are listed below.
    #   * LSSetDefaultRoleHandler has to reach lsd in an Aqua (GUI) session.
    #     Activating over SSH with nobody logged in at the console means there
    #     is no such session, so every call fails with -10822
    #     (kLSServerCommunicationErr) and takes the whole rebuild down with it.
    #
    # So: read the current assignments out of the Launch Services preference
    # file (which works headless), only invoke duti for UTIs that actually need
    # changing, and downgrade a failure to a warning.

    _lsHandlerFor() {
      local prefs="$HOME/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"
      [ -r "$prefs" ] || return 0
      /usr/bin/plutil -convert json -o - "$prefs" 2>/dev/null \
        | ${pkgs.jq}/bin/jq -r --arg uti "$1" '
            (.LSHandlers // [])
            | map(select(.LSHandlerContentType == $uti))
            | (first // {})
            | (.LSHandlerRoleAll // .LSHandlerRoleEditor // .LSHandlerRoleViewer // "")
          ' 2>/dev/null || true
    }

    _lsSetHandler() {
      local uti="$1" have
      have="$(_lsHandlerFor "$uti")"
      if [ "''${have,,}" = "com.microsoft.vscode" ]; then
        verboseEcho "Launch Services: $uti already handled by VSCode"
      elif run ${pkgs.duti}/bin/duti -s com.microsoft.VSCode "$uti" all; then
        noteEcho "Launch Services: $uti -> VSCode"
      else
        warnEcho "Launch Services: could not set VSCode as handler for $uti (no GUI session?), skipping"
      fi
    }

    for _uti in \
      public.plain-text \
      public.source-code \
      public.shell-script \
      public.json \
      public.xml \
      public.yaml
    do
      _lsSetHandler "$_uti"
    done
    unset _uti
  '';

  home.packages = with pkgs; [
    duti
    jetbrains-mono
    pnpm
    zoxide
    # Maple Mono (Ligature TTF unhinted)
    maple-mono.truetype
    # Maple Mono NF (Ligature unhinted)
    maple-mono.NF-unhinted
    # Maple Mono NF CN (Ligature unhinted)
    maple-mono.NF-CN-unhinted
  ];
}
