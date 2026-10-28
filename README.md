# T480 dotfiles

This is the current Gentoo T480 configuration: edited dwm and st source, Bash and tmux, fastfetch, btop, X startup, Quickshell, GTK, PCManFM, desktop helpers and the Nerd Font. The config files are copied from the active setup; edit the files here and reinstall after making changes. The small helpers are rebuilt from source.

## Install on a fresh system

On an x86-64 Gentoo installation, install Git, sudo, a compiler and make, and as your normal user run:

```sh
git clone https://github.com/farhanakhtar0x66/t480-dots.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

The script needs Internet access and sudo. It enables the GURU repository if needed, accepts the `~amd64` keyword for Quickshell, installs the required Gentoo packages, builds dwm/st and the desktop helpers, installs the included font, and downloads pinned fzf, zoxide, eza, bat, Bluetui and Wifitui releases after checking their SHA-256 hashes. Existing files replaced by the installer are saved under `~/.local/state/dotfiles/`. The `--skip-system` option skips package installation and is useful only when dependencies are already installed.

Start a **new login shell** and run `startx` after installation. Bash sets `XINITRC` to `~/.config/X11/xinitrc`; tmux reads `~/.config/tmux/tmux.conf`. The installer adjusts btop's stored theme path for the destination home directory, leaving the project copy unchanged.

This setup is made for the ThinkPad T480 and Gentoo/OpenRC. The script does not configure kernel options, a display manager, network/audio/Bluetooth services, user groups, or hardware permissions. Optional applications bound to shortcuts (LibreWolf, ChatGPT and LocalSend) have their own repositories and installation requirements and are not installed by this script. A working Gentoo base, network access and compatible package repository/USE settings are still required; no fresh-machine installation has been tested. Portage may ask for further keyword, license or USE decisions on another system.

Keep a copy of this repository somewhere outside the computer before reinstalling Linux. It does not contain your personal data, shell history, credentials, or application accounts.

## Theme and clipboard

The desktop uses a monochrome black-and-gray palette; terminal and Vis syntax retain the GitHub Dark coding colors. Vis enables line numbers, current-line highlighting, and a colorful `github-dark` syntax theme. Normal and visual `y` send the default yank to the X clipboard; explicit named registers still work. In tmux copy mode, `y` and mouse selections copy through `xclip`. Mouse selection is handled by tmux; use Shift while dragging to select through st itself.

The installer applies the LibreWolf styles if exactly one `~/.config/librewolf/librewolf/*.default-release` profile exists. Otherwise, after starting LibreWolf once, copy `browser/chrome/userChrome.css` and `userContent.css` into your chosen profile's `chrome/` directory and enable `toolkit.legacyUserProfileCustomizations.stylesheets` in `about:config` if necessary. Restart LibreWolf to load its chrome styles. The styles cover the browser chrome and internal pages, not arbitrary websites.

## Search panels

Super+Space opens Spotlight for installed applications and local files. Super+K opens the searchable shortcut guide. Use the arrow keys and Enter to open a result, or Escape to close. Super+Up focuses the window above. The previous-layout control remains available by clicking the layout symbol in the bar.

File search creates a local, user-only cache under `~/.cache/t480-search` when Spotlight opens. It searches your home directory, skips common cache/build directories and browser/Codex profile data, and indexes up to 30,000 entries. The index refreshes each time Spotlight opens; installed desktop applications are refreshed on each search. Text and code files without a system default handler open in Vis.

## Bar

The dwm bar uses a restrained monochrome workspace strip, a bordered focused-window title, and separated clickable status items. Quickshell supplies live status information. After rebuilding dwm, press Super+Shift+R to reload the window manager and apply the new bar.
