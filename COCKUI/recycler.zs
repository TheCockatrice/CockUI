class UIRecycler {
    protected Array<Shape2D> shapes;

    const MAX_SHAPES = 300;

    Shape2D getShape(bool shouldClear = true) {
        if(shapes.size() > 0) {
            Shape2D shape = shapes[shapes.size() - 1];
            shapes.pop();
            if(shouldClear) shape.clear();
            return shape;
        }

        return new("Shape2D");
    }

    void recycleShape(Shape2D shape) {
        if(shapes.size() < MAX_SHAPES) {
            shapes.push(shape);
        } else {
            shape.destroy();
        }
    }
}