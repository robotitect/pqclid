Coordinates = Struct.new(:row, :col)
Box = Struct.new(:top_left, :top_right, :bot_left, :bot_right)

top_left_corners = []
textboxes = []

capture = File.readlines(ARGV[0]) 

capture.each_with_index do |line, row|
  indices_top_left = line.enum_for(:scan, /(?=┌)/).map do 
    Regexp.last_match.offset(0).first
  end    
  
  indices_top_left.each do |col|
      top_left_corners << Coordinates.new(row, col)
  end
end

# Get text for all boxes
top_left_corners.each_with_index do |coords, i|
  puts "Box #{i + 1}"

  first_row = coords.row
  first_col = coords.col

  # Go right until get top right corner
  last_col = first_col + capture[first_row].split("").drop(first_col).find_index('┐')

  # Go down until get bot left corner
  last_row = first_row
  (first_row...capture.size).each do |row|
    char = capture[row].split("")[first_col]
    if char == '└'
        last_row = row
        break
    end
  end
  
  # Extract each line based on corners
  textbox = Array.new()
  (first_row..last_row).each do |r|
    textbox << capture[r][first_col..last_col]
  end

  # puts textbox
  textboxes << textbox
end

