extend class UISlider {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        getOptionalDouble(obj, "value", value);
        prevValue = value;

        getOptionalDouble(obj, "increment", increment);
        getOptionalDouble(obj, "pageIncrement", pageIncrement);
        getOptionalDouble(obj, "minVal", minVal);
        getOptionalDouble(obj, "maxVal", maxVal);
        getOptionalDouble(obj, "buttonSize", buttonSize);
        getOptionalDouble(obj, "buttonScrollSize", buttonScrollSize);
        getOptionalDouble(obj, "minButtonScrollSize", minButtonScrollSize);

        getOptionalBool(obj, "isVertical", isVertical);
        getOptionalBool(obj, "scaleButton", scaleButton);
        getOptionalBool(obj, "forceIncrement", forceIncrement);

        JsonObject bgSlicesObj = JsonObject(obj.get("bgSlice"));
        if(bgSlicesObj) {
            makeBackgroundImage(NineSlice.deserialize(bgSlicesObj));
        }

        JsonObject slideSlicesObj = JsonObject(obj.get("slideSlice"));
        if(slideSlicesObj) {
            makeSlideImage(NineSlice.deserialize(slideSlicesObj));
        }

        slideButt = UISliderButton( deserializeOptionalView(obj, "button", 'UISliderButton', slideButt, templates) );
        if(slideButt.parent == null) add(slideButt);

        if(!slideButt) {
            // Slide button must be specified
            ThrowAbortException("UISlider::_deserialize No 'slideButt' inherited or specified for '%s'", getClassName());
        }

        if(buttonScrollSize == 0) {
            buttonScrollSize = slideButt.frame.size.x;
        }


        return self;
    }
}
