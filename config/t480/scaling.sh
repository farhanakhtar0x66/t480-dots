# Qt Quick uses logical pixels; keep its scale aligned with Xft/GTK.
# Pin the base DPI so Xft.dpi does not multiply the scale a second time.
export QT_FONT_DPI=96
export QT_SCALE_FACTOR=1.25
export QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough
