struct TagInfo {
    uint startPos, endPos;
    string tag;
    string content;
    Map<string, string> attributes;
}

class ScriptCodeView : UIVerticalLayout {
    string code;

    ScriptCodeView init(Vector2 pos = (0,0), Vector2 size = (100, 100), string code = "") {
        Super.init(pos, size);
        
        self.code = code;
        itemSpacing = 0;

        if(code != "") {
            parse();
        }

        return self;
    }


    // Reads margins, creates a container if any margins are necessary
    // returns the container view
    void getMargins(out TagInfo tag, out UIPadding padding, double defaultLeft = 0, double defaultTop = 0, double defaultRight = 0, double defaultBottom = 0) {
        String marginStr = tag.attributes.GetIfExists("margin");
        
        padding.left = defaultLeft;
        padding.top = defaultTop;
        padding.right = defaultRight;
        padding.bottom = defaultBottom;

        if(marginStr != "") {
            Array<String> margins;
            marginStr.split(margins, ",");
            for(int x = 0; x < margins.size(); x++) {
                margins[x].stripLeftRight();
                String margin = margins[x];
                if(margin != "") {
                    if(x == 0) {
                        // Left margin
                        padding.left = margin.toDouble();
                    } else if(x == 1) {
                        // Top margin
                        padding.top = margin.toDouble();
                    } else if(x == 2) {
                        // Right margin
                        padding.right = -margin.toDouble();
                    } else if(x == 3) {
                        // Bottom margin
                        padding.bottom = margin.toDouble();
                    }
                }
            }
        }


        // Get explicit margins
        if(tag.attributes.CheckKey("margin-left")) padding.left = tag.attributes.Get("margin-left").toDouble();
        if(tag.attributes.CheckKey("margin-top")) padding.top = tag.attributes.Get("margin-top").toDouble();
        if(tag.attributes.CheckKey("margin-right")) padding.right = -tag.attributes.Get("margin-right").toDouble();
        if(tag.attributes.CheckKey("margin-bottom")) padding.bottom = tag.attributes.Get("margin-bottom").toDouble();
    }


    void parse() {
        clearManaged();
        if(code == "") return;

        // Parse code and create tag objects, VERY CRUDE
        // Find every chunk until a tag
        TagInfo curTag;
        UIPadding margin;

        string curText;

        for(uint pos = 0, lastPos = 0; pos < code.length();) {
            lastPos = pos;

            if(getNextTag(curTag, pos)) {
                if(lastPos < curTag.startPos) {
                    curText.appendFormat("%s", code.mid(lastPos, curTag.startPos - 1 - lastPos));
                }

                lastPos = pos;

                // Handle the tag
                if(curTag.tag ~== "br") {
                    // Add a line break
                    curText.appendCharacter("\n");
                    curText.appendCharacter("\n");
                } else if(curTag.tag ~== "h1") {
                    addCode(curText);
                    curText = "";

                    // Add a header
                    getMargins(curTag, margin);
                    addCode(curTag.content, fnt: "SEL21FONT", marginLeft: margin.left, marginTop: margin.top, marginRight: margin.right, marginBottom: margin.bottom);
                } else if(curTag.tag ~== "h2") {
                    addCode(curText);
                    curText = "";

                    // Add a sub-header
                    getMargins(curTag, margin);
                    addCode(curTag.content, fnt: "SEL21FONT", fontScale: (0.8, 0.8), marginLeft: margin.left, marginTop: margin.top, marginRight: margin.right, marginBottom: margin.bottom);
                } else if(curTag.tag ~== "h3") {
                    addCode(curText);
                    curText = "";

                    // Add a sub-header
                    getMargins(curTag, margin);
                    addCode(curTag.content, fnt: "SEL16FONT", marginLeft: margin.left, marginTop: margin.top, marginRight: margin.right, marginBottom: margin.bottom);
                } else if(curTag.tag ~== "code") {
                    addCode(curText);
                    curText = "";

                    // Add a code block
                    getMargins(curTag, margin, 20, 0, -80, 0);
                    let lbl = addCode(curTag.content, fnt: "PDA16FONT", vSpacing: 2, fontScale: (0.8, 0.8), marginLeft: margin.left, marginTop: margin.top, marginRight: margin.right, marginBottom: margin.bottom);
                    lbl.textColor = Font.CR_LIGHTBLUE;
                    lbl.monospace = true;
                    lbl.backgroundColor = 0x66000000; // Dark background for code blocks
                } else if(curTag.tag ~== "img") {
                    addCode(curText);
                    curText = "";

                    // Add an image
                    getMargins(curTag, margin, defaultBottom: 20);
                    string src = curTag.attributes.GetIfExists("src");
                    if(src != "") {
                        let img = new("UIImage").init((0,0), (100,100), src);
                        
                        string widthStr = curTag.attributes.GetIfExists("width");
                        string heightStr = curTag.attributes.GetIfExists("height");
                        string alignStr = curTag.attributes.GetIfExists("align");

                        if(widthStr != "") {
                            bool isPercent = widthStr.length() > 1 && widthStr.byteAt(widthStr.length() - 1) == "%";
                            double widthValue = !isPercent ? widthStr.toDouble() : widthStr.mid(0, widthStr.length() - 1).toDouble() / 100.0;
                            img.pinWidth(widthValue, isFactor: isPercent);
                        }
                        else {
                            // Default width if not specified
                            img.pinWidth(UIView.Size_Min);
                        }

                        if(heightStr != "") {
                            bool isPercent = heightStr.length() > 1 && heightStr.byteAt(heightStr.length() - 1) == "%";
                            double heightValue = !isPercent ? heightStr.toDouble() : heightStr.mid(0, heightStr.length() - 1).toDouble() / 100.0;
                            img.pinHeight(heightValue, isFactor: isPercent);
                            
                            if(isPercent) {
                                Console.Printf("\c[yellow]ScriptCodeView: Image height is a percentage (%s), this will not work correctly since in a vertical layout % height has no meaning unless weights are used!");
                            }
                        } else {
                            // Default height if not specified
                            img.pinHeight(UIView.Size_Min);
                            if(img.widthPin.value != UIView.Size_Min) img.imgStyle = UIImage.Image_Aspect_Fill;   // Should result in better auto sizing
                        }

                        

                        if(alignStr == "right") {
                            img.pin(UIPin.Pin_Right, offset: margin.right);
                        } else if(alignStr == "left" || alignStr == "none" || alignStr == "") {
                            img.pin(UIPin.Pin_Left, offset: margin.left);
                        } else if(alignStr == "center" || alignStr == "middle") {
                            img.pin(UIPin.Pin_HCenter, value: 1.0, isFactor: true);
                        }
                        
                        if(margin.top > 0) addSpacer(margin.top);
                        addManaged(img);
                        if(margin.bottom > 0) addSpacer(margin.bottom);
                    } else {
                        Console.Printf("\c[yellow]ScriptCodeView: No 'src' attribute for image tag at position %d", curTag.startPos);
                    }
                }
            } else {
                // Read the rest of the code as text
                if(lastPos < code.length() - 1) {
                    curText.appendFormat("%s", code.mid(lastPos, code.length() - lastPos));
                    addCode(curText);
                }
                
                break;
            }
        }
    }


    virtual UILabel addcode(String txt, Font fnt = "PDA16FONT", int vSpacing = 3, Vector2 fontScale = (1,1), double marginLeft = 0, double marginTop = 0, double marginRight = 0, double marginBottom = 0, double marginBottom = 0) {
        if(txt.length() == 0 && marginTop == 0 && marginBottom == 0) {
            // No text and no margins, nothing to add
            return null;
        }

        let newLabel = new("UILabel").init((0,0), (100,100), txt, fnt, fontScale: fontScale);
        newLabel.multiline = true;
        newLabel.pin(UIPin.Pin_Left, offset: marginLeft);
        newLabel.pin(UIPin.Pin_Right, offset: marginRight);
        newLabel.pinHeight(UIView.Size_Min);
        newLabel.verticalSpacing = vSpacing;

        if(marginTop > 0) {
            addSpacer(marginTop);
        
        }
        addManaged(newLabel);
        
        if(marginBottom > 0) {
            addSpacer(marginBottom);
        }
        
        return newLabel;
    }


    bool getNextTag(out TagInfo tag, out uint pos) {
        int tagPos = pos;
        uint tagEnd = 0;

        while(uint(tagPos) < code.length()) {
            tagPos = code.IndexOf("<", tagPos);

            // Verify that < is not escaped
            if(tagPos > 0 && code.byteAt(tagPos - 1) == 92) {
                tagPos++;
                continue;
            } else if(tagPos < 0) {
                return false;
            }

            tagEnd = code.IndexOf(">", tagPos);
            break;
        }
        
        tag.startPos = tagPos;
        tag.attributes.clear();

        // We have an opening and closing token, scan interior for name and attributes
        if(tagEnd > 0) {
            pos = tagEnd + 1;
            uint ppos = tagPos + 1;
            if(!getString(ppos, tag.tag)) {
                if(developer) Console.Printf("\c[yellow]ScriptCodeView: No tag name found at position %d", tagPos);
                return false; // No tag name found
            }
            
            // Loop through and find attributes
            while(ppos < tagEnd) {
                string attrName, attrValue;
                if(getString(ppos, attrName)) {
                    if(isNextChar(ppos, "=")) {
                        if(getString(ppos, attrValue)) {
                            tag.attributes.insert(attrName, attrValue);
                        } else {
                            if(developer) Console.Printf("\c[yellow]ScriptCodeView: No value for attribute '%s' at position %d", attrName, ppos);
                            break;  // No value for attribute, stop parsing
                        }
                    } else {
                        // If no equals sign, treat as boolean attribute
                        tag.attributes.insert(attrName, "true");
                    }
                } else {
                    break; // No more attributes found
                }
            }

            
            // Find the closing tag, unless the last attribute is /
            if(tag.attributes.CheckKey("/") || tag.tag ~== "img" || tag.tag ~== "br") {
                // Don't find a closing tag!
                
            } else {
                // Find the closing tag
                if(!getClosingTag(tag.tag, pos, tag.content)) {
                    if(developer) Console.Printf("\c[yellow]ScriptCodeView: No closing tag for '%s' at position %d", tag.tag, pos);
                    return false; // No closing tag found
                }
            }

            tag.endPos = pos - 1;

            // TODO: Parse the inner content of the tag, for now tags must not be nested
            if(!(tag.tag ~== "code"))
                tag.content.stripLeftRight();   // Remove whitespace around content
            else {
                // Delete only the first \r\n or \n if it exists, so code blocks don't have a leading newline
                if(tag.content.length() > 0 && tag.content.byteAt(0) == "\r") {
                    tag.content = tag.content.mid(1);
                }

                if(tag.content.length() > 0 && tag.content.byteAt(0) == "\n") {
                    tag.content = tag.content.mid(1);
                }
            }
            return true;
        }

        pos = code.length();

        return false;
    }

    // Skip whitespace and find the next string
    // TODO: Add support for following between quotes, so we can parse attributes like "name=\"value\""
    // TODO: Add support for escaped quotes as well
    bool getString(out uint pos, out string str, bool skipQuotes = true, bool checkTokens = true) {
        uint len = code.length();
        uint start = uint.max;
        uint end = 0;

        // Find the next non-whitespace character to start the next string
        while(pos < len) {
            int ch;
            uint i = pos;
            [ch, i] = code.GetNextCodePoint(i);
            
            if(ch == " " || ch == "\t" || ch == "\n" || ch == "\r" || 
                (skipQuotes && (ch == "\"" || ch == "'")) || 
                (checkTokens && (ch == "<" || ch == ">" || ch == "="))) {
                
                if(start != uint.max) {
                    end = pos;
                    //pos = i;
                    break;
                }

                pos = i;
            } else {
                if(start == uint.max) {
                    start = pos;
                }
                pos = i;
            }
        }

        if(end == 0 && start != uint.max) {
            end = pos;
        }

        if(start < end) {
            str = code.mid(start, end - start);
            return true;
        } else {
            return false;
        }
    }


    bool isNextChar(out uint pos, int chr) {
        uint len = code.length();

        // Find the next non-whitespace character to start the next string
        while(pos < len) {
            int ch;
            uint i = pos;
            [ch, i] = code.GetNextCodePoint(i);
            
            if(ch == " " || ch == "\t" || ch == "\n" || ch == "\r") {
                pos = i;
            } else {
                pos = i;
                return ch == chr;
            }
        }

        return false;
    }


    bool getClosingTag(string tag, out uint pos, out string content) {
        while(pos < code.length()) {
            int tagPos = code.IndexOf("</", pos);
            int tagEnd = tagPos >= 0 ? code.IndexOf(">", tagPos) : -1;

            if(tagPos > 0 && tagEnd > 0) {
                string ttag = code.mid(tagPos + 2, tagEnd - tagPos - 2);
                
                if(ttag ~== tag) {
                    content = code.mid(pos, tagPos - pos);
                    pos = tagEnd + 1;
                    return true;
                } else {
                    pos = tagEnd + 1;
                }
            } else {
                pos = code.length();
                return false;
            }
        }

        return false;
    }
}