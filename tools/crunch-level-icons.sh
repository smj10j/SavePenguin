echo "----------- Running pngquant on level icons  --------------"

find "Penguin Rescue/Resources/Levels" -type d | while read dir
do 

echo "In directory: $dir"
tools/pngquant -f -ext .png 256 "$dir"/*.png

done
