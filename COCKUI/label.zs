// TODO: Figure out if text drawing uses kerning when drawing in MONOSPACE and account for that
class UILabel : UIView {
    string text;
    BrokenLines lines;
    Font fnt;
    Vector2 fontScale, shadowOffset;
    Color textColor, shadowColor, stencilColor;
    Color blendColor;
    Color textBackgroundColor;
    float desaturation, minScale;

    int charLimit, lineLimit, verticalSpacing;
    bool multiline, noFilter, clipText, pixelAlign, drawShadow, shadowStencil;
    bool monospace, autoScale, charLimitChangesSizes;
    double cacheWidth, cacheAutoScale;
    Alignment textAlign;

    protected int cursorPos;            // Represents BYTE pos, should skip extra unicode bytes where necessary
    protected int cursorX, cursorY;     // Represents BYTE pos in broken lines. Since BL removes whitespace, tracking this separately is necessary
    

    UILabel init(Vector2 pos, Vector2 size, string text, Font fnt, int textColor = Font.CR_UNTRANSLATED, Alignment textAlign = Align_TopLeft, Vector2 fontScale = (1,1)) {
        Super.init(pos, size);

        // Align by default. Sometimes this can cause jerky animation so we can turn it off in those cases
        pixelAlign = true;  

        self.fnt = fnt;
        self.fontScale = fontScale;
        self.textAlign = textAlign;
        verticalSpacing = 1;
        self.text = text;
        self.textColor = textColor;
        self.cursorPos = -1;
        shadowColor = 0x66000000;
        shadowOffset = (2, 2);
        minScale = 0.5;

        charLimit = -1;
        multiline = true;
        raycastTarget = false;
        monospace = false;

        return self;
    }

    override UIView baseInit() {
        Super.baseInit();

        pixelAlign = true;
        fontScale = (1,1);
        textAlign = 0;
        verticalSpacing = 1;
        textColor = 0xFFFFFFFF;
        cursorPos = -1;
        shadowColor = 0x66000000;
        shadowOffset = (2, 2);
        minScale = 0.5;
        charLimit = -1;
        multiline = true;
        raycastTarget = false;
        monospace = false;

        return self;
    }

    override void applyTemplate(UIView template) {
        Super.applyTemplate(template);
        UILabel t = UILabel(template);

        if(t) {
            text = t.text;
            fnt = t.fnt;
            fontScale = t.fontScale;
            textColor = t.textColor;
            textAlign = t.textAlign;
            shadowColor = t.shadowColor;
            shadowOffset = t.shadowOffset;
            minScale = t.minScale;
            charLimit = t.charLimit;
            multiline = t.multiline;
            noFilter = t.noFilter;
            clipText = t.clipText;
            pixelAlign = t.pixelAlign;
            drawShadow = t.drawShadow;
            shadowStencil = t.shadowStencil;
            monospace = t.monospace;
            autoScale = t.autoScale;
            desaturation = t.desaturation;
            textBackgroundColor = t.textBackgroundColor;
            blendColor = t.blendColor;
            stencilColor = t.stencilColor;
            lineLimit = t.lineLimit;
            verticalSpacing = t.verticalSpacing;
        }
    }

    override string getDescription() {
        return String.Format("%s  [ \"%s\" ]", Super.getDescription(), text ? text.mid(0, 50) : "");
    }

    // TODO: Get cursor character from font, but like actually get it. GZDoom wants to use a graphical lump instead.
    protected string getCursor() {
        return fnt.getCursor();
    }

    int getStringWidth(string str) {
        //return monospace ? fnt.GetCharWidth("0") * str.codePointCount() : fnt.StringWidth(str);
        return monospace ? fnt.GetCharWidth("0") * getNumPrintableChars(str) : fnt.StringWidth(str);
    }

    // This is the slowest possible way to do this, but without engine changes I cannot find a way to do it
    // Leave this in for non Selaco based CockUI
    static int getNumPrintableChars(string str) {
        int cp = 0;
        int lastCp = 0;
        for (uint i = 0; i < str.Length();) {
            int chr, next;
            [chr, next] = str.GetNextCodePoint(i);
            i = next;
            
            // Skip color sequences
            if(chr == int("\c") || (lastCp == 92 && chr == int("c"))) {
                for(; i < str.length();) {
                    [chr, i] = str.GetNextCodePoint(i);
                    if(i == next && chr != 91) break; // Skip after one char if this isn't a [COLOR] block
                    if(chr == 93) break;  // End after closing bracket ]
                }
                lastCp = chr;
                continue;
            }

            // Skip unprintables
            if(chr == 13 || chr == 10) {
                lastCp = chr;
                continue;
            }

            cp++;
            lastCp = chr;
        }

        return cp;
    }

    void setShadow(Color col, Vector2 offset = (999, 999)) {
        drawShadow = true;
        shadowColor = col;

        if(!(offset ~== (999,999))) {
            shadowOffset = offset;
        }
    }

    override Vector2 calcMinSize(Vector2 parentSize) {
        Vector2 size = minSize;

        if(fnt && multiline) {
            double width = calcPinnedWidth(parentSize);
            String txt = charLimitChangesSizes ? text.mid(0, charLimit) : text;

            BrokenLines bl = fnt.breakLines(txt, width / fontScale.x);
            for(int x = 0; x < bl.count() && (lineLimit < 1 || x < lineLimit); x++) {
                double w = getStringWidth(bl.stringAt(x)) * fontScale.x;
                if(pixelAlign) w = ceil(w);
                if(w > size.x) {
                    size.x = w;
                }
            }

            size.x = MAX(minSize.x, size.x);
            // If there is no text, still assume at least one line height
            size.y = MAX(calcTextHeight(bl), MAX(minSize.y, ceil(fnt.getHeight() * fontScale.y)));
            
            bl.destroy();
        } else if(fnt) {
            String txt = charLimitChangesSizes ? text.mid(0, charLimit) : text;

            size.x = MAX(minSize.x, ceil(getStringWidth(txt) * fontScale.x));
            size.y = MAX(ceil(fnt.getHeight() * fontScale.y), minSize.y);
        }

        return size;
    }

    void findCursorXY() {
        if(cursorPos < 0) { cursorX = cursorY = -1; }

        if(lines) {
            // Figure out the current row/col of the cursor if it exists
            int cursorRow = -1, cursorCol = -1;
            if(cursorPos >= 0) {
                if(cursorPos == 0 || !lines.count()) {
                    cursorRow = 0;
                    cursorCol = 0;
                } else {
                    uint chCnt = 0;
                    cursorRow = 0;
                    int cPos = cursorPos;
                    for(int x = 0; x < lines.count(); x++) {
                        string str = lines.StringAt(x);
                        chCnt += str.length();

                        if(cursorPos <= int(chCnt) || x == lines.count() - 1) {
                            cursorCol = MAX(0, str.length() - (chCnt - cPos));
                            break;
                        }

                        // Search ahead in the actual string and add to our count any control or whitespace characters 
                        // that would have been trimmed when breaking the lines. 
                        // This is necessary to have an appropriate character count
                        for(uint i = chCnt; i < text.length();) {
                            int ch, next;
                            [ch, next] = text.getNextCodePoint(i);

                            if(ch == 10 || ch == 13 || ch == 32 || ch == 9) chCnt++;
                            else break;

                            i = next;
                        }
                        
                        cursorRow++;
                    }
                }
            }
            cursorX = cursorCol;
            cursorY = cursorRow;
        } else {
            cursorX = cursorPos;
            cursorY = 0;
        }
    }

    override void layout(Vector2 parentScale, double parentAlpha, bool skipSubviews) {
        Super.layout(parentScale, parentAlpha);
        layoutText();
    }

    override void onAdjustedPostLayout(UIView sourceView) {
        layoutText();

        if(heightPin && heightPin.value == UIView.Size_Min) {
            if(multiline) frame.size.y = calcTextHeight(lines) + heightPin.offset;
            else frame.size.y = ceil(fnt.getHeight() * fontScale.y) + heightPin.offset;
        }

        requiresLayout = false;
    }

    virtual void layoutText() {
        // Build brokenlines to cache some info about text layout
        String txt = charLimitChangesSizes ? text.mid(0, charLimit) : text;
        
        if(multiline && fnt) {
            lines = fnt.breakLines(txt, int((frame.size.x / fontScale.x) + 0.01));
            cacheAutoScale = 1.0;   // No auto sizing for multiline text yet
        } else {
            cacheWidth = fnt ? getStringWidth(txt) : 0;
            double dWidth = cacheWidth * fontScale.x;
            cacheAutoScale = autoScale && dWidth > frame.size.x && dWidth > 0 ? max(minScale, frame.size.x / ceil(dWidth + 2)) : 1.0;
            lines = null;
        }

        findCursorXY();
    }


    override void draw() {
        if(hidden || !fnt) { return; }

        Super.draw();

        if(!isOnScreen()) { return; }

        if(clipText) {
            UIBox clipRect;
            getScreenClip(clipRect);
            setClip(int(clipRect.pos.x), int(clipRect.pos.y), int(clipRect.size.x), int(clipRect.size.y));
        }

        Vector2 screenSize = screenSize();
        Vector2 fScale = (cScale.x * fontScale.x * cacheAutoScale, cScale.y * fontScale.y * cacheAutoScale);
        Vector2 vSize = (screenSize.x / fScale.x, screenSize.y / fScale.y);
        int desat = int(255.0 * desaturation);
        int charWidth = fnt.GetCharWidth("0");
        int spaceWidth = fnt.GetCharWidth(" ");

        bool drawCursor = cursorPos >= 0 && (MSTime() / 250) % 2 == 0;

        if(multiline) {
            bool fullColor = !(textColor <= 128 && textColor >= 0);
            double height = calcTextHeight(lines);
            double startY = (textAlign & Align_Bottom) ? frame.size.y - height : ((textAlign & Align_Middle) ? (frame.size.y / 2.0) - (height / 2.0) : 0);
            if(pixelAlign) startY = floor(startY);

            if(!lines || lines.count() == 0) {
                if(drawCursor) {                    
                    double yPos = startY;
                    double xPos = (textAlign & Align_Right) ? frame.size.x : ((textAlign & Align_Center) ? (frame.size.x / 2.0) : 0);

                    Vector2 pos = relToScreen((xPos, yPos));
                    pos = ((pos.x / fScale.x), (pos.y / fScale.y));
                    if(pixelAlign) { 
                        pos.x = floor(pos.x); 
                        pos.y = floor(pos.y);
                    }

                    // Draw the cursor character
                    if(drawCanvas) {
                        drawCanvas.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, getCursor(),
                            DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                            DTA_KeepRatio, true,
                            DTA_Alpha, cAlpha,
                            DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                            DTA_Filtering, !noFilter,
                            DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                            DTA_Desaturate, desat,
                            DTA_ColorOverlay, blendColor,
                            DTA_Monospace, monospace ? MONO_CellCenter : 0,
                            DTA_Spacing, monospace ? charWidth : 0
                        );
                    } else {
                        Screen.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, getCursor(),
                            DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                            DTA_KeepRatio, true,
                            DTA_Alpha, cAlpha,
                            DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                            DTA_Filtering, !noFilter,
                            DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                            DTA_Desaturate, desat,
                            DTA_ColorOverlay, blendColor,
                            DTA_Monospace, monospace ? MONO_CellCenter : 0,
                            DTA_Spacing, monospace ? charWidth : 0
                        );
                    }
                }
            } else {
                int charCounter = charLimit < 0 ? 9999999 : charLimit;
                double lineHeight = fnt.getHeight() * fontScale.y;

                for(int x = 0; x < lines.count() && charCounter > 0 && (lineLimit < 1 || x < lineLimit); x++) {
                    string line = lines.stringAt(x);
                    double yPos = startY + (x * (lineHeight + verticalSpacing));
                    double lineWidth = getStringWidth(lines.stringAt(x));
                    double xPos = (textAlign & Align_Right) ? frame.size.x - (double(lineWidth) * fontScale.x) : ((textAlign & Align_Center) ? (frame.size.x / 2.0) - ((lineWidth * fontScale.x) / 2.0) : 0);
                    Vector2 pos = relToScreen((xPos, yPos));

                    pos = ((pos.x / fScale.x), (pos.y / fScale.y));

                    if(pixelAlign) { 
                        pos.x = floor(pos.x); 
                        pos.y = floor(pos.y);
                    }

                    if(textBackgroundColor != 0) {
                        let pos = relToScreen((xPos, yPos));
                        fill((xPos, yPos), (lineWidth * fontScale.x, lineHeight * fontScale.y), textBackgroundColor);
                    }

                    if(drawShadow) {
                        Vector2 spos = relToScreen((xPos, yPos) + (shadowOffset.x / fontScale.x, shadowOffset.y / fontScale.y));
                        spos = (spos.x / fscale.x, spos.y / fscale.y);

                        if(pixelAlign) {
                            spos.x = floor(spos.x); 
                            spos.y = floor(spos.y);
                        }
                        
                        if(drawCanvas) {
                            drawCanvas.DrawText(fnt, Font.CR_UNTRANSLATED, spos.x, spos.y, line,
                                DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                                DTA_KeepRatio, true,
                                DTA_Alpha, (255.0 / shadowColor.a) * cAlpha,
                                DTA_Color, shadowStencil ? 0xFFFFFFFF : shadowColor,
                                DTA_TextLen, charCounter,
                                DTA_Filtering, !noFilter,
                                DTA_FillColor, shadowStencil ? Color(0, shadowColor.r, shadowColor.g, shadowColor.b) : ~0u,
                                DTA_Desaturate, desat,
                                DTA_ColorOverlay, blendColor,
                                DTA_Monospace, monospace ? MONO_CellCenter : 0,
                                DTA_Spacing, monospace ? charWidth : 0
                            );
                        } else {
                            Screen.DrawText(fnt, Font.CR_UNTRANSLATED, spos.x, spos.y, line,
                                DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                                DTA_KeepRatio, true,
                                DTA_Alpha, (255.0 / shadowColor.a) * cAlpha,
                                DTA_Color, shadowStencil ? 0xFFFFFFFF : shadowColor,
                                DTA_TextLen, charCounter,
                                DTA_Filtering, !noFilter,
                                DTA_FillColor, shadowStencil ? Color(0, shadowColor.r, shadowColor.g, shadowColor.b) : ~0u,
                                DTA_Desaturate, desat,
                                DTA_ColorOverlay, blendColor,
                                DTA_Monospace, monospace ? MONO_CellCenter : 0,
                                DTA_Spacing, monospace ? charWidth : 0
                            );
                        }
                    }

                    if(drawCanvas) {
                        drawCanvas.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, line,
                            DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                            DTA_KeepRatio, true,
                            DTA_Alpha, cAlpha,
                            DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                            DTA_TextLen, charCounter,
                            DTA_Filtering, !noFilter,
                            DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                            DTA_Desaturate, desat,
                            DTA_ColorOverlay, blendColor,
                            DTA_Monospace, monospace ? MONO_CellCenter : 0,
                            DTA_Spacing, monospace ? charWidth : 0
                        );
                    } else {
                        Screen.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, line,
                            DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                            DTA_KeepRatio, true,
                            DTA_Alpha, cAlpha,
                            DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                            DTA_TextLen, charCounter,
                            DTA_Filtering, !noFilter,
                            DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                            DTA_Desaturate, desat,
                            DTA_ColorOverlay, blendColor,
                            DTA_Monospace, monospace ? MONO_CellCenter : 0,
                            DTA_Spacing, monospace ? charWidth : 0
                        );
                    }

                    // Draw the cursor
                    if(drawCursor && x == cursorY) {
                        // Find the position to draw
                        int kern = fnt.GetDefaultKerning();
                        double xp = xPos;
                        string cursorString = getCursor();
                        for(uint i = 0; i <= line.length();) {
                            if(i == cursorX || i >= line.length()) {
                                int cursorOffset = (cursorX >= 0 && uint(cursorX) >= line.length() && cursorY == lines.count() - 1 ? - 3 : int((fnt.StringWidth(cursorString) * 0.5) * fontScale.x));  // Offset cursor if at end of line, or between characters
                                pos = relToScreen((xp - cursorOffset, yPos));    // TODO: Eliminate this unnecessary call with MATH
                                pos = ((pos.x / fScale.x), (pos.y / fScale.y));
                                if(pixelAlign) { 
                                    pos.x = floor(pos.x); 
                                    pos.y = floor(pos.y);
                                }

                                // Draw the cursor character
                                if(drawCanvas) {
                                    drawCanvas.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, cursorString,
                                        DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                                        DTA_KeepRatio, true,
                                        DTA_Alpha, cAlpha,
                                        DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                                        DTA_TextLen, charCounter,
                                        DTA_Filtering, !noFilter,
                                        DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                                        DTA_Desaturate, desat,
                                        DTA_ColorOverlay, blendColor,
                                        DTA_Monospace, monospace ? MONO_CellCenter : 0,
                                        DTA_Spacing, monospace ? charWidth : 0
                                    );
                                } else {
                                    Screen.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, cursorString,
                                        DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                                        DTA_KeepRatio, true,
                                        DTA_Alpha, cAlpha,
                                        DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                                        DTA_TextLen, charCounter,
                                        DTA_Filtering, !noFilter,
                                        DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                                        DTA_Desaturate, desat,
                                        DTA_ColorOverlay, blendColor,
                                        DTA_Monospace, monospace ? MONO_CellCenter : 0,
                                        DTA_Spacing, monospace ? charWidth : 0
                                    );
                                }

                                break;
                            }

                            int ch, next;
                            [ch, next] = line.getNextCodePoint(i);
                            double w = fnt.GetCharWidth(ch) * fontScale.x;
                            xp += w + kern;
                            i = next;
                        }
                    }

                    charCounter -= lines.stringAt(x).length();
                }
            }
        } else if(!multiline) {
            bool fullColor = !(textColor <= 128 && textColor >= 0);
            
            double height = double(fnt.getHeight()) * fontScale.y * cacheAutoScale;
            double width = cacheWidth * fontScale.x * cacheAutoScale;

            double yPos = (textAlign & Align_Bottom) ? frame.size.y - height : ((textAlign & Align_Middle) ? (frame.size.y / 2.0) - (height / 2.0) : 0);
            double xPos = (textAlign & Align_Right) ? frame.size.x - width : ((textAlign & Align_Center) ? (frame.size.x / 2.0) - (width / 2.0) : 0);
            
            if(pixelAlign) yPos = floor(yPos);
            
            Vector2 pos = relToScreen((xPos, yPos));
            pos = (pos.x / fscale.x, pos.y / fscale.y);
            

            if(pixelAlign) {    // TODO: I don't think this belongs here.. I think it belongs before the scaling
                pos.x = floor(pos.x);
                pos.y = floor(pos.y);
            }

            int charCounter = charLimit < 0 ? 9999999 : charLimit;

            if(drawShadow) {
                Vector2 spos = relToScreen((xPos, yPos) + (shadowOffset.x / fontScale.x, shadowOffset.y / fontScale.y));
                spos = (spos.x / fscale.x, spos.y / fscale.y);

                if(pixelAlign) {
                    spos.x = floor(spos.x); 
                    spos.y = floor(spos.y);
                }

                if(drawCanvas) {
                    drawCanvas.DrawText(fnt, Font.CR_UNTRANSLATED, spos.x, spos.y, text,
                        DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                        DTA_KeepRatio, true,
                        DTA_Alpha, (255.0 / shadowColor.a) * cAlpha,
                        DTA_Color, shadowStencil ? 0xFFFFFFFF : shadowColor,
                        DTA_TextLen, charCounter,
                        DTA_Filtering, !noFilter,
                        DTA_FillColor, shadowStencil ? Color(0, shadowColor.r, shadowColor.g, shadowColor.b) : ~0u,
                        DTA_Desaturate, desat,
                        DTA_ColorOverlay, blendColor,
                        DTA_Monospace, monospace ? MONO_CellCenter : 0,
                            DTA_Spacing, monospace ? charWidth : 0
                    );
                } else {
                    Screen.DrawText(fnt, Font.CR_UNTRANSLATED, spos.x, spos.y, text,
                        DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                        DTA_KeepRatio, true,
                        DTA_Alpha, (255.0 / shadowColor.a) * cAlpha,
                        DTA_Color, shadowStencil ? 0xFFFFFFFF : shadowColor,
                        DTA_TextLen, charCounter,
                        DTA_Filtering, !noFilter,
                        DTA_FillColor, shadowStencil ? Color(0, shadowColor.r, shadowColor.g, shadowColor.b) : ~0u,
                        DTA_Desaturate, desat,
                        DTA_ColorOverlay, blendColor,
                        DTA_Monospace, monospace ? MONO_CellCenter : 0,
                            DTA_Spacing, monospace ? charWidth : 0
                    );
                }
            }


            if(drawCanvas) {
                drawCanvas.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, text,
                    DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, cAlpha,
                    DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                    DTA_TextLen, charCounter,
                    DTA_Filtering, !noFilter,
                    DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                    DTA_Desaturate, desat,
                    DTA_ColorOverlay, blendColor,
                    DTA_Monospace, monospace ? MONO_CellCenter : 0,
                    DTA_Spacing, monospace ? charWidth : 0
                );
            } else {
                Screen.DrawText(fnt, fullColor ? Font.CR_WHITE : textColor, pos.x, pos.y, text,
                        DTA_VirtualWidthF, vSize.x, DTA_VirtualHeightF, vSize.y,
                        DTA_KeepRatio, true,
                        DTA_Alpha, cAlpha,
                        DTA_Color, fullColor ? textColor : 0xFFFFFFFF,
                        DTA_TextLen, charCounter,
                        DTA_Filtering, !noFilter,
                        DTA_FillColor, stencilColor ? Color(0, stencilColor.r, stencilColor.g, stencilColor.b) : ~0u,
                        DTA_Desaturate, desat,
                        DTA_ColorOverlay, blendColor,
                        DTA_Monospace, monospace ? MONO_CellCenter : 0,
                        DTA_Spacing, monospace ? charWidth : 0
                );
            }
        }
    }

    // Be careful when setting cursor pos, make sure it does not sit between bytes
    // of a multibyte character. e.g: Use GetNextCodePoint()
    void setCursorPos(int pos) {
        if(cursorPos == pos) return;
        cursorPos = MIN(pos, text.length());
        findCursorXY();
    }

    int getCursorPos() {
        return cursorPos;
    }

    // Assumes we have been layed out
    int cursorPosFromLocal(Vector2 localCoord) {
        if(multiline) {
            if(!lines || lines.count() == 0) return -1;
            int yRow = 0, xCol = 0;
            double startOffset = 0;
            double textHeight = calcTextHeight(lines);
            double lineHeight = textHeight / double(lines.count());

            if(textAlign & UIView.Align_Bottom) startOffset = frame.size.y - textHeight;
            else if(textAlign & UIView.Align_Middle) startOffset = (frame.size.y / 2.0) - (textHeight / 2.0);
            
            // Find y row
            if(localCoord.y < startOffset) yRow = 0;
            else if(localCoord.y > startOffset + textHeight) yRow = lines.count() - 1;
            else yRow = int(floor((localCoord.y - startOffset) / lineHeight));

            string line = lines.stringAt(yRow);

            // Find the x offset of this row based on layout
            double startXOffset = 0;
            double lineWidth = getStringWidth(line) * fontScale.x;
            if(textAlign & UIView.Align_Right) startXOffset = frame.size.x - lineWidth;
            else if(textAlign & UIView.Align_Center) startXOffset = (frame.size.x / 2.0) - (lineWidth / 2.0);

            // Find x pos in the row
            if(localCoord.x <= startXOffset) {
                xCol = 0;
            } else if(localCoord.x >= startXOffset + lineWidth) {
                xCol = line.length();
            } else {
                xCol = line.length();

                // Check each character to see if the X point is inside it
                double xPos = startXOffset;
                for(int x = 0; x < int(line.length());) {
                    int ch;
                    uint next;
                    [ch, next] = line.getNextCodePoint(x);
                    double w = fnt.GetCharWidth(ch);

                    if(localCoord.x < xPos + w) {
                        // If this is the last char of a row other than the last, don't round the position. The cursor always goes before.
                        if(next >= line.length() && yRow < lines.count() - 1) {
                            xCol = x;
                        } else {
                            xCol = int(round(((xPos + w) - localCoord.x) / w)) ? x : next;
                        }
                        break;
                    }

                    // TODO: Do new lines use kerning on the first character? I don't think so but I need to find out - cockatrice
                    xPos += w + fnt.GetDefaultKerning();
                    x = next;
                }
            }
            
            // Convert to index
            uint newPos = 0;
            for(int row = 0; row < yRow; row++) {
                newPos += lines.stringAt(row).length();

                // Add count for whitespace which is removed with BrokenLines
                for(uint i = newPos; i < text.length();) {
                    int ch, next;
                    [ch, next] = text.getNextCodePoint(i);

                    if(ch == 10 || ch == 13 || ch == 32 || ch == 9) newPos++;
                    else break;

                    i = next;
                }
            }
            newPos += xCol;
            return int(newPos);
        } else {
            // Make sure we are inside a threshold of Y from the text
            return -1;
        }
    }

    override void onAddedToParent(UIView parentView) {
        Super.onAddedToParent(parentView);
        
        if(multiline) {
            requiresLayout = true;
        }
    }

    // Set text scale to make characters fit specified height
    void scaleToHeight(double height) {
        double fntHeight = fnt.getHeight();
        fontScale = (height / fntHeight, height / fntHeight);
    }

    double getScaleForHeight(double height) {
        double fntHeight = fnt.getHeight();
        return height / fntHeight;
    }

    protected double calcTextHeight(BrokenLines bl) {
        double height = 0;

        // Assume at least one line by default, don't calculate to zero if there is no text
        int count = bl ? MAX(1, bl.count()) : 1;
        if(lineLimit > 0) {
            return double(MIN(lineLimit, count)) * ((fnt.getHeight() * fontScale.y) + double(verticalSpacing));
        }
        
        return double(count) * ((fnt.getHeight() * fontScale.y) + double(verticalSpacing));
    }

    void setText(string txt) {
        text = txt;
        requiresLayout = true;
    }

    // Animation Helper functions
    UILabelAnimation animateLabel(double length = 0.25,
            Vector2 fromScale    = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            Vector2 toScale      = (UIViewFrameAnimation.invalid, UIViewFrameAnimation.invalid),
            bool layoutSubviewsEveryFrame = false,
            AnimEasing ease = Ease_None,
            bool loop = false ) 
    {

        let animator = getAnimator();

        if(animator) {
            let anim = new("UILabelAnimation").initComponents(self, length,
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


class UILabelAnimation : UIViewAnimation {
    Vector2 scaleStart, scaleEnd;
    UILabel label;

    const invalid = -99999;

    UILabelAnimation init(UILabel label, double length = 0.25, bool layoutSubviewsEveryFrame = false) {
        Super.init(label, length, layoutSubviewsEveryFrame);
        finishOnCancel = true;
        self.label = label;

        return self;
    }

    UILabelAnimation initComponents(UILabel label, 
            double length = 0.25,
            Vector2 fromScale = (invalid, invalid),
            Vector2 toScale = (invalid, invalid),
            bool layoutSubviewsEveryFrame = false,
            AnimEasing ease = Ease_None,
            bool loop = false) {

        Super.init(label, length, layoutSubviewsEveryFrame);
        self.label = label;
        finishOnCancel = true;

        easing = ease;
        scaleStart = fromScale;
        scaleEnd = toScale;
        looping = loop;

        if(toScale.x != invalid && fromScale.x == invalid) {
            scaleStart = label.fontScale;
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

        if(scaleStart.x != invalid && scaleEnd.x != invalid) label.fontScale = UIMath.LerpV(scaleStart, scaleEnd, tm);

        if(view.onAnimationStep() || layoutSubviewsEveryFrame) {
            view.requiresLayout = true;
        }

        Super.step(time);

        return true;
    }

    void setFinalValues() {
        if(scaleStart.x != invalid && scaleEnd.x != invalid) label.fontScale = scaleEnd;
    }

    void setInitialValues() {
        if(scaleStart.x != invalid && scaleEnd.x != invalid) label.fontScale = scaleStart;
    }
}