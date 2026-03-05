namespace Adore {
    public class CookiesCacheDialog : Gtk.Dialog {
        private WebKit.WebContext _web_context;

        public CookiesCacheDialog(Gtk.Window parent,
                                  WebKit.WebContext web_context) {
            Object(
                title:          "Cookies & Cache",
                transient_for:  parent,
                modal:          true,
                use_header_bar: 1
            );
            _web_context = web_context;
            set_default_size(380, -1);
            resizable = false;
            build_ui();
        }

        private void build_ui() {
            var content = get_content_area();
            content.spacing = 0;

            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing    = 12;
            grid.margin         = 16;

            int row = 0;

            // ---- Cookies ----
            var cookies_label = new Gtk.Label("<b>Cookies</b>");
            cookies_label.use_markup = true;
            cookies_label.halign = Gtk.Align.START;
            grid.attach(cookies_label, 0, row++, 2, 1);

            var clear_cookies_btn = new Gtk.Button.with_label("Clear all cookies");
            clear_cookies_btn.hexpand = true;
            clear_cookies_btn.clicked.connect(on_clear_cookies);
            grid.attach(clear_cookies_btn, 0, row++, 2, 1);

            var sep1 = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep1.margin_top = 4;
            sep1.margin_bottom = 4;
            grid.attach(sep1, 0, row++, 2, 1);

            // ---- Cache ----
            var cache_label = new Gtk.Label("<b>Cache</b>");
            cache_label.use_markup = true;
            cache_label.halign = Gtk.Align.START;
            grid.attach(cache_label, 0, row++, 2, 1);

            var clear_cache_btn = new Gtk.Button.with_label("Clear disk cache");
            clear_cache_btn.hexpand = true;
            clear_cache_btn.clicked.connect(on_clear_cache);
            grid.attach(clear_cache_btn, 0, row++, 2, 1);

            var clear_all_btn = new Gtk.Button.with_label("Clear cookies & cache");
            clear_all_btn.hexpand = true;
            clear_all_btn.get_style_context().add_class("destructive-action");
            clear_all_btn.clicked.connect(on_clear_all);
            grid.attach(clear_all_btn, 0, row++, 2, 1);

            content.pack_start(grid, true, true, 0);
            content.show_all();

            add_button("Close", Gtk.ResponseType.CLOSE);
            response.connect((id) => destroy());
        }

        private void on_clear_cookies() {
            _web_context.get_cookie_manager().delete_all_cookies();
            show_info("All cookies cleared.");
        }

        private void on_clear_cache() {
            _web_context.clear_cache();
            show_info("Disk cache cleared.");
        }

        private void on_clear_all() {
            _web_context.get_cookie_manager().delete_all_cookies();
            _web_context.clear_cache();
            show_info("Cookies and cache cleared.");
        }

        private void show_info(string message) {
            var dlg = new Gtk.MessageDialog(
                this,
                Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                Gtk.MessageType.INFO,
                Gtk.ButtonsType.OK,
                "%s", message
            );
            dlg.run();
            dlg.destroy();
        }
    }
}
