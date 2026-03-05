namespace Adore {
    [GtkTemplate(ui = "/io/github/adore-browser/adore/ui/window.ui")]
    public class ApplicationWindow : Gtk.ApplicationWindow {
        [GtkChild] protected unowned Adore.Notebook notebook;
        [GtkChild] protected unowned Gtk.ToolButton back_button;
        [GtkChild] protected unowned Gtk.ToolButton forward_button;
        [GtkChild] protected unowned Gtk.ToolButton reload_button;
        [GtkChild] public unowned Gtk.Entry address_entry;
        [GtkChild] protected unowned Gtk.MenuButton menu_button;

        protected Adore.GoogleCompletion address_entry_completion;

        // Monitoring the download status to switch reload ↔ stop
        private bool _page_is_loading = false;

        public ApplicationWindow(Gtk.Application application) {
            Object(application: application);

            icon = notebook.icon;

            back_button.clicked.connect(notebook.go_back);
            forward_button.clicked.connect(notebook.go_forward);

            // reload_button: a click either restarts or stops the download
            reload_button.clicked.connect(() => {
                if (_page_is_loading) {
                    notebook.stop_loading();
                } else {
                    notebook.reload();
                }
            });

            address_entry_completion = new Adore.GoogleCompletion();
            address_entry_completion.match_selected.connect((entry_completion, model, iter) => {
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

            notebook.notify["icon"].connect(() => icon = notebook.icon);
            notebook.notify["title"].connect(() => title = notebook.title);
            notebook.notify["uri"].connect(() => address_entry.text = notebook.uri);
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
                // Check if the drop landed inside any existing application window
                foreach (var win in application.get_windows()) {
                    if (win == this) continue;
                    var app_win = win as Adore.ApplicationWindow;
                    if (app_win == null) continue;
                    int wx, wy, ww, wh;
                    app_win.get_position(out wx, out wy);
                    app_win.get_size(out ww, out wh);
                    if (x >= wx && x <= wx + ww && y >= wy && y <= wy + wh) {
                        return app_win.notebook;
                    }
                }
                // Otherwise open a new window
                var new_window = new Adore.ApplicationWindow(application);
                new_window.show();
                return new_window.notebook;
            });

            notebook.page_removed.connect(() => {
                if (notebook.get_n_pages() == 0) {
                    close();
                }
            });

            setup_menu();
        }

        // Switching the icon of the reload/stop button
        private void update_loading_state(bool loading) {
            _page_is_loading = loading;
            reload_button.icon_name = loading ? "process-stop" : "view-refresh";
        }

        // Собираем выпадающее меню
        private void setup_menu() {
            var menu = new Gtk.Menu();

            var settings_item = new Gtk.MenuItem.with_label("Settings");
            settings_item.activate.connect(open_settings);
            menu.append(settings_item);

            var about_item = new Gtk.MenuItem.with_label("About");
            about_item.activate.connect(open_about);
            menu.append(about_item);

            menu.show_all();
            menu_button.popup = menu;
        }

        private void open_settings() {
            var dlg = new Adore.SettingsDialog(this);
            dlg.settings_changed.connect(() => {
                var app = (Adore.Application) application;
                var s = Adore.Settings.get_default();
                s.apply_proxy(app.web_context);
                s.apply_web_settings(app.web_settings);
                // Reloading the tabs so that the new JS setting is immediately applied
                for (int i = 0; i < notebook.get_n_pages(); i++) {
                    var wp = (WebKit.WebView) notebook.get_nth_page(i);
                    wp.reload();
                }
            });
            dlg.show();
        }

        private void open_about() {
            var dlg = new Gtk.AboutDialog();
            dlg.transient_for = this;
            dlg.modal = true;
            dlg.logo = Gtk.IconTheme.get_default().load_icon("browser", 64, 0);
            dlg.program_name = "Adore";
            dlg.comments = "The missing browser for lightweight\nX11 desktop environments.";
            dlg.copyright = "Copyright © 2026 Qwaderton";
            dlg.version = "1.1";
            dlg.website = "https://adore.qwaderton.org";
            dlg.license_type = Gtk.License.GPL_3_0;
            dlg.wrap_license = true;
            dlg.run();
            dlg.destroy();
        }

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
            notebook.set_current_page(neighbor ?
                notebook.insert_page(web_page, notebook.page + 1) :
                notebook.append_page(web_page));
            web_page.grab_focus();
            return web_page;
        }

        /// WebKit request creation (window.open, target=_blank, middle button)
        // Returns a "bare" WebView — without show() and without adding to the notebook.
        // WebKit will load the page into it itself, then emit a ready-to-show.
        private Adore.WebPage create_page_for_webkit(Adore.WebPage parent) {
            var web_page = new Adore.WebPage.as_related(parent, (Adore.Application) application);
            setup_page_signals(web_page);

            web_page.ready_to_show.connect(() => {
                web_page.show();
                notebook.set_current_page(
                    notebook.insert_page(web_page, notebook.page + 1)
                );
                web_page.grab_focus();
            });

            return web_page;
        }

        // The entire signal harness has been moved here so as not to duplicate
        private void setup_page_signals(Adore.WebPage web_page) {
            web_page.create.connect((nav_action) => {
                return create_page_for_webkit(web_page);
            });

            web_page.context_menu.connect((context_menu, event, hit_test_result) => {
                if (hit_test_result.context_is_link()) {
                    context_menu.remove_all();
                    var open_link = new WebKit.ContextMenuItem.from_stock_action_with_label(
                        WebKit.ContextMenuAction.OPEN_LINK, "Open Link");
                    var link_uri = hit_test_result.get_link_uri();
                    var tab_action = new Gtk.Action("open-in-tab", "Open in New Tab", null, null);
                    tab_action.activate.connect(() => {
                        create_page().load_uri(link_uri);
                    });
                    var open_in_tab = new WebKit.ContextMenuItem(tab_action);

                    var copy_link = new WebKit.ContextMenuItem.from_stock_action_with_label(
                        WebKit.ContextMenuAction.COPY_LINK_TO_CLIPBOARD, "Copy Link");
                    var download_link = new WebKit.ContextMenuItem.from_stock_action_with_label(
                        WebKit.ContextMenuAction.DOWNLOAD_LINK_TO_DISK, "Download linked File");
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
