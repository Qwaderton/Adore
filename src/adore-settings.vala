namespace Adore {
    public class Settings : Object {
        private static Settings? _instance = null;
        private KeyFile keyfile;
        private string config_path;

        // Прокси
        public enum ProxyType {
            NONE,
            SYSTEM,
            HTTP,
            HTTPS,
            SOCKS4,
            SOCKS5
        }

        public ProxyType proxy_type    { get; set; default = ProxyType.SYSTEM; }
        public string   proxy_host     { get; set; default = ""; }
        public int      proxy_port     { get; set; default = 8080; }
        public string   proxy_username { get; set; default = ""; }
        public string   proxy_password { get; set; default = ""; }

        // JavaScript
        public bool enable_javascript  { get; set; default = true; }

        // Homepage
        public string homepage         { get; set; default = "https://www.protopage.com/adorefoss"; }
        public string search_engine_url { get; set; default = "https://www.google.com/search?q=%s"; }
        public bool   enable_suggestions { get; set; default = true; }

        public static Settings get_default() {
            if (_instance == null) {
                _instance = new Settings();
            }
            return _instance;
        }

        private Settings() {
            keyfile = new KeyFile();

            var config_dir = Path.build_filename(
                Environment.get_user_config_dir(), "adore"
            );
            DirUtils.create_with_parents(config_dir, 0700);
            config_path = Path.build_filename(config_dir, "settings.ini");

            load();
        }

        private void load() {
            try {
                keyfile.load_from_file(config_path, KeyFileFlags.NONE);
            } catch (Error e) {
                // The file doesn't exist yet — it's fine
                return;
            }

            try {
                proxy_type = (ProxyType) keyfile.get_integer("proxy", "type");
            } catch {}
            try { proxy_host     = keyfile.get_string ("proxy", "host");     } catch {}
            try { proxy_port     = keyfile.get_integer("proxy", "port");     } catch {}
            try { proxy_username = keyfile.get_string ("proxy", "username"); } catch {}
            try { proxy_password = keyfile.get_string ("proxy", "password"); } catch {}

            try { enable_javascript = keyfile.get_boolean("web", "javascript"); } catch {}
            try { homepage          = keyfile.get_string ("web", "homepage");   } catch {}
            try { search_engine_url  = keyfile.get_string ("web", "search_engine_url");  } catch {}
            try { enable_suggestions = keyfile.get_boolean("web", "enable_suggestions"); } catch {}
        }

        public void save() {
            keyfile.set_integer("proxy", "type",     (int) proxy_type);
            keyfile.set_string ("proxy", "host",     proxy_host);
            keyfile.set_integer("proxy", "port",     proxy_port);
            keyfile.set_string ("proxy", "username", proxy_username);
            keyfile.set_string ("proxy", "password", proxy_password);

            keyfile.set_boolean("web", "javascript", enable_javascript);
            keyfile.set_string ("web", "homepage",   homepage);
            keyfile.set_string ("web", "search_engine_url",  search_engine_url);
            keyfile.set_boolean("web", "enable_suggestions", enable_suggestions);

            try {
                keyfile.save_to_file(config_path);
            } catch (Error e) {
                warning("Couldn't save settings: %s", e.message);
            }
        }

        // Apply proxy to WebContext
        public void apply_proxy(WebKit.WebContext context) {
            if (proxy_type == ProxyType.NONE) {
                context.set_network_proxy_settings(
                    WebKit.NetworkProxyMode.NO_PROXY, null
                );
                return;
            }
            if (proxy_type == ProxyType.SYSTEM) {
                context.set_network_proxy_settings(
                    WebKit.NetworkProxyMode.DEFAULT, null
                );
                return;
            }

            string scheme;
            switch (proxy_type) {
                case ProxyType.SOCKS4: scheme = "socks4"; break;
                case ProxyType.SOCKS5: scheme = "socks5"; break;
                case ProxyType.HTTPS:  scheme = "https";  break;
                default:               scheme = "http";   break;
            }

            string uri;
            if (proxy_username != "" && proxy_password != "") {
                uri = "%s://%s:%s@%s:%d".printf(
                    scheme, proxy_username, proxy_password, proxy_host, proxy_port
                );
            } else {
                uri = "%s://%s:%d".printf(scheme, proxy_host, proxy_port);
            }

            var proxy_settings = new WebKit.NetworkProxySettings(uri, null);
            context.set_network_proxy_settings(
                WebKit.NetworkProxyMode.CUSTOM, proxy_settings
            );
        }

        // Apply JS settings to WebKit.Settings
        public void apply_web_settings(WebKit.Settings web_settings) {
            web_settings.enable_javascript = enable_javascript;
        }
    }
}
