capture = File.open(ARGV[0]) 

Coordinates = Struct.new(:row, :col)
Box = Struct.new(:top_left, :top_right, :bot_left, :bot_right)

Boxes = Array.new

top_left_corners = Array.new

capture.each_with_index do |line, row|
  indices_top_left = line.enum_for(:scan, /(?=┌)/).map do 
    Regexp.last_match.offset(0).first
  end    
  
  indices_top_left.each do |col|
      top_left_corners << Coordinates.new(row, col)
  end
end

puts top_left_corners

# Get coordinates for all boxes
# Go down until get bot left corner
# Go right until get top right corner
# Have coordinates for the bot right corner now as well

top_left_corners.each do |coords|
  r, c = coords
end

