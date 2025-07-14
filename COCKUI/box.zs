struct UIBox {
    Vector2 pos;
    Vector2 size;

    Vector2 getBR() {
        return (pos.x + size.x, pos.y + size.y);
    }

    void copy(UIBox b) {
        pos = b.pos;
        size = b.size;
    }

    void setTRBL(double t, double r, double b, double l) {
        pos.x = l;
        pos.y = t;
        size.x = r - l;
        size.y = b - t;
    }

    bool intersect(out UIBox ret, UIBox b) {
		double left = max(pos.x, b.pos.x);
		double right = min(pos.x + size.x, b.pos.x + b.size.x);
		double top = max(pos.y, b.pos.y);
		double bottom = min(pos.y + size.y, b.pos.y + b.size.y);
		if (right - left > 0 && bottom - top > 0) {
			ret.pos = (left, top);
			ret.size = (right - left, bottom - top);
            return true;
		}
        ret.pos = (0,0);
        ret.size = (0,0);
		return false;
    }

    bool pointInside(Vector2 point) {
		return point.x > pos.x && point.x < pos.x + size.x && point.y > pos.y && point.y < pos.y + size.y;
	}
}


struct UIPadding {
    double left, top, right, bottom;

    void zero() {
        top = right = bottom = left = 0;
    }

    void set(double l, double t, double r, double b) {
        left = l;
        top = t;
        right = r;
        bottom = b;
    }
}