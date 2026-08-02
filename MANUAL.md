# Manual steps

Everything a fresh `just switch` cannot do. Roughly 15 minutes.

## Credentials

- [ ] Copy `~/.ssh/` from the old machine or your password manager, then
      `chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_*`
- [ ] `gh auth login`
- [ ] `gcloud auth login` and `gcloud config set project <project>`
- [ ] Copy `~/.aws/credentials` and `~/.aws/config`
- [ ] Copy `~/.kube/config` if you need cluster access

## Apps needing a sign-in

- [ ] Slack, Telegram, Discord, WhatsApp, Claude, ChatGPT
- [ ] VS Code — sign in to Settings Sync if you use it

## Apps this repo does not install

Installed by hand on the old machine and deliberately left undeclared. Install
whichever you still want:

Microsoft Office (Word, Excel, PowerPoint, OneNote, Outlook), Xcode, Adobe
Acrobat, OneDrive, Grammarly, Obsidian, Steam, AdGuard, Clash Verge, AWS VPN
Client, VLC, Folx, Google Chrome, Cursor, Portal, Wallspace, Syncthing.

## macOS settings not managed here

- [ ] Apple ID and iCloud sign-in
- [ ] Keyboard layouts and input sources
- [ ] Displays, Night Shift, hot corners
- [ ] Grant Accessibility permission to AeroSpace on first launch
      (System Settings → Privacy & Security → Accessibility)
- [ ] Grant Accessibility permission to Rectangle on first launch

## First-run notes

- Ghostty may need a restart after the font casks land, or it falls back to a
  system font.
- tmux plugins are installed by Nix at pinned revisions — `prefix + I` is NOT
  needed and would only re-clone them at newer versions.
- Saved tmux sessions do not transfer. Continuum starts saving fresh.
- Hidden Bar comes from the Homebrew cask (the GitHub release), whereas the old
  machine had the App Store build. Same app, different distribution.
- Telegram comes from the `telegram` cask, whereas the old machine ran
  "Telegram Lite" from the App Store.

## Verify

```sh
just doctor
```

Expect `doctor: all checks passed`. Anything else is real — read the output.
