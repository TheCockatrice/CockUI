extend class UIVerticalLayout {
    override UIView _deserialize(JsonObject obj, Map<Name, UIView> templates) {
        Super._deserialize(obj, templates);

        

        return self;
    }
}
