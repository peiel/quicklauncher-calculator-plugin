# frozen_string_literal: true
require 'minitest/autorun'
require 'json'
require 'open3'
require_relative '../main'

class CalculatorTest < Minitest::Test
  def calculate(input)
    Calculator.new(input).calculate
  end

  def test_arithmetic_and_precedence
    assert_equal '7', calculate('1+2*3')
    assert_equal '9', calculate('(1 + 2) × 3')
    assert_equal '-4', calculate('-2^2')
    assert_equal '0.25', calculate('2^-2')
    assert_equal '512', calculate('2^3^2')
    assert_equal '2.5', calculate('12.5%5')
    assert_equal '300', calculate('1e2 + 2E2')
    assert_equal '0.333333333333', calculate('1/3')
    assert_equal '-0.666666666667', calculate('-2/3')
  end

  def test_invalid_and_unsafe_expressions_are_rejected
    ['', '1/0', '0^-1', '2^101', '1e999999', '1 +', '1; system("open")', '`id`', "1\n2", '1e-100', '(' * 100 + '1' + ')' * 100].each do |expression|
      assert_raises(Calculator::Invalid, expression) { calculate(expression) }
    end
  end

  def test_json_protocol_and_errors
    file = File.expand_path('../main.rb', __dir__)
    out, status = Open3.capture2('/usr/bin/ruby', file, stdin_data: JSON.generate(version: 1, arguments: '12 ÷ 4'))
    assert status.success?
    assert_equal({ 'version' => 1, 'action' => 'copyAndShow', 'text' => '3' }, JSON.parse(out))
    out, status = Open3.capture2('/usr/bin/ruby', file, stdin_data: JSON.generate(version: 1, arguments: '1/0'))
    assert status.success?
    assert_equal 'error', JSON.parse(out)['action']
  end

  def test_passive_expression_uses_same_json_protocol
    file = File.expand_path('../main.rb', __dir__)
    out, status = Open3.capture2('/usr/bin/ruby', file, stdin_data: JSON.generate(version: 1, arguments: '1+1'))
    assert status.success?
    assert_equal({ 'version' => 1, 'action' => 'copyAndShow', 'text' => '2' }, JSON.parse(out))
  end

  def test_result_length_limit_matches_host
    assert_equal 200, calculate('10^100 * 10^99').length
    assert_equal 200, calculate('-10^100 * 10^98').length
    assert_equal '结果过长（最多 200 个字符）。', assert_raises(Calculator::Invalid) { calculate('10^100 * 10^100') }.message
    assert_equal '结果过长（最多 200 个字符）。', assert_raises(Calculator::Invalid) { calculate('-10^100 * 10^99') }.message
  end
end
