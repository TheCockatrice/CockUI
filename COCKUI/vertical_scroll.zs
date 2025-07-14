class UIScrollBarConfig {
    NineSlice barBackground, barSlideBackground;
    UIButtonState buttStates[UIButton.NUM_STATES];
    double barWidth, buttSize, insetA, insetB;

    static UIScrollBarConfig Create( double barWidth, double buttSize,
                                    NineSlice barBgSlices, NineSlice barSlideSlices,
                                    UIButtonState buttonNormal = null,
                                    UIButtonState buttonHover = null,
                                    UIButtonState buttonPressed = null,
                                    UIButtonState buttonDisabled = null,
                                    UIButtonState buttonSelected = null,
                                    UIButtonState buttonSelectedHover = null,
                                    UIButtonState buttonSelectedPressed = null,
                                    double insetA = 0, double insetB = 0) {
        
        let ret = new("UIScrollBarConfig");
        ret.barWidth = barWidth;
        ret.barBackground = barBgSlices;
        ret.barSlideBackground = barSlideSlices;
        ret.buttStates[UIButton.State_Normal] = buttonNormal;
        ret.buttStates[UIButton.State_Hover] = buttonHover;
        ret.buttStates[UIButton.State_Pressed] = buttonPressed;
        ret.buttStates[UIButton.State_Disabled] = buttonDisabled;
        ret.buttStates[UIButton.State_Selected] = buttonSelected;
        ret.buttStates[UIButton.State_SelectedHover] = buttonSelectedHover;
        ret.buttStates[UIButton.State_SelectedPressed] = buttonSelectedPressed;
        ret.insetA = insetA;
        ret.insetB = insetB;
        ret.buttSize = buttSize;

        return ret;
    }
}


class UIVerticalScroll : UIControl {
    UIViewManager mLayout;
    UISlider scrollbar;
    UIPin layoutTopPin;
    UIScrollBarConfig config;
    double targetScroll, sourceScroll;
    double mouseScrollAmount;
    double scrollbarPadding;                // Pad when scrollbar is showing via autohide/show
    uint ticks, scrollStart;

    bool autoHideScrollbar, autoHideAdjustsSize, hugEnd;
    int animateTicks;

    const scrollTicks = 15;

    UIVerticalScroll init( Vector2 pos, Vector2 size, double scrollWidth, double buttSize,
                                    NineSlice barBgSlices, NineSlice barSlideSlices,
                                    UIButtonState barButtNormal = null,
                                    UIButtonState barButtHover = null,
                                    UIButtonState barButtPressed = null,
                                    UIButtonState barButtDisabled = null,
                                    UIButtonState barButtSelected = null,
                                    UIButtonState barButtSelectedHover = null,
                                    UIButtonState barButtSelectedPressed = null,
                                    int insetA = 0, int insetB = 0,
                                    double scrollPadding = 0) {
         
        let config = UIScrollBarConfig.Create(scrollWidth, buttsize, barBgSlices, barSlideSlices,
            barButtNormal,
            barButtHover,
            barButtPressed,
            barButtDisabled, 
            barButtSelected,
            barButtSelectedHover,
            barButtSelectedPressed,
            insetA, insetB
        );

        return initFromConfig(pos, size, config, scrollPadding);
    }

    UIVerticalScroll initFromConfig(Vector2 pos, Vector2 size, UIScrollBarConfig config, double scrollPadding = 0) {
        Super.Init(pos, size);

        self.config = config;
        scrollbarPadding = scrollPadding;

        mLayout = new("UIVerticalLayout").init((0,0), (100,100));
        mLayout.pin(UIPin.Pin_Left);
        layoutTopPin = mLayout.pin(UIPin.Pin_Top);
        mLayout.pin(UIPin.Pin_Right, offset: -(config.barWidth + scrollbarPadding));
        mLayout.layoutMode = UIViewManager.Content_SizeParent;
        add(mLayout);

        scrollbar = new("UISlider").init((0,0), (config.barWidth, 0),
            0, 1.0, 0.1,
            config.barBackground, config.barSlideBackground,
            config.buttStates[UIButton.State_Normal],
            config.buttStates[UIButton.State_Hover],
            config.buttStates[UIButton.State_Pressed],
            config.buttStates[UIButton.State_Disabled],
            config.buttStates[UIButton.State_Selected],
            config.buttStates[UIButton.State_SelectedHover],
            config.buttStates[UIButton.State_SelectedPressed],
            isVertical: true
        );
        scrollbar.buttonSize = config.buttSize;
        scrollbar.pin(UIPin.Pin_Right);
        scrollbar.pin(UIPin.Pin_Top, offset: config.insetA);
        scrollbar.pin(UIPin.Pin_Bottom, offset: -config.insetB);
        scrollbar.increment = 0.1;
        add(scrollbar);

        targetScroll = -1;
        mouseScrollAmount = 100;
        autoHideAdjustsSize = false;
        rejectHoverSelection = true;

        return self;
    }

    void initBasic(Vector2 pos, Vector2 size) {
        Super.Init(pos, size);
    }

    override UIView baseInit() {
        Super.baseInit();

        scrollbarPadding = 0;
        targetScroll = -1;
        mouseScrollAmount = 100;
        autoHideAdjustsSize = false;
        rejectHoverSelection = true;

        return self;
    }

    override void tick() {
        Super.tick();

        // Handle scrolling animation
        if(targetScroll != -1 && ticks - scrollStart == animateTicks) {
            double a = animateTicks > 0 ? double(ticks - scrollStart) / double(animateTicks) : 1;
            if(animateTicks > 5) a = UIMath.EaseOutCubicf(a);
            scrollNormalized(UIMath.lerpd(sourceScroll, targetScroll, a));
            targetScroll = -1;  // Reset target scroll
        }

        ticks++;
    }

    override void draw() {
        double passTics = System.GetTimeFrac() + double(ticks - scrollStart);
        
        // Handle scrolling animation
        if(targetScroll != -1 && passTics <= animateTicks) {
            double a = passTics / double(animateTicks);
            if(animateTicks > 5) a = UIMath.EaseOutCubicf(a);
            scrollNormalized(UIMath.lerpd(sourceScroll, targetScroll, a), sendEvt: false);
        }

        Super.draw();
    }

    override bool handleSubControl(UIControl ctrl, int event, bool fromMouse, bool fromController) {
        if(ctrl == scrollbar && event == UIHandler.Event_ValueChanged) {
            handleScrollbar(scrollbar.getNormalizedValue(), true, fromMouse, fromController);
            return true;
        }

        return Super.handleSubControl(ctrl, event, fromMouse, fromController);
    }

    virtual void handleScrollbar(double value, bool sendEvt = true, bool fromMouse = true, bool fromController = false) {
        if(contentsCanScroll()) {
            layoutTopPin.offset = -((mLayout.frame.size.y - frame.size.y) * value);
            mLayout.frame.pos.y = layoutTopPin.offset;
        } else {
            layoutTopPin.offset = 0;
            mLayout.frame.pos.y = layoutTopPin.offset;
        }
        

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse, fromController);
        }
    }

    // Only accurate if properly sized/layed-out
    virtual bool contentsCanScroll() {
        return mLayout.frame.size.y > frame.size.y;
    }

    // Update scrollbar sizes and optionally adjust scroll
    void updateScrollbar(double scrollNormalized = -1) {
        if(mLayout.frame.size.y <= frame.size.y) {
            if(autoHideScrollbar) {
                scrollbar.hidden = true;
                
                if(autoHideAdjustsSize) {
                    let rpin = mLayout.firstPin(UIPin.Pin_Right);
                    if(rpin && rpin.offset != 0) {
                        rpin.offset = 0;
                        mLayout.layout();
                    }
                }
            } else {
                if(autoHideAdjustsSize) {
                    let rpin = mLayout.firstPin(UIPin.Pin_Right);
                    if(rpin && rpin.offset ~== 0) {
                        rpin.offset = -(config.barWidth + scrollbarPadding);
                        mLayout.layout();
                    }
                }
            }

            scrollbar.setDisabled(true);
            scrollbar.value = 0;

            if(hugEnd) {
                mLayout.frame.pos.y = frame.size.y - (mLayout.frame.size.y * mLayout.scale.y);
                layoutTopPin.offset = mLayout.frame.pos.y;
            } else {
                mLayout.frame.pos.y = 0;
                layoutTopPin.offset = 0;
            }
        } else {
            if(autoHideScrollbar && scrollbar.hidden) {
                scrollbar.hidden = false;

                if(autoHideAdjustsSize) {
                    let rpin = mLayout.firstPin(UIPin.Pin_Right);
                    if(rpin && rpin.offset ~== 0) {
                        rpin.offset = -(config.barWidth + scrollbarPadding);
                        mLayout.layout();
                    }
                }
            }

            scrollbar.setDisabled(false);

            if(scrollNormalized >= 0) {
                layoutTopPin.offset = -((mLayout.frame.size.y - frame.size.y) * scrollNormalized);
                mLayout.frame.pos.y = layoutTopPin.offset;
            }
        }

        if(mLayout.frame.size.y > 0) {
            scrollbar.buttonScrollSize = max(max(15, scrollbar.minButtonScrollSize), scrollbar.frame.size.y * min(1.0, frame.size.y / mLayout.frame.size.y));
        } else {
            scrollbar.buttonScrollSize = max(15, scrollbar.minButtonScrollSize);
        }
        scrollbar.layoutButton();
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        // Get current scroll value
        double scroll = scrollbar.getNormalizedValue();

        Super.layout(parentScale, parentAlpha);

        updateScrollbar(scroll);
    }

    override void onAdjustedPostLayout(UIView sourceView) {
        updateScrollbar(scrollbar.getNormalizedValue());
    }

    virtual void scrollNormalized(double val, bool animated = false, bool sendEvt = true, bool fromMouse = true, int animateTicks = scrollTicks) {
        if(requiresLayout) {
            layout();
        }
        
        if(!animated) {
            scrollbar.setNormalizedValue(val, true);

            layoutTopPin.offset = -((mLayout.frame.size.y - frame.size.y) * val);
            mLayout.frame.pos.y = layoutTopPin.offset;
        } else {
            sourceScroll = scrollbar.getNormalizedValue();
            targetScroll = val;
            scrollStart = ticks;
            self.animateTicks = animateTicks;
        }

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse);
        }
    }

    virtual void scrollBy(double offset, bool animated = false, bool sendEvt = true, bool fromMouse = true, int animateTicks = scrollTicks) {
        if(requiresLayout) {
            layout();
        }

        let startScroll = targetScroll != -1 ? targetScroll : scrollbar.getNormalizedValue();
        let val = clamp(startScroll + offset, 0.0, 1.0f);

        if(!animated) {
            scrollbar.setNormalizedValue(val, true);

            layoutTopPin.offset = -((mLayout.frame.size.y - frame.size.y) * val);
            mLayout.frame.pos.y = layoutTopPin.offset;
        } else {
            sourceScroll = scrollbar.getNormalizedValue();
            targetScroll = val;
            scrollStart = ticks;
            self.animateTicks = animateTicks;
            // Do the first tick of the scroll now
        }

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse);
        }
    }

    virtual void scrollByPixels(double offset, bool animated = false, bool sendEvt = true, bool fromMouse = true, int animateTicks = scrollTicks) {
        if(requiresLayout) {
            layout();
        }

        let startScroll = targetScroll != -1 ? targetScroll : scrollbar.getNormalizedValue();
        let normalizedNewVal = startScroll + (offset / (mLayout.frame.size.y - frame.size.y));
        let val = clamp(normalizedNewVal, 0.0, 1.0f);

        if(!animated) {
            scrollbar.setNormalizedValue(val, true);

            layoutTopPin.offset = -((mLayout.frame.size.y - frame.size.y) * val);
            mLayout.frame.pos.y = layoutTopPin.offset;
        } else {
            sourceScroll = scrollbar.getNormalizedValue();
            targetScroll = val;
            scrollStart = ticks;
            self.animateTicks = animateTicks;
            // Do the first tick of the scroll now
        }

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse);
        }
    }

    virtual void scrollTo(UIView view, bool animated = false, double padding = 20) {
        if(requiresLayout) {
            layout();
        }

        Vector2 screenPosTop = view.relToScreen((0,0 - padding));
        Vector2 screenPosBottom = view.relToScreen((0,view.frame.size.y + padding));
        
        Vector2 layoutPosTop = mLayout.screenToRel(screenPosTop);
        Vector2 layoutPosBottom = mLayout.screenToRel(screenPosBottom);

        // if pos is already inside the viewing window, don't worry about it
        let relPosTop = screenToRel(screenPosTop);
        let relPosBot = screenToRel(screenPosBottom);
        if(mLayout.frame.size.y == 0 || (relPosTop.y >= 0 && relPosBot.y < frame.size.y)) {
            return; // We are inside the scroll view or not valid
        }

        if(mLayout.frame.size.y <= frame.size.y) {
            return; // No scrolling, how did we even get here?
        }

        double scroll = max(min(((relPosBot.y > frame.size.y ? layoutPosBottom.y : layoutPosTop.y) / mLayout.frame.size.y), 1.0), 0.0);

        scrollNormalized(scroll, animated);
    }

    void cancelScrollAnim(bool finish = false) {
        if(finish) {
            scrollNormalized(targetScroll);
        }
        targetScroll = -1;
        scrollStart = 0;
    }

    override bool event(ViewEvent ev) {
        if(ev.type == UIEvent.Type_WheelUp || ev.type == UIEvent.Type_WheelDown) {
            // If this event happened while the mouse is inside the scroll view, scroll!
            if(raycastTest((ev.mouseX, ev.mouseY))) {
                if(mLayout.frame.size.y <= frame.size.y) {
                    return true;
                }

                double curPos = targetScroll != -1 ? targetScroll : scrollbar.getNormalizedValue();
                double inc = mouseScrollAmount / (mLayout.frame.size.y - frame.size.y);
                if(ev.type == UIEvent.Type_WheelUp) {
                    scrollNormalized(Clamp(curPos - inc, 0.0, 1.0), animated: true, animateTicks: 3);
                } else {
                    scrollNormalized(Clamp(curPos + inc, 0.0, 1.0), animated: true, animateTicks: 3);
                }
                return true;
            }
        }

        return Super.event(ev);
    }

    override Vector2 calcMinSize(Vector2 parentSize) {
        // We can only expand vertically, so calculate our pinned width
        Vector2 size;
        size.x = MIN(maxSize.x, calcPinnedWidth(parentSize));
        size.y = 9999999;

        size = mLayout.calcMinSize(size);
        size.x = clamp(size.x, minSize.x, maxSize.x);
        size.y = clamp(size.y, minSize.y, maxSize.y);
        // TODO: Include scrollbar if not autohide

        return size;
    }
}