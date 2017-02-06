
require 'claide'
require 'json'
require 'fileutils'

class String

  def xor_unpacked(second)
    valueBytes = self.unpack('C*')
    keyBytes = second.unpack('C*')
    keyIndex = 0

    out = valueBytes.map { |x|
      value = x ^ keyBytes[keyIndex]
      keyIndex += 1

      if keyIndex == keyBytes.count then
          keyIndex = 0
      end

      value
    }

    return out
  end
end

class CodeWriter

  def initialize(file)
    @file = file
    @intendation_level = 0
  end

  def intend
    @intendation_level += 1
  end

  def unintend
    @intendation_level -= 1
  end

  def write(string)
    @file.write "\t" * @intendation_level
    @file.write(string)
  end

  def writeln(string = nil)
    write(string) unless string.nil?
    @file.write("\n")
  end

  def intending
    intend
    yield
    unintend
  end
end

class CodeGenerator
  def initialize(name, output, xor_key)
    @name = name
    @output = output
    @xor_key = xor_key
  end

  def generate(keys)
    # does nothing
  end

  def prepare_path(filename, extension)
    output_is_dir = File.directory?(@output)
    output_dir = output_is_dir ? @output : File.dirname(@output)

    FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)

    filepath = File.join(output_dir, filename + extension)
    FileUtils.remove filepath unless !File.exists?(filepath)

    FileUtils.touch(filepath)

    filepath
  end
end

class SwiftCodeGenerator < CodeGenerator
  def generate(keys)
    filepath = prepare_path(@name, '.swift')

    file = File.open(filepath, "a+") { |file|
        writer = CodeWriter.new(file)

        prepare_header(writer)
        writer.writeln
        generate_string_encoding(writer)
        writer.writeln
        generate_keys_struct(keys, writer)
    }
  end

  private

  def prepare_header(writer)
    writer.writeln("// Generated automatically. Do not modify.\n")
    writer.writeln("import Foundation")
  end

  def generate_string_encoding(writer)
    writer.writeln('fileprivate extension String {')

    writer.intending {
      writer.writeln('func encoding(_ key: String) -> String {')
      writer.intending {
        writer.writeln('var valueData = data(using: .ascii)!')
        writer.writeln('var keyData = key.data(using: .ascii)!')
        writer.writeln('var keyIndex = 0')
        writer.writeln('for i in 0..<valueData.count {')
        writer.intending {
          writer.writeln('valueData[i] = valueData[i] ^ keyData[keyIndex]')
          writer.writeln('keyIndex += 1')
          writer.writeln('if keyIndex == keyData.count { keyIndex = 0 }')
        }
        writer.writeln('}')
        writer.writeln('return String(data: valueData, encoding: .ascii)!')
      }
      writer.writeln('}')
    }

    writer.writeln('}')
  end

  def generate_keys_struct(keys, writer)
    writer.writeln("public enum #{@name} {")

    writer.intending {
      keys.each { |key, value|
        writer.writeln "case #{key}"
      }

      writer.writeln
      generate_value_getter(keys, writer)
      writer.writeln
      generate_encoding_key(writer)
    }

    writer.write('}')
  end

  def generate_value_getter(keys, writer)
    writer.writeln('public var value: String {')

    writer.intending {
      writer.writeln("let bytes: [UInt8]\n")
      writer.writeln('switch self {')

      keys.each { |key, value|
        writer.writeln "case .#{key}:"
        writer.intending {
          writer.writeln("bytes = #{value.xor_unpacked(key + @xor_key)}")
        }
      }

      writer.writeln("}\n")

      writer.writeln("let encodedString = String(bytes: bytes, encoding: .ascii)!")
      writer.writeln('return encodedString.encoding(encodingKey)')
    }

    writer.writeln('}')
  end

  def generate_encoding_key(writer)
    writer.writeln('private var encodingKey: String {')
    writer.intending {
      writer.writeln('@inline(__always)')
      writer.writeln('get {')
      writer.intending {
        writer.writeln("let bytes: [UInt8] = #{@xor_key.xor_unpacked(@name)}")
        writer.writeln('let type = String(describing: type(of: self))')
        writer.writeln('let key = String(bytes: bytes, encoding: .ascii)!.encoding(type)')
        writer.writeln('return String(describing: self) + key')
      }
      writer.writeln('}')
    }
    writer.writeln('}')
  end
end


class GenerateKeysCommand < CLAide::Command

  DEFAULT_OUTPUT_FILE_NAME = 'StaticKey'

  self.summary = 'XORed keys generator'

  self.description = "Generate XORed strings for your project.\n" \
  "\nIMPORANT: This tool doesn't prevent your strings from being stolen by a praying eyes. " \
  "All it does is hide strings from being discovered by the 'strings' utility or by a disassembler. " \
  "Therefore it is strongly not recommended to put sensitive data like S3 secret key in your app at all."
  
  # This would normally default to `beverage-make`, based on the class’ name.
  self.command = 'keys-generator'

  def self.options
    [
      ['--keys=absolute_path', 'Path to the .json file that contains dictionary of the keys that needs to be XORed'],
      ['--output=absolute_path', 'Output directory for the generated file'],
      ['--xor_key', 'Key used for XORing.'],
      ['--name', "(optional) Name of the desired generated enum with keys. Default is #{DEFAULT_OUTPUT_FILE_NAME}"]
    ].concat(super)
  end

  def initialize(argv)
    @keys_path = argv.option('keys')
    @output = argv.option('output')
    @xor_key = argv.option('xor_key')

    super
  end

  self.arguments = [
    CLAide::Argument.new('--keys', true),
    CLAide::Argument.new('--output', true),
    CLAide::Argument.new('--xor_key', true),
    CLAide::Argument.new('--name', false)
  ]

  def validate!
    super

    if @keys_path.nil? || @output.nil? || @xor_key.nil? then
      help! "#{@command} requires all of [keys|output|xor_key] arguments to be passed"
    end
  end

  def run
    file = File.read(@keys_path)
    keys = JSON.parse(file)

    generator = SwiftCodeGenerator.new(DEFAULT_OUTPUT_FILE_NAME, @output, @xor_key)
    generator.generate(keys)
  end
end

GenerateKeysCommand.run ARGV
