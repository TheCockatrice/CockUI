extend class UILabel {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        string fontName, textAlignString;

        getOptionalString(obj, "text", text, localize: true);
        getOptionalString(obj, "font", fontName);
        getOptionalString(obj, "textAlign", textAlignString);
        getOptionalBool(obj, "multiline", multiline);
        getOptionalBool(obj, "noFilter", noFilter);
        getOptionalBool(obj, "clipText", clipText);
        getOptionalBool(obj, "pixelAlign", pixelAlign);
        getOptionalBool(obj, "drawShadow", drawShadow);
        getOptionalBool(obj, "shadowStencil", shadowStencil);
        getOptionalBool(obj, "monospace", monospace);
        getOptionalBool(obj, "autoScale", autoScale);
        getOptionalint(obj, "charLimit", charLimit);
        getOptionalint(obj, "lineLimit", lineLimit);
        getOptionalint(obj, "verticalSpacing", verticalSpacing);

        if(fontName == "" && fnt == null) {
            ThrowAbortException("UILabel: No font specified for label with text '%s' in object %s", text, obj.getClassName());
        }

        fnt = Font.GetFont(fontName);
        if(!fnt) {
            ThrowAbortException("UILabel: No font found for name '%s' in object %s", fontName, obj.getClassName());
        }

        // Determine text alignment
        if(textAlignString != "") {
            textAlign = UIView.GetAlignmentFromString(textAlignString, Align_Center);
        }

        // Various colors
        string col;
        if(getOptionalString(obj, "shadowColor", col)) shadowColor = parseColor(col);
        if(getOptionalString(obj, "textColor", col)) textColor = parseColor(col);
        if(getOptionalString(obj, "stencilColor", col)) stencilColor = parseColor(col);
        if(getOptionalString(obj, "blendColor", col)) blendColor = parseColor(col);
        if(getOptionalString(obj, "textBackgroundColor", col)) textBackgroundColor = parseColor(col);

        double desat = double.max;
        getOptionalDouble(obj, "desaturation", desat);
        getOptionalDouble(obj, "desat", desat);
        if(desat != double.max) desaturation = desat;

        double mins = double.max;
        getOptionalDouble(obj, "minScale", mins);
        if(mins != double.max) minScale = desat;

        return self;
    }
}
