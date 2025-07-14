extend class UIImage {
    static const Name AnchorLookup[] = {
        'middle', 'topLeft', 'top', 'topRight',
        'left', 'right', 'bottomLeft', 'bottom', 'bottomRight'
    };

    static const Name ImageStyleLookup[] = {
        'scale', 'center', 'absolute', 'aspectFit', 'aspectScale', 'aspectFill', 'repeat'
    };

    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates) {
        Super._deserialize(obj, templates);

        getOptionalDouble(obj, "imgScaleX", imgScale.x);
        getOptionalDouble(obj, "imgScaleY", imgScale.y);
        getOptionalBool(obj, "flipX", flipX);
        getOptionalBool(obj, "flipY", flipY);
        getOptionalBool(obj, "noFilter", noFilter);

        double boxScale = 1.0;
        if(getOptionalDouble(obj, "imgScale", boxScale)) {
            imgScale = (boxScale, boxScale);
        }

        string imageName;
        if(getOptionalString(obj, "image", imageName)) {
            tex = UITexture.Get(imageName);
        }

        // Support slices
        JsonObject j_slice = JsonObject(obj.get("slice"));
        if(j_slice) {
            slices = NineSlice.deserialize(j_slice, imageName);
            if(slices && slices.texture) {
                tex = slices.texture;
            } else if(slices && !slices.texture) {
                slices.texture = UITexture.Get(imageName);
            }
        }

        // Blend Color
        string bColor;
        if(getOptionalString(obj, "blendColor", bColor)) {
            blendColor = parseColor(bColor);
        }

        // Anchor and style
        string tString;
        if(getOptionalString(obj, "anchor", tString)) {
            Name tn = Name(tString);
            for(int i = 0; i < AnchorLookup.size(); i++) {
                if(tn == AnchorLookup[i]) {
                    imgAnchor = i;
                    break;
                }
            }
        }

        if(getOptionalString(obj, "style", tString)) {
            Name tn = Name(tString);
            for(int i = 0; i < ImageStyleLookup.size(); i++) {
                if(tn == ImageStyleLookup[i]) {
                    imgStyle = i;
                    break;
                }
            }
        }

        return self;
    }
}


extend class NineSlice {
    mixin DeserializeHelper;

    private NineSlice _deserialize(JsonObject obj, string texName = "") { 
        drawCenter = true;
        scaleCenter = true;
        scaleSides = true;
        
        getOptionalDouble(obj, "top", tl.y);
        getOptionalDouble(obj, "left", tl.x);
        getOptionalDouble(obj, "bottom", br.y);
        getOptionalDouble(obj, "right", br.x);
        getOptionalBool(obj, "scaleSides", scaleSides);
        getOptionalBool(obj, "scaleCenter", scaleCenter);
        getOptionalBool(obj, "drawCenter", drawCenter);

        string textureName;
        if(getOptionalString(obj, "texture", textureName)) {
            texture = UITexture.Get(textureName);
        } else {
            texture = UITexture.Get(texName);
        }

        setPixels(tl, br);

        return self;
    }

    static NineSlice deserialize(JsonObject obj, string texName = "") {
        if(!obj) ThrowAbortException("NineSlice: No object provided for deserialization!");

        return new("NineSlice")._deserialize(obj, texName);
    }
}