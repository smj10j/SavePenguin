echo "----------- Running pngquant on splash screens --------------"
tools/pngquant -f -ext .png 256 Default*.png
echo "----------- Running pngquant on spritesheets --------------"
tools/pngquant -f -ext .png 256 Penguin\ Rescue/Resources/images/*.png
echo "----------- Running pngquant on level icons --------------"
tools/pngquant -f -ext .png 256 Penguin\ Rescue/Resources/Levels/**/*.png
echo "----------- Running pngquant on screenshots  --------------"
tools/pngquant -f -ext .png 256 screenshots/**/**/*.png

