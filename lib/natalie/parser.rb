require 'strscan'

module Natalie
  class Parser
    def initialize(code_str)
      @code_str = code_str.strip + "\n"
      @scanner = StringScanner.new(@code_str)
    end

    def ast
      ast = []
      while !@scanner.eos? && (e = expr)
        ast << e
        raise "expected ; or newline; got: #{@scanner.inspect}" unless @scanner.skip(/;+|\n+/)
      end
      ast
    end

    def expr
      assignment || message || number || string || method
    end

    def assignment
      if @scanner.check(/[a-z]+\s*=/)
        id = identifier
        @scanner.skip(/\s*=\s*/)
        [:assign, id, expr]
      end
    end

    def identifier
      @scanner.scan(/[a-z][a-z0-9_]*/)
    end

    def number
      if (n = @scanner.scan(/\d+/))
        [:number, n]
      end
    end

    def string
      if (s = @scanner.scan(/'[^']*'|"[^"]*"/))
        [:string, s[1...-1]]
      end
    end

    def method
      if @scanner.scan(/def /)
        @scanner.skip(/\s*/)
        name = identifier
        raise 'expected method name after def' unless name
        @scanner.skip(/[;\n]*/)
        body = []
        until @scanner.check(/\s*end[;\n\s]/)
          body << expr
          raise 'expected ; or newline' unless @scanner.skip(/;+|\n+/)
        end
        @scanner.skip(/\s*end/)
        [:def, name, [], body]
      end
    end

    IDENTIFIER = /[a-z][a-z0-9_]*[\!\?=]?/i

    def identifier
      @scanner.scan(IDENTIFIER)
    end

    def bare_word_message
      if (id = identifier)
        [:send, 'self', id, []]
      end
    end

    OPERATOR = /<<?|>>?|<=>|<=|=>|===?|\!=|=~|\!~|\||\^|&|\+|\-|\*\*?|\/|%/

    def message
      explicit_message || implicit_message
    end

    def explicit_message
      start = @scanner.pos
      if @explicit_message_recurs
        receiver = implicit_message || string || number
      else
        @explicit_message_recurs = true
        receiver = expr
      end
      @explicit_message_recurs = false
      if receiver
        if @scanner.check(/\s*\.?\s*#{OPERATOR}\s*/)
          @scanner.skip(/\s*\.?\s*/)
          message = @scanner.scan(OPERATOR)
          args = args_with_parens || args_without_parens
          raise 'expected expression after operator' unless args
          [:send, receiver, message, args]
        elsif @scanner.check(/\s*\.\s*/)
          @scanner.skip(/\s*\.\s*/)
          message = identifier
          raise 'expected method call after dot' unless message
          args = args_with_parens || args_without_parens || []
          [:send, receiver, message, args]
        else
          receiver
        end
      else
        @scanner.pos = start
        nil
      end
    end

    def args_with_parens
      if @scanner.check(/[ \t]*\(\s*/)
        @scanner.skip(/[ \t]*\(\s*/)
        args = [expr]
        while @scanner.skip(/[ \t]*,\s*/)
          args << expr
        end
        raise 'expected )' unless @scanner.skip(/\s*\)/)
        args
      end
    end

    def args_without_parens
      if @scanner.check(/[ \t]+/)
        @scanner.skip(/[ \t]+/)
        args = [expr]
        while @scanner.skip(/[ \t]*,\s*/)
          args << expr
        end
        args
      end
    end

    def implicit_message
      if (id = identifier)
        args = args_with_parens || args_without_parens || []
        [:send, 'self', id, args]
      end
    end
  end
end
