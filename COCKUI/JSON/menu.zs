extend class UIMenu {
    mixin DeserializeHelper;

    Map<Name, UIView> templateViews;


    private UIMenu _deserialize(JsonObject obj) {
        JsonElement j_mainView = obj.get("mainView");

        if(!j_mainView) ThrowAbortException("UIMenu: No 'mainView' element found!");
        
        // Go through each optional field
        getOptionalBool(obj, "isModal", isModal);
        getOptionalBool(obj, "gamepadHidesCursor", gamepadHidesCursor);
        getOptionalBool(obj, "mouseMovementShowsCursor", mouseMovementShowsCursor);
        getOptionalString(obj, "defaultCursor", defaultCursor);

        // Deserialize template views first, so the views have something to reference
        JSONObject j_templateViews = JSONObject(obj.get("templateViews"));
        if(j_templateViews) {
            foreach(key, j_template : j_templateViews.data) {
                UIView template = UIView.deserialize(j_template);
                if(!template) Console.Printf("\c[RED]UIView: Failed to deserialize template view from object %s", j_template.getClassName());
                else {
                    templateViews.insert(Name(key), template);
                }
            }
        }

        // Start deserializing the main view
        mainView = UIView.deserialize(j_mainView, templateViews);
        if(!mainView) ThrowAbortException("UIMenu: Failed to deserialize 'mainView' element!");

        return self;
    }

    void buildFromJson(JsonObject obj) {
        if(!obj) ThrowAbortException("UIMenu: Expected a JsonObject, got null");

        // Deserialize the menu
        _deserialize(obj);
        
        mainView.frame.size = lastScreenSize;
        mainView.clipsSubviews = true;
		mainView.parentMenu = self;
        mainView.requiresLayout = true;
        calcScale(int(lastScreenSize.x), int(lastScreenSize.y));
    }

    static UIMenu deserialize(JsonElement elem) {
        if(!elem) ThrowAbortException("UIMenu: Expected a JsonElement, got null");
        JsonObject obj = JsonObject(elem);
        if(!obj) ThrowAbortException("UIMenu: expected a JsonObject, got a "..elem.getClassName());

        // Peek the class of the UIMenu from the element
        // If none specified, this is a generic UIMenu
        string className;
        if(getOptionalString(obj, "class", className)) {
            class<UIMenu> cls = (class<UIMenu>)(className);
            if(!cls) ThrowAbortException("UIMenu: No menu class found for name '%s'", className);
            return UIMenu(new(cls))._deserialize(obj);
        }

        // Create the menu of the specified class
        return new("UIMenu")._deserialize(obj);
    }


    void load(string filename) {
        int lump = Wads.CheckNumForFullName("/" .. filename);
		if(lump == -1){
			ThrowAbortException("UIMenu::Load() Could not find %s", filename);
		}

		JsonElementOrError data = JSON.parse(Wads.ReadLump(lump), false);
		if(data is "JsonError"){
			ThrowAbortException("%s :  %s", filename, JsonError(data).what);
		}

        buildFromJson(JSONObject(data));
    }

    UIView findViewById(Name id) {
        return mainView.findViewById(id, localOnly: false);
    }
}


mixin class DeserializeHelper {
    protected static bool getOptionalBool(JsonObject obj, string key, out bool b) {
        JsonElement elem = obj.get(key);
        if(!elem) return false;
        JsonBool j_bool = JsonBool(elem);
        if(j_bool) {
            b = j_bool.b;
            return true;
        }
        return false;
    }

    protected static bool getOptionalDouble(JsonObject obj, string key, out double d) {
        JsonElement elem = obj.get(key);
        if(!elem) return false;
        JsonDouble j_double = JsonDouble(elem);
        JsonInt j_int = JsonInt(elem);
        if(j_double) {
            d = j_double.d;
            return true;
        } else if(j_int) {
            d = j_int.i;
            return true;
        }
        return false;
    }

    protected static bool getOptionalInt(JsonObject obj, string key, out int i) {
        JsonElement elem = obj.get(key);
        if(!elem) return false;
        JsonInt j_int = JsonInt(elem);
        if(j_int) {
            i = j_int.i;
            return true;
        }
        return false;
    }

    protected static bool getOptionalString(JsonObject obj, string key, out string s, bool localize = false) {
        JsonElement elem = obj.get(key);
        if(!elem) return false;
        JsonString j_str = JsonString(elem);
        if(j_str) {
            if(localize) s = StringTable.Localize(j_str.s);
            else s = j_str.s;
            return true;
        }
        return false;
    }

    protected static string getMandatoryString(JsonObject obj, string key) {
        JsonElement elem = obj.get(key);
        if(!elem) ThrowAbortException("%s: No %s element found!", "Deserializer", key);
        JsonString j_str = JsonString(elem);
        if(!j_str) ThrowAbortException("%s: Expected a string for %s, got %s", "Deserializer", key, elem.getClassName());
        return j_str.s;
    }

    static int parseColor(String str) {
        return str.toint(0);
    }
}


class JTestMenu : UIMenu {
    override void init(Menu parent) {
		Super.init(parent);

        // Load JSON data
        load("view_test.json");

        mainView.requiresLayout = true;
    }
}
