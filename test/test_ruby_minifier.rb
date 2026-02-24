# frozen_string_literal: true

require "test_helper"
require "kureha"

class TestKureha < Minitest::Test
  def setup
    @minifier = Kureha::Minifier.new
  end

  def test_that_it_has_a_version_number
    refute_nil ::Kureha::VERSION
  end

  def test_basic_minification
    code = <<~RUBY
      def hello
        puts "Hello, World!"
      end
    RUBY

    expected = "def hello;puts\"Hello, World!\";end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_operator_precedence
    code = <<~RUBY
      x = 1 + 2 * 3
      y = (a + b) * (c - d)
    RUBY

    expected = "x=1+2*3;y=(a+b)*(c-d)"
    assert_equal expected, @minifier.minify(code)
  end

  def test_string_interpolation
    code = <<~RUBY
      name = "John"
      puts "Hello, \#{name}!"
    RUBY

    expected = 'name="John";puts"Hello, #{name}!"'
    assert_equal expected, @minifier.minify(code)
  end

  def test_method_call
    code = <<~RUBY
      object.method(arg1, arg2)
      puts(value)
    RUBY

    expected = "object.method(arg1,arg2);puts value"
    assert_equal expected, @minifier.minify(code)
  end

  def test_block
    code = <<~RUBY
      array.each do |item|
        process(item)
      end
    RUBY

    expected = "array.each do|item|;process(item);end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_class_definition
    code = <<~RUBY
      class Example
        def initialize(name)
          @name = name
        end
      end
    RUBY

    expected = "class Example;def initialize(name);@name=name;end;end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_module_definition
    code = <<~RUBY
      module Example
        def initialize(name)
          @name = name
        end
      end
    RUBY

    expected = "module Example;def initialize(name);@name=name;end;end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_constant_definition
    code = <<~RUBY
      CONST = "example"
      class Example2
        OTHER_CONST = "other"
      end
    RUBY

    expected = "CONST=\"example\";class Example2;OTHER_CONST=\"other\";end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_token_structure
    code = "puts 'hello'"
    result = Prism.lex(code)
    tokens = result.value

    assert_equal 5, tokens.length
    assert_equal :IDENTIFIER, tokens[0][0].type
    assert_equal "puts", tokens[0][0].value
  end

  def test_comment_removal
    code = "# This is a comment\ndef hello # inline comment\n  puts 'world' # another comment\nend\n"
    expected = "def hello;puts\"world\";end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_whitespace_optimization
    code = "def  calculate(x,   y)\n  \n  result   =  x  +  y\n\n  return    result\nend\n"
    expected = "def calculate(x,y);result=x+y;return result;end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_complex_code_minification
    code = <<~RUBY
      class Calculator
        def add(a, b)  # 足し算
          a + b        # 結果を返す
        end

        def multiply(a, b)
          # 掛け算を実行
          a * b
        end
      end

      calc = Calculator.new
      result = calc.add(2, 3)      # 2 + 3
      result2 = calc.multiply(4, 5) # 4 * 5
    RUBY

    expected = "class Calculator;def add(a,b);a+b;end;def multiply(a,b);a*b;end;end;calc=Calculator.new;result=calc.add(2,3);result2=calc.multiply(4,5)"
    assert_equal expected, @minifier.minify(code)
  end

  def test_class_with_instance_variables_and_string_interpolation
    code = <<~RUBY
      class Calculator
        def initialize(name = "Simple Calculator")
          @name = name
          @history = []
        end

        def add(a, b)
          result = a + b
          @history << { operation: "add", result: result }
          result
        end

        def multiply(x, y)
          # Multiply two numbers
          result = x * y
          @history << { operation: "multiply", result: result }
          result
        end

        def show_history
          puts "Calculator History:"
          @history.each do |record|
            puts "\#{record[:operation]}: \#{record[:result]}"
          end
        end
      end

      # Create a new calculator
      calc = Calculator.new("My Calculator")
      result1 = calc.add(10, 20)
      result2 = calc.multiply(5, 6)
      puts "Addition result: \#{result1}"
      puts "Multiplication result: \#{result2}"
      calc.show_history
    RUBY

    expected = 'class Calculator;def initialize(name="Simple Calculator");@name=name;@history=[];end;def add(a,b);result=a+b;@history<<{operation:"add",result:result};result;end;def multiply(x,y);result=x*y;@history<<{operation:"multiply",result:result};result;end;def show_history;puts"Calculator History:";@history.each do|record|;puts"#{record[:operation]}: #{record[:result]}";end;end;end;calc=Calculator.new("My Calculator");result1=calc.add(10,20);result2=calc.multiply(5,6);puts"Addition result: #{result1}";puts"Multiplication result: #{result2}";calc.show_history'
    assert_equal expected, @minifier.minify(code)
  end

  def test_complex_string_interpolation
    code = <<~RUBY
      name = "John"
      age = 30
      puts "Name: \#{name}, Age: \#{age}"
      puts "Hash access: \#{hash[:key]}"
      puts "Nested hash: \#{nested[:key][:subkey]}"
      puts "Method call: \#{object.method}"
      puts "Multiple: \#{first} \#{second}"
    RUBY

    expected = 'name="John";age=30;puts"Name: #{name}, Age: #{age}";puts"Hash access: #{hash[:key]}";puts"Nested hash: #{nested[:key][:subkey]}";puts"Method call: #{object.method}";puts"Multiple: #{first} #{second}"'
    assert_equal expected, @minifier.minify(code)
  end

  def test_complex_block_structures
    code = <<~RUBY
      array.each do |item|
        if item.valid?
          process(item)
        end
      end

      hash.each do |key, value|
        puts "\#{key}: \#{value}"
      end

      (1..10).each do |i|
        puts i if i.even?
      end
    RUBY

    expected = "array.each do|item|;process(item) if item.valid?;end;hash.each do|key,value|;puts\"\#{key}: \#{value}\";end;(1..10).each do|i|;puts i if i.even?;end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_operator_spacing
    code = <<~RUBY
      x = 1 + 2 * 3
      y = (a + b) * (c - d)
      z = x == y && a != b
      result = value || default
    RUBY

    expected = "x=1+2*3;y=(a+b)*(c-d);z=x==y&&a!=b;result=value||default"
    assert_equal expected, @minifier.minify(code)
  end

  def test_edge_cases
    code = <<~RUBY
      # Empty block
      def empty
      end

      # Single line block
      def single_line; puts "hello"; end

      # Multiple semicolons
      x = 1;;; y = 2

      # Complex string interpolation
      puts "\#{hash[:key]}: \#{value}"

      # Nested blocks
      outer do
        inner do
          puts "nested"
        end
      end
    RUBY

    expected = 'def empty;;end;def single_line;puts"hello";end;x=1;y=2;puts"#{hash[:key]}: #{value}";outer do;inner do;puts"nested";end;end'
    assert_equal expected, @minifier.minify(code)
  end

  def test_if_statement_minification
    code = <<~RUBY
      if condition
        do_something
      else
        do_other_thing
      end
    RUBY

    expected = <<~RUBY
      if condition;do_something;else;do_other_thing;end
    RUBY

    assert_equal expected.strip, @minifier.minify(code)
  end

  def test_invalid_code
    code = "def invalid_syntax"
    assert_raises(Kureha::ParseError) do
      @minifier.minify(code)
    end
  end

  def test_magic_comments
    code = <<~RUBY
      # frozen_string_literal: true
      # encoding: utf-8
      
      puts "Hello"
    RUBY

    result = @minifier.minify(code)
    assert result.start_with?("# frozen_string_literal: true\n# encoding: utf-8\n")
    assert result.include?('puts"Hello"')
  end

  def test_require_statements
    code = <<~RUBY
      require 'json'
      require_relative 'helper'
      puts "loaded"
    RUBY

    expected = 'require "json";require_relative "helper";puts"loaded"'
    assert_equal expected, @minifier.minify(code)
  end

  def test_unless_statement
    code = <<~RUBY
      puts "error" unless valid
      
      unless condition
        do_something
      else
        do_other
      end
    RUBY

    expected = 'puts"error" unless valid;unless condition;do_something;else;do_other;end'
    assert_equal expected, @minifier.minify(code)
  end

  def test_return_statement
    code = <<~RUBY
      def calculate
        return 42
      end
      
      def early_return
        return if error
        process
      end
    RUBY

    expected = "def calculate;return 42;end;def early_return;return if error;process;end"
    assert_equal expected, @minifier.minify(code)
  end

  def test_case_when_statement
    code = <<~RUBY
      case value
      when 1
        puts "one"
      when 2, 3
        puts "two or three"
      else
        puts "other"
      end
    RUBY

    expected = 'case value;when 1;puts"one";when 2,3;puts"two or three";else;puts"other";end'
    assert_equal expected, @minifier.minify(code)
  end

  def test_regular_expressions
    code = <<~RUBY
      text =~ /hello/i
      match = /world/.match(text)
    RUBY

    expected = "text=~/hello/i;match=/world/.match(text)"
    assert_equal expected, @minifier.minify(code)
  end

  def test_super_keyword
    code = <<~RUBY
      def method_with_super
        super
        super(arg)
      end
    RUBY

    expected = "def method_with_super;super;super(arg);end"
    assert_equal expected, @minifier.minify(code)
  end

  private

  def capture_output
    original_stdout = $stdout
    output = StringIO.new
    $stdout = output
    yield
    output.string
  ensure
    $stdout = original_stdout
  end
end
