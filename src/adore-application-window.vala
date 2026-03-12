namespace Adore {
    [GtkTemplate(ui = "/io/github/adore-browser/adore/ui/window.ui")]
    public class ApplicationWindow : Gtk.ApplicationWindow {
        [GtkChild] protected unowned Adore.Notebook notebook;
        [GtkChild] protected unowned Gtk.Button back_button;
        [GtkChild] protected unowned Gtk.Button forward_button;
        [GtkChild] protected unowned Gtk.Button reload_button;
        [GtkChild] protected unowned Gtk.Image  reload_image;
        [GtkChild] public unowned Gtk.Entry address_entry;
        [GtkChild] protected unowned Gtk.MenuButton menu_button;
        [GtkChild] protected unowned Gtk.Button bookmark_button;
        [GtkChild] protected unowned Gtk.Image bookmark_image;

        protected Adore.GoogleCompletion address_entry_completion;

        private bool _page_is_loading = false;

        // ── Persistent dialogs (one per window) ──────────────────────────────
        private Adore.DownloadsDialog?  _downloads_dialog  = null;
        private Adore.BookmarksDialog?  _bookmarks_dialog   = null;
        private Adore.FilteringDialog?  _filtering_dialog   = null;

        public ApplicationWindow(Gtk.Application application) {
            Object(application: application);

            icon = notebook.icon;

            back_button.clicked.connect(notebook.go_back);
            forward_button.clicked.connect(notebook.go_forward);

            reload_button.clicked.connect(() => {
                if (_page_is_loading)
                    notebook.stop_loading();
                else
                    notebook.reload();
            });

            address_entry_completion = new Adore.GoogleCompletion();
            address_entry_completion.match_selected.connect(
                (entry_completion, model, iter) => {
                    var completion = (Adore.GoogleCompletion) entry_completion;
                    var suggestion_value = Value(typeof(string));
                    model.get_value(iter, completion.text_column, out suggestion_value);
                    open_in_current_page(suggestion_value.get_string());
                    completion.clear_model();
                    return true;
                });
            address_entry.completion = address_entry_completion;
            address_entry.changed.connect(address_entry_completion.load_model);
            address_entry.activate.connect(() => {
                address_entry_completion.clear_model();
                open_in_current_page(address_entry.text);
            });

            notebook.notify["icon"].connect(()     => icon  = notebook.icon);
            notebook.notify["title"].connect(()    => title = notebook.title);
            notebook.notify["uri"].connect(()      => {
                address_entry.text = notebook.uri;
                update_bookmark_button();
            });
            notebook.notify["progress"].connect(() => {
                double prog = notebook.progress;
                address_entry.progress_fraction = prog;
                update_loading_state(prog > 0.0 && prog < 1.0);
            });
            notebook.notify["can-go-back"].connect(() =>
                back_button.set_sensitive(notebook.can_go_back));
            notebook.notify["can-go-forward"].connect(() =>
                forward_button.set_sensitive(notebook.can_go_forward));

            notebook.new_page_button.clicked.connect(() => {
                create_page(false);
                address_entry.grab_focus();
                address_entry.select_region(0, -1);
            });

            notebook.create_window.connect((page, x, y) => {
                foreach (var win in application.get_windows()) {
                    if (win == this) continue;
                    var app_win = win as Adore.ApplicationWindow;
                    if (app_win == null) continue;
                    int wx, wy, ww, wh;
                    app_win.get_position(out wx, out wy);
                    app_win.get_size(out ww, out wh);
                    if (x >= wx && x <= wx + ww && y >= wy && y <= wy + wh)
                        return app_win.notebook;
                }
                var new_window = new Adore.ApplicationWindow(application);
                new_window.show();
                return new_window.notebook;
            });

            notebook.page_removed.connect(() => {
                if (notebook.get_n_pages() == 0) close();
            });

            // ── Bookmark button ───────────────────────────────────────────────
            bookmark_button.clicked.connect(toggle_bookmark);

            // ── Keyboard shortcuts ────────────────────────────────────────────
            setup_keyboard_shortcuts();

            // ── Menu ──────────────────────────────────────────────────────────
            setup_menu();

            // ── Download hook ─────────────────────────────────────────────────
            var app = (Adore.Application) application;
            app.web_context.download_started.connect((dl) => {
                ensure_downloads_dialog();
                _downloads_dialog.add_download(dl);
                // Auto-open the dialog on first download
                if (!_downloads_dialog.visible)
                    _downloads_dialog.show();
            });
        }

        // ── Loading indicator ─────────────────────────────────────────────────
        private void update_loading_state(bool loading) {
            _page_is_loading = loading;
            reload_image.icon_name = loading ? "process-stop-symbolic" : "view-refresh-symbolic";
        }

        // ── Bookmark button appearance ────────────────────────────────────────
        private void update_bookmark_button() {
            var uri = notebook.uri ?? "";
            var store = BookmarkStore.get_default();
            if (store.contains(uri)) {
                bookmark_button.get_style_context().add_class("suggested-action");
                bookmark_button.tooltip_text = "Remove bookmark";
                bookmark_image.icon_name = "starred-symbolic";
            } else {
                bookmark_button.get_style_context().remove_class("suggested-action");
                bookmark_button.tooltip_text = "Bookmark this page";
                bookmark_image.icon_name = "star-new-symbolic";
            }
        }

        private void toggle_bookmark() {
            var uri   = notebook.uri   ?? "";
            var title = notebook.title ?? uri;
            if (uri == "" || uri == "about:blank") return;
            var store = BookmarkStore.get_default();
            if (store.contains(uri)) {
                // Find and remove
                unowned var entries = store.entries;
                int i = 0;
                foreach (var e in entries) {
                    if (e.url == uri) {
                        store.remove_at(i);
                        break;
                    }
                    i++;
                }
            } else {
                store.add(title, uri);
            }
            update_bookmark_button();
        }

        // ── Keyboard shortcuts ────────────────────────────────────────────────
        private void setup_keyboard_shortcuts() {
            key_press_event.connect(on_key_press);
        }

        private bool on_key_press(Gdk.EventKey event) {
            bool ctrl  = (event.state & Gdk.ModifierType.CONTROL_MASK) != 0;
            bool shift = (event.state & Gdk.ModifierType.SHIFT_MASK)   != 0;

            if (ctrl) {
                switch (event.keyval) {
                    // ── Tabs ──────────────────────────────────────────────────
                    case Gdk.Key.t:
                        create_page(false);
                        address_entry.grab_focus();
                        address_entry.select_region(0, -1);
                        return true;

                    case Gdk.Key.w:
                        if (notebook.get_n_pages() > 0) {
                            int p = notebook.page;
                            notebook.remove_page(p);
                        }
                        return true;

                    case Gdk.Key.Page_Down:
                        notebook.next_page();
                        return true;

                    case Gdk.Key.Page_Up:
                        notebook.prev_page();
                        return true;

                    // ── New window ────────────────────────────────────────────
                    case Gdk.Key.n:
                        if (shift) {
                            // Ctrl+Shift+N — private window placeholder
                            // (WebKit private browsing is a separate context)
                        } else {
                            open_new_window();
                        }
                        return true;

                    // ── Navigation ────────────────────────────────────────────
                    case Gdk.Key.l:
                    case Gdk.Key.d:
                        address_entry.grab_focus();
                        address_entry.select_region(0, -1);
                        return true;

                    case Gdk.Key.r:
                        if (shift)
                            notebook.reload();   // hard reload (same action here)
                        else
                            notebook.reload();
                        return true;

                    // ── Bookmarks ─────────────────────────────────────────────
                    case Gdk.Key.b:
                        if (shift)
                            show_bookmarks_dialog();
                        else
                            toggle_bookmark();
                        return true;

                    // ── Downloads ─────────────────────────────────────────────
                    case Gdk.Key.j:
                        show_downloads_dialog();
                        return true;

                    // ── Find (F3 / Ctrl+F) — forward to WebView ────────────────
                    case Gdk.Key.f:
                        if (notebook.page >= 0) {
                            var wv = (WebKit.WebView) notebook.get_nth_page(notebook.page);
                            var fc = wv.get_find_controller();
                            fc.search("", WebKit.FindOptions.WRAP_AROUND, 100);
                        }
                        return false;  // let entry handle it

                    // ── Zoom ──────────────────────────────────────────────────
                    case Gdk.Key.plus:
                    case Gdk.Key.equal:
                        zoom_current(0.1);
                        return true;

                    case Gdk.Key.minus:
                        zoom_current(-0.1);
                        return true;

                    case Gdk.Key.@0:
                        zoom_current(0.0); // reset
                        return true;

                    default:
                        break;
                }
            }

            // F5 — reload, Alt+Left/Right — back/forward
            switch (event.keyval) {
                case Gdk.Key.F5:
                    notebook.reload();
                    return true;
                case Gdk.Key.Escape:
                    if (_page_is_loading) notebook.stop_loading();
                    return false;
                case Gdk.Key.F6:
                    address_entry.grab_focus();
                    address_entry.select_region(0, -1);
                    return true;
            }
            if ((event.state & Gdk.ModifierType.MOD1_MASK) != 0) {
                if (event.keyval == Gdk.Key.Left)  { notebook.go_back();    return true; }
                if (event.keyval == Gdk.Key.Right) { notebook.go_forward(); return true; }
            }

            return false;
        }

        // ── Zoom helper ───────────────────────────────────────────────────────
        private void zoom_current(double delta) {
            if (notebook.page < 0) return;
            var wv = (WebKit.WebView) notebook.get_nth_page(notebook.page);
            if (delta == 0.0)
                wv.zoom_level = 1.0;
            else
                wv.zoom_level = (wv.zoom_level + delta).clamp(0.25, 5.0);
        }

        // ── Menu ──────────────────────────────────────────────────────────────
        private void setup_menu() {
            var menu_model = new GLib.Menu();

            // ── Window section ──
            var window_section = new GLib.Menu();
            window_section.append("New Tab",      "win.new-tab");
            window_section.append("New Window",   "win.new-window");
            menu_model.append_section(null, window_section);

            // ── Bookmarks / Downloads section ──
            var tools_section = new GLib.Menu();
            tools_section.append("Bookmarks",  "win.show-bookmarks");
            tools_section.append("Downloads",  "win.show-downloads");
            menu_model.append_section(null, tools_section);

            // ── Settings / About section ──
            var app_section = new GLib.Menu();
            app_section.append("Filtering", "win.open-filtering");
            app_section.append("Settings",  "win.open-settings");
            app_section.append("About",     "win.open-about");
            menu_model.append_section(null, app_section);

            // ── Register actions ──
            add_named_action("new-tab", () => {
                create_page(false);
                address_entry.grab_focus();
                address_entry.select_region(0, -1);
            });
            add_named_action("new-window",      open_new_window);
            add_named_action("show-bookmarks",  show_bookmarks_dialog);
            add_named_action("show-downloads",  show_downloads_dialog);
            add_named_action("open-filtering",  show_filtering_dialog);
            add_named_action("open-settings",   open_settings);
            add_named_action("open-about",      open_about);

            menu_button.set_menu_model(menu_model);
        }

        private void add_named_action(string name, owned GLib.SimpleActionActivateCallback cb) {
            var action = new GLib.SimpleAction(name, null);
            action.activate.connect(cb);
            add_action(action);
        }

        // ── New window ────────────────────────────────────────────────────────
        private void open_new_window() {
            var new_win = new Adore.ApplicationWindow(application);
            var app = (Adore.Application) application;
            new_win.create_page(false).load_html("", null);
            new_win.address_entry.grab_focus();
            new_win.show();
        }

        // ── Downloads dialog ──────────────────────────────────────────────────
        private void ensure_downloads_dialog() {
            if (_downloads_dialog == null) {
                _downloads_dialog = new Adore.DownloadsDialog(this);
                _downloads_dialog.delete_event.connect(() => {
                    _downloads_dialog.hide();
                    return true;  // don't destroy, just hide
                });
            }
        }

        private void show_downloads_dialog() {
            ensure_downloads_dialog();
            _downloads_dialog.present();
        }

        // ── Bookmarks dialog ──────────────────────────────────────────────────
        private void ensure_bookmarks_dialog() {
            if (_bookmarks_dialog == null) {
                _bookmarks_dialog = new Adore.BookmarksDialog(this);
                _bookmarks_dialog.delete_event.connect(() => {
                    _bookmarks_dialog.hide();
                    return true;
                });
                _bookmarks_dialog.open_url.connect((url) => {
                    open_in_current_page(url);
                    _bookmarks_dialog.hide();
                });
            }
        }

        private void show_bookmarks_dialog() {
            ensure_bookmarks_dialog();
            _bookmarks_dialog.present();
        }

        // ── Filtering dialog ──────────────────────────────────────────────────
        private void show_filtering_dialog() {
            if (_filtering_dialog == null) {
                _filtering_dialog = new Adore.FilteringDialog(this);
            }
            _filtering_dialog.present();
        }

        // ── Settings ──────────────────────────────────────────────────────────
        private void open_settings() {
            var dlg = new Adore.SettingsDialog(this);
            dlg.settings_changed.connect(() => {
                var app = (Adore.Application) application;
                var s = Adore.Settings.get_default();
                s.apply_proxy(app.web_context);
                s.apply_web_settings(app.web_settings);
                for (int i = 0; i < notebook.get_n_pages(); i++) {
                    var wp = (WebKit.WebView) notebook.get_nth_page(i);
                    wp.reload();
                }
            });
            dlg.show();
        }

        // ── About ─────────────────────────────────────────────────────────────
        private Gdk.Pixbuf? load_logo_icon() {
            var theme = Gtk.IconTheme.get_default();
            
            string[] icons = {
                "io.github.adore-browser.adore",  // Primary
                "web-browser",                    // Fallback 1  
                "applications-internet",          // Fallback 2
                null
            };
            
            foreach (string? icon_name in icons) {
                if (icon_name == null) break;
                
                var gicon = theme.lookup_icon(icon_name, 128, 0);
                if (gicon != null) {
                    return gicon.load_icon();
                }
            }
            
            return null;
        }
        
        private void open_about() {
            var dlg = new Gtk.AboutDialog();
            dlg.transient_for = this;
            dlg.modal = true;
            
            var logo = load_logo_icon();
            if (logo != null) {
                dlg.logo = logo;
            }
            
            dlg.program_name = "Adore Web Browser";
            dlg.comments = "The missing browser.";
            dlg.copyright = "Copyright © 2026 Qwaderton";
            dlg.website = "https://adore-browser.github.io/";
            dlg.run();
            dlg.destroy();
        }

        // ── Navigation ────────────────────────────────────────────────────────
        public void open_in_current_page(string text) {
            if (notebook.page >= 0) {
                var web_view = (WebKit.WebView) notebook.get_nth_page(notebook.page);
                web_view.grab_focus();
                string uri;
                if (Adore.Util.Uri.is_valid(text)) {
                    uri = Adore.Util.Uri.normalize(text);
                } else {
                    var search_url = Adore.Settings.get_default().search_engine_url;
                    uri = search_url.printf(GLib.Uri.escape_string(text, null, true));
                }
                web_view.load_uri(uri);
            }
        }

        public Adore.WebPage get_current_page() {
            return (Adore.WebPage) notebook.get_nth_page(notebook.page);
        }

        public Adore.WebPage create_page(bool neighbor = true) {
            var web_page = new Adore.WebPage((Adore.Application) application);
            setup_page_signals(web_page);
            web_page.show();
            notebook.set_current_page(neighbor
                ? notebook.insert_page(web_page, notebook.page + 1)
                : notebook.append_page(web_page));
            web_page.grab_focus();
            return web_page;
        }

        private Adore.WebPage create_page_for_webkit(Adore.WebPage parent) {
            var web_page = new Adore.WebPage.as_related(
                parent, (Adore.Application) application);
            setup_page_signals(web_page);
            web_page.ready_to_show.connect(() => {
                web_page.show();
                notebook.set_current_page(
                    notebook.insert_page(web_page, notebook.page + 1));
                web_page.grab_focus();
            });
            return web_page;
        }

        private void setup_page_signals(Adore.WebPage web_page) {
            web_page.create.connect((nav_action) =>
                create_page_for_webkit(web_page));

            web_page.context_menu.connect(
                (context_menu, event, hit_test_result) => {
                    if (hit_test_result.context_is_link()) {
                        context_menu.remove_all();
                        var open_link = new WebKit.ContextMenuItem
                            .from_stock_action_with_label(
                                WebKit.ContextMenuAction.OPEN_LINK, "Open Link");
                        var link_uri  = hit_test_result.get_link_uri();
                        var tab_action = new Gtk.Action(
                            "open-in-tab", "Open in New Tab", null, null);
                        tab_action.activate.connect(() =>
                            create_page().load_uri(link_uri));
                        var open_in_tab  = new WebKit.ContextMenuItem(tab_action);
                        var copy_link    = new WebKit.ContextMenuItem
                            .from_stock_action_with_label(
                                WebKit.ContextMenuAction.COPY_LINK_TO_CLIPBOARD,
                                "Copy Link");
                        var download_link = new WebKit.ContextMenuItem
                            .from_stock_action_with_label(
                                WebKit.ContextMenuAction.DOWNLOAD_LINK_TO_DISK,
                                "Download linked File");
                        context_menu.append(open_link);
                        context_menu.append(open_in_tab);
                        context_menu.append(copy_link);
                        context_menu.append(download_link);
                    }
                    return false;
                });
        }
    }
}