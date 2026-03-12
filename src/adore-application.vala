namespace Adore {
    public class Application : Gtk.Application {
        protected ApplicationWindow window;
        public WebKit.WebContext web_context;
        public WebKit.Settings web_settings;
        public WebKit.UserContentManager user_content_manager;
        private string _data_path;
        private string _database_path;

        public string data_path {
            get { return _data_path; }
        }

        public string database_path {
            get { return _database_path; }
        }

        public Application() {
            Object(application_id: APP_ID, flags: ApplicationFlags.HANDLES_OPEN);

            _data_path = Path.build_path(
                Path.DIR_SEPARATOR_S,
                Environment.get_user_data_dir(),
                "adore"
            );
            DirUtils.create_with_parents(_data_path, 0700);
            _database_path = Path.build_filename(_data_path, "browser.db");

            web_context = new WebKit.WebContext();
            web_context.set_favicon_database_directory(null);
            web_context.set_cache_model(WebKit.CacheModel.DOCUMENT_BROWSER);

            web_context.get_cookie_manager().set_persistent_storage(
                _database_path,
                WebKit.CookiePersistentStorage.SQLITE
            );

            web_settings = new WebKit.Settings();
            web_settings.enable_smooth_scrolling = true;
            web_settings.enable_developer_extras = true;

            // Applying the saved settings
            var settings = Adore.Settings.get_default();
            settings.apply_proxy(web_context);
            settings.apply_web_settings(web_settings);

            // ── Content filtering ──────────────────────────────────────────────
            user_content_manager = new WebKit.UserContentManager();
            Adore.ContentFilterManager.get_default().attach(user_content_manager);
            Adore.ContentFilterManager.get_default().update_if_needed.begin(null);

            startup.connect(() => {
                window = new ApplicationWindow(this);
            });

            open.connect((files, hint) => {
                foreach (var file in files) {
                    window.create_page(false).load_uri(file.get_uri());
                }
                window.present();
            });
        }

        protected override void activate() {
            var settings = Adore.Settings.get_default();
            string homepage = settings.homepage.strip();

            var page = window.create_page(false);
            if (homepage != "") {
                page.load_uri(homepage);
            } else {
                // Empty page — focus on the address bar, as it was before
                page.load_html("", null);
            }

            window.address_entry.grab_focus();
            window.address_entry.select_region(0, -1);
            window.present();
        }
    }
}

public static int main(string[] args) {
    var application = new Adore.Application();
    return application.run(args);
}