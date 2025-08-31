class UITexture {
    string path;
    TextureID texID;
    Vector2 size;

    static UITexture Get(string path) {
        UITexture tex = new("UITexture");
        tex.path = path;
        tex.texID = TexMan.checkForTexture(path, TexMan.Type_Any);
        tex.size = TexMan.getScaledSize(tex.texID);
		
		if(developer && !tex.texID.isValid() && path != "") {
			Console.Printf("\c[YELLOW]Warning: UITexture(%s): Error loading texture", path);
		}
        return tex;
    }

	static UITexture GetTex(TextureID tid) {
        UITexture tex = new("UITexture");
        tex.path = "";
        tex.texID = tid;
        tex.size = TexMan.getScaledSize(tex.texID);

		if(developer && !tex.texID.isValid() && int(tid) != 0) {
			Console.Printf("\c[YELLOW]Warning: UITexture(%d): Error loading texture", tid);
		}

        return tex;
    }

	bool isValid() {
		return texID.isValid();
	}

	ui bool makeReady() {
		return TexMan.MakeReady(texID);
	}

	ui void unload() {
		if(texID.isValid()) {
			TexMan.UnloadTexture(texID);
		}
	}
}

struct UISTexture {
	string path;
    TextureID texID;
    Vector2 size;

    bool get(string path, bool readyUp = false) {
        path = path;
        texID = TexMan.checkForTexture(path, TexMan.Type_Any);
        size = TexMan.getScaledSize(texID);

		if(developer > 1 && !texID.isValid() && path != "") {
			Console.Printf("\c[YELLOW]Warning: UITexture(%s): Error loading texture", path);
		}

        return isValid();
    }

	bool getTex(TextureID tid) {
        path = "";
        texID = tid;
        size = TexMan.getScaledSize(texID);

		if(developer > 1 && !texID.isValid() && int(tid) != 0) {
			Console.Printf("\c[YELLOW]Warning: UITexture(%d): Error loading texture", tid);
		}

        return isValid();
    }

	bool isValid() {
		return texID.isValid();
	}

	ui bool makeReady() {
		return TexMan.MakeReady(texID);
	}

	ui void unload() {
		if(texID.isValid()) {
			TexMan.UnloadTexture(texID);
		}
	}
}


class NineSlice {
    Vector2 tl, br;
	Vector2 tlpix, brpix;
    UITexture texture;
    bool drawCenter, scaleCenter, scaleSides;

    static NineSlice Create(string tex, Vector2 topLeft, Vector2 bottomRight, bool scaleSides = true, bool scaleCenter = true, bool drawCenter = true) {
        NineSlice slice = new("NineSlice");
        slice.drawCenter = drawCenter;
        slice.scaleCenter = scaleCenter;
        slice.scaleSides = scaleSides;
        slice.texture = UITexture.Get(tex);
        slice.setPixels(topLeft, bottomRight);
		
        return slice;
    }

    void setPixels(Vector2 topLeft, Vector2 bottomRight) {
		tlpix = topLeft;
		brpix = bottomRight;
		tl = (topLeft.x / texture.size.x, topLeft.y / texture.size.y);
		br = (bottomRight.x / texture.size.x, bottomRight.y / texture.size.y);
    }

    Vector2 scaleVec(Vector2 a, Vector2 b) {
        return (a.x * b.x, a.y * b.y);
    }


	void buildShape(Shape2D shape, Vector2 pos, Vector2 size, Vector2 scale = (1,1), int pointCount = 0, bool usePixelBoundary = false) {
		Vector2 imageSize = texture.size;
		
		if(usePixelBoundary) {
			pos = (floor(pos.x), floor(pos.y));
			size = (floor(size.x), floor(size.y));
		}

		if (imageSize.x < 0 || imageSize.x ~== 0 || imageSize.y < 0 || imageSize.y ~== 0) {
			return;
		}

		// TODO: Not all of these are even used, dummy.
		Vector2 uv[] = {
			(0, 0), 	(tl.x, 0), 		(br.x, 0), 		(1, 0),			// Top Row
			(0, tl.y), 	(tl.x, tl.y), 	(br.x, tl.y),	(1, tl.y),		// Upper Row
			(0, br.y),  (tl.x, br.y),	(br.x, br.y), 	(1, br.y),		// Lower Row
			(0, 1), 	(tl.x, 1), 		(br.x, 1), 		(1,1)			// Bottom Row
		};

		double right = size.x;
		double bottom = size.y;
		Vector2 tls = scaleVec(tlpix, scale);
		Vector2 brs = size - scaleVec(imageSize - brpix, scale);

		Vector2 hpos[] = {
			(0, 0), 	(tls.x, 0), 	(brs.x, 0), 	(right, 0),			// Top Row
			(0, tls.y), (tls.x, tls.y), (brs.x, tls.y),	(right, tls.y),		// Upper Row
			(0, brs.y), (tls.x, brs.y),	(brs.x, brs.y), (right, brs.y),		// Lower Row
			(0, bottom),(tls.x, bottom),(brs.x, bottom),(right, bottom)		// Bottom Row
		};

		// Start with corners because they don't require tiling
		Shape2DHelper.AddQuadRaw(shape, hpos[0], hpos[5], uv[0], uv[5], pointCount);	// Top Left
		Shape2DHelper.AddQuadRaw(shape, hpos[2], hpos[7], uv[2], uv[7], pointCount);	// Top Right
		Shape2DHelper.AddQuadRaw(shape, hpos[8], hpos[13], uv[8], uv[13], pointCount);	// Bottom Left
		Shape2DHelper.AddQuadRaw(shape, hpos[10], hpos[15], uv[10], uv[15], pointCount);	// Bottom Right

		// Center
		if(drawCenter) {
			if(scaleCenter) {
				Shape2DHelper.AddQuadRaw(shape, hpos[5], hpos[10], uv[5], uv[10], pointCount);
			} else {
				Vector2 midScaledSize = (brs.x - tls.x, brs.y - tls.y);
				Shape2DHelper.AddTiledQuads(shape, hpos[5], (brs.x - tls.x, brs.y - tls.y), midScaledSize, uv[5], (uv[10].x - uv[5].x, uv[10].y - uv[5].y), pointCount);
			}
		}

		// Sides
		if(scaleSides) {
			Shape2DHelper.AddQuadRaw(shape, hpos[1], hpos[6],  uv[1], uv[6],  pointCount);	// Top
			Shape2DHelper.AddQuadRaw(shape, hpos[9], hpos[14], uv[9], uv[14], pointCount);	// Bottom
			Shape2DHelper.AddQuadRaw(shape, hpos[4], hpos[9],  uv[4], uv[9],  pointCount);	// Left
			Shape2DHelper.AddQuadRaw(shape, hpos[6], hpos[11], uv[6], uv[11], pointCount);	// Right
		} else {
			Vector2 topScaledSize 		= (brs.x - tls.x, tls.y);
			Vector2 bottomScaledSize 	= (brs.x - tls.x, bottom - brs.y);
			Vector2 leftScaledSize 		= (tls.x, 		  brs.y - tls.y);
			Vector2 rightScaledSize 	= (right - brs.x, brs.y - tls.y);

			Shape2DHelper.AddTiledQuads(shape, hpos[1], (brs.x - tls.x, tls.y), topScaledSize, uv[1], (uv[6].x - uv[1].x, uv[6].y - uv[1].y), pointCount);					// Top
			Shape2DHelper.AddTiledQuads(shape, hpos[9], (brs.x - tls.x, bottom - brs.y), bottomScaledSize, uv[9], (uv[14].x - uv[9].x, uv[14].y - uv[9].y), pointCount);	// Bottom
			Shape2DHelper.AddTiledQuads(shape, hpos[4], (tls.x, brs.y - tls.y), leftScaledSize, uv[4], (uv[9].x - uv[4].x, uv[9].y - uv[4].y), pointCount);					// Left
			Shape2DHelper.AddTiledQuads(shape, hpos[6], (right - brs.x, brs.y - tls.y), rightScaledSize, uv[6], (uv[11].x - uv[6].x, uv[11].y - uv[6].y), pointCount);		// Right
		}
    }
}