require 'Nokogiri'
require 'HTTParty'

if ARGV.length != 1
  p "usage: #{File.basename($0)} <game id>"
  exit
end

game_id = ARGV[0]

url = "http://www.j-archive.com/showgame.php?game_id=#{game_id}" 
page = HTTParty.get( url )
parsed = Nokogiri::HTML( page )

num_columns = 6
questions_and_answers = []

# .final_round lays out a little different.  not handling that for now
round_selectors = [ ".round"  ].each do |round_identifier|

  column = 0

  # grab the items for this round
  the_round = parsed.css( round_identifier )
  the_round.each do |item|

    categories = []
    item.css( ".category_name" ).each do |c|
      categories << c.text
    end
    
    item.css( "td.clue" ).each do |clue|
      question = clue.css( ".clue_text" ).text
      question = question.gsub( /\*/, "" )

      if( ( question == ""  ) ||  # some questions dont show up - prob cause time ran out
          ( /seen here\Z/.match( question ) ) || # skip questions that appear to be visual
          ( /heard here\Z/.match( question ) ) # skip questions that appear to be audio
        )
        column = column + 1
        next
      end

      category = categories[ column % num_columns ]
      column = column + 1
      amount = clue.css( ".clue_value" ).text

      answer_raw = clue.css( "div" )[0].attributes['onmouseover'].value
      # this is raw text that is passed into js, so parsing w/regex
      answer_match = /<em class=\"correct_response\">(.*)<\/em>/.match( answer_raw )
      answer = answer_match[1]

      # some answers are wrapped in <i>, <b>, etc..
      answer = answer.gsub( /<[^>]*>/, "" ).
               gsub( /\*/, "[asterisk]" ). # trivia plugin uses asterisk as a delim
               gsub( /\\'/, "'" ). # answers are escape quoted
               gsub( /"/, "" )
      

      answers = []
      
      # now clean up the data.

      # The format of the answers whereby there are multiple correct answers, is all over the place - so we'll drop them for now
      #  SHEEP (): 1 of the 2 countries which raise the most sheep,(1 of) australia or the Soviet Union
      if( /\d of\)/.match( answer ) )
        next
      end

      # (Charles) Schwab
      if( matches = /\((.*)\)\s?([^\s]+)\Z/.match( answer ) )
        answers << "#{matches[1]} #{matches[2]}"
        answers << matches[2]
      end


      # green (mint accepted)
      if( matches = /(.+)\s+\((.*)\s+accepted\)\Z/.match( answer ) )
        answers << matches[1]
        answers << matches[2]
      end

      # Linda Eastman (McCartney)
      if( matches = /(.+)\s+\((.*)\)\Z/.match( answer ) )
        answers << matches[1]
        answers << "#{matches[1]} #{matches[2]}"
      end

      # the equestrian order
      if( matches = /\Athe\s+(.*)\Z/.match( answer ) )
        answers << matches[1]
        answers << answer
      end

      # an opera house
      if( matches = /\Aan?\s+(.*)\Z/.match( answer ) )
        answers << matches[1]
        answers << answer
      end
        
      questions_and_answers << 
        
      { "question" => question,
        "answers" => answers.length > 0 ? answers : [ answer ],
        "category" => category,
        "amount" => amount }

    end
  end
end

questions_and_answers.each do |q|
  puts "#{q['category']} (#{q['amount']}): #{q['question']}*#{q['answers'].join('*')}"
end


  
