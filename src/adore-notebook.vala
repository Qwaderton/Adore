namespace Adore {
    [GtkTemplate(ui = "/io/github/adore-browser/adore/ui/notebook.ui")]
    public class Notebook : Gtk.Notebook {
        [GtkChild] public unowned Gtk.Button new_page_button;
        public bool can_go_back { get; private set; }
        public bool can_go_forward { get; private set; }
        public Gdk.Pixbuf icon { get; private set; }
        public string title { get; private set; }
        public string uri { get; private set; }
        public double progress { get; private set; }

        // Tracks the page whose signals are currently connected, so we can
        // cleanly disconnect before switching — avoids the double get_current_page()
        // call and the null deref when there is no current page yet.
        private Adore.Page? _connected_page = null;

        construct {
            group_name = "adore";

            page_added.connect((child, page_num) => {
                var pg = (Adore.Page) child;
                this.set_tab_reorderable(pg, true);
                this.set_tab_detachable(pg, true);

                pg.label.close.connect(() => {
                    int n = this.page_num(pg);
                    if (n >= 0) {
                        this.remove_page(n);
                        pg.destroy();
                    }
                });
            });

            switch_page.connect((child, page_num) => {
                if (_connected_page != null) {
                    disconnect_page_signals(_connected_page);
                    _connected_page = null;
                }
                var new_page = (Adore.WebPage) child;
                _connected_page = new_page;
                connect_page_signals(new_page);

                title    = new_page.label.text;
                icon     = new_page.label.icon;
                uri      = new_page.uri ?? "";
                progress = new_page.is_loading ? new_page.estimated_load_progress : 0;
                can_go_back    = new_page.can_go_back();
                can_go_forward = new_page.can_go_forward();
            });
        }

        protected void connect_page_signals(Adore.Page pg) {
            pg.label.notify["text"].connect(update_title);
            pg.label.notify["icon"].connect(update_icon);
            pg.notify["uri"].connect(update_uri);
            pg.notify["estimated-load-progress"].connect(update_progress);
            pg.notify["is-loading"].connect(update_progress);
        }

        protected void disconnect_page_signals(Adore.Page pg) {
            pg.label.notify["text"].disconnect(update_title);
            pg.label.notify["icon"].disconnect(update_icon);
            pg.notify["uri"].disconnect(update_uri);
            pg.notify["estimated-load-progress"].disconnect(update_progress);
            pg.notify["is-loading"].disconnect(update_progress);
        }

        public new Adore.Page get_nth_page(int page_num) {
            return (Adore.Page) base.get_nth_page(page_num);
        }

        public new int append_page(Adore.Page pg) {
            return base.append_page(pg, pg.label);
        }

        public new int insert_page(Adore.Page pg, int position) {
            return base.insert_page(pg, pg.label, position);
        }

        // All update_* callbacks guard against an empty notebook (page == -1).
        protected void update_icon() {
            if (_connected_page == null) return;
            icon = _connected_page.label.icon;
        }

        protected void update_title() {
            if (_connected_page == null) return;
            title = _connected_page.label.text;
        }

        protected void update_uri() {
            if (_connected_page == null) return;
            var web_page = (Adore.WebPage) _connected_page;
            uri = web_page.uri ?? "";
            can_go_back    = web_page.can_go_back();
            can_go_forward = web_page.can_go_forward();
        }

        protected void update_progress() {
            if (_connected_page == null) return;
            var web_page = (Adore.WebPage) _connected_page;
            progress       = web_page.is_loading ? web_page.estimated_load_progress : 0;
            can_go_back    = web_page.can_go_back();
            can_go_forward = web_page.can_go_forward();
        }

        public void go_back() {
            if (page >= 0)
                ((Adore.WebPage) get_nth_page(page)).go_back();
        }

        public void go_forward() {
            if (page >= 0)
                ((Adore.WebPage) get_nth_page(page)).go_forward();
        }

        public void reload() {
            if (page >= 0)
                ((Adore.WebPage) get_nth_page(page)).reload();
        }

        public void stop_loading() {
            if (page >= 0)
                ((Adore.WebPage) get_nth_page(page)).stop_loading();
        }
    }
}
