enum AnimEasing {
    Ease_None = 0,
    Ease_In,
    Ease_Out,
    Ease_In_Out,
    Ease_Out_Back,
    Ease_Out_Back_More,
    Ease_Out_Elastic
}

// Instead of putting the animator code in the menu it lives here, because
// in the future we might want to add animations to an eventhandler or a non-UIMenu object
class UIViewAnimator ui {
    Array<UIViewAnimation> animations;

    bool step() {
        double t = getTime();
        bool animated = animations.size() > 0;
        // Step all animations, remove if they return false (indication completion)
        // Animations are responsible for setting the full finished values on completion
        for(int x = 0; x < animations.size(); x++) {
            if(!animations[x].step(t)) {
                if(animations[x].selfDestruct && animations[x].view) {
                    animations[x].view.removeFromSuperview();
                }
                animations.delete(x);
                x--;
            }
        }
        return animated;
    }

    // Cancel all animations
    void clear(UIView forView = null, bool cancelEach = true) {
        for(int x = 0; x < animations.size(); x++) {
            if(forView == null || animations[x].view == forView) {
                if(cancelEach) animations[x].cancel();

                if(forView != null) {
                    if(animations[x].selfDestruct && animations[x].view) {
                        animations[x].view.removeFromSuperview();
                    }
                    animations.delete(x);
                    x--;
                }
            }
        }

        if(forView == null) animations.clear();
    }

    // Cancel animations that are a descendant of the parent
    void clearChildren(UIView forParent, bool cancelEach = true) {
        for(int x = 0; x < animations.size(); x++) {
            if(animations[x].view.hasParent(forParent)) {
                if(cancelEach) animations[x].cancel();

                if(animations[x].selfDestruct && animations[x].view) {
                    animations[x].view.removeFromSuperview();
                }
                
                animations.delete(x);
                x--;
            }
        }
    }

    // Finish animation by time or cancel if not started yet
    void finish(UIView forView, double time = -1, bool cancelUnstarted = true) {
        let now = getTime();
        if(time == -1) time = now;

        for(int y = animations.size() - 1; y >= 0; y--) {
            if(animations[y].view == forView) {
                if(cancelUnstarted && animations[y].startTime >= now) {
                    animations[y].finishOnCancel = false;
                    animations[y].cancel();
                } else {
                    animations[y].endTime = MIN(time, animations[y].endTime);

                    if(time >= now) {
                        animations[y].finishOnCancel = true;
                        animations[y].cancel();

                        if(animations[y].selfDestruct && animations[y].view) {
                            animations[y].view.removeFromSuperview();
                        }

                        animations.delete(y);
                        continue;
                    }
                }
            }
        }
    }

    bool isAnimating(UIView forView = null) {
        if(forView == null) { return animations.size() > 0; }
        for(int x = 0; x < animations.size(); x++) { if(animations[x].view == forView) return true; }
        return false;
    }

    static double getTime() {
        return MSTimeF() / 1000.0;
    }

    void add(UIViewAnimation anim) {
        animations.push(anim);
    }
}


class UIViewAnimation ui {
    UIView view;
    double startTime, endTime, lastFrameTime;
    bool layoutSubviewsEveryFrame, layoutEveryFrame;
    bool looping, cancelled;
    bool finishOnCancel;             // Should we skip to the end frame when this animation is cancelled?
    bool hasPlayedStartSound, hasPlayedEndSound;
    bool selfDestruct;
    AnimEasing easing;
    string startSound, endSound;

    UIViewAnimation init(UIView view, double length = 0.25, bool layoutSubviewsEveryFrame = false) {
        self.view = view;
        startTime = getTime();
        endTime = startTime + length;
        self.layoutSubviewsEveryFrame = layoutSubviewsEveryFrame;

        return self;
    }

    virtual bool step(double time) {
        lastFrameTime = time;
        return false;   // Base animation should never be added so always return false
    }

    virtual bool checkValid(double time) {
        if(cancelled) return false;
        return !looping && time - endTime < 0;
    }

    virtual void cancel() { 
        cancelled = true;
    }

    double getTime() {
        return MSTimeF() / 1000.0;
    }

    double ease(double tm) {
        switch(easing) {
            case Ease_Out:
                return UIMath.EaseOutCubicf(tm);
            case Ease_In:
                return UIMath.EaseInCubicF(tm);
            case Ease_In_Out:
                return UIMath.EaseInOutCubicF(tm);
            case Ease_Out_Back:
                return UIMath.EaseOutBackF(tm);
            case Ease_Out_Back_More:
                return UIMath.EaseOutBackMoreF(tm);
            case Ease_Out_Elastic:
                return UIMath.easeOutElastic(tm);
            default:
                return tm;
        }
    }
}


class UIViewFrameAnimation : UIViewAnimation {
    enum AnimViewComponents {
        C_Pos         = 1,
        C_Size        = 1 << 1,
        C_Alpha       = 1 << 2,
        C_Scale       = 1 << 3,
        C_Angle       = 1 << 4
    }

    int components;
    UIBox frameStart, frameEnd;
    double alphaStart, alphaEnd, angleStart, angleEnd;
    Vector2 scaleStart, scaleEnd;

    const invalid = -99999;

    UIViewFrameAnimation init(UIView view, double length = 0.25, bool layoutSubviewsEveryFrame = false) {
        Super.init(view, length, layoutSubviewsEveryFrame);
        finishOnCancel = true;
        return self;
    }

    UIViewFrameAnimation initComponents(UIView view, 
            double length = 0.25,
            Vector2 fromPos = (invalid, invalid), 
            Vector2 toPos = (invalid, invalid),
            Vector2 fromSize = (invalid, invalid),
            Vector2 toSize = (invalid, invalid),
            Vector2 fromScale = (invalid, invalid),
            Vector2 toScale = (invalid, invalid),
            double fromAlpha = invalid, double toAlpha = invalid,
            bool layoutSubviewsEveryFrame = false,
            AnimEasing ease = Ease_None,
            bool loop = false,
            double fromAngle = invalid, double toAngle = invalid) {

        Super.init(view, length, layoutSubviewsEveryFrame);
        finishOnCancel = true;

        easing = ease;
        frameStart.pos = fromPos;
        frameEnd.pos = toPos;
        frameStart.size = fromSize;
        frameEnd.size = toSize;
        alphaStart = fromAlpha;
        alphaEnd = toAlpha;
        scaleStart = fromScale;
        scaleEnd = toScale;
        angleStart = fromAngle;
        angleEnd = toAngle;

        looping = loop;

        if(!(fromPos.x ~== invalid)) {
            components |= C_Pos;
        } else if(!(toPos.x ~== invalid)) {
            // We only set end pos, so take the current pos as the start pos
            components |= C_Pos;
            frameStart.pos = view.frame.pos;
        }

        if(!(fromSize.x ~== invalid)) {
            components |= C_Size;
        } else if(!(toSize.x ~== invalid)) {
            // We only set end size, so take the current size as the start size
            components |= C_Size;
            frameStart.size = view.frame.size;
        }

        if(!(fromAlpha ~== invalid)) {
            components |= C_Alpha;
        } else if(!(toAlpha ~== invalid)) {
            components |= C_Alpha;
            alphaStart = view.alpha;
        }

        if(!(fromScale.x ~== invalid)) {
            components |= C_Scale;
        } else if(!(toScale.x ~== invalid)) {
            // We only set end pos, so take the current pos as the start pos
            components |= C_Scale;
            scaleStart = view.scale;
        }

        if(!(fromAngle ~== invalid)) {
            components |= C_Angle;
        } else if(!(toAngle ~== invalid)) {
            components |= C_Angle;
            angleStart = view.angle;
        }

        return self;
    }

    override void cancel() {
        Super.cancel();

        if(finishOnCancel) {
            setFinalValues();
        }
    }

    void startCapture() {
        frameStart.pos = view.frame.pos;
        frameStart.size = view.frame.size;
        alphaStart = view.alpha;
        scaleStart = view.scale;
    }

    void endCapture() {
        frameEnd.pos = view.frame.pos;
        frameEnd.size = view.frame.size;
        alphaEnd = view.alpha;
        scaleEnd = view.scale;

        if(frameEnd.pos != frameStart.pos) components |= C_Pos;
        if(frameEnd.size != frameStart.size) components |= C_Size;
        if(alphaEnd != alphaStart) components |= C_Alpha;
        if(scaleEnd != scaleStart) components |= C_Scale;
        if(angleEnd != angleStart) components |= C_Angle;
    }


    override bool step(double time) {
        if(looping) {
            double len = endTime - startTime;

            while(time - endTime > 0) {
                endTime += time - endTime;
            }
            startTime = endTime - len;
        } else if(!checkValid(time)) {
            setFinalValues();

            if(!hasPlayedEndSound && endSound != "") {
                hasPlayedEndSound = true;
                Menu.MenuSound(endSound);
            }

            return false; 
        }

        double te = time - startTime;
        double tm = clamp(ease(te / (endTime - startTime)), 0.0, 1.0);

        if(te < 0) return true;
        
        if(!hasPlayedStartSound && startSound != "") {
            hasPlayedStartSound = true;
            Menu.MenuSound(startSound);
        }

        if(components & C_Pos) view.frame.pos = UIMath.LerpV(frameStart.pos, frameEnd.pos, tm);
        if(components & C_Size) view.frame.size = UIMath.LerpV(frameStart.size, frameEnd.size, tm);
        if(components & C_Alpha) view.setAlpha(UIMath.Lerpd(alphaStart, alphaEnd, tm));
        if(components & C_Scale) view.setScale(UIMath.LerpV(scaleStart, scaleEnd, tm));
        if(components & C_Angle) view.angle = UIMath.Lerpd(Actor.Normalize180(angleStart), Actor.Normalize180(angleEnd), tm);

        if(view.onAnimationStep() || layoutSubviewsEveryFrame) {
            // Set requiresLayout on every subview
            for(int x = 0; x < view.numSubviews(); x++) {
                view.viewAt(x).requiresLayout = true;
            }
        }
        
        if(layoutEveryFrame) {
            view.requiresLayout = true;
        }
        
        Super.step(time);
        return true;
    }

    void setFinalValues() {
        if(components & C_Pos) view.frame.pos = frameEnd.pos;
        if(components & C_Size) view.frame.size = frameEnd.size;
        if(components & C_Scale) view.setScale(scaleEnd);
        if(components & C_Alpha) view.setAlpha(alphaEnd);
        if(components & C_Angle) view.angle = angleEnd;

        if(view.onAnimationStep()) {
            view.layoutSubviews();
        }
    }
}


class UIViewPinAnimationValues {
    int anchor;
    double startValue, endValue, startOffset, endOffset;
    UIPin pin;

    const invalid = -99999;

    void apply(double tm) {
        if(!pin) return;

        if(tm == 0) {
            pin.value = startValue != invalid ? startValue : pin.value;
            pin.offset = startOffset != invalid ? startOffset : pin.offset;
        } else if(tm == 1) {
            pin.value = startValue != invalid ? endValue : pin.value;
            pin.offset = startOffset != invalid ? endOffset : pin.offset;
        } else {
            pin.value = startValue != invalid ? UIMath.Lerpd(startValue, endValue, tm) : pin.value;
            pin.offset = startOffset != invalid ? UIMath.Lerpd(startOffset, endOffset, tm) : pin.offset;
        }
    }
}


// Use this animation type to animate a view by its pins
// You can animate any value for any pin, but the view has to actually 
// have a pin of that type. Values for pins that do not exist
// in the view will be ignored completely
class UIViewPinAnimation : UIViewAnimation {
    enum LayoutMethod {
        LAYOUT_EVERY_FRAME  = 0,    // Call a view layout every frame, the default
        LAYOUT_FROM_DEST    = 1,    // Layout subviews from the desination values, at the start. This is to save layout time on complicated view hierarchies but still allow you to animate them
        LAYOUT_FROM_START   = 2     // Same as above, but lays out from the starting values instead of the finish values
    }

    Array<UIViewPinAnimationValues> values;

    double alphaStart, alphaEnd;
    Vector2 scaleStart, scaleEnd;
    LayoutMethod layoutType;

    const invalid = -99999;

    UIViewPinAnimation init(UIView view, double length = 0.25, LayoutMethod layoutType = LAYOUT_EVERY_FRAME) {
        Super.init(view, length, layoutSubviewsEveryFrame);
        self.layoutType = layoutType;
        finishOnCancel = true;
        return self;
    }

    UIViewPinAnimation initComponents(UIView view, 
            double length = 0.25,
            Vector2 fromScale = (invalid, invalid),
            Vector2 toScale = (invalid, invalid),
            double fromAlpha = invalid, double toAlpha = invalid,
            AnimEasing ease = Ease_None,
            LayoutMethod layoutType = LAYOUT_EVERY_FRAME,
            bool loop = false) {

        Super.init(view, length, layoutSubviewsEveryFrame);
        finishOnCancel = true;

        easing = ease;
        alphaStart = fromAlpha;
        alphaEnd = toAlpha;
        scaleStart = fromScale;
        scaleEnd = toScale;

        looping = loop;

        if(fromAlpha == invalid && toAlpha != invalid) {
            alphaStart = view.alpha;
        }

        if(toScale.x != invalid && fromScale.x == invalid) {
            scaleStart = view.scale;
        }

        return self;
    }


    void addValues(int anchor, double startVal = invalid, double endVal = 1.0, double startOffset = invalid, double endOffset = invalid) {
        let v = new('UIViewPinAnimationValues');
        v.pin = view.firstPin(anchor);
        v.anchor = anchor;

        if(v.pin) {
            v.startvalue = startVal == invalid ? v.pin.value : startVal;
            v.endValue = endVal;
            v.startOffset = startOffset == invalid && endOffset != invalid ? v.pin.offset : startOffset;
            v.endOffset = endOffset;
        } else {
            v.startvalue = startVal == invalid ? 1.0 : startVal;
            v.endValue = endVal;
            v.startOffset = startOffset;
            v.endOffset = endOffset;
        }
        
        values.push(v);
    }

    // Call this after adding all desired anchors to set up the first frame of the animation
    void prepare() {
        if(layoutType == LAYOUT_FROM_DEST) {
            // Layout the subviews with the final values, then the master view will be layed out
            setFinalValues();
            view.layout();
            setInitialValues();
            view.layout(skipSubviews: true);    // Layout only the main view, subviews should be skipped now
        } else {
            setInitialValues();
            view.requiresLayout = true;     // Don't layout now, we can do this before the next frame
        }
    }

    override void cancel() {
        Super.cancel();

        if(finishOnCancel) {
            setFinalValues();
            view.layout();
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

        if(alphaStart != invalid && alphaEnd != invalid) view.setAlpha(UIMath.Lerpd(alphaStart, alphaEnd, tm));
        if(scaleStart.x != invalid && scaleEnd.x != invalid) view.setScale(UIMath.LerpV(scaleStart, scaleEnd, tm));
        
        // Set all pin values
        for(int x = 0; x < values.size(); x++) {
            values[x].apply(tm);
        }

        if(view.onAnimationStep() || layoutType == LAYOUT_EVERY_FRAME) {
            view.requiresLayout = true;
            //view.layout();
        }

        Super.step(time);
        return true;
    }

    void setFinalValues() {
        if(scaleStart.x != invalid && scaleEnd.x != invalid) view.setScale(scaleEnd);
        if(alphaStart != invalid && alphaEnd != invalid) view.setAlpha(alphaEnd);

        // Set all pin values
        for(int x = 0; x < values.size(); x++) {
            values[x].apply(1);
        }
    }

    void setInitialValues() {
        if(scaleStart.x != invalid && scaleEnd.x != invalid) view.setScale(scaleStart);
        if(alphaStart != invalid && alphaEnd != invalid) view.setAlpha(alphaStart);

        // Set all pin values
        for(int x = 0; x < values.size(); x++) {
            values[x].apply(0);
        }
    }
}


class UIViewShakeAnimation : UIViewAnimation {
    Array<UIViewPinAnimationValues> values;
    const invalid = -99999;

    Vector2 initialPos;
    double intensity, intensityStart, speed, speedStart;
    double seed;

    UIViewShakeAnimation init(UIView view, double length = 0.25, double intensity = 50, double speed = 10) {
        Super.init(view, length, layoutSubviewsEveryFrame);
        initialPos = view.frame.pos;
        finishOnCancel = true;
        self.intensity = intensity;
        self.speed = speed;
        speedStart = speed;
        intensityStart = intensity;
        easing = Ease_Out;
        seed = frandom(0, 360);

        return self;
    }

    override void cancel() {
        Super.cancel();

        if(finishOnCancel) {
            setFinalValues();
            view.layout();
        }
    }

    override bool step(double time) {
        // Don't animate until we hit our start time
        if(!looping && startTime > time) {
            return true;
        }

        if(!looping && !checkValid(time)) {
            setFinalValues();
            view.layout();
            return false; 
        }

        double te = time - startTime;
        double tm = ease(te / (endTime - startTime));
        double item = 1.0 - tm;
        
        
        speed = speedStart * item;
        intensity = intensityStart * item;

        view.frame.pos.x = initialPos.x + (intensity * sin((item * speed * 9000) + seed));
        view.frame.pos.y = initialPos.y + (intensity * sin((item * speed * 8500) + (seed * 0.5)));

        if(view.onAnimationStep() || layoutEveryFrame) {
            view.requiresLayout = true;
        }

        Super.step(time);
        return true;
    }

    void setFinalValues() {
        view.frame.pos = initialPos;
    }

    void setInitialValues() {
        
    }
}