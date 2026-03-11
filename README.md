# Adore Browser

> The missing browser for lightweight X11 desktop environments.

For many years, Midori was the default browser in lightweight configurations. It was fast, simple, and lightweight. But after it was acquired by Astian, it quickly died out — because "why do we need a Firefox fork when we can just install Firefox directly?"

**Adore's main goal** is to be simple and integrated with lightweight desktop environments like XFCE, LXDE, and MATE. We don't strive for the latest technologies and protocols. We just need a browser.

## Features

- Tabbed browsing with drag-and-drop tab reordering and detachment
- Address bar with Google search suggestions and URL completion
- Per-tab favicons and titles
- Cookie persistence (SQLite)
- Favicon database
- Context menu for links (open, open in new tab, copy, download)
- Multiple windows

## Building

Adore uses [Meson](https://mesonbuild.com/).

```sh
meson setup build
cd build
ninja
```

To install system-wide:

```sh
sudo ninja install
```

## Debian/Ubuntu dependencies

```sh
sudo apt install valac meson ninja-build \
    libgtk-3-dev \
    libwebkit2gtk-4.1-dev \
    libsoup-3.0-dev \
    libjson-glib-dev
```

## Fedora dependencies

```sh
sudo dnf install vala meson ninja-build \
    gtk3-devel \
    webkit2gtk4.1-devel \
    libsoup3-devel \
    json-glib-devel
```

## Origin

Adore is a spiritual revival of [pumpkin-browser](https://github.com/dannote/pumpkin-browser),
originally written circa 2014 in Vala + WebKit/GTK. The codebase has been modernized:

- CMake → Meson
- `webkit2gtk-4.0` → `webkit2gtk-4.1`
- `libsoup-2.4` (`Soup.URI`, `queue_message`) → `libsoup-3.0` (`GLib.Uri`, `send_and_read_async`)
- All symbols renamed from `Pumpkin` to `Adore`

## License

GPL-3.0-or-later
