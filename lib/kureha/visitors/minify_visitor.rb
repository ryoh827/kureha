require "prism"

module Kureha
  module Visitors
    class MinifyVisitor < Prism::Visitor
      OPERATORS = %w[+ - * / % ** & | ^ << >> && || < <= > >= == === != =~ !~ <=>].freeze
      NEEDS_PARENS = %w[* / %].freeze

      OPERATOR_PRECEDENCE = {
        "**" => 16,
        "*" => 15, "/" => 15, "%" => 15,
        "+" => 14, "-" => 14,
        "==" => 9, "!=" => 9, ">" => 9, "<" => 9, ">=" => 9, "<=" => 9,
        "&&" => 8,
        "||" => 7
      }.freeze

      def initialize
        @result = []
      end

      def visit(node)
        super
        @result.join.force_encoding("UTF-8")
      end

      def visit_program_node(node)
        visit(node.statements)
      end

      def visit_statements_node(node)
        last_index = node.body.length - 1
        node.body.each_with_index do |stmt, i|
          visit(stmt)
          unless i == last_index || @current_parent.class.name.end_with?("ParenthesesNode")
            @result << ";"
          end
        end
      end

      def visit_def_node(node)
        @result << "def "
        @result << node.name
        if node.parameters
          @result << "("
          visit(node.parameters)
          @result << ")"
        end
        @result << ";"
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_module_node(node)
        @result << "module "
        visit(node.constant_path)
        @result << ";"
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_class_node(node)
        @result << "class "
        visit(node.constant_path)
        if node.superclass
          @result << "<"
          visit(node.superclass)
        end
        @result << ";"
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_constant_path_node(node)
        if node.parent
          visit(node.parent)
          @result << "::"
        elsif node.delimiter_loc
          @result << "::"
        end
        @result << node.name
      end

      def visit_constant_read_node(node)
        @result << node.name
      end

      def visit_constant_write_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_string_node(node)
        @result << node.unescaped.dump
      end

      def visit_integer_node(node)
        @result << node.value.to_s
      end

      def visit_float_node(node)
        @result << node.value.to_s
      end

      def visit_true_node(_)
        @result << "true"
      end

      def visit_false_node(_)
        @result << "false"
      end

      def visit_nil_node(_)
        @result << "nil"
      end

      def visit_call_node(node)
        if node.receiver
          if node.name.to_s == "[]"
            visit(node.receiver)
            @result << "["
            visit(node.arguments) if node.arguments
            @result << "]"
            return
          end

          if OPERATORS.include?(node.name.to_s)
            if node.receiver.class.name.end_with?("ParenthesesNode")
              visit(node.receiver)
            else
              receiver_needs_parens = needs_parens?(node.receiver, node)
              @result << "(" if receiver_needs_parens
              visit(node.receiver)
              @result << ")" if receiver_needs_parens
            end

            @result << node.name.to_s

            if node.arguments && !node.arguments.arguments.empty?
              arg = node.arguments.arguments.first
              if arg.class.name.end_with?("ParenthesesNode")
                visit(arg)
              else
                arg_needs_parens = needs_parens?(arg, node)
                @result << "(" if arg_needs_parens
                visit(arg)
                @result << ")" if arg_needs_parens
              end
            end
          else
            visit(node.receiver)
            @result << "."
            @result << node.name
          end
        else
          @result << node.name.to_s
        end

        if node.arguments && !node.arguments.arguments.empty? && !OPERATORS.include?(node.name.to_s)
          needs_parens = !%w[puts print p require require_relative].include?(node.name.to_s)
          if needs_parens
            @result << "("
            visit(node.arguments)
            @result << ")"
          elsif %w[require require_relative].include?(node.name.to_s)
            # Special handling for require/require_relative
            @result << " "
            visit(node.arguments)
          else
            first_arg = node.arguments.arguments.first
            if !first_arg.class.name.end_with?("StringNode") && !first_arg.class.name.end_with?("InterpolatedStringNode")
              @result << " "
            end
            visit(node.arguments)
          end
        end

        if node.block
          visit(node.block)
        end
      end

      def visit_arguments_node(node)
        node.arguments.each_with_index do |arg, i|
          visit(arg)
          @result << "," unless i == node.arguments.length - 1
        end
      end

      def visit_parameters_node(node)
        params = []
        params.concat(node.requireds) if node.requireds
        params.concat(node.optionals) if node.optionals
        params.each_with_index do |param, i|
          visit(param)
          @result << "," unless i == params.length - 1
        end
      end

      def visit_optional_parameter_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_local_variable_read_node(node)
        @result << node.name
      end

      def visit_local_variable_write_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_instance_variable_read_node(node)
        @result << node.name
      end

      def visit_instance_variable_write_node(node)
        @result << node.name
        @result << "="
        visit(node.value)
      end

      def visit_block_node(node)
        @result << " do"
        if node.parameters
          @result << "|"
          visit(node.parameters)
          @result << "|"
        end
        if node.body&.body&.any?
          @result << ";"
        end
        visit(node.body) if node.body
        @result << ";end"
      end

      def visit_block_parameters_node(node)
        parameters = []
        if node.parameters
          parameters.concat(node.parameters.requireds) if node.parameters.respond_to?(:requireds)
          parameters.concat(node.parameters) if !node.parameters.respond_to?(:requireds)
        end
        parameters.concat(node.locals) if node.locals
        parameters.each_with_index do |param, i|
          visit(param)
          @result << "," unless i == parameters.length - 1
        end
      end

      def visit_required_parameter_node(node)
        @result << node.name
      end

      def visit_local_variable_target_node(node)
        @result << node.name
      end

      def visit_binary_node(node)
        if needs_parens?(node, @current_parent)
          @result << "("
          with_parent(node) do
            visit(node.left)
            @result << node.operator
            visit(node.right)
          end
          @result << ")"
        else
          with_parent(node) do
            visit(node.left)
            @result << node.operator
            visit(node.right)
          end
        end
      end

      def visit_if_node(node)
        if !node.subsequent && node.statements && node.statements.body.length == 1
          visit(node.statements)
          @result << " if "
          visit(node.predicate)
        else
          @result << "if "
          visit(node.predicate)
          @result << ";"
          visit(node.statements) if node.statements
          if node.subsequent
            @result << ";else;"
            visit(node.subsequent)
          end
          @result << ";end"
        end
      end

      def visit_unless_node(node)
        if !node.else_clause && node.statements && node.statements.body.length == 1
          visit(node.statements)
          @result << " unless "
          visit(node.predicate)
        else
          @result << "unless "
          visit(node.predicate)
          @result << ";"
          visit(node.statements) if node.statements
          if node.else_clause
            @result << ";else;"
            visit(node.else_clause)
          end
          @result << ";end"
        end
      end

      def visit_array_node(node)
        @result << "["
        node.elements.each_with_index do |elem, i|
          visit(elem)
          @result << "," unless i == node.elements.length - 1
        end
        @result << "]"
      end

      def visit_parentheses_node(node)
        @result << "("
        visit(node.body)
        @result << ")"
      end

      def visit_hash_node(node)
        @result << "{"
        node.elements.each_with_index do |elem, i|
          visit(elem)
          @result << "," unless i == node.elements.length - 1
        end
        @result << "}"
      end

      def visit_assoc_node(node)
        if node.key.class.name.end_with?("SymbolNode")
          @result << node.key.value
        else
          visit(node.key)
        end
        @result << ":"
        visit(node.value)
      end

      def visit_string_interpolation_node(node)
        @result << "\""
        node.parts.each do |part|
          case part
          when Prism::StringNode
            @result << part.unescaped.dump[1...-1]
          when Prism::EmbeddedStatementsNode
            @result << "\#{"
            visit(part.statements)
            @result << "}"
          end
        end
        @result << "\""
      end

      def visit_index_node(node)
        visit(node.receiver)
        @result << "["
        visit(node.index)
        @result << "]"
      end

      def visit_range_node(node)
        visit(node.left)
        @result << ".."
        visit(node.right)
      end

      def visit_embedded_statements_node(node)
        visit(node.statements)
      end

      def visit_symbol_node(node)
        if node.value.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/)
          @result << ":"
          @result << node.value
        else
          @result << node.value.inspect
        end
      end

      def visit_interpolated_string_node(node)
        @result << "\""
        node.parts.each do |part|
          case part
          when Prism::StringNode
            @result << part.unescaped.dump[1...-1]
          else
            @result << "\#{"
            visit(part)
            @result << "}"
          end
        end
        @result << "\""
      end

      def visit_and_node(node)
        if node.left.class.name.end_with?("ParenthesesNode")
          visit(node.left)
        else
          left_needs_parens = needs_parens?(node.left, node)
          @result << "(" if left_needs_parens
          visit(node.left)
          @result << ")" if left_needs_parens
        end

        @result << "&&"

        if node.right.class.name.end_with?("ParenthesesNode")
          visit(node.right)
        else
          right_needs_parens = needs_parens?(node.right, node)
          @result << "(" if right_needs_parens
          visit(node.right)
          @result << ")" if right_needs_parens
        end
      end

      def visit_or_node(node)
        if node.left.class.name.end_with?("ParenthesesNode")
          visit(node.left)
        else
          left_needs_parens = needs_parens?(node.left, node)
          @result << "(" if left_needs_parens
          visit(node.left)
          @result << ")" if left_needs_parens
        end

        @result << "||"

        if node.right.class.name.end_with?("ParenthesesNode")
          visit(node.right)
        else
          right_needs_parens = needs_parens?(node.right, node)
          @result << "(" if right_needs_parens
          visit(node.right)
          @result << ")" if right_needs_parens
        end
      end

      def visit_return_node(node)
        @result << "return"
        if node.arguments
          @result << " "
          visit(node.arguments)
        end
      end

      def visit_break_node(node)
        @result << "break"
        if node.arguments
          @result << " "
          visit(node.arguments)
        end
      end

      def visit_yield_node(node)
        @result << "yield"
        if node.arguments && !node.arguments.arguments.empty?
          @result << "("
          visit(node.arguments)
          @result << ")"
        end
      end

      def visit_begin_node(node)
        @result << "begin"
        if node.statements && !node.statements.body.empty?
          @result << ";"
          visit(node.statements)
        end
        if node.rescue_clause
          @result << ";"
          visit(node.rescue_clause)
        end
        if node.else_clause
          @result << ";else;"
          visit(node.else_clause)
        end
        if node.ensure_clause
          @result << ";"
          visit(node.ensure_clause)
        end
        @result << ";end"
      end

      def visit_else_node(node)
        visit(node.statements) if node.statements
      end

      def visit_ensure_node(node)
        @result << "ensure"
        if node.statements && !node.statements.body.empty?
          @result << ";"
          visit(node.statements)
        end
      end

      def visit_case_node(node)
        @result << "case "
        visit(node.predicate) if node.predicate
        @result << ";"
        node.conditions.each do |condition|
          visit(condition)
        end
        if node.else_clause
          @result << "else;"
          visit(node.else_clause)
          @result << ";"
        end
        @result << "end"
      end

      def visit_when_node(node)
        @result << "when "
        node.conditions.each_with_index do |cond, i|
          visit(cond)
          @result << "," unless i == node.conditions.length - 1
        end
        @result << ";"
        visit(node.statements) if node.statements
        @result << ";"
      end

      def visit_regular_expression_node(node)
        # Use original source to preserve flags correctly
        source = node.location.slice
        @result << source
      end

      def visit_match_last_line_node(node)
        @result << "=~"
        visit(node.call)
      end

      def visit_super_node(node)
        @result << "super"
        if node.arguments && !node.arguments.arguments.empty?
          @result << "("
          visit(node.arguments)
          @result << ")"
        end
        visit(node.block) if node.block
      end

      def visit_forwarding_super_node(node)
        @result << "super"
        visit(node.block) if node.block
      end

      private

      def needs_parens?(node, parent = nil)
        return false unless parent

        if parent.class.name.end_with?("AndNode", "OrNode")
          if node.class.name.end_with?("AndNode", "OrNode")
            return false if (parent.class.name.end_with?("AndNode") && node.class.name.end_with?("AndNode")) ||
              (parent.class.name.end_with?("OrNode") && node.class.name.end_with?("OrNode"))
            parent_precedence = parent.class.name.end_with?("AndNode") ? 8 : 7
            node_precedence = node.class.name.end_with?("AndNode") ? 8 : 7
            return node_precedence <= parent_precedence
          end
        end

        if parent.respond_to?(:operator)
          if node.class.name.end_with?("CallNode")
            return true if NEEDS_PARENS.include?(parent.operator)
            return false
          end

          if node.respond_to?(:operator)
            return false if node.operator == parent.operator && %w[+ * && ||].include?(parent.operator)

            return true if NEEDS_PARENS.include?(node.operator)

            node_precedence = OPERATOR_PRECEDENCE[node.operator] || 0
            parent_precedence = OPERATOR_PRECEDENCE[parent.operator] || 0

            if node_precedence <= parent_precedence
              return false if node.operator == "**" && parent.operator == "**" && parent.right == node
              return true
            end
          end
        end

        return true if node.class.name.end_with?("ParenthesesNode")

        false
      end

      def is_control_structure?(node)
        node.class.name.end_with?("IfNode", "UnlessNode", "WhileNode", "UntilNode", "CaseNode", "ForNode", "BeginNode", "RescueNode", "EnsureNode")
      end

      def is_modifier_form?(node)
        # if modifier form has only one statement and no else clause
        if node.class.name.end_with?("IfNode")
          return node.statements&.body&.length == 1 && !node.subsequent
        elsif node.class.name.end_with?("UnlessNode")
          return node.statements&.body&.length == 1 && !node.else_clause
        end
        false
      end

      def with_parent(parent)
        old_parent = @current_parent
        @current_parent = parent
        yield
      ensure
        @current_parent = old_parent
      end
    end
  end
end
