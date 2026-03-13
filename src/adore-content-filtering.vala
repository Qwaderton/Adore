namespace Adore {

    // ─────────────────────────────────────────────────────────────────────────
    // ContentFilterManager – singleton
    // ─────────────────────────────────────────────────────────────────────────
    public class ContentFilterManager : Object {

        private static ContentFilterManager? _instance = null;

        private WebKit.UserContentManager?     _ucm   = null;
        private WebKit.UserContentFilterStore? _store = null;

        private KeyFile  _kf;
        private string   _kf_path;     // ~/.config/adore/filters.ini
        private string   _store_dir;   // ~/.local/share/adore/filter-store
        private string[] _urls;

        private Soup.Session _session;

        public static ContentFilterManager get_default() {
            if (_instance == null)
                _instance = new ContentFilterManager();
            return _instance;
        }

        private ContentFilterManager() {
            var config_dir = Path.build_filename(
                Environment.get_user_config_dir(), "adore");
            DirUtils.create_with_parents(config_dir, 0700);
            _kf_path = Path.build_filename(config_dir, "filters.ini");

            _store_dir = Path.build_filename(
                Environment.get_user_data_dir(), "adore", "filter-store");
            DirUtils.create_with_parents(_store_dir, 0700);

            _kf      = new KeyFile();
            _session = new Soup.Session();
            _urls    = {};

            load_config();
        }

        // ── Public API ────────────────────────────────────────────────────────

        public void attach(WebKit.UserContentManager ucm) {
            _ucm   = ucm;
            _store = new WebKit.UserContentFilterStore(_store_dir);
            reload_installed_filter();
        }

        public string get_urls_text() {
            return string.joinv("\n", _urls);
        }

        public async void set_urls_and_update(string text,
                                              owned UpdateCallback callback) {
            parse_urls(text);
            save_config();
            yield do_update(true, callback);
        }

        public async void update_if_needed(owned UpdateCallback? callback) {
            yield do_update(false, callback);
        }

        public delegate void UpdateCallback(bool ok, string status);

        // ── Config persistence ────────────────────────────────────────────────

        private void parse_urls(string text) {
            string[] result = {};
            foreach (var line in text.split("\n")) {
                var url = line.strip();
                if (url.length > 0)
                    result += url;
            }
            _urls = result;
        }

        private void load_config() {
            try { _kf.load_from_file(_kf_path, KeyFileFlags.NONE); } catch {}
            try { _urls = _kf.get_string_list("filters", "urls"); } catch { _urls = {}; }
        }

        private void save_config() {
            _kf.set_string_list("filters", "urls", _urls);
            try { _kf.save_to_file(_kf_path); } catch (Error e) {
                warning("filters: save config: %s", e.message);
            }
        }

        // ── Metadata (per-URL) ────────────────────────────────────────────────
        // Use a stable key derived from the full URL string instead of a 32-bit
        // hash, which has a meaningful collision probability when many lists are
        // configured.  We base64-encode the URL to keep it KeyFile-safe.
        private string meta_key(string url) {
            return "meta_" + GLib.Base64.encode(url.data).replace("=", "").replace("/", "_").replace("+", "-");
        }

        private string meta_last_modified(string url) {
            try { return _kf.get_string(meta_key(url), "last_modified"); } catch { return ""; }
        }
        private int meta_expires_days(string url) {
            try { return _kf.get_integer(meta_key(url), "expires_days"); } catch { return 0; }
        }
        private int64 meta_fetched_at(string url) {
            try { return _kf.get_int64(meta_key(url), "fetched_at"); } catch { return 0; }
        }

        private void save_meta(string url, string last_modified,
                               int expires_days, int64 fetched_at) {
            var key = meta_key(url);
            _kf.set_string (key, "last_modified", last_modified);
            _kf.set_integer(key, "expires_days",  expires_days);
            _kf.set_int64  (key, "fetched_at",    fetched_at);
            try { _kf.save_to_file(_kf_path); } catch {}
        }

        private bool is_expired(string url) {
            var fetched = meta_fetched_at(url);
            if (fetched == 0) return true;
            var expires = meta_expires_days(url);
            if (expires <= 0) return true;
            var age_days = (GLib.get_real_time() / 1000000 - fetched) / 86400;
            return age_days >= expires;
        }

        // ── Cache paths ───────────────────────────────────────────────────────
        // Use the same collision-free key as meta_key for file names.
        private string cache_path(string url) {
            var safe = GLib.Base64.encode(url.data)
                .replace("=", "").replace("/", "_").replace("+", "-");
            return Path.build_filename(_store_dir, "raw_%s.txt".printf(safe));
        }

        private string? load_cached_rules(string url) {
            try {
                string data;
                FileUtils.get_contents(cache_path(url), out data);
                return data;
            } catch { return null; }
        }

        private void save_cached_rules(string url, string body) {
            try { FileUtils.set_contents(cache_path(url), body); }
            catch (Error e) { warning("filters: cache write: %s", e.message); }
        }

        // ── Fetch + compile ───────────────────────────────────────────────────

        private async void do_update(bool force, UpdateCallback? callback) {
            if (_ucm == null) {
                if (callback != null) callback(false, "Not attached to WebKit yet.");
                return;
            }

            int fetched = 0, skipped = 0, failed = 0;
            var all_rules = new StringBuilder();

            foreach (var url in _urls) {
                string? body = null;

                if (!force && !is_expired(url)) {
                    var cached = load_cached_rules(url);
                    if (cached != null) {
                        append_rules(all_rules, cached);
                        skipped++;
                        continue;
                    }
                    // Cache file missing → fall through to fetch
                }

                body = yield fetch_url(url);
                if (body == null) {
                    var cached = load_cached_rules(url);
                    if (cached != null) append_rules(all_rules, cached);
                    failed++;
                    continue;
                }

                var last_mod  = parse_header(body, "Last modified") ?? meta_last_modified(url);
                var expires_d = parse_expires(body);
                save_meta(url, last_mod, expires_d, GLib.get_real_time() / 1000000);
                save_cached_rules(url, body);
                append_rules(all_rules, body);
                fetched++;
            }

            bool ok = false;
            if (_urls.length == 0) {
                _ucm.remove_all_filters();
                ok = true;
            } else if (all_rules.len > 0) {
                ok = yield compile_and_install(all_rules.str);
            }

            var status = "Updated: %d fetched, %d from cache, %d failed.".printf(
                fetched, skipped, failed);
            if (!ok && all_rules.len > 0)
                status += " (compilation failed — old filter still active)";

            if (callback != null) callback(ok || _urls.length == 0, status);
        }

        // Append rules text ensuring there is always a newline separator between
        // concatenated files, so the last line of one file never merges with the
        // first line of the next.
        private static void append_rules(StringBuilder sb, string body) {
            if (sb.len > 0 && sb.str[sb.len - 1] != '\n')
                sb.append_c('\n');
            sb.append(body);
        }

        private async string? fetch_url(string url) {
            try {
                var msg = new Soup.Message("GET", url);
                // Identify ourselves so CDNs don't block the request
                msg.request_headers.replace("User-Agent",
                    "Adore/" + Adore.APP_ID + " (content-filter-update)");
                var data = yield _session.send_and_read_async(
                    msg, GLib.Priority.DEFAULT, null);
                if (msg.status_code != 200) return null;
                return (string) data.get_data();
            } catch (Error e) {
                warning("filters: fetch %s: %s", url, e.message);
                return null;
            }
        }

        // ── WebKit compile + install ──────────────────────────────────────────

        private async bool compile_and_install(string rules_text) {
            var json = abp_to_webkit_json(rules_text);
            if (json == "") return false;

            var bytes = new GLib.Bytes(json.data);
            bool ok   = false;
            try {
                var filter = yield _store.save("adore-main", bytes, null);
                _ucm.remove_all_filters();
                _ucm.add_filter(filter);
                ok = true;
            } catch (Error e) {
                warning("filters: WebKit compile: %s", e.message);
                reload_installed_filter();   // keep old filter alive
            }
            return ok;
        }

        private void reload_installed_filter() {
            if (_store == null || _ucm == null) return;
            _store.load.begin("adore-main", null, (obj, res) => {
                try {
                    var f = _store.load.end(res);
                    _ucm.remove_all_filters();
                    _ucm.add_filter(f);
                } catch { /* no stored filter yet */ }
            });
        }

        // ── ABP/uBlock → WebKit Content Blocker JSON ──────────────────────────

        private static string abp_to_webkit_json(string rules_text) {
            var sb    = new StringBuilder("[\n");
            bool first = true;

            foreach (var raw_line in rules_text.split("\n")) {
                var line = raw_line.strip();
                if (line.length == 0 || line[0] == '!' || line[0] == '[')
                    continue;

                string? entry = null;

                if ("##" in line && !line.has_prefix("@@") && !line.has_prefix("||")) {
                    // Cosmetic rule: [domain(s)]##selector
                    var parts    = line.split("##", 2);
                    var selector = parts[1].strip();
                    if (selector.length == 0) continue;
                    // Skip cosmetic exception rules (#@#)
                    if (selector.has_prefix("@")) continue;
                    var sel_esc  = selector.replace("\\", "\\\\").replace("\"", "\\\"");
                    entry = "  {\"trigger\":{\"url-filter\":\".*\"},\"action\":{\"type\":\"css-display-none\",\"selector\":\"%s\"}}".printf(sel_esc);

                } else if (line.has_prefix("@@||")) {
                    // Whitelist network rule
                    var domain  = extract_domain(line.substring(4));
                    if (domain.length == 0) continue;
                    var escaped = Regex.escape_string(domain).replace("/", "\\/");
                    entry = "  {\"trigger\":{\"url-filter\":\"^[a-z]+:\\/\\/([^/]*\\.)?%s\"},\"action\":{\"type\":\"ignore-previous-rules\"}}".printf(escaped);

                } else if (line.has_prefix("||")) {
                    // Block network rule anchored to host
                    var domain  = extract_domain(line.substring(2));
                    if (domain.length == 0) continue;
                    var escaped = Regex.escape_string(domain).replace("/", "\\/");
                    entry = "  {\"trigger\":{\"url-filter\":\"^[a-z]+:\\/\\/([^/]*\\.)?%s\"},\"action\":{\"type\":\"block\"}}".printf(escaped);

                } else if (!line.has_prefix("@@") && !("##" in line)) {
                    // Plain substring/pattern rule (no cosmetic, no whitelist)
                    var pattern = line.split("$")[0].strip();
                    if (pattern.length < 4) continue;  // too generic
                    var escaped = Regex.escape_string(pattern).replace("/", "\\/");
                    entry = "  {\"trigger\":{\"url-filter\":\"%s\"},\"action\":{\"type\":\"block\"}}".printf(escaped);
                }

                if (entry != null) {
                    if (!first) sb.append(",\n");
                    sb.append(entry);
                    first = false;
                }
            }

            sb.append("\n]");
            return first ? "" : sb.str;
        }

        private static string extract_domain(string raw) {
            return raw.replace("^", "").split("$")[0].split("/")[0].strip();
        }

        // ── Header parsers ────────────────────────────────────────────────────

        private static string? parse_header(string body, string key) {
            var prefix = ("! " + key + ":").down();
            foreach (var line in body.split("\n")) {
                if (line.down().has_prefix(prefix))
                    return line.substring(prefix.length).strip();
            }
            return null;
        }

        private static int parse_expires(string body) {
            var raw = parse_header(body, "Expires");
            if (raw == null) return 0;
            return int.parse(raw.split(" ")[0]);
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FilteringDialog – GTK dialog
    // ─────────────────────────────────────────────────────────────────────────
    public class FilteringDialog : Gtk.Dialog {

        private Gtk.TextView _url_view;
        private Gtk.Label    _status_label;
        private Gtk.Button   _update_btn;
        private Gtk.Spinner  _spinner;

        public FilteringDialog(Gtk.Window parent) {
            Object(
                title:          "Content Filtering",
                transient_for:  parent,
                modal:          true,
                use_header_bar: 1
            );
            set_default_size(520, 340);
            build_ui();
            delete_event.connect(() => { hide(); return true; });
        }

        private void build_ui() {
            var content = get_content_area();
            content.spacing = 0;

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 8);
            box.margin = 12;
            content.pack_start(box, true, true, 0);

            var lbl = new Gtk.Label(
                "<b>Filter list URLs</b>  <small>(one per line)</small>");
            lbl.use_markup = true;
            lbl.halign = Gtk.Align.START;
            box.pack_start(lbl, false, false, 0);

            _url_view = new Gtk.TextView();
            _url_view.wrap_mode     = Gtk.WrapMode.NONE;
            _url_view.monospace     = true;
            _url_view.top_margin    = 6;
            _url_view.bottom_margin = 6;
            _url_view.left_margin   = 6;
            _url_view.right_margin  = 6;

            var scroll = new Gtk.ScrolledWindow(null, null);
            scroll.vexpand     = true;
            scroll.hexpand     = true;
            scroll.shadow_type = Gtk.ShadowType.IN;
            scroll.add(_url_view);
            box.pack_start(scroll, true, true, 0);

            var hint = new Gtk.Label(
                "<small>Supports Adblock Plus / uBlock Origin .txt lists.\n" +
                "Lists are refreshed automatically when they expire.</small>");
            hint.use_markup = true;
            hint.halign = Gtk.Align.START;
            hint.wrap   = true;
            box.pack_start(hint, false, false, 0);

            var status_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            _spinner = new Gtk.Spinner();
            _spinner.no_show_all = true;
            status_box.pack_start(_spinner, false, false, 0);
            _status_label = new Gtk.Label("");
            _status_label.halign    = Gtk.Align.START;
            _status_label.ellipsize = Pango.EllipsizeMode.END;
            status_box.pack_start(_status_label, true, true, 0);
            box.pack_start(status_box, false, false, 0);

            add_button("Cancel", Gtk.ResponseType.CANCEL);
            _update_btn = (Gtk.Button) add_button("Update lists", Gtk.ResponseType.APPLY);
            _update_btn.get_style_context().add_class("suggested-action");

            response.connect(on_response);

            _url_view.buffer.text =
                ContentFilterManager.get_default().get_urls_text();

            content.show_all();
            _spinner.hide();
        }

        private void on_response(int id) {
            if (id == Gtk.ResponseType.APPLY) {
                start_update();
            } else {
                hide();
            }
        }

        private void start_update() {
            _update_btn.sensitive = false;
            _spinner.show();
            _spinner.start();
            _status_label.label = "Updating…";

            var text = _url_view.buffer.text;
            ContentFilterManager.get_default().set_urls_and_update.begin(
                text,
                (ok, status) => {
                    _spinner.stop();
                    _spinner.hide();
                    _update_btn.sensitive = true;
                    _status_label.label   = status;
                }
            );
        }
    }
}
