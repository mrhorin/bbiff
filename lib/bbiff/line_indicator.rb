module Bbiff
  class LineIndicator
    def initialize(out = STDOUT)
      @width = 0
      @out = out
    end

    def set_line(str)
      clear
      if str[-1] == "\n"
        if str.rindex("\n") != str.size-1 || str.index("\n") < str.rindex("\n")
          raise 'multiline'
        end

        @out.print str
        @width = 0
      else
        @out.print str
        @width = mbswidth(str)
      end
    end

    def newline
      @out.print "\n"
      @width = 0
    end

    def clear
      @out.print "\r#{' ' * @width}\r"
      @width = 0
    end

    def puts(str)
      set_line(str)
      newline
    end

    private

    def mbswidth(str)
      Unicode::DisplayWidth.of(str)
    end
  end
end
