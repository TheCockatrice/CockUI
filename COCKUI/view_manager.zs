// Simple base class for any view that manages other views seperate from the normal view hierarchy, such as layouts
class UIViewManager : UIView {
    enum ContentLayoutMode {
        Content_None        = 0,         // Content will be clipped to the layout
        Content_Stretch     = 1,         // Stretch or squash the contents of subviews equally to fill
        Content_SizeParent  = 2,         // Resize this container to fit the content
    }

    double itemSpacing;
    UIPadding padding;
    bool ignoreHiddenViews;
    ContentLayoutMode layoutMode;

    protected Array<UIView> managedViews, unmanagedViews;

    UIViewManager init(Vector2 pos, Vector2 size) {
        Super.init(pos, size);

        layoutWithChildren = true;
        
        return self;
    }

    override UIView baseInit() {
        Super.baseInit();
        
        layoutWithChildren = true;
        layoutMode = Content_None;

        return self;
    }

    override void applyTemplate(UIView template) {
        Super.applyTemplate(template);
        UIViewManager t = UIViewManager(template);

        if(t) {
            layoutWithChildren = t.layoutWithChildren;
            itemSpacing = t.itemSpacing;
            padding.left = t.padding.left;
            padding.right = t.padding.right;
            padding.top = t.padding.top;
            padding.bottom = t.padding.bottom;
            ignoreHiddenViews = t.ignoreHiddenViews;
            layoutMode = t.layoutMode;

            // Copy managed view indexes
            managedViews.clear();
            for(int i = 0; i < t.managedViews.size(); i++) {
                let idx = t.indexOf(t.managedViews[i]);
                managedViews.push(viewAt(idx));
            }

            // Copy unmanaged view indexes
            unmanagedViews.clear();
            for(int i = 0; i < t.unmanagedViews.size(); i++) {
                let idx = t.indexOf(t.unmanagedViews[i]);
                unmanagedViews.push(viewAt(idx));
            }
        }
    }

    void addManaged(UIView v) {
        Super.add(v);
        managedViews.push(v);
        requiresLayout = true;
    }

    void insertManaged(UIView v, int index) {
        Super.add(v);
        if(index < managedViews.size()) managedViews.insert(index, v);
        else managedViews.push(v);
    }

    virtual void removeManagedAt(int index, int count = 1) {
        for(int i = index + count - 1; i >= index; i--) {
            if(i < managedViews.size() && i >= 0) {
                UIView vv = managedViews[i];
                managedViews.delete(i);
                Super.removeView(vv);
                requiresLayout = true;
            }
        }
    }

    virtual int managedIndex(UIView subview) {
        for(int i = managedViews.size() - 1; i >= 0; i--) {
            if(managedViews[i] == subview) {
                return i;
            }            
        }

        return -1;
    }

    virtual void removeManaged(UIView v) {
        int i = managedViews.Find(v);
        if(i != managedViews.size()) {
            UIView vv = managedViews[i];
            managedViews.delete(i);
            Super.removeView(vv);
            requiresLayout = true;
        }
    }

    virtual void removeUnManaged(UIView v) {
        Super.removeView(v);
        int i = unmanagedViews.Find(v);
        if(i != unmanagedViews.size()) {
            unmanagedViews.delete(i);
        }
    }

    override void add(UIView v) {
        Super.add(v);

        unmanagedViews.push(v);
    }

    override void removeViewAt(int index) {
        UIView v = subviews[index];
        Super.removeViewAt(index);
        
        removeManaged(v);
        removeUnManaged(v);
    }

    override void layoutSubviews() {
        layingOutSubviews = true;
        layout();
        layingOutSubviews = false;
    }


    UIView getManaged(int i) {
        return managedViews[i];
    }

    int numManaged() {
        return managedViews.size();
    }

    virtual void clearManaged(bool destroy = true, UIRecycler recycler = null) {
        // Remove all managed views, not sure if calling Destroy() on them would be useful at this point
        if(!recycler) {
            UIMenu m = getMenu();
            recycler = m ? m.recycler : null;
        }

        while(managedViews.size() > 0) {
            UIView v = managedViews[0];
            removeView(v);

            if(destroy) { 
                v.teardown(recycler);
                v.Destroy();
            }
        }

        requiresLayout = true;
    }

    virtual void setPadding(double left = 0, double top = 0, double right = 0, double bottom = 0) {
        padding.left = left;
        padding.right = right;
        padding.top = top;
        padding.bottom = bottom;
        requiresLayout = true;
    }

    virtual UIView addSpacer(double size) {
        // Do nothing
        return null;
    }
}