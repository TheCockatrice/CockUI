class UIAnimatedLabel : UILabel {
    int absCharLimit;
    double animCharLimit, startingChars;
    double animStart, animSpeed;

    UIAnimatedLabel init(Vector2 pos, Vector2 size, string text, Font fnt, int textColor = Font.CR_WHITE, Alignment textAlign = Align_TopLeft, Vector2 fontScale = (1,1)) {
        Super.init(pos, size, text, fnt, textColor, textAlign, fontScale);
        absCharLimit = -1;
        animStart = -1;

        return self;
    }

    void start(double animSpeed = 25.0, int startingCharacters = 0, double timeOffset = 0) {
        animStart = getTime() - timeOffset;
        self.animSpeed = animSpeed;
        startingChars = startingCharacters;
        animCharLimit = 0;
    }

    override UIView baseInit() {
        Super.baseInit();

        absCharLimit = -1;
        animStart = -1;

        return self;
    }

    void end() {
        charLimit = -1;
        animStart = -1;
    }

    override void draw() {
        if(animStart >= 0) {
            double te = getTime() - animStart;
            animCharLimit = startingChars + (animSpeed * te);
            charLimit = max(0, int(floor(animCharLimit)));
        }
        
        Super.Draw();
    }
}