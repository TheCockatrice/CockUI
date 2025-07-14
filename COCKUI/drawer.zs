enum DrawFlags {
    DR_SCREEN_RIGHT         = 1 << 1,
    DR_SCREEN_HCENTER       = 1 << 2,
    DR_SCREEN_BOTTOM        = 1 << 3,
    DR_SCREEN_VCENTER       = 1 << 4,

    DR_IGNORE_INSETS        = 1 << 5,

    DR_TEXT_RIGHT           = 1 << 8,
    DR_TEXT_BOTTOM          = 1 << 9,
    DR_TEXT_VCENTER         = 1 << 10,
    DR_TEXT_HCENTER         = 1 << 11,

    DR_NO_SPRITE_OFFSET     = 1 << 12,
    DR_SCALE_IS_SIZE        = 1 << 13,
    DR_IMG_ASPECT_FIT       = 1 << 14,

    // Can't remember why I did this, but there was a reason...
    DR_IMG_VCENTER          = DR_TEXT_VCENTER,
    DR_IMG_HCENTER          = DR_TEXT_HCENTER,
    DR_IMG_RIGHT            = DR_TEXT_RIGHT,
    DR_IMG_BOTTOM           = DR_TEXT_BOTTOM,
    DR_IMG_CENTER           = DR_IMG_HCENTER | DR_IMG_VCENTER,
    DR_SCREEN_CENTER        = DR_SCREEN_HCENTER | DR_SCREEN_VCENTER,
    DR_TEXT_CENTER          = DR_TEXT_HCENTER | DR_TEXT_VCENTER,

    DR_TEXT_VCENTER_FIRSTLINE   = 1 << 15,
    DR_ROUND_COORDS             = 1 << 16,
    DR_FLIP_X                   = 1 << 17,
    DR_FLIP_Y                   = 1 << 18,
    DR_TEXT_BACKGROUND          = 1 << 19,
    DR_STENCIL                  = 1 << 20,
    
    DR_ADDITIVE                 = 1 << 25,

    DR_WAIT_READY               = 1 << 30       // For images, only draw if texture is ready. Requires some overhead.
}

const TICKRATE = double(35.0);
const ITICKRATE = double(1.0/35.0);


mixin class CVARBuddy {
    clearscope double fGetCVar(Name cv, double defValue = 0) {
        let cva = CVar.FindCVar(cv);

        return cva ? cva.GetFloat() : defValue;
    }
    
    
    clearscope int iGetCVar(Name cv, int defValue = 0) {
        let cva = CVar.FindCVar(cv);

        return cva ? cva.GetInt() : defValue;
    }

    clearscope void iSetCVar(Name cv, int val) {
        let cva = CVar.FindCVar(cv);

        if(cva) cva.setInt(val);
    }

    clearscope void fSetCVar(Name cv, double val) {
        let cva = CVar.FindCVar(cv);

        if(cva) cva.setFloat(val);
    }
}


mixin class SCVARBuddy {
    static double fGetCVar(Name cv, double defValue = 0) {
        let cva = CVar.FindCVar(cv);

        return cva ? cva.GetFloat() : defValue;
    }
    
    
    static int iGetCVar(Name cv, int defValue = 0) {
        let cva = CVar.FindCVar(cv);

        return cva ? cva.GetInt() : defValue;
    }

    static void iSetCVar(Name cv, int val) {
        let cva = CVar.FindCVar(cv);

        if(cva) cva.setInt(val);
    }

    static void fSetCVar(Name cv, double val) {
        let cva = CVar.FindCVar(cv);

        if(cva) cva.setFloat(val);
    }
}


mixin class HUDScaleReader {
    transient CVar hudScaleCVAR;

    float getHUDScale() {
        if(!hudScaleCVAR) hudScaleCVAR = CVar.FindCVar("hud_scaling");
        float hudScale = hudScaleCVAR.GetFloat();
        if(hudScale < 0) hudScale = HUD_SCALING_DEFAULT;

        return hudScale;
    }    
}


mixin class ScreenSizeChecker {
    ui transient Vector2 lastScreenSize;

    ui bool screenSizeChanged() {
        let ss = (Screen.GetWidth(), Screen.GetHeight());
        if(ss != lastScreenSize) {
            lastScreenSize = ss;
            return true;
        }

        return false;
    }
}

mixin class UIDrawer {
    transient ui Vector2 screenSize, virtualScreenSize, screenInsets;
    transient ui bool isTightScreen, isUltrawide;

    ui bool calcTightScreen(int defaultWidth = 1920, int defaultHeight = 1080, double xRatio = 0.8854, double yRatio = 0.8333) {
        isTightScreen = (virtualScreenSize.x < ceil(defaultWidth * xRatio)) || (virtualScreenSize.y < ceil(defaultHeight * yRatio));
        return isTightScreen;
    }

    ui bool calcUltrawide() {
        isUltrawide = (virtualScreenSize.x / virtualScreenSize.y) > 2.0;
        return isUltrawide;
    }

    ui Vector2 getVirtualScreenScale() {
        return (screenSize.x / virtualScreenSize.x, screenSize.y / virtualScreenSize.y);
    }

    ui Vector2 getEffectiveScreenSize() {
        return virtualScreenSize - (screenInsets * 2);
    }

    ui bool makeReady(string texture) {
        return TexMan.MakeReady(TexMan.CheckForTexture(texture));
    }

    ui bool makeTexReady(TextureID texture) {
        return TexMan.MakeReady(texture);
    }

    ui TextureID getReady(string texture) {
        TextureID tex = TexMan.CheckForTexture(texture);
        TexMan.MakeReady(tex);
        return tex;
    }

    ui void adjustXY(out double x, out double y, int flags) {
        if(flags != 0) {
            if(flags & DR_IGNORE_INSETS) {
                if(flags & DR_SCREEN_RIGHT)         x = virtualScreenSize.x + x;
                else if(flags & DR_SCREEN_HCENTER)  x = (virtualScreenSize.x / 2.0) + x;
                if(flags & DR_SCREEN_BOTTOM)        y = virtualScreenSize.y + y;
                else if(flags & DR_SCREEN_VCENTER)  y = (virtualScreenSize.y / 2.0) + y;
            } else {
                if(flags & DR_SCREEN_RIGHT)         x = virtualScreenSize.x - screenInsets.x + x;
                else if(flags & DR_SCREEN_HCENTER)  x = (virtualScreenSize.x / 2.0) + x;
                else                                x += screenInsets.x;
                if(flags & DR_SCREEN_BOTTOM)        y = virtualScreenSize.y - screenInsets.y + y;
                else if(flags & DR_SCREEN_VCENTER)  y = (virtualScreenSize.y / 2.0) + y;
                else                                y += screenInsets.y;
            }
        } else {
            x += screenInsets.x;
            y += screenInsets.y;
        }
    }

    ui void Clip(double left, double top, double width, double height, int flags = 0) {
        Vector2 scale = getVirtualScreenScale();
        
        adjustXY(left, top, flags);
        
        int x = int(left * scale.x);
        int y = int(top * scale.y);
        Screen.SetClipRect(
            x, 
            y, 
            int(left + (width * scale.x) - x), 
            int(top + (height * scale.y) - y)
        );
    }


    ui void ClearClip() {
        Screen.ClearClipRect();
    }


    ui void Dim(int col, double alpha, double left, double top, double width, double height, int flags = 0) {
        Vector2 scale = getVirtualScreenScale();

        adjustXY(left, top, flags);
        
        int x = int(left * scale.x);
        int y = int(top * scale.y);

        Screen.Dim(
            col,
            alpha,
            x, 
            y, 
            int(left + (width * scale.x) - x), 
            int(top + (height * scale.y) - y)
        );
    }


    // Image drawing helper funcs ========================================
    ui void DrawImg(String img, Vector2 pos, int flags = 0, double a = 1.0, bool animate = false, bool filter = true) {
		TextureID tex = TexMan.CheckForTexture (img, TexMan.Type_Any);
        DrawTex(tex, pos, flags, a, animate, filter);
	}

    ui void DrawTex(TextureID tex, Vector2 pos, int flags = 0, double a = 1.0, bool animate = false, bool filter = true) {
        if(flags & DR_WAIT_READY && !TexMan.MakeReady(tex)) { return; }
        adjustXY(pos.x, pos.y, flags);

        screen.DrawTexture(tex, animate, pos.x, pos.y,
            DTA_KeepRatio, true,
            DTA_VirtualWidthF, virtualScreenSize.x, DTA_VirtualHeightF, virtualScreenSize.y, 
            DTA_Alpha, a,
            DTA_Filtering, filter);
    }

    ui void DrawImgAdvanced(String img, Vector2 pos, int flags = 0, double a = 1.0, Vector2 scale = (1, 1), int desaturate = 0, bool filter = true, int color = 0xFFFFFFFF) {
        TextureID tex = TexMan.CheckForTexture (img, TexMan.Type_Any);
		DrawTexAdvanced(tex, pos, flags, a, scale, desaturate, filter, color);
    }

    ui void DrawTexAdvanced(TextureID tex, Vector2 pos, int flags = 0, double a = 1.0, Vector2 scale = (1, 1), int desaturate = 0, bool filter = true, int color = 0xFFFFFFFF) {
        if (tex.isValid()) {
            if(flags & DR_WAIT_READY && !TexMan.MakeReady(tex)) return;

			Vector2 texsize;
            Vector2 scScale = getVirtualScreenScale();
            
            if(flags & DR_SCALE_IS_SIZE) {
                texsize = scale;

                if(flags & DR_IMG_ASPECT_FIT) {
                    let osize = TexMan.GetScaledSize(tex);
                    if(osize.x > osize.y) {
                        texsize.y *= (osize.y / osize.x);
                    } else {
                        texsize.x *= (osize.x / osize.y);
                    }
                }

                scale = (1, 1);
            } else {
                texsize = TexMan.GetScaledSize(tex);
                texsize.x *= scale.x;
                texsize.y *= scale.y;
            }
            
			let rpos = pos;
            adjustXY(rpos.x, rpos.y, flags);

            if(flags & DR_IMG_BOTTOM)       rpos.y -= texsize.y;
            else if(flags & DR_IMG_VCENTER) rpos.y -= texsize.y * 0.5;
            if(flags & DR_IMG_HCENTER)      rpos.x -= texsize.x * 0.5;
            else if(flags & DR_IMG_RIGHT)   rpos.x -= texsize.x;

            int stencil = -1;
            int ccolor = color;
            if(flags & DR_STENCIL) {
                stencil = color;
                ccolor = 0xFFFFFFFF;
            }

            if(flags & DR_NO_SPRITE_OFFSET) {
                screen.DrawTexture(tex, true, 
                    flags & DR_ROUND_COORDS ? rpos.x * scScale.x : rpos.x * scScale.x, 
                    flags & DR_ROUND_COORDS ? rpos.y * scScale.y : rpos.y * scScale.y,
                    DTA_DestWidthF, texsize.x * scScale.x,
                    DTA_DestHeightF, texsize.y * scScale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_TopOffset, 0,
                    DTA_LeftOffset, 0,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_Color, ccolor,
                    DTA_FillColor, stencil,
                    DTA_FlipX, !!(flags & DR_FLIP_X),   // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                    DTA_FlipY, !!(flags & DR_FLIP_Y)    // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                );
            } else {
                screen.DrawTexture(tex, true, 
                    flags & DR_ROUND_COORDS ? rpos.x * scScale.x : rpos.x * scScale.x, 
                    flags & DR_ROUND_COORDS ? rpos.y * scScale.y : rpos.y * scScale.y,
                    DTA_DestWidthF, texsize.x * scScale.x,
                    DTA_DestHeightF, texsize.y * scScale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_Color, ccolor,
                    DTA_FillColor, stencil,
                    DTA_FlipX, !!(flags & DR_FLIP_X),   // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                    DTA_FlipY, !!(flags & DR_FLIP_Y)    // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                );
            }
		}
    }


    ui void DrawTexClip(TextureID tex, Vector2 pos, Vector2 srcPos, Vector2 destSize, int flags = 0, double a = 1.0, Vector2 scale = (1, 1), int desaturate = 0, bool filter = true, int color = 0xFFFFFFFF) {
        if (tex.isValid()) {
			Vector2 texsize;
            Vector2 scScale = getVirtualScreenScale();
            
            if(flags & DR_SCALE_IS_SIZE) {
                texsize = scale;

                if(flags & DR_IMG_ASPECT_FIT) {
                    let osize = TexMan.GetScaledSize(tex);
                    if(osize.x > osize.y) {
                        texsize.y *= (osize.y / osize.x);
                    } else {
                        texsize.x *= (osize.x / osize.y);
                    }
                }

                scale = (1, 1);
            } else {
                texsize = destSize;
                texsize.x *= scale.x;
                texsize.y *= scale.y;
            }
            
			let rpos = pos;
            adjustXY(rpos.x, rpos.y, flags);

            if(flags & DR_IMG_BOTTOM)       rpos.y -= texsize.y;
            else if(flags & DR_IMG_VCENTER) rpos.y -= texsize.y * 0.5;
            if(flags & DR_IMG_HCENTER)      rpos.x -= texsize.x * 0.5;
            else if(flags & DR_IMG_RIGHT)   rpos.x -= texsize.x;

            int stencil = -1;
            int ccolor = color;
            if(flags & DR_STENCIL) {
                stencil = color;
                ccolor = 0xFFFFFFFF;
            }

            if(flags & DR_NO_SPRITE_OFFSET) {
                screen.DrawTexture(tex, true, 
                    rpos.x * scScale.x, 
                    rpos.y * scScale.y,
                    DTA_DestWidthF, texsize.x * scScale.x,
                    DTA_DestHeightF, texsize.y * scScale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_TopOffset, 0,
                    DTA_LeftOffset, 0,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_Color, ccolor,
                    DTA_FillColor, stencil,
                    DTA_FlipX, !!(flags & DR_FLIP_X),   // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                    DTA_FlipY, !!(flags & DR_FLIP_Y),   // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                    DTA_SrcX, srcPos.x,
                    DTA_SrcY, srcPos.y,
                    DTA_SrcWidth, destSize.x, 
                    DTA_SrcHeight, destSize.y
                );
            } else {
                screen.DrawTexture(tex, true, 
                    rpos.x * scScale.x, 
                    rpos.y * scScale.y,
                    DTA_DestWidthF, texsize.x * scScale.x,
                    DTA_DestHeightF, texsize.y * scScale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_Color, ccolor,
                    DTA_FillColor, stencil,
                    DTA_FlipX, !!(flags & DR_FLIP_X),   // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                    DTA_FlipY, !!(flags & DR_FLIP_Y),   // TODO: These don't work propery because they aren't being manually offset. TODO: Fix.
                    DTA_SrcX, srcPos.x,
                    DTA_SrcY, srcPos.y,
                    DTA_SrcWidth, destSize.x, 
                    DTA_SrcHeight, destSize.y
                );
            }
		}
    }


    ui void DrawXImg(String img, Vector2 pos, int flags = 0, double a = 1.0, Vector2 scale = (1, 1), int color = 0xFFFFFFFF, double rotation = 0, Vector2 center = (0, 0), bool flipX = false, bool flipY = false, bool filter = true) {
        TextureID tex = TexMan.CheckForTexture (img, TexMan.Type_Any);
		DrawXTex(tex, pos, flags, a, scale, color, rotation, center, flipX, flipY, filter);
    }

    // Used mostly for crosshairs, defaults to center of the screen, simplifies options, adds rotation and offsetting
    ui void DrawXTex(TextureID tex, Vector2 pos, int flags = 0, double a = 1.0, Vector2 scale = (1, 1), int color = 0xFFFFFFFF, double rotation = 0, Vector2 center = (0, 0), bool flipX = false, bool flipY = false, bool filter = true) {
        if(flags & DR_WAIT_READY && !TexMan.MakeReady(tex)) { return; }

        Vector2 texsize = TexMan.GetScaledSize(tex);
        Vector2 scScale = getVirtualScreenScale();
        Vector2 cpos = (center.x * texSize.x, center.y * texSize.y);

        if(flags & DR_SCALE_IS_SIZE) {
            texsize = scale;
            scale = (1, 1);
        } else {
            texsize.x *= scale.x;
            texsize.y *= scale.y;
        }
        
        Vector2 base = virtualScreenSize * 0.5;
        let rpos = base + pos;

        screen.DrawTexture(tex, true, 
            rpos.x * scScale.x, 
            rpos.y * scScale.y,
            DTA_DestWidthF, texsize.x * scScale.x,
            DTA_DestHeightF, texsize.y * scScale.y,
            DTA_KeepRatio, true,
            DTA_Alpha, a,
            DTA_Filtering, filter,
            DTA_Color, color,
            DTA_Rotate, rotation,
            DTA_LeftOffsetF, cpos.x,
            DTA_TopOffsetF, cpos.y,
            DTA_FlipX, flipx,
            DTA_FlipY, flipy,
            // TODO: Better style handling
            DTA_LegacyRenderStyle, flags & DR_ADDITIVE ? STYLE_Add : STYLE_Translucent
        );
    }


    ui void DrawXImgAdvanced(String img, Vector2 pos, int flags = DR_SCREEN_CENTER, double a = 1.0, Vector2 scale = (1, 1), int color = 0xFFFFFFFF, double rotation = 0, Vector2 center = (0, 0), bool flipX = false, bool flipY = false, bool filter = true) {
        TextureID tex = TexMan.CheckForTexture (img, TexMan.Type_Any);
		DrawXTexAdvanced(tex, pos, flags, a, scale, color, rotation, center, flipX, flipY, filter);
    }

    // Used mostly for crosshairs, defaults to center of the screen, simplifies options, adds rotation and offsetting
    ui void DrawXTexAdvanced(TextureID tex, Vector2 pos, int flags = DR_SCREEN_CENTER, double a = 1.0, Vector2 scale = (1, 1), int color = 0xFFFFFFFF, double rotation = 0, Vector2 center = (0, 0), bool flipX = false, bool flipY = false, bool filter = true) {
        if(flags & DR_WAIT_READY && !TexMan.MakeReady(tex)) return;

        Vector2 texsize = TexMan.GetScaledSize(tex);
        Vector2 scScale = getVirtualScreenScale();
        Vector2 cpos = (center.x * texSize.x, center.y * texSize.y);

        if(flags & DR_SCALE_IS_SIZE) {
            texsize = scale;
            scale = (1, 1);
        } else {
            texsize.x *= scale.x;
            texsize.y *= scale.y;
        }

        let rpos = pos;
        adjustXY(rpos.x, rpos.y, flags);

        // Ignore IMG_X flags, since we use the center variable as the anchor instead
        screen.DrawTexture(tex, true, 
            rpos.x * scScale.x, 
            rpos.y * scScale.y,
            DTA_DestWidthF, texsize.x * scScale.x,
            DTA_DestHeightF, texsize.y * scScale.y,
            DTA_KeepRatio, true,
            DTA_Alpha, a,
            DTA_Filtering, filter,
            DTA_Color, color,
            DTA_Rotate, rotation,
            DTA_LeftOffsetF, cpos.x,
            DTA_TopOffsetF, cpos.y,
            DTA_FlipX, flipx,
            DTA_FlipY, flipy
        );
    }


    ui void DrawImgCol(String img, Vector2 pos, int col = 0xFFFFFFFF, int flags = 0, double a = 1.0, bool animate = false, bool filter = true, int desaturate = 0) {
		TextureID tex = TexMan.CheckForTexture (img, TexMan.Type_Any);

        DrawTexCol(tex, pos, col, flags, a, animate, filter, desaturate);
	}

    ui void DrawTexCol(TextureID tex, Vector2 pos, int col = 0xFFFFFFFF, int flags = 0, double a = 1.0, bool animate = false, bool filter = true, int desaturate = 0) {
		if (tex) {
            adjustXY(pos.x, pos.y, flags);

			screen.DrawTexture(tex, animate, pos.x, pos.y,
				DTA_KeepRatio, true,
				DTA_VirtualWidthF, virtualScreenSize.x, DTA_VirtualHeightF, virtualScreenSize.y,
                DTA_ColorOverlay , col,
                DTA_Alpha, a,
                DTA_Filtering, filter,
                DTA_Desaturate, desaturate);
		}
	}


    ui Vector2 GetPos(int flags) {
        Vector2 pos;
        adjustXY(pos.x, pos.y, flags);
        return pos;
    }


    // Returns the width of the string
    ui float DrawStr(Font fnt, String str, Vector2 pos, int flags = 0, int translation = Font.CR_UNTRANSLATED, double a = 1., bool monoSpace = true, int linespacing = 0, Vector2 scale = (1, 1), bool filter = true, int desaturate = 0, Vector2 padding = (0,0)) {
        int zerowidth = fnt.GetCharWidth("0");
        int spacing = 0;
        int fntHeight = fnt.GetHeight();
        float strWidth = 0;

        Vector2 base;
        adjustXY(base.x, base.y, flags);

        if(monoSpace) strWidth = ((zerowidth + spacing) * scale.x) * str.Length();
        else strWidth = round(fnt.stringWidth(str) * scale.x);

        if(flags & DR_TEXT_RIGHT) {
            base.x -= strWidth + padding.x;
        } else if(flags & DR_TEXT_HCENTER) {
            base.x -= strWidth / 2.0;
        }

        if(flags & DR_TEXT_BOTTOM) {
            base.y -= round(fntHeight * scale.y) + padding.y;
        } else if(flags & DR_TEXT_VCENTER) {
            base.y -= round((fntHeight / 2.0) * scale.y);
        }

        pos += base;
        pos = (pos.x / scale.x, pos.y / scale.y);

        bool fullColor = !(translation <= 128 && translation >= 0);

        if(flags & DR_TEXT_BACKGROUND) {
            // Draw background
            Dim(desaturate, a, pos.x, pos.y, strWidth + padding.x + padding.x, (fntHeight * scale.y) + padding.y + padding.y);
            desaturate = 0;
        }
        
        pos += padding;

        if(fullColor) {
            if(monospace) {
                Screen.DrawText(fnt, Font.CR_UNTRANSLATED, pos.x, pos.y, str,
                    DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Color, translation,
                    DTA_Monospace,
                    MONO_CellCenter,
                    DTA_Spacing, zerowidth,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_CellY, fntHeight + linespacing);
            } else {
                Screen.DrawText(fnt, Font.CR_UNTRANSLATED, pos.x, pos.y, str,
                    DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Color, translation,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_CellY, fntHeight + linespacing);
            }
            
        } else {
            if(monospace) {
                Screen.DrawText(fnt, translation, pos.x, pos.y, str,
                    DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Monospace,
                    MONO_CellCenter,
                    DTA_Spacing, zerowidth,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_CellY, fntHeight + linespacing);
            } else {
                Screen.DrawText(fnt, translation, pos.x, pos.y, str,
                    DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate,
                    DTA_CellY, fntHeight + linespacing);
            }
        }

        return strWidth + padding.x + padding.x;
    }


    ui void DrawStrCol(Font fnt, String str, Vector2 pos, int baseCol = 0xFFFFFFFF, int col = 0xFFFFFFFF, int flags = 0, double a = 1., bool monoSpace = true, int linespacing = 0, Vector2 scale = (1, 1), bool filter = true, int desaturate = 0) {
        int zerowidth = fnt.GetCharWidth("0");
        int spacing = 0;
        int fntHeight = fnt.GetHeight();

        Vector2 base;
        adjustXY(base.x, base.y, flags);

        if(flags & DR_TEXT_RIGHT) {
            if(monospace) {
                base.x -= ((zerowidth + spacing) * scale.x) * str.Length();
            } else {
                base.x -= round((fnt.stringWidth(str) * scale.x) / 2.0);
            }
        } else if(flags & DR_TEXT_HCENTER) {
            if(monospace) {
                base.x -= round((((zerowidth + spacing) * scale.x) * str.Length()) / 2.0);
            } else {
                base.x -= round((fnt.stringWidth(str) * scale.x) / 2.0);
            }
        }

        if(flags & DR_TEXT_BOTTOM) {
            base.y -= fntHeight * scale.y;
        } else if(flags & DR_TEXT_VCENTER) {
            base.y -= (fntHeight / 2.0) * scale.y;
        }

        pos += base;
        pos = (pos.x / scale.x, pos.y / scale.y);

        if(monospace) {
            Screen.DrawText(fnt, Font.CR_UNTRANSLATED, pos.x, pos.y, str,
                DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                DTA_KeepRatio, true,
                DTA_Alpha, a,
                DTA_Color, baseCol,
                DTA_ColorOverlay, col,
                DTA_Monospace,
                MONO_CellCenter,
                DTA_Spacing, zerowidth,
                DTA_Filtering, filter, 
                DTA_Desaturate, desaturate,
                DTA_CellY, fntHeight + linespacing);
        } else {
            Screen.DrawText(fnt, Font.CR_UNTRANSLATED, pos.x, pos.y, str,
                DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                DTA_KeepRatio, true,
                DTA_Alpha, a,
                DTA_Color, baseCol,
                DTA_ColorOverlay, col,
                DTA_Filtering, filter,
                DTA_Desaturate, desaturate,
                DTA_CellY, fntHeight + linespacing);
        }
    }

    // For convenience, returns the total height in virtual space
    ui float DrawStrMultiline(Font fnt, String str, Vector2 pos, int maxWidth, int flags = 0, int translation = Font.CR_UNTRANSLATED, double a = 1., int linespacing = 0, Vector2 scale = (1, 1), bool filter = true, int desaturate = 0) {
        //Vector2 sScale = getVirtualScreenScale();
        float lineHeight = fnt.GetHeight() * scale.y + linespacing;
        bool fullColor = !(translation <= 128 && translation >= 0);

        Vector2 refPos = pos;
        adjustXY(refPos.x, refPos.y, flags);
        

        BrokenLines lines = fnt.BreakLines(str, int(floor(maxWidth / scale.x)));
        float totalHeight = lines.count() * lineHeight;

        if(flags & DR_TEXT_BOTTOM) {
            refPos.y -= totalHeight;
        } else if(flags & DR_TEXT_VCENTER) {
            refPos.y -= round(totalHeight / 2.0);
        } else if(flags & DR_TEXT_VCENTER_FIRSTLINE) {
            refPos.y -= round(lineHeight / 2.0);
        }

        // TODO: Rethink use of ROUND() here
        for(int lineNum = 0; lineNum < lines.count(); lineNum++) {
            Vector2 base = refPos + (0, lineHeight * lineNum);

            if(flags & DR_TEXT_RIGHT) {
                base.x -= lines.StringWidth(lineNum) * scale.x;
            } else if(flags & DR_TEXT_HCENTER) {
                base.x -= round((lines.StringWidth(lineNum) * scale.x) / 2.0);
            }

            if(fullColor) {
                Screen.DrawText(fnt, Font.CR_WHITE, base.x / scale.x, base.y / scale.y, lines.StringAt(lineNum),
                    DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Color, translation,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate);
            } else {
                Screen.DrawText(fnt, translation, base.x / scale.x, base.y / scale.y, lines.StringAt(lineNum),
                    DTA_VirtualWidthF, virtualScreenSize.x / scale.x, DTA_VirtualHeightF, virtualScreenSize.y / scale.y,
                    DTA_KeepRatio, true,
                    DTA_Alpha, a,
                    DTA_Filtering, filter,
                    DTA_Desaturate, desaturate);
            }
        }

        return totalHeight;
    }
}