extend class UIInputText {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        getOptionalBool(obj, "numeric", numeric);
        getOptionalBool(obj, "requireValue", requireValue);
        getOptionalBool(obj, "allowDecimal", allowDecimal);
        getOptionalInt(obj, "charLimit", charLimit);

        string inputFontName;
        if(getOptionalString(obj, "inputFont", inputFontName)) {
            inputFont = Font.GetFont(inputFontName);
            if(!inputFont) {
                ThrowAbortException("UIInputText: No font found for name '%s' in object %s", inputFontName, obj.getClassName());
            }
        }


        // Button style forwarding of some text properties
        string text, fontName, textAlignString;
        bool hasFont;
        Color textColor = Font.CR_UNTRANSLATED;
        Alignment textAlign = Align_Center;

        getOptionalString(obj, "text", text, localize: true);
        hasFont = getOptionalString(obj, "font", fontName);
        getOptionalString(obj, "textAlign", textAlignString);
        string col;
        if(getOptionalString(obj, "textColor", col)) textColor = parseColor(col);

        // Determine text alignment
        if(textAlignString != "") {
            textAlign = UIView.GetAlignmentFromString(textAlignString, Align_Center);
        }

        // Create label if necessary and set info
        if(!label) {
            Font fnt = Font.GetFont(fontName);
            if(!fnt) {
                ThrowAbortException("UIInputText: No font found for name '%s' in object %s", fontName, obj.getClassName());
            }
            
            label = new("UILabel").init((0,0), (100, 50), text, fnt, textColor, textAlign);
            add(label);
        } else {
            if(text != "") label.text = text;
            if(hasFont) {
                label.fnt = Font.GetFont(fontName);
                if(!label.fnt) {
                    ThrowAbortException("UIInputText: No font found for name '%s' in object %s", fontName, obj.getClassName());
                }
            }
            if(textAlignString != "") {
                label.textAlign = textAlign;
            }
        }

        // Rest of label properties
        // Font scale
        double fScale = 1.0;
        if(getOptionalDouble(obj, "fontScale", fScale)) {
            if(fScale <= 0.0) {
                ThrowAbortException("UIInputText: Invalid font scale '%f' for input with text '%s' in object %s", fScale, text, obj.getClassName());
            }
            label.fontScale = (fScale,fScale);
        }

        getOptionalDouble(obj, "fontScaleX", label.fontScale.x);
        getOptionalDouble(obj, "fontScaleY", label.fontScale.y);

        if(getOptionalString(obj, "shadowColor", col)) label.shadowColor = parseColor(col);
        if(getOptionalString(obj, "textColor", col)) label.textColor = parseColor(col);
        if(getOptionalString(obj, "stencilColor", col)) label.stencilColor = parseColor(col);
        if(getOptionalString(obj, "blendColor", col)) label.blendColor = parseColor(col);
        if(getOptionalString(obj, "textBackgroundColor", col)) label.textBackgroundColor = parseColor(col);

        // Extended info can be put in "label" sub object
        deserializeOptionalView(obj, "label", 'UILabel', label, templates);

        // Create label pins if necessary, or assign them
        textPins[0] = label.firstPin(UIPin.Pin_Left);
        textPins[1] = label.firstPin(UIPin.Pin_Top);
        textPins[2] = label.firstPin(UIPin.Pin_Right);
        textPins[3] = label.firstPin(UIPin.Pin_Bottom);
        if(!textPins[0]) textPins[0] = label.pin(UIPin.Pin_Left);
        if(!textPins[1]) textPins[1] = label.pin(UIPin.Pin_Top);
        if(!textPins[2]) textPins[2] = label.pin(UIPin.Pin_Right);
        if(!textPins[3]) textPins[3] = label.pin(UIPin.Pin_Bottom);

        // Set text padding if specified
        JsonElement j_padding = JsonElement(obj.get("textPadding"));
        if(j_padding) {
            if(ParsePadding(j_padding, textPadding))
                setTextPadding(textPadding.left, textPadding.top, textPadding.right, textPadding.bottom);
        }

        // Get specific values for input text now
        // Background images
        // Support slices
        JsonObject j_slice = JsonObject(obj.get("backgroundSlices"));
        if(j_slice) {
            let slices = NineSlice.deserialize(j_slice, "");
            if(slices) {
               setBackgroundSlices(slices.texture.path, slices);
            }
        }

        JsonObject j_slice2 = JsonObject(obj.get("highlightSlices"));
        if(j_slice2) {
            let slices = NineSlice.deserialize(j_slice2, "");
            if(slices) {
                UIPadding highlightPadding;
                JsonElement j_padding = JsonElement(obj.get("highlightPadding"));
                if(j_padding) {
                    ParsePadding(j_padding, highlightPadding);
                }
                setHighlightSlices(slices.texture.path, slices, highlightPadding);
            }
        }

        // Support images
        string backgroundImageName, highlightImageName;
        if(getOptionalString(obj, "backgroundImage", backgroundImageName)) {
            setBackgroundImage(backgroundImageName);
            deserializeOptionalView(obj, "background", 'UIImage', background, templates);
        }

        if(getOptionalString(obj, "highlightImage", highlightImageName)) {
            UIPadding highlightPadding;
            JsonElement j_padding = JsonElement(obj.get("highlightPadding"));
            if(j_padding) {
                ParsePadding(j_padding, highlightPadding);
            }

            setHighlightImage(highlightImageName, highlightPadding);
            deserializeOptionalView(obj, "highlight", 'UIImage', highlight, templates);
        }



        return self;
    }
}
