config_vala = configure_file(
    input:  'adore.vala.in',
    output: 'adore.vala',
    configuration: {
        'APP_VERSION': meson.project_version(),
    }
)

adore_sources = files(
  'adore-application.vala',
  'adore-application-window.vala',
  'adore-notebook.vala',
  'adore-page.vala',
  'adore-page-label.vala',
  'adore-web-page.vala',
  'adore-google-completion.vala',
  'adore-util.vala',
  'adore-settings.vala',
  'adore-settings-dialog.vala',
  'adore-downloads-dialog.vala',
  'adore-bookmarks.vala',
  'adore-content-filtering.vala',
) + [config_vala]

executable('adore',
  adore_sources,
  adore_resources,
  dependencies: adore_deps,
  vala_args: [
    '--target-glib=2.56',
    '--gresourcesdir=' + meson.project_source_root() / 'data',
    '--define=APP_VERSION="' + meson.project_version() + '"'
  ],
  install: true,
)
