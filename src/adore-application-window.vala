namespace Adore {
    [GtkTemplate(ui = "/io/github/adore_browser/adore/ui/window.ui")]
    public class ApplicationWindow : Gtk.ApplicationWindow {
        [GtkChild] protected unowned Adore.Notebook notebook;
        [GtkChild] protected unowned Gtk.ToolButton back_button;
        [GtkChild] protected unowned Gtk.ToolButton forward_button;
        [GtkChild] protected unowned Gtk.ToolButton reload_button;
        [GtkChild] public unowned Gtk.Entry address_entry;
        protected Adore.GoogleCompletion address_entry_completion;

        public ApplicationWindow(Gtk.Application application) {
            Object(application: application);

            icon = notebook.icon;

            back_button.clicked.connect(notebook.go_back);
            forward_button.clicked.connect(notebook.go_forward);
            reload_button.clicked.connect(notebook.reload);

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
            notebook.notify["progress"].connect(() =>
                address_entry.progress_fraction = notebook.progress);
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
                var new_window = new Adore.ApplicationWindow(application);
                new_window.show();
                return new_window.notebook;
            });

            notebook.page_removed.connect(() => {
                if (notebook.get_n_pages() == 0) {
                    close();
                }
            });
        }

        public void open_in_current_page(string text) {
            if (notebook.page >= 0) {
                var web_view = (WebKit.WebView) notebook.get_nth_page(notebook.page);
                web_view.grab_focus();
                string uri;
                if (Adore.Util.Uri.is_valid(text)) {
                    uri = text;
                } else {
                    // libsoup-3: use GLib.Uri.escape_string instead of Soup.URI.encode
                    uri = "https://www.google.com/search?q=%s".printf(
                        GLib.Uri.escape_string(text, null, true)
                    );
                }
                web_view.load_uri(uri);
            }
        }

        public Adore.WebPage get_current_page() {
            return (Adore.WebPage) notebook.get_nth_page(notebook.page);
        }

        public Adore.WebPage create_page(bool neighbor = true) {
            var web_page = new Adore.WebPage((Adore.Application) application);

            web_page.create.connect(() => create_page());
            web_page.context_menu.connect((context_menu, event, hit_test_result) => {
                if (hit_test_result.context_is_link()) {
                    context_menu.remove_all();
                    var open_link = new WebKit.ContextMenuItem.from_stock_action(
                        WebKit.ContextMenuAction.OPEN_LINK
                    );
                    var open_in_tab = new WebKit.ContextMenuItem.from_stock_action_with_label(
                        WebKit.ContextMenuAction.OPEN_LINK_IN_NEW_WINDOW,
                        "Open in New Tab"
                    );
                    var copy_link = new WebKit.ContextMenuItem.from_stock_action(
                        WebKit.ContextMenuAction.COPY_LINK_TO_CLIPBOARD
                    );
                    var download_link = new WebKit.ContextMenuItem.from_stock_action(
                        WebKit.ContextMenuAction.DOWNLOAD_LINK_TO_DISK
                    );
                    context_menu.append(open_link);
                    context_menu.append(open_in_tab);
                    context_menu.append(copy_link);
                    context_menu.append(download_link);
                }
                return false;
            });

            web_page.show();

            notebook.set_current_page(neighbor ?
                notebook.insert_page(web_page, notebook.page + 1) :
                notebook.append_page(web_page));

            web_page.grab_focus();

            return web_page;
        }
    }
}
