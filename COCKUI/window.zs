// TODO: Scaling does not work with drag limits!
class UIWindow : UIControl {
    enum DragArea {
        Left_DragArea   = 0,
        Bottom_DragArea = 1,
        Right_DragArea  = 2
    };

    UIImage backgroundImage;
    UIView contentView;

    bool draggable, movesToTop, sizeable;   // TODO: Implement draggable and sizeable, currently ignored

    int sizerWidth, dragHeight;
    UIBox topDragArea;
    UIBox resizeAreas[3];

    bool limitDragging;
    bool isDragging;
    bool isSizing[3];
    Vector2 mousePos, lastMousePos;
    Vector2 absDrag, absSizer;


    UIWindow init(Vector2 pos, Vector2 size, NineSlice bgSlices = null, 
            bool canSize = true,
            bool canDrag = true,
            bool limitDragging = false,
            int dragHeight = 30, 
            int sizerWidth = 10,
            int paddingTop = 30,
            int paddingLeft = 10,
            int paddingRight = 10,
            int paddingBottom = 10) {

        Super.init(pos, size);
        
        self.dragHeight = dragHeight;
        self.sizerWidth = sizerWidth;
        draggable = canDrag;
        sizeable = canSize;
        self.limitDragging = limitDragging;
        contentView = new("UIView").init((0,0), (100,100));
        contentView.pinToParent(paddingLeft, paddingTop, -paddingRight, -paddingBottom);
        add(contentView);

        if(bgSlices) {
            setBackgroundSlices(bgSlices);
        }

        return self;
    }


    void setBackground(string img, int imgStyle = UIImage.Image_Scale) {
        if(backgroundImage) {
            backgroundImage.setImage(img);
            backgroundImage.imgStyle = imgStyle;
        } else {
            backgroundImage = new("UIImage").init((0,0), (1,1), img, imgStyle: imgStyle);
            backgroundImage.pinToParent();
            add(backgroundImage);
            moveToBack(backgroundImage);
        }
    }

    void setBackgroundSlices(NineSlice slices) {
        if(backgroundImage) {
            backgroundImage.setSlices(slices);
        } else {
            backgroundImage = new("UIImage").init((0,0), (1,1), "", slices);
            backgroundImage.pinToParent();
            add(backgroundImage);
            moveToBack(backgroundImage);
        }
    }

    void buildSizers() {
        topDragArea.size = (frame.size.x, dragHeight);

        resizeAreas[Left_DragArea].pos = (0, topDragArea.size.y);
        resizeAreas[Left_DragArea].size = (sizerWidth, frame.size.y - resizeAreas[Left_DragArea].pos.y);

        resizeAreas[Right_DragArea].pos = (frame.size.x - sizerWidth, topDragArea.size.y);
        resizeAreas[Right_DragArea].size = (sizerWidth, frame.size.y - resizeAreas[Right_DragArea].pos.y);

        resizeAreas[Bottom_DragArea].pos = (0, frame.size.y - sizerWidth);
        resizeAreas[Bottom_DragArea].size = (frame.size.x, sizerWidth);
    }

    // Called whenever this frame is resized
    override void layout(Vector2 parentScale, double parentAlpha) {
        Super.layout(parentScale, parentAlpha);

        // Adjust sizes first..
        // Min Size
        if(minSize.x > 0) frame.size.x = MAX(frame.size.x, minSize.x);
        if(minSize.y > 0) frame.size.y = MAX(frame.size.y, minSize.y);

        // Max Size
        if(maxSize.x > 0) frame.size.x = MIN(frame.size.x, maxSize.x);
        if(maxSize.y > 0) frame.size.y = MIN(frame.size.y, maxSize.y);
        
        // Make sure the element is inside the drag area
        if(limitDragging && parent) {
            if(frame.pos.x < 0) frame.pos.x = 0;
            if(frame.pos.y < 0) frame.pos.y = 0;
            if(frame.pos.x + frame.size.x > parent.frame.size.x) frame.pos.x = parent.frame.size.x - frame.size.x;
            if(frame.pos.y + frame.size.y > parent.frame.size.y) frame.pos.y = parent.frame.size.y - frame.size.y;
        }

        buildSizers();
    }


    override void onMouseDown(Vector2 screenPos) {
        // TODO: Move window to top if specified
        Vector2 localPos = screenToRel(screenPos);
        if(topDragArea.pointInside(localPos)) {
            isDragging = true;
            absDrag = frame.pos;
            for(int x = 0; x < 3; x++) {
                isSizing[x] = false;
            }
        } else if(sizerWidth > 0) {
            absSizer = frame.size;
            for(int x = 0; x < 3; x++) {
                isSizing[x] = resizeAreas[x].pointInside(localPos);
            }
        }

        Super.onMouseDown(screenPos);
    }

    override void onMouseUp(Vector2 screenPos) {
        isDragging = false;
        for(int x = 0; x < 3; x++) {
            isSizing[x] = false;
        }

        // We may have resized and need to rebuild our hotzones
        // TODO: Only rebuild sizers when coming out of a size op
        BuildSizers();
        
        Super.onMouseUp(screenPos);
    }

    virtual void onManualResize() {}
    virtual void onManualMove() {}


    override bool event(ViewEvent ev) {
		// On mouse move while dragging we have to move the window
		if(ev.type == UIEvent.Type_MouseMove) {
			lastMousePos = mousePos;
            mousePos = (ev.mouseX, ev.mouseY);

			if(isDragging) {
                // Drag window by the difference of mousePos
                // TODO: Take scale into consideration during drag
                if(lastMousePos != mousePos) {
                    let diff = mousePos - lastMousePos;
                    if(parent) {
                        diff.x /= parent.cScale.x;
                        diff.y /= parent.cScale.y;
                    }
                    absDrag += diff;
                    frame.pos = absDrag;

                    // Limit to drag area if necessary and possible
                    if(limitDragging && parent) {
                        if(frame.pos.x < 0) { frame.pos.x = 0; }
                        if(frame.pos.y < 0) { frame.pos.y = 0; }

                        if(frame.pos.x + frame.size.x > parent.frame.size.x) { frame.pos.x = parent.frame.size.x - frame.size.x; }
                        if(frame.pos.y + frame.size.y > parent.frame.size.y) { frame.pos.y = parent.frame.size.y - frame.size.y; }
                    }

                    onManualMove();
                }
            } else if(lastMousePos != mousePos) {
                let diff = mousePos - lastMousePos;

                if(parent && !(parent.cScale.x ~== 0 || parent.cScale.y ~== 0)) {
                    diff.x /= parent.cScale.x;
                    diff.y /= parent.cScale.y;
                }
                
                // Check for resizing
                // TODO: Take scale into account!
                for(int x = 0; x < 3; x++) {
                    bool hasSized = false;
                    if(isSizing[x]) {
                        switch(x) {
                            case Right_DragArea:
                                absSizer.x += diff.x;
                                frame.size.x = absSizer.x;
                                if(maxSize.x > 0 && frame.size.x > maxSize.x) frame.size.x = maxSize.x;
                                if(frame.size.x < minSize.x) frame.size.x = minSize.x;

                                // restrict to bounds
                                if(parent && limitDragging && frame.pos.x + frame.size.x > parent.frame.size.x) {
                                    frame.size.x = parent.frame.size.x - frame.pos.x;
                                }
                                break;
                            case Bottom_DragArea:
                                absSizer.y += diff.y;
                                frame.size.y = absSizer.y;
                                if(maxSize.y > 0 && frame.size.y > maxSize.y) frame.size.y = maxSize.y;
                                if(frame.size.y < minSize.y) frame.size.y = minSize.y;

                                // restrict to bounds
                                if(parent && limitDragging && frame.pos.y + frame.size.y > parent.frame.size.y) {
                                    frame.size.y = parent.frame.size.y - frame.pos.y;
                                }
                                break;
                            case Left_DragArea:
                            default:
                                let df = diff.x;
                                absSizer.x -= df;
                                df = frame.size.x - absSizer.x;

                                // Limit diff based on max size
                                if(maxSize.x > 0) {
                                    df = df < 0 ? MAX(frame.size.x - maxSize.x, df) : df;
                                }

                                // Limit based on min size
                                df = df > 0 ? MIN(frame.size.x - minSize.x, df) : df;

                                // Limit based on drag limit
                                if(limitDragging) {
                                    df = df < 0 ? MAX(-frame.pos.x, df) : df;
                                }

                                frame.pos.x += df;
                                frame.size.x -= df;
                                break;
                        }

                        hasSized = true;
                    }

                    if(hasSized) {
                        requiresLayout = true;
                        onManualResize();
                    }
                }
            }
		}

        return Super.event(ev);
	}
}