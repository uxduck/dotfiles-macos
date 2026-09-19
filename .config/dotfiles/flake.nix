{
  description = "Ben Butterworth's nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    # https://github.com/nix-community/home-manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nix-darwin module for configuring the determinate-nixd daemon (installed separately by the Determinate Nix installer)
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";

  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      determinate,
      home-manager,
    }:
    let
      username =
        let
          u = builtins.getEnv "NIX_DARWIN_USER";
        in
        if u == "" then
          throw "NIX_DARWIN_USER environment variable must be set (e.g., NIX_DARWIN_USER=\"$(whoami)\")"
        else
          u;
      hostname =
        let
          h = builtins.getEnv "NIX_DARWIN_HOST";
        in
        if h == "" then
          throw "NIX_DARWIN_HOST environment variable must be set (e.g., NIX_DARWIN_HOST=\"$(scutil --get LocalHostName)\")"
        else
          h;
      config =
        { pkgs, ... }:
        {
          # To disable nix-darwin management of nix, which determinate systems does instead
          nix.enable = false;

          users.users.${username}.home = "/Users/${username}";

          nix.extraOptions = ''
            extra-platforms = x86_64-darwin aarch64-darwin
          '';

          # List packages installed in system profile. To search by name, run:
          # $ nix-env -qaP | grep wget
          # nixpkgs are almost always out of date with brew.
          # I don't like using Nix packages for auto updating apps because they will just add a duplicate app into /applications.
          environment.systemPackages = with pkgs; [
            ripgrep
            delta
            # Editors & Shell
            tmux
            vim
            neovim
            nixfmt-rfc-style
            # For Flutter, Android and iOS
            # too out of date
            # bundler
            # read permissions failing when trying to `bundle install`
            # ruby
            # System/Mac Utilities
            darwin.trash
            gnupg
            # bartender
            # mas  # disabled — MASError 5 on nix
            tree
            wget
            htop
            uv
            git-extras
            k9s
            cmake
            fzf
            nmap
            lazygit
            # https://github.com/restic/restic
            restic
            # formatting code
            dprint
            # The tailscale package doesn't include the mac menu bar, so we use the cask instead
            # tailscale
          ];

          # Add Podman to PATH (installed by Podman Desktop)
          environment.systemPath = [ "/opt/podman/bin" ];

          # Tailscale is installed via Homebrew cask (see line 263) for the menu bar app
          # services.tailscale.enable = true;

          # Bring Tailscale up at boot, unattended. The macOS app only connects
          # once a GUI session exists and duckd is headless, so nothing started
          # the tunnel after a reboot until someone logged in.
          #
          # A LaunchAgent can't do this: launchd only scans ~/Library/LaunchAgents
          # for GUI sessions, so it never loads for an SSH-only login. A daemon
          # does run - FileVault holds userspace until the volume unlocks, but
          # system daemons start immediately after (verified 2026-09-19).
          #
          # Calling the CLI also demand-starts the network extension, which took
          # ~80s to answer on a cold boot. Doing it here absorbs that wait rather
          # than hanging the first interactive 'tailscale status'.
          #
          # Bare 'up' is deliberate: it resumes the prefs already on disk, while
          # passing ANY flag makes it demand every non-default pref on the command
          # line. It's idempotent, so KeepAlive retries until it exits 0, then stops.
          # Absolute path because tailscale comes from the cask, not nixpkgs.
          launchd.daemons.tailscale-up.serviceConfig = {
            ProgramArguments = [
              "/usr/local/bin/tailscale"
              "up"
            ];
            RunAtLoad = true;
            KeepAlive.SuccessfulExit = false;
            ThrottleInterval = 30;
            StandardOutPath = "/var/log/tailscale-up.log";
            StandardErrorPath = "/var/log/tailscale-up.log";
          };

          # Necessary for using flakes on this system.
          nix.settings.experimental-features = "nix-command flakes";

          # Enable alternative shell support in nix-darwin.
          # programs.fish.enable = true;

          # Set Git commit hash for darwin-version.
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility, please read the changelog before changing.
          # $ darwin-rebuild changelog
          system.stateVersion = 6;

          # The platform the configuration will be used on.
          nixpkgs.hostPlatform = "aarch64-darwin";

          # Allow unfree packages
          nixpkgs.config.allowUnfree = true;

          # Sudo touch id
          security.pam.services.sudo_local.touchIdAuth = true;

          # Enable GPG agent
          programs.gnupg.agent = {
            enable = true;
            enableSSHSupport = false;
          };

          system.primaryUser = username;
          # More in https://github.com/nix-darwin/nix-darwin/tree/master/modules/system/defaults
          system.defaults = {
            # Setting Dock to auto-hide and removing the auto-hiding delay
            dock.autohide = true;
            dock.autohide-delay = 0.0;
            dock.autohide-time-modifier = 0.0;
            # Setting the icon size of Dock items in pixels (large)
            dock.tilesize = 90;
            # Speeding up Mission Control animations and grouping windows by application
            dock.expose-animation-duration = 0.1;
            dock.expose-group-apps = true;
            # Grey out apps that have been hidden (Command + H)
            dock.showhidden = true;
            dock.mru-spaces = false;
            dock.orientation = "left";
            dock.show-recents = false;
            finder.AppleShowAllExtensions = true;
            finder.FXPreferredViewStyle = "clmv";
            finder.AppleShowAllFiles = true;
            loginwindow.LoginwindowText = "If found, please email plantbased@duck.com or 074821 48484 (UK). International: +44 7482 148484 or +447927067521";
            screencapture.location = "~/Desktop";

            # Expanding the save and print panels by default
            NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
            NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
            NSGlobalDomain.PMPrintingExpandedStateForPrint = true;
            NSGlobalDomain.PMPrintingExpandedStateForPrint2 = true;
            # Show path bar in the bottom of Finder windows"
            finder.ShowPathbar = true;
            # Disabling the warning when changing a file extension
            finder.FXEnableExtensionChangeWarning = false;

            # Disable smart quotes and smart dashes as they are annoying when typing code
            NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
            NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
            # Enable function keys to work as standard function keys by default
            NSGlobalDomain."com.apple.keyboard.fnState" = true;
            # Disable Gatekeeper. You'll be able to install any app you want from here on, not just Mac App Store apps
            LaunchServices.LSQuarantine = false;

            # Saving to disk (not to iCloud) by default
            NSGlobalDomain.NSDocumentSaveNewDocumentsToCloud = false;
            # Enabling full keyboard access for all controls (e.g. enable Tab in modal dialogs)
            NSGlobalDomain.AppleKeyboardUIMode = 3;

            # Setting mouse speed to a reasonable number
            ".GlobalPreferences"."com.apple.mouse.scaling" = 3.0;
            # Showing icons for hard drives, servers, and removable media on the desktop
            finder.ShowExternalHardDrivesOnDesktop = true;
          };

          system.activationScripts.postActivation.text = ''
            # Exit immediately if any command errors (e), error if variables undefined (u), error on pipeline error (-o pipefail). Why? See https://gist.github.com/mohanpedala/1e2ff5661761d3abd0385e8223e16425

            set -euo pipefail
            # Install Rosetta 2 if not already installed (Apple Silicon only)
            if [[ "$(uname -m)" == "arm64" ]] && ! /usr/bin/pgrep oahd >/dev/null 2>&1; then
              echo "Installing Rosetta 2..."
              /usr/sbin/softwareupdate --install-rosetta --agree-to-license
            fi

            # Set Activity Monitor update period to 1 second
            defaults write com.apple.ActivityMonitor "UpdatePeriod" -int "1"
            # Automatically quit printer app once the print jobs complete
            defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true
            # Check for software updates daily, not just once per week
            defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1
            # Avoiding the creation of .DS_Store files on network volumes
            defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
            # Setting trackpad speed to a reasonable number
            defaults write -g com.apple.trackpad.scaling 3
            # NSGlobalDomain.NSQuitAlwaysKeepsWindows = true; (TODO: open a PR on https://github.com/ben-xD/nix-darwin - true is already the default though)
            defaults write NSGlobalDomain NSQuitAlwaysKeepsWindows -bool true
            # Preventing Time Machine from prompting to use new hard drives as backup volume (TODO: Open a PR for this)
            defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

            #"Enabling snap-to-grid for icons on the desktop and in other icon views"
            /usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" /Users/${username}/Library/Preferences/com.apple.finder.plist
            /usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" /Users/${username}/Library/Preferences/com.apple.finder.plist
            /usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" /Users/${username}/Library/Preferences/com.apple.finder.plist

            # Disable gatekeeper, allowing app from anywhere to run
            # sudo spctl --master-disable

            killall Finder || true
          '';

          # Reminder about brew: although it's convenient, brew has been painful when needing to specify a specific version of a package. This is important when using brew to install dependencies of C/C++ projects. I'll still use it for general purpose tools and apps, but not build dependencies.
          homebrew = {
            # Temporarily disabled: `brew bundle` fails with "unknown or
            # unsupported macOS version: :dunno" on macOS 26 (Tahoe) until the
            # installed Homebrew adds support. Re-enable after `brew update`.
            enable = false;
            # Keep Homebrew itself mutable. nix-darwin only writes a Brewfile and
            # runs brew bundle, which avoids nix-homebrew's read-only Ruby bundle.
            taps = [];

            brews = [
              # also need to run `brew services start ollama`, to actually run the API which the CLI connects to
              "ollama"
              "fastlane"
              "git-filter-repo"
              "f3"
              "fastfetch"
              "iproute2mac"
              "ffmpeg"
              "gh"
              "gmp"
              "meson"
              # for podman
              "docker-credential-helper"
              "mkcert"
              "imagemagick"
              "pinentry-mac"
              "pam-reattach"
              "sccache"
              "scrcpy"
              "cloc"
            ];

            # Add desktop applications here!
            # Need a custom cask? see https://github.com/Homebrew/homebrew-cask/blob/c1bc489c27f061871660c902c89a250a621fb7aa/Casks/e/eagle.rb
            casks = [
              # Terminal & Dev Tools
              "iterm2"
              "alfred"
              "tailscale-app"
              "notunes"
              "surfshark"
              "trailer"
              "alt-tab"
              "customshortcuts"
              # the nix package errors when it is not located in /Applications
              "android-studio"
              "itsycal"
              "pdf-expert"
              "db-browser-for-sqlite"
              "dbeaver-community"
              "postico"
              "mitmproxy"
              "fork"
              "jordanbaird-ice@beta"
              # network
              "wireshark-app"
              # Doesn't allow you to make below/separate from the menubar
              # "hiddenbar"
              # Crashes on macos 26 tahoe
              # "bartender"
              "calibre"
              # Productivity
              # "cleanshot"
              "meetingbar"
              # "typora" # SHA-256 mismatch on download
              "figma"
              "ogdesign-eagle"
              "logi-options+"
              "keyclu"
              # Browsers
              # Communication
              "signal"
              # Utilities
              "vlc"
              "yubico-authenticator"
              "keepassxc"
              # Quick Look Plugins
              "qlmarkdown"
              "qlstephen"
              # Browsers
              "microsoft-edge"
              "brave-browser"
              "google-chrome"
              "firefox"
              # Productivity
              "obsidian"
              "chatgpt"
              "claude"
              # Dev Tools
              "visual-studio-code"
              # Not always needed
              # obs-studio
              # net-news-wire
              # zotero
              # qbittorrent
              # blender
              "monitorcontrol"
              "betterdisplay"
              "rectangle"
            ];
            # Install Mac App Store apps. To get more ids, see https://github.com/mas-cli/mas?tab=readme-ov-file#-app-ids
            # masApps disabled — MASError 5 on nix
            masApps = {
              # "Xcode" = 497799835;
              # "Windows app" = 1295203466;  # MASError 5 on nix
              # "Amphetamine" = 937984704;  # MASError 5 on nix
              # "Colorslurp" = 1287239339;  # MASError 5 on nix
              # "Snippose" = 1140313689;
              # "TestFlight" = 899247664;
              # "Bitwarden" = 1352778147;
            };
          };
        };

      homeManagerConfig = {
        home-manager.extraSpecialArgs = {
          inherit username;
        };
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.users.${username} = import ./home.nix;

        # Optionally, use home-manager.extraSpecialArgs to pass
        # arguments to home.nix
      };
      resetDockIconsApp = import ./reset-dock-icons-app.nix { inherit nixpkgs; };
      setupApp = import ./setup-app.nix { inherit nixpkgs username; };
    in
    {
      # Build darwin flake using:
      # $ NIX_DARWIN_HOST="$(scutil --get LocalHostName)" NIX_DARWIN_USER="$(whoami)" sudo darwin-rebuild switch --flake ~/.config/dotfiles --impure
      darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
        modules = [
          config
          determinate.darwinModules.default
          {
            determinateNix = {
              enable = true;
              determinateNixd.garbageCollector.strategy = "disabled";
            };
          }
          home-manager.darwinModules.home-manager
          homeManagerConfig
        ];
      };

      apps.x86_64-darwin.reset-dock-icons = {
        type = "app";
        program = resetDockIconsApp "x86_64-darwin";
      };
      apps.aarch64-darwin.reset-dock-icons = {
        type = "app";
        program = resetDockIconsApp "aarch64-darwin";
      };
      apps.x86_64-darwin.setup = {
        type = "app";
        program = setupApp "x86_64-darwin";
      };
      apps.aarch64-darwin.setup = {
        type = "app";
        program = setupApp "aarch64-darwin";
      };
    };
}
