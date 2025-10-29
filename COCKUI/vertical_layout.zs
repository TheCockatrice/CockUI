// Provides vertical layout of subviews and optionally sizes to fit contents vertically
class UIVerticalLayout : UIViewManager {
    UIVerticalLayout init(Vector2 pos, Vector2 size) {
        Super.init(pos, size);
        return self;
    }

    // This should be used sparingly and not for extremely large layouts
    override Vector2 calcMinSize(Vector2 parentSize) {
        Vector2 size = minSize;
        Vector2 pad = (padding.left + padding.right, padding.top + padding.bottom);
        Vector2 pSize = (MIN(parentSize.x - pad.x, maxSize.x), 999899);
        Vector2 totalSize = (0,0);

        for(int x = 0; x < managedViews.size(); x++) {
            if(ignoreHiddenViews && managedViews[x].hidden) continue;
            Vector2 s = managedViews[x].calcMinSize(pSize);
            totalSize.y += s.y;
            totalSize.x = MAX(s.x, totalSize.x);

            if(x > 0) totalSize.y += itemSpacing;
        }

        totalSize += pad;

        return (MIN(MAX(minSize.x, totalSize.x), maxSize.x), MIN(MAX(minSize.y, totalSize.y), maxSize.y));
    }

    override void layout(Vector2 parentScale, double parentAlpha, bool skipSubviews) {
        cScale = (parentScale ~== (0,0) ? calcScale() : (parentScale.x * scale.x, parentScale.y * scale.y));
        cAlpha = (parentAlpha == -1 ? calcAlpha() : parentAlpha) * alpha;

        // Process anchor pins
        if(!layingOutSubviews) processPins();
        if(skipSubviews) return;    // Nothing else to do

        
        frame.size.x -= padding.left + padding.right;
        layingOutSubviews = true;

        if(layoutMode == Content_Stretch) {
            // Determine amount of space used for static sized objects
            // And the total proportional weight
            double staticSize = 0;
            double totalSpacing = 0;
            double propoTotal = 0;

            for(int i = 0; i < managedViews.size(); i++) {
                if(ignoreHiddenViews && managedViews[i].hidden) continue;

                let managed = managedViews[i];
                managed.layout(cScale, cAlpha, skipSubviews: true);
                managed.frame.pos.x += padding.left;

                double ls = managed.getLayoutHeightAbsolute();
                double lso, propo;
                [propo, lso] = managed.getProportionalHeight();
                
                if(ls == -1) ls = 0;
                if(propo > -1) propoTotal += propo;
                if(lso > -1) ls += lso;
                staticSize += clamp(ls, managed.minSize.y, managed.maxSize.y);

                if(i > 0) totalSpacing += itemSpacing;
            }
            
            double ySpaceAvail = max(0, frame.size.y - staticSize - totalSpacing);

            // Layout each view, stretching/squashing proportional views to fit vertically
            for(int i = 0; i < managedViews.size(); i++) {
                if(ignoreHiddenViews && managedViews[i].hidden) continue;
                
                let managed = managedViews[i];
                
                double lso, propo;
                [propo, lso] = managed.getProportionalHeight();

                if(propo > 0) {
                    propo /= propoTotal;
                    managed.frame.size.y = propo * ySpaceAvail;
                    if(lso) managed.frame.size.y += lso;
                    managed.frame.size.y = clamp(managed.frame.size.y, managed.minSize.y, managed.maxSize.y);
                }

                // We skipped subviews before so lay them out now
                managed.layoutSubviews();

                if(developer > 1) managed.backgroundColor = Color(255, random(0, 255), random(127, 255), random(0, 255));
            }
        } else if(layoutMode == Content_SizeParent) {
            // Briefly fudge our height so auto sizing views work
            double oldHeight = frame.size.y;
            frame.size.y = 8888888;

            // Layout managed views
            for(int i = 0; i < managedViews.size(); i++) {
                managedViews[i].layout(cScale, cAlpha);
                managedViews[i].frame.pos.x += padding.left;
            }

            // Restore our fudge.
            frame.size.y = oldHeight;
        } else {
            // Layout managed views
            for(int i = 0; i < managedViews.size(); i++) {
                managedViews[i].layout(cScale, cAlpha);
                managedViews[i].frame.pos.x += padding.left;
            }
        }

        frame.size.x += padding.left + padding.right;

        // After laying out managed views we will rearrange them inside our container in order, adding spacing
        // One can only hope none of the subviews actually used vertical pinning for sizing, otherwise the subviews could be the full height of this container at the time of layout
        double ypos = arrangeManagedViews();
        if(layoutMode == Content_SizeParent) sizeToFitContents(ypos);

        // Now layout subviews
        for(int i = 0; i < unmanagedViews.size(); i++) {
            unmanagedViews[i].layout(cScale, cAlpha);
        }

        requiresLayout = false;
        layingOutSubviews = false;
    }


    override void layoutChildChanged(UIView subview) {
        if(layingOutSubviews) return;

        // If we already needed a full layout, do it now
        if(requiresLayout || layoutMode == Content_Stretch) {
            layout();
            return;
        }

        Vector2 oldSize = frame.size;

        // Process anchor pins
        processPins();

        // Briefly fudge our height so auto sizing views work
        double oldHeight = frame.size.y;
        if(layoutMode == Content_SizeParent) frame.size.y = 8888888;
        frame.size.x -= padding.left + padding.right;

        // Layout managed view first
        if(managedViews.find(subview) != managedViews.size()) {
            subview.layout(cScale, cAlpha);
            subview.frame.pos.x += padding.left;
        }

        // Restore our fudge.
        frame.size.y = oldHeight;
        frame.size.x += padding.left + padding.right;

        // After laying out managed views we will rearrange them inside our container in order, adding spacing
        double ypos = arrangeManagedViews();
        if(layoutMode == Content_SizeParent) sizeToFitContents(ypos);

        // Layout subviews if our size has changed
        if(!(frame.size ~== oldSize)) {
            for(int i = 0; i < unmanagedViews.size(); i++) {
                unmanagedViews[i].layout(cScale, cAlpha);
            }
        }
    }


    double arrangeManagedViews() {
        let ypos = padding.top;
        for(int x = 0; x < managedViews.size(); x++) {
            managedViews[x].frame.pos.y = ypos;
            if(!ignoreHiddenViews || !managedViews[x].hidden) {
                ypos += managedViews[x].frame.size.y + itemSpacing;
                managedViews[x].onAdjustedPostLayout(self);
            }
        }
        return ypos;
    }


    void sizeToFitContents(double contentBottom) {
        frame.size.y = MIN(maxSize.y, MAX(contentBottom - itemSpacing + padding.bottom, minSize.y));

        // Check for a VCenter Pin first
        let centerPin = firstPin(UIPin.Pin_VCenter);
        if(centerPin) {
            double center = centerPin.getParentPos(parent.frame.size) * centerPin.value + centerPin.offset;
            frame.pos.y = center - ((frame.size.y * scale.y) / 2.0);
        } else {
            // See if we have a bottom-pin that overrides the top pin
            let botPin = firstPin(UIPin.Pin_Bottom);
            let topPin = firstPin(UIPin.Pin_Top);
            if(botPin && (!topPin || topPin.priority < botPin.priority)) {
                // Process the bottom pin
                let bottom = botPin.isFactor ? botPin.getParentPos(parent.frame.size) * botPin.value + botPin.offset : botPin.getParentPos(parent.frame.size) + botPin.offset;
                frame.pos.y = bottom - frame.size.y;
            }
        }
    }


    override UIView addSpacer(double size) {
        let v = new("UIView").init((0,0), (1, size));
        v.pinHeight(size);
        v.minSize.y = size;
        addManaged(v);
        return v;
    }


    // Go through all managed views to find controls linkable for navigation
    virtual UIControl linkNavigation(UIControl upControl = null, UIControl downControl = null, UIControl leftControl = null, UIControl rightControl = null, bool deepSearch = false) {
        UIControl prevControl;

        foreach(sv : managedViews) {
            if(ignoreHiddenViews && sv.hidden) continue;

            // First, if this is another vertical layout manager, have it link its own controls
            UIVerticalLayout vlayout = UIVerticalLayout(sv);
            if(vlayout) {
                prevControl = vlayout.linkNavigation(upControl: prevControl, downControl: downControl, leftControl: leftControl, rightControl: rightControl, deepSearch: deepSearch);
                continue;
            }

            UIControl con = UIControl(sv);
            if(!con && deepSearch) {
                con = sv.getFirstControl(deep: true);
            }

            if(con) {
                if(prevControl) {
                    prevControl.navDown = con;
                    con.navUp = prevControl;
                } else if(upControl) {
                    con.navUp = upControl;
                    upControl.navDown = con;
                }

                prevControl = con;
                con.navLeft = leftControl;
                con.navRight = rightControl;
            }
        }

        if(prevControl && downControl) {
            prevControl.navDown = downControl;
            downControl.navUp = prevControl;
        }

        return prevControl;
    }
}