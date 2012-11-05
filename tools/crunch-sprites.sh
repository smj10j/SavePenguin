echo "----------- Running pngquant on splash screens and icons --------------"
tools/pngquant -f -ext .png 256 *.png
echo "----------- Running pngquant on spritesheets --------------"
tools/pngquant -f -ext .png 256 Penguin\ Rescue/Resources/images/*.png
echo "----------- Running pngquant on level icons --------------"
tools/pngquant -f -ext .png 256 Penguin\ Rescue/Resources/Levels/**/*.png
