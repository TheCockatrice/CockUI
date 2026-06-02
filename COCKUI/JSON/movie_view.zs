extend class MovieView {

    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates, UIView parentView) {
        Super._deserialize(obj, templates, parentView);

        getOptionalString(obj, "moviePath", moviePath);
        
        String sndName;
        getOptionalString(obj, "soundName", sndName);
        if(sndName) {
            soundName = sndName;
        }

        getOptionalBool(obj, "looping", looping);
        getOptionalBool(obj, "startImmediately", startImmediately);

        getOptionalInt(obj, "startFrameTime", startFrameTime);
        getOptionalInt(obj, "endFrameTime", endFrameTime);

        // TODO: If this is going to be a template, we don't want to actually create a player.. no idea how to prevent this just yet
        // So don't make template views with MoviewView in them yet!
        createPlayer();

        return self;
    }
}
