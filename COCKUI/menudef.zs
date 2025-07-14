class UIDefMenu : UIMenu {
    //Array<ListMenuItem> items;
    ListMenuDescriptor desc;
    bool isDisabled;

    virtual UIDefMenu init(Menu parent, ListMenuDescriptor desc) {
		Super.init(parent);
        AnimatedTransition = true;
        Animated = true;
        //calcScale(Screen.GetWidth(), Screen.GetHeight());
        self.desc = desc;

        if(desc) {
            //items.append(desc.mItems);

            // Create items based on the descriptor
            Array<UIVerticalLayout> layoutStack;
            UIVerticalLayout curLayout;
            Array<UIPin> pins;
            UIPin wPin, hPin;
            UIControl lastControl, firstControl;

            for(int x = 0; x < desc.mItems.size(); x++) {
                ListMenuItem i = desc.mItems[x];

                if(i is "ListMenuItemPin") {
                    pins.push(ListMenuItemPin(i).pin);
                } else if(i is "ListMenuItemPinWidth") {
                    wPin = ListMenuItemPinWidth(i).pin;
                } else if(i is "ListMenuItemPinHeight") {
                    hPin = ListMenuItemPinHeight(i).pin;
                } else if(i is "ListMenuItemDisabled") {
                    isDisabled = true;
                } else if(i is "ListMenuItemVerticalGroup") {
                    let li = ListMenuItemVerticalGroup(i);
                    curLayout = new("UIVerticalLayout").init((0, 0), (li.width, li.height));
                    if(li.height == -1) curLayout.layoutMode = UIViewManager.Content_SizeParent;
                    curLayout.itemSpacing = li.spacing;
                    curLayout.ignoreHiddenViews = true;
                    curLayout.pins.Append(pins);
                    curLayout.clipsSubviews = false;
                    pins.clear();
                    if(layoutStack.size()) {
                        layoutStack[layoutStack.size() - 1].addManaged(curLayout);
                    } else {
                        mainView.add(curLayout);
                    }
                    layoutStack.push(curLayout);
                } else if(i is "ListMenuItemReset") {
                    curLayout = null;
                    layoutStack.clear();
                    pins.clear();
                    wPin = null;
                    hPin = null;
                } else if(i is "ListMenuItemEndGroup") {
                    layoutStack.pop();
                    if(layoutStack.size()) {
                        curLayout = layoutStack[layoutStack.size() - 1];
                    } else {
                        curLayout = null;
                    }
                }else {
                    UIView v = createItemView(i);
                    if(v) {
                        // Apply pins
                        v.pins.Append(pins);
                        if(wPin) v.widthPin = wPin;
                        if(hPin) v.heightPin = hPin;
                        wPin = null;
                        hPin = null;
                        pins.clear();

                        // Add to current layout if there is one
                        if(curLayout) {
                            curLayout.addManaged(v);
                            v.pin(UIPin.Pin_Left);
                            v.pin(UIPin.Pin_Right);
                        } else {
                            mainView.add(v);
                        }

                        let con = UIControl(v);
                        if(con) {
                            con.controlID = x;

                            // Select the first control as active
                            if(!activeControl) {
                                navigateTo(UIControl(v));
                            }

                            if(!firstControl) {
                                firstControl = con;
                            }
                            
                            con.navUp = lastControl;

                            if(lastControl) {
                                lastControl.navDown = con;
                            }

                            lastControl = con;

                            if(isDisabled) {
                                con.setDisabled( true );
                            }
                        }
                    }

                    isDisabled = false;
                }
            }

            // Loop selection chain
            if(firstControl && lastControl && lastControl != firstControl) {
                lastControl.navDown = firstControl;
                firstControl.navUp = lastControl;
            }
        }

        return self;
    }

    virtual UIView createItemView(ListMenuItem i) {
        /*if(i is "ListMenuItemTextButton") {
            let ib = ListMenuItemTextButton(i);
            let v = new("UIButton").init(
                ib.pos, (300, 40),
                ib.text, ib.fnt,
                UIButtonState.Create("", ib.color),
                UIButtonState.Create("", ib.colorSelected),
                UIButtonState.Create("", ib.colorSelected),
                textAlign: ib.align
            );
            v.setTextPadding(0, ib.yPadTop, 0, ib.yPadBottom);
            if(v.label) v.label.fontScale = ib.textScale;
            if(!v.heightPin) v.pinHeight(UIView.Size_Min);
            return v;
        }

        if(i is "ListMenuItemLabel") {
            let il = ListMenuItemLabel(i);
            let v = new("UILabel").init(
                il.pos, (300, 40),
                il.text, il.fnt,
                il.color,
                textAlign: il.align,
                fontScale: il.textScale
            );

            if(!v.heightPin) v.pinHeight(UIView.Size_Min);
            return v;
        }*/

        if(i is 'UIListMenuItem') {
            return UIListMenuItem(i).buildView();
        }

        return null;
    }

    override void handleControl(UIControl ctrl, int event, bool fromMouseEvent) {
        if(event == UIHandler.Event_Activated) {
            if(desc.mItems.size() > ctrl.controlID) {
                let i = desc.mItems[ctrl.controlID];

                if(i.activate()) {
                    MenuSound("menu/advance");
                }
            }
        }
    }

    override bool navigateTo(UIControl con, bool mouseSelection) {
		let ac = activeControl;

        let ff = Super.navigateTo(con, mouseSelection);

        if(ac != activeControl && !mouseSelection && ticks > 1) {
            MenuSound("menu/cursor");
        }
        
        return ff;
	}
}


class UIDefListMenu : Listmenu {
    UIDefMenu umen;
    Menu parentMenu;
    ListMenuDescriptor mDesc2;
    int oneTick;

    override void init(Menu parent, ListMenuDescriptor desc) {
		Super.Init(parent, new("ListMenuDescriptor"));
        DontDim = true;
        DontBlur = true;
        // This class won't get used, since it's not a UIMenu, we will just replace ourselves with a UIMenu
        //
        mDesc2 = desc;
        parentMenu = parent;
    }

    override void ticker() {
        //if(oneTick == 1) {
            close();

            class<UIDefMenu> cls = "UIDefMenu";

            // Find the subclass if it exists, must be the first item in the list
            if(mDesc2.mItems.size() > 0 && mDesc2.mItems[0] is "ListMenuItemSubClass") {
                cls = (class<UIDefMenu>)(ListMenuItemSubClass(mDesc2.mItems[0]).mSubclass);
            }

            if(cls == null) {
                cls = "UIDefMenu";
                Console.Printf("Defaulting to UIDEFMENU");
            } 
            umen = UIDefMenu(new(cls));
            umen.init(parentMenu, mDesc2);
            umen.ActivateMenu();
        //}
        //oneTick++;
    }

    override bool OnUIEvent(UIEvent ev) { return true; }
    override bool MenuEvent (int mkey, bool fromcontroller) { return true; }
}


class UIReplaceMenu : Listmenu {
    UIMenu umen;
    Menu parentMenu;
    ListMenuDescriptor mDesc2;

    override void init(Menu parent, ListMenuDescriptor desc) {
		Super.Init(parent, new("ListMenuDescriptor"));
        DontDim = true;
        DontBlur = true;
        parentMenu = parent;
        mDesc2 = desc;
    }

    override void ticker() {
        close();

        class<UIMenu> cls;

        // Find the subclass if it exists, must be the first item in the list
        if(mDesc2.mItems.size() > 0 && mDesc2.mItems[0] is "ListMenuItemSubClass") {
            cls = ListMenuItemSubClass(mDesc2.mItems[0]).mSubclass;
        } else {
            ThrowAbortException("UIReplaceMenu: No subclass specified in the first item of the descriptor");
        }

        if(cls == null) {
            ThrowAbortException("UIReplaceMenu: Subclass could not be resolved");
        } 

        umen = UIMenu(new(cls));
        umen.init(parentMenu);
        umen.ActivateMenu();
    }

    override bool OnUIEvent(UIEvent ev) { return true; }
    override bool MenuEvent (int mkey, bool fromcontroller) { return true; }
}


class UIListMenuItem : ListMenuItem {
    virtual UIView buildView() {
        return null;
    }
}


class ListMenuItemPin : ListMenuItem {
    UIPin pin;

    void init(ListMenuDescriptor desc, string first, string second = "pfft", int offset = 0, float value = 1.0, bool isFactor = false) {
        Super.Init();
        pin = UIPin.Create(anchorType(first), anchorType(second), value, offset, isFactor);
    }

    int anchorType(string st) {
        if(st == "right") {
            return UIPin.Pin_Right;
        } else if(st == "top") {
            return UIPin.Pin_Top;
        } else if(st == "bottom") {
            return UIPin.Pin_Bottom;
        } else if(st == "hcenter") {
            return UIPin.Pin_HCenter;
        } else if(st == "vcenter") {
            return UIPin.Pin_VCenter;
        }

        return UIPin.Pin_Left;
    }
}

class ListMenuItemPinWidth : ListMenuItem {
    UIPin pin;

    void init(ListMenuDescriptor desc, float offset = 0, float value = 1.0, bool isFactor = false) {
        Super.Init();
        pin = UIPin.Create(0, 0, value, offset, isFactor);
    }
}

class ListMenuItemPinHeight : ListMenuItem {
    UIPin pin;

    void init(ListMenuDescriptor desc, float offset = 0, float value = 1.0, bool isFactor = false) {
        Super.Init();
        pin = UIPin.Create(0, 0, value, offset, isFactor);
    }
}


class ListMenuItemSubClass : ListMenuItem {
    class<UIMenu> mSubclass;

    void Init(ListMenuDescriptor desc, string menuClass) {
        Super.Init();

        mSubclass = menuClass;
    }
}

class ListMenuItemVerticalGroup : ListMenuItem {
    int width, height, spacing;

    void Init(ListMenuDescriptor desc, int width = 900, int height = -1, int spacing = 0) {
		Super.Init();

        self.width = width;
        self.height = height;
        self.spacing = spacing;
	}
}

class ListMenuItemReset : ListMenuItem {
    void Init() {
        Super.Init();
    }
}

class ListMenuItemEndGroup : ListMenuItem {
    void Init() {
        Super.Init();
    }
}


class ListMenuItemTextButton : UIListMenuItem {
    string text, hotkey, target;
    Font fnt;
    int color, colorSelected;
    int yPadTop, yPadBottom;
    int align;
    Vector2 textScale;
    Vector2 pos;

    void Init(ListMenuDescriptor desc, String text, String hotkey = "", String target = "",  int align = 48, int yPadTop = 0, int yPadBottom = 0, float textScaleX = 1.0, float textScaleY = 1.0) {
		Super.Init();

        self.target = target;
        self.text = text.filter();
        self.hotkey = hotkey;
        fnt = desc.mFont;
        self.color = desc.mFontColor;
        self.colorSelected = desc.mFontColor2;
        self.yPadTop = yPadTop;
        self.yPadBottom = yPadBottom;
        self.textScale = (textScaleX, textScaleY);
        self.align = align;

        pos = (mXpos, mYpos);
	}

    override bool Activate() {
        if(target == "") {
            return false;
        }

        Menu.SetMenu(target, 0);
		
		return true;
	}

    override UIView buildView() {
        let v = new("UIButton").init(
            pos, (300, 40),
            text, fnt,
            UIButtonState.Create("", color),
            UIButtonState.Create("", colorSelected),
            UIButtonState.Create("", colorSelected),
            textAlign: align
        );

        v.setTextPadding(0, yPadTop, 0, yPadBottom);
        if(v.label) v.label.fontScale = textScale;
        if(!v.heightPin) v.pinHeight(UIView.Size_Min);
        return v;
    }
}


class ListMenuItemLabel : UIListMenuItem {
    string text;
    Font fnt;
    int color, colorSelected;
    int align;
    Vector2 textScale;
    Vector2 pos;

    void Init(ListMenuDescriptor desc, String text, int align = 48, float textScaleX = 1.0, float textScaleY = 1.0) {
		Super.Init();

        text = StringTable.Localize(text);
        self.text = text;
        fnt = desc.mFont;
        self.color = desc.mFontColor;
        self.colorSelected = desc.mFontColor2;
        self.textScale = (textScaleX, textScaleY);
        self.align = align;

        pos = (mXpos, mYpos);
	}

    override UIView buildView() {
        let v = new("UILabel").init(
            pos, (300, 40),
            text, fnt,
            color,
            textAlign: align,
            fontScale: textScale
        );

        if(!v.heightPin) v.pinHeight(UIView.Size_Min);
        return v;
    }
}


class ListMenuItemImage : UIListMenuItem {
    string img;
    int style, anchor;
    Vector2 pos;

    void Init(ListMenuDescriptor desc, String img, int style = 0, int anchor = 1) {
		Super.Init();

        self.img = img;
        self.style = style;
        self.anchor = anchor;
        pos = (mXpos, mYpos);
	}

    override UIView buildView() {
        let v = new("UIImage").init(
            pos, (100, 100),
            img, imgStyle: style, imgAnchor: anchor
        );

        if(!v.heightPin) v.pinHeight(UIView.Size_Min);
        if(!v.widthPin) v.pinWidth(UIView.Size_Min);
        return v;
    }
}


class ListMenuItemDisabled : ListMenuItem {
    void Init(ListMenuDescriptor desc) {
        Super.Init();
    }
}