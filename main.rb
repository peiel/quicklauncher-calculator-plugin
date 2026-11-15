# frozen_string_literal: true
require 'json'

# Only arithmetic is parsed; input is never passed to eval or a shell.
class Calculator
  class Invalid < StandardError; end
  MAX_DIGITS = 512
  PRECISION = 12

  def initialize(expression)
    raise Invalid, '请输入公式，例如 calc (1 + 2) * 3。' unless expression.is_a?(String) && !expression.strip.empty?
    raise Invalid, '公式过长（最多 1024 字节）。' if expression.bytesize > 1024
    @expression = expression.tr('×÷', '*/')
    @position = 0
    @tokens = 0
    @depth = 0
  end

  def calculate
    result = add
    skip_space
    raise Invalid, '公式中包含无法识别的内容。' unless @position == @expression.length
    render(result)
  end

  private

  def skip_space
    @position += 1 while @position < @expression.length && @expression[@position].match?(/\s/)
  end

  def take(token)
    skip_space
    return false unless @expression[@position, token.length] == token
    @position += token.length
    @tokens += 1
    raise Invalid, '公式过于复杂。' if @tokens > 256
    true
  end

  def checked(value)
    if value.numerator.abs.to_s.length > MAX_DIGITS || value.denominator.to_s.length > MAX_DIGITS
      raise Invalid, '计算结果过大或精度超出限制。'
    end
    value
  end

  def add
    value = multiply
    loop do
      if take('+')
        value = checked(value + multiply)
      elsif take('-')
        value = checked(value - multiply)
      else
        return value
      end
    end
  end

  def multiply
    value = unary
    loop do
      skip_space
      if @expression[@position, 2] == '**'
        raise Invalid, '公式格式无效。'
      elsif take('*')
        value = checked(value * unary)
      elsif take('/')
        divisor = unary
        raise Invalid, '除数不能为零。' if divisor.zero?
        value = checked(value / divisor)
      elsif take('%')
        divisor = unary
        raise Invalid, '除数不能为零。' if divisor.zero?
        value = checked(value % divisor)
      else
        return value
      end
    end
  end

  def unary
    with_depth do
      if take('+')
        unary
      elsif take('-')
        -unary
      else
        power
      end
    end
  end

  def power
    value = primary
    if take('**') || take('^')
      exponent = unary
      raise Invalid, '指数必须是 -100 到 100 的整数。' unless exponent.denominator == 1 && exponent.abs <= 100
      raise Invalid, '零不能作为负指数的底数。' if value.zero? && exponent.negative?
      checked(value**exponent.to_i)
    else
      value
    end
  end

  def primary
    skip_space
    if take('(')
      value = with_depth { add }
      raise Invalid, '缺少右括号。' unless take(')')
      return value
    end
    match = /\G(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/.match(@expression, @position)
    raise Invalid, '公式格式无效。' unless match
    literal = match[0]
    raise Invalid, '数字过长。' if literal.length > 80
    exponent = literal.split(/[eE]/, 2)[1]
    raise Invalid, '数字指数必须在 -100 到 100 之间。' if exponent && (exponent.length > 4 || exponent.to_i.abs > 100)
    @position = match.end(0)
    @tokens += 1
    raise Invalid, '公式过于复杂。' if @tokens > 256
    checked(Rational(literal))
  rescue ArgumentError
    raise Invalid, '数字格式无效。'
  end

  def with_depth
    @depth += 1
    raise Invalid, '公式嵌套过深。' if @depth > 64
    yield
  ensure
    @depth -= 1
  end

  def render(value)
    # Round to 12 decimal places, half away from zero, without floating point.
    factor = 10**PRECISION
    scaled, remainder = (value.numerator.abs * factor).divmod(value.denominator)
    scaled += 1 if remainder * 2 >= value.denominator
    raise Invalid, '结果太小，超出显示精度。' if scaled.zero? && !value.zero?
    integer, fractional = scaled.divmod(factor)
    suffix = fractional.zero? ? '' : '.' + fractional.to_s.rjust(PRECISION, '0').sub(/0+\z/, '')
    sign = value.negative? && !scaled.zero? ? '-' : ''
    output = sign + integer.to_s + suffix
    raise Invalid, '结果过长（最多 200 个字符）。' if output.length > 200
    output
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    request = JSON.parse(STDIN.gets || '')
    raise Calculator::Invalid, '不支持的请求。' unless request.is_a?(Hash) && request['version'] == 1
    value = Calculator.new(request['arguments']).calculate
    response = { version: 1, action: 'copyAndShow', text: value }
  rescue JSON::ParserError, Calculator::Invalid => e
    response = { version: 1, action: 'error', text: e.is_a?(JSON::ParserError) ? '请求格式无效。' : e.message }
  end
  STDOUT.write(JSON.generate(response) + "\n")
end
