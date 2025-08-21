class ViewFunctionHolder ui {
	UIView receiver;
	Function<ui bool(UIView, int, int, int, bool)> func;
}

class ViewFunctionList ui {
	Array<ViewFunctionHolder> functions;
	String name;
}

class UIMenu : GenericMenu {
	mixin ScreenSizeChecker;
	mixin CVARBuddy;
	mixin UIDrawer;

	Canvas drawCanvas;
	CVar ui_scaling;
	UIMenu uiParentMenu;
	UIView mainView;
	int mouseX;
	int mouseY;
	
	int ticks;
	bool hasDrawnOnce, hasCalledFirstTick;
	bool ignoreUIScaling;
	bool isModal, isAnimated;
	bool mouseCaptureBeforeMDOWN;

	double lastUIScale;

	// Last element that was mouse-downed or hovered
	UIView mDownView, mHoverView;
	UIControl activeControl, lastActiveControl;
	UIRecycler recycler;
	bool mouseDown, lastEventWasMouse, hasLayedOutOnce;
	
	int mouseCounter, controlCounter, keyboardCounter;			// Used to determine wether the user is primarily using mouse or keyboard

	// Drag info
	bool globalDragging, dragStarted;
	UIView globalDragOriginalView, dragRestrictView, dragTargetView;
	UIControl dragControl;
	Vector2 dragStartPos;


	UIViewAnimator animator;
	String defaultCursor;
	bool gamepadHidesCursor, mouseMovementShowsCursor, mouseIsHidden;

	Map<String, Function<ui bool(UIMenu, int, int, int, bool)> > interfaceCallbacks;
	Map<String, ViewFunctionList> viewInterfaceCallbacks;
	

	void registerInterfaceCallback(string name, Function<ui bool(UIMenu, int, int, int, bool)> callback) {
		interfaceCallbacks.insert(name, callback);
	}

	void unRegisterInterfaceCallback(string name) {
		interfaceCallbacks.remove(name);
	}

	void registerViewInterfaceCallback(string name, UIView receiver, Function<ui bool(UIView, int, int, int, bool)> callback) {
		ViewFunctionHolder holder = new("ViewFunctionHolder");
		holder.receiver = receiver;
		holder.func = callback;
		
		ViewFunctionList list = viewInterfaceCallbacks.GetIfExists(name);
		if(!list) {
			list = new("ViewFunctionList");
			list.name = name;
			viewInterfaceCallbacks.insert(name, list);
		}
		list.functions.push(holder);
	}

	void unRegisterViewInterfaceCallback(string name, UIView view) {
		//viewInterfaceCallbacks.remove(name);
		ViewFunctionList list = viewInterfaceCallbacks.GetIfExists(name);
		if(list) {
			for(int i = list.functions.size() - 1; i >= 0; i--) {
				if(list.functions[i].receiver == view) {
					list.functions.delete(i);
				}
			}
		}
	}

	bool isTopMenu() {
		return Menu.GetCurrentMenu() == self;
	}

	void allowDimInGameOnly() {
		DontDim = Level.MapName ~== "TITLEMAP";
	}

	void allowDimInTitlemapOnly() {
		DontDim = Level.MapName != "TITLEMAP";
	}

	virtual void layoutChange(int screenWidth, int screenHeight) {
		hasLayedOutOnce = true;
		calcScale(screenWidth, screenHeight);

		//mainView.frame.size = (screenWidth, screenHeight);
		mainView.layout();
		
		// TODO: Adjust animations to the new layout if possible, or cancel them if not possible
	}

	virtual void calcScale(int screenWidth, int screenHeight, Vector2 baselineResolution = (1920, 1080)) {
		let size = (screenWidth, screenHeight);
		let uscale = ui_scaling && !ignoreUIScaling ? ui_scaling.getFloat() : 1.0;
		lastUIScale = uscale;
		if(uscale <= 0.001) uscale = 1.0;

        let newScale = uscale * CLAMP(size.y / baselineResolution.y, 0.5, 2.0);
		
		// If we are close enough to 1.0.. 
		if(abs(newScale - 1.0) < 0.08) {
			newScale = 1.0;
		} else if(abs(newScale - 2.0) < 0.08) {
			newScale = 2.0;
		}

		mainView.frame.size = (screenWidth / newScale, screenHeight / newScale);
        mainView.scale = (newScale, newScale);

		// For UIDrawer
		screenSize = (screenWidth, screenHeight);
		virtualScreenSize = screenSize / newScale;
	}

	override void init(Menu parent) {
		Super.init(parent);
		ui_scaling = CVar.FindCVar("ui_scaling");

		if(parent is "UIMenu") {
			uiParentMenu = UIMenu(parent);
			mouseIsHidden = uiParentMenu.mouseIsHidden;
			controlCounter = uiParentMenu.isUsingController() ? 1 : 0;
			keyboardCounter = uiParentMenu.isUsingKeyboard() ? 1 : 0;
		}

		int scW = Screen.GetWidth();
		int scH = Screen.GetHeight();
		lastScreenSize = (scw, sch);

		animator = new("UIViewAnimator");
		recycler = new("UIRecycler");
        mainView = new("UIView").init((0,0), lastScreenSize);
		mainView.clipsSubviews = true;
		mainView.parentMenu = self;
		defaultCursor = "MOUSE";
		gamepadHidesCursor = true;
		mouseMovementShowsCursor = true;

		mouseX = mouseY = -1;

		isAnimated = true;	// Comment out to allow 35fps menu when not animating

		calcScale(scW, scH);
	}

	// Came back from being hidden by a child menu
	virtual void onResume(bool cursorWasHidden = false) {
		if(cursorWasHidden != mouseIsHidden) {
			if(cursorWasHidden) hideCursor();
			else showCursor(true);
		}
	}

	virtual void close() {
		Super.close();
		
		if(uiParentMenu) {
			uiParentMenu.onResume(mouseIsHidden);
		}
	}

	override void ticker() {
		if(isModal && uiParentMenu) {
			uiParentMenu.ticker();
		}

		if(!hasCalledFirstTick) {
			onFirstTick();
			hasCalledFirstTick = true;
		}

		ticks++;

		// Check for screen size changes since last frame
		double uiScale = ui_scaling ? ui_scaling.getFloat() : 1.0;

		if((!drawCanvas && screenSizeChanged()) || (!ignoreUIScaling && !(uiScale ~== lastUIScale))) {
			//mouseX = mouseY = -1;
			layoutChange(Screen.GetWidth(), Screen.GetHeight());
		}

		Super.ticker();
		mainView.Tick();

		
		// We only get to set the animated status if we are the top menu
		if(self == Menu.GetCurrentMenu()) {
			if(isAnimated) animated = true;
			else {
				let anim = animator && animator.animations.size();
				let p = uiParentMenu;
				while(p && !anim) {
					if(p.animator && p.animator.animations.size()) anim = true;
					p = p.uiParentMenu;
				}
				animated = anim;
			}
		}
	}

	virtual void hideCursor(bool force = false) {
		if(!mouseIsHidden || force) {
			mouseIsHidden = true;
			Screen.SetCursor("NOTACRSR");
		}
	}

	virtual void showCursor(bool force = false) {
		if(mouseIsHidden || force) {
			Screen.SetCursor(defaultCursor);
			mouseIsHidden = false;
		}
	}

	virtual void SetCursor(string crsr) {
		defaultCursor = crsr;

		if(!mouseIsHidden) {
			Screen.SetCursor(crsr);
		}
	}

	virtual void onFirstTick() {
		showCursor();
	}

	virtual void beforeFirstDraw() {}

	override void drawer() {
		if(!drawCanvas && (screenSizeChanged() || !hasLayedOutOnce)) {
			layoutChange(Screen.GetWidth(), Screen.GetHeight());
		}

		if(isModal && uiParentMenu) {
			uiParentMenu.drawer();
		}

		if(!hasDrawnOnce) {
			beforeFirstDraw();
		}

		Super.drawer();
		drawSubviews();
		hasDrawnOnce = true;
	}

	virtual void drawSubviews() {
		// After animations update the mouse selection in case something moved under the mouse
		if(animator.step()) {
			testMouse(mouseX, mouseY, true);
		}

		mainView.draw();
		mainView.drawSubviews();
	}

	Vector2 getMousePos(bool viewRelative = false) {
		if(viewRelative) return mainView.screenToRel((mouseX, mouseY));
		return (mouseX, mouseY);
	}

	virtual bool handleInterfaceEvent(ConsoleEvent e) {
		// Check for function callbacks
		let func = interfaceCallbacks.GetIfExists(e.name);
		if(func) {
			if( func.call(self, e.args[0], e.args[1], e.args[2], e.IsManual) ) {
				return true;
			}
		}

		// Check for view based function callbacks
		let funcList = viewInterfaceCallbacks.GetIfExists(e.name);
		if(funcList) {
			for(int x = 0; x < funcList.functions.size(); x++) {
				let funcHolder = funcList.functions[x];
				if(funcHolder.receiver) {
					if( funcHolder.func.call(funcHolder.receiver, e.args[0], e.args[1], e.args[2], e.IsManual) ) {
						return true;
					}
				} else {
				 	// Remove stale references
					funcList.functions.delete(x);
					x--;
				}
			}
		}

		if(isModal && uiParentMenu) {
			return uiParentMenu.handleInterfaceEvent(e);
		}

		return false;
	}

	override bool onUIEvent(UIEvent ev) {
		if(!mainView) return false;

		bool mouseHasMovedEnough = false;

		if (ev.type == UIEvent.Type_MouseMove) {
			// Check the mouse delta to see if we've moved enough to be considered a real move
			if(mouseX >= 0 && mouseY >= 0 && (ev.mouseX - mouseX >= 1 || ev.mouseY >= 1)) mouseHasMovedEnough = true;
			mouseX = ev.mouseX;
			mouseY = ev.mouseY;
		}

		let veev = new("ViewEvent");
		ViewEvent.fromGZDUiEvent(ev, veev);

		// Inject mouse pos into mouse wheel events
		if(ev.type >= UIEvent.Type_WheelUp && ev.type <= UIEvent.Type_WheelLeft) {
			veev.mouseX = mouseX;
			veev.mouseY = mouseY;
		}

		if(mainView.event(veev)) return true;

        // Perform basic UI callbacks for simple event handling
		// Elements can use both methods, but are encouraged to only use one or the other
		Vector2 mousePos = (veev.mouseX, veev.mouseY);
		switch(ev.type) {
			case UIEvent.Type_LButtonDown:
				mouseX = ev.mouseX;
				mouseY = ev.mouseY;
				mouseCaptureBeforeMDOWN = mMouseCapture; 
				SetCapture(true);
				if(mouseDownEvent(veev)) return true;
				break;
			case UIEvent.Type_LButtonUp:
				mouseX = ev.mouseX;
				mouseY = ev.mouseY;
				SetCapture(mouseCaptureBeforeMDOWN);
				if(mouseUpEvent(veev)) return true;
				break;
			case UIEvent.Type_MouseMove:
				if(mouseHasMovedEnough) mouseMoveEvent(veev);
				break;
			case UIEvent.Type_KeyDown:
			case UIEvent.Type_KeyRepeat:
				if(ev.KeyChar == UIEvent.Key_Tab && activeControl) {
					// Attempt to focus to the next control
					UIControl nextCon = ev.IsShift ? activeControl.getPrevControl() : activeControl.getNextControl();
					if(nextCon) {
						navigateTo(nextCon);
						return true;
					}
				}
				break;
			default:
				break;
		}

		return Super.onUIEvent(ev);
	}

	virtual bool mouseDownEvent(ViewEvent ev) {
		if(mouseMovementShowsCursor) showCursor();

		mouseDown = true;
		mouseCounter++;
		lastEventWasMouse = true;

		// Find front most object and call to it
		Vector2 mousePos = (ev.mouseX, ev.mouseY);
		UIView v = mainView.raycastPoint(mousePos);
		mDownView = v;
		if(v) {
			if(ev.IsCtrl && ev.IsShift && developer) {
				Console.Printf("View Hit: %s At: X(%f)  Y(%f)", v.getClassName(), mousePos.x, mousePos.y);
			}
			v.onMouseDown(mousePos, ev);
			return true;
		}

		return false;
	}

	virtual bool mouseUpEvent(ViewEvent ev) {
		if(mouseMovementShowsCursor) showCursor();
		lastEventWasMouse = true;
		mouseDown = false;

		// If we are dragging, the drag object gets the mouse up event
		if(dragControl) {
			Vector2 mousePos = (ev.mouseX, ev.mouseY);
			dragControl.onMouseUp(mousePos, ev);

			// If we are still global dragging, this is where it ends
			if(dragControl && globalDragging) {
				// Stop dragging and call onDragEnd
				stopDragging(dragControl, dropped: dragTargetView != null);
			} else {
				dragControl = null;
			}

			return true;
		}

		// Call mouse up on the previously selected Down view
		if(mDownView) {
			Vector2 mousePos = (ev.mouseX, ev.mouseY);
			mDownView.onMouseUp(mousePos, ev);
			mDownView = null;
			return true;
		}

		return false;
	}

	virtual void testMouse(int mouseX, int mouseY, bool onlyDeselect = false) {
		Vector2 mousePos = (mouseX, mouseY);
		UIView v = mainView.raycastPoint(mousePos);

		if(mHoverView && v != mHoverView) {
			mHoverView.onMouseExit(mousePos, v);

			UIControl con = UIControl(mHoverView);
			if(dragControl == null && con && con == activeControl) {
				// Make sure this doesn't forward to the same activeControl
				UIView vsel = v;
				while(vsel && vsel.forwardSelection) { vsel = vsel.forwardSelection; }

				if(activeControl != vsel && (!activecontrol.cancelsHoverDeSelect || (vsel is 'UIControl' && !UIControl(vsel).rejectHoverSelection))) {
					activeControl.onDeselected();
					lastActiveControl = activeControl;
					activeControl = null;
				}
			}

			mHoverView = null;
		}

		if(!onlyDeselect) {
			if(v && v != mHoverView && dragControl == null) {
				mHoverView = v;
				v.onMouseEnter(mousePos);

				// Abort if this control does not support hover selection
				if(!UIControl(v) || !UIControl(v).rejectHoverSelection) {
					// Check for forwarding first, then check for control
					UIView vsel = v;
					while(vsel && vsel.forwardSelection) { vsel = vsel.forwardSelection; }

					// If this is a control, make it the active control unless the view says NO
					UIControl con = UIControl(vsel);
					if(con && con != activeControl && !con.isDisabled() && !con.rejectHoverSelection) {
						navigateTo(con, true);
					}
				}
			}
		}
	}

	virtual void mouseMoveEvent(ViewEvent ev) {
		if(mouseMovementShowsCursor) showCursor();

		testMouse(ev.mouseX, ev.mouseY);

		if(dragControl && dragControl.globalDragging) {
			// Only start dragging if we've actually moved the mouse enough to count
			if((mainView.screenToRel((mouseX, mouseY)) - dragStartPos).length() >= 5) {
				
				// Start dragging officially, beginning with moving the drag control to the top of the view stack
				if(!dragStarted) {
					Console.Printf("Starting drag with control: %s", dragControl.getClassName());
					dragControl.frame.pos = dragControl.relToScreen((0, 0));	// Move to screen coords
					globalDragOriginalView = dragControl.parent;
					dragControl.removeFromSuperview();
					dragControl.globalDragging = true;
					mainView.add(dragControl);
					dragStarted = true;
				}
			}

			if(dragStarted) {
				dragControl.onDrag((mouseX, mouseY), dragRestrictView);

				// If we are still dragging, test for overlap with drag target views
				if(dragControl && dragControl.globalDragging) {
					// Check if we are over a view that accepts drops
					UIView oldDragTargetView = dragTargetView;
					UIView v = mainView.raycastDragTarget(dragControl, (mouseX, mouseY));
					if(v && dragControl) {
						if( dragControl.onDragOver(v, (mouseX, mouseY), dragRestrictView) ) {
							dragTargetView = v;
						}

						if( oldDragTargetView && oldDragTargetView != v ) {
							// If our new view replaces the old one, call onDragOut on the old view
							oldDragTargetView.onDragOut(dragControl, (mouseX, mouseY), dragRestrictView);
						}
					} else {
						if( oldDragTargetView ) {
							oldDragTargetView.onDragOut(dragControl, (mouseX, mouseY), dragRestrictView);
						}

						dragTargetView = null;
					}
				}
			}
		}
	}


	virtual bool onBack() {
		Close();
		let m = GetCurrentMenu();
		MenuSound(m != null ? "menu/backup" : "menu/clear");
		if (!m) menuDelegate.MenuDismissed();

		return true;
	}

	virtual bool navigateTo(UIControl con, bool mouseSelection = false, bool controllerSelection = false) {
		for(int loopLimit = 0; loopLimit < 200 && con && con.forwardSelection; loopLimit++) {
			con = UIControl(con.forwardSelection);
		}

		if(!con || con == activeControl) { return false; }

		if(activeControl) {
			activeControl.onDeselected();
		}

		lastActiveControl = activeControl;
		activeControl = con;
		activeControl.onSelected(mouseSelection, controllerSelection);

		return true;
	}

	virtual void clearNavigation() {
		if(activeControl) {
			activeControl.onDeselected();
		}

		lastActiveControl = null;
		activeControl = null;
	}

	bool isUsingController() {
		return controlCounter > 0;
	}

	bool isUsingMouse() {
		return mouseCounter > 1;
	}

	bool isMostlyUsingMouse() {
		return mouseCounter > controlCounter;
	}

	bool isMostlyUsingController() {
		return controlCounter > mouseCounter;
	}

	bool isUsingKeyboard() {
		return keyboardCounter > 0;
	}

	bool logController(int mkey, bool fromcontroller) {
		if(fromController) {
			controlCounter++;
			lastEventWasMouse = false;
		} else if(mkey < NUM_MKEYS && mkey != MKEY_Back) {
			keyboardCounter++;
			lastEventWasMouse = false;
		}

		// This is entirely for syntax: return logController(key, fromCon);
		return true;
	}

	virtual void didNavigate(bool withController) {
		// Do nothing by default
	}

	virtual void didActivate(UIControl control, bool withController) {
		// Nothing by default
	}

	virtual void didReverse(bool withController) {
		// Nothing by default
	}

	virtual UIControl findFirstControl(int mkey) {
		return null;
	}

	override bool MenuEvent(int mkey, bool fromcontroller) {
		logController(mkey, fromcontroller);

		if(fromController && gamepadHidesCursor) {
			hideCursor();
		}

		let activeControl = activeControl ? activeControl : lastActiveControl;
		if(!activeControl) {
			if(mkey == MKEY_Back) {
				if(onBack()) {
					didReverse(fromController);
					return true;
				}
			}
			
			// Attempt to find an automatic selection
			let c = findFirstControl(mkey);
			if(c) {
				navigateTo(c);
				return true;
			}
			
			return Super.MenuEvent(mkey, fromcontroller);
		}

		// Check active control first
		if(activeControl.menuEvent(mkey, fromcontroller)) {
			return true;
		}

		switch (mkey) {
			case MKEY_Back:
				if(onBack()) {
					didReverse(fromController);
					return true;
				}
				break;

			case MKEY_Left:
				{
					UIControl c = activeControl.navLeft;
					
					if(c && c.isDisabled()) {
						for(int loopLimit = 0; loopLimit < 200 && c && c.isDisabled() && c.navLeft != c; loopLimit++) {
							c = c.navLeft;
						}
					}

					if(c && !c.isDisabled() && navigateTo(c, false, fromController)) { 
						didNavigate(fromController);
						return true;
					}
				}
				break;
			case MKEY_Right:
				{
					UIControl c = activeControl.navRight;
					
					if(c && c.isDisabled()) {
						for(int loopLimit = 0; loopLimit < 200 && c && c.isDisabled() && c.navRight != c; loopLimit++) {
							c = c.navRight;
						}
					}
					if(c && !c.isDisabled() && navigateTo(c, false, fromController)) { 
						didNavigate(fromController);
						return true; 
					}
				}
				break;
			case MKEY_Up:
				{
					UIControl c = activeControl.navUp;
					
					if(c && c.isDisabled()) {
						for(int loopLimit = 0; loopLimit < 200 && c && c.isDisabled() && c.navUp != c; loopLimit++) {
							c = c.navUp;
						}
					}
					if(c && !c.isDisabled() && navigateTo(c, false, fromController)) { 
						didNavigate(fromController);
						return true;
					}
				}
				break;
			case MKEY_Down:
				{
					UIControl c = activeControl.navDown;
					
					if(c && c.isDisabled()) {
						for(int loopLimit = 0; loopLimit < 200 && c && c.isDisabled() && c.navDown != c; loopLimit++) {
							c = c.navDown;
						}
					}
					if(c && !c.isDisabled() && navigateTo(c, false, fromController)) { 
						didNavigate(fromController);
						return true; 
					}
				}
				break;
			case MKEY_Enter:
				if(activeControl.onActivate(false, fromController)) {
					didActivate(activeControl, fromController);
					return true; 
				}
				break;
			default:
				break;
		}

		return Super.MenuEvent(mkey, fromcontroller);
	}


	override bool OnInputEvent(InputEvent ev) {
		//Console.Printf("INPUT EVENT: %d", ev.KeyChar);
		return Super.OnInputEvent(ev);
	}


	virtual void startDragging(UIControl source, bool globalDrag = false, UIView restrictView = null, bool startImmediately = false) {
		dragControl = source;
		dragStarted = startImmediately;
		globalDragging = globalDrag;
		dragRestrictView = restrictView;
		dragStartPos = mainView.screenToRel((mouseX, mouseY));

		if(globalDragging) {
			globalDragOriginalView = dragControl.parent;
			dragControl.globalDragging = true;
		}

		// If starting immediately, move the view to the top of the view stack
		if(dragStarted && globalDragging) {
			dragControl.frame.pos = dragControl.relToScreen((0, 0));	// Move to screen coords
			globalDragOriginalView = dragControl.parent;
			dragControl.removeFromSuperview();
			mainView.add(dragControl);
		}
	}


	virtual void stopDragging(UIControl source, bool dropped = true) {
		if(dragControl) {
			if(globalDragging) {
				if(!dragStarted) dropped = false;

				// Returns true if this was a successful drag
				if( dragControl.onDragEnd(dragTargetView, (mouseX, mouseY), dragRestrictView, dropped) ) {
					if(dropped && dragTargetView) {
						// Call the drop func on the target view
						dragTargetView.onDropped(dragControl, (mouseX, mouseY), dragRestrictView);
					}
				}
			}
		}

		globalDragOriginalView = null;
		dragControl = null;
		globalDragging = false;
		dragStarted = false;
		dragRestrictView = null;
	}


	virtual void viewRemoved(UIView v) {
		if(v == mHoverView) {
			mHoverView = null;
		}

		if(v == mDownView) {
			mDownView = null;
		}

		if(UIControl(v) == activeControl) {
			activeControl = null;
		}

		if(UIControl(v) == lastActiveControl) {
			lastActiveControl = null;
		}
	}

	virtual void handleControl(UIControl ctrl, int event, bool fromMouse = false, bool fromController = false) { }

	// Helper Funcs
	void menuSound(string snd, float volume = 1.0) {
        S_StartSound (snd, CHAN_VOICE, CHANF_UI, snd_menuvolume * volume);
    }

    double getTime() {
        return MSTimeF() / 1000.0;
    }
	
	double getRenderTime() {
		return (System.GetTimeFrac() + double(ticks)) * ITICKRATE;
	}
}