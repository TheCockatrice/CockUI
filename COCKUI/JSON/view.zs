extend class UIView {
    mixin DeserializeHelper;

    string id;
    Map<Name, UIView> viewLookup;
    Map<Name, UIPin> pinLookup;


    protected virtual UIView _deserialize(JsonObject obj, Map<Name, UIView> templates = null, UIView parentView = null) {
        // Apply template first and overwrite any properties after
        JsonString j_template = JsonString(obj.get("template"));
        JsonString j_templateID = JsonString(obj.get("viewTemplate"));
        if(j_template && j_template.s != "") {
            let n = Name(j_template.s);
            UIView template = templates ? templates.getIfExists(n) : null;
            if(!template) template = CockHandler.GetTemplateView(n);

            if(template) applyTemplate(template);
            else {
                Console.Printf("\c[RED]UIView: Failed to find template view '%s'", j_template.s);
            }
        } else if(j_templateID && j_templateID.s != "") {
            if(!parentView) {
                ThrowAbortException("\c[RED]UIView: No parent view, view templating cannot be performed for template ID '%s'", j_templateID.s);
            }
            let topView = parentView.getMasterView();
            let n = Name(j_templateID.s);
            UIView template = topView.findViewByID(n);

            if(template) applyTemplate(template);
            else {
                Console.Printf("\c[RED]UIView: Failed to find template from View ID '%s'", n);
            }
        }
        

        getOptionalDouble(obj, "x", frame.pos.x);
        getOptionalDouble(obj, "y", frame.pos.y);
        getOptionalDouble(obj, "width", frame.size.x);
        getOptionalDouble(obj, "height", frame.size.y);
        getOptionalString(obj, "id", id);
        getOptionalDouble(obj, "alpha", alpha);
        getOptionalDouble(obj, "scaleX", scale.x);
        getOptionalDouble(obj, "scaleY", scale.y);
        getOptionalDouble(obj, "angle", angle);
        getOptionalBool(obj, "hidden", hidden);
        getOptionalBool(obj, "clipsSubviews", clipsSubviews);
        getOptionalBool(obj, "cancelsSubviewRaycast", cancelsSubviewRaycast);
        getOptionalBool(obj, "ignoresClipping", ignoresClipping);
        getOptionalBool(obj, "layoutWithChildren", layoutWithChildren);

        string bgColor;
        if(getOptionalString(obj, "backgroundColor", bgColor)) {
            backgroundColor = parseColor(bgColor);
        }

        // Attempt to get shortcuts for auto-minimum sizes
        string tempStr;
        if(getOptionalString(obj, "width", tempStr)) {
            if(tempStr ~== "min") {
                if(widthPin) widthPin.value = UIView.Size_Min;
                else pinWidth(UIView.Size_Min);
            }
        }

        if(getOptionalString(obj, "height", tempStr)) {
            if(tempStr ~== "min") {
                if(heightPin) heightPin.value = UIView.Size_Min;
                else pinHeight(UIView.Size_Min);
            }
        }        

        // Get a quick pinToParent
        let j_pp = JsonArray(obj.get("pinToParent"));
        if(j_pp) {
            double vals[4] = {0, 0, 0, 0};
            for(int i = 0; i < j_pp.arr.size() && i < 4; i++) {
                JsonNumber j_num = JsonNumber(j_pp.arr[i]);
                if(!j_num) ThrowAbortException("UIView: Expected a number for pinToParent, got a %s", j_pp.arr[i].getClassName());
                vals[i] = j_num.asDouble();
            }

            pinToParent(
                vals[0],
                vals[1],
                vals[2],
                vals[3]
            );
        }

        JsonArray j_pins = JsonArray(obj.get("pins"));
        if(j_pins) {
            foreach(j_pin : j_pins.arr) {
                let pin = UIPin.deserialize(j_pin);
                if(!pin) Console.Printf("\c[RED]UIView: Failed to deserialize pin from object %s", j_pin.getClassName());
                else {
                    JsonObject j_pinObj = JsonObject(j_pin);
                    if(!j_pinObj) ThrowAbortException("UIView: Expected a JsonObject for pin, got a "..j_pin.getClassName());
                    JsonString j_type = JsonString(j_pinObj.get("type"));
                    if(j_type) {
                        if(j_type.s ~== "width") widthPin = pin;
                        else if(j_type.s ~== "height") heightPin = pin;
                        else {
                            pins.push(pin);
                        }
                    } else {
                        pins.push(pin);
                    }

                    // Optionally add the pin to the lookup table
                    JsonString j_id = JsonString(j_pinObj.get("id"));
                    if(j_id && j_id.s != "") {
                        pinLookup.insert(Name(j_id.s), pin);
                    }
                }
            }
        }

        // Deserialize the subviews
        JsonArray j_subviews = JsonArray(obj.get("subViews"));
        if(j_subviews) {
            foreach(j_subview : j_subviews.arr) {
                UIView subview = UIView.deserialize(j_subview, templates, parentView: self);
                if(!subview) Console.Printf("\c[RED]UIView: Failed to deserialize subview from object %s", j_subview.getClassName());
                else {
                    add(subview);
                    
                    // Optionally add the subview to the lookup table
                    if(subview.id != "") {
                        viewLookup.insert(Name(subview.id), subview);
                    }
                }
            }
        }

        return self;
    }

    static UIView deserialize(JsonElement elem, Map<Name, UIView> templates = null, class<UIView> cls = 'UIView', UIView view = null, UIView parentView = null) {
        if(!elem) ThrowAbortException("UIView: Expected a JsonElement, got null");
        JsonObject obj = JsonObject(elem);
        if(!obj) ThrowAbortException("UIView: expected a JsonObject, got a "..elem.getClassName());

        if(view) {
            return view._deserialize(obj, templates);
        }

        // Peek the class of the UIView from the element
        // If none specified, this is a generic UIView
        string className;
        if(getOptionalString(obj, "class", className)) {
            class<UIView> cls = (class<UIView>)(className);
            if(!cls) ThrowAbortException("UIView: No View class found for name '%s'", className);
            return UIView(new(cls)).baseInit()._deserialize(obj, templates, parentView);
        }

        // Create the view of the specified class
        return UIView(new(cls)).baseInit()._deserialize(obj, templates, parentView);
    }


    UIView findViewById(Name id, bool localOnly = false) {
        UIView v = viewLookup.getIfExists(id);

        // If not found, search in subviews
        if(v == null && !localOnly) {
            foreach(subview : subviews) {
                v = subview.findViewById(id, localOnly);
                if(v) return v;
            }
        }

        return v;
    }

    static Alignment GetAlignmentFromString(string alignString, Alignment defaultAlign = Align_Center) {
        if(alignString ~== "Left") return Align_Left;
        else if(alignString ~== "Right") return Align_Right;
        else if(alignString ~== "Top") return Align_Top;
        else if(alignString ~== "Bottom") return Align_Bottom;
        else if(alignString ~== "VCenter" || alignString ~== "Middle") return Align_VCenter;
        else if(alignString ~== "HCenter" || alignString ~== "Center") return Align_HCenter;
        else if(alignString ~== "Centered") return Align_Centered;
        else if(alignString ~== "TopLeft") return Align_TopLeft;
        else if(alignString ~== "TopRight") return Align_TopRight;
        else if(alignString ~== "BottomLeft") return Align_BottomLeft;
        else if(alignString ~== "BottomRight") return Align_BottomRight;
        
        return defaultAlign;
    }

    static bool ParsePadding(JsonElement j, out UIPadding padding) {
        if(!j) return false;

        padding.zero();

        let j_arr = JsonArray(j);
        if(j_arr) {
            for(int i = 0; i < 4 && i < j_arr.arr.size(); i++) {
                JsonNumber j_num = JsonNumber(j_arr.arr[i]);
                if(!j_num) {
                    Console.Printf("\c[RED]UIView: Expected a number for padding element %d, got a %s", i, j_arr.arr[i].getClassName());
                    continue;
                }
                switch(i) {
                    case 0: padding.left = j_num.asDouble(); break;
                    case 1: padding.top = j_num.asDouble(); break;
                    case 2: padding.right = j_num.asDouble(); break;
                    case 3: padding.bottom = j_num.asDouble(); break;
                    default: break; // Should not happen
                }
            }
            return true;
        }

        let j_obj = JsonObject(j);
        if(j_obj) {
            getOptionalDouble(j_obj, "left", padding.left);
            getOptionalDouble(j_obj, "top", padding.top);
            getOptionalDouble(j_obj, "right", padding.right);
            getOptionalDouble(j_obj, "bottom", padding.bottom);
            return true;
        }

        Console.Printf("\c[RED]UIView: Expected a JsonArray or JsonObject for padding, got a %s", j.getClassName());

        return false;
    }
    
    void buildFromJson(JsonObject obj) {
        if(!obj) ThrowAbortException("UIView: Expected a JsonObject, got null");
        _deserialize(obj);
    }

    void load(string filename) {
        int lump = Wads.CheckNumForFullName("/" .. filename);
		if(lump == -1){
			ThrowAbortException("UIView::Load() Could not find %s", filename);
		}

		JsonElementOrError data = JSON.parse(Wads.ReadLump(lump), false);
		if(data is "JsonError"){
			ThrowAbortException("%s :  %s", filename, JsonError(data).what);
		}

        buildFromJson(JSONObject(data));
    }
}


extend class UIControl {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        getOptionalBool(obj, "disabled", disabled);
        getOptionalBool(obj, "rejectHoverSelection", rejectHoverSelection);
        getOptionalBool(obj, "cancelsHoverDeSelect", cancelsHoverDeSelect);
        getOptionalString(obj, "command", command);
        getOptionalInt(obj, "controlID", controlID);
        
        return self;
    }
}


extend class UIPin {
    mixin DeserializeHelper;

    private UIPin _deserialize(JsonObject obj) {
        getOptionalBool(obj, "isFactor", isFactor);
        getOptionalDouble(obj, "value", value);
        getOptionalDouble(obj, "offset", offset);
        getOptionalInt(obj, "priority", priority);

        JsonElement j_anchorElem = obj.get("anchor");
        if(!j_anchorElem) ThrowAbortException("UIPin: No 'anchor' element found!");

        string anchorString, parentAnchorString;
        if(getOptionalString(obj, "anchor", anchorString)) {
            anchor = UIPinAnchorFromString(anchorString);

            if(getOptionalString(obj, "parentAnchor", parentAnchorString)) {
                parentAnchor = UIPinAnchorFromString(parentAnchorString);
            } else {
                parentAnchor = anchor;
            }
        } else {
            anchor = UIPin.Pin_Static;
            parentAnchor = UIPin.Pin_Static;
        }

        // Special case for string values, so far only "min" is supported
        string tString;
        if(getOptionalString(obj, "value", tString)) {
            if(tString ~== "min") {
                value = UIView.Size_Min;
            }
        }

        return self;
    }

    static UIPin deserialize(JsonElement elem) {
        if(!elem) ThrowAbortException("UIPin: Expected a JsonElement, got null");
        JsonObject obj = JsonObject(elem);
        if(!obj) ThrowAbortException("UIPin: expected a JsonObject, got a "..elem.getClassName());

        return new("UIPin")._deserialize(obj);
    }

    PinAnchor UIPinAnchorFromString(string anchorString) {
        if(anchorString ~== "Left") return Pin_Left;
        else if(anchorString ~== "Right") return Pin_Right;
        else if(anchorString ~== "Top") return Pin_Top;
        else if(anchorString ~== "Bottom") return Pin_Bottom;
        else if(anchorString ~== "VCenter") return Pin_VCenter;
        else if(anchorString ~== "HCenter") return Pin_HCenter;
        else if(anchorString ~== "Static") return Pin_Static;
        else ThrowAbortException("UIPin: Unknown anchor type '%s'", anchorString);
        return Pin_Left;
    }
}