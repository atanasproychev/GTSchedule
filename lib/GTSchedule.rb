# encoding: utf-8
require 'nokogiri'
require 'prawn'
require 'open-uri'

module GT
  HOME_DIRECTORY = "G:/Dropbox/Ruby/GTProject/GTSchedule/"
  class GTSchedule
    def initialize(type, lines = :all)
      line_numbers = get_lines
      # p lines
      if lines.instance_of? Hash
        line_numbers.each_key do |type|
          if lines[type].nil?
            line_numbers[type] = []
          else
            line_numbers[type] &= lines[type]
          end
        end
      end
      @lines = {}
      @type = type == :all ? [:weekdays, :saturday, :sunday] : type
      # p line_numbers
      line_numbers.each do |type, numbers|
        line_objects = []
        numbers.each { |number| line_objects << Line.new(number, type, @type[0]) }
        @lines[type] = line_objects.sort { |line1, line2| line1.number.to_i <=> line2.number.to_i }
      end
      # p HOME_DIRECTORY
    end
    
    def get_lines
      # document = GTSchedule.parse "Home.html"
      document = GTSchedule.parse ""
      lines = {}
      sections = document.css(".lines_section")
      sections.each_with_index do |section, index|
        numbers = []
        sections[index].css("a").each { |line| numbers << line.text }
        type = case index
                 when 0
                   :tramway
                 when 1
                   :trolleybus
                 when 2, 3
                   :autobus
               end
        lines.merge!({type => numbers}) { |key, old, new| old + new }
      end
      lines.merge!({:metro => ['1']})
      # lines
    end
  
    def self.parse(url = nil)
      # new_html = open("http://schedules.sofiatraffic.bg/autobus/102").read  #IO.read(File.expand_path("../../test102.html"))
      # p __FILE__
      p url
      # html = IO.read(File.expand_path("../../../#{url}", __FILE__))
      html = self.get_html_from "http://schedules.sofiatraffic.bg/#{url}"
      # p html, "\n\n"
      document = Nokogiri::HTML::Document.parse(html, nil, "utf-8")
      
      #File.open(File.expand_path("../../test.txt")) { |file| new_html << file.read }
      
      #puts directions
      # document.css(".schedule_direction_view_course table")[0].css("th,td")
      # line = Line.new '102', :autobus, directions
      
      # times
      # Prawn::Document.generate("Proba.pdf") do
        # font_path = "#{Prawn::BASEDIR}/data/fonts/"
        # font_families.update('TimesNewRoman' => {:bold => font_path + 'timesbd.ttf',
                                                    # :italic => font_path + 'timesi.ttf',
                                                    # :bold_italic => font_path + 'timesbi.ttf',
                                                    # :normal => font_path + 'times.ttf'},
                                # 'CourierNew' => {:normal => font_path + 'cour.ttf'})
        # font 'TimesNewRoman'
        # text document.css("h3").text
      # end
    end
    
    def self.get_html_from(site)
      # open(site) { |f| f.each_line { |line| p line } }#.read
      open(site).read
    end
    
    def to_pdf
      @type.each do |type|
        prawn_object = Prawn::Document.new
        font_path = "#{Prawn::BASEDIR}/data/fonts/"
        prawn_object.font_families.update('TimesNewRoman' => {:bold => font_path + 'timesbd.ttf',
                                                              :italic => font_path + 'timesi.ttf',
                                                              :bold_italic => font_path + 'timesbi.ttf',
                                                              :normal => font_path + 'times.ttf'},
                                          'CourierNew' => {:normal => font_path + 'cour.ttf',
                                                           :bold => font_path + 'courbd.ttf',
                                                           :italic => font_path + 'couri.ttf'})
        prawn_object.font 'CourierNew'
        
        create_content_pages prawn_object
        [:autobus, :trolleybus, :tramway, :metro].each do |type_transport|
          @lines[type_transport].each do |line|
            line.change_type_of_schedule type
            line.to_pdf(prawn_object)
          end
        end
        time = Time.new
        name = "#{HOME_DIRECTORY}pdf/#{type.capitalize}_#{time.day}_#{time.mon}_#{time.year}"
        prawn_object.render_file "#{name}.pdf"
      end
    end
    
    def create_content_pages(prawn_object)
      prawn_object.text "<b>Съдържание</b>", :inline_format => true, :size => 18, :align => :center
      prawn_object.move_down 40
      count_of_all_lines = @lines.inject(0) { |sum, (type, lines)| sum + lines.length }
      displacement = (count_of_all_lines / 40.0).ceil
      p displacement
      page = displacement + 1
      [:autobus, :trolleybus, :tramway, :metro].each do |type_transport|
        max_dots = 75
        type_transport_name = GTSchedule.transport_type_name type_transport
        heading = type_transport_name.dup
        heading[-1] = 'и' unless type_transport == :metro
        heading << ' линии'
        unless @lines[type_transport] == []
          prawn_object.text "<b>#{heading}</b>", :inline_format => true, :size => 16
          prawn_object.move_down 5
        end
        # p type_transport
        @lines[type_transport].each do |line|
          content_string = "%s линия %d" % [type_transport_name, line.number]
          line.page = page
          dots = max_dots - content_string.length
          dots -= page > 9 ? 2 : 1
          content_string << '.' * dots << page.to_s
          prawn_object.text content_string, :inline_format => true
          prawn_object.move_down 5
          page += line.count_of_directions
        end
      end
    end
    
    def self.schedule_name(type)
      if type == :weekdays
        'делник'
      elsif type == :saturday
        'предпразник'
      elsif type == :sunday
        'празник'
      end
    end
    
    def self.transport_type_name(type)
      if type == :autobus
        'Автобусна'
      elsif type == :trolleybus
        'Тролейбусна'
      elsif type == :tramway
        'Трамвайна'
      elsif type == :metro
        'Метро'
      end
    end
  end
  
  class MyTime
    attr_accessor :minutes, :hours
    
    def initialize(time)
      # p time
      time.match /(\d?\d):(\d\d)/
      @hours = $1.to_i
      @minutes = $2.to_i
      # p @hours
      # p @minutes
    end
    
    def +(minutes)
      @minutes += minutes
      if @minutes >= 60
        @hours++
        @minutes = @minutes % 60
      end
    end
    
    def -(other)
      minutes = @minutes - other.minutes
      hours = @hours - other.hours
      if minutes < 0
        minutes += 60
        hours -= 1
      end
      if hours == -24
        hours = 0
      end
      time_string = "%02d:%02d" % [hours, minutes]
      MyTime.new time_string
    end
    
    def self.minutes_to_min_sec(minutes)
      min = minutes.to_i
      sec = (minutes - min) * 100
      sec *= 0.6
      "%02d:%02d" % [min, sec.to_i]
    end
    
    def to_min
      @hours * 60 + @minutes
    end
    
    def to_s
      "#@hours:#@minutes"
    end
  end
  
  class Course
    attr_accessor :course_times, :begins, :vehicle
  
    def initialize(begins, course_times, incomplete = false)
      @begins = MyTime.new begins
      @course_times = get_times_from course_times
      # p @course_times
      @incomplete = incomplete
    end
    
    def get_times_from(course_times)
      @vehicle = 0;
      course_times.match(/Raz.exec \('show_course', \['.{9}', '(.+?)'\]\); return false;/)
      course_times = $1
      course_times = course_times.split(',').map { |elem| elem.to_i }
      @vehicle = course_times.shift
      (1...course_times.length).each { |index| course_times[index] -= course_times[0] }
      course_times[0] = 0
      course_times
    end
    
    def incomplete?
      @incomplete
    end
    
    def as_minutes
      @begins.minutes
    end
    
    def to_pdf(prawn_object)
      rgb_string = @incomplete ? ' rgb="FF0000"' : ''
      string = "<color%s>%02d</color>" % [rgb_string, @begins.minutes]
      prawn_object.text string, :inline_format => true, :align => :center
    end
    
    def to_s
      @begins
      #p @time
    end
  end
  
  class Direction
    attr_accessor :name, :course_list, :station_list

    def initialize(name, time_to = nil)
      @name = name
      @course_list = []
      @station_list = []
    end
    
    def average_course_times
      # p @course_list.flatten
      course_times = @course_list.flatten.map { |course| course.course_times.dup }
      # p test
      all = []
      # p max_length test
      max_length(course_times).times do |number|
        arr = []
        course_times.map! do |array|
          arr << array.shift
          array
        end
        all << arr.compact
      end
    # p @course_list
      all.map do |elem|
        (elem.inject(0.0, :+) / elem.length).round(2)
      end
      # p test, all
      #p test.transpose
    end
    
    def max_length(array)
      return 0 if array.first.nil?
      max = array.first.length
      array.each { |arr| max = arr.length > max ? arr.length : max }
      max
    end
    
    def vehicles(from = 4, to = 24)  #???+
      list = []
      ((from - 4)..(to - 4)).each { |hour| list << @course_list[hour] }
      list.flatten.map { |course| course.vehicle }.uniq.length
    end
    
    def average_interval_between(from, to)
      time_list = @course_list[from - 4..to - 4].flatten.map(&:begins)#.map { |time| MyTime.new time }
      # p time_list#.map(&:class)
      return 0 if time_list == []
      intervals = []
      # arr = [1, 2, 3, 5, 8]
      time_list.each_cons(2) { |a| intervals << a[1] - a[0] }
      # p intervals
      p (intervals.map(&:to_min).inject(0.0, :+) / intervals.length).floor
    end
    
    def print_data(function, hours)
      # "#{vehicles(4, 6)}-#{vehicles(7, 9)}-#{vehicles(10, 15)}-#{vehicles(16, 19)}-#{vehicles(21, 24)}"
      function(4, 6)
    end
    
    def print_razstanovka
      "#{vehicles(4, 6)}-#{vehicles(7, 9)}-#{vehicles(10, 15)}-#{vehicles(16, 19)}-#{vehicles(21, 24)}"
      # p print_data(vehicles, 'd')
    end
    
    def print_intervals
      "#{average_interval_between(4, 6)}-#{average_interval_between(7, 9)}-#{average_interval_between(10, 15)}-#{average_interval_between(16, 19)}-#{average_interval_between(21, 24)}"
    end
    
    def to_pdf(prawn_object)
      y_min_table = 516
      y_stops = 252
      
      to = 709
      from = 16
      hours = 21
      cell_width = (to - from) / hours

      # course_times = @course_list.flatten.map { |course| course.course_times }
      max_length = max_length @course_list
      height = 25 + max_length * 15
      max_height = y_min_table - y_stops
      y_table = (max_height - height) / 2 + height + y_stops
      prawn_object.stroke_horizontal_line from, to, :at => y_table
      hours.times do |count|
        x = from + count * cell_width
        prawn_object.stroke_vertical_line y_table, y_table - height, :at => x
      # p height
        prawn_object.bounding_box([x, y_table], :width => cell_width, :height => height) do
          # stroke_bounds
          prawn_object.move_down 5
          prawn_object.text "<b>#{count + 4}</b>", :inline_format => true, :align => :center
          prawn_object.move_down 7
          @course_list[count].each do |time|
            prawn_object.move_down 5
            time.to_pdf prawn_object
            # prawn_object.text time.as_minutes, :inline_format => true, :align => :center
          end
        end
      end
      prawn_object.stroke_horizontal_line from, to, :at => y_table - 20
      prawn_object.stroke_vertical_line y_table, y_table - height, :at => to
      
      # move_down 5
      average_times = average_course_times.map { |minutes| MyTime.minutes_to_min_sec minutes }
      slice_number = 0
      @station_list.each_slice(21) do |slice|
        prawn_object.bounding_box([260 * slice_number, y_stops], :width => 250) do
          # stroke_bounds
          slice.each_with_index do |station, index|
            station.to_pdf prawn_object, :left
            # prawn_object.text_box spirka, :width => 200, :height => 10, :overflow => :shrink_to_fit, :at => [0, prawn_object.cursor]
            # move_up 10
            prawn_object.text_box "+#{average_times[slice_number * 17 + index]}", :at => [201, prawn_object.cursor], :width => 50, :height => 10, :overflow => :shrink_to_fit
            prawn_object.move_down 13
          end
        end
        slice_number += 1
      end
      
      
      prawn_object.bounding_box([520, 250], :width => 250, :height => 100) do
        # prawn_object.stroke_bounds
        last_station_incomplete = @course_list.flatten.select { |course| course.incomplete? }[0]
        # p last_station_incomplete
        # p @course_list
        if last_station_incomplete
          prawn_object.text "<color rgb='ff0000'>ЗА ГАРАЖ</color> до спирка:", :inline_format => true
          prawn_object.move_down 5
          # p last_station_incomplete.course_times
          @station_list[last_station_incomplete.course_times.length - 1].to_pdf prawn_object, :center
          prawn_object.move_down 15
        end
        prawn_object.text "Брой коли на линия: #{vehicles}"
        prawn_object.move_down 5
        prawn_object.text "Разстановка: #{print_razstanovka}"
        prawn_object.move_down 5
        prawn_object.text "Интервали:  #{print_intervals}"
        prawn_object.move_down 15
        prawn_object.text "(4%6-7%9-10%15-16%19-21%24)", :align => :center
      end
      
      
    end
    
    def to_s
      "#@name\n#@station_list\n#@course_list"
    end
  end
  
  class Station
    def initialize(name, number)
      @name, @number = name, number
    end
    
    def to_pdf(prawn_object, align)
      prawn_object.text_box "#@number|#@name", :width => 200, :height => 10, :overflow => :shrink_to_fit, :at => [0, prawn_object.cursor], :align => align
    end
    
    def to_s
      "#@number #@name"
    end
  end
  
  class Line
    attr_accessor :number, :page
    
    def initialize(number, type, type_schedule, page = 0, directions = [])
      @number, @type, @directions, @type_schedule, @page = number, type, directions, type_schedule, page
      get_directions if @directions == []
      # @directions.map { |dir| puts dir }
    end
    
    def schedule_type_as_number
      types = {:weekdays => 0, :saturday => 1, :sunday => 2}
      type_number = types[@type_schedule]
      if @froms.length - 1 < type_number
        type_number = @froms.length - 1
      end
      type_number
    end
    
    def count_of_directions
      @directions.length
    end
    
    def change_type_of_schedule(type_number)
      @type_schedule = type_number
      get_directions
    end
    
    def get_directions
      p @document.class
      # @document = GTSchedule.parse "Line#{@number}.html" if @document.nil?
      @document = GTSchedule.parse "#@type/#@number" if @document.nil?
      
      @froms = []
      @document.css("h3 em").each { |date| @froms << date.text }
      # @document.css("h3").each { |date| @froms << date.text }
      # p @number, @froms
      @directions = []
      all_directions = @document.css(".schedule_view_direction_tabs li a span")
      number_of_directions_per_day = all_directions.length / @froms.length
      0.upto(number_of_directions_per_day - 1).each { |number| @directions[number] = Direction.new all_directions[number].text }
      type_schedule_number = schedule_type_as_number
      @directions.each_with_index do |direction, index|
        index_special = index + number_of_directions_per_day * type_schedule_number
        times = @document.css(".schedule_times")[index_special].css(".hours_cell")
        course_list = []
        times.each do |hour|
          hour_list = []
          hour.children.each do |time|
            time_as_string = time.text.strip
            unless time_as_string.empty?
              next if time_as_string == "\u00A0"
              #p time_as_string
              hour_list << Course.new(time_as_string, time['onclick'], time['class'] == 'incomplete_course')
            end
          end
          course_list << hour_list
        end
        direction.course_list = course_list
        # p direction.course_list
        
        # p direction.vehicles 7, 9
        stops = @document.css(".schedule_direction_view_course table")[index_special].css("th,td")
        station_list = []
        stops.each_slice(3) do |array|
          stop = array.first.text
          if stop.match /\A(.+) \| (\d+)/
            station_list << Station.new($1, $2)
          else
            next
          end
        end
        direction.station_list = station_list
        # direction.average_course_times.each { |minutes| MyTime.minutes_to_min_sec minutes }
      end
      # p @directions[0]
    end
    
    def to_pdf(prawn_object)
      type_name = GTSchedule.transport_type_name(@type)
      type_schedule_name = GTSchedule.schedule_name(@type_schedule)
      @directions.each_with_index do |direction, index|
        prawn_object.start_new_page(:layout => :landscape, :size => 'A4')
        prawn_object.move_up 10
        prawn_object.text "<b>#{type_name} линия #{number} - #{type_schedule_name}</b>", :inline_format => true, :align => :center, :size => 16
        prawn_object.move_down 5
        prawn_object.text "<b>#{direction.name}</b> <i>от #{@froms[schedule_type_as_number]}г.</i>", :inline_format => true, :align => :center
        direction.to_pdf prawn_object
        prawn_object.text_box "Стр. #{@page + index}", :at => [650, 10], :width => 100
      end
    end
    
    def to_s
      "#@type  #@number"
    end
  end
end


# sche = GT::GTSchedule.new [:weekdays, :saturday], :autobus => ['102', '204'], :tramway => ['5'], :metro => ['1']#, :autobus => ['1', '5', '204'], :trolleybus => ['2', '9'], :tramway => ['10']
# sche.to_pdf
GT::GTSchedule.new([:weekdays], :autobus => ['102', '204', '94'], :trolleybus => ['2', '9'], :tramway => ['10']).to_pdf
# GT::GTSchedule.new([:weekdays], :trolleybus => ['1', '2', '4', '5', '6', '7', '9', '11']).to_pdf
# GT::GTSchedule.parse
# GT::Course.new '8:55', "Raz.exec ('show_course', ['1c79b7fbb', '10,535,536,538,539,540,541,542,543,544,547,548,,,,,,,,,,,,,,,,,,,,,,,']); return false;"
# dir = GT::Direction.new("Test")
# dir.course_list = [[], ['5:00', '5:15', '5:30', '5:45'], ['6:00', '6:14', '6:28', '6:41', '6:54'], ['7:07', '7:19', '7:32', '7:45', '7:59'], ['8:13', '8:29', '8:46', '8:55'], ['9:04', '9:22', '9:31', '9:40', '9:58'], ['10:16', '10:25', '10:34', '10:52'], ['11:10', '11:28', '11:46'], ['12:04', '12:22', '12:40', '12:58'], ['13:16', '13:34', '13:52'], ['14:10', '14:28', '14:46'], ['15:03', '15:19', '15:34', '15:49'], ['16:03', '16:16', '16:29', '16:42', '16:55'], ['17:08', '17:21', '17:34', '17:47'], ['18:00', '18:13', '18:26', '18:39', '18:53'], ['19:07', '19:22', '19:38', '19:47', '19:56'], ['20:09', '20:21', '20:37', '20:47'], ['21:00', '21:13', '21:39'], ['22:04', '22:29', '22:55'], ['23:20', '23:45'], []]
# dir.average_interval_between 5, 6