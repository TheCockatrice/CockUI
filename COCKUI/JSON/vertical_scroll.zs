extend class UIVerticalScroll {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates) {
        Super._deserialize(obj, templates);

        getOptionalDouble(obj, "mouseScrollAmount", mouseScrollAmount);
        getOptionalDouble(obj, "scrollBarPadding", scrollBarPadding);
        getOptionalDouble(obj, "barWidth", barWidth);
        getOptionalBool(obj, "autoHideScrollBar", autoHideScrollBar);
        getOptionalBool(obj, "autoHideAdjustsSize", autoHideAdjustsSize);
        getOptionalBool(obj, "hugEnd", hugEnd);

        mLayout = UIVerticalLayout( deserializeOptionalView(obj, "layout", 'UIVerticalLayout', mLayout, templates) );
        scrollBar = UISlider( deserializeOptionalView(obj, "scrollBar", 'UISlider', scrollBar, templates) );

        if(barWidth == 0 && scrollBar) {
            barWidth = scrollBar.frame.size.x;
        }

        if(!mLayout) {
            // Create default layout
            mLayout = new("UIVerticalLayout").init((0,0), (100,100));
            mLayout.pin(UIPin.Pin_Left);
            layoutTopPin = mLayout.pin(UIPin.Pin_Top);
            mLayout.pin(UIPin.Pin_Right, offset: -(scrollbarPadding));
            mLayout.layoutMode = UIViewManager.Content_SizeParent;
            add(mLayout);
        } else {
            if(!mLayout.parent) {
                mLayout.pin(UIPin.Pin_Left);
                mLayout.pin(UIPin.Pin_Right, offset: -(scrollbarPadding));
                mLayout.layoutMode = UIViewManager.Content_SizeParent;
                add(mLayout);
            }

            if(layoutTopPin == null) {
                layoutTopPin = mLayout.firstPin(UIPin.Pin_Top);
                if(!layoutTopPin) layoutTopPin = mLayout.pin(UIPin.Pin_Top);
            }
        }

        if(!scrollBar) {
            // Scrollbar must be specified
            ThrowAbortException("UIVerticalScroll::_deserialize No scrollbar inherited or specified for '%s'", getClassName());
        } else {
            if(!scrollbar.firstPin(UIPin.Pin_Right)) scrollbar.pin(UIPin.Pin_Right);
            if(!scrollbar.firstPin(UIPin.Pin_Top)) scrollbar.pin(UIPin.Pin_Top);
            if(!scrollbar.firstPin(UIPin.Pin_Bottom)) scrollbar.pin(UIPin.Pin_Bottom);
            scrollbar.increment = 0.1;

            if(scrollbar.parent != self)
                add(scrollbar);
        }

        scrollBar.isVertical = true; // Forced vertical

        return self;
    }
}
