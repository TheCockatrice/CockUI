extend class UIViewManager {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        getOptionalDouble(obj, "itemSpacing", itemSpacing);
        getOptionalBool(obj, "ignoreHiddenViews", ignoreHiddenViews);
        
        string contentModeString;
        if(getOptionalString(obj, "layoutMode", contentModeString)) {
            if(contentModeString ~== "None") layoutMode = Content_None;
            else if(contentModeString ~== "Stretch") layoutMode = Content_Stretch;
            else if(contentModeString ~== "SizeParent") layoutMode = Content_SizeParent;
            else {
                Console.Printf("\c[RED]UIViewManager: Unknown layout mode '%s'", contentModeString);
            }
        }

        JsonElement j_padding = JsonElement(obj.get("padding"));
        if(j_padding) {
            if(ParsePadding(j_padding, padding))
                setPadding(padding.left, padding.top, padding.right, padding.bottom);
        }


        // Deserialize managed views
        JsonArray j_managed = JsonArray(obj.get("managedViews"));
        if(j_managed) {
            foreach(j_view : j_managed.arr) {
                JsonObject j_view = JsonObject(j_view);
                if(!j_view) {
                    Console.Printf("\c[RED]UIViewManager: Failed to deserialize managed view from non-object element");
                    continue;
                }

                JsonNumber spacer = JsonNumber(j_view.get("spacer"));
                if(spacer) {
                    // If the view is a spacer, add it directly
                    addSpacer(spacer.asDouble());
                    continue;
                }

                UIView v = UIView.deserialize(j_view, templates, parentView: self);
                if(v) {
                    addManaged(v);

                    // Optionally add the subview to the lookup table
                    if(v.id != "") {
                        viewLookup.insert(Name(v.id), v);
                    }
                } else {
                    Console.Printf("\c[RED]UIViewManager: Failed to deserialize managed view from object %s", j_view.getClassName());
                }
            }
        }


        return self;
    }
}
