// Simple view with an image rendered as the background
class UIImage : UIView {
    enum ImageStyle {
        Image_Scale = 0,
        Image_Center,
        Image_Absolute,
        Image_Aspect_Fit,
        Image_Aspect_Scale,     // Fit, but will scale up
        Image_Aspect_Fill,
        Image_Repeat
    };

    enum ImageAnchor {
        ImageAnchor_Middle = 0,
        ImageAnchor_TopLeft,
        ImageAnchor_Top,
        ImageAnchor_TopRight,
        ImageAnchor_Left,
        ImageAnchor_Right,
        ImageAnchor_BottomLeft,
        ImageAnchor_Bottom,
        ImageAnchor_BottomRight
    };

    Color blendColor;
    float desaturation;
    bool pixelAlign;
    UITexture tex;
    NineSlice slices;
    Shape2DTransform shapeTransform;
    Shape2D drawShape;
    ImageStyle imgStyle;
    ImageAnchor imgAnchor;
    Vector2 imgScale;
    double rotation;
    bool noFilter, flipX, flipY, requiresRebuild;
    

    UIImage init(Vector2 pos, Vector2 size, string image, NineSlice slices = null, ImageStyle imgStyle = Image_Scale, Vector2 imgScale = (1,1), ImageAnchor imgAnchor = ImageAnchor_Middle) {
        tex = image == "" && slices ? slices.texture : UITexture.Get(image);
        self.slices = slices;
        self.imgStyle = imgStyle;
        self.imgScale = imgScale;
        self.imgAnchor = imgAnchor;

        Super.init(pos, size);
        raycastTarget = false;

        return self;
    }

    UIImage initTex(Vector2 pos, Vector2 size, TextureID image, NineSlice slices = null, ImageStyle imgStyle = Image_Scale, Vector2 imgScale = (1,1), ImageAnchor imgAnchor = ImageAnchor_Middle) {
        tex = UITexture.GetTex(image);
        self.slices = slices;
        self.imgStyle = imgStyle;
        self.imgScale = imgScale;
        self.imgAnchor = imgAnchor;

        Super.init(pos, size);
        raycastTarget = false;

        return self;
    }

    override UIView baseInit() {
        Super.baseInit();

        raycastTarget = false;
        imgStyle = Image_Scale;
        imgScale = (1,1);
        imgAnchor = ImageAnchor_Middle;

        return self;
    }

    override void applyTemplate(UIView template) {
        Super.applyTemplate(template);
        UIImage t = UIImage(template);

        
        if(t) {
            blendColor = t.blendColor;
            desaturation = t.desaturation;
            pixelAlign = t.pixelAlign;
            tex = t.tex;
            slices = t.slices;
            imgStyle = t.imgStyle;
            imgAnchor = t.imgAnchor;
            imgScale = t.imgScale;
            rotation = t.rotation;
            noFilter = t.noFilter;
            flipX = t.flipX;
            flipY = t.flipY;
            drawShape = null;
            shapeTransform = null;
            requiresRebuild = true;
        }
    }

    override string getDescription() {
        return String.Format("%s  [ TexID: %d  Path: (%s)]", Super.getDescription(), tex ? int(tex.texID) : -1, tex ? tex.path : "None");
    }

    bool isValid() {
        return tex && tex.texID.isValid();
    }

    void setImage(string newImage) {
        tex = UITexture.Get(newImage);
        requiresLayout = true;
    }

    void setSlices(NineSlice newSlice) {
        slices = newSlice;
        requiresLayout = true;
    }

    override bool onAnimationStep() {
        // TODO: Check to make sure that the frame has actually changed since the last animation step
        if(slices || imgStyle == Image_Repeat) {
            buildShape();
        }
        
        return false;
    }

    override Vector2 calcMinSize(Vector2 parentSize) {
        Vector2 size = minSize;

        if(tex && tex.texID.isValid()) {
            if(imgStyle == Image_Aspect_Fit || imgStyle == Image_Aspect_Fill || imgStyle == Image_Aspect_Scale) {
                double aspect = tex.size.y / tex.size.x;
                double w = !widthPin || widthPin.value != UIView.Size_Min ? calcPinnedWidth(parentSize) : 0;
                // TODO: This is super bogus but is functional for Selaco right now
                // TODO: Refactor this at some point to properly calculate aspect based minimum sizes
                if(w) {
                    size.x = w;
                    size.y = size.x * aspect;
                } else {
                    parentSize.x = MIN(maxSize.x, parentSize.x);
                    size.x = MIN(tex.size.x * imgScale.x, parentSize.x);
                    size.y = size.x * aspect;

                    if(size.y > parentSize.y) {
                        double diff = parentSize.y - size.y;
                        size.y -= diff;
                        size.x -= diff / aspect;
                    }

                    if(size.y > maxSize.y) {
                        double diff = maxSize.y - size.y;
                        size.y -= diff;
                        size.x -= diff / aspect;
                    }
                }
            } else if(imgStyle == Image_Scale) {
                size.x = tex.size.x * imgScale.x;
                size.y = tex.size.y * imgScale.y;
            } else {
                size.x = tex.size.x * imgScale.x;
                size.y = tex.size.x * imgScale.x;
            }
        }

        // Make sure we don't exceed max size
        size.x = MIN(size.x, maxSize.x);
        size.y = MIN(size.y, maxSize.y);

        return size;
    }

    override void layout(Vector2 parentScale, double parentAlpha) {
        Super.layout(parentScale, parentAlpha);

        // If necessary clear and create shape
        if(slices || imgStyle == Image_Repeat) {
            buildShape();
        }
    }

    override void onAddedToParent(UIView parentView) {
        Super.onAddedToParent(parentView);
        
        if(slices || imgStyle == Image_Repeat) {
            requiresLayout = true;
        }
    }

    override void onAdjustedPostLayout(UIView sourceView) {
        Super.onAdjustedPostLayout(sourceView);
        requiresRebuild = true;
    }

    void buildShape() {
        if(slices) {
            if(!drawShape) {
                UIMenu m = getMenu();
                drawShape = m ? m.recycler.getShape() : new("Shape2D");
            }

            if(!shapeTransform) {
                shapeTransform = new("Shape2DTransform");
            }

            drawShape.clear();
            UIBox b;
            boundingBoxToScreen(b);
            slices.buildShape(drawShape, (0,0)/*b.pos*/, b.size, cScale);

        } else if(imgStyle == Image_Repeat) {
            if(!drawShape) {
                UIMenu m = getMenu();
                drawShape = m ? m.recycler.getShape() : new("Shape2D");
            }
            
            if(!shapeTransform) {
                shapeTransform = new("Shape2DTransform");
            }

            drawShape.clear();
            UIBox b;
            boundingBoxToScreen(b);

            int vc;
            Vector2 containerSize = b.size;
            containerSize.x /= cScale.x;
            containerSize.y /= cScale.y;
            Vector2 size = (containerSize.x / (tex.size.x * imgScale.x), containerSize.y / (tex.size.y * imgScale.y));
            Shape2DHelper.AddQuad(drawShape, (0,0), b.size, (0,0), size, vc);
        }

        requiresRebuild = false;
    }

    Vector2 makePos(UIBox b, Vector2 size) {
        switch(imgAnchor) {
            case ImageAnchor_TopLeft:
                return b.pos;
            case ImageAnchor_Top:
                return b.pos + ((b.size.x / 2.0) - (size.x / 2.0), 0);
            case ImageAnchor_TopRight:
                return b.pos + (b.size.x - size.x, 0);

            case ImageAnchor_Left:
                return b.pos + (0, (b.size.y / 2.0) - (size.y / 2.0));
            case ImageAnchor_Right:
                return b.pos + (b.size.x - size.x, (b.size.y / 2.0) - (size.y / 2.0));
            case ImageAnchor_BottomLeft:
                return b.pos + (0, b.size.y - size.y);
            case ImageAnchor_Bottom:
                return b.pos + ((b.size.x / 2.0) - (size.x / 2.0), b.size.y - size.y);
            case ImageAnchor_BottomRight:
                return b.pos + (b.size.x - size.x, b.size.y - size.y);
            default:
                return b.pos + (b.size / 2.0) - (size / 2.0);
        }
    }

    // Get image pos/size in screen units
    // b = screen bounding box
    Vector2, Vector2 getImgPos(UIBox b) {
        Vector2 pos, size;

        switch(imgStyle) {
            case Image_Absolute:
                size = (tex.size.x * imgScale.x * cScale.x, tex.size.y * imgScale.y * cScale.y);
                pos = makePos(b, size);//b.pos;
                break;
            case Image_Center:
                size = (tex.size.x * imgScale.x * cScale.x, tex.size.y * imgScale.y * cScale.y);
                pos = b.pos + (b.size / 2.0) - (size / 2.0);
                break;
            case Image_Aspect_Fill:
                {
                    double aspect = tex.size.x / tex.size.y;
                    double target_aspect = b.size.x / b.size.y;

                    size = aspect > target_aspect ? (b.size.y * aspect, b.size.y) : (b.size.x, b.size.x / aspect);
                    size = (size.x * imgScale.x, size.y * imgScale.y);
                    pos = makePos(b, size);
                    //pos = b.pos + (b.size / 2.0) - (size / 2.0);
                }
                break;
            case Image_Aspect_Scale:
                {
                    double aspect = tex.size.x / tex.size.y;

                    size = (tex.size.x * imgScale.x * cScale.x, tex.size.y * imgScale.y * cScale.y);

                    if(b.size.x < size.x) {
                        size *= b.size.x / size.x;
                    }

                    if(b.size.y < size.y) {
                        size *= b.size.y / size.y;
                    }

                    if(aspect >= 1 && size.x < b.size.x) {
                        size *= min(b.size.x / size.x, b.size.y / size.y);
                    } else if(aspect < 1 && size.y < b.size.y) {
                        size *= min(b.size.y / size.y, b.size.x / size.x);
                    }

                    pos = makePos(b, size);
                }
            case Image_Aspect_Scale:
            case Image_Aspect_Fit:
                {
                    double aspect = tex.size.x / tex.size.y;

                    size = (tex.size.x * imgScale.x * cScale.x, tex.size.y * imgScale.y * cScale.y);

                    if(b.size.x < size.x) {
                        size *= b.size.x / size.x;
                    }

                    if(b.size.y < size.y) {
                        size *= b.size.y / size.y;
                    }

                    if(imgStyle == Image_Aspect_Scale) {
                        if(aspect >= 1 && size.x < b.size.x) {
                            size *= min(b.size.x / size.x, b.size.y / size.y);
                        } else if(aspect < 1 && size.y < b.size.y) {
                            size *= min(b.size.y / size.y, b.size.x / size.x);
                        }
                    }

                    pos = makePos(b, size);
                }
                break;
            default:
                size = (b.size.x * imgScale.x, b.size.y * imgScale.y);
                pos = b.pos + ((b.size - size) * 0.5);
                break;
        }

        return pos, size;
    }

    override void draw() {
        if(hidden) { return; }
        
        Super.draw();

        UIBox b;
        boundingBoxToScreen(b);

        if(slices && slices.texture && drawShape) {
            // Draw the draw shape
            if(requiresRebuild) buildShape();
            shapeTransform.Clear();
            shapeTransform.Translate((floor(b.pos.x), floor(b.pos.y)));
            drawShape.SetTransform(shapeTransform);
            Screen.drawShape(
                slices.texture.texID, 
                true,
                drawShape,
                DTA_Alpha, cAlpha,
                DTA_Filtering, !noFilter,
                DTA_ColorOverlay, blendColor,
                DTA_Desaturate, int(255.0 * desaturation)
            );
        } else if(imgStyle == Image_Repeat) {
            if(requiresRebuild) buildShape();
            shapeTransform.Clear();
            shapeTransform.Translate((floor(b.pos.x), floor(b.pos.y)));
            drawShape.SetTransform(shapeTransform);
            Screen.drawShape(
                tex.texID,
                true,
                drawShape,
                DTA_Alpha, cAlpha,
                DTA_Filtering, !noFilter,
                DTA_Desaturate, int(255.0 * desaturation)
            );
        } else if(tex) {
            Vector2 pos, size;
            [pos, size] = getImgPos(b);

            if(rotation != 0) {
                pos += size * 0.5;
            }
            
            if(imgStyle == Image_Aspect_Fill || imgStyle == Image_Absolute || imgStyle == Image_Aspect_Fit || imgStyle == Image_Aspect_Scale) {
                UIBox clipRect;
                getScreenClip(clipRect);
                Screen.setClipRect(int(clipRect.pos.x), int(clipRect.pos.y), int(clipRect.size.x), int(clipRect.size.y));
            }

            if(pixelAlign) {
                pos.x = floor(pos.x);
                pos.y = floor(pos.y);
            }

            // Draw texture
            if(angle == 0) {
                Screen.DrawTexture(
                    tex.texID, 
                    true, 
                    pos.x,
                    pos.y,
                    DTA_DestWidthF, size.x,
                    DTA_DestHeightF, size.y,
                    DTA_Alpha, cAlpha,
                    DTA_ColorOverlay, blendColor,
                    DTA_Filtering, !noFilter,
                    DTA_Desaturate, int(255.0 * desaturation),
                    DTA_Rotate, rotation,
                    DTA_CenterOffset, rotation != 0,
                    DTA_FlipX, flipX,
                    DTA_FlipY, flipY
                );
            } else {
                Vector2 texsize = TexMan.GetScaledSize(tex.texID);
                Vector2 cpos = (rotCenter.x * texSize.x, rotCenter.y * texSize.y);

                Screen.DrawTexture(
                    tex.texID, 
                    true, 
                    pos.x + (rotCenter.x * size.x),
                    pos.y + (rotCenter.x * size.x),
                    DTA_DestWidthF, size.x,
                    DTA_DestHeightF, size.y,
                    DTA_Alpha, cAlpha,
                    DTA_ColorOverlay, blendColor,
                    DTA_Filtering, !noFilter,
                    DTA_Desaturate, int(255.0 * desaturation),
                    DTA_Rotate, rotation,
                    DTA_CenterOffset, rotation != 0,
                    DTA_FlipX, flipX,
                    DTA_FlipY, flipY,
                    DTA_Rotate, angle,
                    DTA_LeftOffsetF, cPos.x,
                    DTA_TopOffsetF, cPos.y
                );
            }
        }
    }


    virtual Vector2 imageRelToLocal(Vector2 pt) {
        // Get the point relative to the image coordinates, taking effective image scale into account
        switch(imgStyle) {
            case Image_Absolute:
                return (pt.x * imgScale.x, pt.y * imgScale.y);
            case Image_Center: {
                let size = (tex.size.x * imgScale.x, tex.size.y * imgScale.y);
                pt += (frame.size / 2.0) - (size / 2.0);
                return (pt.x * imgScale.x, pt.y * imgScale.y);
            }
            case Image_Aspect_Fill: {
                double aspect = tex.size.x / tex.size.y;
                double target_aspect = frame.size.x / frame.size.y;

                let size = aspect > target_aspect ? (frame.size.y * aspect, frame.size.y) : (frame.size.x, frame.size.x / aspect);
                size = (size.x * imgScale.x, size.y * imgScale.y);
                
                pt = ((pt.x / tex.size.x) * size.x, (pt.y / tex.size.y) * size.y);
                pt += (frame.size * 0.5) - (size * 0.5);

                // TODO: Include anchoring
                return pt;
            }
            case Image_Aspect_Scale:
            case Image_Aspect_Fit: {
                double aspect = tex.size.x / tex.size.y;
                let size = (tex.size.x * imgScale.x, tex.size.y * imgScale.y);

                if(frame.size.x < size.x) {
                    size *= frame.size.x / size.x;
                }

                if(frame.size.y < size.y) {
                    size *= frame.size.y / size.y;
                }

                if(imgStyle == Image_Aspect_Scale) {
                    if(aspect >= 1 && size.x < frame.size.x) {
                        size *= min(frame.size.x / size.x, frame.size.y / size.y);
                    } else if(aspect < 1 && size.y < frame.size.y) {
                        size *= min(frame.size.y / size.y, frame.size.x / size.x);
                    }
                }

                let effectiveScale = tex.size.x / size.x;
                switch(imgAnchor) {
                    case ImageAnchor_TopLeft:
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_Top:
                        pt.x += (frame.size.x / 2.0) - (size.x / 2.0);
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_TopRight:
                        pt.x += frame.size.x - size.x;
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_Left:
                        pt.y += (frame.size.y / 2.0) - (size.y / 2.0);
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_Right:
                        pt += (frame.size.x - size.x, (frame.size.y / 2.0) - (size.y / 2.0));
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_BottomLeft:
                        pt.y += frame.size.y - size.y;
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_Bottom:
                        pt += ((frame.size.x / 2.0) - (size.x / 2.0), frame.size.y - size.y);
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_BottomRight:
                        pt += (frame.size.x - size.x, frame.size.y - size.y);
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    default:
                        pt += (frame.size / 2.0) - (size / 2.0);
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                }
            }
            default:
                return pt;
        }
    }

    virtual Vector2 localToImageRel(Vector2 pt) {
        // Get the point relative to the image coordinates, taking effective image scale into account
        switch(imgStyle) {
            case Image_Absolute:
                return (pt.x / imgScale.x, pt.y / imgScale.y);
            case Image_Center: {
                let size = (tex.size.x * imgScale.x, tex.size.y * imgScale.y);
                pt -= (frame.size / 2.0) - (size / 2.0);
                return (pt.x / imgScale.x, pt.y / imgScale.y);
            }
            case Image_Aspect_Fill: {
                double aspect = tex.size.x / tex.size.y;
                double target_aspect = frame.size.x / frame.size.y;

                let size = aspect > target_aspect ? (frame.size.y * aspect, frame.size.y) : (frame.size.x, frame.size.x / aspect);
                size = (size.x * imgScale.x, size.y * imgScale.y);
                pt -= (frame.size / 2.0) - (size / 2.0);
                return (pt.x / imgScale.x, pt.y / imgScale.y);
            }
            case Image_Aspect_Scale:
            case Image_Aspect_Fit: {
                double aspect = tex.size.x / tex.size.y;
                let size = (tex.size.x * imgScale.x, tex.size.y * imgScale.y);

                if(frame.size.x < size.x) {
                    size *= frame.size.x / size.x;
                }

                if(frame.size.y < size.y) {
                    size *= frame.size.y / size.y;
                }

                if(imgStyle == Image_Aspect_Scale) {
                    if(aspect >= 1 && size.x < frame.size.x) {
                        size *= min(frame.size.x / size.x, frame.size.y / size.y);
                    } else if(aspect < 1 && size.y < frame.size.y) {
                        size *= min(frame.size.y / size.y, frame.size.x / size.x);
                    }
                }

                let effectiveScale = tex.size.x / size.x;
                switch(imgAnchor) {
                    case ImageAnchor_TopLeft:
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    case ImageAnchor_Top:
                        pt.x -= (frame.size.x / 2.0) - (size.x / 2.0);
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    case ImageAnchor_TopRight:
                        pt.x -= frame.size.x - size.x;
                        return (pt.x * effectiveScale, pt.y * effectiveScale);
                    case ImageAnchor_Left:
                        pt.y -= (frame.size.y / 2.0) - (size.y / 2.0);
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    case ImageAnchor_Right:
                        pt -= (frame.size.x - size.x, (frame.size.y / 2.0) - (size.y / 2.0));
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    case ImageAnchor_BottomLeft:
                        pt.y -= frame.size.y - size.y;
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    case ImageAnchor_Bottom:
                        pt -= ((frame.size.x / 2.0) - (size.x / 2.0), frame.size.y - size.y);
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    case ImageAnchor_BottomRight:
                        pt -= (frame.size.x - size.x, frame.size.y - size.y);
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                    default:
                        pt += (frame.size / 2.0) - (size / 2.0);
                        return (pt.x / effectiveScale, pt.y / effectiveScale);
                }
            }
            default:
                return pt;
        }
    }

    override void teardown(UIRecycler recycler) {
        Super.teardown(recycler);
        if(drawShape && recycler) {
            recycler.recycleShape(drawShape);
            drawShape = null;
        }
    }

    // Animation Helper functions
    UIImageAnimation animateImage(double length = 0.25,
            Vector2 fromScale    = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            Vector2 toScale      = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            bool layoutSubviewsEveryFrame = false,
            AnimEasing ease = Ease_None,
            bool loop = false ) 
    {

        let animator = getAnimator();

        if(animator) {
            let anim = new("UIImageAnimation").initComponents(self, length,
                fromScale: fromScale,
                toScale: toScale, 
                layoutSubviewsEveryFrame,
                ease,
                loop
            );
            
            animator.add(anim);

            return anim;
        }

        return null;
    }
}


class UIImageAnimation : UIViewAnimation {
    Vector2 scaleStart, scaleEnd;
    UIImage image;

    const invalid = -99999;

    UIImageAnimation init(UIImage image, double length = 0.25, bool layoutSubviewsEveryFrame = false) {
        Super.init(image, length, layoutSubviewsEveryFrame);
        finishOnCancel = true;
        self.image = image;

        return self;
    }

    UIImageAnimation initComponents(UIImage image, 
            double length = 0.25,
            Vector2 fromScale = (invalid, invalid),
            Vector2 toScale = (invalid, invalid),
            bool layoutSubviewsEveryFrame = false,
            AnimEasing ease = Ease_None,
            bool loop = false) {

        Super.init(image, length, layoutSubviewsEveryFrame);
        self.image = image;
        finishOnCancel = true;

        easing = ease;
        scaleStart = fromScale;
        scaleEnd = toScale;
        looping = loop;

        if(toScale.x != invalid && fromScale.x == invalid) {
            scaleStart = image.imgScale;
        }

        return self;
    }

    override void cancel() {
        if(finishOnCancel) {
            setFinalValues();
        }
    }

    override bool step(double time) {
        // Don't animate until we hit our start time
        if(!looping && startTime > time) {
            return true;
        }

        if(looping) {
            double len = endTime - startTime;

            while(time - endTime > 0) {
                endTime += time - endTime;
            }
            startTime = endTime - len;
        } else if(!checkValid(time)) {
            setFinalValues();
            view.layout();
            return false; 
        }

        double te = time - startTime;
        double tm = ease(te / (endTime - startTime));

        if(scaleStart.x != invalid && scaleEnd.x != invalid) image.imgScale = UIMath.LerpV(scaleStart, scaleEnd, tm);

        if(view.onAnimationStep() || layoutSubviewsEveryFrame) {
            view.requiresLayout = true;
        }

        Super.step(time);

        return true;
    }

    void setFinalValues() {
        if(scaleStart.x != invalid && scaleEnd.x != invalid) image.imgScale = scaleEnd;
    }

    void setInitialValues() {
        if(scaleStart.x != invalid && scaleEnd.x != invalid) image.imgScale = scaleStart;
    }
}