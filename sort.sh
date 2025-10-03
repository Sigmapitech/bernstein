for file in $@; do
    npx yaml-sort -i "$file" -o "$file.sorted"
    mv "$file.sorted" "$file"
done
