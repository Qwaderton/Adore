namespace Adore.Util {
    namespace Uri {
        public static bool is_valid(string uri) {
            if (uri.contains(" ")) return false;

            try {
                var parsed = GLib.Uri.parse(uri, GLib.UriFlags.NONE);
                var scheme = parsed.get_scheme();
                return scheme == "http"  || scheme == "https" ||
                    scheme == "file"  || scheme == "about" ||
                    scheme == "ftp";
            } catch {}

            if (uri.has_prefix("about:") || uri.has_prefix("file:")) return true;

            var host_and_port = uri.split("/")[0];
            var host = host_and_port.split(":")[0];

            if (host == "localhost") return true;

            if (!host.contains(".")) return false;

            var parts = host.split(".");
            if (parts.length < 2) return false;
            var tld = parts[parts.length - 1];
            if (tld.length == 0) return false;

            bool all_digits = true;
            bool has_alpha  = false;
            for (int i = 0; i < tld.length; i++) {
                if (!tld[i].isdigit()) all_digits = false;
                if (tld[i].isalpha())  has_alpha  = true;
            }
            return all_digits || has_alpha;
        }

        public static string normalize(string text) {
            try {
                var parsed = GLib.Uri.parse(text, GLib.UriFlags.NONE);
                var scheme = parsed.get_scheme();
                if (scheme == "http"  || scheme == "https" ||
                    scheme == "file"  || scheme == "about" ||
                    scheme == "ftp") {
                    return text;
                }
            } catch {}
            return "https://" + text;
        }
    }
}
