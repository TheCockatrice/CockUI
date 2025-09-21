// Responsible for storing ultra-basic auto layout functions
class UIPin {
    enum PinAnchor {
        Pin_Left = 0,
        Pin_Right,
        Pin_Top,
        Pin_Bottom,
        Pin_HCenter,
        Pin_VCenter,
        Pin_Static      // Only used for static width/height, ignored on normal pins
    }

    bool isFactor;
    double value, offset;
    int priority;
    PinAnchor parentAnchor, anchor;

    double getParentPos(Vector2 parentSize) {
        switch(parentAnchor) {
            case Pin_Bottom:
                return parentSize.y;
            case Pin_Right:
                return parentSize.x;
            case Pin_HCenter:
                return parentSize.x / 2.0;
            case Pin_VCenter:
                return parentSize.y / 2.0;
            default:
                break;
        }

        return 0;
    }

    // Copy properties from another UIPin
    void copyFrom(UIPin other) {
        anchor = other.anchor;
        parentAnchor = other.parentAnchor;
        value = other.value;
        offset = other.offset;
        isFactor = other.isFactor;
        priority = other.priority;
    }

    static UIPin Create(int anchor = 0, int parentAnchor = 0, double value = 0, double offset = 0, bool isFactor = false, int priority = 0) {
        let p = new("UIPin");
        p.anchor = anchor;
        p.parentAnchor = parentAnchor;
        p.value = value;
        p.offset = offset;
        p.isFactor = isFactor;
        p.priority = priority;

        return p;
    }
}


class ViewEvent ui {
	int Type;
	String KeyString;
	int KeyChar;
	int MouseX;
	int MouseY;
	bool IsShift;
	bool IsCtrl;
	bool IsAlt;

	static void fromGZDUiEvent(UiEvent gzdEv, ViewEvent ev) {
		ev.Type = gzdEv.Type;
		ev.KeyString = gzdEv.KeyString;
		ev.KeyChar = gzdEv.KeyChar;
		ev.MouseX = gzdEv.MouseX;
		ev.MouseY = gzdEv.MouseY;
		ev.IsShift = gzdEv.IsShift;
		ev.IsCtrl = gzdEv.IsCtrl;
		ev.IsAlt = gzdEv.IsAlt;
	}
}



class UIView ui {
    enum Alignment {
        Align_Left        = 1 << 1,
        Align_Right       = 1 << 2,
        Align_Top         = 1 << 3,
        Align_Bottom      = 1 << 4,
        Align_Center      = 1 << 5,     // Horizontal
        Align_Middle      = 1 << 6,     // Vertical

        // Convenience
        Align_Centered      = (Align_Center | Align_Middle),
        Align_TopLeft       = (Align_Top    | Align_Left),
        Align_TopRight      = (Align_Top    | Align_Right),
        Align_BottomLeft    = (Align_Bottom | Align_Left),
        Align_BottomRight   = (Align_Bottom | Align_Right),

        Align_VCenter = Align_Middle,   // What was I doing when I named these
        Align_HCenter = Align_Center
    }

    const Size_Min            = double(-9999991);
    const Size_Max            = double(9999991);

    UIBox frame;
    UIView parent;
    UIView forwardSelection;            // Forward selection events from menu to this view
    UIMenu parentMenu;

    Color backgroundColor;
    bool hidden, raycastTarget, eventsEnabled, clipsSubviews, ignoresClipping, dragTarget;
    bool cancelsSubviewRaycast;         // Will not raycast to subviews
    bool requiresLayout;                // Will layout before next Draw()
    bool layoutWithChildren;            // If turned on, call layout() on this view when children require layout 
    bool drawSubviewsFirst;
    bool layingOutSubviews;             // Used to prevent layout loops when laying out subviews
    double alpha, angle;
    Vector2 scale, rotCenter;

    int cStencil;     // Calculated stencil level during draw, should be 0 at other times
    double cAlpha;    // Calculated alpha during Layout()
    Vector2 cScale;   // Calculated scale during Layout()

    protected Array<UIView> subviews;
    protected UIView mask;

    Array<UIPin> pins;
    UIPin widthPin, heightPin;
    Vector2 minSize, maxSize;               // Used only when calculating pins or automatic sizing
    Canvas drawCanvas;

    const invalid = double(9999999);

    static UIView Create(Vector2 pos, Vector2 size) {
        return new('UIView').Init(pos, size);
    }

    UIView init(Vector2 pos = (0,0), Vector2 size = (100, 100)) {
        frame.pos = pos;
        frame.size = size;
        alpha = 1;
        scale = (1,1);
        rotCenter = (0.5, 0.5);
        maxSize = (99999, 99999);
        clipsSubviews = true;
        requiresLayout = true;
        raycastTarget = true;

        return self;
    }

    virtual UIView clone() {
        UIView newView = UIView(new(getClass()));
        newView.baseInit();
        newView.applyTemplate(self);
        return newView;
    }

    // Minimum initialization, used to prepare the view for deserialization
    virtual UIView baseInit() {
        alpha = 1;
        scale = (1,1);
        rotCenter = (0.5, 0.5);
        maxSize = (99999, 99999);
        clipsSubviews = true;
        requiresLayout = true;
        raycastTarget = true;

        return self;
    }

    // Copy the properties of another UIView
    virtual void applyTemplate(UIView template) {
        frame.pos = template.frame.pos;
        frame.size = template.frame.size;
        backgroundColor = template.backgroundColor;
        hidden = template.hidden;
        raycastTarget = template.raycastTarget;
        eventsEnabled = template.eventsEnabled;
        clipsSubviews = template.clipsSubviews;
        ignoresClipping = template.ignoresClipping;
        dragTarget = template.dragTarget;
        cancelsSubviewRaycast = template.cancelsSubviewRaycast;
        layoutWithChildren = template.layoutWithChildren;
        drawSubviewsFirst = template.drawSubviewsFirst;
        alpha = template.alpha;
        angle = template.angle;
        scale = template.scale;
        rotCenter = template.rotCenter;
        cAlpha = 0;
        cScale = (0,0);
        minSize = template.minSize;
        maxSize = template.maxSize;
        requiresLayout = true;
        id = template.id;

        // Copy pins
        pins.clear();
        for(int i = 0; i < template.pins.size(); i++) {
            UIPin p = template.pins[i];
            UIPin newPin = UIPin.Create(p.anchor, p.parentAnchor, p.value, p.offset, p.isFactor, p.priority);
            pins.push(newPin);
        }

        // Copy width/height pins
        if(template.widthPin) {
            if(!widthPin) widthPin = new("UIPin");
            widthPin.copyFrom(template.widthPin);
        } else {
            widthPin = null;
        }

        if(template.heightPin) {
            if(!heightPin) heightPin = new("UIPin");
            heightPin.copyFrom(template.heightPin);
        } else {
            heightPin = null;
        }

        // Copy subviews
        subviews.clear();
        for(int i = 0; i < template.subviews.size(); i++) {
            UIView sv = template.subviews[i];
            UIView newSv = UIView(new(sv.getClass()));
            newSv.baseInit();
            newSv.applyTemplate(sv);
            add(newSv);

            if(newSV.id != "") {
                viewLookup.insert(Name(newSv.id), newSv);
            }
        }

        // Set mask
        if(template.mask) {
            setMask(template.mask.clone());
        } else {
            mask = null;
        }
    }


    virtual string getDescription() {
        return String.Format("%s  Pos: (x: %.2f, y: %.2f)  Size: (%.2f x %.2f)", getClassName(), frame.pos.x, frame.pos.y, frame.size.x, frame.size.y);
    }

    void setCanvas(Canvas c) {
        drawCanvas = c;
        foreach(v : subviews) {
            v.setCanvas(c);
        }
    }

    void setMask(UIView v) {
        if(mask) removeMask();
        mask = v;
        v.parent = self;
    }

    void clearMask(bool delete = true, UIRecycler recycler = null) {
        if(delete && mask) {
            mask.teardown(recycler);
            mask.destroy();
        }
        mask = null;
    }

    void removeMask() {
        if(mask) 
            mask.parent = null;
        mask = null;
    }

    UIView getMask() {
        return mask;
    }

    UIPin pin(int anchor = 0, int parentAnchor = -1, double value = 0, double offset = 0, bool isFactor = false, int priority = 0) {
        if(parentAnchor == -1) { parentAnchor = anchor; }
        
        UIPin p = new("UIPin");
        p.anchor = anchor;
        p.parentAnchor = parentAnchor;
        p.value = value;
        p.offset = offset;
        p.isFactor = isFactor;
        p.priority = priority;
        pins.push(p);

        return p;
    }

    void pinToParent(double lOffset = 0, double tOffset = 0, double rOffset = 0, double bOffset = 0) {
        pin(UIPin.Pin_Left, value: 0, lOffset);
        pin(UIPin.Pin_Top, value: 0, tOffset);
        pin(UIPin.Pin_Right, value: 0, rOffset);
        pin(UIPin.Pin_Bottom, value: 0, bOffset);
    }

    void pinWidth(double value, double offset = 0, bool isFactor = false) {
        if(!widthPin) widthPin = new("UIPin");
        widthPin.value = value;
        widthPin.offset = offset;
        widthPin.isFactor = isFactor;
    }

    void pinHeight(double value, double offset = 0, bool isFactor = false) {
        if(!heightPin) heightPin = new("UIPin");
        heightPin.value = value;
        heightPin.offset = offset;
        heightPin.isFactor = isFactor;
    }

    // Get absolute height defined by pins or frame
    // Returns -1 if height is flexible as defined by pins
    double getLayoutHeightAbsolute() {
        if(heightPin && !heightPin.isFactor && heightPin.value != UIView.Size_Min) {
            return heightPin.value + heightPin.offset;
        } else if(!heightPin) {
            return frame.size.y;
        }
        return -1;
    }

    // Get proportional height and offset if defined by pins
    // Return -1 if not set
    double, double getProportionalHeight() {
        if(heightPin && heightPin.isFactor) {
            return heightPin.value, heightPin.offset;
        }
        return -1, -1;
    }

    // Get absolute width defined by pins or frame
    // Returns -1 if width is flexible as defined by pins
    double getLayoutWidthAbsolute() {
        if(widthPin && !widthPin.isFactor && widthPin.value != UIView.Size_Min) {
            return widthPin.value + widthPin.offset;
        } else if(!widthPin || widthPin.value == UIView.Size_Min) {
            return frame.size.x;
        }
        return -1;
    }

    // Get proportional width and offset if defined by pins
    // Return -1 if not set
    double, double getProportionalWidth() {
        if(widthPin && widthPin.isFactor) {
            return widthPin.value, widthPin.offset;
        }
        return -1, -1;
    }

    UIPin firstPin(int type) {
        for(int x = 0; x < pins.size(); x++) {
            if(pins[x].anchor == type) {
                return pins[x];
            }
        }

        return null;
    }

    void removePins(int type) {
        for(int x = 0; x < pins.size(); x++) {
            if(pins[x].anchor == type) {
                pins.delete(x--);
                requiresLayout = true;
            }
        }
    }

    void clearPins() {
        pins.clear();
        requiresLayout = true;
    }

    virtual void drawMask(int stencilLevel) {
        // Prepare for drawing the stencil
        Screen.SetStencil(stencilLevel, SOP_Increment, SF_ColorMaskOff);
        cStencil = stencilLevel ? stencilLevel << 1 : 1;

        // TODO: Handle special clipping rules for masks
        // Draw the mask view
        mask.layoutIfNecessary();
        mask.draw();
        mask.drawSubviews();

        /*Screen.DrawTexture(TexMan.CheckForTexture("WPNICON4"), false, 0, 0, 
            DTA_DestWidth, Screen.GetWidth(),
            DTA_DestHeight, Screen.GetHeight()
        );*/

        // Set drawn stencil active
        Screen.SetStencil(cStencil, SOP_Keep, SF_AllOn);

        Console.Printf("Drew mask at x: %f y: %f w: %f h: %f to stencil level %d", mask.frame.pos.x, mask.frame.pos.y, mask.frame.size.x, mask.frame.size.y, cStencil);
    }

    virtual void undrawMask() {
        if(cStencil == 0 || cStencil == 1) {
            // Just clear the whole thing and revert
            Screen.ClearStencil();
            Screen.SetStencil(0, SOP_Keep, SF_AllOn);

            Console.Printf("Undrew mask, cleared stencil");
            return;
        }

        Screen.SetStencil(cStencil, SOP_Decrement);
        
        // Draw over the current stencil area
        Screen.Clear(0, 0, Screen.GetWidth(), Screen.GetHeight(), 0xFFFFFFFF);
        
        Screen.SetStencil(cStencil >> 1, SOP_Keep, SF_AllOn);

        Console.Printf("Undrew mask, decremented to stencil level %d", cStencil >> 1);
    }

    virtual void draw() {
        if(hidden) { return; }
        
        layoutIfNecessary();

        if(ignoresClipping) {
            clearClip();
        }

        if(backgroundColor != 0) {
            fill((0,0), frame.size, backgroundColor);
        }
    }


    virtual void drawSubviews() {
        if(hidden || subviews.size() == 0) { return; }

        cStencil = parent ? parent.cStencil : 0;

        UIBox clipRect;
        UIBox svClipRect;
        getScreenClip(clipRect);
        
        if(!ignoresClipping && clipRect.size ~== (0,0)) { return; } // Don't draw if our clip rect is too small

        for(int x = 0; x < subviews.size(); x++) {
            let sv = subviews[x];
            sv.layoutIfNecessary();     // We require accurate coordinates for the clip rect

            if(!sv.ignoresClipping) {
                sv.getScreenClip(svClipRect);
                if(svClipRect.pos.x > clipRect.pos.x + clipRect.size.x || svClipRect.pos.y > clipRect.pos.y + clipRect.size.y || svClipRect.pos.x + svClipRect.size.x < clipRect.pos.x || svClipRect.pos.y + svClipRect.size.y < clipRect.pos.y) {
                    continue;
                }
            }

            if(!ignoresClipping) setClip(int(clipRect.pos.x), int(clipRect.pos.y), int(clipRect.size.x), int(clipRect.size.y));

            if(sv.mask) {
                sv.drawMask(cStencil);
            }

            if(sv.drawSubviewsFirst) {
                sv.drawSubviews();

                // Reset clip rect because subviews probably changed it
                if(!ignoresClipping) setClip(int(clipRect.pos.x), int(clipRect.pos.y), int(clipRect.size.x), int(clipRect.size.y));
                
                sv.draw();
            } else {
                sv.draw();
                sv.drawSubviews();
            }
            
            if(sv.mask) {
                sv.undrawMask();
            }
        }
    }

    virtual void tick() {
        if(!hidden && requiresLayout) {
            if(parent && parent.layoutWithChildren) {
                parent.layoutChildChanged(self);
            } else {
                layout();
            }
        }

        for(int x = 0; x < subviews.size(); x++) {
            subviews[x].Tick();
        }

        if(mask) mask.Tick();
    }

    virtual bool event(ViewEvent ev) {
        for(int x = subviews.size() - 1; x >=0; x--) {
            if(subviews[x].event(ev)) {
                return true;
            }
        }
        return false; 
    }

    bool isOnScreen() {
        Vector2 screen = screenSize();
        Vector2 pos = relToScreen((0,0));
		Vector2 size = (frame.size.x * cScale.x, frame.size.y * cScale.y);

        if(pos.x > screen.x || pos.y > screen.y || pos.x + size.x < 0 || pos.y + size.y < 0) {
            return false;
        }
        return true;
    }

    virtual void onMouseDown(Vector2 screenPos, ViewEvent ev = null) { }
    virtual void onMouseUp(Vector2 screenPos, ViewEvent  ev = null) { }
    virtual void onMouseEnter(Vector2 screenPos) { }
    virtual void onMouseExit(Vector2 screenPos, UIView newView) { }

    // Sent to the view being dragged
    virtual void onDrag(Vector2 mousePos, UIView restrictView) { }
    virtual bool onDragOver(UIView overView, Vector2 mousePos, UIView restrictView) { return true; }
    virtual bool onDragEnd(UIView control, Vector2 mousePos, UIView restrictView, bool dropped) { return true; }

    // Sent to the drag target
    virtual void onDragOut(UIControl control, Vector2 mousePos, UIView restrictView) { }

    virtual Vector2 calcMinSize(Vector2 parentSize) {
        return minSize;     // Default just returns minSize, override on specific views for more functionality
    }

    virtual double calcPinnedWidth(Vector2 parentSize) {
        double width = invalid;

        if(widthPin) {
            if(widthPin.anchor == UIPin.Pin_Static) {
                width = widthPin.value + widthPin.offset;
            } else if(parent && widthPin.isFactor) {
                width = parentSize.x * widthPin.value + widthPin.offset;
            } else if(!widthPin.isFactor) {
                if(widthPin.value == Size_Min) {
                    width = parentSize.x;
                } else {
                    width = widthPin.value + widthPin.offset;
                }
            }
            width = MAX(MIN(width, maxSize.x), minSize.x);
        }


        double left = invalid, right = invalid;

        if(width == invalid) {
            for(int i = 0; i < pins.size(); i++) {
                UIPin p = pins[i];

                switch(p.anchor) {
                    case UIPin.Pin_Left:
                        left = p.isFactor ? p.getParentPos(parentSize) * p.value + p.offset : p.getParentPos(parentSize) + p.offset;
                        break;
                    case UIPin.Pin_Right:
                        right = p.isFactor ? p.getParentPos(parentSize) * p.value + p.offset : p.getParentPos(parentSize) + p.offset;
                        break;
                    default:
                        break;
                }
            }
        }
        
        // Enforce minimum width
        if(width == invalid && right != invalid && left != invalid) {
            width = right - left;
        } else if(width == invalid) {
            width = 9999999;
        }

        if(width < minSize.x) {
            width = minSize.x;
        }

        // Enforce maximum width
        if(width > maxSize.x) {
            width = maxSize.x;
        }

        return width;
    }

    void processPins() {
        Vector2 minimumSize = (invalid, invalid);       // Not minSize. This is the calculated minimum size. Sorry.

        // Process Width
        if(widthPin) {
            if(widthPin.anchor == UIPin.Pin_Static) {
                frame.size.x = widthPin.value + widthPin.offset;
            } else if(parent && widthPin.isFactor) {
                frame.size.x = parent.frame.size.x * widthPin.value + widthPin.offset;
            } else if(!widthPin.isFactor) {
                if(widthPin.value == Size_Min) {
                    if(minimumSize.x == invalid) { minimumSize = calcMinSize(parent ? parent.frame.size : (invalid,invalid)); }
                    frame.size.x = minimumSize.x + widthPin.offset;
                } else {
                    frame.size.x = widthPin.value + widthPin.offset;
                }
            }
            frame.size.x = MAX(MIN(frame.size.x, maxSize.x), minSize.x);
        }

        // Process Height
        if(heightPin) {
            if(heightPin.anchor == UIPin.Pin_Static) {
                frame.size.y = heightPin.value + heightPin.offset;
            } else if(parent && heightPin.isFactor) {
                frame.size.y = parent.frame.size.y * heightPin.value + heightPin.offset;
            } else if(!heightPin.isFactor) {
                if(heightPin.value == Size_Min) {
                    if(minimumSize.y == invalid) { minimumSize = calcMinSize(parent ? parent.frame.size : (invalid,invalid)); }
                    frame.size.y = minimumSize.y + heightPin.offset;
                } else {
                    frame.size.y = heightPin.value + heightPin.offset;
                }
            }
            frame.size.y = MAX(MIN(frame.size.y, maxSize.y), minSize.y);
        }

        if(parent) {
            double left = invalid, top = invalid, right = invalid, bottom = invalid;
            int leftPriority = 0, rightPriority = 0, topPriority = 0, bottomPriority = 0;
            bool hCentered, vCentered;
            Vector2 parentSize = parent.frame.size;
            Vector2 currentSize = frame.size;

            for(int i = 0; i < pins.size(); i++) {
                UIPin p = pins[i];

                switch(p.anchor) {
                    case UIPin.Pin_Left:
                        left = p.isFactor ? p.getParentPos(parentSize) * p.value + p.offset : p.getParentPos(parentSize) + p.offset;
                        leftPriority = p.priority;
                        break;
                    case UIPin.Pin_Right:
                        right = p.isFactor ? p.getParentPos(parentSize) * p.value + p.offset : p.getParentPos(parentSize) + p.offset;
                        rightPriority = p.priority;
                        if(scale.x != 0) right /= scale.x;
                        else right = 0;

                        break;
                    case UIPin.Pin_Top:
                        top = p.isFactor ? p.getParentPos(parentSize) * p.value + p.offset : p.getParentPos(parentSize) + p.offset;
                        topPriority = p.priority;
                        break;
                    case UIPin.Pin_Bottom:
                        bottom = p.isFactor ? p.getParentPos(parentSize) * p.value + p.offset : p.getParentPos(parentSize) + p.offset;
                        bottomPriority = p.priority;
                        if(scale.y != 0) bottom /= scale.y;
                        else bottom = 0;

                        break;
                    case UIPin.Pin_HCenter: {
                            double center = p.getParentPos(parentSize) * p.value + p.offset;
                            left = center - ((currentSize.x * scale.x) / 2.0);
                            right = left + currentSize.x;
                            hCentered = true;
                        }
                        break;
                    case UIPin.Pin_VCenter: {
                            double center = p.getParentPos(parentSize) * p.value + p.offset;
                            top = center - ((currentSize.y * scale.y) / 2.0);
                            bottom = top + currentSize.y;
                            vCentered = true;
                        }
                        break;
                    default:
                        break;
                }
            }

            // Fill in missing details
            if(right == invalid) {
                if(left == invalid) { left = frame.pos.x; }
                right = MAX(left + minSize.x, left + currentSize.x);
            }

            if(bottom == invalid) {
                if(top == invalid) { top = frame.pos.y; }
                bottom = MAX(top + minSize.y, top + currentSize.y);
            }

            if(left == invalid) { left = MIN(right - minSize.x, right - currentSize.x); }
            if(top == invalid) { top = MIN(bottom - minSize.y, bottom - currentSize.y); }


            // Enforce minimum width
            if(right - left < minSize.x) {
                double err = minSize.x - (right - left);
                if(hCentered) {
                    right += err * 0.5;
                    left -= err * 0.5;
                } else {
                    if(rightPriority > leftPriority) { left -= err; } else { right += err; }
                }
            }

            // Enforce minimum height
            if(bottom - top < minSize.y) {
                double err = minSize.y - (bottom - top);
                if(vCentered) {
                    bottom += err * 0.5;
                    top -= err * 0.5;
                } else {
                    if(bottomPriority > topPriority) { top -= err; } else { bottom += err; }
                }
            }

            // Enforce maximum width
            if(right - left > maxSize.x) {
                double err = maxSize.x - (right - left);
                if(hCentered) {
                    right += err * 0.5;
                    left -= err * 0.5;
                } else {
                    if(rightPriority > leftPriority) { left -= err; } else { right += err; }
                }
            }

            // Enforce maximum height
            if(bottom - top > maxSize.y) {
                double err = maxSize.y - (bottom - top);
                if(vCentered) {
                    bottom += err * 0.5;
                    top -= err * 0.5;
                } else {
                    if(bottomPriority > topPriority) { top -= err; } else { bottom += err; }
                }
            }

            frame.pos.x = left;
            frame.pos.y = top;
            frame.size.x = right - left;
            frame.size.y = bottom - top;
        }
    }

    virtual void layout(Vector2 parentScale = (0,0), double parentAlpha = -1, bool skipSubviews = false) {
        cScale = (parentScale ~== (0,0) ? calcScale() : (parentScale.x * scale.x, parentScale.y * scale.y));
        cAlpha = (parentAlpha == -1 ? calcAlpha() : parentAlpha * alpha);

        // Process anchor pins
        processPins();
        
        // Layout subviews
        if(!skipSubviews) layoutSubviews();

        requiresLayout = false;
    }

    // Called by some view managers if adjustments were made to this view after laying out
    virtual void onAdjustedPostLayout(UIView sourceView) {
        // Do nothing by default
    }

    // If a child changes layout and this view has layoutWithChildren, this view will take charge of laying out the subview
    // This will be passed up until A) There are no more views with layoutWithChildren or B) The view is a layout manager
    virtual void layoutChildChanged(UIView subview) {
        if(parent && parent.layoutWithChildren) parent.layoutChildChanged(self);
        else layout();
    }
    
    virtual void layoutSubviews() {
        layingOutSubviews = true;
        for(int i = 0; i < subviews.size(); i++) {
            subviews[i].layout(cScale, cAlpha);
        }
        if(mask) mask.layout(cScale, cAlpha);
        layingOutSubviews = false;
    }

    virtual void layoutIfNecessary() {
        if(requiresLayout) {
            if(parent && parent.layoutWithChildren) {
                parent.layoutChildChanged(self);
            } else {
                layout();
            }
        }
    }

    // This is called just after an animation frame has adjusted the size/pos and values of the view
    // it should give subclasses an opportunity to adjust to the changes without a full layout
    // onAnimationStep is called BEFORE laying out the subviews
    // Return TRUE if the subviews REQUIRE layout after an animation frame. Return false to let the animation decide.
    virtual bool onAnimationStep() { return false; }
    UIViewAnimator getAnimator() {
        let m = getMenu();
        return m ? m.animator : null;   // TODO: Find other ways to get the animator if we are not inside a UIMenu
    }

    UIViewFrameAnimation animateFrame(double length = 0.25,
            Vector2 fromPos     = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid), 
            Vector2 toPos       = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            Vector2 fromSize    = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            Vector2 toSize      = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            double fromAlpha    = UIViewFrameAnimation.invalid, 
            double toAlpha      = UIViewFrameAnimation.invalid,
            double fromAngle    = UIViewFrameAnimation.invalid,
            double toAngle      = UIViewFrameAnimation.invalid,
            bool layoutSubviewsEveryFrame = false,
            AnimEasing ease = Ease_None,
            bool loop = false
            ) {

        let animator = getAnimator();

        if(animator) {
            let anim = new("UIViewFrameAnimation").initComponents(self, length,
                fromPos: fromPos,
                toPos: toPos,
                fromSize: fromSize,
                toSize: toSize, 
                fromAlpha: fromAlpha,
                toAlpha: toAlpha,
                layoutSubviewsEveryFrame,
                ease,
                loop,
                fromAngle: fromAngle, 
                toAngle: toAngle
            );
            
            animator.add(anim);

            return anim;
        }

        return null;
    }

    void setAlpha(double a) {
        alpha = a;
        cAlpha = calcAlpha();

        // Calc subview alpha
        for(int i = 0; i < subviews.size(); i++) {
            subviews[i].setAlpha(subviews[i].alpha);
        }
    }

    void setScale(Vector2 sc) {
        scale = sc;
        cScale = calcScale();

        // Tell subviews they need to be laid out
        setRequiresLayout(true);
    }

    void setRequiresLayout(bool subviewsToo = true) {
        requiresLayout = true;

        if(subviewsToo) {
            for(int i = 0; i < subviews.size(); i++) {
                subviews[i].setRequiresLayout(true);
            }
        }
    }

    // Property Management ====================
	double calcAlpha() {
		double a = alpha;

		UIView v = self.parent;
		while (v) {
			a *= min(1.0, v.alpha);
			v = v.parent;
		}
		return a;
	}

    Vector2 calcScale() {
		Vector2 s = scale;

		UIView v = self.parent;
		while (v) {
			s = (s.x * v.scale.x, s.y * v.scale.y);
			v = v.parent;
		}
		return s;
	}

    // Get the menu this view belongs to
    UIMenu getMenu() {
        if(parentMenu) {
            return parentMenu;
        }

        // If not found yet, go up the chain and find a parent that has a menu
        let m = parent ? parent.getMenu() : null;
        if(m) { return m; }

        return null;

        // Don't do this anymore, if run before the first frame (during INIT) we will end up grabbing the wrong menu
        // Last ditch effort, get the active menu and see if it's a UIMenu
        // TODO: Check passthrough menus too and find the UIMenu they references
        //return UIMenu(Menu.GetCurrentMenu());
    }

    UIView getMasterView() {
        if(parent) { return parent.getMasterView(); }
        return self;
    }

    // Subview Management =====================
    virtual void removeFromSuperview() {
        if(parent) {
            parent.removeView(self);
        }
    }

    virtual void add(UIView v) {
        v.removeFromSuperview();
        subviews.push(v);

        v.parent = self;
        if(drawCanvas) v.setCanvas(drawCanvas);

        v.onAddedToParent(self);
    }

    virtual void onAddedToParent(UIView parentView) {
        parentMenu = getMenu();
    }

    bool hasParent(UIView potentialParent) {
        UIView p = parent;
        while(p) {
            if(p == potentialParent) return true;
            p = p.parent;
        }

        return false;
    }

    // TODO: Rename this. I regret naming this removeView() instead of remove()
    virtual void removeView(UIView v) {
        int i = subviews.Find(v);
        if(i != subviews.size()) {
            removeViewAt(i);
        }
    }

    virtual void removeViewAt(int index) {
        UIView v = subviews[index];
        subviews.delete(index);

        UIMenu m = getMenu();
        if(m) {
            m.viewRemoved(v);
        }

        v.parent = null;
        v.parentMenu = null;
        // TODO: We might need an onRemoveFromParent() function but as of yet it is not required

        v.onRemoved(self);
    }

    virtual void onRemoved(UIView oldSuperview) { 
        drawCanvas = null;
    }

    int numSubviews() {
        return subviews.size();
    }

    UIView viewAt(int idx) {
        return subviews[idx];
    }

    UIView topView() {
        return subviews.size() > 0 ? subviews[subviews.size() - 1] : null;
    }

    void moveToBack(UIView v) {
        int i = subviews.Find(v);
        if(i != subviews.size()) {
            moveTowardsBack(i);
        }
    }

    void moveToFront(UIView v) {
        int i = subviews.Find(v);
        if(i != subviews.size()) {
            moveTowardsFront(i);
        }
    }

    void moveTowardsBack(int i) {
        UIView v = subviews[i];
        subviews.delete(i);
        subviews.insert(0, v);
    }

    void moveTowardsFront(int i) {
        UIView v = subviews[i];
        subviews.delete(i);
        subviews.push(v);
    }

    // Moves view Source behind view Target
    void moveBehind(UIView source, UIView target) {
        if(!source || !target || source == target) return;
        int idx1 = subviews.find(source);
        int idx2 = subviews.find(target);

        if(idx1 < subviews.size() && idx2 < subviews.size()) {
            subviews.delete(idx1);
            if(idx2 > idx1) idx2--;
            subviews.insert(idx2, source);
        }
    }

    // Moves view Source in front of view Target
    void moveInfront(UIView source, UIView target) {
        if(!source || !target || source == target) return;
        int idx1 = subviews.find(source);
        int idx2 = subviews.find(target);

        if(idx1 < subviews.size() && idx2 < subviews.size()) {
            subviews.delete(idx1);
            if(idx2 >= subviews.size() - 1) subviews.push(source);
            if(idx2 < idx1) idx2++;
            subviews.insert(idx2, source);
        }
    }

    int indexOf(UIView v) {
        int idx = subviews.find(v);
        if(idx >= subviews.size()) {
            return -1;  // Not found
        }
        return idx;
    }


    // Must return false if no action was taken
    virtual bool handleSubControl(UIControl ctrl, int event, bool fromMouse = false, bool fromController = false) {
        if(parent) {
            return parent.handleSubControl(ctrl, event, fromMouse, fromController);
        }
        return false;
    }

    // Teardown could be called whenever a view is no longer needed
    virtual void teardown(UIRecycler recycler) {
        // Call teardown on on sub objects
        for(int x =0; x < subviews.size(); x++) {
            subviews[x].teardown(recycler);
        }
    }

    override void onDestroy() {
        // TODO: Call teardown maybe
    }

    // Frame and drawing ops ==================
    virtual Vector2 relToScreen(Vector2 relPos) {
        if(parent) return parent.relToScreen(frame.pos + (relPos.x * scale.x, relPos.y * scale.y));
        else return (relpos.x * scale.x, relPos.y * scale.y);
	}

    virtual Vector2 screenToRel(Vector2 screenPos) {
        Vector2 tl = relToScreen((0,0));
        tl = (screenPos - tl);
        if(cScale ~== (0,0)) { cScale = calcScale(); }
        return (tl.x / cScale.x, tl.y / cScale.y);
    }

    void boxToScreenClipped(out UIBox ret, UIBox b) {
        ret.pos = relToScreen(b.pos);
		ret.size = (b.size.x * cScale.x, b.size.y * cScale.y);
		
		if(parent != NULL) {
            UIBox m;
            UIView p = parent;

            // Find the next view up that clips subviews
            while(p) {
                if(p && p.clipsSubviews) {
                    p.clipToScreen(m);
                    if(!m.intersect(ret, ret)) {
                        break;  // Early out if we clipped down to zero
                    }
                }
 
                p = p.parent;
            }
		}
	}

    void boundingBoxToScreen(out UIBox ret) {
		ret.pos = relToScreen((0,0));
		ret.size = (frame.size.x * cScale.x, frame.size.y * cScale.y);
	}

    Vector2 screenSize() {
        // TODO: Add an engine call for canvas size
        if(drawCanvas) {
            double x, y, w, h;
            [x, y, w, h] = drawCanvas.GetFullscreenRect(1.0, 1.0, FSMode_ScaleToScreen);
            return (round(w), round(h));
        }
        else return (Screen.GetWidth(), Screen.GetHeight());
    }

    virtual void clipToScreen(out UIBox ret) {
		ret.pos = relToScreen((0,0));
		ret.size = (frame.size.x * cScale.x, frame.size.y * cScale.y);
	}

    virtual void clearClip() {
        if(drawCanvas) drawCanvas.ClearClipRect();
        else Screen.ClearClipRect();
    }

    virtual void setClip(int x, int y, int w, int h) {
        if(drawCanvas) drawCanvas.SetClipRect(x, y, w, h);
        else Screen.SetClipRect(x, y, w, h);
    }


    virtual void getScreenClip(out UIBox ret) {
        UIBox b;
        b.pos = clipsSubviews ? (0,0) : (-454545, -454545);
        b.size = clipsSubviews ? frame.size : (999999,999999);
        boxToScreenClipped(ret, b);
    }

    void getScreenClipActual(out UIBox ret) {
        UIBox b;
        b.size = frame.size;
        boxToScreenClipped(ret, b);
    }

    // Find the top-most element at the specified position
    // TODO: Discard subview tests when the point is outside the parent bounds (And clipping is not disabled) !!!
	UIView raycastPoint(Vector2 screenPos) {
		if(!cancelsSubviewRaycast) {
            for(int i = subviews.size() - 1; i >= 0; i--) {
                UIView v = subviews[i];

                if(v && !v.hidden) {
                    UIView found = v.raycastPoint(screenPos);
                    if(found) { return found; }
                }
            }
        }
        
		if(raycastTarget && raycastTest(screenPos)) {
			return self;
		}

		return null;
	}


    UIView raycastDragTarget(UIControl dragControl, Vector2 mousePos) {
        if(!cancelsSubviewRaycast) {
            for(int i = subviews.size() - 1; i >= 0; i--) {
                UIView v = subviews[i];

                if(v && !v.hidden) {
                    UIView found = v.raycastDragTarget(dragControl, mousePos);
                    if(found) { return found; }
                }
            }
        }

        if(raycastTarget && dragTarget && overlapTest(dragControl) && canAcceptDragFrom(dragControl, mousePos)) {
            return self;
        }

        return null;
    }


    virtual bool canAcceptDragFrom(UIControl dragControl, Vector2 mousePos) {
        return true;
    }

    virtual bool onDropped(UIControl dragControl, Vector2 mousePos, UIView restrictView) {
        // Default implementation does nothing
        Console.Printf("UIControl: %s Dropped on %s", dragControl.getClassName(), self.getClassName());
        return true;
    }


    virtual bool raycastTest(Vector2 screenPos) {
        UIBox f;
        if(ignoresClipping) boundingBoxToScreen(f);
        else getScreenClipActual(f);   // TODO: Don't always calculate clips upwards
		return f.pointInside(screenPos);
	}


    virtual bool overlapTest(UIView sourceView) {
        UIBox f;
        if(ignoresClipping) boundingBoxToScreen(f);
        else getScreenClipActual(f);

        UIBox d;
        sourceView.boundingBoxToScreen(d);
        return f.intersect(f, d);
    }


    void fill(Vector2 relStartPos, Vector2 size, Color col = 0xFFFFFFFF, double a = 1, bool fullClip = true) {
		Vector2 startPos = relToScreen(relStartPos);
		size = (size.x * cScale.x, size.y * cScale.y);

        UIBox tempRect;
        
        // Get clip rect
        int cx, cy, sx, sy;

        if(fullClip) {
            getScreenClip(tempRect);
            cx = int(tempRect.pos.x);
            cy = int(tempRect.pos.y);
            sx = int(tempRect.size.x) + cx;
            sy = int(tempRect.size.y) + cy;
        } else {
            if(drawCanvas) {
                [cx, cy, sx, sy] = drawCanvas.GetClipRect();
                sx = sx == -1 ? 999999 : sx + cx;
                sy = sy == -1 ? 999999 : sx + cy;
            } else {
                sx = sx == -1 ? Screen.GetWidth() : sx + cx;
                sy = sy == -1 ? Screen.GetHeight() : sx + cy;
            }
        }

        // Trim draw rect
        cx = MAX(cx, int(startPos.x));
        cy = MAX(cy, int(startPos.y));
        sx = MAX(0, MIN(sx, int(startPos.x + size.x)));
        sy = MAX(0, MIN(sy, int(startPos.y + size.y)));

        // Draw
        if(drawCanvas) drawCanvas.dim(col, a * cAlpha * (col.a / 256.0), cx, cy, sx - cx, sy - cy);
        else Screen.dim(col, a * cAlpha * (col.a / 256.0), cx, cy, sx - cx, sy - cy);
    }

    void clip(double left, double top, double width, double height, int flags = 0) {
        if(flags != 0) {
            if(flags & DR_SCREEN_RIGHT) left = frame.size.x + left;
            if(flags & DR_SCREEN_HCENTER) left = (frame.size.x / 2.0) + left;
            if(flags & DR_SCREEN_BOTTOM) top = frame.size.y + top;
            if(flags & DR_SCREEN_VCENTER) top = (frame.size.y / 2.0) + top;
        }
        
        let pos = relToScreen((left, top));
        int x = int(pos.x);
        int y = int(pos.y);
        setClip(
            pos.x, 
            pos.y,
            width * cScale.x, 
            height * cScale.y
        );
    }

    // Helper Funcs
    double getTime() {
        return MSTimeF() / 1000.0;
    }

    void playSound(string snd, float volume = 1.0) {
        S_StartSound (snd, CHAN_VOICE, CHANF_UI, snd_menuvolume * volume);
    }
}


class UIHandler abstract ui {
    enum EventType {
        Event_Selected = UIEvent.Type_LastMouseEvent,
        Event_Deselected,
        Event_Activated,
        Event_Alternate_Activate,    // Usually used for double-clicking buttons
        Event_ValueChanged,
        Event_Closed,
        Event_Last
    }

    virtual void handleEvent(int type, UIControl con, bool fromMouseEvent = false, bool fromcontrollerEvent = false) { }
    virtual bool handleMenuEvent(int mkey, UIControl con, bool fromcontroller) { return false; }
}


class UIControl : UIView {
    bool activeSelection;       // Selected via keyboard or gamepad navigation
    bool rejectHoverSelection;  // Menu will not select this control on a mouseOver event
    bool cancelsHoverDeSelect;  // Menu will not deselect this control on a mouseExit event, unless the new view is a control
    bool globalDragging;        // This view is being managed by the menu and is in the dragging state

    protected bool disabled;
    string command;
    UIHandler handler;
    UIControl controlHandler;

    int controlID;              // Use this to idenfity controls in the interface
    
    UIControl navLeft, navRight, navUp, navDown;

    UIControl init(Vector2 pos, Vector2 size) {
        Super.init(pos, size);

        raycastTarget = true;   // Controls are designed to be interacted with!
        return self;
    }

    override UIView baseInit() {
        Super.baseInit();

        raycastTarget = true;
        return self;
    }

    override void applyTemplate(UIView view) {
        Super.applyTemplate(view);
        UIControl t = UIControl(view);

        if(t) {
            rejectHoverSelection = t.rejectHoverSelection;
            cancelsHoverDeSelect = t.cancelsHoverDeSelect;
            disabled = t.disabled;
            command = t.command;
            controlID = t.controlID;

            // TODO: Somehow we have to copy the navigation links with the new hierarchy
        }
    }

    override bool raycastTest(Vector2 screenPos) {
        return !disabled && Super.raycastTest(screenPos);
	}

    virtual bool isDisabled() {
        return disabled;
    }

    virtual void setDisabled(bool disable = true) {
        disabled = disable;
    }

    virtual void onSelected(bool mouseSelection = false, bool controllerSelection = false) {
        activeSelection = true;
        sendEvent(UIHandler.Event_Selected, mouseSelection, controllerSelection);
    }

    virtual void onDeselected() {
        activeSelection = false;
        sendEvent(UIHandler.Event_Deselected, false);
    }

    virtual UIControl getNextControl(bool immediate = false) {
        UIControl nextCon = null;
        
        if(navRight) nextCon = navRight;
        else if(navDown) nextCon = navDown;
        else if(navLeft) nextCon = navLeft;
        else if(navUp) nextCon = navUp;

        if(!immediate) {
            for(int cnt = 0; nextCon && nextCon.isDisabled(); cnt++) {
                nextCon = nextCon.getNextControl(true);
                if(nextCon == self) return null;
                if(cnt > 100) return null;
            }
        }        

        return nextCon;
    }

    virtual UIControl getPrevControl(bool immediate = false) {
        UIControl nextCon = null;
        
        if(navLeft) nextCon = navLeft;
        else if(navUp) nextCon = navUp;
        else if(navRight) nextCon = navRight;
        else if(navDown) nextCon = navDown;

        if(!immediate) {
            while(nextCon && nextCon.isDisabled()) {
                nextCon = nextCon.getPrevControl(true);
                if(nextCon == self) return null;
            }
        }

        return nextCon;
    }

    // Return whether or not you consumed the event
    virtual bool onActivate(bool mouseSelection = false, bool controllerSelection = false) {
        return false;
    }

    // TODO: Require registering for menu events in menu
    virtual bool menuEvent(int key, bool fromcontroller) {
        if(handler && handler.handleMenuEvent(key, self, fromcontroller)) {
            return true;
        }
        
        UIView v = parent;
        while(v && !(v is "UIControl")) {
            v = v.parent; 
        }

        if(v && v is "UIControl") {
            return UIControl(v).menuEvent(key, fromcontroller);
        }
        return false;
    }

    void sendEvent(int evt, bool fromMouseEvent, bool fromController = false) {
        if(handler) {
            handler.handleEvent(evt, self, fromMouseEvent, fromController);
        } else if(controlHandler) {
            controlHandler.handleSubControl(self, evt, fromMouseEvent, fromController);
        } else if(parent) {
            if(!parent.handleSubControl(self, evt, fromMouseEvent, fromController)) {
                let m = getMenu();
                if(m) {
                    m.handleControl(self, evt, fromMouseEvent, fromController);
                }
            }
        } else {
            let m = getMenu();
            if(m) {
                m.handleControl(self, evt, fromMouseEvent, fromController);
            }
        }
    }
}