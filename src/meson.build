adore_sources = files(
  'adore.vala',
  'adore-application.vala',
  'adore-application-window.vala',
  'adore-notebook.vala',
  'adore-page.vala',
  'adore-page-label.vala',
  'adore-web-page.vala',
  'adore-google-completion.vala',
  'adore-util.vala',
)

executable('adore',
  adore_sources,
  adore_resources,
  dependencies: adore_deps,
  vala_args: [
    '--target-glib=2.56',
    '--gresourcesdir=' + meson.project_source_root() / 'data',
  ],
  install: true,
)
