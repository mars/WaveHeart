module WaveHeart
  module Source
    class Itunes < Base
      attr_reader :library_xml_filename
      
      def initialize(library_xml_filename = '~/Music/iTunes/iTunes Music Library.xml')
        super
        load_from_library(library_xml_filename)
      end

      def load_from_library(library_xml_filename = nil)
        @library_xml_filename = library_xml_filename if library_xml_filename
        @data = load_plist(File.read(File.expand_path(@library_xml_filename)))
        assert_valid_library_data!
        @data
      end

      private

      def assert_valid_library_data!
        raise ArgumentError, "iTunes Library.xml #{library_xml_filename.inspect} does not contain valid data." unless 
          Hash===data && data.size > 1
        version = data["Application Version"]
        matched, major_v, minor_v = /^(\d+)\.(\d+)/.match(version).to_a
        raise ArgumentError, "iTunes #{version} Library.xml is too old; major version > 10 is required." unless 
          major_v.to_i >= 10
      end

    end
  end
end
