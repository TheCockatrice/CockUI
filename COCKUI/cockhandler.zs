class CockHandler : StaticEventHandler {
    ui Map<Name, UIView> templateViews;

    static clearscope CockHandler instance() {
        return CockHandler(StaticEventHandler.Find("CockHandler"));
    }

    static ui UIView GetTemplateView(Name id) {
        CockHandler handler = CockHandler.instance();
        if(!handler) {
            ThrowAbortException("\c[RED]CockHandler::GetTemplateView() No instance of CockHandler found!");
            return null;
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
            loadTemplates(developer > 0);
            Console.Printf("\c[GREEN]CockHandler::loadTemplates() Loaded %d templates", templateViews.CountUsed());
            return;
        }
        
        UIMenu men = UIMenu(Menu.GetCurrentMenu());
        if(men) {
            men.handleInterfaceEvent(e);
        }
    }

    override void OnEngineInitialize() {
        EventHandler.SendInterfaceEvent(consolePlayer, "EngineInitialize");
    }

    ui void loadTemplates(bool haltOnError = true) {
        int lump = Wads.CheckNumForFullName("/interfaces/templates.json");
		if(lump == -1){
			if(haltOnError) ThrowAbortException("CockHandler::loadTemplates() Could not find /interfaces/templates.json");
            else Console.Printf("\c[RED]CockHandler::loadTemplates() Could not find /interfaces/templates.json");
            return;
		}

		JsonElementOrError data = JSON.parse(Wads.ReadLump(lump),false);
		if(data is "JsonError"){
			ThrowAbortException("CockHandler::loadTemplates() "..JsonError(data).what);
            return;
		}
		
        let rootElement = JSONObject(data);
        foreach(key, elem : rootElement.data) {
            UIView template = UIView.deserialize(JsonObject(elem));
            if(!template) {
                Console.Printf("\c[RED]CockHandler::loadTemplates() Failed to deserialize template %s", key);
            } else {
                templateViews.insert(Name(key), template);
            }
        }
    }
}