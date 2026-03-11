namespace Adore {

    // ──────────────────────────────────────────────────────────────────────────
    // Bookmark store — reads/writes a plain text file (title\turl per line)
    // ──────────────────────────────────────────────────────────────────────────
    public class BookmarkStore : Object {
        private static BookmarkStore? _instance = null;
        private string _path;

        public struct Entry {
            public string title;
            public string url;
        }

        private Gee.ArrayList<Entry?> _entries;

        public static BookmarkStore get_default() {
            if (_instance == null) _instance = new BookmarkStore();
            return _instance;
        }

        private BookmarkStore() {
            var dir = Path.build_filename(
                Environment.get_user_data_dir(), "adore");
            DirUtils.create_with_parents(dir, 0700);
            _path = Path.build_filename(dir, "bookmarks.tsv");
            _entries = new Gee.ArrayList<Entry?>();
            load();
        }

        public Gee.ArrayList<Entry?> entries { get { return _entries; } }

        public void add(string title, string url) {
            // Avoid exact duplicates
            foreach (var e in _entries) {
                if (e.url == url) return;
            }
            Entry ent = { title, url };
            _entries.add(ent);
            save();
            changed();
        }

        public void remove_at(int index) {
            if (index >= 0 && index < _entries.size) {
                _entries.remove_at(index);
                save();
                changed();
            }
        }

        public bool contains(string url) {
            foreach (var e in _entries)
                if (e.url == url) return true;
            return false;
        }

        public signal void changed();

        private void load() {
            try {
                string content;
                FileUtils.get_contents(_path, out content);
                foreach (var line in content.split("\n")) {
                    if (line.strip() == "") continue;
                    var parts = line.split("\t", 2);
                    if (parts.length == 2) {
                        Entry e = { parts[0], parts[1] };
                        _entries.add(e);
                    }
                }
            } catch { /* file doesn't exist yet */ }
        }

        private void save() {
            var sb = new StringBuilder();
            foreach (var e in _entries) {
                sb.append(e.title);
                sb.append_c('\t');
                sb.append(e.url);
                sb.append_c('\n');
            }
            try {
                FileUtils.set_contents(_path, sb.str);
            } catch (Error e) {
                warning("Bookmarks save error: %s", e.message);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Bookmarks manager window
    // ──────────────────────────────────────────────────────────────────────────
    public class BookmarksDialog : Gtk.Dialog {
        private Gtk.ListBox _list;
        private BookmarkStore _store;

        public signal void open_url(string url);

        public BookmarksDialog(Gtk.Window parent) {
            Object(
                title:          "Bookmarks",
                transient_for:  parent,
                modal:          false,
                use_header_bar: 1
            );
            set_default_size(480, 440);

            _store = BookmarkStore.get_default();

            var empty = new Gtk.Label("<i>No bookmarks yet</i>");
            empty.use_markup = true;
            empty.show();

            _list = new Gtk.ListBox();
            _list.selection_mode = Gtk.SelectionMode.SINGLE;
            _list.set_placeholder(empty);
            _list.row_activated.connect(on_row_activated);

            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroll.expand = true;
            scroll.add(_list);

            get_content_area().add(scroll);
            get_content_area().set_border_width(0);

            populate();
            _store.changed.connect(populate);

            show_all();
        }

        private void populate() {
            // Clear
            foreach (var child in _list.get_children()) {
                _list.remove(child);
                child.destroy();
            }
            var entries = _store.entries;
            for (int i = 0; i < entries.size; i++) {
                var e = entries.get(i);
                add_row(e.title, e.url, i);
            }
        }

        private void add_row(string title, string url, int index) {
            var row = new Gtk.ListBoxRow();

            var hbox = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            hbox.margin = 6;

            // Favicon placeholder
            var icon = new Gtk.Image.from_icon_name(
                "user-bookmarks-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            hbox.pack_start(icon, false, false, 0);

            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            var title_lbl = new Gtk.Label(title);
            title_lbl.halign    = Gtk.Align.START;
            title_lbl.hexpand   = true;
            title_lbl.ellipsize = Pango.EllipsizeMode.END;

            var url_lbl = new Gtk.Label("<small>%s</small>"
                .printf(GLib.Markup.escape_text(url)));
            url_lbl.halign     = Gtk.Align.START;
            url_lbl.use_markup = true;
            url_lbl.ellipsize  = Pango.EllipsizeMode.END;
            url_lbl.get_style_context().add_class("dim-label");

            vbox.pack_start(title_lbl, false, false, 0);
            vbox.pack_start(url_lbl,   false, false, 0);
            hbox.pack_start(vbox, true, true, 0);

            // Delete button
            var del_btn = new Gtk.Button.from_icon_name(
                "edit-delete-symbolic", Gtk.IconSize.BUTTON);
            del_btn.relief       = Gtk.ReliefStyle.NONE;
            del_btn.tooltip_text = "Remove bookmark";
            int captured_index = index;
            del_btn.clicked.connect(() => {
                _store.remove_at(captured_index);
            });
            hbox.pack_start(del_btn, false, false, 0);

            row.add(hbox);
            row.set_data<string>("url", url);
            row.show_all();
            _list.add(row);
        }

        private void on_row_activated(Gtk.ListBoxRow row) {
            var url = row.get_data<string>("url");
            if (url != null) {
                open_url(url);
            }
        }
    }
}
