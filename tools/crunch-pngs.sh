echo "----------- Running pngquant on splash screens --------------"
tools/pngquant -f -ext .png 256 Default*.png

tools/crunsh-level-icons.sh
tools/crunch-screenshots.sh
tools/crunch-spritesheets.sh
