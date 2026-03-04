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
