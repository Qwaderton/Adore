namespace Adore {
    public class GoogleCompletion : Gtk.EntryCompletion {
        // libsoup-3: Soup.Session is still used but queue_message is gone;
        // we use the GLib.Task-based async send() instead.
        private Soup.Session session;

        public GoogleCompletion() {
            session = new Soup.Session();

            model = new Gtk.ListStore(2, typeof(string), typeof(string));
            text_column = 1;
            inline_completion = true;

            var source_renderer = new Gtk.CellRendererText();
            source_renderer.style = Pango.Style.ITALIC;
            cell_area.pack_end(source_renderer, false);
            cell_area.add_attribute(source_renderer, "text", 0);

            set_match_func((completion, key, iter) => {
                var suggestion_value = Value(typeof(string));
                completion.model.get_value(iter, completion.text_column, out suggestion_value);
                var suggestion = suggestion_value.get_string();
                if (suggestion != null) {
                    return suggestion.has_prefix(key) ||
                           suggestion.has_prefix(Adore.Util.Uri.normalize(key));
                }
                return false;
            });
        }

        public void clear_model() {
            ((Gtk.ListStore) model).clear();
        }

        public void load_model() {
            var entry = (Gtk.Entry?) get_entry();
            if (entry == null || entry.text.length == 0) {
                return;
            }
            if (!Adore.Settings.get_default().enable_suggestions) {
                var list_store = (Gtk.ListStore) model;
                list_store.clear();
                var query = entry.text;
                if (!Adore.Util.Uri.is_valid(query) || !query.has_prefix("http")) {
                    Gtk.TreeIter iter;
                    list_store.append(out iter);
                    list_store.set(iter, 0, "URL", 1, Adore.Util.Uri.normalize(query));
                }
                return;
            }
            fetch_suggestions.begin(entry.text);
        }

        private async void fetch_suggestions(string query) {
            var list_store = (Gtk.ListStore) model;
            Gtk.TreeIter iter;

            // libsoup-3: Soup.Message constructor is the same
            var url = "https://suggestqueries.google.com/complete/search?client=firefox&q=%s"
                .printf(GLib.Uri.escape_string(query, null, true));

            var message = new Soup.Message("GET", url);

            try {
                // libsoup-3: use send_and_read_async instead of queue_message
                var bytes = yield session.send_and_read_async(
                    message, GLib.Priority.DEFAULT, null
                );

                if (message.status_code != 200) {
                    return;
                }

                var response = (string) bytes.get_data();
                if (response.length == 0) {
                    return;
                }

                list_store.clear();

                var parser = new Json.Parser();
                parser.load_from_data(response);

                var root = parser.get_root();
                if (root == null || root.get_node_type() != Json.NodeType.ARRAY) {
                    return;
                }

                var suggestion_array = root.get_array().get_element(1);
                if (suggestion_array.get_node_type() != Json.NodeType.ARRAY) {
                    return;
                }

                foreach (var node in suggestion_array.get_array().get_elements()) {
                    list_store.append(out iter);
                    list_store.set(iter, 0, "Google", 1, node.get_string());
                }
            } catch (Error e) {
                warning("Google suggestions fetch failed: %s", e.message);
            } finally {
                // Always offer URL/hostname as a completion option
                if (!Adore.Util.Uri.is_valid(query) || !query.has_prefix("http")) {
                    list_store.append(out iter);
                    list_store.set(iter, 0, "URL", 1, Adore.Util.Uri.normalize(query));
                }
            }
        }
    }
}
