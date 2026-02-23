# wallzz

Random gradient & abstract wallpaper setter for macOS. One command, instant desktop refresh.

Fetches curated gradient/abstract wallpapers from [Wallhaven](https://wallhaven.cc) (no API key needed) and sets them as your desktop background.

## Install

```bash
git clone https://github.com/madebycm/wallzz.git
chmod +x wallzz/wallzz.sh
```

Optional alias in `~/.zprofile` or `~/.zshrc`:

```bash
alias wz="~/path/to/wallzz/wallzz.sh"
```

## Usage

```bash
./wallzz.sh
# or with alias:
wz
```

## Requirements

- macOS
- `curl`, `python3` (pre-installed on macOS)

## How it works

- Picks from curated Wallhaven tag queries (gradient, soft gradient, abstract + color filters)
- Fetches a random wallpaper at your screen's native resolution
- Sets it across all desktops via Finder

No API keys. No config. No dependencies.

## License

All rights reserved. No reuse without permission.
