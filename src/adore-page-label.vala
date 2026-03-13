namespace Adore {
    [GtkTemplate(ui = "/io/github/adore-browser/adore/ui/page-label.ui")]
    public class PageLabel : Gtk.Box {
        [GtkChild] public unowned Gtk.Image image;
        [GtkChild] protected unowned Gtk.Label caption;
        [GtkChild] protected unowned Gtk.Button close_button;

        public string text {
            get { return caption.label; }
            set {
                caption.label = value;
                caption.tooltip_text = value;
            }
        }

        public Gdk.Pixbuf icon {
            get {
                return image.get_pixbuf();
            }
            set {
                if (value == null) {
                    image.set_from_icon_name("text-html", Gtk.IconSize.SMALL_TOOLBAR);
                } else {
                    image.set_from_pixbuf(
                        value.scale_simple(ICON_SIZE, ICON_SIZE, Gdk.InterpType.BILINEAR)
                    );
                }
                notify_property("icon");
            }
        }

        public signal void close();

        construct {
            close_button.clicked.connect(() => close());
            icon = null;
        }
    }
}
