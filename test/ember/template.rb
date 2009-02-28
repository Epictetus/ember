require 'inochi/util/combinatorics'

class Array
  ##
  # Invokes the given block, passing in the result
  # of Array#join, for every possible combination.
  #
  def each_join
    raise ArgumentError unless block_given?

    permutations do |combo|
      yield combo.join
    end
  end
end

describe "A template" do
  it "should render single & multi-line comments as nothing" do
    WHITESPACE.each_join do |s|
      render("<%##{s}an#{s}eRuby#{s}comment#{s}%>").must_equal("")
    end
  end

  it "should render directives with whitespace-only bodies as nothing" do
    WHITESPACE.each_join do |s|
      OPERATIONS.each do |o|
        render("<%#{o}#{s}%>").must_equal("")
      end
    end
  end

  it "should render escaped directives in unescaped form" do
    render("<%%%>").must_equal("<%%>")

    render("<%% %>").must_equal("<% %>")

    lambda { render("<% %%>") }.
      must_raise(SyntaxError, "the trailing delimiter must not be unescaped")

    render("<%%%%>").must_equal("<%%%>",
      "the trailing delimiter must not be unescaped")

    WHITESPACE.each_join do |s|
      body = "#{s}an#{s}eRuby#{s}directive#{s}"

      OPERATIONS.each do |o|
        render("<%%#{o}#{body}%>").must_equal("<%#{o}#{body}%>")
      end
    end
  end

  it "should render whitespace surrounding vocal directives correctly" do
    o = rand.to_s
    i = "<%= #{o} %>"

    WHITESPACE.each_join do |s|
      (BLANK + NEWLINES).enumeration do |a, b|
        render("a#{a}#{s}#{i}#{b}#{s}b").must_equal("a#{a}#{s}#{o}#{b}#{s}b")
      end
    end
  end

  it "should render whitespace surrounding silent directives correctly" do
    i = '<%%>'
    o = ''

    SPACES.each_join do |s|
      NEWLINES.each do |n|
        # without preceding newline
        render("a#{s}#{i}#{n}#{s}b").must_equal("a#{s}#{o}#{n}#{s}b")

        # with preceding newline
        render("a#{n}#{s}#{i}#{s}b").must_equal("a#{o}#{s}b",
          "preceding newline and spacing must be removed for silent directives")
      end
    end
  end

  private

  def render input, options = {}
    Ember::Template.new(input, options).render
  end

  BLANK      = [''] # the empty string
  NEWLINES   = ["\n", "\r\n"]
  SPACES     = [' ', "\t"]
  WHITESPACE = SPACES + NEWLINES
  OPERATIONS = [nil, '=', '#', *WHITESPACE]
end

describe "A program compiled from a template" do
  it "should have the same number of lines, regardless of template options" do
    (BLANK + NEWLINES).each do |s|
      test_num_lines(s)
      test_num_lines("hello#{s}world")
    end
  end

  private

  ##
  # Checks that the given input template is compiled into the same
  # number of lines of Ruby code for all possible template options.
  #
  def test_num_lines input
    num_input_lines = count_lines(input)

    OPTIONS.each_combo do |options|
      template = Ember::Template.new(input, options)
      program = template.program

      count_lines(program).must_equal num_input_lines, "template program compiled with #{options.inspect} has different number of lines for input #{input.inspect}"
    end
  end

  ##
  # Counts the number of lines in the given string.
  #
  def count_lines string
    string.to_s.scan(/$/).length
  end

  OPTIONS = [:shorthand, :infer_end, :unindent]

  ##
  # Invokes the given block, passing in an options hash
  # for Ember::Template, for every possible combination.
  #
  def OPTIONS.each_combo
    raise ArgumentError unless block_given?

    combinations do |flags|
      yield Hash[ *flags.map {|f| [f, true] }.flatten ]
    end
  end
end
