class Neo4jRubyDriverInflector < Zeitwerk::Inflector
  def camelize(basename, _abspath)
    case basename
    when "point_2d_value"
      "Point2DValue"
    when "point_3d_value"
      "Point3DValue"
    else
      super
    end
  end
end
