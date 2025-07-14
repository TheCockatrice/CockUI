// A horizontal bar of selectable buttons
class UIButtonBar : UIControl {
    Array<string> items;
    Array<UIButton> itemButts;
    protected int selectedItem;
    UIButtonState buttStates[UIButton.NUM_STATES];
    UIImage bgImage;
    Font fnt;
    UIPadding padding;
    int spacing;

    /*static UIButtonBar Create(Vector2 pos, Vector2 size, Array<string> items, Font fnt,
                                NineSlice bgSlices = null,
                                UIButtonState normal = null,
                                UIButtonState hover = null,
                                UIButtonState pressed = null,
                                UIButtonState disabled = null,
                                UIButtonState selected = null,
                                UIButtonState selectedHover = null,
                                UIButtonState selectedPressed = null) {
        let bb = new("UIButtonBar");
        bb.spacing = 4;
        bb.buttStates[UIButton.State_Normal] = normal;
        bb.buttStates[UIButton.State_Hover] = hover;
        bb.buttStates[UIButton.State_Pressed] = pressed;
        bb.buttStates[UIButton.State_Disabled] = disabled;
        bb.buttStates[UIButton.State_Selected] = selected;
        bb.buttStates[UIButton.State_SelectedHover] = selectedHover;
        bb.buttStates[UIButton.State_SelectedPressed] = selectedPressed;
        bb.items.append(items);
        bb.fnt = fnt;
        
        bb.init();

        if(bgSlices) {
            bb.setBackground(bgSlices);
        }

        return bb;
    }*/

    UIButtonBar init(Vector2 pos, Vector2 size, Array<string> items, Font fnt,
                        NineSlice bgSlices = null,
                        UIButtonState normal = null,
                        UIButtonState hover = null,
                        UIButtonState pressed = null,
                        UIButtonState disabled = null,
                        UIButtonState selected = null,
                        UIButtonState selectedHover = null,
                        UIButtonState selectedPressed = null) {
        Super.init(pos, size);

        spacing = 4;
        buttStates[UIButton.State_Normal] = normal;
        buttStates[UIButton.State_Hover] = hover;
        buttStates[UIButton.State_Pressed] = pressed;
        buttStates[UIButton.State_Disabled] = disabled;
        buttStates[UIButton.State_Selected] = selected;
        buttStates[UIButton.State_SelectedHover] = selectedHover;
        buttStates[UIButton.State_SelectedPressed] = selectedPressed;
        self.items.append(items);
        self.fnt = fnt;

        buildButtons();

        requiresLayout = true;

        if(bgSlices) {
            setBackground(bgSlices);
        }

        return self;
    }

    void setBackground(NineSlice slices) {
        if(bgImage) {
            bgImage.setSlices(slices);
        } else {
            bgImage = new("UIImage").init((0,0), (0,0), "", slices);
            bgImage.pinToParent();
            add(bgImage);
            moveToBack(bgImage);
        }
    }

    void setSelectedItem(int selected) {
        selectedItem = selected;

        for(int x = 0; x < itemButts.size(); x++) {
            itemButts[x].setDisabled(x == selected);
            itemButts[x].requiresRebuild = true;
        }
    }

    int getSelectedItem() {
        return selectedItem;
    }

    bool selectNext() {
        if(items.size() == 0) { return false; }

        selectedItem++;
        if(selectedItem >= items.size()) {
            selectedItem = 0;
        }
        setSelectedItem(selectedItem);

        return true;
    }

    bool selectPrevious() {
        if(items.size() == 0) { return false; }

        selectedItem--;
        if(selectedItem < 0) {
            selectedItem = items.size() - 1;
        }
        setSelectedItem(selectedItem);

        return true;
    }

    void buildButtons() {
        // Remove unecessary buttons
        for(int x = items.size(); x < itemButts.size(); x++) {
            itemButts[x].removeFromSuperview();
            itemButts[x].Destroy();
        }
        for(int x = itemButts.size() - 1; x > items.size(); x--) {
            itemButts.pop();
        }

        // Build and configure butts
        for(int x = 0; x < items.size(); x++) {
            if(itemButts.size() <= x) {
                UIButton b = new("UIButton").init(
                    (0,0), (100, frame.size.y), items[x], fnt,
                    buttStates[UIButton.State_Normal],
                    buttStates[UIButton.State_Hover],
                    buttStates[UIButton.State_Pressed],
                    buttStates[UIButton.State_Disabled],
                    buttStates[UIButton.State_Selected],
                    buttStates[UIButton.State_SelectedHover],
                    buttStates[UIButton.State_SelectedPressed]
                );
                b.label.multiline = false;
                itemButts.push(b);
                add(b);
            } else {
                itemButts[x].label.setText(items[x]);
            }
        }

        requiresLayout = true;
    }

    void setItems(Array<string> newItems, int selected = 0) {
        items.clear();
        items.append(newItems);

        selectedItem = selected;
        requiresLayout = true;

        buildButtons();
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        cScale = (parentScale ~== (0,0) ? calcScale() : (parentScale.x * scale.x, parentScale.y * scale.y));
        cAlpha = (parentAlpha == -1 ? calcAlpha() : parentAlpha) * alpha;

        // Process anchor pins
        processPins();

        frame.size.x = floor(frame.size.x);
        frame.size.y = floor(frame.size.y);
        requiresLayout = false;

        // Layout buttons, which have no pins so the laying out subviews should not override this
        int numButts = itemButts.size();
        
        if(numButts > 0) {
            float totalRequiredSize = padding.left - spacing;
            Array<float> sizes;

            // First get the total required size
            for(int x = 0; x < numButts; x++) {
                Vector2 vs = itemButts[x].calcMinSize((99999, frame.size.y));
                float size = spacing + vs.x;
                sizes.push(vs.x);
                totalRequiredSize += size;
            }
            totalRequiredSize += padding.right;

            // Extra bonus size to add to each element
            float bonus = floor((frame.size.x - totalRequiredSize) / double(numButts));
            float posX = padding.left;
            float sizey = frame.size.y - (padding.top + padding.bottom);
            for(int x = 0; x < numButts; x++) {
                itemButts[x].frame.pos.x = posX;
                itemButts[x].frame.pos.y = padding.top;
                if(x == numButts - 1) {
                    itemButts[x].frame.size = (frame.size.x - posX, sizey);
                } else {
                    itemButts[x].frame.size = (sizes[x] + bonus, sizey);
                    posX += spacing + sizes[x] + bonus;
                }
            }
        }

        layoutSubviews();
    }

    override bool handleSubControl(UIControl ctrl, int event, bool fromMouse, bool fromController) {
        if(event == UIHandler.Event_Activated) {
            for(int x = 0; x < itemButts.size(); x++) {
                if(ctrl == itemButts[x]) {
                    setSelectedItem(x);
                    
                    sendEvent(UIHandler.Event_ValueChanged, fromMouse, fromController);
                    return true;
                }
            }
        }

        return Super.handleSubControl(ctrl, event, fromMouse, fromController);
    }
}