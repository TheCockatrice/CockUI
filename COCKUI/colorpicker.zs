class UIColorPicker : UIControl {
    UIView exampleView;
    UIImage colorImage, brImage, arrowImage, pointImage;

    UIColorPicker init(Vector2 pos, Vector2 size, Color startingColor = 0xFFFFFFFF) {
        Super.init(pos, size);

        exampleView = new("UIView").init((0,0), (100, 100));
        exampleView.pin(UIPin.Pin_Left);
        exampleView.pin(UIPin.Pin_Right, offset: -15);
        exampleView.pin(UIPin.Pin_Top);
        exampleView.pinHeight(40);
        exampleView.backgroundColor = startingColor;
        add(exampleView);

        colorImage = new("UIImage").init((0,0), (100, 100), "COLPICKR");
        colorImage.pin(UIPin.Pin_Left);
        colorImage.pin(UIPin.Pin_Right, offset: -40);
        colorImage.pin(UIPin.Pin_Top, offset: 45);
        colorImage.pin(UIPin.Pin_Bottom);
        add(colorImage);

        brImage = new("UIImage").init((0,0), (100, 100), "COLPICKB");
        brImage.pinWidth(15);
        brImage.pin(UIPin.Pin_Right, offset: -15);
        brImage.pin(UIPin.Pin_Top, offset: 45);
        brImage.pin(UIPin.Pin_Bottom);
        add(brImage);

        arrowImage = new("UIImage").init((0,0), (100, 100), "COLPICKA");
        arrowImage.pinWidth(10);
        arrowImage.pinHeight(10);
        arrowImage.pin(UIPin.Pin_Right);
        arrowImage.pin(UIPin.Pin_Top, offset: 45);
        add(arrowImage);

        pointImage = new("UIImage").init((0,45), (10, 10), "COLPICKC");
        pointImage.pinWidth(11);
        pointImage.pinHeight(11);
        add(pointImage);

        return self;
    }
}