// Designed as a COCKUI drop in replacement for MoviePlayer that can be added to a view hierarchy
class MovieView : UIImage {
    MoviePlayer player;
    String moviePath;
    Sound soundName;
    int startFrameTime, endFrameTime, frameRate;
    bool playing, looping, started, startImmediately, isComplete;

    int ticks;

    MovieView init(Vector2 pos, Vector2 size, String moviePath, Sound soundName = 0, int frameRate = -1, int startFrameTime = -1, int endFrameTime = -1, bool loop = false,
        ImageStyle imgStyle = Image_Scale, Vector2 imgScale = (1,1), ImageAnchor imgAnchor = ImageAnchor_Middle) {

        Super.init(pos, size, "", imgStyle: imgStyle, imgScale: imgScale, imgAnchor: imgAnchor);

        self.moviePath = moviePath;
        self.frameRate = frameRate;
        self.startFrameTime = startFrameTime;
        self.endFrameTime = endFrameTime;
        self.soundName = soundName;
        self.looping = loop;
        self.imgStyle = imgStyle;
        self.imgScale = imgScale;
        self.imgAnchor = imgAnchor;
        self.tex = new("UITexture");    // Dummy texture until we start grabbing frames from the FMV

        startImmediately = false;
        playing = false;

        createPlayer();

        return self;
    }


    void createPlayer() {
        if(player) {
            player.Destroy();
        }

        // Create sound info if sound is valid
        Array<int> sndInfo;
        if(soundName > 0) {
            sndInfo.push(1);
            sndInfo.push(int(soundName));
        }

        player = MoviePlayer.Create(moviePath, sndInfo, 0, frameRate, startFrameTime, endFrameTime);
        
        if(startImmediately) {
            playing = true;
            if(!started) {
                ticks = 0;
                // player will start in Draw()
            }
        }
    }


    override UIView baseInit() {
        Super.baseInit();

        startFrameTime = -1;
        endFrameTime = -1;
        frameRate = -1;
        tex = new("UITexture");    // Dummy texture until we start grabbing frames from the FMV

        return self;
    }


    override void tick() {
        Super.tick();

        if(player && playing) {
            ticks++;
        }
    }


    void startPlaying() {
        playing = true;
        ticks = 0;

        if(!player) {
            createPlayer();
        }

        if(player && !started) {
            player.start();
            started = true;
        }
    }

    
    void stopPlaying() {
        playing = false;
        started = false;
        ticks = 0;
        
        // There is no way to stop the playing audio, so destroy the player
        if(player) {
            player.Destroy();
            player = null;
        }
    }


    override void applyTemplate(UIView view) {
        Super.applyTemplate(view);
        MovieView t = MovieView(view);

        if(t) {
            moviePath = t.moviePath;
            soundName = t.soundName;
            startFrameTime = t.startFrameTime;
            endFrameTime = t.endFrameTime;
            frameRate = t.frameRate;
            looping = t.looping;
            tex = UITexture.Get("");
            if(t.tex && t.tex.isValid()) {
                tex.assignTex(t.tex.texID);
            }

            createPlayer();
        }
    }


    override void draw() {
        if(hidden) { return; }

        if(player && playing) {
            if(!started) {
                player.start();
                started = true;
            }

            double clock = (ticks + System.GetTimeFrac()) * 1000000000. / GameTicRate;
            if(!player.Frame(clock)) {
                // We have advanced beyond the end of the movie, so loop or stop
                if(looping) {
                    ticks = 0;
                    clock = 0;
                    createPlayer();
                    player.start();
                } else {
                    if(tex) tex.setInvalid();
                    playing = false;
                    isComplete = true;
                    return;
                }
            }

            if(!tex) {
                tex = new("UITexture");
            }

            tex.assignTex(player.getTexture());

            Super.draw();
        } else {
            Super.draw();
        }
    }


    override void OnDestroy() {
		if (player) {
			player.Destroy();
		}
		player = null;
	}
}