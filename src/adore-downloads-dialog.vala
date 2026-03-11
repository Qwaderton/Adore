namespace Adore {

    // ──────────────────────────────────────────────────────────────────────────
    // One row per download
    // ──────────────────────────────────────────────────────────────────────────
    public class DownloadRow : Gtk.ListBoxRow {
        public WebKit.Download download { get; construct; }
        public bool is_finished { get; private set; default = false; }

        private Gtk.Label       _name_label;
        private Gtk.Label       _status_label;
        private Gtk.ProgressBar _progress_bar;
        private Gtk.Button      _cancel_btn;
        private Gtk.Button      _open_btn;

        public DownloadRow(WebKit.Download dl) {
            Object(download: dl);
        }

        construct {
            var vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 2);
            vbox.margin = 8;

            var top = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);

            _name_label = new Gtk.Label("Downloading…");
            _name_label.halign    = Gtk.Align.START;
            _name_label.hexpand   = true;
            _name_label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            top.pack_start(_name_label, true, true, 0);

            _cancel_btn = new Gtk.Button.from_icon_name(
                "process-stop-symbolic", Gtk.IconSize.BUTTON);
            _cancel_btn.relief       = Gtk.ReliefStyle.NONE;
            _cancel_btn.tooltip_text = "Cancel download";
            _cancel_btn.clicked.connect(() => download.cancel());
            top.pack_start(_cancel_btn, false, false, 0);

            _open_btn = new Gtk.Button.from_icon_name(
                "document-open-symbolic", Gtk.IconSize.BUTTON);
            _open_btn.relief       = Gtk.ReliefStyle.NONE;
            _open_btn.tooltip_text = "Open file";
            _open_btn.no_show_all  = true;
            _open_btn.clicked.connect(on_open);
            top.pack_start(_open_btn, false, false, 0);

            _progress_bar = new Gtk.ProgressBar();
            _progress_bar.show_text = false;

            _status_label = new Gtk.Label("");
            _status_label.halign     = Gtk.Align.START;
            _status_label.use_markup = true;

            vbox.pack_start(top,           false, false, 0);
            vbox.pack_start(_progress_bar, false, false, 0);
            vbox.pack_start(_status_label, false, false, 0);
            add(vbox);
            show_all();

            update_name();
            download.notify["destination"].connect(update_name);
            download.notify["estimated-progress"].connect(on_progress);
            download.finished.connect(on_finished);
            download.failed.connect(on_failed);
        }

        private void update_name() {
            var dest = download.get_destination();
            if (dest != null && dest != "") {
                var unesc = GLib.Uri.unescape_string(dest) ?? dest;
                _name_label.label = GLib.Path.get_basename(unesc);
                return;
            }
            var req = download.get_request();
            if (req != null) {
                var url = req.get_uri();
                var idx = url.last_index_of("/");
                _name_label.label = (idx >= 0) ? url.substring(idx + 1) : url;
            }
        }

        private void on_progress() {
            double p = download.estimated_progress;
            _progress_bar.fraction = p;
            _status_label.label = "<small>%.0f %%</small>".printf(p * 100.0);
        }

        private void on_finished() {
            is_finished      = true;
            _progress_bar.fraction = 1.0;
            _status_label.label =
                "<small><span foreground=\"#2ec27e\">✓  Done</span></small>";
            _cancel_btn.hide();
            _open_btn.show();
        }

        private void on_failed(WebKit.Download dl, WebKit.DownloadError err) {
            is_finished = true;
            _status_label.label =
                "<small><span foreground=\"#e01b24\">✗  %s</span></small>"
                .printf(GLib.Markup.escape_text(err.message));
            _cancel_btn.hide();
        }

        private void on_open() {
            var dest = download.get_destination();
            if (dest != null) {
                try {
                    Gtk.show_uri(null, dest, Gdk.CURRENT_TIME);
                } catch (Error e) {
                    warning("Cannot open %s: %s", dest, e.message);
                }
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // The downloads window
    // ──────────────────────────────────────────────────────────────────────────
    public class DownloadsDialog : Gtk.Dialog {
        private Gtk.ListBox _list;

        public DownloadsDialog(Gtk.Window parent) {
            Object(
                title:          "Downloads",
                transient_for:  parent,
                modal:          false,
                use_header_bar: 1
            );
            set_default_size(420, 400);

            var clear_btn = new Gtk.Button.with_label("Clear finished");
            clear_btn.get_style_context().add_class("flat");
            clear_btn.clicked.connect(clear_finished);
            ((Gtk.HeaderBar) get_header_bar()).pack_start(clear_btn);

            var empty = new Gtk.Label("<i>No downloads yet</i>");
            empty.use_markup = true;
            empty.show();

            _list = new Gtk.ListBox();
            _list.selection_mode = Gtk.SelectionMode.NONE;
            _list.set_placeholder(empty);

            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            scroll.expand = true;
            scroll.add(_list);

            get_content_area().add(scroll);
            get_content_area().set_border_width(0);
            show_all();
        }

        public void add_download(WebKit.Download dl) {
            var row = new DownloadRow(dl);
            _list.prepend(row);
        }

        private void clear_finished() {
            foreach (var child in _list.get_children()) {
                var row = child as DownloadRow;
                if (row != null && row.is_finished) {
                    _list.remove(row);
                    row.destroy();
                }
            }
        }
    }
}
