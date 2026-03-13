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

        // Related views (window.open / middle-click) must share the same
        // UserContentManager so content filters apply to them too.
        public WebPage.as_related(WebKit.WebView parent, Adore.Application application) {
            Object(
                related_view:          parent,
                user_content_manager:  application.user_content_manager
            );
            set_settings(application.web_settings);
            _label = new Adore.PageLabel();
            init_signals();
        }

        public WebPage.with_label(Adore.Application application, Adore.PageLabel label) {
            Object(
                web_context:           application.web_context,
                user_content_manager:  application.user_content_manager
            );
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
                    var ctx = new Cairo.Context(surface);
                    double x1, y1, x2, y2;
                    ctx.clip_extents(out x1, out y1, out x2, out y2);
                    int w = (int)(x2 - x1);
                    int h = (int)(y2 - y1);
                    if (w > 0 && h > 0) {
                        var pixbuf = Gdk.pixbuf_get_from_surface(surface, 0, 0, w, h);
                        if (pixbuf != null) {
                            _label.icon = pixbuf;
                            return;
                        }
                    }
                }
                _label.icon = null;
            });
        }
    }
}
