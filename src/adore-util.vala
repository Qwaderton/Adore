namespace Adore.Util {
    namespace Uri {
        // libsoup-3 dropped Soup.URI; we use GLib.Uri instead.
        public static bool is_valid(string uri) {
            if (!uri.contains(".") && !uri.has_prefix("about:") && !uri.has_prefix("file:")) {
                return false;
            }
            try {
                var parsed = GLib.Uri.parse(uri, GLib.UriFlags.NONE);
                var scheme = parsed.get_scheme();
                return scheme == "http" || scheme == "https" ||
                       scheme == "file" || scheme == "about" ||
                       scheme == "ftp";
            } catch {
                // Maybe it's a bare hostname like "example.com"
                // Accept if it looks like one (contains a dot, no spaces)
                return uri.contains(".") && !uri.contains(" ");
            }
        }

        public static string normalize(string text) {
            try {
                var parsed = GLib.Uri.parse(text, GLib.UriFlags.NONE);
                var scheme = parsed.get_scheme();
                if (scheme == "http" || scheme == "https" ||
                    scheme == "file" || scheme == "about" || scheme == "ftp") {
                    return text;
                }
            } catch {}
            // Treat as a hostname
            return "https://" + text;
        }
    }
}
