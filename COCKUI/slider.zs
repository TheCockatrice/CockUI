class UISliderButton : UIButton {
    bool holding;
    Vector2 lastMousePos;

    UISliderButton init(    Vector2 pos, Vector2 size,
                            UIButtonState normal,
                            UIButtonState hover = null,
                            UIButtonState pressed = null,
                            UIButtonState disabled = null,
                            UIButtonState selected = null,
                            UIButtonState selectedHover = null,
                            UIButtonState selectedPressed = null) {

        Super.init(pos, size, "", null, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed);

        return self;
    }

    override void onMouseDown(Vector2 screenPos) {
        Super.onMouseDown(screenPos);

        if(disabled) { return; }

        lastMousePos = screenPos;
        holding = true;
        
        let m = getMenu();
        if(m) m.startDragging(self);
    }

    override void onMouseUp(Vector2 screenPos) {
        if(holding) mouseInside = raycastTest(screenPos);

        Super.onMouseUp(screenPos);

        lastMousePos = screenPos;
        holding = false;
        
        UISlider slider = UISlider(parent);
        if(slider) {
            slider.updateSlidePos();
        }

        let m = getMenu();
        if(m) m.stopDragging(self);
    }

    override void onMouseExit(Vector2 screenPos, UIView newView) {
        //mouseInside = false;

        if(disabled) {
            return;
        }

        if(!holding) {
            Super.onMouseExit(screenPos, newView);
        }
    }

    override bool event(ViewEvent ev) {
        if(ev.type == UIEvent.Type_MouseMove && holding) {
            // Send drag event to slider
            UISlider slider = UISlider(parent);

            if(slider) {
                let mpos = (ev.MouseX, ev.MouseY);
                let mdelta = mpos - lastMousePos;
                mdelta.x /= parent.cScale.x;
                mdelta.y /= parent.cScale.y;
                slider.dragEvent(mdelta, mpos);
                lastMousePos = mpos;

                return true;
            }
        }

        return Super.event(ev); 
    }
}


class UISlider : UIControl {
    double value, prevValue;
    double increment, pageIncrement;
    double minVal, maxVal;
    double slidePos;

    bool isVertical;        // Default to horizontal
    bool scaleButton;       // Scale the button to buttonFactor?
    bool forceIncrement;    // Force values in the increment when dragging
    double buttonSize;      // Height or width depending
    double buttonScrollSize, minButtonScrollSize;
    double buttonFactor;    // size factor of button compared to content size (mostly for scrollbars)
    bool selectButtonOnFocus;

    UIImage bgImage, slideImage;
    UISliderButton slideButt;
    UIPin slideImagePin;

    bool buttNeedsLayout;

    UISlider init(  Vector2 pos, Vector2 size,
                    double minVal, double maxVal, double increment,
                    NineSlice bgSlices, NineSlice slideSlices,
                    UIButtonState normal,
                    UIButtonState hover = null,
                    UIButtonState pressed = null,
                    UIButtonState disabled = null,
                    UIButtonState selected = null,
                    UIButtonState selectedHover = null,
                    UIButtonState selectedPressed = null,
                    bool isVertical = false ) {

        Super.init(pos, size);

        prevValue = value = 0;

        self.minVal = minVal;
        self.maxVal = maxVal;
        self.increment = increment;
        self.pageIncrement = increment;
        buttonSize = 24;
        self.isVertical = isVertical;
        build(
            bgSlices, slideSlices,
            normal,
            hover,
            pressed,
            disabled,
            selected,
            selectedHover,
            selectedPressed
        );
        requiresLayout = true;

        return self;
    }

    virtual void build( NineSlice bgSlices, NineSlice slideSlices,
                        UIButtonState normal,
                        UIButtonState hover = null,
                        UIButtonState pressed = null,
                        UIButtonState disabled = null,
                        UIButtonState selected = null,
                        UIButtonState selectedHover = null,
                        UIButtonState selectedPressed = null) {

        makeBackgroundImage(bgSlices);
        if(slideSlices) {
            makeSlideImage(slideSlices);
        }

        slideButt = new("UISliderButton").init((0,0), (16, 40),
            normal,
            hover,
            pressed,
            disabled,
            selected,
            selectedHover,
            selectedPressed
        );
        slideButt.rejectHoverSelection = true;
        slideButt.forwardSelection = self;
        buttonScrollSize = slideButt.frame.size.x;
        //slideButt.ignoresClipping = true;
        clipsSubviews = false;
        buttNeedsLayout = true;
        
        add(slideButt);
    }

    override UIView baseInit() {
        Super.baseInit();

        // Set default values
        value = 0;
        prevValue = 0;
        increment = 1;
        pageIncrement = 10;
        minVal = 0;
        maxVal = 100;
        buttonSize = 24;
        buttonScrollSize = 16;
        minButtonScrollSize = 0;
        isVertical = false;
        scaleButton = false;
        forceIncrement = false;
        selectButtonOnFocus = false;
        buttNeedsLayout = true;

        return self;
    }

    virtual void makeBackgroundImage(NineSlice bgSlices) {
        bgImage = new("UIImage").init((0,0), (0,0), "", bgSlices);
        bgImage.pinToParent();
        bgImage.raycastTarget = false;
        add(bgImage);
    }

    virtual void makeSlideImage(NineSlice slideSlices) {
        // TODO: Allow a image for vertical bars too eventually
        if(slideSlices && !isVertical) {
            slideImage = new("UIImage").init((0,0), (0,0), "", slideSlices);
            slideImage.pin(UIPin.Pin_Left);
            slideImagePin = slideImage.pin(UIPin.Pin_Right, UIPin.Pin_Left);
            slideImage.pin(UIPin.Pin_Top);
            slideImage.pin(UIPin.Pin_Bottom);
            slideImage.raycastTarget = false;
            add(slideImage);
        }
    }

    override void onSelected(bool mouseSelection) {
        if(selectButtonOnFocus) slideButt.selected = true;
        slideButt.onSelected(mouseSelection);
        Super.onSelected(mouseSelection);
    }

    override void onDeselected() {
        if(selectButtonOnFocus) slideButt.selected = false;
        slideButt.onDeselected();
        Super.onDeselected();
    }


    virtual void setValue(double val, bool moveButt = false, bool clampValue = false) {
        prevValue = value;
        value = val;

        if(clampValue) {
            value = clamp(val, minVal, maxVal);
        }
        
        if(moveButt) {
            updateSlidePos();
        }
    }

    virtual double getNormalizedValue() {
        return (value - minVal) / (maxVal - minVal);
    }

    virtual double getNormalizedPotential(double value) {
        return (value - minVal) / (maxVal - minVal);
    }
    
    virtual void setNormalizedValue(double t, bool moveButt = false) {
        prevValue = value;
        value = minVal + t * (maxVal - minVal);
        if(moveButt) {
            updateSlidePos();
        }
    }

    void updateSlidePos() {
        if((isVertical ? frame.size.y : frame.size.x) > 0) {
            slidePos = (getNormalizedValue() * ((isVertical ? frame.size.y : frame.size.x) - buttonScrollSize)) / (isVertical ? frame.size.y : frame.size.x);
        } else {
            slidePos = 0;
        }
        
        buttNeedsLayout = true;
    }

    override void tick() {
        Super.tick();

        if(buttNeedsLayout) {
            layoutButton();
        }
    }

    override void draw() {
        if(buttNeedsLayout && !requiresLayout) {
            layoutButton();
        }

        Super.draw();
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        cScale = (parentScale ~== (0,0) ? calcScale() : (parentScale.x * scale.x, parentScale.y * scale.y));
        cAlpha = (parentAlpha == -1 ? calcAlpha() : parentAlpha) * alpha;

        // Process anchor pins
        processPins();
        
        layingOutSubviews = true;

        // Layout subviews
        for(int i = 0; i < subviews.size(); i++) {
            if(subviews[i] == slideButt) { continue; }
            if(subviews[i] == slideImage) { continue; }
            subviews[i].layout(cScale, cAlpha);
        }
        
        updateSlidePos();
        layoutButton();

        requiresLayout = false;
        layingOutSubviews = false;
    }

    void layoutButton() {
        // Layout the BG
        double normValue = clamp(getNormalizedValue(), 0.0, 1.0);
        if(slideImage && slideImagePin) {
            if(isVertical) {
                slideImagePin.value = ((normValue * frame.size.y) / (frame.size.y - buttonScrollSize));
            } else {
                slideImagePin.offset = (normValue * (frame.size.x - buttonScrollSize)) + buttonScrollSize;
            }
            slideImage.layout(cScale, cAlpha);
        }

        // Layout the button
        if(isVertical) {
            slideButt.frame.size.x = buttonSize;
            slideButt.frame.pos.x = (frame.size.x * 0.5) - (slideButt.frame.size.x * 0.5);
            slideButt.frame.size.y = buttonScrollSize;

            slideButt.frame.pos.y = max(0.0, min(slidePos * frame.size.y, frame.size.y - buttonScrollSize));
        } else {
            slideButt.frame.size.y = buttonSize;
            slideButt.frame.pos.y = (frame.size.y * 0.5) - (slideButt.frame.size.y * 0.5);
            slideButt.frame.size.x = buttonScrollSize;

            
            slideButt.frame.pos.x = max(0.0, min(slidePos * frame.size.x, frame.size.x - buttonScrollSize));
        }

        slideButt.layout(cScale, cAlpha);
        buttNeedsLayout = false;
    }

    void dragEvent(Vector2 mdelta, Vector2 mpos) {
        if(disabled) { return; }
        
        
        if(isVertical) {
            if((frame.size.y - buttonScrollSize) ~== 0) {
                setNormalizedValue(0);
            } else {
                slidePos = ((slidePos * frame.size.y) + mdelta.y) / frame.size.y;
                double a = (slidePos * frame.size.y) / (frame.size.y - buttonScrollSize);
                a = max(0.0, min(a, 1.0));
                setNormalizedValue( a );
            }
        } else {
            if((frame.size.x - buttonScrollSize) ~== 0) {
                setNormalizedValue(0);
            } else {
                slidePos = ((slidePos * frame.size.x) + mdelta.x) / frame.size.x;
                double a = (slidePos * frame.size.x) / (frame.size.x - buttonScrollSize);
                a = max(0.0, min(a, 1.0));
                setNormalizedValue( a );
            }
        }

        sendEvent(UIHandler.Event_ValueChanged, true);
        layoutButton();
    }

    override void onMouseDown(Vector2 screenPos) {
        Super.onMouseDown(screenPos);

        if(disabled) { return; }

        // Move the slider to the relative pos
        Vector2 apos = screenToRel(screenPos);
        if(isVertical) {
            setNormalizedValue( max(0.0, min(apos.y / frame.size.y, 1.0)) );
            //slidePos = getNormalizedValue();
            updateSlidePos();
        } else {
            setNormalizedValue( max(0.0, min(apos.x / frame.size.x, 1.0)) );
            //slidePos = getNormalizedValue();
            updateSlidePos();
        }

        sendEvent(UIHandler.Event_ValueChanged, true);

        layoutButton();
    }

    void increase(double amount = -9999) {
        if(amount == -9999) { amount = increment; }

        prevValue = value;
        if(minVal < maxVal) {
            value = clamp(value + amount, minVal, maxVal);
        } else {
            value = clamp(value + amount, maxVal, minVal);
        }
        
        updateSlidePos();
        layoutButton();
    }

    void decrease(double amount = -9999) {
        if(amount == -9999) { amount = increment; }

        prevValue = value;
        if(minVal < maxVal) {
            value = clamp(value - amount, minVal, maxVal);
        } else {
            value = clamp(value - amount, maxVal, minVal);
        }

        updateSlidePos();
        layoutButton();
    }

    override bool MenuEvent(int mkey, bool fromcontroller) {
        if(isVertical) {
            if(mkey == Menu.MKEY_Up) {
                decrease();
                sendEvent(UIHandler.Event_ValueChanged, false, fromController);
                return true;
            }

            if(mkey == Menu.MKEY_Down) {
                increase();
                sendEvent(UIHandler.Event_ValueChanged, false, fromController);
                return true;
            }
        } else {
            if(mkey == Menu.MKEY_Left) {
                decrease();
                sendEvent(UIHandler.Event_ValueChanged, false, fromController);
                return true;
            }

             if(mkey == Menu.MKEY_Right) {
                increase();
                sendEvent(UIHandler.Event_ValueChanged, false, fromController);
                return true;
            }            
        }

        if(mkey == Menu.MKEY_PageUp) {
            decrease(pageIncrement);
            sendEvent(UIHandler.Event_ValueChanged, false, fromController);
            return true;
        }

        if(mkey == Menu.MKEY_PageDown) {
            increase(pageIncrement);
            sendEvent(UIHandler.Event_ValueChanged, false, fromController);
            return true;
        }

        return Super.MenuEvent(mkey, fromcontroller);
    }


    override void setDisabled(bool disable) {
        Super.setDisabled(disable);

        slideButt.setDisabled(disable);
    }
}