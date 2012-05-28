#--#####################################################################
# Copyright (c) 2009-2012 Gareth Lewis and Intuit, Inc.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.opensource.org/licenses/eclipse-1.0.php
#
# Contributors:
#    Gareth Lewis - Initial contribution.
#    Intuit Partner Platform.
#++#####################################################################

module QuickBase

  # Miscellaneous static helper methods
  class Misc

    def Misc.ruby19?
       RUBY_VERSION >= "1.9"
    end
   
    def Misc.createBase32ConversionHash
      base32Symbols = {}
      decimal = 0
      ("a".."z").each{|letter|
         unless letter == "l" or letter == "o"
           base32Symbols[decimal.to_s]=letter
           decimal += 1
         end
      }
      (2..9).each{|number|
           base32Symbols[decimal.to_s]=number.to_s
           decimal += 1
      }
      base32Symbols
    end

    def Misc.decimalToBase32(decimalNumber)
      @base32Symbols ||= Misc.createBase32ConversionHash
      base32Num = ""
      decimalNumber = decimalNumber.to_i
      if decimalNumber < 32
        base32Num = @base32Symbols[decimalNumber.to_s]
      else
        power = 10
        power -= 1 while (decimalNumber/(32**power)) < 1
        while decimalNumber > 0
           n = (decimalNumber/(32**power))
           base32Num << @base32Symbols[n.to_s] if @base32Symbols[n.to_s]
           decimalNumber = (decimalNumber-((32**power)*n))
           power -= 1
         end
      end
      base32Num
    end
    
    def Misc.isBase32Number?(string)
      ret = true
      if string
        @base32Symbols ||= Misc.createBase32ConversionHash
        base32SymbolsValues = @base32Symbols.values
        stringCopy = string.to_s
        stringCopy.split(//).each{|char|
          if !base32SymbolsValues.include?(char)
            ret = false 
            break
          end  
        }
      else
        ret = false
      end  
      ret
    end  
    
    def Misc.isDbidString?(string) 
      Misc.isBase32Number?(string) 
    end
    
    def Misc.time_in_milliseconds(time = nil)
      ret = 0
      time ||= Time.now
      if time.is_a?(Time)
        ret = (time.to_f * 1000).to_i
      elsif time.is_a?(DateTime)
        t = Time.mktime(time.year,time.month,time.day,time.hour,time.min,time.sec,0)
        ret = (t.to_f * 1000).to_i
      elsif time.is_a?(Date)
        t = Time.mktime(time.year,time.month,time.day,0,0,0,0)
        ret = (t.to_f * 1000).to_i
      end  
      ret  
    end 
    
    def Misc.listUserToArray(listUser)
      listUser.split(/;/)
    end	    
    
    def Misc.arrayToListUser(array)
      array.join(";")
    end	    
       
  end
end
