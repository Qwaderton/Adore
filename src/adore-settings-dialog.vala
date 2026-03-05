namespace Adore {
    public class SettingsDialog : Gtk.Dialog {
        // Proxy
        private Gtk.ComboBoxText proxy_type_combo;
        private Gtk.Entry        proxy_host_entry;
        private Gtk.SpinButton   proxy_port_spin;
        private Gtk.Entry        proxy_user_entry;
        private Gtk.Entry        proxy_pass_entry;
        private Gtk.Grid         proxy_detail_grid;
        private Gtk.Entry        search_engine_entry;
        private Gtk.Switch       suggestions_switch;

        // Browser
        private Gtk.Switch js_switch;
        private Gtk.Entry  homepage_entry;

        // Privacy (Cookies & Cache)
        private WebKit.WebContext _web_context;

        public SettingsDialog(Gtk.Window parent) {
            Object(
                title:          "Settings",
                transient_for:  parent,
                modal:          true,
                use_header_bar: 1
            );

            var app = (Adore.Application) ((Gtk.ApplicationWindow) parent).application;
            _web_context = app.web_context;

            set_default_size(500, -1);
            resizable = false;

            build_ui();
            load_values();

            add_button("Cancel", Gtk.ResponseType.CANCEL);
            var apply_btn = (Gtk.Button) add_button("Apply", Gtk.ResponseType.APPLY);
            apply_btn.get_style_context().add_class("suggested-action");

            response.connect(on_response);
        }

        private void build_ui() {
            var content = get_content_area();
            content.spacing = 0;

            var notebook = new Gtk.Notebook();
            notebook.margin = 12;
            notebook.append_page(build_browser_page(), new Gtk.Label("Browser"));
            notebook.append_page(build_proxy_page(),   new Gtk.Label("Proxy"));
            notebook.append_page(build_privacy_page(), new Gtk.Label("Privacy"));
            content.pack_start(notebook, true, true, 0);
            content.show_all();
        }

        // ── Browser ──────────────────────────────────────────────────────────
        private Gtk.Widget build_browser_page() {
            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing    = 12;
            grid.margin         = 16;

            int row = 0;

            grid.attach(make_label("JavaScript:"), 0, row, 1, 1);
            js_switch = new Gtk.Switch();
            js_switch.halign = Gtk.Align.START;
            grid.attach(js_switch, 1, row++, 1, 1);

            grid.attach(make_label("Homepage:"), 0, row, 1, 1);
            homepage_entry = new Gtk.Entry();
            homepage_entry.hexpand = true;
            homepage_entry.placeholder_text = "https://example.com";
            grid.attach(homepage_entry, 1, row++, 1, 1);

            grid.attach(make_label("Search engine URL:"), 0, row, 1, 1);
            search_engine_entry = new Gtk.Entry();
            search_engine_entry.hexpand = true;
            search_engine_entry.placeholder_text = "https://www.google.com/search?q=%s";
            grid.attach(search_engine_entry, 1, row++, 1, 1);

            var search_hint = new Gtk.Label("<small>Use <tt>%s</tt> as query placeholder</small>");
            search_hint.use_markup = true;
            search_hint.halign = Gtk.Align.START;
            grid.attach(search_hint, 1, row++, 1, 1);

            grid.attach(make_label("Search suggestions:"), 0, row, 1, 1);
            suggestions_switch = new Gtk.Switch();
            suggestions_switch.halign = Gtk.Align.START;
            grid.attach(suggestions_switch, 1, row++, 1, 1);

            return grid;
        }

        // ── Proxy ─────────────────────────────────────────────────────────────
        private Gtk.Widget build_proxy_page() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            box.margin = 16;

            // --- Proxy type ---
            var type_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 8);
            type_box.pack_start(new Gtk.Label("Proxy type:"), false, false, 0);

            proxy_type_combo = new Gtk.ComboBoxText();
            proxy_type_combo.append_text("No proxy");          // 0 = NONE
            proxy_type_combo.append_text("System proxy");    // 1 = SYSTEM
            proxy_type_combo.append_text("HTTP");                 // 2 = HTTP
            proxy_type_combo.append_text("HTTPS");                // 3 = HTTPS
            proxy_type_combo.append_text("SOCKS4");               // 4 = SOCKS4
            proxy_type_combo.append_text("SOCKS5");               // 5 = SOCKS5
            proxy_type_combo.hexpand = true;
            type_box.pack_start(proxy_type_combo, true, true, 0);
            box.pack_start(type_box, false, false, 0);

            // --- Connection details  ---
            proxy_detail_grid = new Gtk.Grid();
            proxy_detail_grid.column_spacing = 10;
            proxy_detail_grid.row_spacing    = 8;
            proxy_detail_grid.margin_top     = 8;

            int row = 0;
            proxy_detail_grid.attach(make_label("Host:"),     0, row, 1, 1);
            proxy_host_entry = new Gtk.Entry();
            proxy_host_entry.hexpand = true;
            proxy_host_entry.placeholder_text = "127.0.0.1";
            proxy_detail_grid.attach(proxy_host_entry, 1, row++, 1, 1);

            proxy_detail_grid.attach(make_label("Port:"),     0, row, 1, 1);
            proxy_port_spin = new Gtk.SpinButton.with_range(1, 65535, 1);
            proxy_port_spin.value = 8080;
            proxy_detail_grid.attach(proxy_port_spin, 1, row++, 1, 1);

            proxy_detail_grid.attach(make_label("Login:"),    0, row, 1, 1);
            proxy_user_entry = new Gtk.Entry();
            proxy_user_entry.placeholder_text = "(optional)";
            proxy_detail_grid.attach(proxy_user_entry, 1, row++, 1, 1);

            proxy_detail_grid.attach(make_label("Password:"),   0, row, 1, 1);
            proxy_pass_entry = new Gtk.Entry();
            proxy_pass_entry.visibility = false;
            proxy_pass_entry.placeholder_text = "(optional)";
            proxy_detail_grid.attach(proxy_pass_entry, 1, row++, 1, 1);

            box.pack_start(proxy_detail_grid, false, false, 0);

            // Show/hide details depending on the type
            proxy_type_combo.changed.connect(update_proxy_detail_visibility);

            return box;
        }

        // ── Privacy (Cookies & Cache) ─────────────────────────────────────────
        private Gtk.Widget build_privacy_page() {
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 12);
            box.margin = 16;

            var cookies_lbl = new Gtk.Label("<b>Cookies</b>");
            cookies_lbl.use_markup = true;
            cookies_lbl.halign = Gtk.Align.START;
            box.pack_start(cookies_lbl, false, false, 0);

            var clear_cookies_btn = new Gtk.Button.with_label("Clear all cookies");
            clear_cookies_btn.clicked.connect(() => {
                _web_context.get_cookie_manager().delete_all_cookies();
                show_info("All cookies cleared.");
            });
            box.pack_start(clear_cookies_btn, false, false, 0);

            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            box.pack_start(sep, false, false, 0);

            var cache_lbl = new Gtk.Label("<b>Cache</b>");
            cache_lbl.use_markup = true;
            cache_lbl.halign = Gtk.Align.START;
            box.pack_start(cache_lbl, false, false, 0);

            var clear_cache_btn = new Gtk.Button.with_label("Clear disk cache");
            clear_cache_btn.clicked.connect(() => {
                _web_context.clear_cache();
                show_info("Disk cache cleared.");
            });
            box.pack_start(clear_cache_btn, false, false, 0);

            var clear_all_btn = new Gtk.Button.with_label("Clear cookies & cache");
            clear_all_btn.get_style_context().add_class("destructive-action");
            clear_all_btn.clicked.connect(() => {
                _web_context.get_cookie_manager().delete_all_cookies();
                _web_context.clear_cache();
                show_info("Cookies and cache cleared.");
            });
            box.pack_start(clear_all_btn, false, false, 0);

            return box;
        }

        private Gtk.Label make_label(string text) {
            var lbl = new Gtk.Label(text);
            lbl.halign = Gtk.Align.END;
            return lbl;
        }

        private void update_proxy_detail_visibility() {
            proxy_detail_grid.sensitive = (proxy_type_combo.get_active() >= 2);
        }

        private void load_values() {
            var s = Adore.Settings.get_default();

            proxy_type_combo.set_active((int) s.proxy_type);
            proxy_host_entry.text  = s.proxy_host;
            proxy_port_spin.value  = s.proxy_port;
            proxy_user_entry.text  = s.proxy_username;
            proxy_pass_entry.text  = s.proxy_password;

            js_switch.active          = s.enable_javascript;
            homepage_entry.text       = s.homepage;
            search_engine_entry.text  = s.search_engine_url;
            suggestions_switch.active = s.enable_suggestions;

            update_proxy_detail_visibility();
        }

        private void on_response(int response_id) {
            if (response_id == Gtk.ResponseType.APPLY) {
                save_values();
            }
            destroy();
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

        private void save_values() {
            var s = Adore.Settings.get_default();

            s.proxy_type     = (Adore.Settings.ProxyType) proxy_type_combo.get_active();
            s.proxy_host     = proxy_host_entry.text;
            s.proxy_port     = (int) proxy_port_spin.value;
            s.proxy_username = proxy_user_entry.text;
            s.proxy_password = proxy_pass_entry.text;

            s.enable_javascript  = js_switch.active;
            s.homepage           = homepage_entry.text;
            s.search_engine_url  = search_engine_entry.text.strip() != ""
                ? search_engine_entry.text.strip()
                : "https://www.google.com/search?q=%s";
            s.enable_suggestions = suggestions_switch.active;

            s.save();
            settings_changed();
        }

        public signal void settings_changed();
    }
}
