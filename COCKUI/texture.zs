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
}


class NineSlice {
    Vector2 tl, br;
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
		tl = (topLeft.x / texture.size.x, topLeft.y / texture.size.y);
		br = (bottomRight.x / texture.size.x, bottomRight.y / texture.size.y);
    }

    Vector2 scaleVec(Vector2 a, Vector2 b) {
        return (a.x * b.x, a.y * b.y);
    }

    // Reused code from ZForms because it works. Thanks ZForms!
    void buildShape(Shape2D shape, Vector2 pos, Vector2 size, Vector2 scale = (1,1), int pointCount = 0) {
		if(!texture) return;
		Vector2 imageSize = texture.size;
		Vector2 imageSizeInv = (1.0 / imageSize.x, 1.0 / imageSize.y);

		if (imageSize.x < 0 || imageSize.x ~== 0 || imageSize.y < 0 || imageSize.y ~== 0) {
			return;
		}

		let absPos = (floor(pos.x), floor(pos.y));
		let scaledSize = size;

		// Raw
		Vector2 tlRawSize = scaleVec(imageSize, tl);

		Vector2 brRawPos = scaleVec(imageSize, br);
		Vector2 brRawSize = imageSize - brRawPos;

		Vector2 midRawPos = tlRawSize;
		Vector2 midRawSize = brRawPos - tlRawSize;

		// UVs
		Vector2 tlUVSize = scaleVec(tlRawSize, imageSizeInv);

		Vector2 brUVSize = scaleVec(brRawSize, imageSizeInv);
		Vector2 brUVPos = scaleVec(brRawPos, imageSizeInv);

		Vector2 midUVPos = scaleVec(midRawPos, imageSizeInv);
		Vector2 midUVSize = scaleVec(midRawSize, imageSizeInv);

		// Scaled
		Vector2 tlScaledSize = scaleVec(tlRawSize, scale);

		Vector2 brScaledPos = scaleVec(brRawPos, scale);
		Vector2 brScaledSize = scaleVec(brRawSize, scale);

		Vector2 midScaledPos = scaleVec(midRawPos, scale);
		Vector2 midScaledSize = scaleVec(midRawSize, scale);

		// Screen
		Vector2 tlScreenPos = absPos;
		Vector2 tlScreenSize = tlScaledSize;

		Vector2 brScreenPos = absPos + scaledSize - brScaledSize;
		Vector2 brScreenSize = (absPos + scaledSize) - brScreenPos;

		Vector2 midScreenPos = tlScreenPos + tlScreenSize;
		Vector2 midScreenSize = brScreenPos - midScreenPos;

		int vertCount = pointCount;

		/* Corners */ {
			// Screen
			Vector2 trScreenPos = (brScreenPos.x, tlScreenPos.y);
			Vector2 trScreenSize = (brScreenSize.x, tlScreenSize.y);

			Vector2 blScreenPos = (tlScreenPos.x, brScreenPos.y);
			Vector2 blScreenSize = (tlScreenSize.x, brScreenSize.y);
			
			Shape2DHelper.AddQuadRawUV(shape, tlScreenPos, tlScreenSize, (0,0), tl, vertCount);				// Top Left
			Shape2DHelper.AddQuadRawUV(shape, trScreenPos, trScreenSize, (br.x, 0), (1, tl.y), vertCount);	// Top Right
			Shape2DHelper.AddQuadRawUV(shape, blScreenPos, blScreenSize, (0, br.y), (tl.x, 1), vertCount);	// Bottom Left
			Shape2DHelper.AddQuadRawUV(shape, brScreenPos, brScreenSize, (br.x, br.y), (1, 1), vertCount);	// Bottom Right
		}

		/* Sides */ {
			// Screen
			Vector2 topScreenPos = (midScreenPos.x, tlScreenPos.y);
			Vector2 topScreenSize = (midScreenSize.x, tlScreenSize.y);

			Vector2 bottomScreenPos = (midScreenPos.x, brScreenPos.y);
			Vector2 bottomScreenSize = (midScreenSize.x, brScreenSize.y);

			Vector2 leftScreenPos = (tlScreenPos.x, midScreenPos.y);
			Vector2 leftScreenSize = (tlScreenSize.x, midScreenSize.y);

			Vector2 rightScreenPos = (brScreenPos.x, midScreenPos.y);
			Vector2 rightScreenSize = (brScreenSize.x, midScreenSize.y);

			if(scaleSides) {
				Shape2DHelper.AddQuadRawUV(shape, topScreenPos, 	topScreenSize, 		(tl.x, 0), 	 (br.x, tl.y),	vertCount);
				Shape2DHelper.AddQuadRawUV(shape, bottomScreenPos, 	bottomScreenSize, 	(tl.x, br.y), 	(br.x, 1), 	vertCount);
				Shape2DHelper.AddQuadRawUV(shape, leftScreenPos, 	leftScreenSize, 	(0, tl.y), 	 (tl.x, br.y), 	vertCount);
				Shape2DHelper.AddQuadRawUV(shape, rightScreenPos, 	rightScreenSize, 	(br.x, tl.y), 	(1, br.y), 	vertCount);
			} else {
				Vector2 topUVPos = (midUVPos.x, 0);
				Vector2 topUVSize = (midUVSize.x, tlUVSize.y);

				Vector2 bottomUVPos = (midUVPos.x, brUVPos.y);
				Vector2 bottomUVSize = (midUVSize.x, brUVSize.y);

				Vector2 leftUVPos = (0, midUVPos.y);
				Vector2 leftUVSize = (tlUVSize.x, midUVSize.y);

				Vector2 rightUVPos = (brUVPos.x, midUVPos.y);
				Vector2 rightUVSize = (brUVSize.x, midUVSize.y);

				Vector2 topScaledSize = (midScaledSize.x, tlScaledSize.y);
				Vector2 bottomScaledSize = (midScaledSize.x, brScaledSize.y);
				Vector2 leftScaledSize = (tlScaledSize.x, midScaledSize.y);
				Vector2 rightScaledSize = (brScaledSize.x, midScaledSize.y);

				Shape2DHelper.AddTiledQuads(shape, topScreenPos, topScreenSize, topScaledSize, topUVPos, topUVSize, vertCount);
				Shape2DHelper.AddTiledQuads(shape, bottomScreenPos, bottomScreenSize, bottomScaledSize, bottomUVPos, bottomUVSize, vertCount);
				Shape2DHelper.AddTiledQuads(shape, leftScreenPos, leftScreenSize, leftScaledSize, leftUVPos, leftUVSize, vertCount);
				Shape2DHelper.AddTiledQuads(shape, rightScreenPos, rightScreenSize, rightScaledSize, rightUVPos, rightUVSize, vertCount);
			}
		}

		if(drawCenter) {
			if(scaleCenter) {
				Shape2DHelper.AddQuadRawUV(shape, midScreenPos, midScreenSize, tl, br, vertCount);
			} else {
				Shape2DHelper.AddTiledQuads(shape, midScreenPos, midScreenSize, midScaledSize, midUVPos, midUVSize, vertCount);
			}
		}
    }


	// Same as above but forces (0,0) and (1,1) where necessary
	void buildShape2(Shape2D shape, Vector2 pos, Vector2 size, Vector2 scale = (1,1), int pointCount = 0) {
		Vector2 imageSize = texture.size;
		Vector2 imageSizeInv = (1 / imageSize.x, 1 / imageSize.y);

		if (imageSize.x < 0 || imageSize.x ~== 0 || imageSize.y < 0 || imageSize.y ~== 0) {
			return;
		}

		let absPos = (floor(pos.x), floor(pos.y));
		let scaledSize = size;

		// Raw
		Vector2 tlRawSize = scaleVec(imageSize, tl);

		Vector2 brRawPos = scaleVec(imageSize, br);
		Vector2 brRawSize = imageSize - brRawPos;

		Vector2 midRawPos = tlRawSize;
		Vector2 midRawSize = brRawPos - tlRawSize;

		// UVs
		Vector2 tlUVSize = scaleVec(tlRawSize, imageSizeInv);

		Vector2 brUVSize = scaleVec(brRawSize, imageSizeInv);
		Vector2 brUVPos = scaleVec(brRawPos, imageSizeInv);

		Vector2 midUVPos = scaleVec(midRawPos, imageSizeInv);
		Vector2 midUVSize = scaleVec(midRawSize, imageSizeInv);

		// Scaled
		Vector2 tlScaledSize = scaleVec(tlRawSize, scale);

		Vector2 brScaledPos = scaleVec(brRawPos, scale);
		Vector2 brScaledSize = scaleVec(brRawSize, scale);

		Vector2 midScaledPos = scaleVec(midRawPos, scale);
		Vector2 midScaledSize = scaleVec(midRawSize, scale);

		// Screen
		Vector2 tlScreenPos = absPos;
		Vector2 tlScreenSize = tlScaledSize;

		Vector2 brScreenPos = absPos + scaledSize - brScaledSize;
		Vector2 brScreenSize = (absPos + scaledSize) - brScreenPos;

		Vector2 midScreenPos = tlScreenPos + tlScreenSize;
		Vector2 midScreenSize = brScreenPos - midScreenPos;

		int vertCount = pointCount;

		/* Corners */ {
			// UVs
			Vector2 trUVPos = (brUVPos.x, 0);
			Vector2 trUVSize = (brUVSize.x, tlUVSize.y);

			Vector2 blUVPos = (0, brUVPos.y);
			Vector2 blUVSize = (tlUVSize.x, brUVSize.y);
			// Screen
			Vector2 trScreenPos = (brScreenPos.x, tlScreenPos.y);
			Vector2 trScreenSize = (brScreenSize.x, tlScreenSize.y);

			Vector2 blScreenPos = (tlScreenPos.x, brScreenPos.y);
			Vector2 blScreenSize = (tlScreenSize.x, brScreenSize.y);
			
			Shape2DHelper.AddQuad(shape, tlScreenPos, tlScreenSize,  (0, 0), tlUVSize, vertCount);
			Shape2DHelper.AddQuadRawUV(shape, trScreenPos, trScreenSize, trUVPos, (1, trUVPos.y + trUVSize.y), vertCount);
			Shape2DHelper.AddQuadRawUV(shape, brScreenPos, brScreenSize, brUVPos, (1,1), vertCount);
			Shape2DHelper.AddQuadRawUV(shape, blScreenPos, blScreenSize, blUVPos, (blUVPos.x + blUVSize.x, 1), vertCount);
		}

		/* Sides */ {
			// UVs
			Vector2 topUVPos = (midUVPos.x, 0);
			Vector2 topUVSize = (midUVSize.x, tlUVSize.y);

			Vector2 bottomUVPos = (midUVPos.x, brUVPos.y);
			Vector2 bottomUVSize = (midUVSize.x, brUVSize.y);

			Vector2 leftUVPos = (0, midUVPos.y);
			Vector2 leftUVSize = (tlUVSize.x, midUVSize.y);

			Vector2 rightUVPos = (brUVPos.x, midUVPos.y);
			Vector2 rightUVSize = (brUVSize.x, midUVSize.y);
			// Screen
			Vector2 topScreenPos = (midScreenPos.x, tlScreenPos.y);
			Vector2 topScreenSize = (midScreenSize.x, tlScreenSize.y);

			Vector2 bottomScreenPos = (midScreenPos.x, brScreenPos.y);
			Vector2 bottomScreenSize = (midScreenSize.x, brScreenSize.y);

			Vector2 leftScreenPos = (tlScreenPos.x, midScreenPos.y);
			Vector2 leftScreenSize = (tlScreenSize.x, midScreenSize.y);

			Vector2 rightScreenPos = (brScreenPos.x, midScreenPos.y);
			Vector2 rightScreenSize = (brScreenSize.x, midScreenSize.y);

			if(scaleSides) {
				Shape2DHelper.AddQuad(shape, topScreenPos, topScreenSize, topUVPos, topUVSize, vertCount);
				Shape2DHelper.AddQuadRawUV(shape, bottomScreenPos, bottomScreenSize, bottomUVPos, (bottomUVPos.x + bottomUVSize.x, 1), vertCount);
				Shape2DHelper.AddQuad(shape, leftScreenPos, leftScreenSize, leftUVPos, leftUVSize, vertCount);
				Shape2DHelper.AddQuadRawUV(shape, rightScreenPos, rightScreenSize, rightUVPos, (1, rightUVPos.y + rightUVSize.y), vertCount);
			} else {
				Vector2 topScaledSize = (midScaledSize.x, tlScaledSize.y);
				Vector2 bottomScaledSize = (midScaledSize.x, brScaledSize.y);
				Vector2 leftScaledSize = (tlScaledSize.x, midScaledSize.y);
				Vector2 rightScaledSize = (brScaledSize.x, midScaledSize.y);

				Shape2DHelper.AddTiledQuads(shape, topScreenPos, topScreenSize, topScaledSize, topUVPos, topUVSize, vertCount);
				Shape2DHelper.AddTiledQuads(shape, bottomScreenPos, bottomScreenSize, bottomScaledSize, bottomUVPos, bottomUVSize, vertCount);
				Shape2DHelper.AddTiledQuads(shape, leftScreenPos, leftScreenSize, leftScaledSize, leftUVPos, leftUVSize, vertCount);
				Shape2DHelper.AddTiledQuads(shape, rightScreenPos, rightScreenSize, rightScaledSize, rightUVPos, rightUVSize, vertCount);
			}
		}

		if(drawCenter) {
			if(scaleCenter) {
				Shape2DHelper.AddQuad(shape, midScreenPos, midScreenSize, midUVPos, midUVSize, vertCount);
			} else {
				Shape2DHelper.AddTiledQuads(shape, midScreenPos, midScreenSize, midScaledSize, midUVPos, midUVSize, vertCount);
			}
		}
    }
}