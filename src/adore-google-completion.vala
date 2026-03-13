namespace Adore {
    public class GoogleCompletion : Gtk.EntryCompletion {
        private Soup.Session     session;
        // Debounce: only fire the network request after the user pauses typing.
        private uint             _debounce_id   = 0;
        // Cancellable: cancel the in-flight request when a new one starts so
        // stale responses never overwrite fresher results.
        private GLib.Cancellable? _cancel        = null;

        public GoogleCompletion() {
            session = new Soup.Session();

            model       = new Gtk.ListStore(2, typeof(string), typeof(string));
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
            // Cancel any pending debounce and in-flight request
            if (_debounce_id != 0) {
                GLib.Source.remove(_debounce_id);
                _debounce_id = 0;
            }
            _cancel?.cancel();
            _cancel = null;
            ((Gtk.ListStore) model).clear();
        }

        public void load_model() {
            var entry = (Gtk.Entry?) get_entry();
            if (entry == null || entry.text.length == 0) {
                clear_model();
                return;
            }

            if (!Adore.Settings.get_default().enable_suggestions) {
                // Suggestions disabled: just offer a URL/search normalisation hint.
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

            // Debounce: wait 300 ms after the last keystroke before sending the request.
            if (_debounce_id != 0)
                GLib.Source.remove(_debounce_id);

            var query = entry.text;
            _debounce_id = GLib.Timeout.add(300, () => {
                _debounce_id = 0;
                fetch_suggestions.begin(query);
                return GLib.Source.REMOVE;
            });
        }

        private async void fetch_suggestions(string query) {
            var list_store = (Gtk.ListStore) model;

            // Cancel the previous request (if any) before starting a new one.
            _cancel?.cancel();
            _cancel = new GLib.Cancellable();
            var local_cancel = _cancel;

            var url = "https://suggestqueries.google.com/complete/search?client=firefox&q=%s"
                .printf(GLib.Uri.escape_string(query, null, true));

            var message = new Soup.Message("GET", url);

            try {
                var bytes = yield session.send_and_read_async(
                    message, GLib.Priority.DEFAULT, local_cancel);

                // Drop the result if this request was superseded.
                if (local_cancel.is_cancelled()) return;
                if (message.status_code != 200)  return;

                var response = (string) bytes.get_data();
                if (response.length == 0) return;

                list_store.clear();

                var parser = new Json.Parser();
                parser.load_from_data(response);

                var root = parser.get_root();
                if (root == null || root.get_node_type() != Json.NodeType.ARRAY)
                    return;

                var suggestion_array = root.get_array().get_element(1);
                if (suggestion_array.get_node_type() != Json.NodeType.ARRAY)
                    return;

                Gtk.TreeIter iter;
                foreach (var node in suggestion_array.get_array().get_elements()) {
                    list_store.append(out iter);
                    list_store.set(iter, 0, "Google", 1, node.get_string());
                }
            } catch (GLib.IOError.CANCELLED e) {
                return; // expected — don't log it
            } catch (Error e) {
                warning("Google suggestions fetch failed: %s", e.message);
            } finally {
                // Always append a normalised URL/hostname option at the bottom.
                if (!local_cancel.is_cancelled() &&
                    (!Adore.Util.Uri.is_valid(query) || !query.has_prefix("http"))) {
                    Gtk.TreeIter iter;
                    list_store.append(out iter);
                    list_store.set(iter, 0, "URL", 1, Adore.Util.Uri.normalize(query));
                }
            }
        }
    }
}
