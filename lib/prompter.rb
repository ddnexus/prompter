require 'dye'

# @author Domizio Demichelis
#
class Prompter

  VERSION = File.read(File.expand_path('../../VERSION', __FILE__)).strip

  class << self ; attr_accessor :dye_styles ; end

  @dye_styles = { :say_style         => nil,
                  :say_echo_style    => nil,
                  :say_notice_style  => :yellow,
                  :say_warning_style => :red,
                  :ask_style         => :magenta,
                  :hint_style        => :green }

  # Standard constructor, also accepts a block
  #
  # @param [Hash] opts The options to create a Prompter object.
  # @option opts [String] :prefix The prefix string
  # @option opts [Boolean] :echo when true adds a line with the result
  #
  # @yield yields the block with self
  # @yieldparam [Prompter]
  #
  def initialize(opts={})
    @prefix = opts[:prefix]
    @echo = opts[:echo] || true
    yield self if block_given?
  end

  module Methods

    define_dye_method Prompter.dye_styles

    attr_writer :echo, :prefix

    # The echo instance option (true by default)
    def echo
      @echo ||= true
    end

    def prefix
      @prefix ||= ''
    end

    # Shows a message
    #
    # @param [String] message Your message
    #
    # @param [Hash] opts the standard opts to pass along
    # @option opts [String] :default The default choice when the user hits <enter> instead of any content
    # @option opts [String] :prefix The prefix string
    # @option opts [Boolean] :echo Adds a line showing the input (=> input)
    # @option opts [String] :hint A string to show the available choices
    # @option opts [Symbol] :style The Dye style name to use for this prompt
    # @option opts [Boolean] :force_new_line Forces the addition of a new line (otherwise determined by the end of the prompt string)
    #
    def say(message="", opts={})
      message = message.to_s
      opts = { :force_new_line => (message !~ /( |\t)$/),
               :style          => :say_style,
               :prefix         => prefix }.merge opts
      message = dye(message, *opts[:style]) unless opts[:style].nil?
      message = (opts[:prefix]||'') + message
      $stdout.send((opts[:force_new_line] ? :puts : :print), message)
      $stdout.flush
    end

    # Shows a colored message. It uses :say passing the :say_notice_style :style option
    #
    # @see #say
    #
    def say_notice(message="", opts={})
      opts = { :style => :say_notice_style }.merge opts
      say message, opts
    end

    # Shows a red colored message. It uses :say passing the :say_warning_style :style option,
    # besides it adds an audible bell character to the message. Pass :mute => true to mute.
    #
    # @see #say
    #
    def say_warning(message="", opts={})
      opts = { :style => :say_warning_style }.merge opts
      message = "\a" + message unless opts[:mute]
      say message, opts
    end

    # Asks for an input
    #
    # @param [String] prompt Your question
    #
    # @param [Hash] opts the standard opts to pass along (see #say
    #
    # for block {|input| ... }
    # @yield [input] yields the block with the user input
    # @yieldparam [String] input user input
    # @return [String] The user input
    #
    def ask(prompt, opts={})
      opts = { :style   => :ask_style,
               :hint    => '',
               :default => '' }.merge opts
      force_new_line = !!opts.delete(:force_new_line) unless opts[:hint].empty?
      prompt = prompt + ' ' unless opts[:force_new_line]
      say prompt, opts
      say_hint(opts[:hint], opts.merge({:force_new_line => !!force_new_line})) unless opts[:hint].empty?
      input = $stdin.gets || '' # multilines ended at start generate a nil
      input.strip!
      input = opts[:default].to_s if input.empty?
      say_echo(input, opts) unless opts[:echo] == false || echo == false
      block_given? ? yield(input) : input
    end

    # Asks for a multiline input
    #
    # @param [String] prompt Your question
    #
    # @param [Hash] opts the standard opts to pass along (see #say, plus the followings)
    # @option opts [String] :input_end Used to end the input (default nil: requires ^D to end the input)
    # @option opts [Boolean] :force_new_line Default to true
    #
    # for block {|input| ... }
    # @yield [input] yields the block with the user input
    # @yieldparam [String] input user input
    # @return [String] The user input (with the eventual :input_end line removed)
    #
    def ask_multiline(prompt, opts={})
      opts = { :input_end => nil,
               :force_new_line => true,
               :hint => %([end the input by typing "#{opts[:input_end] || '^D'}" in a new line]) }.merge opts
      old_separator = $/
      $/ = opts.delete(:input_end)
      input = ask(prompt, opts).sub(/\n#{$/}$/, '')
      $/ = old_separator
      block_given? ? yield(input) : input
    end

    # Chooses among different choices
    #
    # @param [String] prompt Your question
    # @param [RegExp, Proc] validation Validates the input
    #
    # @param [Hash] opts the standard opts to pass along (see #say)
    #
    # @yield [input] yields the block with the user-chosen input
    # @yieldparam [String] input The user input
    # @return [String] The user-chosen input
    #
    def choose(prompt, validation, opts={}, &block)
      choice = ask prompt, opts
      if valid_choice?(validation, choice)
        block_given? ? yield(choice) : choice
      else
        say_warning 'Unknown choice!'
        choose(prompt, validation, opts, &block)
      end
    end

    # Chooses many among different choices
    #
    # @param [String] prompt Your question
    # @param [RegExp, Proc] validation Validates the input
    #
    # @param [Hash] opts the standard opts to pass along (see #say, plus the followings)
    # @option opts [String, RegExp] :split Used to split the input (see String#split)
    #
    # @yield [input] yields the block with the user-chosen array of input
    # @yieldparam [Array] input The user array of input
    # @return [Array] The user-chosen array of input
    #
    def choose_many(prompt, validation, opts={}, &block)
      choices = ask(prompt, opts).split(opts[:split])
      if choices.all? {|c| valid_choice?(validation, c)}
        block_given? ? yield(choices) : choices
      else
        say_warning 'One or more choices are unknown!'
        choose_many(prompt, validation, opts, &block)
      end
    end


    # Asks a yes/no question and yields the block with the resulting Boolean
    #
    # @param [Hash] opts the standard opts to pass along (see #say)
    #
    # @yield yields the block always with a Boolean
    # @yieldparam [Boolean]
    # @return [Boolean] true for 'y' and false for 'n'
    #
    def yes_no?(prompt, opts={})
      opts = { :hint => '[y|n]' }.merge opts
      choice = choose(prompt, /^y|n$/i, opts)
      result = choice.match(/^y$/i) ? true : false
      block_given? ? yield(result) : result
    end

    # Asks a yes/no question and yields the block only when the answer is yes
    #
    # @param [String] prompt Your question
    #
    # @param [Hash] opts the standard opts to pass along (see #say)
    #
    # @yield yields the block when the answer is 'y'
    # @return [Boolean] true for 'y' and false for 'n'
    #
    def yes?(prompt, opts={})
      result = yes_no? prompt, opts
      (block_given? && result) ? yield : result
    end

    # Asks a yes/no question and yields the block only when the answer is no
    #
    # @param [String] prompt Your question
    #
    # @param [Hash] opts the standard opts to pass along (see #say)
    #
    # @yield yields the block when the answer is no
    # @return [Boolean] true for 'n' and false for 'y'
    #
    def no?(prompt, opts={})
      result = yes_no? prompt, opts
      (block_given? && !result) ? yield : !result
    end

    # Chooses among different choices in an indexed list
    #
    # @param [String] prompt Your question
    # @param [Array] list The list of choices
    #
    # @param [Hash] opts the standard opts to pass along (see #say)
    #
    # @yield yields the block with the user-chosen input
    # @yieldparam [Integer] index The index number
    # @return [Integer] The index number from the list referring to the user-chosen input
    #
    def choose_index(prompt, list, opts={})
      opts = list_choices(prompt, list, opts)
      choice = choose ">", lambda{|v| (1..list.size).map(&:to_s).include?(v) }, opts
      index = choice.to_i-1
      block_given? ? yield(index) : index
    end

    # Chooses many among different choices in an indexed list
    #
    # @param [String] prompt Your question
    # @param [Array] list The list of choices
    #
    # @param [Hash] opts the standard opts to pass along (see #say, plus the followings)
    # @option opts [String, RegExp] :split Used to split the input (see String#split)
    #
    # @yield [input] yields the block with the user-chosen array of input
    # @yieldparam [Array] indexes The user-chosen array of indexes
    # @return [Array] The user-chosen array of indexes
    #
    def choose_many_index(prompt, list, opts={})
      opts = list_choices(prompt, list, opts, true)
      choices = choose_many ">", lambda{|v| (1..list.size).map(&:to_s).include?(v) }, opts
      indexes = choices.map {|i| i.to_i-1 }
      block_given? ? yield(indexes) : indexes
    end

  protected

    # used internally to show a feedback of the input
    def say_echo(result, opts={})
      opts.delete(:style) # :style is not passed
      opts = { :style  => :say_echo_style,
               :prefix => ' ' * prefix.to_s.size }.merge opts
      say( ('=> ' + result.inspect), opts )
      result
    end

    # used internally to show the hints
    def say_hint(hint, opts={})
      return if hint.empty?
      opts.merge!( { :style  => :hint_style} ) # hint is always :hint_style
      opts = {:prefix => '' }.merge opts
      hint = hint + ' ' unless opts[:force_new_line]
      say hint, opts
    end

  private

    def valid_choice?(validation, choice)
      (validation.is_a?(Regexp) && validation.match(choice)) ||
      (validation.is_a?(Proc)   && validation.call(choice))
    end

    def list_choices(prompt, list, opts={}, many=false)
      hint = many ? "[choose one or more in range 1..#{list.size} (#{opts[:split].nil? ? '<space>' : opts[:split].inspect} splitted)]" :
                    "[choose one in range 1..#{list.size}]"
      opts = { :style => :ask_style,
               :hint  => hint }.merge opts
      say prompt, opts
      list.each_with_index do |item, index|
        say_hint (index+1).to_s.rjust(count_digits(list.size)) + '.', :prefix => ' ' * (prefix.to_s.length)
        say item, :prefix => ''
      end
      opts
    end

    def count_digits(number)
      num = number.abs
      count = 0
      while num >= 1
        num = num / 10
        count += 1
      end
      count
    end

  end

  extend Methods
  include Methods

end
