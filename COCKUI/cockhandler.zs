// Container class for CockBar for receiving events from CockHandler
class CockBarContainer : BaseStatusBar {
    virtual void handleInterfaceEvent(ConsoleEvent e) {
        // Do nothing by default
    }
}


class CockHandler : StaticEventHandler {
    ui Map<Name, UIView> templateViews;
    ui bool hasLoadedTemplates;

    static clearscope CockHandler instance() {
        return CockHandler(StaticEventHandler.Find("CockHandler"));
    }

    static ui UIView GetTemplateView(Name id) {
        CockHandler handler = CockHandler.instance();
        if(!handler) {
            ThrowAbortException("\c[RED]CockHandler::GetTemplateView() No instance of CockHandler found!");
            return null;
        }

        if(!handler.hasLoadedTemplates) {
            handler.loadTemplates("interfaces/templates.json", developer > 0);
        }

        return handler.templateViews.getIfExists(id);
    }

    static ui void SetTemplateView(Name id, UIView view) {
        CockHandler handler = CockHandler.instance();
        if(!handler) {
            ThrowAbortException("\c[RED]CockHandler::SetTemplateView() No instance of CockHandler found!");
            return;
        }
        handler.templateViews.insert(id, view);
    }

    override void InterfaceProcess(ConsoleEvent e) {
        if(e.Name == "EngineInitialize") {
            loadTemplates("interfaces/templates.json", developer > 0);
            Console.Printf("\c[GREEN]CockHandler: Loaded %d templates", templateViews.CountUsed());
            return;
        }
        
        UIMenu men = UIMenu(Menu.GetCurrentMenu());
        if(men) {
            men.handleInterfaceEvent(e);
        }
        
        let barcock = CockBarContainer(StatusBar);
        if(barcock) {
            barcock.handleInterfaceEvent(e);
        }
    }

    override void OnEngineInitialize() {
        EventHandler.SendInterfaceEvent(consolePlayer, "EngineInitialize");
    }

    ui void loadTemplates(string filename, bool haltOnError = true, bool subPath = false) {
        if(hasLoadedTemplates) return;
        
        if(developer) Console.Printf("\c[green]CockHandler: Loading templates from %s", filename);

        int lump = Wads.CheckNumForFullName(filename);
		if(lump == -1) {
			if(haltOnError) ThrowAbortException("CockHandler::loadTemplates() Could not find %s", filename);
            else Console.Printf("\c[RED]CockHandler::loadTemplates() Could not find %s", filename);
            if(!subPath) hasLoadedTemplates = true;
            return;
		}

		JsonElementOrError data = JSON.parse(Wads.ReadLump(lump),false);
		if(data is "JsonError"){
			ThrowAbortException("CockHandler::loadTemplates() " .. JsonError(data).what);
            return;
		}
		
        // Do this in two stages:
        // 1) Deserialize all templates that don't reference unknown templates, also process includes in the first sweep
        // 2) Deserialize remaining templates, allowing references to previously deserialized templates

        let rootElement = JSONObject(data);
        foreach(key, elem : rootElement.data) {
            if(key == "include") {
                if(developer > 1) Console.Printf("\c[YELLOW]CockHandler: Processing includes in %s", filename);

                // Handle includes
                if(elem is 'JsonArray') {
                    foreach(includeElem : JsonArray(elem).arr) {
                        if(includeElem is 'JsonString') {
                            String includePath = JsonString(includeElem).s;
                            loadTemplates(includePath, haltOnError, true);
                        } else {
                            Console.Printf("\c[RED]CockHandler::loadTemplates() Invalid include format for %s in [%s]", key, filename);
                        }
                    }
                } else {
                    Console.Printf("\c[RED]CockHandler::loadTemplates() 'include' must be an array of strings");
                }
                continue;
            }
            
            JsonObject j_obj = JsonObject(elem);
            if(j_obj) {
                JsonString j_template = JsonString(j_obj.get("template"));
                if(j_template && j_template.s != "" && !templateViews.checkKey(j_template.s))
                    continue;   // Skip templates that reference unknown templates
            }

            UIView template = UIView.deserialize(JsonObject(elem), templateViews);
            if(!template) {
                Console.Printf("\c[RED]CockHandler::loadTemplates() Failed to deserialize template %s", key);
            } else {
                templateViews.insert(Name(key), template);
            }
        }


        // Second pass: Now deserialize those that we skipped
        foreach(key, elem : rootElement.data) {
            if(templateViews.checkKey(Name(key))) 
                continue;   // Already deserialized

            JsonObject j_obj = JsonObject(elem);
            if(j_obj) {
                JsonString j_template = JsonString(j_obj.get("template"));
                if(!j_template) {
                    continue;
                }
            } else {
                continue;
            }

            UIView template = UIView.deserialize(JsonObject(elem), templateViews);
            if(!template) {
                Console.Printf("\c[RED]CockHandler::loadTemplates() Failed to deserialize template (stage 2) %s", key);
            } else {
                templateViews.insert(Name(key), template);
            }
        }

        // Debug output a list of all templates loaded
        if(developer > 1) {
            foreach(key, t : templateViews) {
                Console.Printf("\c[YELLOW]DEBUG::CockHandler: Loaded template '%s' (%s)", key, t.getClassName());
            }
        }

        if(!subPath) hasLoadedTemplates = true;
    }
}