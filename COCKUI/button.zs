class UIButtonState {
    int alignment;

    UITexture tex;
    NineSlice slices;
    string sound, mouseSound;
    float soundVolume, mouseSoundVolume;
    int textColor, backgroundColor;
    int blendColor;
    float desaturation;
    double texScale;

    void copyFrom(UIButtonState other) {
        alignment = other.alignment;
        tex = other.tex;
        slices = other.slices;
        self.sound = other.sound;
        mouseSound = other.mouseSound;
        soundVolume = other.soundVolume;
        mouseSoundVolume = other.mouseSoundVolume;
        textColor = other.textColor;
        backgroundColor = other.backgroundColor;
        blendColor = other.blendColor;
        desaturation = other.desaturation;
        texScale = other.texScale;
    }

    static UIButtonState Create(string tex, int textColor = 0, string sound = "", float soundVolume = 1.0, string mouseSound = "", float mouseSoundVolume = 1.0, int backgroundColor = 0) {
        UIButtonState bstate = new("UIButtonState");
        bstate.tex = UITexture.Get(tex);
        bstate.textColor = textColor;
        bstate.sound = sound;
        bstate.texScale = 1.0;
        bstate.soundVolume = soundVolume;
        bstate.backgroundColor = backgroundColor;

        // If not set, mouse sound and volume will adopt the sound and the minimum volume set
        // This seems weird but it allows you to set the mouse volume lower without having to specify the sound twice
        if(mouseSound == "") {
            bstate.mouseSound = "";
            bstate.mouseSoundVolume = MIN(soundVolume, soundVolume);
        } else {
            bstate.mouseSound = mouseSound;
            bstate.mouseSoundVolume = mouseSoundVolume;
        }

        bstate.blendColor = -1;
        bstate.desaturation = -1;
        
        return bstate;
    }

    static UIButtonState CreateSlices(string tex, Vector2 tl, Vector2 br, bool scaleSides = true, bool scaleCenter = true, bool drawCenter = true, int textColor = 0, string sound = "", double texScale = 1.0, float soundVolume = 1.0, string mouseSound = "", float mouseSoundVolume = 1.0) {
        UIButtonState bstate = new("UIButtonState");
        bstate.tex = UITexture.Get(tex);
        bstate.slices = NineSlice.Create(tex, tl, br, scaleSides, scaleCenter, drawCenter);
        bstate.texScale = texScale;
        bstate.textColor = textColor;
        bstate.sound = sound;
        bstate.soundVolume = soundVolume;

        // If not set, mouse sound and volume will adopt the sound and the minimum volume set
        // This seems weird but it allows you to set the mouse volume lower without having to specify the sound twice
        if(mouseSound == "") {
            bstate.mouseSound = "";
            bstate.mouseSoundVolume = MIN(soundVolume, soundVolume);
        } else {
            bstate.mouseSound = mouseSound;
            bstate.mouseSoundVolume = mouseSoundVolume;
        }

        bstate.blendColor = -1;
        bstate.desaturation = -1;

        return bstate;
    }
}


class UIButton : UIControl {
    enum ButtonState {
        State_Normal = 0,
        State_Hover, 
        State_Pressed,
        State_Selected,
        State_SelectedHover,
        State_SelectedPressed,
        State_Disabled,
        NUM_STATES
    };

    static const string StateDebugNames[] = {
        "Normal",
        "Hover",
        "Pressed",
        "Selected",
        "SelectedHover",
        "SelectedPressed",
        "Disabled",
        "Unknown"
    };
    
    ButtonState currentState;
    UIButtonState buttStates[NUM_STATES];
    UILabel label;
    Shape2DTransform shapeTransform;
    Shape2D drawShape;
    protected UIPadding textPadding;
    protected UIPin textPins[4];
    bool noFilter, pixelAlign;
    bool activateOnDownEvent;
    bool selected, mouseInside, requiresRebuild, doubleClickEnabled;
    bool menuSelected;          // Selected by menu system. When selected we stay highlighted even when the mouse exits
    int restoreCounter;         // Countdown after activation to restore to normal state
    int doubleClickCounter;

    Color blendColor;
    float desaturation;

    int imgStyle;
    int imgAnchor;
    Vector2 imgScale;

    Function<ui bool(Object, UIButton, bool, bool)> onDown, onUp, onClick, onSelect;
    Object receiver;

    const DOUBLE_CLICK_MAX_TICKS = 15;
    

    UIButton init(Vector2 pos, Vector2 size, string text, Font fnt,
                    UIButtonState normal,
                    UIButtonState hover = null,
                    UIButtonState pressed = null,
                    UIButtonState disabled = null,
                    UIButtonState selected = null,
                    UIButtonState selectedHover = null,
                    UIButtonState selectedPressed = null,
                    Alignment textAlign = Align_Centered,
                    Function<ui bool(Object, UIButton, bool, bool)> onClick = null,
                    Function<ui bool(Object, UIButton, bool, bool)> onDown = null,
                    Function<ui bool(Object, UIButton, bool, bool)> onUp = null,
                    Function<ui bool(Object, UIButton, bool, bool)> onUp = null,
                    Object receiver = null) {

        Super.Init(pos, size);

        buttStates[State_Normal] = normal;
        buttStates[State_Hover] = hover;
        buttStates[State_Pressed] = pressed;
        buttStates[State_Selected] = selected;
        buttStates[State_SelectedHover] = selectedHover;
        buttStates[State_SelectedPressed] = selectedPressed;
        buttStates[State_Disabled] = disabled;

        self.onUp = onUp;
        self.onDown = onDown;
        self.onClick = onClick;
        self.onSelect = onSelect;
        self.receiver = receiver;

        restoreCounter = -1;
        requiresRebuild = true;
        cancelsSubviewRaycast = true;
        imgStyle = UIImage.Image_Scale;
        imgScale = (1,1);
        imgAnchor = UIImage.ImageAnchor_Middle;

        if(fnt != null) {
            buildLabel(text, fnt, textAlign);
        }
        
        transitionToState(self.disabled ? State_Disabled : (self.selected ? State_Selected : State_Normal), false);

        doubleClickCounter = -1;

        return self;
    }


    override UIView baseInit() {
        Super.baseInit();

        restoreCounter = -1;
        requiresRebuild = true;
        cancelsSubviewRaycast = true;
        imgStyle = UIImage.Image_Scale;
        imgScale = (1,1);
        imgAnchor = UIImage.ImageAnchor_Middle;
        doubleClickCounter = -1;

        return self;
    }

    // Note: We are sharing references with the template, so don't change the states
    override void applyTemplate(UIView template) {
        Super.applyTemplate(template);
        UIButton t = UIButton(template);

        
        if(t) {
            currentState = t.currentState;
            for(int i = 0; i < NUM_STATES; i++) {
                buttStates[i] = t.buttStates[i];
            }
            textPadding.left = t.textPadding.left;
            textPadding.right = t.textPadding.right;
            textPadding.top = t.textPadding.top;
            textPadding.bottom = t.textPadding.bottom;
            noFilter = t.noFilter;
            activateOnDownEvent = t.activateOnDownEvent;
            selected = false;
            mouseInside = false;
            requiresRebuild = true;
            menuSelected = false;
            blendColor = t.blendColor;
            desaturation = t.desaturation;
            imgStyle = t.imgStyle;
            imgAnchor = t.imgAnchor;
            imgScale = t.imgScale;
            textPins[0] = textPins[1] = textPins[2] = textPins[3] = null;

            // We don't copy the callback functions
            receiver = null;

            // If the template had a label we find the copy in the new hierarchy
            if(t.label) {
                // Find the position in the subviews
                int idx = t.indexOf(t.label);
                if(idx >= 0) {
                    label = UILabel(subviews[idx]);
                    if(label) {
                        // Copy the pins from the template
                        textPins[0] = label.firstPin(UIPin.Pin_Left);
                        textPins[1] = label.firstPin(UIPin.Pin_Top);
                        textPins[2] = label.firstPin(UIPin.Pin_Right);
                        textPins[3] = label.firstPin(UIPin.Pin_Bottom);
                    } else {
                        Console.Printf("\c[RED]UIButton: Failed to recreate UILabel in subviews of UIButton template '%s'", template.getClassName());
                    }
                } else {
                    Console.Printf("\c[RED]UIButton: Failed to find UILabel in subviews of UIButton template '%s'", template.getClassName());
                }
            }
        }
    }


    virtual void buildLabel(string text,  Font fnt, Alignment textAlign = Align_Centered) {
        label = new("UILabel").init((0,0), frame.size, text, fnt, textAlign: textAlign, (1,1));
        add(label);

        textPins[0] = label.pin(UIPin.Pin_Left);
        textPins[1] = label.pin(UIPin.Pin_Top);
        textPins[2] = label.pin(UIPin.Pin_Right);
        textPins[3] = label.pin(UIPin.Pin_Bottom);
    }

    virtual void setTextPadding(double left = 0, double top = 0, double right = 0, double bottom = 0) {
        textPadding.left = left;
        textPadding.right = right;
        textPadding.top = top;
        textPadding.bottom = bottom;

        if(label) {
            textPins[0].offset = left;
            textPins[1].offset = top;
            textPins[2].offset = -right;
            textPins[3].offset = -bottom;
            label.requiresLayout = true;
            requiresLayout = true;
        }
    }

    protected virtual void transitionToState(int idx, bool sound = true, bool mouseSelection = false, bool controllerSelection = false) {
        if(currentState != idx) {
            requiresRebuild = true;
        }

        UIButtonState state = buttStates[idx];
    
        if(state) {
            if(currentState != idx && sound) {
                string snd = state.sound;
                float vol = mouseSelection ? state.mouseSoundVolume : state.soundVolume;
                if(mouseSelection && state.mouseSound != "") snd = state.mouseSound;
                if(vol > 0.0001) playSound(snd, vol);
            }

            if(label && state.textColor != 0) {
                label.textColor = state.textColor;
            }

            if(state.backgroundColor != 0 && !state.tex.isValid() && state.slices == null) {
                backgroundColor = state.backgroundColor;
            } else if((state.tex && state.tex.isValid()) || state.slices != null) {
                backgroundColor = 0;
            }

            if(state.desaturation != -1) {
                desaturation = state.desaturation;
            }

            if(state.blendColor != -1) {
                blendColor = state.blendColor;
            }
        }

        currentState = idx;
    }

    override void draw() {
        if(hidden) { return; }
        
        Super.draw();
        
        if(requiresRebuild) {
            buildShapes();
        }

        UIButtonState bstate = buttStates[currentState];
        UIBox b;
        boundingBoxToScreen(b);

        if(bstate && bstate.tex && bstate.slices && drawShape) {
            // Draw the draw shape
            shapeTransform.Clear();
            shapeTransform.Translate((floor(b.pos.x), floor(b.pos.y)));
            drawShape.SetTransform(shapeTransform);
            
            if(drawCanvas) {
                drawCanvas.drawShape(
                    bstate.tex.texID, 
                    true,
                    drawShape,
                    DTA_Alpha, cAlpha,
                    DTA_Filtering, !noFilter,
                    DTA_ColorOverlay, blendColor,
                    DTA_Desaturate, int(255.0 * desaturation)
                );
            } else {
                Screen.drawShape(
                    bstate.tex.texID, 
                    true,
                    drawShape,
                    DTA_Alpha, cAlpha,
                    DTA_Filtering, !noFilter,
                    DTA_ColorOverlay, blendColor,
                    DTA_Desaturate, int(255.0 * desaturation)
                );
            }
            
        } else if(bstate && bstate.tex) {
            // Draw texture
            let tex = bstate.tex;
            Vector2 pos, size;
            switch(imgStyle) {
                case UIImage.Image_Absolute:
                    size = (tex.size.x * imgScale.x * cScale.x, tex.size.y * imgScale.y * cScale.y);
                    pos = b.pos;
                    break;
                case UIImage.Image_Center:
                    size = (tex.size.x * imgScale.x * cScale.x, tex.size.y * imgScale.y * cScale.y);
                    pos = b.pos + (b.size / 2.0) - (size / 2.0);
                    break;
                case UIImage.Image_Aspect_Fill:
                    {
                        double aspect = tex.size.x / tex.size.y;
                        double target_aspect = b.size.x / b.size.y;

                        size = aspect > target_aspect ? (b.size.y * aspect, b.size.y) : (b.size.x, b.size.x / aspect);
                        size = (size.x * imgScale.x, size.y * imgScale.y);
                        pos = b.pos + (b.size / 2.0) - (size / 2.0);
                    }
                    break;
                case UIImage.Image_Aspect_Fit:
                    {
                        double aspect = tex.size.x / tex.size.y;
                        size = tex.size;

                        if(b.size.x < size.x) {
                            size *= b.size.x / size.x;
                        }

                        if(b.size.y < size.y) {
                            size *= b.size.y / size.y;
                        }
                        
                        switch(imgAnchor) {
                            case UIImage.ImageAnchor_TopLeft:
                                pos = b.pos;
                                break;
                            case UIImage.ImageAnchor_Top:
                                pos = b.pos + ((b.size.x / 2.0) - (size.x / 2.0), 0);
                                break;
                            case UIImage.ImageAnchor_TopRight:
                                pos = b.pos + (b.size.x - size.x, 0);
                                break;
                            case UIImage.ImageAnchor_Left:
                                pos = b.pos + (0, (b.size.y / 2.0) - (size.y / 2.0));
                                break;
                            case UIImage.ImageAnchor_Right:
                                pos = b.pos + (b.size.x - size.x, (b.size.y / 2.0) - (size.y / 2.0));
                                break;
                            case UIImage.ImageAnchor_BottomLeft:
                                pos = b.pos + (0, b.size.y - size.y);
                                break;
                            case UIImage.ImageAnchor_Bottom:
                                pos = b.pos + ((b.size.x / 2.0) - (size.x / 2.0), b.size.y - size.y);
                                break;
                            case UIImage.ImageAnchor_BottomRight:
                                pos = b.pos + (b.size.x - size.x, b.size.y - size.y);
                                break;
                            default:
                                pos = b.pos + (b.size / 2.0) - (size / 2.0);
                                break;
                        }
                    }
                    break;
                default:
                    pos = b.pos;
                    size = b.size;
                    break;
            }

            // Draw texture
            if(angle == 0) {
                if(drawCanvas) {
                    drawCanvas.DrawTexture(
                        tex.texID, 
                        true, 
                        floor(pos.x),
                        floor(pos.y),
                        DTA_DestWidthF, size.x,
                        DTA_DestHeightF, size.y,
                        DTA_Alpha, cAlpha,
                        DTA_ColorOverlay, blendColor,
                        DTA_Filtering, !noFilter,
                        DTA_Desaturate, int(255.0 * desaturation)
                    );
                } else {
                    Screen.DrawTexture(
                        tex.texID, 
                        true, 
                        floor(pos.x),
                        floor(pos.y),
                        DTA_DestWidthF, size.x,
                        DTA_DestHeightF, size.y,
                        DTA_Alpha, cAlpha,
                        DTA_ColorOverlay, blendColor,
                        DTA_Filtering, !noFilter,
                        DTA_Desaturate, int(255.0 * desaturation)
                    );
                }
            } else {
                Vector2 texsize = TexMan.GetScaledSize(tex.texID);
                Vector2 cpos = (rotCenter.x * texSize.x, rotCenter.y * texSize.y);

                if(drawCanvas) {
                    drawCanvas.DrawTexture(
                        tex.texID, 
                        true, 
                        floor(pos.x) + (rotCenter.x * size.x),
                        floor(pos.y) + (rotCenter.y * size.y),
                        DTA_DestWidthF, size.x,
                        DTA_DestHeightF, size.y,
                        DTA_Alpha, cAlpha,
                        DTA_ColorOverlay, blendColor,
                        DTA_Filtering, !noFilter,
                        DTA_Desaturate, int(255.0 * desaturation),
                        DTA_Rotate, angle,
                        DTA_LeftOffsetF, cPos.x,
                        DTA_TopOffsetF, cPos.y
                    );
                } else {
                    Screen.DrawTexture(
                        tex.texID, 
                        true, 
                        floor(pos.x) + (rotCenter.x * size.x),
                        floor(pos.y) + (rotCenter.y * size.y),
                        DTA_DestWidthF, size.x,
                        DTA_DestHeightF, size.y,
                        DTA_Alpha, cAlpha,
                        DTA_ColorOverlay, blendColor,
                        DTA_Filtering, !noFilter,
                        DTA_Desaturate, int(255.0 * desaturation),
                        DTA_Rotate, angle,
                        DTA_LeftOffsetF, cPos.x,
                        DTA_TopOffsetF, cPos.y
                    );
                }
            }
            
        }
    }

    override void tick() {
        Super.tick();

        if(restoreCounter > 0) {
            restoreCounter--;

            if(restoreCounter == 0) {
                restoreCounter = -1;

                if(!isDisabled()) {
                    if(mouseInside) {   // TODO: Fix this somehow. If hovered from menu select (keyboard controls) this will not restore correctly
                        transitionToState(selected ? State_SelectedHover : State_Hover, sound: false);
                    } else {
                        let m = getMenu();
                        if(m && m.activeControl == UIControl(self)) {
                            transitionToState(selected ? State_SelectedHover : State_Hover, sound: false);
                        } else {
                            transitionToState(selected ? State_Selected : State_Normal, sound: false);
                        }
                    }
                }
            }
        }

        if(doubleClickCounter > 0) {
            doubleClickCounter++;
        }
    }


    override void onMouseEnter(Vector2 screenPos) {
        mouseInside = true;

        if(disabled) {
            return;
        }

        if(selected) {
            if(currentState != State_SelectedHover && currentState != State_SelectedPressed) {
                transitionToState(State_SelectedHover, mouseSelection: true);
            }
        } else {
            if(currentState != State_Hover && currentState != State_Pressed) {
                transitionToState(State_Hover, mouseSelection: true);
            }
        }
    }

    override void onMouseExit(Vector2 screenPos, UIView newView) {
        mouseInside = false;
        doubleClickCounter = -1;

        // Don't change state if we are still the selected control
        if(menuSelected || disabled) {
            return;
        }

        if(selected) {
            if(currentState != State_Selected) {
                transitionToState(State_Selected, mouseSelection: true);
            }
        } else {
            if(currentState != State_Normal) {
                transitionToState(State_Normal, mouseSelection: true);
            }
        }
    }

    override void onMouseUp(Vector2 screenPos) {
        if(disabled) { return; }

        if(mouseInside) {
            // Transition to state first, in case the handler changes our state manually
            transitionToState(selected ? State_SelectedHover : State_Hover, sound: false);

            // This is a full button press!
            if(!activateOnDownEvent) {
                if(onUp == null || !onUp.call(receiver, self, true, false)) {
                    if(onClick == null || !onClick.call(receiver, self, true, false)) 
                        sendEvent(UIHandler.Event_Activated, true);
                    else return;    // Don't send double click event if we consumed the click
                }
            }

            if(doubleClickEnabled && doubleClickCounter > 0 && doubleClickCounter < DOUBLE_CLICK_MAX_TICKS) {
                sendEvent(UIHandler.Event_Alternate_Activate, true);
            } else if(doubleClickEnabled && doubleClickCounter == 0) {
                doubleClickCounter = 1;
            } else if(doubleClickEnabled && doubleClickCounter >= DOUBLE_CLICK_MAX_TICKS) {
                doubleClickCounter = 1;
            }
            
        } else {
            doubleClickCounter = -1;
            transitionToState(selected ? State_Selected : State_Normal, mouseSelection: true);
        }
    }

    override void onMouseDown(Vector2 screenPos) {
        mouseInside = true;
        if(!disabled) {
            transitionToState(selected ? State_SelectedPressed : State_Pressed, mouseSelection: true);
            
            if(doubleClickEnabled) {
                doubleClickCounter++;
            } else if(activateOnDownEvent) {
                if(onDown == null || !onDown.call(receiver, self, true, false)) {
                    if(onClick == null || !onClick.call(receiver, self, true, false)) 
                        sendEvent(UIHandler.Event_Activated, true);
                }
            }
        }
    }

    override void onSelected(bool mouseSelection, bool controllerSelection) {
        menuSelected = true;

        if(!disabled) {    
            transitionToState(selected ? State_SelectedHover : State_Hover, mouseSelection: mouseSelection, controllerSelection: controllerSelection);

            if(onSelect) {
                onSelect.call(receiver, self, mouseSelection, controllerSelection);
            }
        }

        Super.onSelected(mouseSelection, controllerSelection);
    }

    override void onDeselected() {
        Super.onDeselected();

        menuSelected = false;

        if(/*!mouseInside && */!disabled && (selected ? currentState != State_Selected : currentState != State_Normal)) {
            transitionToState(selected ? State_Selected : State_Normal);

            if(handler) {
                handler.handleEvent(UIHandler.Event_Deselected, self, false);
            }
        }
    }


    override bool onActivate(bool mouseSelection, bool controllerSelection) {
        if(!disabled) {
            transitionToState(selected ? State_SelectedPressed : State_Pressed, mouseSelection: mouseSelection);
            restoreCounter = 5;

            if(onClick == null || !onClick.call(receiver, self, mouseSelection, controllerSelection))
                sendEvent(UIHandler.Event_Activated, mouseSelection, controllerSelection);

            return true;
        }

        return false;
    }

    void buildShapes() {
        // If necessary clear and create shape
        UIButtonState bstate = buttStates[currentState];
        
        if(bstate && bstate.slices) {
            if(!drawShape) {
                UIMenu m = getMenu();
                drawShape = m ? m.recycler.getShape() : new("Shape2D");
            }

            if(!shapeTransform) {
                shapeTransform = new("Shape2DTransform");
            }

            drawShape.clear();
            UIBox b;
            boundingBoxToScreen(b);
            bstate.slices.buildShape(drawShape, (0,0), b.size, cScale, usePixelBoundary: pixelAlign);
        }

        requiresRebuild = false;
    }

    override bool onAnimationStep() {
        // TODO: Check to make sure that the frame has actually changed since the last animation step
        requiresRebuild = true;

        // Check for mouse positioning, if the mouse was previously inside this button, it may have escaped between mouse move events
        if(mouseInside) {
            let m = getMenu();
            if(m) m.testMouse(m.mouseX, m.mouseY);    // Will call mouseExit if no longer inside
        }

        return false;
    }

    override Vector2 calcMinSize(Vector2 parentSize) {
        Vector2 size = minSize;
        double hPadding = textPadding.left + textPadding.right;
        double vPadding = textPadding.top + textPadding.bottom;

        if(label && !label.hidden) {
            double pw = calcPinnedWidth(parentSize);    // If we are pinned we must use this as the max width
            Vector2 lSize = label.calcMinSize((pw, parentSize.y)) + (hPadding, vPadding);
            
            size.x = MIN(MAX(minSize.x, lSize.x), maxSize.x);
            size.y = MIN(MAX(minSize.y, lSize.y), maxSize.y);
        }

        return size;
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        Super.layout(parentScale, parentAlpha);

        buildShapes();
    }

    override void onAdjustedPostLayout(UIView sourceView) {
        Super.onAdjustedPostLayout(sourceView);
        requiresRebuild = true;
    }

    override void setDisabled(bool disable) {
        disabled = disable;

        if(disabled) {
            if(currentState != State_Disabled) { transitionToState(State_Disabled); }
        } else {
            if(selected) {
                if(mouseInside) {
                    if(currentState != State_SelectedHover) { transitionToState(State_SelectedHover, mouseSelection: true); }
                } else {
                    if(currentState != State_Selected) { transitionToState(State_Selected); }
                }
            } else {
                if(mouseInside) {
                    if(currentState != State_Hover) { transitionToState(State_Hover, mouseSelection: true); }
                } else {
                    if(currentState != State_Normal) { transitionToState(State_Normal); }
                }
            }
        }
    }


    void setSelected(bool s = true, bool sound = true) {
        if(s != selected) {
            selected = s;

            if(!disabled) {
                if(selected) {
                    if(mouseInside || currentState == State_Hover || currentState == State_SelectedHover) {
                        transitionToState(currentState == State_Pressed ? State_SelectedPressed : State_SelectedHover, sound, mouseSelection: true);
                    } else {
                        transitionToState(State_Selected, sound);
                    }
                } else {
                    if(mouseInside || currentState == State_Hover || currentState == State_SelectedHover) {
                        transitionToState(currentState == State_SelectedPressed ? State_Pressed : State_Hover, sound, mouseSelection: true);
                    } else {
                        transitionToState(State_Normal, sound);
                    }
                }
            }
        }
    }

    override void teardown(UIRecycler recycler) {
        Super.teardown(recycler);
        if(drawShape && recycler) {
            recycler.recycleShape(drawShape);
            drawShape = null;
        }
    }

    bool isSelected(int sstate = (-1)) {
        if(sstate == -1) sstate = currentState;
        return sstate == State_Selected || sstate == State_SelectedHover || sstate == State_SelectedPressed;
    }
}