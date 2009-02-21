require 'pathname'

module Ember
  class Template
    ##
    # Builds a processor that evaluates eRuby directives
    # in the given input according to the given options.
    #
    # This processor transforms the given input into an
    # executable Ruby program (provided by the #to_s() method)
    # which is then executed by the #render() method on demand.
    #
    # @param [Hash] options
    #   Additional method parameters, which are all optional:
    #
    #   [#to_s] :result_variable =>
    #     Name of the variable which stores the result of
    #     template evaluation during template evaluation.
    #
    #     The default value is "_erbout".
    #
    #   [String] :input_file =>
    #     Name of the file which contains the given input.  This
    #     is shown in stack traces when reporting error messages.
    #
    #     The default value is "(input)".
    #
    #   [Integer] :input_line =>
    #     Line number at which the given input exists in the :input_file.
    #     This is shown in stack traces when reporting error messages.
    #
    #     The default value is 1.
    #
    #   [boolean] :chomp_before =>
    #     Omit newline before each eRuby directive?
    #
    #     The default value is false.
    #
    #   [boolean] :strip_before =>
    #     Omit spaces and tabs before each eRuby directive?
    #
    #     The default value is false.
    #
    #   [boolean] :chomp_after =>
    #     Omit newline after each eRuby directive?
    #
    #     The default value is false.
    #
    #   [boolean] :strip_after =>
    #     Omit spaces and tabs after each eRuby directive?
    #
    #     The default value is false.
    #
    #   [boolean] :shorthand =>
    #     Treat lines beginning with "%" as eRuby directives.
    #
    #     The default value is false.
    #
    #   [boolean] :infer_end =>
    #     Add missing <% end %> statements based on indentation.
    #
    #     The default value is false.
    #
    #   [boolean] :unindent =>
    #     Unindent the content of eRuby blocks (everything
    #     between <% do %> ...  <% end %>) hierarchically.
    #
    #     The default value is false.
    #
    def initialize input, options = {}
      @options = options
      @program = compile(input.to_s)
    end

    ##
    # Builds a template whose body is read from the given source.
    #
    # If the source is a relative path, it will be resolved
    # relative to options[:input_file] if that is a valid path.
    #
    def self.load source, options = {}
      # resolve relative path to source file
      unless Pathname.new(source).absolute?
        if base = options[:input_file] and File.exist? base
          # target is relative to the file in
          # which the include directive exists
          source = File.join(File.dirname(base), source)
        end
      end

      input = File.read(source)
      options[:input_file] = source

      new input, options
    end

    ##
    # Returns the executable Ruby program that was assembled from the
    # eRuby template provided as input to the constructor of this class.
    #
    def to_s
      @program
    end

    ##
    # Returns the result of executing the Ruby program for this template
    # (provided by the #to_s() method) inside the given context binding.
    #
    def render(context = TOPLEVEL_BINDING)
      eval @program, context,
        @options[:input_file] || '(input)',
        @options[:input_line] || 1
    end

    private

    OPERATION_EVALUATE = '='
    OPERATION_COMMENT  = '#'
    OPERATION_BLOCK    = '|'
    OPERATION_INCLUDE  = '<'

    DIRECTIVE_HEAD     = '<%'
    DIRECTIVE_BODY     = '(?:(?# there is INTENTIONALLY nothing here because we want to match the "<%%>" base case )|[^%](?:.(?!<%))*?)'
    DIRECTIVE_TAIL     = '%>'

    NEWLINE            = '\r?\n'
    SPACING            = '[[:blank:]]*'

    CHUNKS_REGEXP = /#{
      '(%s?)(%s)%s(%s)%s(%s)(%s?)' % [
        NEWLINE,
        SPACING,
        DIRECTIVE_HEAD,
        DIRECTIVE_BODY,
        DIRECTIVE_TAIL,
        SPACING,
        NEWLINE,
      ]
    }/mo

    MARGIN_REGEXP = /^#{SPACING}(?=\S)/o

    ##
    # Transforms the given eRuby template into an executable Ruby program.
    #
    def compile template
      program = Program.new(@options[:result_variable] || :_erbout)

      # convert "% at beginning of line" usage into <% normal %> usage
        if @options[:shorthand]
          i = 0
          contents, directives =
            template.split(/(#{DIRECTIVE_HEAD}#{DIRECTIVE_BODY}#{DIRECTIVE_TAIL})/mo).
            partition { (i += 1) & 1 == 1 } # even/odd partition

          # only process the content; do not touch the directives
          # because they may contain code lines beginning with "%"
          contents.each do |content|
            # process unescaped directives
            content.gsub! %r/^(#{SPACING})(%[^%].*)$/o, '\1<\2%>'

            # unescape escaped directives
            content.gsub! %r/^(#{SPACING})(%)%/o, '\1\2'
          end

          template = contents.zip(directives).join
        end

      # compile the template into an executable Ruby program
        chunks = template.split(CHUNKS_REGEXP)

        inner_margins = []
        outer_margins = []

        until chunks.empty?
          before_content, before_newline, before_spacing,
          directive, after_spacing, after_newline = chunks.slice!(0, 6)

          if after_content = chunks.first # look ahead
            after_margin = after_content[MARGIN_REGEXP]
          else
            after_margin = nil
          end

          if directive
            operation = directive[0, 1]
            arguments = directive[1..-1]
          else
            operation = arguments = nil
          end

          # parser actions
            begin_block = lambda do
              inner_margins.push after_margin
              outer_margins.push before_spacing
            end

            end_block = lambda do
              outer_margins.pop
              inner_margins.pop
            end

            emit_end = lambda do
              program.code :end unless outer_margins.empty?
              end_block.call
            end

            infer_end = lambda do |line|
              if margin = line[MARGIN_REGEXP]
                outer_margins.select {|m| m >= margin }.each do
                  emit_end.call
                end
              end
            end

            unindent = lambda do |line|
              if margin = inner_margins.last
                line.sub! %r/^#{margin}/, ''
              end
            end

          if before_content
            lines = before_content.split(/^/)

            while line = lines.shift
              infer_end.call line if @options[:infer_end]
              unindent.call line if @options[:unindent]

              # unescape escaped directives
              line.gsub! '<%%', '<%'

              program.text line
              program.line unless lines.empty? and line !~ /\n$/
            end
          end

          if @options[:infer_end] and before_spacing and directive
            infer_end.call before_spacing + directive
          end

          if before_newline and not before_newline.empty?
            program.text before_newline unless @options[:chomp_before]
            program.line
          end

          ##
          # at this point, a new line of code has begun
          #

          if before_spacing and not before_spacing.empty?
            unindent.call before_spacing if @options[:unindent]

            if operation == OPERATION_EVALUATE or not @options[:strip_before]
              program.text before_spacing
            end
          end

          if operation and not operation.empty?
            case operation
            when OPERATION_EVALUATE
              program.expr arguments

            when OPERATION_COMMENT
              program.code directive.gsub(/\S/, ' ')

            when OPERATION_BLOCK
              arguments =~ /(\bdo\b)?\s*(\|.*?\|)?\s*\z/
              program.code "#{$`} #{$1 || 'do'} #{$2}"

              begin_block.call

            when OPERATION_INCLUDE
              program.code "::Ember::Template.load((#{arguments}), #{@options.inspect}).render(Kernel.binding)"

            else
              program.code directive

              case directive
              when /\bdo\b\s*(\|.*?\|)?\s*\z/  # TODO: add begin|while|until ...
                begin_block.call

              when /\A\s*end\b/
                end_block.call
              end
            end
          end

          if after_spacing and not after_spacing.empty?
            if operation == OPERATION_EVALUATE or not @options[:strip_after]
              program.text after_spacing
            end
          end

          if after_newline and not after_newline.empty?
            program.text after_newline unless @options[:chomp_after]
            program.line
          end
        end

        if @options[:infer_end]
          outer_margins.length.times do
            emit_end.call
          end
        else
          warn "There are at least #{outer_margins.length} missing '<% end %>' statements in the eRuby template." unless outer_margins.empty?
        end

      program.compile
    end

    class Program
      ##
      # Transforms this program into Ruby code which uses
      # the given variable name as the evaluation buffer.
      #
      def initialize result_variable
        @var   = result_variable
        @lines = [] # each line is composed of multiple statements
      end

      ##
      # Begins a new line in the program's source code.
      #
      def line
        @lines << []
      end

      ##
      # Schedules the given text to be inserted verbatim
      # into the evaluation buffer when this program is run.
      #
      def text value
        # combine adjacent statements to reduce code size
        if prev = insertion_point.last and prev.type == :text
          prev.value << value
        else
          statement :text, value
        end
      end

      ##
      # Schedules the given Ruby code to be
      # evaluated when this program is run.
      #
      def code value
        statement :code, value
      end

      ##
      # Schedules the given Ruby code to be evaluated and inserted
      # into the evaluation buffer when this program is run.
      #
      def expr value
        statement :expr, value
      end

      ##
      # Transforms this program into executable Ruby source code.
      #
      def compile
        '(%s ||= []; %s; %s.join)' % [
          @var,
          @lines.map {|l| l.map {|s| s.compile @var }.join('; ') }.join("\n"),
          @var,
        ]
      end

      private

      def insertion_point
        line if @lines.empty?
        @lines.last
      end

      def statement *args
        insertion_point << Statement.new(*args)
      end

      Statement = Struct.new :type, :value

      class Statement
        def compile result_variable
          case type
          when :code then value
          when :expr then "#{result_variable} << (#{value})"
          when :text then "#{result_variable} << #{value.inspect}"
          else            raise ArgumentError, type
          end
        end
      end
    end
  end
end