project('adore', 'vala', 'c',
  version: '1.2',
  license: 'GPL-3.0-or-later',
  meson_version: '>= 0.59.0',
  default_options: [
    'warning_level=0',
  ]
)

gnome = import('gnome')

adore_deps = [
  dependency('gtk+-3.0', version: '>= 3.22'),
  dependency('webkit2gtk-4.1'),
  dependency('libsoup-3.0'),
  dependency('json-glib-1.0'),
  dependency('glib-2.0'),
  dependency('gio-2.0')
]

subdir('data')
subdir('src')
