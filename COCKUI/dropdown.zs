class UIDropdownScroll : UIVerticalScroll {
    UIDropdown dropOwner;
    bool justOpened;

    UIDropdownScroll init(Vector2 pos, Vector2 size, UIScrollBarConfig config) {
        Super.initFromConfig(pos, size, config);
        autoHideScrollbar = true;
        return self;
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        // Don't do anything when we are layed out from parent
    }

    void ddLayout(UIView dropView) {
        // Note: This is not going to work correctly if we have any pins, because pins rely on the parent for positioning/sizing
        // Move into position under the drop view
        frame.pos = parent.screenToRel(dropView.relToScreen((0,dropView.frame.size.y)));

        // Get min width to fit contents
        Vector2 min = mLayout.calcMinSize((maxSize.x, 999999)) + (config.barWidth, 0);

        // Set width to match contents, or min width (this ignores scaling differences)
        frame.size.x = MAX(dropView.frame.size.x, ceil(min.x + 1));

        // Set height to match, don't go larger than screen size
        Vector2 screenBot = parent.screenToRel((0, Screen.GetHeight()));
        Vector2 screenPos = dropView.relToScreen((0,dropView.frame.size.y));
        Vector2 screenTop = parent.screenToRel((0, 0));
        
        // TODO: Factor in max size
        // If we are in the bottom third of the screen and our dropdown would be significantly cut off, swap to being on top of the dropdown
        if(screenBot.y - frame.pos.y < min.y * 0.65 && screenPos.y > (Screen.GetHeight() * 0.666666)) {
            double iwannabebig = MAX(minSize.y, min.y);
            Vector2 dropScreenPos = dropView.relToScreen((0,0));
            frame.pos = parent.screenToRel(dropScreenPos) - (0, iwannabebig);
            frame.pos.y = MAX(screenTop.y, frame.pos.y);
            frame.size.y = MIN(iwannabebig, dropScreenPos.y - screenTop.y);
        } else {
            frame.size.y = MIN(screenBot.y - frame.pos.y, MAX(minSize.y, min.y));
        }
        
        Super.layout(parent.cScale, parent.cAlpha);
    }

    void ddPosition(UIView dropView) {
        frame.pos = parent.screenToRel(dropView.relToScreen((0,dropView.frame.size.y)));

        // Check if bottom is below the bottom of the screen, if so move to above the dropview instead of below it
        Vector2 screenPos = relToScreen((0,frame.size.y));
        if(screenPos.y > Screen.GetHeight() || frame.size.y < mLayout.frame.size.y) {
            ddLayout(dropView); // TODO: Instead of laying out the whole bugger, just softly resize the bounding frame. The internal layout view definitely shouldn't need a full layout here
        }
    }

    override void tick() {
        Super.tick();

        if(dropOwner) {
            UIBox clipRect;

            // Get drop owners render clip to check if it's visible on screen
            dropOwner.getScreenClip(clipRect);
            if(clipRect.size ~== (0,0)) { 
                dropOwner.close();
            } else {
                ddPosition(dropOwner);
            }
        }

        justOpened = false;
    }
}

class UIDropdownHandler : UIHandler {
    UIDropdown dd;

    override void handleEvent(int type, UIControl con, bool fromMouseEvent, bool fromcontrollerEvent) {
        if(type == UIHandler.Event_Activated) {
            dd.conSelected(con, fromMouseEvent, fromcontrollerEvent);
        } else if(type == UIHandler.Event_Selected) {
            dd.conNav(con, fromMouseEvent, fromcontrollerEvent);
        }
    }

    override bool handleMenuEvent(int mkey, UIControl con, bool fromcontroller) {
        if(mkey == Menu.MKEY_Back) {
            if(dd && dd.isOpen()) {
                dd.close();
                dd.playSound("menu/backup");
                dd.restoreActiveSelection();
                return true;
            }
        }
        return false;
    }
}


class UIDropdown : UIButton {
    UIView dropBlocker;                 // View to block input on other views
    UIDropdownScroll dropScroll;
    UIVerticalLayout dropLayout;
    UIImage dropLayoutBG;               // Background image for drop layout, hopefully 9 slice
    UIImage dropIndicator;              // Indicator image, pinned to middle-right
    Font fnt;
    UIDropdownHandler ddHandler;
    int itemSpacing;
    bool mouseNavigateToItems, wasOpenBeforeClick, allowDuplicateSelection;
    string noneText;

    Array<string> items;
    Array<UIButton> itemButts;
    protected int selectedItem;


    UIDropdown init(Vector2 pos, Vector2 size, Array<string> items, int selectedItem, Font fnt,
                            UIScrollBarConfig scrollConfig,
                            UIButtonState normal = null,
                            UIButtonState hover = null,
                            UIButtonState pressed = null,
                            UIButtonState disabled = null,
                            UIButtonState selected = null,
                            UIButtonState selectedHover = null,
                            UIButtonState selectedPressed = null,
                            NineSlice dropdownBG = null,
                            Alignment textAlign = Align_Left | Align_Middle,
                            string indicator = "", int itemSpacing = 4, string noneText = "None") {
        

        Super.init(pos, size, items.size() > selectedItem && selectedItem >= 0 ? items[selectedItem] : noneText, fnt,
                normal,
                hover,
                pressed,
                disabled, 
                selected,
                selectedHover,
                selectedPressed,
                textAlign);
        
        self.fnt = fnt;
        self.noneText = noneText;

        dropScroll = new("UIDropdownScroll").init(
            (0,0), (0,0), scrollConfig
        );
        
        dropScroll.dropOwner = self;
        dropScroll.ignoresClipping = true;
        dropScroll.mLayout.itemSpacing = itemSpacing;
        dropLayout = UIVerticalLayout(dropScroll.mLayout);

        let ddh = new("UIDropdownHandler");
        ddh.dd = self;
        ddHandler = ddh;

        if(dropdownBG) {
            // Create a background to fit the dropdown layout
            let img = new("UIImage").init((0,0), (49,40), "", dropdownBG);
            img.pinToParent();
            dropScroll.add(img);
            dropScroll.moveToBack(img);
        }

        if(indicator != "") {
            dropIndicator = new("UIImage").init((0,0), (0,0), indicator, imgStyle: UIImage.Image_Center);
            dropIndicator.pin(UIPin.Pin_Top);
            dropIndicator.pin(UIPin.Pin_Bottom);
            dropIndicator.pin(UIPin.Pin_Right);
            dropIndicator.pinWidth(UIView.Size_Min);
            add(dropIndicator);
        }
        
        setItems(items, selectedItem);

        return self;
    }

    virtual bool selectNext() {
        if(items.size() == 0) { return false; }

        selectedItem++;
        if(selectedItem >= items.size()) {
            selectedItem = items.size() - 1;
            return false;
        }

        label.text = items[selectedItem];
        requiresLayout = true;

        return true;
    }

    virtual bool selectPrevious() {
        if(items.size() == 0) { return false; }

        selectedItem--;
        if(selectedItem < 0) {
            selectedItem = 0;
            return false;
        }

        label.text = items[selectedItem];
        requiresLayout = true;

        return true;
    }

    virtual void cycleNext() {
        if(items.size() == 0) { return; }

        selectedItem++;
        if(selectedItem >= items.size()) {
            selectedItem = 0;
        }

        label.text = items[selectedItem];
        requiresLayout = true;
    }

    int getSelectedItem() {
        return selectedItem;
    }

    void setItems(Array<string> newItems, int selected = 0) {
        items.clear();
        items.append(newItems);

        selectedItem = selected;
        label.text = selectedItem >= 0 && items.size() > selectedItem ? items[selectedItem] : noneText;
        
        requiresLayout = true;

        buildItems();
    }

    protected void buildItems() {
        dropLayout.clearManaged();
        dropLayout.itemSpacing = itemSpacing;
        dropLayout.requiresLayout = true;
        itemButts.clear();

        // Create buttons
        // TODO: Allow user to assign states and shiz for these butts
        for(int x =0; x < items.size(); x++) {
            let b = new("UIButton").init((0,0), (0,0), items[x], fnt, 
                UIButtonState.Create("", x == selectedItem ? 0xFFAAAAAA : 0xFFFFFFFF), 
                UIButtonState.Create("", 0xFFb0c6f7), 
                textAlign: Align_Left | Align_Middle);

            b.pin(UIPin.Pin_Left);
            b.pin(UIPin.Pin_Right);
            b.heightPin = UIPin.Create(0,0,UIView.Size_Min);
            b.setTextPadding(15,3,10,3);
            b.handler = ddHandler;

            if(x > 0) {
                b.navUp = itemButts[x - 1];
                itemButts[x - 1].navDown = b;
            }

            itemButts.push(b);
            dropLayout.addManaged(b);
        }

        if(itemButts.size() > 1) {
            itemButts[itemButts.size() - 1].navUp = itemButts[itemButts.size() - 2];
        }
    }

    virtual void setSelectedItem(int selected = 0) {
        selectedItem = selected;
        label.text = selectedItem >= 0 && items.size() > selectedItem ? items[selectedItem] : noneText;
        requiresLayout = true;
    }

    void open(bool activate = false) {
        UIView master = getMasterView();

        if(master) {
            dropScroll.removeFromSuperview();
            master.add(dropScroll);
            dropScroll.justOpened = true;
        }

        buildItems();

        dropScroll.requiresLayout = true;
        requiresLayout = true;

        if(activate && itemButts.size() > 0) {
            let m = getMenu();
            if(m && selectedItem >= 0 && items.size() > selectedItem) {
                layout();
                dropScroll.layout();
                m.navigateTo(itemButts[selectedItem]); 
            }
            else if(m) {
                m.navigateTo(itemButts[0]); 
            }
        }
    }

    void restoreActiveSelection() {
        let m = getMenu();
        if(m) {
            UIView v = self;
            while(v.forwardSelection) { v = v.forwardSelection; }

            if(v is "UIControl") {
                m.navigateTo(UIControl(v));
            }
        }
    }

    void close() {
        if(dropBlocker) {
            dropBlocker.removeFromSuperview();
        }

        dropScroll.removeFromSuperview();
    }

    bool isOpen() {
        return dropScroll.parent != null;
    }

    override void onMouseUp(Vector2 screenPos) {
        Super.onMouseUp(screenPos);

        if(mouseInside && !wasOpenBeforeClick) {
            if(!isOpen()) {
                open();
            }
        } else {
            close();
        }

        wasOpenBeforeClick = false;
    }

    override bool event(ViewEvent ev) {
        if(isOpen() && ev.type == UIEvent.Type_LButtonDown) {
            if(!dropScroll.raycastTest((ev.mouseX, ev.mouseY))) {
                // Check if this click happened inside the dropdown
                if(!disabled && raycastTest((ev.mouseX, ev.mouseY))) {
                    wasOpenBeforeClick = true;
                }
                close();
            }
        }

        return Super.event(ev); 
    }

    override bool menuEvent(int key, bool fromcontroller) {
        if(key == Menu.MKEY_Back && isOpen()) {
            close();
            playSound("menu/backup");
            restoreActiveSelection();
            return true;
        }

        return Super.menuEvent(key, fromcontroller);
    }
    

    override void layout(Vector2 parentScale, double parentAlpha) {
        Super.layout(parentScale, parentAlpha);

        if(isOpen()) { dropScroll.ddLayout(self); }
    }

    override void onRemoved(UIView oldSuperview) {
        dropScroll.removeFromSuperview();
    }

    override Vector2 calcMinSize(Vector2 parentSize) {
        Vector2 size = minSize;
        //Vector2 pad = (textPadding.left + textPadding.right + (dropIndicator ? dropIndicator.tex.size.x : 0), textPadding.top + textPadding.bottom);
        double hPadding = textPadding.left + textPadding.right + (dropIndicator ? dropIndicator.tex.size.x : 0);
        double vPadding = textPadding.top + textPadding.bottom;

        if(label && label.text != "" && !label.hidden) {
            double pw = calcPinnedWidth(parentSize);    // If we are pinned we must use this as the max width
            Vector2 lSize = label.calcMinSize((pw, parentSize.y)) + (hPadding, vPadding);

            size.x = MIN(MAX(minSize.x, lSize.x), maxSize.x);
            size.y = MIN(MAX(minSize.y, lSize.y), maxSize.y);
        }

        return size;
    }

    override void setTextPadding(double left, double top, double right, double bottom) {
        Super.setTextPadding(left, top, right, bottom);

        // Add drop indicator size to padding
        if(label && dropIndicator) {
            textPins[2].offset = -(right + dropIndicator.tex.size.x);
        }
    }

    void conNav(UIControl ctrl, bool fromMouse, bool fromController) {
        if(!fromMouse) {
            dropScroll.scrollTo(ctrl, dropScroll.justOpened ? false : true);
        }
    }

    void conSelected(UIControl ctrl, bool fromMouse, bool fromController) {
        for(int x =0; x < itemButts.size(); x++) {
            if(itemButts[x] == ctrl) {
                if(selectedItem == x && !allowDuplicateSelection) {
                    close();    // Don't call back if we selected the existing selection
                    
                    if(!fromMouse) {
                        restoreActiveSelection();
                    }
                    return;
                }

                /*if(label) {
                    label.text = items[x];
                    requiresLayout = true;
                }

                selectedItem = x;*/
                setSelectedItem(x);
                sendEvent(UIHandler.Event_ValueChanged, fromMouse, fromController);
                
                close();

                // If not a mouse event, navigate to either the dropdown or it's forwarding view again
                if(!fromMouse) {
                    restoreActiveSelection();
                }
                return;
            }
        }
    }
}