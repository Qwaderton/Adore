# Adore Web Browser

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
- Content filtering lists

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

### Debian/Ubuntu dependencies

```sh
sudo apt install valac meson ninja-build \
    libgtk-3-dev \
    libwebkit2gtk-4.1-dev \
    libsoup-3.0-dev \
    libjson-glib-dev
```

### Fedora dependencies

```sh
sudo dnf install vala meson ninja-build \
    gtk3-devel \
    webkit2gtk4.1-devel \
    libsoup3-devel \
    json-glib-devel
```

## FAQ

### How long will the Adore browser be supported?

I will try to maintain the browser until the end of GTK 3's life, then use some of its source code for a new project, although I think by that point it will no longer make sense.

### What is the point of the project?

There is currently no good browser on GTK 3. Previously, there was Midori, and now there is Epiphany. One has stopped being updated, and the other has already switched to GTK 4. Many still prefer GTK 3 environments, such as Budgie, Pantheon, XFCE, MATE, and even LXDE. Firefox, to put it mildly, does not fit into the overall style and is heavier than WebKit2.

### 

## Origin

Adore is a spiritual revival of [pumpkin-browser](https://github.com/dannote/pumpkin-browser),
originally written circa 2014 in Vala + WebKit/GTK. The codebase has been modernized.

## License

GPL-3.0-or-later
