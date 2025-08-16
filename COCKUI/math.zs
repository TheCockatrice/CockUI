class UIMath {
    const pi = 3.14159;
    const c1 = 1.70158;
    const c3 = c1 + 1;
    const LOOKMUL = double(360. / 65536.);
    
    static Color Desaturate(Color col, float amount = 1.0) {
        uint desat = uint(amount * 256.0);
        uint inv_desaturate = 256 - desat;
        uint intensity = ((col.r * 77 + col.g * 143 + col.b * 37) >> 8) * desat;
        
        return Color(
            col.a,
            (col.r * inv_desaturate + intensity) / 256,
            (col.g * inv_desaturate + intensity) / 256,
            (col.b * inv_desaturate + intensity) / 256
        );
    }

    static Color Darken(Color col, float amount = 1.0) {
        uint desat = uint(amount * 256.0);
        uint inv_desaturate = 256 - desat;
        
        return Color(
            col.a,
            (col.r * inv_desaturate + col.r) / 256,
            (col.g * inv_desaturate + col.g) / 256,
            (col.b * inv_desaturate + col.b) / 256
        );
    }

    static Color Invert(Color col) {
        Color invCol = 0xFFFFFFFF - col;
        return Color(
            col.a,
            invCol.r,
            invCol.g,
            invCol.b
        );
    }

    static Color LerpC(Color a, Color b, float amount = 1.0) {
        float amInv = 1.0f - amount;
        return Color(
            int(a.a * amInv + b.a * amount),
            int(a.r * amInv + b.r * amount), 
            int(a.g * amInv + b.g * amount), 
            int(a.b * amInv + b.b * amount)
        );
    }

    static float Powf(float x, float n) {
        float y = 1.0;
        while (n-- > 0) y *= x;
        return y;
    }

    static double Powd(double x, double n) {
        double y = 1.0;
        while (n-- > 0) y *= x;
        return y;
    }

    const c4 = 360.0 / 3.0;
    static float EaseOutElastic(float x) {
        return x ~== 0
        ? 0
        : x ~== 1
        ? 1
        : Powf(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0;
    }

    static float EaseInQuadF(float x) {
        return x * x;
    }

    static float EaseInQuartF(float x) {
        return x * x * x * x;
    }

    static float EaseOutQuadF(float x) {
        return 1.0 - (1.0 - x) * (1.0 - x);
    }


    static float EaseOutCubicf(float num) {
        return 1.0 - powf(1.0 - num, 3);
    }

    static float EaseOutQuartf(float num) {
        return 1.0 - powf(1.0 - num, 5);
    }

    static float EaseOutCirc(float x) {
        return sqrt(1.0 - powf(x - 1, 2));
    }

    const eob_c1 = 1.70158;
    const eob_c3 = c1 + 1.0;
    static float EaseOutBackF(float x) {
        return 1.0 + eob_c3 * powf(x - 1.0, 3.0) + eob_c1 * powf(x - 1.0, 2.0);
    }

    const eob_cc1 = 2.70158;
    const eob_cc3 = c1 + 1.0;
    static float EaseOutBackMoreF(float x) {
        return 1.0 + eob_cc3 * powf(x - 1.0, 3.0) + eob_cc1 * powf(x - 1.0, 2.0);
    }

    static float EaseInCubicF(float num) {
        return num * num * num;
    }

    static float EaseInOutCubicF(float num) {
        return num < 0.5 ? 4.0 * num * num * num : 1.0 - powf(-2 * num + 2.0, 3) / 2.0;
    }

    static float EaseToAndBack(float num, float mid = 0.5) {
        if(num < mid) {
            return (num / mid) * (num / mid);
        } else {
            float n = (num - mid) / (1.0 - mid);
            return 1.0 - (n * n);
        }
    }

    // Ease out values between x and y by a
    static float EaseOutXYA(float x, float y, float a) {
        float na = EaseOutCubicf(a);
        return x + na * (y - x);
    }

    // Ease in values between x and y by a
    static float EaseInXYA(float x, float y, float a) {
        float na = EaseInCubicF(a);
        return x + na * (y - x);
    }

    // Ease in and then out, values between x and y by a
    static float EaseInOutXYA(float x, float y, float a) {
        float na = EaseInOutCubicF(a);
        return x + na * (y - x);
    }

    static float EaseInBackF(float x) {
        return c3 * x * x * x - c1 * x * x;
    }

    static float EaseInQuintF(float x) {
        return x * x * x * x * x;
    }

    static float Lerpf (float p1, float p2, float a) {
		return p1 + a * (p2 - p1);
	}

    static double Lerpd (double p1, double p2, double a) {
		return p1 + a * (p2 - p1);
	}

    static double Lerpi (int p1, int p2, double a) {
		return int(round(p1 + a * (p2 - p1)));
	}

    // Lerp a Vector
    static Vector2 LerpV(Vector2 a, Vector2 b, float t) {
        return a + t * (b - a);
    }

    // Basic Lerp Angle (Thanks itsmrpeck)
    static double LerpA(double a, double b, double t) {
        float result;
        float diff = b - a;
        if (diff < -180.0) {
            b += 360;
            result = a + t * (b - a);
            if (result >= 360.0) {
                result -= 360.0;
            }
        } else if (diff > 180.0) {
            // lerp downwards past 0
            b -= 360.0;
            result = a + t * (b - a);
            if (result < 0.0) {
                result += 360.0;
            }
        } else {
            // straight lerp
            return a + t * (b - a);
        }

        return result;
    }

    static float rnd2d(float n, float m) {//random 2d gooed enough for mountains -1, 1
        let e = ( n*m *31.178694)%1;
        return  (e*e*137.21321)%1;
    }

    static float rndng ( float n) 
    {//random linear graph -1, 1
        let e = ( n *122.459)%1;
        return  (e*e*143.754)%2-1;
    }

    static double loopi(int a, int start = 0, int end = 360) {
        int width       = end - start;
        int offsetValue = a - start;
        return ( offsetValue - ( offsetValue / width * width ) ) + start;
    }

    static double loopd(double a, double start = 0.0, double end = 1.0) {
        double width       = end - start;
        double offsetValue = a - start;
        return ( offsetValue - ( floor( offsetValue / width ) * width ) ) + start;
    }
}


class Shape2DHelper {
    static void AddQuad(Shape2D shape, Vector2 pos, Vector2 size, Vector2 uvPos, Vector2 uvSize, out int vertCount) {
		shape.pushVertex((pos.x         , pos.y         ));
		shape.pushVertex((pos.x + size.x, pos.y         ));
		shape.pushVertex((pos.x         , pos.y + size.y));
		shape.pushVertex((pos.x + size.x, pos.y + size.y));

		shape.pushTriangle(vertCount + 0, vertCount + 3, vertCount + 1);
		shape.pushTriangle(vertCount + 0, vertCount + 2, vertCount + 3);

		shape.pushCoord((uvPos.x           , uvPos.y           ));
		shape.pushCoord((uvPos.x + uvSize.x, uvPos.y           ));
		shape.pushCoord((uvPos.x           , uvPos.y + uvSize.y));
		shape.pushCoord((uvPos.x + uvSize.x, uvPos.y + uvSize.y));

		vertCount += 4;
	}

    static void AddQuadRawUV(Shape2D shape, Vector2 pos, Vector2 size, Vector2 uvPos, Vector2 uvEndPos, out int vertCount) {
		shape.pushVertex((pos.x         , pos.y         ));
		shape.pushVertex((pos.x + size.x, pos.y         ));
		shape.pushVertex((pos.x         , pos.y + size.y));
		shape.pushVertex((pos.x + size.x, pos.y + size.y));

		shape.pushTriangle(vertCount + 0, vertCount + 3, vertCount + 1);
		shape.pushTriangle(vertCount + 0, vertCount + 2, vertCount + 3);

		shape.pushCoord((uvPos.x       , uvPos.y            ));
		shape.pushCoord((uvEndPos.x    , uvPos.y            ));
		shape.pushCoord((uvPos.x       , uvEndPos.y         ));
		shape.pushCoord((uvEndPos.x    , uvEndPos.y         ));

		vertCount += 4;
	}

    static void AddQuadRawUV4(Shape2D shape, Vector2 pos, Vector2 size, Vector2 uv1, Vector2 uv2, Vector2 uv3, Vector2 uv4, out int vertCount) {
		shape.pushVertex((pos.x         , pos.y         ));
		shape.pushVertex((pos.x + size.x, pos.y         ));
		shape.pushVertex((pos.x         , pos.y + size.y));
		shape.pushVertex((pos.x + size.x, pos.y + size.y));

		shape.pushTriangle(vertCount + 0, vertCount + 3, vertCount + 1);
		shape.pushTriangle(vertCount + 0, vertCount + 2, vertCount + 3);

		shape.pushCoord(uv1);
		shape.pushCoord(uv2);
		shape.pushCoord(uv3);
		shape.pushCoord(uv4);

		vertCount += 4;
	}

    
    static void AddTiledQuads(Shape2D shape, Vector2 screenPos, Vector2 screenSize, Vector2 scaledSize, Vector2 uvPos, Vector2 uvSize, out int vertCount) {
		if (scaledSize.x ~== 0 || scaledSize.y ~== 0) {
			return;
		}

		double fracX = screenSize.x / scaledSize.x;
		double fracY = screenSize.y / scaledSize.y;
		int countX = int (ceil (fracX));
		int countY = int (ceil (fracY));

		double drawSizeLimitX = fracX;
		double drawPosX = screenPos.x;

		for (int x = 0; x < countX; x++) {
			double drawSizeLimitY = fracY;
			double drawPosY = screenPos.y;

			double drawFracX = min (1, drawSizeLimitX);
			double drawSizeX = scaledSize.x * drawFracX;
			double drawUVSizeX = uvSize.x * drawFracX;

			for (int y = 0; y < countY; y++) {
				double drawFracY = min (1, drawSizeLimitY);
				double drawSizeY = scaledSize.y * drawFracY;
				double drawUVSizeY = uvSize.y * drawFracY;

				AddQuad(shape, (drawPosX, drawPosY), (drawSizeX, drawSizeY), uvPos, (drawUVSizeX, drawUVSizeY), vertCount);

				drawPosY += drawSizeY;
				drawSizeLimitY -= drawFracY;
			}

			drawPosX += drawSizeX;
			drawSizeLimitX -= drawFracX;
		}
	}
}


class PerlinNoise {
   static double noise3D(double x, double y, double z) {
      int xx = int(Floor(x)) & 255,                  // FIND UNIT CUBE THAT
          yy = int(Floor(y)) & 255,                  // CONTAINS POINT.
          zz = int(Floor(z)) & 255;
      x -= Floor(x);                                // FIND RELATIVE X,Y,Z
      y -= Floor(y);                                // OF POINT IN CUBE.
      z -= Floor(z);
      double u = fade(x),                                // COMPUTE FADE CURVES
             v = fade(y),                                // FOR EACH OF X,Y,Z.
             w = fade(z);
      int A = PerlinNoise.p[xx  ]+yy, AA = PerlinNoise.p[A]+zz, AB = PerlinNoise.p[A+1]+zz,      // HASH COORDINATES OF
          B = PerlinNoise.p[xx+1]+yy, BA = PerlinNoise.p[B]+zz, BB = PerlinNoise.p[B+1]+zz;      // THE 8 CUBE CORNERS,

      return lerp(w, lerp(v, lerp(u, grad(PerlinNoise.p[AA  ], x  , y  , z   ),  // AND ADD
                                     grad(PerlinNoise.p[BA  ], x-1, y  , z   )), // BLENDED
                             lerp(u, grad(PerlinNoise.p[AB  ], x  , y-1, z   ),  // RESULTS
                                     grad(PerlinNoise.p[BB  ], x-1, y-1, z   ))),// FROM  8
                     lerp(v, lerp(u, grad(PerlinNoise.p[AA+1], x  , y  , z-1 ),  // CORNERS
                                     grad(PerlinNoise.p[BA+1], x-1, y  , z-1 )), // OF CUBE
                             lerp(u, grad(PerlinNoise.p[AB+1], x  , y-1, z-1 ),
                                     grad(PerlinNoise.p[BB+1], x-1, y-1, z-1 ))));
   }
   static double fade(double t) { return t * t * t * (t * (t * 6.0 - 15.0) + 10.0); }
   static double lerp(double t, double a, double b) { return a + t * (b - a); }
   static double grad(int hash, double x, double y, double z) {
      int h = hash & 15;                      // CONVERT LO 4 BITS OF HASH CODE
      double u = h<8 ? x : y,                 // INTO 12 GRADIENT DIRECTIONS.
             v = h<4 ? y : h==12||h==14 ? x : z;
      return ((h&1) == 0 ? u : -u) + ((h&2) == 0 ? v : -v);
   }

   static const int p[] = {
        151,160,137,91,90,15,
        131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
        190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
        88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
        77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
        102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
        135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
        5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
        223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
        129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
        251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
        49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180,
        151,160,137,91,90,15,
        131,13,201,95,96,53,194,233,7,225,140,36,103,30,69,142,8,99,37,240,21,10,23,
        190, 6,148,247,120,234,75,0,26,197,62,94,252,219,203,117,35,11,32,57,177,33,
        88,237,149,56,87,174,20,125,136,171,168, 68,175,74,165,71,134,139,48,27,166,
        77,146,158,231,83,111,229,122,60,211,133,230,220,105,92,41,55,46,245,40,244,
        102,143,54, 65,25,63,161, 1,216,80,73,209,76,132,187,208, 89,18,169,200,196,
        135,130,116,188,159,86,164,100,109,198,173,186, 3,64,52,217,226,250,124,123,
        5,202,38,147,118,126,255,82,85,212,207,206,59,227,47,16,58,17,182,189,28,42,
        223,183,170,213,119,248,152, 2,44,154,163, 70,221,153,101,155,167, 43,172,9,
        129,22,39,253, 19,98,108,110,79,113,224,232,178,185, 112,104,218,246,97,228,
        251,34,242,193,238,210,144,12,191,179,162,241, 81,51,145,235,249,14,239,107,
        49,192,214, 31,181,199,106,157,184, 84,204,176,115,121,50,45,127, 4,150,254,
        138,236,205,93,222,114,67,29,24,72,243,141,128,195,78,66,215,61,156,180
   };
}