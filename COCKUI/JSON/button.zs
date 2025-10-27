extend class UIButton {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        string text, fontName, textAlignString;
        bool hasText, hasFont;
        Alignment textAlign = Align_Center;

        getOptionalBool(obj, "doubleClickEnabled", doubleClickEnabled);
        getOptionalBool(obj, "doubleClick", doubleClickEnabled);
        hasText = getOptionalString(obj, "text", text, localize: true);
        hasFont = getOptionalString(obj, "font", fontName);
        getOptionalDouble(obj, "imgScaleX", imgScale.x);
        getOptionalDouble(obj, "imgScaleY", imgScale.y);
        getOptionalString(obj, "textAlign", textAlignString);
        getOptionalString(obj, "command", command);

        // Determine text alignment
        if(textAlignString != "") {
            textAlign = UIView.GetAlignmentFromString(textAlignString, Align_Center);
        }
        
        // Get label info
        if(hasText || hasFont) {
            // Font is mandatory for buttons with text
            if(fontName == "" && !label) {
                ThrowAbortException("UIButton: No font specified for button with text '%s' in object %s", text, obj.getClassName());
            }

            if(!label) {
                Font fnt = Font.GetFont(fontName);
                if(!fnt) {
                    ThrowAbortException("UIButton: No font found for name '%s' in object %s", fontName, obj.getClassName());
                }
                buildLabel(text, fnt, textAlign);
            } else {
                if(hasText) label.text = text;
                if(hasFont) {
                    label.fnt = Font.GetFont(fontName);
                    if(!label.fnt) {
                        ThrowAbortException("UIButton: No font found for name '%s' in object %s", fontName, obj.getClassName());
                    }
                }
            }

            // Font scale
            double fScale = 1.0;
            if(getOptionalDouble(obj, "fontScale", fScale)) {
                if(fScale <= 0.0) {
                    ThrowAbortException("UILabel: Invalid font scale '%f' for label with text '%s' in object %s", fScale, text, obj.getClassName());
                }
                label.fontScale = (fScale,fScale);
            }

            getOptionalDouble(obj, "fontScaleX", label.fontScale.x);
            getOptionalDouble(obj, "fontScaleY", label.fontScale.y);

            string col;
            if(getOptionalString(obj, "shadowColor", col)) label.shadowColor = parseColor(col);
            if(getOptionalString(obj, "textColor", col)) label.textColor = parseColor(col);
            if(getOptionalString(obj, "stencilColor", col)) label.stencilColor = parseColor(col);
            if(getOptionalString(obj, "blendColor", col)) label.blendColor = parseColor(col);
            if(getOptionalString(obj, "textBackgroundColor", col)) label.textBackgroundColor = parseColor(col);

            // Extended info can be put in "label" sub object
            deserializeOptionalView(obj, "label", 'UILabel', label, templates);
        }

        // Set text padding
        JsonElement j_padding = JsonElement(obj.get("textPadding"));
        if(j_padding) {
            if(ParsePadding(j_padding, textPadding))
                setTextPadding(textPadding.left, textPadding.top, textPadding.right, textPadding.bottom);
        }

        // Get image style and anchor, same as with UIImage
        string tString;
        if(getOptionalString(obj, "anchor", tString)) {
            Name tn = Name(tString);
            for(int i = 0; i < UIImage.AnchorLookup.size(); i++) {
                if(tn == UIImage.AnchorLookup[i]) {
                    imgAnchor = i;
                    break;
                }
            }
        }

        if(getOptionalString(obj, "style", tString)) {
            Name tn = Name(tString);
            for(int i = 0; i < UIImage.ImageStyleLookup.size(); i++) {
                if(tn == UIImage.ImageStyleLookup[i]) {
                    imgStyle = i;
                    break;
                }
            }
        }

        // TODO: Add support for referencing a static set of button states instead of specifying them for every button
        // Deserialize button states
        JsonObject j_states = JsonObject(obj.get("states"));
        if(j_states) {
            foreach(key, j_state : j_states.data) {
                UIButtonState state = UIButtonState.deserialize(JsonObject(j_state));
                if(!state) {
                    Console.Printf("\c[RED]UIButton: Failed to deserialize button state '%s' from object %s", key, j_state.getClassName());
                }

                // Determine which state this object goes to
                switch(Name(key)) {
                    case 'normal':
                        buttStates[State_Normal] = state;
                        break;
                    case 'hover':
                        buttStates[State_Hover] = state;
                        break;
                    case 'pressed':
                        buttStates[State_Pressed] = state;
                        break;
                    case 'disabled':
                        buttStates[State_Disabled] = state;
                        break;
                    case 'selected':
                        buttStates[State_Selected] = state;
                        break;
                    case 'selectedhover':
                        buttStates[State_SelectedHover] = state;
                        break;
                    case 'selectedpressed':
                        buttStates[State_SelectedPressed] = state;
                        break;
                    default:
                        Console.Printf("\c[RED]UIButton: Unknown button state '%s' in object %s", key, j_state.getClassName());
                        break;
                }
            }
        }


        transitionToState(self.disabled ? State_Disabled : (self.selected ? State_Selected : State_Normal), false);

        return self;
    }
}


extend class UIButtonState {
    mixin DeserializeHelper;

    virtual UIButtonState _deserialize(JsonObject obj) {
        texScale = 1.0;
        blendColor = -1;
        desaturation = -1;

        getOptionalDouble(obj, "texScale", texScale);

        // We can't really work with floats directly
        double desat = double.max;
        getOptionalDouble(obj, "desaturation", desat);
        getOptionalDouble(obj, "desat", desat);
        if(desat != double.max) desaturation = desat;
        
        UISoundInfo sndInfo = new("UISoundInfo");
        JsonElement j_soundElem = obj.get("sound");
        JsonElement j_mouseSoundElem = obj.get("mouseSound");

        if(j_soundElem) {
            if(j_soundElem is 'JsonObject') {
                sndInfo.deserialize(JsonObject(j_soundElem));
                self.sound = sndInfo.sound;
                soundVolume = sndInfo.volume;
            } else if(j_soundElem is 'JsonString') {
                self.sound = JsonString(j_soundElem).s;
                soundVolume = 1.0; // Default volume
            }
        }

        if(j_mouseSoundElem) {
            if(j_mouseSoundElem is 'JsonObject') {
                sndInfo.deserialize(JsonObject(j_mouseSoundElem));
                mouseSound = sndInfo.sound;
                mouseSoundVolume = sndInfo.volume;
            } else if(j_mouseSoundElem is 'JsonString') {
                mouseSound = JsonString(j_mouseSoundElem).s;
                mouseSoundVolume = 1.0; // Default volume
            }
        }


        string imageName;
        if(getOptionalString(obj, "image", imageName)) {
            tex = UITexture.Get(imageName);
        }

        // Support slices
        JsonObject j_slice = JsonObject(obj.get("slice"));
        if(j_slice) {
            slices = NineSlice.deserialize(j_slice, imageName);
            if(slices && slices.texture) {
                tex = slices.texture;
            } else if(slices && !slices.texture) {
                slices.texture = UITexture.Get(imageName);
            }
        }

        // Blend Color
        string col;
        if(getOptionalString(obj, "blendColor", col)) blendColor = parseColor(col);

        // Text Color
        if(getOptionalString(obj, "textColor", col)) textColor = parseColor(col);

        // Background Color
        if(getOptionalString(obj, "backgroundColor", col)) backgroundColor = parseColor(col);
        if(getOptionalString(obj, "bgColor", col)) backgroundColor = parseColor(col);


        return self;
    }

    static UIButtonState deserialize(JsonObject obj) {
        if(!obj) ThrowAbortException("UIButtonState: No object provided for deserialization!");

        return new("UIButtonState")._deserialize(obj);
    }
}


class UISoundInfo {
    mixin DeserializeHelper;

    double volume;
    string sound;

    void deserialize(JsonObject obj) {
        volume = 1.0;
        self.sound = "";

        if(!obj) return;

        getOptionalString(obj, "sound", sound);
        getOptionalDouble(obj, "volume", volume);
        getOptionalDouble(obj, "vol", volume);
    }
}