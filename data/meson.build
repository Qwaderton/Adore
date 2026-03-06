adore_resources = gnome.compile_resources(
  'adore-resources',
  'adore.gresource.xml',
  source_dir: meson.current_source_dir(),
  c_name: 'adore',
  export: true,
)

install_data(
  'io.github.adore_browser.adore.desktop',
  install_dir: join_paths(get_option('datadir'), 'applications'),
)

install_data(
  'icons/Adore.svg',
  install_dir: join_paths(get_option('datadir'), 'icons', 'hicolor', 'scalable', 'apps'),
  rename: 'io.github.adore-browser.adore.svg',
)

gnome.post_install(
  gtk_update_icon_cache: true,
)