class UIHorizontalScroll : UIVerticalScroll {
    UIHorizontalScroll init( Vector2 pos, Vector2 size, double scrollWidth, double buttSize,
                                    NineSlice barBgSlices, NineSlice barSlideSlices,
                                    UIButtonState barButtNormal = null,
                                    UIButtonState barButtHover = null,
                                    UIButtonState barButtPressed = null,
                                    UIButtonState barButtDisabled = null,
                                    UIButtonState barButtSelected = null,
                                    UIButtonState barButtSelectedHover = null,
                                    UIButtonState barButtSelectedPressed = null,
                                    int insetA = 0, int insetB = 0) {

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

        return initFromConfig(pos, size, config);
    }


    UIHorizontalScroll initFromConfig(Vector2 pos, Vector2 size, UIScrollBarConfig config) {
        Super.initBasic(pos, size);

        self.config = config;

        scrollbar = new("UISlider").init((0,0), (0, config.barWidth),
            0, 1.0, 0.1,
            config.barBackground, config.barSlideBackground,
            config.buttStates[UIButton.State_Normal],
            config.buttStates[UIButton.State_Hover],
            config.buttStates[UIButton.State_Pressed],
            config.buttStates[UIButton.State_Disabled],
            config.buttStates[UIButton.State_Selected],
            config.buttStates[UIButton.State_SelectedHover],
            config.buttStates[UIButton.State_SelectedPressed],
            isVertical: false
        );
        scrollbar.buttonSize = config.buttSize;
        scrollbar.pin(UIPin.Pin_Left, offset: config.insetA);
        scrollbar.pin(UIPin.Pin_Right, offset: -config.insetB);
        scrollbar.pin(UIPin.Pin_Bottom);
        scrollbar.increment = 0.1;
        add(scrollbar);

        mLayout = new("UIHorizontalLayout").init((0,0), (100,100));
        layoutTopPin = mLayout.pin(UIPin.Pin_Left);
        mLayout.pin(UIPin.Pin_Top);
        mLayout.pin(UIPin.Pin_Bottom, offset: -config.barWidth);
        mLayout.layoutMode = UIViewManager.Content_SizeParent;
        add(mLayout);

        targetScroll = -1;
        mouseScrollAmount = 50;
        autoHideAdjustsSize = false;
        rejectHoverSelection = true;

        return self;
    }


    override void applyTemplate(UIView template) {
        Super.applyTemplate(template);

        UIHorizontalScroll t = UIHorizontalScroll(template);

        if(t) {
            if(t.mLayout)  mLayout = UIHorizontalLayout(subviews[t.indexOf(t.mLayout)]);
            if(!mLayout) {
                ThrowAbortException("UIHorizontalScroll::applyTemplate: Missing mLayout in template '%s'", template.getClassName());
            }

            layoutTopPin = mLayout.firstPin(UIPin.Pin_Top);

            if(!layoutTopPin) {
                layoutTopPin = mLayout.pin(UIPin.Pin_Top);
            }
        }
    }


    override void handleScrollbar(double value, bool sendEvt, bool fromMouse, bool fromController) {
        if(contentsCanScroll()) {
            layoutTopPin.offset = -((mLayout.frame.size.x - frame.size.x) * value);
            mLayout.frame.pos.x = layoutTopPin.offset;
        } else {
            layoutTopPin.offset = 0;
            mLayout.frame.pos.x = layoutTopPin.offset;
        }
        

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse, fromController);
        }
    }


    override bool contentsCanScroll() {
        return mLayout.frame.size.x > frame.size.x;
    }


    void updateScrollbar(double scroll) {
         // Reapply scroll value, or related
         if(!contentsCanScroll()) {
            if(autoHideScrollbar) {
                scrollbar.hidden = true;
                
                if(autoHideAdjustsSize) {
                    let rpin = mLayout.firstPin(UIPin.Pin_Bottom);
                    if(rpin && rpin.offset != 0) {
                        rpin.offset = 0;
                        mLayout.layout();
                    }
                }
            } else {
                if(autoHideAdjustsSize) {
                    let rpin = mLayout.firstPin(UIPin.Pin_Bottom);
                    if(rpin && rpin.offset == 0) {
                        rpin.offset = -config.barWidth;
                        mLayout.layout();
                    }
                }
            }

            scrollbar.setDisabled(true);
            scrollbar.value = 0;

            if(hugEnd) {
                mLayout.frame.pos.x = frame.size.x - (mLayout.frame.size.x * mLayout.scale.x);
                layoutTopPin.offset = mLayout.frame.pos.x;
            } else {
                mLayout.frame.pos.x = 0;
                layoutTopPin.offset = 0;
            }
        } else {
            if(autoHideScrollbar && scrollbar.hidden) {
                scrollbar.hidden = false;
            }

            scrollbar.setDisabled(false);

            layoutTopPin.offset = -((mLayout.frame.size.x - frame.size.x) * scroll);
            mLayout.frame.pos.x = layoutTopPin.offset;
        }

        if(mLayout.frame.size.x > 0) {
            scrollbar.buttonScrollSize = max(max(15, scrollbar.minButtonScrollSize), scrollbar.frame.size.x * min(1.0, frame.size.x / mLayout.frame.size.x));
        } else {
            scrollbar.buttonScrollSize = max(15, scrollbar.minButtonScrollSize);
        }
        scrollbar.layoutButton();
    }


    override void layout(Vector2 parentScale, double parentAlpha) {
        // Get current scroll value
        double scroll = scrollbar.getNormalizedValue();

        UIControl.layout(parentScale, parentAlpha);

        updateScrollbar(scroll);
    }


    override void onAdjustedPostLayout(UIView sourceView) {
        updateScrollbar(scrollbar.getNormalizedValue());
    }


    override void scrollNormalized(double val, bool animated, bool sendEvt, bool fromMouse) {
        if(requiresLayout) {
            layout();
        }
        
        sourceScroll = scrollbar.getNormalizedValue();

        if(!animated) {
            scrollbar.setNormalizedValue(val, true);

            layoutTopPin.offset = -((mLayout.frame.size.x - frame.size.x) * val);
            mLayout.frame.pos.x = layoutTopPin.offset;
        } else {
            targetScroll = val;
            scrollStart = ticks;
        }

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse);
        }
    }


    override void scrollBy(double offset, bool animated, bool sendEvt, bool fromMouse) {
        if(requiresLayout) {
            layout();
        }

        sourceScroll = scrollbar.getNormalizedValue();
        let val = clamp(sourceScroll + offset, 0.0, 1.0f);

        if(!animated) {
            scrollbar.setNormalizedValue(val, true);

            layoutTopPin.offset = -((mLayout.frame.size.x - frame.size.x) * val);
            mLayout.frame.pos.x = layoutTopPin.offset;
        } else {
            targetScroll = val;
            scrollStart = ticks;
        }

        if(sendEvt) {
            sendEvent(UIHandler.Event_ValueChanged, fromMouse);
        }
    }


    override void scrollTo(UIView view, bool animated, double padding) {
        if(requiresLayout) {
            layout();
        }

        Vector2 screenPosLeft = view.relToScreen((0 - padding, 0));
        Vector2 screenPosRight = view.relToScreen((view.frame.size.x + padding,0));
        
        Vector2 layoutPosLeft = mLayout.screenToRel(screenPosLeft);
        Vector2 layoutPosRight = mLayout.screenToRel(screenPosRight);

        // if pos is already inside the viewing window, don't worry about it
        let relPosLeft = screenToRel(screenPosLeft);
        let relPosRight = screenToRel(screenPosRight);
        if(mLayout.frame.size.x == 0 || (relPosLeft.x >= 0 && relPosRight.x < frame.size.x)) {
            return; // We are inside the scroll view or not valid
        }

        if(mLayout.frame.size.x <= frame.size.x) {
            return; // No scrolling, how did we even get here?
        }

        double scroll = max(min(((relPosRight.x > frame.size.x ? layoutPosRight.x : layoutPosLeft.x) / mLayout.frame.size.x), 1.0), 0.0);

        scrollNormalized(scroll, animated);
    }


    override void scrollByPixels(double offset, bool animated, bool sendEvt, bool fromMouse, int animateTicks) {
        let startScroll = targetScroll != -1 ? targetScroll : scrollbar.getNormalizedValue();
        let normalizedNewVal = startScroll + (offset / (mLayout.frame.size.x - frame.size.x));
        let val = clamp(normalizedNewVal, 0.0, 1.0f);

        if(!animated) {
            scrollbar.setNormalizedValue(val, true);

            layoutTopPin.offset = -((mLayout.frame.size.x - frame.size.x) * val);
            mLayout.frame.pos.x = layoutTopPin.offset;
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


    override bool event(ViewEvent ev) {
        if(ev.type == UIEvent.Type_WheelUp || ev.type == UIEvent.Type_WheelDown) {
            // If this event happened while the mouse is inside the scroll view, scroll!
            if(raycastTest((ev.mouseX, ev.mouseY))) {
                if(!contentsCanScroll()) {
                    return true;
                }

                double curPos = scrollbar.getNormalizedValue();
                double inc = mouseScrollAmount / (mLayout.frame.size.x - frame.size.x);
                if(ev.type == UIEvent.Type_WheelUp) {
                    scrollNormalized(Clamp(curPos - inc, 0.0, 1.0));
                } else {
                    scrollNormalized(Clamp(curPos + inc, 0.0, 1.0));
                }
                return true;
            }
        }

        return UIControl.event(ev);
    }
}