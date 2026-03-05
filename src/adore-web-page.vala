namespace Adore {
    public class WebPage : WebKit.WebView, Adore.Page {
        private Adore.PageLabel _label;

        public Adore.PageLabel label {
            get { return _label; }
            set { _label = value; }
        }

        public WebPage(Adore.Application application) {
            this.with_label(application, new Adore.PageLabel());
        }

        public WebPage.as_related(WebKit.WebView parent, Adore.Application application) {
            Object(related_view: parent);
            set_settings(application.web_settings);
            _label = new Adore.PageLabel();
            init_signals();
        }

        public WebPage.with_label(Adore.Application application, Adore.PageLabel label) {
            Object(web_context: application.web_context);
            set_settings(application.web_settings);
            _label = label;
            init_signals();
        }

        private void init_signals() {
            notify["title"].connect(() => {
                if (title != null && title.length > 0) {
                    _label.text = title;
                }
            });

            notify["favicon"].connect(() => {
                var surface = get_favicon();
                if (surface != null) {
                    double width, height;
                    var ctx = new Cairo.Context(surface);
                    ctx.clip_extents(null, null, out width, out height);
                    var pixbuf = Gdk.pixbuf_get_from_surface(
                        surface, 0, 0, (int) width, (int) height
                    );
                    if (pixbuf != null) {
                        _label.icon = pixbuf.scale_simple(
                            ICON_SIZE, ICON_SIZE, Gdk.InterpType.BILINEAR
                        );
                    }
                } else {
                    _label.icon = null;
                }
            });
        }
    }
}
