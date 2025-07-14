class UIOSKTemplate {
    Font buttonFont;
    Vector2 buttonFontScale;
    String buttonSound, deleteSound, errorSound, okSound;
    UIbuttonState stateNorm, stateHigh, stateDown, stateSelected, stateSelectedDown, stateSelectedHigh, stateDisabled;
    UIbuttonState ctrlStateNorm, ctrlStateHigh, ctrlStateDown, ctrlStateSelected, ctrlStateSelectedDown, ctrlStateSelectedHigh, ctrlStateDisabled;
    Color backgroundColor;
    double maxHeight, screenHeightFactor;
}

class UIInputText : UIControl {
    enum InputTextEvent {
        StartedEditing    = 128,
        StoppedEditing,
        OpenedVirtualKeyboard,
        ClosedVirtualKeyboard
    }

    UIImage background, highlight;
    UILabel label;
    bool requireValue, numeric, allowDecimal;
    int charLimit;
    bool mouseInside, mouseDown;
    Font inputFont;                 // Font used for virtual keyboard, defaults to BIGFONT
    UIOSKTemplate oskTemplate;

    UITextEnterMenu textEnterMenu;

    protected UIPadding textPadding;
    protected UIPin textPins[4];

    bool editing;

    UIInputText init(Vector2 pos, Vector2 size, string text, Font fnt, int textColor = 0xFFFFFFFF, Alignment textAlign = Align_TopLeft, Vector2 fontScale = (1,1)) {
        Super.init(pos, size);
        inputFont = "BIGFONT";

        label = new("UILabel").init((0,0), (100, 50), text, fnt, textColor, textAlign, fontScale);
        add(label);

        textPins[0] = label.pin(UIPin.Pin_Left);
        textPins[1] = label.pin(UIPin.Pin_Top);
        textPins[2] = label.pin(UIPin.Pin_Right);
        textPins[3] = label.pin(UIPin.Pin_Bottom);

        cancelsHoverDeSelect = true;

        return self;
    }

    int getCursorPos() {
        return label.getCursorPos();
    }

    void setCursorPos(int pos) {
        label.setCursorPos(pos);
        requiresLayout = true;
    }

    void setBackgroundImage(string img, int imgStyle = UIImage.Image_Scale, Vector2 imgScale = (1,1), int imgAnchor = UIImage.ImageAnchor_Middle) {
        if(!background) {
            background = new("UIImage").init((0,0), (1,1), img, imgStyle: imgStyle, imgScale: imgScale, imgAnchor: imgAnchor);
            background.pinToParent();
            add(background);
            moveToBack(background);
        } else {
            background.setImage(img);
            background.imgStyle = imgStyle;
            background.imgScale = imgScale;
            background.imgAnchor = imgAnchor;
        }
    }

    void setBackgroundSlices(string img, NineSlice slice) {
        if(!background) {
            background = new("UIImage").init((0,0), (1,1), img, slice);
            background.pinToParent();
            add(background);
            moveToBack(background);
        } else {
            background.setImage(img);
            background.setSlices(slice);
        }
    }

    void setHighlightImage(string img, UIPadding padding, int imgStyle = UIImage.Image_Scale, Vector2 imgScale = (1,1), int imgAnchor = UIImage.ImageAnchor_Middle) {
        if(!highlight) {
            highlight = new("UIImage").init((0,0), (1,1), img, imgStyle: imgStyle, imgScale: imgScale, imgAnchor: imgAnchor);
            highlight.pinToParent();
            highlight.ignoresClipping = true;
            add(highlight);
            if(background) moveInfront(highlight, background);
            else moveToBack(highlight);
        } else {
            highlight.setImage(img);
            highlight.imgStyle = imgStyle;
            highlight.imgScale = imgScale;
            highlight.imgAnchor = imgAnchor;
        }

        highlight.hidden = !activeSelection;
    }

    void setHighlightSlices(string img, NineSlice slice, UIPadding padding) {
        if(!highlight) {
            highlight = new("UIImage").init((0,0), (1,1), img, slice);
            highlight.pinToParent(padding.left, padding.top, -padding.right, -padding.bottom);
            highlight.ignoresClipping = true;
            add(highlight);
            if(background) moveInfront(highlight, background);
            else moveToBack(highlight);
        } else {
            highlight.setImage(img);
            highlight.setSlices(slice);
            highlight.firstPin(UIPin.Pin_Left).offset = padding.left;
            highlight.firstPin(UIPin.Pin_Top).offset = padding.top;
            highlight.firstPin(UIPin.Pin_Right).offset = -padding.right;
            highlight.firstPin(UIPin.Pin_Bottom).offset = -padding.bottom;
        }

        highlight.hidden = !activeSelection;
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
        }
    }

    override void onSelected(bool mouseSelection, bool controllerSelection) {
        if(highlight) highlight.hidden = false;
        Super.onSelected(mouseSelection, controllerSelection);
    }

    override void onDeselected() {
        if(highlight) highlight.hidden = true;
        if(textEnterMenu) deactivate();
        else setCursorPos(-1);
        Super.onDeselected();
    }

    override Vector2 calcMinSize(Vector2 parentSize) {
        Vector2 size = minSize;
        double hPadding = textPadding.left + textPadding.right;
        double vPadding = textPadding.top + textPadding.bottom;

        Vector2 lSize = (0,0);
        
        if(label) {
            double width = calcPinnedWidth(parentSize);

            lSize = label.calcMinSize((width, parentSize.y)) + (hPadding, vPadding);
        }

        size.x = MIN(MAX(minSize.x, lSize.x), maxSize.x);
        size.y = MIN(MAX(minSize.y, lSize.y), maxSize.y);

        return size;
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        Super.layout(parentScale, parentAlpha);
    }

    override bool onActivate(bool mouseSelection, bool controllerSelection) {
        Super.onActivate(mouseSelection, controllerSelection);

        if(!disabled) {
            moveCursorToEnd();
            if(!textEnterMenu) {
                // Send event first, so event handlers can potentially change topology when changing text/input fields
                sendEvent(StartedEditing, mouseSelection, controllerSelection);
                textEnterMenu = UITextEnterMenu.present(self, controllerSelection, oskTemplate);
                
                return true;
            }
        }

        return false;
    }

    virtual void deactivate() {
        if(textEnterMenu) {
            textEnterMenu.close();
            textEnterMenu = null;
        }
        setCursorPos(-1);
    }

    // Input menu cancelled and closed
    virtual void inputCancelled(bool fromMouse, bool fromController) {
        textEnterMenu.close();
        textEnterMenu = null;
        setCursorPos(-1);
        sendEvent(StoppedEditing, fromMouse, fromController);
    }

    /*verride void onDeselected() {
        Super.onDeselected();

        // If the text enter menu is up, it must be closed
        // but we don't know what changed selection, so we can't relay the correct event information
        if(textEnterMenu) {
            textEnterMenu.close();
            textEnterMenu = null;
            setCursorPos(-1);
            sendEvent(StoppedEditing, false, false);
        }
    }*/

    void setText(string newText) {
        label.setText(newText);
    }

    string getText() {
        return label.text;
    }

    bool isMultiline() {
        return label.multiline;
    }

    void setMultiline(bool multiline) {
        if(label.multiline != multiline) {
            label.multiline = multiline;
            label.requiresLayout = true;
            requiresLayout = true;
        }
    }

    void appendCharacter(int newChar, bool fromController = false, bool send = true) {
        if(numeric) {   // Prevent non-numeric characters if this is a number field
            if(newChar < 48 || newChar > 57) {
                if(!allowDecimal || newChar != 46) return;
            }
        }

        // Enforce char limit
        if(charLimit > 0 && int(label.text.length()) >= charLimit) return;
        
        int cursorPos = getCursorPos();
        if(cursorPos == -1 || cursorPos == label.text.length()) {
            label.text.appendCharacter(newChar);
        } else {
            label.text = String.Format( "%s%c%s",
                                        cursorPos > 0 ? label.text.mid(0, cursorPos) : "", 
                                        newChar,
                                        cursorPos < int(label.text.length()) ? label.text.mid(cursorPos) :  "");
        }
        
        if(cursorPos == label.text.length() - 1) moveCursorToEnd();
        else cursorRight();
        label.requiresLayout = true;
        requiresLayout = true;

        if(send) sendEvent(UIHandler.Event_ValueChanged, false, fromController);
    }

    bool backspace(bool fromMouse = false, bool fromController = false, bool send = true) {
        if(label.text.length() > 0) {
            int cursorPos = getCursorPos();
            if(cursorPos == 0) return false;
            if(cursorPos == -1 || cursorPos == label.text.length()) {
                label.text.remove(label.text.length() - 1, 1);
            } else {
                label.text = String.Format( "%s%s",
                                            cursorPos > 1 ? label.text.mid(0, cursorPos - 1) : "", 
                                            cursorPos < int(label.text.length()) ? label.text.mid(cursorPos) :  "");
            }
        
            if(cursorPos > int(label.text.length())) moveCursorToEnd();
            else cursorLeft();
            label.requiresLayout = true;
            requiresLayout = true;

            if(send) sendEvent(UIHandler.Event_ValueChanged, fromMouse, fromController);

            return true;
        }
        return false;
    }
    
    bool delete(bool fromMouse = false, bool fromController = false, bool send = true) {
        if(label.text.length() > 0) {
            int cursorPos = getCursorPos();
            if(cursorPos == -1 || cursorPos == label.text.length()) {
                // Do nothing
                return false;
            } else {
                label.text = String.Format( "%s%s",
                                            cursorPos > 0 ? label.text.mid(0, cursorPos) : "", 
                                            cursorPos < int(label.text.length()) - 1 ? label.text.mid(cursorPos + 1) :  "");
            }
        
            if(cursorPos >= int(label.text.length())) moveCursorToEnd();
            label.requiresLayout = true;
            requiresLayout = true;

            if(send) sendEvent(UIHandler.Event_ValueChanged, fromMouse, fromController);

            return true;
        }
        return false;
    }

    void cursorLeft() {
        if(getCursorPos() - 1 <= 0) {
            setCursorPos(0);
            return;
        }

        // rewind until we get a previous code point, or 0
        int ch, idx, curPos = getCursorPos();
        int sPos = curPos - 1;
        [ch, idx] = label.text.getNextCodePoint(sPos);
        while(idx == curPos && sPos > 0) {
            sPos--;
            [ch, idx] = label.text.getNextCodePoint(sPos);
        }
        if(sPos == 0) setCursorPos(0);
        setCursorPos(MAX(0, idx));
    }

    void cursorRight() {
        int ch, idx;
        [ch, idx] = label.text.getNextCodePoint(getCursorPos());
        setCursorPos(idx);
    }

    void moveCursorToEnd() {
        setCursorPos(label.text.length());
    }

    void moveCursorToStart() {
        setCursorPos(0);
    }

    // Mouse input handlers, to allow mouse selection/cursor positioning
    override void onMouseEnter(Vector2 screenPos) {
        Super.onMouseEnter(screenPos);
        mouseInside = true;
    }

    override void onMouseExit(Vector2 screenPos, UIView newView) {
        Super.onMouseExit(screenPos, newView);

        if(!mouseDown) mouseInside = false;
    }

    override void onMouseUp(Vector2 screenPos) {
        mouseInside = false;
        mouseDown = false;
        
        Super.onMouseUp(screenPos);
    }

    override void onMouseDown(Vector2 screenPos) {
        mouseInside = true;
        mouseDown = true;

        // If we are already editing, move selection to mouse down location
        if(!disabled && textEnterMenu) {
            Vector2 localCoord = label.screenToRel(screenPos);
            int newPos = label.cursorPosFromLocal(localCoord);

            if(newPos >= 0) setCursorPos(newPos);
        } else if(!disabled) {
            onActivate(true, false);
        }

        Super.onMouseDown(screenPos);
    }

    override bool event(ViewEvent ev) {
        //if(ev.type == ev.type == UIEvent.Type_MouseMove) Console.Printf("Mouse Move: %d %d", mouseInside, mouseDown);
        if(ev.type == UIEvent.Type_MouseMove && mouseInside && mouseDown && !disabled && textEnterMenu) {
            let screenPos = (ev.MouseX, ev.MouseY);
            Vector2 localCoord = label.screenToRel(screenPos);
            int newPos = label.cursorPosFromLocal(localCoord);
            if(newPos >= 0) setCursorPos(newPos);
        }

        return Super.event(ev); 
    }
}


// This menu should appear invisible and simply alter the edit text as input is provided
// Note: Menus with a text enter field should be cautious of closing themselves when the
// text enter menu is open. It is important to close this menu or to de-focus the text 
// entry field ahead of time.
class UITextEnterMenu : UIMenu {
    UIInputText inputText;
    UIOnScreenKeyboard osk;
    UIOSKTemplate oskTemplate;
    bool requireValue;
    bool useVirtualKeyboard;
    bool showVirtualKeyboard;
    bool cancelable;

    bool spaceDown, backspaceDown;
    int spaceTimer, backspaceTimer, backspaceCounter;

    static UITextEnterMenu present(UIInputText inputText, bool useVirtualKeyboard = false, UIOSKTemplate template = null) {
        let te = new("UITextEnterMenu");
		te.useVirtualKeyboard = useVirtualKeyboard;
        te.inputText = inputText;
        te.requireValue = inputText.requireValue;
        te.oskTemplate = template;
        te.Init(Menu.GetCurrentMenu());
        te.ActivateMenu();
		return te;
    }

    override void init(Menu parent) {
		Super.init(parent);

        cancelable = true;
        ReceiveAllInputEvents = true;
        DontBlur = parent.DontBlur;
        DontDim = parent.DontDim;
        BlurAmount = parent.BlurAmount;

        if(useVirtualKeyboard) {
            openVirtualKeyboard();
        }
    }

    override void onFirstTick() {
        Super.onFirstTick();

        if(useVirtualKeyboard && !osk) {
            openVirtualKeyboard();
        }
    }

    override void close() {
        if(osk) {
            inputText.sendEvent(UIInputText.ClosedVirtualKeyboard, false, true);
        }
        Super.close();
    }

    override void drawer() {
        if(uiParentMenu) uiParentMenu.drawer();
		Super.drawer();
	}

    override void ticker() {
        if(uiParentMenu) uiParentMenu.ticker();

        // Space repeat timer, for controllers
        if(spaceDown) {
            if(--spaceTimer < 0) {
                spaceTimer = 2;
                if(osk) {
                    inputText.appendCharacter(" ");
                    if(oskTemplate && oskTemplate.buttonSound != "") MenuSound(oskTemplate.buttonSound);
                }
            }
        }

        // Backspace repeat timer, for controllers
        if(backspaceDown) {
            if(--backspaceTimer < 0) {
                backspaceTimer = backspaceCounter > 5 ? (backspaceCounter > 10 ? 0 : 1) : 2;
                backspaceCounter++;
                if(osk) {
                    inputText.backspace(fromController: true);
                    if(backspaceCounter <= 5 && oskTemplate && oskTemplate.deleteSound != "") MenuSound(oskTemplate.deleteSound);
                }
            }
        }

        // If we hid the OSK and the animation is complete, remove the osk from screen
        if(osk && !showVirtualKeyboard && !animator.isAnimating(osk)) {
            mainView.removeView(osk);
        }

        Super.ticker();
    }

    void openVirtualKeyboard() {
        if(showVirtualKeyboard && osk) return;

        if(osk) {
            if(!osk.parent) mainView.add(osk);
            osk.alpha = 0;
            osk.layout();
            osk.animateFrame(
                0.15,
                fromPos: osk.frame.pos + (0, 200),
                toPos: osk.frame.pos,
                fromAlpha: 0.0,
                toAlpha: 1.0,
                ease: Ease_Out
            );
            navigateTo(osk.charKeys[0]);
        } else {
            osk = new("UIOnScreenKeyboard").init((0,0), (1024, 600), inputText, inputText.inputFont, 1.0, inputText.isMultiline(), oskTemplate); 
            osk.backgroundColor = 0xCC101010;
            osk.pin(UIPin.Pin_Left);
            osk.pin(UIPin.Pin_Right);
            osk.pin(UIPin.Pin_Bottom);
            osk.pin(UIPin.Pin_Top, UIPin.Pin_Bottom, value: 0.666669, isFactor: true);
            mainView.add(osk);
            osk.layout();
            osk.backKey.setDisabled(!cancelable);
            navigateTo(osk.charKeys[0]);

            osk.animateFrame(
                0.15,
                fromPos: osk.frame.pos + (0, 200),
                toPos: osk.frame.pos,
                fromAlpha: 0.0,
                toAlpha: 1.0,
                ease: Ease_Out
            );
        }

        showVirtualKeyboard = true;

        inputText.sendEvent(UIInputText.OpenedVirtualKeyboard, false, true);
    }


    void closeVirtualKeyboard() {
        if(showVirtualKeyboard) {
            showVirtualKeyboard = false;

            if(osk) {
                osk.layout();
                osk.animateFrame(
                    0.15,
                    fromPos: osk.frame.pos,
                    toPos: osk.frame.pos + (0, 200),
                    fromAlpha: osk.alpha,
                    toAlpha: 0.0,
                    ease: Ease_In
                );

                inputText.sendEvent(UIInputText.ClosedVirtualKeyboard, false, true);
            }
        }
    }

    override bool OnUIEvent(UIEvent ev) {
		if (ev.Type == UIEvent.Type_Char) {
            closeVirtualKeyboard();
			
            // Add character to text field
            inputText.appendCharacter(ev.KeyChar);
			return true;
		}

		int ch = ev.KeyChar;

		if ((ev.Type == UIEvent.Type_KeyDown || ev.Type == UIEvent.Type_KeyRepeat) && ch == 8) {
			inputText.backspace();
            return true;
        } else if(ch == UIEvent.Key_Left && (ev.Type == UIEvent.Type_KeyDown || ev.Type == UIEvent.Type_KeyRepeat)) {
            inputText.cursorLeft();
            closeVirtualKeyboard();
            return true;
        } else if(ch == UIEvent.Key_Right && (ev.Type == UIEvent.Type_KeyDown || ev.Type == UIEvent.Type_KeyRepeat)) {
            inputText.cursorRight();
            closeVirtualKeyboard();
            return true;
        } else if(ch == UIEvent.Key_Del && (ev.Type == UIEvent.Type_KeyDown || ev.Type == UIEvent.Type_KeyRepeat)) {
            inputText.delete(false, false, true);
            closeVirtualKeyboard();
            return true;
        } else if(ch == UIEvent.Key_Home && (ev.Type == UIEvent.Type_KeyDown || ev.Type == UIEvent.Type_KeyRepeat)) {
            inputText.moveCursorToStart();
            closeVirtualKeyboard();
            return true;
        } else if(ch == UIEvent.Key_End && (ev.Type == UIEvent.Type_KeyDown || ev.Type == UIEvent.Type_KeyRepeat)) {
            inputText.moveCursorToEnd();
            closeVirtualKeyboard();
            return true;
        } else if (ev.Type == UIEvent.Type_KeyDown) {
			if(ch == UIEvent.Key_ESCAPE) {
				if(cancelable) {
                    inputText.inputCancelled(false, false);
                }
                return true;
			} else if(ch == 13) {
				if(!requireValue || inputText.label.text.length() > 0) {
					let parentMenu = uiParentMenu;
                    inputText.textEnterMenu = null;
                    Close();
                    if(parentMenu) parentMenu.MenuEvent(MKEY_Input, false);
					return true;
				}
			}
		}

		// TODO: Add input for arrow keys to adjust cursor pos
        
		return uiParentMenu ? uiParentMenu.OnUIEvent(ev) : Super.OnUIEvent(ev);
	}

    override bool OnInputEvent(InputEvent ev) {
        if(ev.type == InputEvent.Type_KeyDown) {
            switch(ev.KeyScan) {
                case InputEvent.Key_Pad_LThumb:
                    if(osk && showVirtualKeyboard) osk.capsKey.onActivate(false, true);//osk.toggleCaps();
                    return true;
                case InputEvent.Key_Pad_Y:
                    if(osk && showVirtualKeyboard) {
                        spaceDown = true;
                        spaceTimer = 28;
                        inputText.appendCharacter(32);
                        if(oskTemplate && oskTemplate.buttonSound != "") MenuSound(oskTemplate.buttonSound);
                    }
                    return true;
                case InputEvent.Key_Pad_X:
                    if(osk && showVirtualKeyboard) {
                        backspaceDown = true;
                        backspaceTimer = 28;
                        backspaceCounter = 0;
                        inputText.backspace();
                        if(oskTemplate && oskTemplate.deleteSound != "") MenuSound(oskTemplate.deleteSound);
                    }
                    return true;
                case InputEvent.Key_Pad_Start:
                    if(osk && showVirtualKeyboard) {
                        if(MenuEvent(MKEY_Input, true)) {
                            return true;
                        }
                    }
                    break;
                default:
                    break;
            }
        }

        if(ev.type == InputEvent.Type_KeyUp) {
            switch(ev.KeyScan) {
                case InputEvent.Key_Pad_Y:
                    if(osk && showVirtualKeyboard) {
                        spaceDown = false;
                        spaceTimer = 35;
                    }
                    return true;
                case InputEvent.Key_Pad_X:
                    if(osk && showVirtualKeyboard) {
                        backspaceDown = false;
                        backspaceTimer = 35;
                    }
                    return true;
                default:
                    break;
            }
        }

        return Super.OnInputEvent(ev);
    }

    override bool MenuEvent(int mkey, bool fromcontroller) {
        // If we didn't have the OSK up, bring it up now
		if(mkey != MKEY_Back && fromController && (!osk || !showVirtualKeyboard)) {
            openVirtualKeyboard();
            return true;
        }

        switch (mkey) {
			case MKEY_Clear:
                if(!osk) inputText.backspace(fromController: fromController);
                return true;
            case MKEY_PageUp:
                inputText.cursorLeft();
                return true;
            case MKEY_PageDown:
                inputText.cursorRight();
				return true;
			case MKEY_Enter:
            case MKEY_Input:
                if(mkey == MKEY_Input || (!osk || !showVirtualKeyboard)) {
                    // Send event to parent menu that we have completed
                    if(!requireValue || inputText.label.text.length() > 0) {
                        let parentMenu = uiParentMenu;
                        inputText.textEnterMenu = null;
                        if(oskTemplate && oskTemplate.okSound != "") MenuSound(oskTemplate.okSound);
                        Close();
                        if(parentMenu) parentMenu.MenuEvent(MKEY_Input, false);
                    } else {
                        if(oskTemplate && oskTemplate.errorSound != "") MenuSound(oskTemplate.errorSound);
                    }
                    return true;
                }
                break;
            case MKEY_Back:
                if(cancelable) {
                    inputText.inputCancelled(false, fromcontroller);
                }
                return true;
			default:
				break;
		}

        if(osk && showVirtualKeyboard) {
            if(Super.MenuEvent(mkey, fromController)) {
                return true;
            }
        }

        return uiParentMenu ? uiParentMenu.MenuEvent(mkey, fromcontroller) : false;
	}

    override bool TranslateKeyboardEvents() {
		return osk && showVirtualKeyboard;
	}
}


class UIOSKButton : UIButton {
    int curChar;
}

// Responsible for handling basic text input with controller/kb
// TODO: Make skinnable!
class UIOnScreenKeyboard : UIView {
    mixin SCVARBuddy;

    Array<UIOSKButton> numKeys, charKeys;
    UIOSKButton spaceKey, backspaceKey, leftKey, rightKey, capsKey, symbolKey, enterKey, newLineKey, backKey;
    UIImage backgroundImage;
    UIInputText textField;
    Font fnt;
    UIOSKTemplate template;

    bool capsEnabled, symEnabled;

    static const int numSymbols[] = {
        "!", "@", "#", 36, "%", "^", "&", "*", "(", ")"
    };

    static const int rowChars[] = {
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "a", "s", "d", "f", "g", "h", "j", "k", "l",
        "\"", "z", "x", "c", "v", "b", "n", "m", "_", ":", "!"
    };

    static const int rowSymbols[] = {
        "!", "@", "#", 36, "%", "^", "&", "*", "(", ")", "-", "+", "[", "]", 92, "<", ">", ";", ":",
        "\"", "'", "{", "}", "v", "b", "/", "~", ",", ".", "?"
    };

    UIOnScreenKeyboard init(Vector2 pos, Vector2 size, UIInputText textField, Font fnt, double textScale = 1.0, bool allowNewline = false, UIOSKTemplate template = null) {
        Super.init(pos, size);

        bool isPlaystation = iGetCVar("g_gamepad_use_psx") > 0;

        self.textField = textField;
        self.fnt = fnt;
        self.template = template;

        UIButtonState normal            = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD3A3A3A);
        UIButtonState hover             = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD33A2FF);
        UIButtonState pressed           = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD2B5B73);
        UIButtonState disabled          = UIButtonState.Create("", 0x66FFFFFF, backgroundColor: 0x663A3A3A);
        UIButtonState selected          = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD338FE6);
        UIButtonState selectedHover     = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD33A2FF);
        UIButtonState selectedPressed   = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD2B5B73);

        // Don't lay out anything until the layout phase. We won't use any pins either because this will be a hardcoded 
        // grid based on size

        // Create numbers
        for(int x = 1; x <= 10; x++) {
            int val = x != 10 ? x : 0;
            let btn = UIOSKButton(new("UIOSKButton").init(
                (0,0), (100, 100), 
                String.Format("%d", val),
                fnt,
                normal,
                hover,
                pressed,
                disabled,
                selected,
                selectedHover,
                selectedPressed
            ));
            btn.label.multiline = false;
            btn.curChar = 48 + val;
            numKeys.push(btn);
            add(btn);
        }

        // Create characters
        for(int x = 0; x < 30; x++) {
            int val = rowChars[x];
            let btn = UIOSKButton(new("UIOSKButton").init(
                (0,0), (100, 100), 
                String.Format("%c", val),
                fnt,
                normal,
                hover,
                pressed,
                disabled,
                selected,
                selectedHover,
                selectedPressed
            ));
            btn.label.multiline = false;
            btn.curChar = val;
            charKeys.push(btn);
            add(btn);
        }

        // Darker color for control buttons
        normal            = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD222222);
        hover             = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD33A2FF);
        pressed           = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD2B5B73);
        disabled          = UIButtonState.Create("", 0x66FFFFFF, backgroundColor: 0x663A3A3A);
        selected          = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD338FE6);
        selectedHover     = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD33A2FF);
        selectedPressed   = UIButtonState.Create("", Font.CR_UNTRANSLATED, backgroundColor: 0xDD2B5B73);

        // Create control buttons
        string spaceText       = String.Format("Space   %c", isPlaystation ? 0x9A : 0x83);
        string backspaceText   = String.Format("Backspace  %c", isPlaystation ? 0x99 : 0x82);
        string backText        = String.Format("%c\nBack", isPlaystation ? 0x98 : 0x81);
        string leftText        = String.Format("%c  L", 0x86);
        string rightText       = String.Format("R  %c", 0x87);
        string enterText       = String.Format("%c\nEnter", 0x8A);
        string capsText        = String.Format("%c\nCaps", 0x84);
        
        spaceKey        = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), spaceText,     fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        backspaceKey    = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), backspaceText, fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        leftKey         = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), leftText,      fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        rightKey        = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), rightText,     fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        capsKey         = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), capsText,      fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        symbolKey       = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), "Symbols",     fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        enterKey        = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), enterText,     fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        newLineKey      = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), "Return",      fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));
        backKey         = UIOSKButton(new("UIOSKButton").init((0,0), (100, 100), backText,      fnt, normal, hover, pressed, disabled, selected, selectedHover, selectedPressed));

        newLineKey.setDisabled(allowNewline);

        add(spaceKey);
        add(backspaceKey);
        add(leftKey);
        add(rightKey);
        add(capsKey);
        add(symbolKey);
        add(enterKey);
        add(newLineKey);
        add(backKey);

        // Setup navigation
        numKeys[0].navLeft = leftKey;
        numKeys[9].navRight = rightKey;
        for(int x = 0; x < 10; x++) {
            if(x > 0) numKeys[x].navLeft = numKeys[x - 1];
            if(x < 9) numKeys[x].navRight = numKeys[x + 1];
            numKeys[x].navDown = charKeys[x];
        }

        for(int y = 0; y < 3; y++) {
            for(int x = 0; x < 10; x++) {
                int idx = (y * 10) + x;
                if(x > 0) charKeys[idx].navLeft = charKeys[idx - 1];
                if(x < 9) charKeys[idx].navRight = charKeys[idx + 1];
                if(y > 0) charKeys[idx].navUp = charKeys[((y - 1) * 10) + x];
                else charKeys[idx].navUp = numKeys[x];
                if(y < 2) charKeys[idx].navDown = charKeys[((y + 1) * 10) + x];
                else charKeys[idx].navDown = x < 2 ? symbolKey : (x < 8 ? spaceKey : backspaceKey);
            }
        }

        charKeys[0].navLeft = backKey;
        charKeys[10].navLeft = backKey;
        charKeys[20].navLeft = capsKey;
        charKeys[9].navRight = newLineKey;
        charKeys[19].navRight = newLineKey;
        charKeys[29].navRight = enterKey;

        leftKey.navRight = numKeys[0];
        leftKey.navDown = backKey;
        rightKey.navLeft = numKeys[9];
        rightKey.navDown = newLineKey;
        backKey.navRight = charKeys[0];
        backKey.navUp = leftKey;
        backKey.navDown = capsKey;
        capsKey.navRight = charKeys[20];
        capsKey.navUp = backKey;
        newLineKey.navUp = rightKey;
        newLineKey.navLeft = charKeys[9];
        newLineKey.navDown = enterKey;
        enterKey.navUp = newLineKey;
        enterKey.navLeft = charKeys[29];
        backspaceKey.navRight = enterKey;
        backspaceKey.navUp = charKeys[28];
        backspaceKey.navLeft = spaceKey;
        spaceKey.navLeft = symbolKey;
        spaceKey.navRight = backspaceKey;
        spaceKey.navUp = charKeys[24];
        symbolKey.navLeft = capsKey;
        symbolKey.navRight = spaceKey;
        symbolKey.navUp = charKeys[20];

        return self;
    }


    const ButtonRatio = 0.66;
    const WideButtonWidth = 1.4;
    const Spacer = 0.08;

    // TODO: Calc minimum size based on character sizes and available space

    override void layoutSubviews() {
        double height = frame.size.y;
        double buttonHeight = height / (5.0 + (6.0 * Spacer));
        double spacerWidth = buttonHeight * Spacer;
        double buttonWidth = buttonHeight / ButtonRatio;
        double largeButtonWidth = buttonWidth * WideButtonWidth;
        double totalWidth = (10 * buttonWidth) + (2 * largeButtonWidth) + (13 * spacerWidth);
        double leftOffset = (frame.size.x / 2.0) - (totalWidth / 2.0);

        if(totalWidth > frame.size.x) {
            // We don't have the space for this size of keyboard, so let's shrink the keys
            totalWidth = frame.size.x;
            double availableWidth = totalWidth - (13 * spacerWidth);
            buttonWidth = availableWidth / (10.0 + (2.0 * WideButtonWidth));
            largeButtonWidth = buttonWidth * WideButtonWidth;
            leftOffset = 0;
        }

        // Manually layout subviews
        // Number Buttons
        for(int x = 0; x < numKeys.size(); x++) {
            let btn = numKeys[x];
            btn.frame.size = (buttonWidth, buttonHeight);
            btn.frame.pos = (
                leftOffset + largeButtonWidth + (spacerWidth * 2) + (x * buttonWidth) + (spacerWidth * x),
                spacerWidth
            );
            btn.layout(cScale, cAlpha);
        }

        // Character Buttons
        int idx = 0;
        for(int y = 0; y < 3; y++) {
            for(int x = 0; x < 10; x++) {
                let btn = charKeys[idx];
                btn.frame.size = (buttonWidth, buttonHeight);
                btn.frame.pos = (
                    leftOffset + largeButtonWidth + (spacerWidth * 2) + (x * buttonWidth) + (spacerWidth * x),
                    spacerWidth + buttonHeight + spacerWidth + (y * spacerWidth) + (buttonHeight * y)
                );
                btn.layout(cScale, cAlpha);
                idx++;
            }
        }

        // Special buttons
        spaceKey.frame.size = ((buttonWidth * 6) + (spacerWidth * 5), buttonHeight);
        spaceKey.frame.pos = (leftOffset + (buttonWidth * 2) + largeButtonWidth + (spacerWidth * 4), height - spacerWidth - buttonHeight);

        backspaceKey.frame.size = ((buttonWidth * 2) + spacerWidth, buttonHeight);
        backspaceKey.frame.pos = (leftOffset + (buttonWidth * 8) + largeButtonWidth + (spacerWidth * 10), height - spacerWidth - buttonHeight);

        leftKey.frame.size = (largeButtonWidth, buttonHeight);
        leftKey.frame.pos = (leftOffset + spacerWidth, spacerWidth);

        rightKey.frame.size = (largeButtonWidth, buttonHeight);
        rightKey.frame.pos = (leftOffset + (buttonWidth * 10) + largeButtonWidth + (spacerWidth * 12), spacerWidth);

        capsKey.frame.size = (largeButtonWidth, (buttonHeight * 2) + spacerWidth);
        capsKey.frame.pos = (leftOffset + spacerWidth, height - (buttonHeight * 2) - (spacerWidth * 2));

        symbolKey.frame.size = ((buttonWidth * 2) + spacerWidth, buttonHeight);
        symbolKey.frame.pos = (leftOffset + largeButtonWidth + (spacerWidth * 2), height - spacerWidth - buttonHeight);

        enterKey.frame.size = (largeButtonWidth, (buttonHeight * 2) + spacerWidth);
        enterKey.frame.pos = (leftOffset + (buttonWidth * 10) + largeButtonWidth + (spacerWidth * 12), height - (spacerWidth * 2) - (buttonHeight * 2));

        newLineKey.frame.size = (largeButtonWidth, (buttonHeight * 2) + spacerWidth);
        newLineKey.frame.pos = (leftOffset + (buttonWidth * 10) + largeButtonWidth + (spacerWidth * 12), height - (spacerWidth * 4) - (buttonHeight * 4));

        backKey.frame.size = (largeButtonWidth, (buttonHeight * 2) + spacerWidth);
        backKey.frame.pos = (leftOffset + spacerWidth, (spacerWidth * 2) + buttonHeight);

        spaceKey.layout(cScale, cAlpha);
        backspaceKey.layout(cScale, cAlpha);
        leftKey.layout(cScale, cAlpha);
        rightKey.layout(cScale, cAlpha);
        capsKey.layout(cScale, cAlpha);
        symbolKey.layout(cScale, cAlpha);
        enterKey.layout(cScale, cAlpha);
        newLineKey.layout(cScale, cAlpha);
        backKey.layout(cScale, cAlpha);

        // Layout any misc attached subviews
        for(int i = 0; i < subviews.size(); i++) {
            if(!(subviews[i] is 'UIOSKButton')) subviews[i].layout(cScale, cAlpha);
        }
    }

    override bool handleSubControl(UIControl ctrl, int event, bool fromMouse, bool fromController) {
        if(event == UIHandler.Event_Activated && ctrl is 'UIOSKButton') {
            let btn = UIOSKButton(ctrl);

            // TODO: Send character and generic events if there is no textfield
            // Check num and char keys first
            if(btn.curChar != 0) {
                textField.appendCharacter(btn.curChar);
                if(template && template.buttonSound != "") S_StartSound(template.buttonSound, CHAN_VOICE, CHANF_UI, snd_menuvolume);
            } else {
                if(btn == spaceKey) {
                    textField.appendCharacter(32, fromController: fromController);
                    if(template && template.buttonSound != "") S_StartSound(template.buttonSound, CHAN_VOICE, CHANF_UI, snd_menuvolume);
                } else if(btn == backspaceKey) {
                    if(textField.backspace(fromController: fromController) && template && template.deleteSound) {
                        S_StartSound(template.deleteSound, CHAN_VOICE, CHANF_UI, snd_menuvolume);
                    }
                } else if(btn == newLineKey) {
                    textField.appendCharacter("\n", fromController: fromController);
                    if(template && template.buttonSound != "") S_StartSound(template.buttonSound, CHAN_VOICE, CHANF_UI, snd_menuvolume);
                } else if(btn == enterKey) {
                    let m = getMenu();
                    if(m) {
                        m.MenuEvent(Menu.MKEY_Input, true);
                    }
                } else if(btn == capsKey) {
                    toggleCaps();
                } else if(btn == leftKey) {
                    textField.cursorLeft();
                } else if(btn == rightKey) {
                    textField.cursorRight();
                } else if(btn == symbolKey) {
                    toggleSymbols();
                } else if(btn == backKey) {
                    let m = getMenu();
                    if(m) {
                        m.MenuEvent(Menu.MKEY_Back, true);
                    }
                }

                return true;
            }
        }

        return Super.handleSubControl(ctrl, event, fromMouse, fromController);
    }

    void toggleCaps() {
        setCaps(!capsEnabled);
    }

    void setCaps(bool capsOn) {
        capsEnabled = capsOn;
        if(capsOn) symEnabled = false;

        for(int x = 0; x < 10; x++) {
            if(capsEnabled) numKeys[x].curChar = numSymbols[x];
            else numKeys[x].curChar = 48 + (x == 9 ? 0 : x + 1);
            string charString = numKeys[x].curChar == int("$") ? "$$" : String.Format("%c", numKeys[x].curChar);
            numKeys[x].label.setText(charString);
        }
        
        for(int x = 0; x < charKeys.size(); x++) {
            let str = String.Format("%c", (symEnabled ? rowSymbols[x] : rowChars[x]));
            if(capsEnabled) charKeys[x].curChar = str.makeUpper().getNextCodePoint(0);
            else charKeys[x].curChar = str.getNextCodePoint(0);
            string charString = charKeys[x].curChar == int("$") ? "$$" : String.Format("%c", charKeys[x].curChar);
            charKeys[x].label.setText(charString);
        }
    }

    void toggleSymbols() {
        symEnabled = !symEnabled;
        if(symEnabled)
            setCaps(false);
        else
            setCaps(capsEnabled);
    }
}