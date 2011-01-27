require 'rubygems'
$:.unshift File.expand_path('../../lib', __FILE__)
require 'prompter'


Prompter.new(:prefix => '--- ') do |p|
  p.say_notice 'You can avoid to extend your class with Prompter::Methods'
end



extend Prompter::Methods

self.prefix = '*** '

say 'This part uses imported method from Prompter::Methods'

yes_no?( 'Do you want to go on or not?') do |yes|
  if yes
    say 'Very good from you!'
    choose('Do you want a, b or c?', /^a|b|c$/i, :hint => '[a|<enter>=b|c]', :default => 'b') do |choice|
      case choice
      when 'a'
        say 'You have chosen A, but that is not good. END'
      when 'b'
        say 'You have chosen B. That is a good option!'
        ask('Which name do you wanna have?', :hint => '[<enter>=user]', :default => 'user') do |name|
          say "You have chosen '#{name}' and that's ok!"
        end
      when 'c'
        say 'You have chosen C. Game over.'
      end
    end
  else
    list = %w[alfa beta gamma delta]
    choose_index('You should choose among this items:', list, :echo => false) do |index|
      say "You have chosen '#{list[index]}', at index #{index}"
    end
  end
end
say '', :prefix => ''
say_notice 'The example is over'

