# encoding: utf-8
require 'nokogiri'
require 'prawn'
require 'open-uri'

module GT
  class GTSchedule
    def self.parse(html = nil)
      # new_html = open("http://schedules.sofiatraffic.bg/autobus/102").read  #IO.read(File.expand_path("../../test102.html"))
      new_html = IO.read(File.expand_path("../../test102.html"))
      document = Nokogiri::HTML::Document.parse(new_html, nil, "utf-8")
      
      #File.open(File.expand_path("../../test.txt")) { |file| new_html << file.read }
      froms = []
      document.css("h3 em").each { |date| froms << date.text }
      directions = []
      all_directions = document.css(".schedule_view_direction_tabs li a span")
      0.upto(all_directions.length / froms.length - 1).each { |number| directions[number] = Direction.new all_directions[number].text }
      directions.each_with_index do |direction, index|
        times = document.css(".schedule_times")[index].css(".hours_cell")
        time_list = []
        times.each do |hour|
          hour.children.each do |time|
            unless time.text.strip.empty?
              time_list << GTTime.new(time.text.strip, time['onclick'], time['class'] == 'incomplete_course')
            end
          end
        end
        direction.time_list = time_list
        stops = document.css(".schedule_direction_view_course table")[index]
      end
      #puts directions
      p document.css(".schedule_direction_view_course table")[0]
      line = Line.new '102', :autobus, directions
      
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
    
    def get_html_from(site)
      open(site).read
    end
    
  end
  
  class GTTime
    def initialize(time, course_times, incomplete = false)
      @time, @course_times, @incomplete = time, course_times, incomplete
    end
    
    def to_s
      "#@time"
      # p @time
    end
  end
  
  class Direction
    attr_accessor :time_list, :station_list

    def initialize(name, time_to = nil)
      @name = name
      @time_list = []
      @station_list = []
    end
    
    def to_s
      "#@name\n#@station_list\n#@time_list"
    end
  end
  
  class Station
    def initialize(name, number, time_to)
    end
  end
  
  class Line
    def initialize(number, type, directions)
    end
  end
end


GT::GTSchedule.parse