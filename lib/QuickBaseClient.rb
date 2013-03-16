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

require 'rexml/document'
require 'net/https'
require 'json'
require 'QuickBaseMisc'

begin
  require 'httpclient'
  USING_HTTPCLIENT = true
rescue LoadError
  USING_HTTPCLIENT = false
end  

module QuickBase

# QuickBase Client: Ruby wrapper class for QuickBase HTTP API.
# The class's method and member variable names correspond closely to the QuickBase HTTP API reference.
# This class was written using ruby 1.8.6.  It is strongly recommended that you use ruby 1.9.2 or higher.
# Use REXML to process any QuickBase response XML not handled by this class.
# The main work of this class is done in initialize(), sendRequest(), and processResponse().
# The API_ wrapper methods just set things up for sendRequest() and put values from the
# response into member variables.
class Client

   attr_reader :access, :accessid, :accountLimit, :accountUsage, :action, :admin 
   attr_reader :adminOnly, :ancestorappid, :app, :appdbid, :appdata, :applicationLimit, :applicationUsage, :apptoken, :authenticationXML 
   attr_reader :cacheSchemas, :cachedSchemas, :chdbids, :choice, :clist, :copyfid, :create, :createapptoken, :createdTime 
   attr_reader :databases, :dbdesc, :dbid, :dbidForRequestURL, :dbname, :delete, :destrid, :dfid, :disprec, :domain, :downLoadFileURL
   attr_reader :email, :errcode, :errdetail, :errtext, :excludeparents, :externalAuth, :fform
   attr_reader :fid, :fids, :field, :fields, :field_data, :field_data_list, :fieldTypeLabelMap, :fieldValue, :fileContents, :fileUploadToken, :firstName, :fmt, :fname, :fnames, :fvlist
   attr_reader :hours, :HTML, :httpConnection, :id, :ignoreError, :includeancestors 
   attr_reader :jht, :jsa, :key_fid, :key, :keepData, :label, :lastAccessTime
   attr_reader :lastError, :lastModifiedTime, :lastName, :lastPaymentDate, :lastRecModTime, :login
   attr_reader :mgrID, :mgrName, :mode, :modify, :name
   attr_reader :newappname, :newowner, :newdbdesc, :newdbid, :newdbname
   attr_reader :num_fields, :numMatches, :num_records, :num_recs_added, :num_records_deleted
   attr_reader :num_recs_input, :num_recs_updated, :numadded, :numCreated
   attr_reader :numRecords, :numremoved, :oldestancestorappid, :options, :org, :page, :pages, :pagebody
   attr_reader :pageid, :pagename, :pagetype, :parentrid, :password, :permissions
   attr_reader :printRequestsAndResponses, :properties, :qarancestorappid, :qdbapi, :qbhost
   attr_reader :qid, :qname, :queries, :query, :record, :records, :records_csv, :recurse, :relfids
   attr_reader :requestHeaders, :requestNextAllowedTime, :requestSucceeded, :requestTime, :requestURL, :requestXML
   attr_reader :responseElement, :responseElementText, :responseElements, :responseXML
   attr_reader :responseXMLdoc, :rid, :rids, :role, :roleid, :rolename, :roles, :saveviews, :screenName 
   attr_reader :serverStatus, :serverVersion ,  :serverUsers,  :serverGroups, :serverDatabases, :serverUptime, :serverUpdays 
   attr_reader :showAppData, :skipfirst, :slist, :sourcerid, :standardRequestHeaders, :status, :stopOnError
   attr_reader :table, :tables, :ticket, :type, :udata, :uname, :update_id, :user, :userid  
   attr_reader :username, :users, :value, :validFieldProperties, :validFieldTypes, :variables 
   attr_reader :varname, :version, :vid, :view, :withembeddedtables
   attr_reader :eventSubscribers, :logger

   attr_writer :cacheSchemas, :apptoken, :escapeBR, :fvlist, :httpConnection, :ignoreCR, :ignoreLF, :ignoreTAB 
   attr_writer :printRequestsAndResponses, :qbhost, :stopOnError, :ticket, :udata, :rdr, :xsl, :encoding

=begin rdoc
 'Plumbing' methods:
  These methods implement the core functionality to make 
  the API_ wrapper methods and the 'Helper' methods work.
=end

   # Set printRequestsAndResponses to true to view the XML sent to QuickBase and return from QuickBase.
   # This can be very useful during debugging.
   #
   # Set stopOnError to true to discontinue sending requests to QuickBase after an error has occured with a request.
   # Set showTrace to true to view the complete stack trace of your running program.  This should only be
   # necessary as a last resort when a low-level exception has occurred.
   #
   # To create an instance of QuickBase::Client using a Hash of options,
   # use QuickBase::Client.init(options) instead of QuickBase::Client.new()
   def initialize( username = nil, 
                       password = nil, 
                       appname = nil, 
                       useSSL = true, 
                       printRequestsAndResponses = false, 
                       stopOnError = false, 
                       showTrace = false, 
                       org = "www", 
                       apptoken = nil,
                       debugHTTPConnection = false,
                       domain = "quickbase",
                       proxy_options = nil
                       )
      begin
         @org = org ? org : "www"
         @domain = domain ? domain : "quickbase"
         @apptoken = apptoken
         @printRequestsAndResponses = printRequestsAndResponses
         @stopOnError = stopOnError
         @escapeBR = @ignoreCR = @ignoreLF = @ignoreTAB = true
         toggleTraceInfo( showTrace ) if showTrace
         setHTTPConnectionAndqbhost( useSSL, org, domain, proxy_options )         
         debugHTTPConnection() if debugHTTPConnection
         @standardRequestHeaders = { "Content-Type" => "application/xml" }
         if username and password
            authenticate( username, password )
            if appname and @errcode == "0"
               findDBByname( appname )
               if @dbid and @errcode == "0"
                 getDBInfo( @dbid )
                 getSchema( @dbid )
               end
            end
         end
      rescue Net::HTTPBadRequest => @lastError
      rescue Net::HTTPBadResponse => @lastError
      rescue Net::HTTPHeaderSyntaxError => @lastError
      rescue StandardError => @lastError
      end
    end
    
   # Class method to create an instance of QuickBase::Client using a Hash of parameters.
   # E.g. qbc = QuickBase::Client.init( { "stopOnError" => true,  "printRequestsAndResponses" => true } )
   def Client.init( options )
     
     options ||= {}
     options["useSSL"] ||= true
     options["printRequestsAndResponses"] ||= false
     options["stopOnError"] ||= false
     options["showTrace"] ||= false
     options["org"]  ||= "www"
     options["debugHTTPConnection"] ||= false
     options["domain"] ||= "quickbase"
     options["proxy_options"] ||= nil
     
     instance = Client.new( options["username"], 
                                     options["password"], 
                                     options["appname"],
                                     options["useSSL"], 
                                     options["printRequestsAndResponses"],
                                     options["stopOnError"],
                                     options["showTrace"],
                                     options["org"],
                                     options["apptoken"],
                                     options["debugHTTPConnection"],
                                     options["domain"],
                                     options["proxy_options"])
   end

   # Initializes the connection to QuickBase.
   def setHTTPConnection( useSSL, org = "www", domain = "quickbase", proxy_options = nil )
      @useSSL = useSSL
      @org = org
      @domain = domain
      if USING_HTTPCLIENT
        if proxy_options
           @httpConnection = HTTPClient.new( "#{proxy_options["proxy_server"]}:#{proxy_options["proxy_port"] || useSSL ? "443" : "80"}" )
           @httpConnection.set_auth(proxy_options["proxy_server"], proxy_options["proxy_user"], proxy_options["proxy_password"])
        else  
           @httpConnection = HTTPClient.new 
        end
      else  
        if proxy_options
           @httpProxy = Net::HTTP::Proxy(proxy_options["proxy_server"], proxy_options["proxy_port"], proxy_options["proxy_user"], proxy_options["proxy_password"])
           @httpConnection = @httpProxy.new( "#{@org}.#{@domain}.com", useSSL ? 443 : 80)
        else
           @httpConnection = Net::HTTP.new( "#{@org}.#{@domain}.com", useSSL ? 443 : 80 )
        end  
        @httpConnection.use_ssl = useSSL
        @httpConnection.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
   end
    
   # Causes useful information to be printed to the screen for every HTTP request.
   def debugHTTPConnection()
      @httpConnection.set_debug_output $stdout if @httpConnection and USING_HTTPCLIENT == false
   end  

   # Sets the QuickBase URL and port to use for requests.
   def setqbhost( useSSL, org = "www", domain = "quickbase" )
      @useSSL = useSSL
      @org = org
      @domain = domain
      @qbhost = useSSL ? "https://#{@org}.#{@domain}.com:443" : "http://#{@org}.#{@domain}.com"
      @qbhost
   end

   # Initializes the connection to QuickBase and sets the QuickBase URL and port to use for requests.
   def setHTTPConnectionAndqbhost( useSSL, org = "www", domain = "quickbase", proxy_options = nil )
      setHTTPConnection( useSSL, org, domain, proxy_options )
      setqbhost( useSSL, org, domain )
   end

   # Return an array of all the public methods of this class.
   # Used by CommandLineClient to verify commands entered by the user.
   def clientMethods
      Client.public_instance_methods( false )
   end

   # Sends requests to QuickBase and processes the reponses.
   def sendRequest( api_Request, xmlRequestData = nil )

      fire( "onSendRequest" )

      resetErrorInfo

      # set up the request
      getDBforRequestURL( api_Request )
      getAuthenticationXMLforRequest( api_Request )
      isHTMLRequest = isHTMLRequest?( api_Request )
      api_Request = "API_" + api_Request.to_s if prependAPI?( api_Request )

      xmlRequestData << toXML( :udata, @udata ) if @udata and @udata.length > 0
      xmlRequestData << toXML( :rdr, @rdr ) if @rdr and @rdr.length > 0
      xmlRequestData << toXML( :xsl, @xsl ) if @xsl and @xsl.length > 0
      xmlRequestData << toXML( :encoding, @encoding ) if @encoding and @encoding.length > 0

      if xmlRequestData
         @requestXML = toXML( :qdbapi, @authenticationXML + xmlRequestData )
      else
         @requestXML = toXML( :qdbapi, @authenticationXML )
      end

      @requestHeaders = @standardRequestHeaders
      @requestHeaders["Content-Length"] = "#{@requestXML.length}"
      @requestHeaders["QUICKBASE-ACTION"] = api_Request
      @requestURL = "#{@qbhost}#{@dbidForRequestURL}"

      printRequest( @requestURL, @requestHeaders,  @requestXML ) if @printRequestsAndResponses
      @logger.logRequest( @dbidForRequestURL, api_Request, @requestXML ) if @logger

      begin

         # send the request
         if USING_HTTPCLIENT
            response = @httpConnection.post( @requestURL, @requestXML, @requestHeaders )
            @responseCode = response.status
            @responseXML = response.content
         else  
            if Net::HTTP.version_1_2?
               response = @httpConnection.post( @requestURL, @requestXML, @requestHeaders )
               @responseCode = response.code
               @responseXML = response.body
            else
               @responseCode, @responseXML = @httpConnection.post( @requestURL, @requestXML, @requestHeaders )
            end	
         end
          
         printResponse( @responseCode,  @responseXML ) if @printRequestsAndResponses

         if not isHTMLRequest
            processResponse( @responseXML )
         end

      @logger.logResponse( @lastError, @responseXML ) if @logger

      fireDBChangeEvents

      rescue Net::HTTPBadResponse => error
         @lastError = "Bad HTTP Response: #{error}"
      rescue Net::HTTPHeaderSyntaxError => error
         @lastError = "Bad HTTP header syntax: #{error}"
      rescue StandardError => error
         @lastError = "Error processing #{api_Request} request: #{error}"
      end

      @requestSucceeded = ( @errcode == "0" and @lastError == "" )

      fire( @requestSucceeded ? "onRequestSucceeded" : "onRequestFailed" )

      if @stopOnError and !@requestSucceeded
         raise @lastError
      end
   end

   # Resets error info before QuickBase requests are sent.
   def resetErrorInfo
      @errcode = "0"
      @errtext = ""
      @errdetail = ""
      @lastError = ""
      @requestSucceeded = true
      self
   end

   # Determines whether the URL for a QuickBase request is for a 
   # specific database table or not, and returns the appropriate string
   # for that portion of the request URL.
   def getDBforRequestURL( api_Request )
      @dbidForRequestURL = "/db/#{@dbid}"
      case api_Request
         when :getAppDTMInfo
            @dbidForRequestURL = "/db/main?a=#{:getAppDTMInfo}&dbid=#{@dbid}"
         when :authenticate, :createDatabase, :deleteAppZip, :dumpAppZip, :getUserInfo, :findDBByname, :getOneTimeTicket, :getFileUploadToken, :grantedDBs, :installAppZip, :obStatus, :signOut
            @dbidForRequestURL = "/db/main"
      end
   end

   # Returns the request XML for either a ticket or a username and password. 
   # The XML includes a apptoken if one has been set. 
   def getAuthenticationXMLforRequest( api_Request )
      @authenticationXML = ""
      if @ticket
         @authenticationXML = toXML( :ticket, @ticket )
      elsif @username and @password
         @authenticationXML = toXML( :username, @username ) + toXML( :password, @password )
      end
      @authenticationXML << toXML( :apptoken, @apptoken ) if @apptoken
   end

   # Returns whether a request will return HTML rather than XML.
   def isHTMLRequest?( api_Request )
      ret = false
      case api_Request
         when :genAddRecordForm, :genResultsTable, :getRecordAsHTML
            ret = true
      end
      ret
    end

   # Returns whether to prepend 'API_' to request string
   def prependAPI?( request )
      ret = true
      ret = false if request.to_s.include?("API_") or request.to_s.include?("QBIS_")
      ret
    end
    
   # Turns program stack tracing on or off.  
   # If followed by a block, the tracing will be toggled on or off at the end of the block.
   def toggleTraceInfo( showTrace )
      if showTrace
         # this will print a very large amount of stuff
         set_trace_func proc { |event, file, line, id, binding, classname|  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname }
         if block_given?
            yield
            set_trace_func nil
         end
      else
         set_trace_func nil
         if block_given?
            yield
            set_trace_func proc { |event, file, line, id, binding, classname|  printf "%8s %s:%-2d %10s %8s\n", event, file, line, id, classname }
         end
      end
      self
   end

   # Called by sendRequest if @printRequestsAndResponses is true
   def printRequest( url, headers, xml )
      puts
      puts "Request: -------------------------------------------"
      p url if url
      p headers if headers
      p xml if xml
      self
   end

   # Called by sendRequest if @printRequestsAndResponses is true
   def printResponse( code, xml )
      puts
      puts "Response: ------------------------------------------"
      p code if code
      p xml if xml
      self
   end

   # Prints the error info, if any, for the last request sent to QuickBase.
   def printLastError
      if @lastError
         puts
         puts "Last error: ------------------------------------------"
         p @lastError
      end
      self
   end

   # Except for requests that return HTML, processes the XML responses returned from QuickBase.
   def processResponse( responseXML )

      fire( "onProcessResponse" )

      parseResponseXML( responseXML )
      @ticket ||= getResponseValue( :ticket )
      @udata = getResponseValue( :udata )
      getErrorInfoFromResponse
   end

   # Extracts error info from XML responses returned by QuickBase.
   def getErrorInfoFromResponse
      if @responseXMLdoc
         errcode = getResponseValue( :errcode )
         @errcode = errcode ? errcode : ""
         errtext = getResponseValue( :errtext )
         @errtext = errtext ? errtext : ""
         errdetail = getResponseValue( :errdetail )
         @errdetail = errdetail ? errdetail : ""
         if @errcode != "0"
            @lastError = "Error code: #{@errcode} text: #{@errtext}: detail: #{@errdetail}"
         end
      end
      @lastError
   end

   # Called by processResponse to put the XML from QuickBase
   # into a DOM tree using the REXML module that comes with Ruby.
   def parseResponseXML( xml )
      if xml
         xml.gsub!( "\r", "" ) if @ignoreCR and @ignoreCR == true
         xml.gsub!( "\n", "" ) if @ignoreLF and @ignoreLF == true
         xml.gsub!( "\t", "" ) if @ignoreTAB and @ignoreTAB == true
         xml.gsub!( "<BR/>", "&lt;BR/&gt;" ) if @escapeBR
         @qdbapi = @responseXMLdoc = REXML::Document.new( xml )
      end
   end

   # Gets the value for a specific field at the top level
   # of the XML returned from QuickBase.
   def getResponseValue( field )
      @fieldValue = nil
      if field and @responseXMLdoc
         @fieldValue = @responseXMLdoc.root.elements[ field.to_s ]
         @fieldValue = fieldValue.text if fieldValue and fieldValue.has_text?
      end
      @fieldValue
   end

   # Gets the value of a field using an XPath spec., e.g. field/name
   def getResponsePathValue( path )
       @fieldValue = ""
       e = getResponseElement( path )
       if e and e.is_a?( REXML::Element ) and e.has_text?
          @fieldValue = e.text
       end
       @fieldValue
   end

   # Gets an array of values at an Xpath in the XML from QuickBase.
   def getResponsePathValues( path )
       @fieldValue = ""
       e = getResponseElements( path )
       e.each{ |e| @fieldValue << e.text if e and e.is_a?( REXML::Element ) and e.has_text?  }
       @fieldValue
   end

   # Gets an array of elements at an Xpath in the XML from QuickBase.
   def getResponseElements( path )
      if path and @responseXMLdoc
         @responseElements = @responseXMLdoc.get_elements( path.to_s )
      end
      @responseElements
   end

   # Gets the element at an Xpath in the XML from QuickBase.
   def getResponseElement( path )
      if path and @responseXMLdoc
         @responseElement = @responseXMLdoc.root.elements[ path.to_s ]
      end
      @responseElement
   end

   # Returns a string representation of the attributes of an XML element.
   def getAttributeString( element )
      attributes = ""
      if element.is_a?( REXML::Element ) and element.has_attributes?
         attributes = "("
         element.attributes.each { |name,value|
            attributes << "#{name}=#{value} "
         }
         attributes << ")"
      end
      attributes
    end
    
   # Gets a field name (i.e. QuickBase field label) using a field ID.
   # getSchema() or doQuery()  should be called before this if you don't supply the dbid.
   def lookupFieldNameFromID( fid, dbid=nil )
     getSchema(dbid) if dbid
      name = nil
      if @fields
            field = lookupField( fid ) if fid
            label = field.elements[ "label" ] if field
            name = label.text if label
      end
      name
   end

   # Returns the name of field given an "fid" XML element.
   def lookupFieldName( element )
      name = ""
      if element and element.is_a?( REXML::Element )
         name = element.name
         if element.name == "f" and @fields
            fid = element.attributes[ "id" ]
            field = lookupField( fid ) if fid
            label = field.elements[ "label" ] if field
            name = label.text if label
         end
      end
      name
   end

   # Returns a QuickBase field type, given an XML "fid" element.
   def lookupFieldType( element )
      type = ""
      if element and element.is_a?( REXML::Element )
         if element.name == "f" and @fields
            fid = element.attributes[ "id" ]
            field = lookupField( fid ) if fid
            type = field.attributes[ "field_type" ] if field
         end
      end
      type
   end

   # Returns an array of XML field elements matching a QuickBase field type.
   def lookupFieldsByType( type )
      findElementsByAttributeValue( @fields, "field_type", type )
   end
   
   # Returns the value of a field property, or nil.
   def lookupFieldPropertyByName( fieldName, property )
      theproperty = nil
      if isValidFieldProperty?(property)
         fid = lookupFieldIDByName( fieldName )
         field = lookupField( fid ) if fid
         theproperty = field.elements[ property ] if field
         theproperty = theproperty.text if theproperty and theproperty.has_text?
      end
      theproperty
   end

   # Returns whether a field will show a Total on reports.
   def isTotalField?(fieldName)
      does_total = lookupFieldPropertyByName(fieldName,"does_total")
      ret = does_total and does_total == "1"
   end
   
   # Returns whether a field will show an Average on reports.
   def isAverageField?(fieldName)
      does_average = lookupFieldPropertyByName(fieldName,"does_average")
      ret = does_average and does_average == "1"
   end

   # Returns whether a field ID is the ID for the key field in a QuickBase table.
   def isRecordidField?( fid )
      fields = lookupFieldsByType( "recordid" )
      (fields and fields.last and fields.last.attributes[ "id" ] == fid)
   end

   # Returns whether a field ID is the ID for a built-in field
   def isBuiltInField?( fid )
       fid.to_i < 6
   end

   # Returns a human-readable string representation of a QuickBase field value.  
   # Also required for subsequent requests to QuickBase.
   def formatFieldValue( value, type, options = nil )
      if value and type
         case type
            when "date"
               value = formatDate( value )
            when "date / time","timestamp"
               value = formatDate( value, "%m-%d-%Y %I:%M %p" )
            when "timeofday"
               value = formatTimeOfDay( value, options )
            when "duration"
               value = formatDuration( value, options )
            when "currency"   
               value = formatCurrency( value, options )
            when "percent"   
               value = formatPercent( value, options )
         end
      end
      value
   end

   # Recursive method to print a simplified (yaml-like) tree of the XML returned by QuickBase.  
   # Translates field IDs into field names.
   # Very useful during debugging.
   def printChildElements( element, indent = 0 )

      indentation = ""
      indent.times{ indentation << " " } if indent > 0

      if element and element.is_a?( REXML::Element ) and element.has_elements?

         attributes = getAttributeString( element )
         name = lookupFieldName( element )
         puts "#{indentation}#{name} #{attributes}:"

         element.each { |element|
            if element.is_a?( REXML::Element ) and element.has_elements?
               printChildElements( element, (indent+1) )
            elsif element.is_a?( REXML::Element ) and element.has_text?
               attributes = getAttributeString( element )
               name = lookupFieldName( element )
               text = formatFieldValue( element.text, lookupFieldType( element ) )
               puts " #{indentation}#{name} #{attributes} = #{text}"
            end
         }
      elsif element and element.is_a?( Array )
         element.each{ |e| printChildElements( e ) }
      end
      self
   end
   def _printChildElements() printChildElements( @qdbapi ) end
   
   # Recursive method to generate a simplified (yaml-like) tree of the XML returned by QuickBase.  
   # Translates field IDs into field names.
   def childElementsAsString( element, indent = 0 )
      ret = ""
      indentation = ""
      indent.times{ indentation << " " } if indent > 0
      if element and element.is_a?( REXML::Element ) and element.has_elements?
         attributes = getAttributeString( element )
         name = lookupFieldName( element )
         ret << "#{indentation}#{name} #{attributes}:\r\n"
         element.each { |element|
            if element.is_a?( REXML::Element ) and element.has_elements?
               ret << childElementsAsString( element, (indent+1) )
            elsif element.is_a?( REXML::Element ) and element.has_text?
               attributes = getAttributeString( element )
               name = lookupFieldName( element )
               text = formatFieldValue( element.text, lookupFieldType( element ) )
               ret << " #{indentation}#{name} #{attributes} = #{text}\r\n"
            end
         }
      elsif element and element.is_a?( Array )
         element.each{ |e| ret << childElementsAsString( e ) }
      end
      ret
   end  
   def _childElementsAsString()  childElementsAsString( @qdbapi ) end  

   # Recursive method to process leaf and (optionally) parent elements
   # of any XML element returned by QuickBase.
   def processChildElements( element, leafElementsOnly, block )
      if element
         if element.is_a?( Array )
            element.each{ |e| processChildElements( e, leafElementsOnly, block ) }
         elsif element.is_a?( REXML::Element ) and element.has_elements?
            block.call( element ) if not leafElementsOnly
            element.each{ |e|
               if e.is_a?( REXML::Element ) and e.has_elements?
                 processChildElements( e, leafElementsOnly, block )
               else
                 block.call( e )
               end
            }
         end
      end
    end
    
   # Enables alternative syntax for processing data using id values or xml element names. E.g:
   #
   # qbc.bcdcajmrh.qid_1.printChildElements(qbc.records) 
   # - prints the records returned by query 1 from table bcdcajmrh
   #
   # puts qbc.bcdcajmrf.xml_desc
   # - get the description from the bcdcajmrf application 
   #
   # puts qbc.dbid_8emtadvk.rid_24105.fid_6 
   # - print field 6 from record 24105 in table 8emtadvk
   def method_missing(missing_method_name, *missing_method_args)
     method_s = missing_method_name.to_s
     if method_s.match(/dbid_.+/) 
       if QuickBase::Misc.isDbidString?(method_s.sub("dbid_",""))
          getSchema(method_s.sub("dbid_","")) 
       end
     elsif @dbid and method_s.match(/rid_[0-9]+/) 
       _setActiveRecord(method_s.sub("rid_",""))
       @fieldValue = @field_data_list
     elsif @dbid and method_s.match(/qid_[0-9]+/) 
       doQuery(@dbid,nil,method_s.sub("qid_",""))
     elsif @dbid and method_s.match(/fid_[0-9]+/) 
        if @field_data_list
          @fieldValue = getFieldDataValue(method_s.sub("fid_","")) 
       else
          lookupField(method_s.sub("fid_",""))
       end  
     elsif @dbid and method_s.match(/pageid_[0-9]+/) 
       _getDBPage(method_s.sub("pageid_",""))
     elsif @dbid and method_s.match(/userid_.+/)
       _getUserRole(method_s.sub("userid_",""))       
     elsif @dbid and @rid and @fid and method_s.match(/vid_[0-9]+/) 
        downLoadFile( @dbid, @rid, @fid, method_s.sub("vid_","") )
     elsif @dbid and method_s.match(/import_[0-9]+/)
       _runImport(method_s.sub("import_",""))
     elsif @qdbapi and method_s.match(/xml_.+/)
       if missing_method_args and missing_method_args.length > 0
          @fieldValue = @qdbapi.send(method_s.sub("xml_",""),missing_method_args)
       else
          @fieldValue = @qdbapi.send(method_s.sub("xml_",""))
       end
     elsif QuickBase::Misc.isDbidString?(method_s)
       getSchema(method_s) 
     else  
       raise "'#{method_s}' is not a valid method in the QuickBase::Client class."
     end
     return @fieldValue if @fieldValue.is_a?(REXML::Element) # chain XML lookups
     return @fieldValue if @fieldValue.is_a?(String) # assume we just want a field value 
     self # otherwise, allows chaining of all above
   end     

   # Returns the first XML sub-element with the specified attribute value.
   def findElementByAttributeValue( elements, attribute_name, attribute_value )
      element = nil
      if elements
          if elements.is_a?( REXML::Element )
            elements.each_element_with_attribute( attribute_name, attribute_value ) { |e|  element = e }
          elsif elements.is_a?( Array )
            elements.each{ |e|
              if e.is_a?( REXML::Element ) and e.attributes[ attribute_name ] == attribute_value
                element = e
              end
            }
          end
      end
      element
   end

   # Returns an array of XML sub-elements with the specified attribute value.
   def findElementsByAttributeValue( elements, attribute_name, attribute_value )
      elementArray = []
      if elements
         if elements.is_a?( REXML::Element )
            elements.each_element_with_attribute( attribute_name, attribute_value ) { |e|  elementArray << e }
         elsif elements.is_a?( Array )
            elements.each{ |e|
              if e.is_a?( REXML::Element ) and e.attributes[ attribute_name ] == attribute_value
                element = e
              end
            }
        end
      end
      elementArray
   end

   # Returns an array of XML sub-elements with the specified attribute name.
   def findElementsByAttributeName( elements, attribute_name )
      elementArray = []
      if elements
         elements.each_element_with_attribute( attribute_name ) { |e|  elementArray << e }
      end
      elementArray
   end

   # Returns the XML element for a field definition.
   # getSchema() or doQuery()  should be called before this.
   def lookupField( fid )
      @field = findElementByAttributeValue( @fields, "id", fid )
   end

   # Returns the XML element for a field returned by a getRecordInfo call.
   def lookupFieldData( fid )
      @field_data = nil
      if @field_data_list
         @field_data_list.each{ |field|
            if field and field.is_a?( REXML::Element ) and field.has_elements?
               fieldid = field.elements[ "fid" ]
               if fieldid and fieldid.has_text? and fieldid.text == fid.to_s
                 @field_data = field
               end
            end
          }
      end
      @field_data
   end

   # Returns the value for a field returned by a getRecordInfo call.
   def getFieldDataValue(fid)
      value = nil
      if @field_data_list
          field_data = lookupFieldData(fid)
          if field_data
            valueElement = field_data.elements[ "value" ]
            value = valueElement.text if valueElement.has_text?
          end   
      end
      value
   end

   # Returns the printable value for a field returned by a getRecordInfo call.
   def getFieldDataPrintableValue(fid)
      printable = nil
      if @field_data_list
         field_data = lookupFieldData(fid)
         if field_data
            printableElement = field_data.elements[ "printable" ]
            printable = printableElement.text if printableElement and printableElement.has_text?
         end   
      end
      printable
    end
    
   # Gets the ID for a field using the QuickBase field label.
   # getSchema() or doQuery()  should be called before this if you don't supply the dbid.
   def lookupFieldIDByName( fieldName, dbid=nil )
      getSchema(dbid) if dbid
      ret = nil
      if @fields
         @fields.each_element_with_attribute( "id" ){ |f|
            if f.name == "field" and f.elements[ "label" ].text.downcase == fieldName.downcase
               ret = f.attributes[ "id" ].dup 
               break
            end
         }
      end
      ret
    end
    
   # Get an array of field IDs for a table.
  def getFieldIDs(dbid = nil, exclude_built_in_fields = false )
    fieldIDs = []
    dbid ||= @dbid
    getSchema(dbid)
    if @fields
       @fields.each_element_with_attribute( "id" ){|f|
          next if exclude_built_in_fields and isBuiltInField?(f.attributes["id"])
          fieldIDs << f.attributes[ "id" ].dup 
       }
    end
    fieldIDs   
  end

   # Get an array of field names for a table.
   def getFieldNames( dbid = nil, lowerOrUppercase = "", exclude_built_in_fields = false )
      fieldNames = []
      dbid ||= @dbid
      getSchema(dbid)
      if @fields
         @fields.each_element_with_attribute( "id" ){ |f|
            next if exclude_built_in_fields and isBuiltInField?(f.attributes["id"])
            if f.name == "field"
               if lowerOrUppercase == "lowercase"
                  fieldNames << f.elements[ "label" ].text.downcase
               elsif lowerOrUppercase == "uppercase"
                  fieldNames << f.elements[ "label" ].text.upcase
               else
                  fieldNames << f.elements[ "label" ].text.dup
               end
            end
         }
      end
      fieldNames
    end
    
   # Get a Hash of application variables.
    def getApplicationVariables(dbid=nil)
      variablesHash = {}
      dbid ||= @dbid
      qbc.getSchema(dbid)
      if @variables
         @variables.each_element_with_attribute( "name" ){ |var|
            if var.name == "var" and var.has_text?
              variablesHash[var.attributes["name"]] =  var.text
            end
         }
      end
      variablesHash
    end  
    
   # Get the value of an application variable.
    def getApplicationVariable(variableName,dbid=nil)
      variablesHash = getApplicationVariables(dbid)
      variablesHash[variableName]
    end
   
   # Returns the XML element for a record with the specified ID.
   def lookupRecord( rid )
      @record = findElementByAttributeValue( @records, "id", rid )
   end

   # Returns the XML element for a query with the specified ID.
   # getSchema() or doQuery()  should be called before this if you don't supply the dbid.
   def lookupQuery( qid, dbid=nil )
      getSchema(dbid) if dbid
      @query = findElementByAttributeValue( @queries, "id", qid )
   end

   # Returns the XML element for a query with the specified ID.
   # getSchema() or doQuery()  should be called before this if you don't supply the dbid.
   def lookupQueryByName( name, dbid=nil  )
      getSchema(dbid) if dbid
      if @queries
         @queries.each_element_with_attribute( "id" ){|q|
            if q.name == "query" and q.elements["qyname"].text.downcase == name.downcase
               return q
            end
         }
      end
      nil
   end
   
   # Given the name of a QuickBase table, returns the QuickBase representation of the table name.
   def formatChdbidName( tableName )
      tableName.downcase!
      tableName.strip!
      tableName.gsub!( /\W/, "_" )
      "_dbid_#{tableName}"
   end

   # Makes the table with the specified name the 'active' table, and returns the id from the table.
   def lookupChdbid( tableName, dbid=nil )
      getSchema(dbid) if dbid
      unmodifiedTableName = tableName.dup
      @chdbid = findElementByAttributeValue( @chdbids, "name", formatChdbidName( tableName ) )
      if @chdbid
         @dbid = @chdbid.text
         return @dbid
      end
      if @chdbids
         chdbidArray = findElementsByAttributeName( @chdbids, "name" )
         chdbidArray.each{ |chdbid|
            if chdbid.has_text?
               dbid = chdbid.text
               getSchema( dbid )
               name = getResponseElement( "table/name" )
               if name and name.has_text? and name.text.downcase == unmodifiedTableName.downcase
                  @chdbid = chdbid
                  @dbid = dbid
                  return @dbid
               end
            end
         }
      end
      nil
   end

   # Get the name of a table given its id.
   def getTableName(dbid)
      tableName = nil 
      dbid ||= @dbid
      if getSchema(dbid)
        tableName = getResponseElement( "table/name" ).text
      end
      tableName
   end   

   # Get a list of the names of the child tables of an application.
   def getTableNames(dbid, lowercaseOrUpperCase = "")
      tableNames = []
      dbid ||= @dbid
      getSchema(dbid)      
      if @chdbids
         chdbidArray = findElementsByAttributeName( @chdbids, "name" )
         chdbidArray.each{ |chdbid|
            if chdbid.has_text?
               dbid = chdbid.text
               getSchema( dbid )
               name = getResponseElement( "table/name" )
               if name and name.has_text?
                  if lowercaseOrUpperCase == "lowercase"
                     tableNames << name.text.downcase
                  elsif lowercaseOrUpperCase == "uppercase"
                     tableNames << name.text.upcase
                  else
                     tableNames << name.text.dup
                  end
               end
            end
         }
      end
      tableNames
    end

   # Get a list of the dbids of the child tables of an application.
   def getTableIDs(dbid)
      tableIDs = []
      dbid ||= @dbid
      getSchema(dbid)      
      if @chdbids
         chdbidArray = findElementsByAttributeName( @chdbids, "name" )
         chdbidArray.each{ |chdbid|
            if chdbid.has_text?
               tableIDs << chdbid.text
            end
         }
      end
      tableIDs
    end

   # Get the number of child tables of an application
   def getNumTables(dbid)
      numTables = 0
      dbid ||= @dbid
      if getSchema(dbid)      
        if @chdbids
           chdbidArray = findElementsByAttributeName( @chdbids, "name" )
           numTables = chdbidArray.length
         end
       end
      numTables       
  end     

   # Get a list of the names of the reports (i.e. queries) for a table.
    def getReportNames(dbid = @dbid)
        reportNames = []
        getSchema(dbid)
        if @queries
           queriesProc = proc { |element|
              if element.is_a?(REXML::Element)
                 if element.name == "qyname" and element.has_text?
                    reportNames << element.text
                 end
              end
           }
           processChildElements(@queries,true,queriesProc)
        end
        reportNames
    end  

   # Given a DBID, get the QuickBase realm it is in.
   def getRealmForDbid(dbid)
      @realm = nil
      if USING_HTTPCLIENT
         begin
            httpclient = HTTPClient.new
            resp = httpclient.get("https://www.quickbase.com/db/#{dbid}")
            location = resp.header['Location'][0]
            location.sub!("https://","")
	    parts = location.split(/\./)
	    @realm = parts[0]
         rescue StandardError => error
            @realm = nil 
         end
      else
         raise "Please get the HTTPClient gem: gem install httpclient" 
      end   
      @realm
   end	

   # Builds the XML for a specific item included in a request to QuickBase.
   def toXML( tag, value = nil )
      if value
         ret = "<#{tag}>#{value}</#{tag}>"
      else
         ret = "<#{tag}/>"
      end
      ret
   end

   # Returns whether a given string represents a valid QuickBase field type.
   def isValidFieldType?( type )
      @validFieldTypes ||= %w{ checkbox dblink date duration email file fkey float formula currency 
                  lookup multiuserid phone percent rating recordid text timeofday timestamp url userid icalendarbutton }
      @validFieldTypes.include?( type )
   end

  # Returns a field type string given the more human-friendly label for a field type.
  def fieldTypeForLabel( fieldTypeLabel )
    @fieldTypeLabelMap ||= Hash["Text","text","Numeric","float","Date / Time","timestamp","Date","date","Checkbox","checkbox","Database Link","dblink","Duration","duration","Email","email","File Attachment","file","Numeric-Currency","currency","Numeric-Rating","rating","Numeric-Percent","percent","Phone Number","phone","Relationship","fkey","Time Of Day","timeofday","URL","url","User","user","Record ID#","recordid","Report Link","dblink","iCalendar","icalendarbutton"]
    @fieldTypeLabelMap[fieldTypeLabel] 
  end  

   # Returns whether a given string represents a valid QuickBase field property.
   def isValidFieldProperty?( property )
      if @validFieldProperties.nil?
         @validFieldProperties = %w{ allow_new_choices allowHTML appears_by_default append_only
              blank_is_zero bold carrychoices comma_start cover_text currency_format currency_symbol
              decimal_places default_kind default_today default_today default_value display_dow 
              display_graphic display_month display_relative display_time display_today display_user display_zone 
              does_average does_total doesdatacopy exact fieldhelp find_enabled foreignkey format formula
              has_extension hours24 label max_versions maxlength nowrap num_lines required sort_as_given 
              source_fid source_fieldname target_dbid target_dbname target_fid target_fieldname unique units
              use_new_window width }
      end
      ret = @validFieldProperties.include?( property )
   end

   # Encapsulates field values to be set and file uploads to be made during addRecord() and editRecord() calls.
   class FieldValuePairXML

      attr_reader :parentClass

      def initialize( parentClass, name, fid, filename, value )

         @parentClass = parentClass

         name = name.downcase if name
         name = name.gsub( /\W/, "_" )  if name
 
         if filename or value
            @xml = "<field "
            if name
               @xml << "name='#{name}'"
            elsif fid
               @xml << "fid='#{fid}'"
            else
               raise "FieldValuePairXML::initialize: must specify 'name' or 'fid'"
            end
            if filename
               @xml << " filename='#{verifyFilename(filename)}'"
            end
            if value
               if filename
                  value = encodeFileContentsForUpload( value )
               else
                  value = @parentClass.encodeXML( value )
               end
               @xml << ">#{value}</field>"
            elsif filename
               value = encodeFileContentsForUpload( filename )
               @xml << ">#{value}</field>"
            else
               @xml << "/>"
            end
         else
            raise "FieldValuePairXML::initialize: must specify 'filename' or 'value'"
         end
      end

      def verifyFilename( filename )
         if filename
            filename.slice!( 0, filename.rindex( '\\' )+1 ) if filename.include?( '\\' )
            filename.slice!( 0, filename.rindex( '/' )+1 ) if filename.include?( '/' )
            filename = @parentClass.encodeXML( filename )
         end
         filename
      end

      def encodeFileContentsForUpload( fileNameOrFileContents )
         if fileNameOrFileContents
            if FileTest.readable?( fileNameOrFileContents )
               f = File.new( fileNameOrFileContents, "r" )
               if f
                   encodedFileContents = ""
                   f.binmode
                   buffer = f.read(60)
                   while buffer
                     encodedFileContents << [buffer].pack('m').tr( "\r\n", '' )
                     buffer = f.read(60)
                   end
                   f.close
                   return encodedFileContents
              end
           elsif fileNameOrFileContents.is_a?( String )
              encodedFileContents = ""
              buffer = fileNameOrFileContents.slice!(0,60)
              while buffer and buffer.length > 0 
                 buffer = buffer.to_s
                 encodedFileContents << [buffer].pack('m').tr( "\r\n", '' )
                 buffer = fileNameOrFileContents.slice!(0,60)
              end
              return encodedFileContents
           end
        end
        nil
      end

      def to_s
         @xml
      end
   end

   # Adds a field value to the list of fields to be set by the next addRecord() or editRecord() call to QuickBase.
   # * name: label of the field value to be set.
   # * fid: id of the field to be set.
   # * filename: if the field is a file attachment field, the name of the file that should be displayed in QuickBase.
   # * value: the value to set in this field. If the field is a file attachment field, the name of the file that should be uploaded into QuickBase.
   def addFieldValuePair( name, fid, filename, value )
      @fvlist ||= []
      @fvlist << FieldValuePairXML.new( self, name, fid, filename, value ).to_s
      @fvlist
   end
   
   # Replaces a field value in the list of fields to be set by the next addRecord() or editRecord() call to QuickBase.
   def replaceFieldValuePair( name, fid, filename, value )
      if @fvlist
         name = name.downcase if name
         name = name.gsub( /\W/, "_" )  if name
         @fvlist.each_index{|i|
            if (name and @fvlist[i].include?("<field name='#{name}'")) or
               (fid and @fvlist[i].include?("<field fid='#{fid}'"))
               @fvlist[i] = FieldValuePairXML.new( self, name, fid, filename, value ).to_s
               break
            end
         } 
      end
      @fvlist
   end

   # Empty the list of field values used for the next addRecord() or editRecord() call to QuickBase.
   def clearFieldValuePairList
      @fvlist = nil
   end

   # Given an array of field names or field IDs and a table ID, builds an array of valid field IDs and field names.
   # Throws an exception when an invalid name or ID is encountered.
   def verifyFieldList( fnames, fids = nil, dbid = @dbid )
     getSchema( dbid )
     @fids = @fnames = nil

     if fids
        if fids.is_a?( Array ) and fids.length > 0
            fids.each { |id|
               fid = lookupField( id )
               if fid
                  fname = lookupFieldNameFromID( id )
                  @fnames ||= []
                  @fnames << fname
               else
                  raise "verifyFieldList: '#{id}' is not a valid field ID"
               end
            }
            @fids = fids
         else
            raise "verifyFieldList: fids must be an array of one or more field IDs"
         end
     elsif fnames
        if fnames.is_a?( Array ) and fnames.length > 0
         fnames.each { |name|
            fid = lookupFieldIDByName( name )
            if fid
               @fids ||= []
               @fids << fid
            else
               raise "verifyFieldList: '#{name}' is not a valid field name"
            end
         }
         @fnames = fnames
       else
         raise "verifyFieldList: fnames must be an array of one or more field names"
       end
     else
        raise "verifyFieldList: must specify fids or fnames"
     end
     @fids
   end

   # Builds the request XML for retrieving the results of a query.
   def getQueryRequestXML( query = nil, qid = nil, qname = nil )
      @query = @qid = @qname = nil
      if query
        @query = query == "" ? "{'0'.CT.''}" : query
        xmlRequestData = toXML( :query, @query )
      elsif qid
        @qid = qid
        xmlRequestData = toXML( :qid, @qid )
      elsif qname
        @qname = qname
        xmlRequestData = toXML( :qname, @qname )
      else
        @query = "{'0'.CT.''}"
        xmlRequestData = toXML( :query, @query )
      end
      xmlRequestData
   end
   
   # Returns the clist associated with a query.
   def getColumnListForQuery( id, name )
      clistForQuery = nil
      if id
         query = lookupQuery( id )
      elsif name
         query = lookupQueryByName( name )
      end
      if query and query.elements["qyclst"]
         clistForQuery = query.elements["qyclst"].text.dup
      end
      clistForQuery
   end
    
   alias getColumnListForReport getColumnListForQuery

   # Returns the slist associated with a query.
   def getSortListForQuery( id, name )
      slistForQuery = nil
      if id
         query = lookupQuery( id )
      elsif name
         query = lookupQueryByName( name )
      end
      if query and query.elements["qyslst"]
         slistForQuery = query.elements["qyslst"].text.dup
      end
      slistForQuery
   end
   
   alias getSortListForReport getSortListForQuery 

   # Returns the criteria associated with a query.
   def getCriteriaForQuery( id, name )
      criteriaForQuery = nil
      if id
         query = lookupQuery( id )
      elsif name
         query = lookupQueryByName( name )
      end
      if query and query.elements["qycrit"]
         criteriaForQuery = query.elements["qycrit"].text.dup
      end
      criteriaForQuery
   end
   
   alias getCriteriaForReport getCriteriaForQuery 

   # Returns a valid query operator.
   def verifyQueryOperator( operator, fieldType )
      queryOperator = ""

      if @queryOperators.nil?
         @queryOperators = {}
         @queryOperatorFieldType = {}

         @queryOperators[ "CT" ]  =  [ "contains", "[]" ]
         @queryOperators[ "XCT" ] = [ "does not contain", "![]" ]

         @queryOperators[ "EX" ]  = [ "is", "==", "eq" ]
         @queryOperators[ "TV" ]  = [ "true value" ]
         @queryOperators[ "XEX" ] = [ "is not", "!=", "ne" ]

         @queryOperators[ "SW" ]  =  [ "starts with" ]
         @queryOperators[ "XSW" ] = [ "does not start with" ]

         @queryOperators[ "BF" ]  = [ "is before", "<" ]
         @queryOperators[ "OBF" ] = [ "is on or before", "<=" ]
         @queryOperators[ "AF" ]  = [ "is after", ">" ]
         @queryOperators[ "OAF" ] = [ "is on or after", ">=" ]

         @queryOperatorFieldType[ "BF" ] = [ "date" ]
         @queryOperatorFieldType[ "OBF" ] = [ "date" ]
         @queryOperatorFieldType[ "ABF" ] = [ "date" ]
         @queryOperatorFieldType[ "OAF" ] = [ "date" ]

         @queryOperators[ "LT" ]  = [ "is less than", "<" ]
         @queryOperators[ "LTE" ]  = [ "is less than or equal to", "<=" ]
         @queryOperators[ "GT" ]  = [ "is greater than", ">" ]
         @queryOperators[ "GTE" ]  = [ "is greater than or equal to", ">=" ]
      end

      upcaseOperator = operator.upcase
      @queryOperators.each { |queryop,aliases|
        if queryop == upcaseOperator
           if @queryOperatorFieldType[ queryop ] and @queryOperatorFieldType[ queryop ].include?( fieldType )
              queryOperator = upcaseOperator
              break
           else
              queryOperator = upcaseOperator
              break
           end
        else
          aliases.each  { |a|
            if a == upcaseOperator
               if @queryOperatorFieldType[ queryop ] and @queryOperatorFieldType[ queryop ].include?( fieldType )
                  queryOperator = queryop
                  break
               else
                  queryOperator = queryop
                  break
               end
            end
          }
        end
      }
      queryOperator
   end

   # Get a field's base type using its name.
   def lookupBaseFieldTypeByName( fieldName )
      type = ""
      fid = lookupFieldIDByName( fieldName )
      field = lookupField( fid ) if fid
      type = field.attributes[ "base_type" ] if field
      type
   end

   # Get a field's type using its name.
   def lookupFieldTypeByName( fieldName )
      type = ""
      fid = lookupFieldIDByName( fieldName )
      field = lookupField( fid ) if fid
      type = field.attributes[ "field_type" ] if field
      type
   end

   # Returns the string required for emebedding CSV data in a request.
   def formatImportCSV( csv )
      "<![CDATA[#{csv}]]>"
   end

   # Returns the human-readable string represntation of a date, given the
   # milliseconds version of the date.  Also needed for requests to QuickBase.
   def formatDate( milliseconds, fmtString = nil, addDay = false )
      fmt = ""
      fmtString = "%m-%d-%Y" if fmtString.nil?
      if milliseconds
         milliseconds_s = milliseconds.to_s
         if milliseconds_s.length == 13
            t = Time.at( milliseconds_s[0,10].to_i,  milliseconds_s[10,3].to_i )
            t += (60 * 60 * 24) if addDay
            fmt = t.strftime(  fmtString )
         elsif milliseconds_s.length > 0
            t = Time.at( (milliseconds_s.to_i) / 1000 )
            t += (60 * 60 * 24) if addDay
            fmt = t.strftime(  fmtString )
         end
      end
      fmt
   end

   # Converts milliseconds to hours and returns the value as a string.
   def formatDuration( value, option = "hours" )
      option = "hours" if option.nil?
      if value.nil?
         value = ""
      else   
         seconds = (value.to_i/1000)
         minutes = (seconds/60)
         hours = (minutes/60)
         days = (hours/24)
         if option == "days"
            value = days.to_s
         elsif option == "hours"
            value = hours.to_s
         elsif option == "minutes"
            value = minutes.to_s
         end
      end
      value
   end

   # Returns a string format for a time of day value.
   def formatTimeOfDay(milliseconds, format = "%I:%M %p" )
      format ||= "%I:%M %p"
      timeOfDay = ""
      timeOfDay = Time.at(milliseconds.to_i/1000).utc.strftime(format) if milliseconds
   end
   
   # Returns a string formatted for a currency value.
   def formatCurrency( value, options = nil )
      value ||= "0.00"
      if !value.include?( '.' )
         value << ".00"
      end
      
      currencySymbol = currencyFormat = nil
      if options
         currencySymbol = options["currencySymbol"]
         currencyFormat = options["currencyFormat"]
      end
      
      if currencySymbol
         if currencyFormat
            if currencyFormat == "0"
               value = "#{currencySymbol}#{value}"
            elsif currencyFormat == "1"
               if value.include?("-")
                  value.gsub!("-","-#{currencySymbol}")
               elsif value.include?("+")
                  value.gsub!("+","+#{currencySymbol}")
               else   
                  value = "#{currencySymbol}#{value}"
               end
            elsif currencyFormat == "2"
               value = "#{value}#{currencySymbol}"
            end
         else
            value = "#{currencySymbol}#{value}"
         end
      end
      
      value
   end
   
   # Returns a string formatted for a percent value, given the data from QuickBase
   def formatPercent( value, options = nil )
      if value
         percent = (value.to_f * 100)
         value = percent.to_s
         if value.include?(".")
            int,fraction = value.split('.')
            if fraction.to_i == 0
               value = int
            else
               value = "#{int}.#{fraction[0,2]}"
            end            
         end         
      else
         value = "0"
      end
      value
   end

   # Returns the milliseconds representation of a date specified in mm-dd-yyyy format.
   def dateToMS( dateString )
      milliseconds = 0
      if dateString and dateString.match( /[0-9][0-9]\-[0-9][0-9]\-[0-9][0-9][0-9][0-9]/)
         d = Date.new( dateString[7,4], dateString[4,2], dateString[0,2] )
         milliseconds = d.jd
      end
      milliseconds
   end

   # Converts a string into an array, given a field separator.
   # '"' followed by the field separator are treated the same way as just the field separator.
   def splitString( string, fieldSeparator = "," )
      ra = []
      string.chomp!
      if string.include?( "\"" )
         a=string.split( "\"#{fieldSeparator}" )
         a.each{ |b| c=b.split( "#{fieldSeparator}\"" )
            c.each{ |d|
               ra << d
            }
         }
      else
         ra = string.split( fieldSeparator )
      end
      ra
   end

   # Returns the URL-encoded version of a non-printing character.
   def escapeXML( char )
      if @xmlEscapes.nil?
         @xmlEscapes = {}
         (0..255).each{ |i| @xmlEscapes[ i.chr ] = sprintf( "&#%03d;", i )  }
      end
      return @xmlEscapes[ char ] if @xmlEscapes[ char ]
      char
   end

   # Returns the list of string substitutions to make to encode or decode field values used in XML.
   def encodingStrings( reverse = false )
      @encodingStrings  = [ {"&" => "&amp;" },  {"<" => "&lt;"} , {">" => "&gt;"}, {"'" => "&apos;"}, {"\"" => "&quot;" }  ] if @encodingStrings.nil?
      if block_given?
         if reverse
            @encodingStrings.reverse_each{ |s| s.each{|k,v| yield v,k } }
         else
            @encodingStrings.each{ |s| s.each{|k,v| yield k,v }  }
         end
      else
         @encodingStrings
      end
   end

   # Modify the given string for use as a XML field value.
   def encodeXML( text, doNPChars = false )
      encodingStrings { |key,value| text.gsub!( key, value ) if text }
      text.gsub!( /([^;\/?:@&=+\$,A-Za-z0-9\-_.!~*'()# ])/ ) { |c| escapeXML( $1 ) } if text and doNPChars
      text
   end

   # Modify the given XML field value for use as a string.
   def decodeXML( text )
      encodingStrings( true ) { |key,value| text.gsub!( value, key ) if text }
      text.gsub!( /&#([0-9]{2,3});/ ) { |c| $1.chr } if text
      text
   end

   # Called when a response is returned from QuickBase.
   # Subscribers listening for onSetActiveTable, onSetActiveRecord, onSetActiveField events 
   # will be notified if the 'active' table, record, or field changes.
   def fireDBChangeEvents()

      if @dbid and @prev_dbid != @dbid
         resetrid
         resetfid
         fire( "onSetActiveTable" )
      end
      @prev_dbid = @dbid

      if @rid and @prev_rid != @rid
         resetfid
         fire( "onSetActiveRecord" )
      end
      @prev_rid = @rid

      if @fid and @prev_fid != @fid
         fire( "onSetActiveField" )
      end
      @prev_fid = @fid

   end
   private :fireDBChangeEvents

   # Set the @rid ('active' record ID) member variable to nil.
   def resetrid
      @rid = nil
   end

   # Set the @fid ('active' field ID) member variable to nil.
   def resetfid
      @fid = nil
   end

   # Reset appropriate member variables after a different table is accessed.
   def onChangedDbid
      _getDBInfo
      _getSchema
      resetrid
      resetfid
   end

   # Called by client methods to notify event subscribers
   def fire( event )
      if @eventSubscribers and @eventSubscribers.include?( event )
         handlers = @eventSubscribers[ event ]
         if handlers
            handlers.each{ |handler| handler.handle( event ) }
         end
      end
   end
   private :fire

   # Subscribe to a specified event published by QuickBase::Client.
   def subscribe( event, handler )

      @events = %w{ onSendRequest onProcessResponse onSetActiveTable
                    onRequestSucceeded onRequestFailed onSetActiveRecord
                    onSetActiveField } if @events.nil?

      if @events.include?( event )
         if handler and handler.is_a?( EventHandler )
            if @eventSubscribers.nil?
               @eventSubscribers = {}
            end
            if not @eventSubscribers.include?( event )
               @eventSubscribers[ event ] = []
            end
            if not @eventSubscribers[ event ].include?( handler )
               @eventSubscribers[ event ] << handler
            end
         else
            raise "subscribe: 'handler' must be a class derived from QuickBase::EventHandler."
         end
      else
         raise "subscribe: invalid event '#{event}'.  Valid events are #{@events.sort.join( ', ' )}."
      end
   end

   # Set the instance of a QuickBase::Logger to be used by QuickBase::Client.
   # Closes the open log file if necessary.
   def setLogger( logger )
      if logger
         if logger.is_a?( Logger )
            if @logger and @logger != logger
               @logger.closeLogFile()
            end
            @logger = logger
         end
      else
         @logger.closeLogFile() if @logger
         @logger = nil
      end
   end

   #------------------------------------------------------------------------------------
   # ------------------------------ API_ wrapper methods. --------------------------
   # Each method expects the 'Input Parameters' of the equivalent HTTP API request.
   # Each method returns the 'Output Parameters' of the equivalent HTTP API response.
   # (Ruby methods can return multiple values)
   # Input and Output Parameters are all stored in '@' member variables.
   # This makes it easy to reuse parameters across multiple requests.
   #  Methods returning lists can be called with an iteration block, e.g. doQuery(){|record|, puts record } .
   #
   #  Each method with dbid as the first parameter has a corresponding method with '_' before the name.
   #  The '_' methods re-use @dbid instead of a requiring the dbid parameter.
   # ------------------------------------------------------------------------------------
   
   # API_AddField
   def addField( dbid, label, type, mode = nil )

      @dbid, @label, @type, @mode = dbid, label, type, mode

      if isValidFieldType?( type )
         xmlRequestData = toXML( :label, @label ) + toXML( :type, @type )
         xmlRequestData << toXML( :mode, mode ) if mode

         sendRequest( :addField, xmlRequestData )

         @fid = getResponseValue( :fid )
         @label = getResponseValue( :label )

         return self if @chainAPIcalls
         return @fid, @label
      else
         raise "addField: Invalid field type '#{type}'.  Valid types are " + @validFieldTypes.join( "," )
      end
   end
    
   # API_AddField, using the active table id.
   def _addField( label, type, mode = nil ) addField( @dbid, label, type, mode )  end

   # API_AddRecord
   def addRecord(  dbid, fvlist = nil, disprec = nil, fform = nil, ignoreError = nil, update_id = nil, msInUTC =nil )

      @dbid, @fvlist, @disprec, @fform, @ignoreError, @update_id, @msInUTC = dbid, fvlist, disprec, fform, ignoreError, update_id, msInUTC
      setFieldValues( fvlist, false ) if fvlist.is_a?(Hash) 

      xmlRequestData = ""
      if @fvlist and @fvlist.length > 0
         @fvlist.each{ |fv| xmlRequestData << fv } #see addFieldValuePair, clearFieldValuePairList, @fvlist
      end
      xmlRequestData << toXML( :disprec, @disprec ) if @disprec
      xmlRequestData << toXML( :fform, @fform ) if @fform
      xmlRequestData << toXML( :ignoreError, "1" ) if @ignoreError
      xmlRequestData << toXML( :update_id, @update_id ) if @update_id
      xmlRequestData << toXML( :msInUTC, "1" ) if @msInUTC
      xmlRequestData = nil if xmlRequestData.length == 0

      sendRequest( :addRecord, xmlRequestData )

      @rid = getResponseValue( :rid )
      @update_id = getResponseValue( :update_id )

      return self if @chainAPIcalls
      return @rid, @update_id
    end
    
   # API_AddRecord, using the active table id. 
   def _addRecord( fvlist = nil, disprec = nil, fform = nil, ignoreError = nil, update_id = nil )
      addRecord( @dbid, fvlist, disprec, fform, ignoreError, update_id )
   end

   # API_AddReplaceDBPage
   def addReplaceDBPage( dbid, pageid, pagename, pagetype, pagebody, ignoreError = nil )

      @dbid, @pageid, @pagename, @pagetype, @pagebody, @ignoreError = dbid, pageid, pagename, pagetype, pagebody, ignoreError

      if pageid
         xmlRequestData = toXML( :pageid, @pageid )
      elsif pagename
         xmlRequestData = toXML( :pagename, @pagename )
      else
         raise "addReplaceDBPage: missing pageid or pagename"
      end

      xmlRequestData << toXML( :pagetype, @pagetype )
      xmlRequestData << toXML( :pagebody, encodeXML( @pagebody ) )
      xmlRequestData << toXML( :ignoreError, "1" ) if @ignoreError

      sendRequest( :addReplaceDBPage, xmlRequestData )

      @pageid = getResponseValue( :pageid )
      @pageid ||= getResponseValue( :pageID ) # temporary

      return self if @chainAPIcalls
      @pageid
    end
    
   # API_AddReplaceDBPage, using the active table id.
   def _addReplaceDBPage( *args ) addReplaceDBPage( @dbid, args ) end

   # API_AddUserToRole
   def addUserToRole( dbid, userid, roleid )
      @dbid, @userid, @roleid  = dbid, userid, roleid 

      xmlRequestData = toXML( :userid, @userid ) 
      xmlRequestData << toXML( :roleid, @roleid ) 
      
      sendRequest( :addUserToRole, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
    end

    # API_AddUserToRole, using the active table id. 
    def _addUserToRole( userid, roleid ) addUserToRole( @dbid, userid, roleid ) end
   
   # API_AssertFederatedIdentity (IPP only)
   def assertFederatedIdentity( dbid, serviceProviderID, targetURL )
     @dbid, @serviceProviderID, @targetURL = dbid, serviceProviderID, targetURL
     
      xmlRequestData = toXML( :serviceProviderID, @serviceProviderID ) 
      xmlRequestData << toXML( :targetURL, @targetURL ) 
      
      sendRequest( :assertFederatedIdentity, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  
    
   # API_AttachIDSRealm (IPP only) 
   def attachIDSRealm( dbid, realm )
     @dbid, @realm = dbid, realm 
     
      xmlRequestData = toXML( :realm, @realm ) 
      
      sendRequest( :attachIDSRealm, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end

   # API_DetachIDSRealm (IPP only) 
   def detachIDSRealm( dbid, realm )
     @dbid, @realm = dbid, realm 
     
      xmlRequestData = toXML( :realm, @realm ) 
      
      sendRequest( :detachIDSRealm, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end

   # API_DeleteAppZip
   def deleteAppZip( dbid )
     @dbid = dbid
     sendRequest( :deleteAppZip )
     return self if @chainAPIcalls
     @responseCode
   end 

  # API_DumpAppZip
   def dumpAppZip( dbid )
     @dbid = dbid
     @noredirect = true
     xmlRequestData = toXML( :noredirect, "1" )
     sendRequest( :dumpAppZip, xmlRequestData )
     return self if @chainAPIcalls
     @responseCode
   end 

   # API_GetIDSRealm (IPP only) 
   def getIDSRealm( dbid )
     @dbid = dbid 
      
      sendRequest( :getIDSRealm )
      @realm = getResponseValue( :realm)
      
      return self if @chainAPIcalls
      @realm
   end

   # API_Authenticate
   def authenticate( username, password, hours = nil )

      @username, @password, @hours = username, password, hours

      if username and password

         @ticket = nil
         if @hours
            xmlRequestData = toXML( :hours, @hours )
            sendRequest( :authenticate, xmlRequestData )
         else
            sendRequest( :authenticate )
         end
          
         @userid = getResponseValue( :userid )
         return self if @chainAPIcalls
         return @ticket, @userid

      elsif username or password
         raise "authenticate: missing username or password"
      elsif @ticket
         raise "authenticate: #{username} is already authenticated"
      end
   end

   # API_ChangePermission (appears to be deprecated)
   def changePermission( dbid, uname, view, modify, create, delete, saveviews, admin )

      raise "changePermission: API_ChangePermission is no longer a valid QuickBase HTTP API request."

      @dbid, @uname, @view, @modify, @create, @delete, @saveviews, @admin = dbid, uname, view, modify, create, delete, saveviews, admin

      xmlRequestData = toXML( :dbid, @dbid )
      xmlRequestData << toXML( :uname, @uname )

      viewModifyPermissions = %w{ none any own group }

      if @view
         if viewModifyPermissions.include?( @view )
            xmlRequestData << toXML( :view, @view )
         else
            raise "changePermission: view must be one of " + viewModifyPermissions.join( "," )
         end
      end

      if @modify
         if viewModifyPermissions.include?( @modify )
            xmlRequestData << toXML( :modify, @modify )
         else
            raise "changePermission: modify must be one of " + viewModifyPermissions.join( "," )
         end
      end

      xmlRequestData << toXML( :create, @create ) if @create
      xmlRequestData << toXML( :delete, @delete ) if @delete
      xmlRequestData << toXML( :saveviews, @saveviews ) if @saveviews
      xmlRequestData << toXML( :admin, @admin ) if @admin

      sendRequest( :changePermission, xmlRequestData )

      # not sure the API reference is correct about these return values
      @username = getResponseValue( :username )
      @view = getResponseValue( :view )
      @modify =  getResponseValue( :modify )
      @create =  getResponseValue( :create )
      @delete = getResponseValue( :delete )
      @saveviews = getResponseValue( :saveviews )
      @admin = getResponseValue( :admin )

      @rolename = getResponseValue( :rolename )

      return self if @chainAPIcalls
      return @username, @view, @modify, @create, @delete, @saveviews, @admin, @rolename
    end
    
   # API_ChangePermission (appears to be deprecated), using the active table id. 
   def _changePermission( *args ) changePermission( @dbid, args ) end

   # API_ChangeRecordOwner
   def changeRecordOwner( dbid, rid, newowner )

      @dbid, @rid, @newowner = dbid, rid, newowner

      xmlRequestData = toXML( :dbid, @dbid )
      xmlRequestData << toXML( :rid, @rid )
      xmlRequestData << toXML( :newowner, @newowner )

      sendRequest( :changeRecordOwner, xmlRequestData )

      return self if @chainAPIcalls
      @requestSucceeded
   end
    
   # API_ChangeRecordOwner
   def _changeRecordOwner( rid, newowner ) changeRecordOwner( @dbid, rid, newowner ) end

   # API_ChangeUserRole. 
   def changeUserRole( dbid, userid, roleid, newroleid )
      @dbid, @userid, @roleid, @newroleid = dbid, userid, roleid, newroleid
      
      xmlRequestData = toXML( :userid, @userid )
      xmlRequestData << toXML( :roleid, @roleid )
      xmlRequestData << toXML( :newroleid, @newroleid )
      
      sendRequest( :changeUserRole, xmlRequestData )

      return self if @chainAPIcalls
      @requestSucceeded
    end
    
   # API_ChangeUserRole, using the active table id. 
   def _changeUserRole( userid, roleid, newroleid ) changeUserRole( @dbid, userid, roleid, newroleid )  end

   # API_CloneDatabase
   def cloneDatabase( dbid, newdbname, newdbdesc, keepData, asTemplate = nil, usersAndRoles = nil )

      @dbid, @newdbname, @newdbdesc, @keepData, @asTemplate, @usersAndRoles = dbid, newdbname, newdbdesc, keepData, asTemplate, usersAndRoles
      
      @keepData = "1" if @keepData.to_s == "true" 
      @keepData = "0" if @keepData != "1"

      xmlRequestData = toXML( :newdbname, @newdbname )
      xmlRequestData << toXML( :newdbdesc, @newdbdesc )
      xmlRequestData << toXML( :keepData, @keepData )
      xmlRequestData << toXML( :asTemplate, @asTemplate ) if @asTemplate
      xmlRequestData << toXML( :usersAndRoles, @usersAndRoles ) if @usersAndRoles

      sendRequest( :cloneDatabase, xmlRequestData )

      @newdbid = getResponseValue( :newdbid )

      return self if @chainAPIcalls
      @newdbid
    end
    
   # API_CloneDatabase, using the active table id. 
   def _cloneDatabase( *args ) cloneDatabase( @dbid, args ) end

   # API_CopyMasterDetail
   def copyMasterDetail( dbid, destrid, sourcerid, copyfid = nil, recurse = nil, relfids = nil )
      
      raise "copyfid must be specified when destrid is 0." if destrid == "0" and copyfid.nil?
      
      @dbid, @destrid, @sourcerid, @copyfid, @recurse, @relfids = dbid, destrid, sourcerid, copyfid, recurse, relfids
 
      xmlRequestData = toXML( :destrid, @destrid)
      xmlRequestData << toXML( :sourcerid, @sourcerid )
      xmlRequestData << toXML( :copyfid, @copyfid ) if @copyfid
      xmlRequestData << toXML( :recurse, @recurse ) if @recurse
      xmlRequestData << toXML( :relfids, @relfids ) if @relfids

      sendRequest( :copyMasterDetail, xmlRequestData )

      @parentrid = getResponseValue( :parentrid )
      @numCreated = getResponseValue( :numCreated )

      return self if @chainAPIcalls
      return @parentrid, @numCreated
   end	   
   
   # API_CopyMasterDetail, using the active table id. 
   def _copyMasterDetail( *args ) copyMasterDetail( @dbid, args ) end

   # API_CreateDatabase
   def createDatabase( dbname, dbdesc, createapptoken = "1" )

      @dbname, @dbdesc, @createapptoken = dbname, dbdesc, createapptoken

      xmlRequestData = toXML( :dbname, @dbname )
      xmlRequestData << toXML( :dbdesc, @dbdesc )
      xmlRequestData << toXML( :createapptoken, @createapptoken )

      sendRequest( :createDatabase, xmlRequestData )

      @dbid = getResponseValue( :dbid )
      @appdbid = getResponseValue( :appdbid )
      @apptoken = getResponseValue( :apptoken )

      return self if @chainAPIcalls
      return @dbid, @appdbid
   end

   # API_CreateTable
   def createTable( tname, pnoun, application_dbid = @dbid )
      @tname, @pnoun, @dbid = tname, pnoun, application_dbid

      xmlRequestData = toXML( :tname, @tname )
      xmlRequestData << toXML( :pnoun, @pnoun )
      sendRequest( :createTable, xmlRequestData )

      @newdbid  = getResponseValue( :newdbid ) 
      @newdbid  ||= getResponseValue( :newDBID ) #temporary
      @dbid = @newdbid 

      return self if @chainAPIcalls
      @newdbid 
   end

   # API_DeleteDatabase
   def deleteDatabase( dbid )
      @dbid = dbid

      sendRequest( :deleteDatabase )

      @dbid = @rid = nil

      return self if @chainAPIcalls
      @requestSucceeded
   end

   # API_DeleteDatabase, using the active table id. 
   def _deleteDatabase() deleteDatabase( @dbid ) end

   # API_DeleteField
   def deleteField( dbid, fid )
      @dbid, @fid = dbid, fid

      xmlRequestData = toXML( :fid, @fid )
      sendRequest( :deleteField, xmlRequestData )

      return self if @chainAPIcalls
      @requestSucceeded
    end
    
   # API_DeleteField, using the active table id. 
   def _deleteField( fid ) deleteField( @dbid, fid ) end

   # Delete a field, using its name instead of its id. Uses the active table id. 
   def _deleteFieldName( fieldName )
      if @dbid and @fields
         @fid = lookupFieldIDByName( fieldName )
         if @fid
            deleteField( @dbid, @fid )
         end
      end
      nil
   end

   # API_DeleteRecord
   def deleteRecord( dbid, rid )
      @dbid, @rid = dbid, rid

      xmlRequestData = toXML( :rid, @rid )
      sendRequest( :deleteRecord, xmlRequestData )

      return self if @chainAPIcalls
      @requestSucceeded
    end
    
   # API_DeleteRecord, using the active table id. 
   def _deleteRecord( rid ) deleteRecord( @dbid, rid ) end

   # API_DoQuery
   def doQuery( dbid, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil  )

      @dbid, @clist, @slist, @fmt, @options = dbid, clist, slist, fmt, options
      
      @clist ||= getColumnListForQuery(qid, qname)
      @slist ||= getSortListForQuery(qid, qname)
      
      xmlRequestData = getQueryRequestXML( query, qid, qname )
      xmlRequestData << toXML( :clist, @clist ) if @clist
      xmlRequestData << toXML( :slist, @slist ) if @slist
      xmlRequestData << toXML( :fmt, @fmt ) if @fmt
      xmlRequestData << toXML( :options, @options ) if @options

      sendRequest( :doQuery, xmlRequestData )

      if @fmt and @fmt == "structured"
         @records = getResponseElement( "table/records" )
         @fields = getResponseElement( "table/fields" )
         @chdbids = getResponseElement( "table/chdbids" )
         @queries = getResponseElement( "table/queries" )
         @variables = getResponseElement( "table/variables" )
      else
         @records = getResponseElements( "qdbapi/record" )
         @fields = getResponseElements( "qdbapi/field" )
         @chdbids = getResponseElements( "qdbapi/chdbid" )
         @queries = getResponseElements( "qdbapi/query" )
         @variables = getResponseElements( "qdbapi/variable" )
      end

      return self if @chainAPIcalls

      if block_given?
         if @records 
            @records.each { |element|  yield element }
         else
             yield nil
         end  
      else
         @records
      end

   end
   
   # API_DoQuery, using the active table id. 
   def _doQuery( *args  ) doQuery( @dbid, args ) end
   
   # Runs API_DoQuery using the name of a query.  Uses the active table id .
   def _doQueryName( queryName ) doQuery( @dbid, nil, nil, queryName ) end

   # version of doQuery that takes a Hash of parameters 
   def _doQueryHash( doQueryOptions )
     doQueryOptions ||= {}
     raise "options must be a Hash" unless doQueryOptions.is_a?(Hash)
     doQueryOptions["dbid"] ||= @dbid
     doQueryOptions["fmt"] ||= "structured"
     doQuery( doQueryOptions["dbid"], 
                   doQueryOptions["query"],
                   doQueryOptions["qid"], 
                   doQueryOptions["qname"], 
                   doQueryOptions["clist"], 
                   doQueryOptions["slist"], 
                   doQueryOptions["fmt"], 
                   doQueryOptions["options"] )
   end
                 
   # API_DoQueryCount
   def doQueryCount( dbid, query )
      @dbid, @query = dbid, query
      
      xmlRequestData = toXML( :query, @query )
      
      sendRequest( :doQueryCount, xmlRequestData )

      @numMatches = getResponseValue( :numMatches )

      return self if @chainAPIcalls
     @numMatches
   end     
   
   # API_DoQueryCount, using the active table id. 
   def _doQueryCount( query ) doQueryCount( @dbid, query ) end

   # Download a file's contents from a file attachment field in QuickBase.
   # You must write the contents to disk before a local file exists.
   def downLoadFile( dbid, rid, fid, vid = "0" )

      @dbid, @rid, @fid, @vid = dbid, rid, fid, vid

      @downLoadFileURL = "http://#{@org}.#{@domain}.com/up/#{dbid}/a/r#{rid}/e#{fid}/v#{vid}"
      
      if @useSSL
         @downLoadFileURL.gsub!( "http:", "https:" )
      end

      @requestHeaders = { "Cookie"  => "ticket=#{@ticket}" }

      if @printRequestsAndResponses
         puts
         puts "downLoadFile request: -------------------------------------"
         p @downLoadFileURL
         p @requestHeaders
      end

      begin

         if USING_HTTPCLIENT
            @responseCode = 404
            @fileContents = @httpConnection.get_content( @downLoadFileURL, nil, @requestHeaders ) 
            @responseCode = 200 if @fileContents
         else  
            @responseCode, @fileContents = @httpConnection.get( @downLoadFileURL, @requestHeaders )
         end
    
      rescue Net::HTTPBadResponse => @lastError
      rescue Net::HTTPHeaderSyntaxError => @lastError
      rescue StandardError => @lastError
      end

      if @printRequestsAndResponses
         puts
         puts "downLoadFile response: -------------------------------------"
         p @responseCode
         p @fileContents
      end

      return self if @chainAPIcalls
      return @responseCode, @fileContents
    end
    
   # Download a file's contents from a file attachment field in QuickBase.
   # You must write the contents to disk before a local file exists.
   # Uses the active table id. 
   def _downLoadFile( rid, fid, vid = "0" ) downLoadFile( @dbid, rid, fid, vid ) end

   alias downloadFile downLoadFile
   alias _downloadFile _downLoadFile
   
   # Download and save a file from a file attachment field in QuickBase.
   # Use the filename parameter to override the file name from QuickBase.
   def downloadAndSaveFile( dbid, rid, fid, filename = nil, vid = "0"  )
      response, fileContents = downLoadFile( dbid, rid, fid, vid )
      if fileContents and fileContents.length > 0
         if filename and filename.length > 0
            Misc.save_file( filename, fileContents )
         else
            record = getRecord( rid, dbid, [fid] )
            if record and record[fid] and record[fid].length > 0
               Misc.save_file( record[fid], fileContents )
            else
               Misc.save_file( "#{dbid}_#{rid}_#{fid}", fileContents )
            end
         end
      end
   end
   
   # API_EditRecord
   def editRecord( dbid, rid, fvlist, disprec = nil, fform = nil, ignoreError = nil, update_id = nil, msInUTC =nil, key = nil )

      @dbid, @rid, @fvlist, @disprec, @fform, @ignoreError, @update_id, @msInUTC, @key = dbid, rid, fvlist, disprec, fform, ignoreError, update_id, msInUTC, key
      setFieldValues( fvlist, false ) if fvlist.is_a?(Hash) 

      xmlRequestData = toXML( :rid, @rid ) if @rid
      xmlRequestData = toXML( :key, @key ) if @key
      @fvlist.each{ |fv| xmlRequestData << fv } #see addFieldValuePair, clearFieldValuePairList, @fvlist
      xmlRequestData << toXML( :disprec, @disprec ) if @disprec
      xmlRequestData << toXML( :fform, @fform ) if @fform
      xmlRequestData << toXML( :ignoreError, "1" ) if @ignoreError
      xmlRequestData << toXML( :update_id, @update_id ) if @update_id
      xmlRequestData << toXML( :msInUTC, "1" ) if @msInUTC

      sendRequest( :editRecord, xmlRequestData )

      @rid = getResponseValue( :rid )
      @update_id = getResponseValue( :update_id )

      return self if @chainAPIcalls
      return @rid, @update_id
   end

   # API_EditRecord, using the active table id. 
   def _editRecord( *args  ) editRecord( @dbid, args ) end

   # API_FieldAddChoices
   # The choice parameter can be one choice string or an array of choice strings.
   def fieldAddChoices( dbid, fid, choice )

      @dbid, @fid, @choice = dbid, fid, choice

      xmlRequestData = toXML( :fid, @fid )

      if @choice.is_a?( Array )
         @choice.each { |c| xmlRequestData << toXML( :choice, c ) }
      elsif @choice.is_a?( String )
         xmlRequestData << toXML( :choice, @choice )
      end

      sendRequest( :fieldAddChoices, xmlRequestData )

      @fid = getResponseValue( :fid )
      @fname = getResponseValue( :fname )
      @numadded = getResponseValue( :numadded )

      return self if @chainAPIcalls
      return @fid, @name, @numadded
   end

   # API_FieldAddChoices, using the active table id. 
   def _fieldAddChoices( fid, choice ) fieldAddChoices( @dbid, fid, choice ) end

   # Runs API_FieldAddChoices using a field name instead ofa field id.  Uses the active table id.
   # Expects getSchema to have been run.    
   def _fieldNameAddChoices( fieldName, choice )
      if fieldName and choice and @fields
         @fid = lookupFieldIDByName( fieldName )
         fieldAddChoices( @dbid, @fid, choice )
      end
      nil
   end

   # API_FieldRemoveChoices
   # The choice parameter can be one choice string or an array of choice strings.
   def fieldRemoveChoices( dbid, fid, choice )

      @dbid, @fid, @choice = dbid, fid, choice

      xmlRequestData = toXML( :fid, @fid )

      if @choice.is_a?( Array )
         @choice.each { |c| xmlRequestData << toXML( :choice, c ) }
      elsif @choice.is_a?( String )
         xmlRequestData << toXML( :choice, @choice )
      end

      sendRequest( :fieldRemoveChoices, xmlRequestData )

      @fid = getResponseValue( :fid )
      @fname = getResponseValue( :fname )
      @numremoved = getResponseValue( :numremoved )

      return self if @chainAPIcalls
      return @fid, @name, @numremoved
   end

   # API_FieldRemoveChoices, using the active table id. 
   def _fieldRemoveChoices( fid, choice ) fieldRemoveChoices( @dbid, fid, choice ) end

   # Runs API_FieldRemoveChoices using a field name instead of a field id.  Uses the active table id.
   def _fieldNameRemoveChoices( fieldName, choice )
      if fieldName and choice and @fields
         @fid = lookupFieldIDByName( fieldName )
         fieldRemoveChoices( @dbid, @fid, choice )
      end
      nil
   end
    
   # API_FindDBByname
   def findDBByname( dbname )
      @dbname = dbname
      xmlRequestData = toXML( :dbname, @dbname )

      sendRequest( :findDBByname, xmlRequestData )
      @dbid = getResponseValue( :dbid )

      return self if @chainAPIcalls
      @dbid
   end
   alias findDBByName findDBByname

   # API_GenAddRecordForm
   def genAddRecordForm( dbid, fvlist = nil )

      @dbid, @fvlist = dbid, fvlist
      setFieldValues( fvlist, false ) if fvlist.is_a?(Hash) 

      xmlRequestData = ""
      @fvlist.each { |fv| xmlRequestData << fv } if @fvlist #see addFieldValuePair, clearFieldValuePairList, @fvlist

      sendRequest( :genAddRecordForm, xmlRequestData )

      @HTML = @responseXML

      return self if @chainAPIcalls
      @HTML
   end

   # API_GenAddRecordForm, using the active table id. 
   def _genAddRecordForm( fvlist = nil ) genAddRecordForm( @dbid, fvlist ) end

   # API_GenResultsTable
   def genResultsTable( dbid, query = nil, clist = nil, slist = nil, jht = nil, jsa = nil, options = nil, qid = nil, qname = nil )

      @dbid, @query, @clist, @slist, @jht, @jsa, @options = dbid, query, clist, slist, jht, jsa, options

      @clist ||= getColumnListForQuery(qid, qname)
      @slist ||= getSortListForQuery(qid, qname)

      xmlRequestData = getQueryRequestXML( query, qid, qname )
      xmlRequestData << toXML( :clist, @clist ) if @clist
      xmlRequestData << toXML( :slist, @slist ) if @slist
      xmlRequestData << toXML( :jht, @jht ) if @jht
      xmlRequestData << toXML( :jsa, @jsa ) if @jsa
      xmlRequestData << toXML( :options, @options ) if @options

      sendRequest( :genResultsTable, xmlRequestData )

      @HTML = @responseXML

      return self if @chainAPIcalls
      @HTML
   end

   # API_GenResultsTable, using the active table id. 
   def _genResultsTable( *args ) genResultsTable( @dbid, args ) end
   
   # API_GetAncestorInfo
   def getAncestorInfo( dbid )
      @dbid = dbid

      sendRequest( :getAncestorInfo )
      
      @ancestorappid = getResponseValue( :ancestorappid )
      @oldestancestorappid = getResponseValue( :oldestancestorappid )
      @qarancestorappid = getResponseValue( :qarancestorappid )

      return self if @chainAPIcalls
      return @ancestorappid, @oldestancestorappid, @qarancestorappid
   end  

   def _getAncestorInfo() getAncestorInfo(@dbid) end

   # API_GetAppDTMInfo
   def getAppDTMInfo( dbid )
      @dbid = dbid

      sendRequest( :getAppDTMInfo )

      @requestTime = getResponseElement( "RequestTime" )
      @requestNextAllowedTime = getResponseElement( "RequestNextAllowedTime" )
      @app = getResponseElement( "app" )
      @lastModifiedTime = getResponsePathValue( "app/lastModifiedTime" )
      @lastRecModTime = getResponsePathValue( "app/lastRecModTime" )
      @tables = getResponseElement( :tables )

      return self if @chainAPIcalls

      if @app and @tables and block_given?
         @app.each { |element| yield element }
         @tables.each { |element| yield element }
      else
         return @app, @tables
      end
   end
   
   # API_GetAppDTMInfo, using the active table id. 
   def _getAppDTMInfo() getAppDTMInfo( @dbid ) end

   # API_GetBillingStatus
   def getBillingStatus( dbid )
      @dbid = dbid
      
      sendRequest( :getBillingStatus )
      
      @lastPaymentDate = getResponseValue( :lastPaymentDate ) 
      @status = getResponseValue( :status ) 
      
      return self if @chainAPIcalls
      return @lastPaymentDate, @status
    end  
    
   # API_GetBillingStatus, using the active table id. 
   def _getBillingStatus() getBillingStatus(@dbid) end

   # API_GetDBInfo
   def getDBInfo( dbid )

      @dbid = dbid
      sendRequest( :getDBInfo )

      @lastRecModTime = getResponseValue( :lastRecModTime )
      @lastModifiedTime = getResponseValue( :lastModifiedTime )
      @createdTime = getResponseValue( :createdTime )
      @lastAccessTime = getResponseValue( :lastAccessTime )
      @numRecords = getResponseValue( :numRecords )
      @mgrID = getResponseValue( :mgrID )
      @mgrName = getResponseValue( :mgrName )
      @dbname = getResponseValue( :dbname)
      @version = getResponseValue( :version)

      return self if @chainAPIcalls
      return @lastRecModTime, @lastModifiedTime, @createdTime, @lastAccessTime, @numRecords, @mgrID, @mgrName
   end

   # API_GetDBInfo, using the active table id. 
   def _getDBInfo() getDBInfo( @dbid ) end

   # API_GetDBPage
   def getDBPage( dbid, pageid, pagename = nil )

      @dbid, @pageid, @pagename = dbid, pageid, pagename

      xmlRequestData = nil
      if @pageid
         xmlRequestData = toXML( :pageid, @pageid )
      elsif @pagename
         xmlRequestData = toXML( :pagename, @pagename )
      else
         raise "getDBPage: missing pageid or pagename"
      end

      sendRequest( :getDBPage, xmlRequestData )

      @pagebody = getResponseElement( :pagebody )

      return self if @chainAPIcalls
      @pagebody
    end
    
   # API_GetDBPage, using the active table id. 
   def _getDBPage(  pageid, pagename = nil ) getDBPage( @dbid,  pageid, pagename ) end

   # API_GetDBVar
   def getDBvar( dbid, varname )
      @dbid, @varname = dbid, varname
      
      xmlRequestData = toXML( :varname, @varname )
      
      sendRequest( :getDBvar, xmlRequestData )
      
      @value = getResponseValue( :value )
      
      return self if @chainAPIcalls
      @value
    end
    
   # API_GetDBVar, using the active table id. 
   def _getDBvar( varname ) getDBvar( @dbid, varname ) end
     
   # API_GetEntitlementValues
   def getEntitlementValues( dbid )
      @dbid = dbid
      
      sendRequest( :getEntitlementValues )
      
      @productID = getResponseValue( :productID ) 
      @planName = getResponseValue( :planName ) 
      @planType = getResponseValue( :planType ) 
      @maxUsers = getResponseValue( :maxUsers ) 
      @currentUsers = getResponseValue( :currentUsers ) 
      @daysRemainingTrial = getResponseValue( :daysRemainingTrial )
      @entitlements = getResponseElement( :entitlements )
      
      return self if @chainAPIcalls
      return @productID, @planName, @planType, @maxUsers, @currentUsers, @daysRemainingTrial, @entitlements
   end

  # API_GetEntitlementValues, using the active table id. 
  def _getEntitlementValues() getEntitlementValues( @dbid ) end

   # API_GetFileAttachmentUsage
   def getFileAttachmentUsage( dbid )
      @dbid = dbid
      
      sendRequest( :getFileAttachmentUsage )
      
      @accountLimit = getResponseValue( :accountLimit )
      @accountUsage = getResponseValue( :accountUsage )
      @applicationLimit = getResponseValue( :applicationLimit )
      @applicationUsage = getResponseValue( :applicationUsage )

      return self if @chainAPIcalls
      return @accountLimit, @accountUsage, @applicationLimit, @applicationUsage
   end  

   # API_GetFileAttachmentUsage, using the active table id. 
   def _getFileAttachmentUsage() getFileAttachmentUsage( @dbid ) end

   # API_GetNumRecords
   def getNumRecords( dbid )
      @dbid = dbid

      sendRequest( :getNumRecords )
      @num_records = getResponseValue( :num_records )

      return self if @chainAPIcalls
      @num_records
   end
   
   # API_GetNumRecords, using the active table id. 
   def _getNumRecords() getNumRecords( @dbid ) end

   # API_GetOneTimeTicket
   def getOneTimeTicket()
      
      sendRequest( :getOneTimeTicket )
      
      @ticket = getResponseValue( :ticket )
      @userid = getResponseValue( :userid )
      
      return self if @chainAPIcalls
      return @ticket, @userid
    end
    
   # API_GetFileUploadToken
   def getFileUploadToken()
      
      sendRequest( :getFileUploadToken)
      
      @fileUploadToken = getResponseValue( :fileUploadToken )
      @userid = getResponseValue( :userid )
      
      return self if @chainAPIcalls
      return @fileUploadToken, @userid
    end

   # API_GetRecordAsHTML
   def getRecordAsHTML( dbid, rid, jht = nil, dfid = nil )

      @dbid, @rid, @jht, @dfid = dbid, rid, jht, dfid

      xmlRequestData = toXML( :rid, @rid )
      xmlRequestData << toXML( :jht, "1" ) if @jht
      xmlRequestData << toXML( :dfid, @dfid ) if @dfid

      sendRequest( :getRecordAsHTML, xmlRequestData )

      @HTML = @responseXML

      return self if @chainAPIcalls
      @HTML
    end
    
   # API_GetRecordAsHTML, using the active table id. 
   def _getRecordAsHTML( rid, jht = nil, dfid = nil ) getRecordAsHTML( @dbid, rid, jht, dfid ) end

   # API_GetRecordInfo
   def getRecordInfo( dbid, rid )

      @dbid, @rid = dbid, rid

      xmlRequestData = toXML( :rid , @rid )
      sendRequest( :getRecordInfo, xmlRequestData )

      @num_fields = getResponseValue( :num_fields )
      @update_id = getResponseValue( :update_id )
      @rid = getResponseValue( :rid )

      @field_data_list = getResponseElements( "qdbapi/field" )

      return self if @chainAPIcalls

      if block_given?
         @field_data_list.each { |field| yield field }
      else
         return @num_fields,  @update_id, @field_data_list
      end
   end
    
   # API_GetRecordInfo, using the active table id. 
   def _getRecordInfo( rid = @rid ) getRecordInfo( @dbid, rid ) end
   
   # API_GetRoleInfo
   def getRoleInfo( dbid )
      @dbid = dbid
      
      sendRequest( :getRoleInfo )
      
      @roles = getResponseElement( :roles )
      
      return self if @chainAPIcalls
      
      if block_given?
        role_list = getResponseElements( "qdbapi/roles/role" )
        if role_list
          role_list.each {|role| yield role}
        else
          yield nil
        end  
      else  
         @roles
       end
       
   end
     
   # API_GetRoleInfo, using the active table id. 
   def _getRoleInfo() getRoleInfo( @dbid ) end

   # API_GetSchema
   def getSchema( dbid )
      @dbid = dbid

      if @cacheSchemas and @cachedSchemas and @cachedSchemas[dbid]
         @responseXMLdoc = @cachedSchemas[dbid]
      else
         sendRequest( :getSchema )
         if @cacheSchemas and @requestSucceeded
            @cachedSchemas ||= {}
            @cachedSchemas[dbid] ||= @responseXMLdoc.dup
         end
      end

      @chdbids = getResponseElement( "table/chdbids" )
      @variables = getResponseElement( "table/variables" )
      @fields = getResponseElement( "table/fields" )
      @queries = getResponseElement( "table/queries" )
      @table = getResponseElement( :table )
      @key_fid = getResponseElement( "table/original/key_fid" )
      @key_fid = @key_fid.text if @key_fid and @key_fid.has_text?

      return self if @chainAPIcalls

      if @table and block_given?
         @table.each { |element| yield element }
      else
         @table
      end
    end
    
   # API_GetSchema, using the active table id. 
   def _getSchema() getSchema( @dbid ) end

   # API_obstatus: get the status of the QuickBase server.
   def obStatus
     sendRequest( :obStatus )
     @serverVersion = getResponseElement("version")
     @serverUsers = getResponseElement("users")
     @serverGroups = getResponseElement("groups")
     @serverDatabases = getResponseElement("databases")
     @serverUptime = getResponseElement("uptime")
     @serverUpdays = getResponseElement("updays")
     @serverStatus = {
     "version" => @serverVersion.text,
     "users" => @serverUsers.text, 
     "groups" => @serverGroups.text, 
     "databases" => @serverDatabases.text, 
     "uptime" => @serverUptime.text, 
     "updays" => @serverUpdays.text 
     } 
   end
   
   # Get the status of the QuickBase server.
   def getServerStatus
     obStatus
   end  

   # API_GetUserInfo
   def getUserInfo( email = nil )
     @email = email
     
      if @email and @email.length > 0
        xmlRequestData = toXML( :email, @email) 
        sendRequest( :getUserInfo, xmlRequestData )
      else
        sendRequest( :getUserInfo )
        @login = getResponsePathValue( "user/login" )
      end  
      
      @name = getResponsePathValue( "user/name" )
      @firstName = getResponsePathValue( "user/firstName" )
      @lastName = getResponsePathValue( "user/lastName" )
      @login = getResponsePathValue( "user/login" )
      @email = getResponsePathValue( "user/email" )
      @screenName = getResponsePathValue( "user/screenName" )
      @externalAuth = getResponsePathValue( "user/externalAuth" )
      @user = getResponseElement( :user )
      @userid = @user.attributes["id"] if @user
      
      return self if @chainAPIcalls
      @user
   end

   # API_GetUserRole
   def getUserRole( dbid, userid, inclgrps = nil )
      @dbid, @userid, @inclgrps = dbid, userid, inclgrps
      
      xmlRequestData = toXML( :userid , @userid ) 
      xmlRequestData << toXML( :inclgrps , "1" ) if @inclgrps  
      sendRequest( :getUserRole, xmlRequestData )
      
      @user = getResponseElement( :user )
      @userid = @user.attributes["id"] if @user 
      @username = getResponsePathValue("user/name")
      @role = getResponseElement( "user/roles/role" )
      @roleid = @role.attributes["id"] if @role
      @rolename = getResponsePathValue("user/roles/role/name")
      access = getResponseElement("user/roles/role/access")
      @accessid = access.attributes["id"] if access
      @access = getResponsePathValue("user/roles/role/access") if access
      member = getResponseElement("user/roles/role/member")
      @member_type = member.attributes["type"] if member
      @member = getResponsePathValue("user/roles/role/member") if member
      
      return self if @chainAPIcalls
      return @user, @role
    end
    
   # API_GetUserRole, using the active table id. 
   def _getUserRole( userid, inclgrps = nil ) getUserRole( @dbid, userid, inclgrps ) end
   
   # API_GrantedDBs
   def grantedDBs( withembeddedtables = nil, excludeparents = nil, adminOnly = nil, includeancestors = nil, showAppData = nil )

      @withembeddedtables, @excludeparents, @adminOnly, @includeancestors, @showAppData = withembeddedtables, excludeparents, adminOnly, includeancestors, showAppData

      xmlRequestData = ""
      xmlRequestData << toXML( :withembeddedtables, @withembeddedtables ) if @withembeddedtables
      xmlRequestData << toXML( "Excludeparents", @excludeparents ) if @excludeparents
      xmlRequestData << toXML( :adminOnly, @adminOnly ) if @adminOnly
      xmlRequestData << toXML( :includeancestors, @includeancestors ) if @includeancestors
      xmlRequestData << toXML( :showAppData, @showAppData ) if @showAppData

      sendRequest( :grantedDBs, xmlRequestData )

      @databases = getResponseElement( :databases )

      return self if @chainAPIcalls

      if @databases and block_given?
         @databases.each { |element| yield element }
      else
         @databases
      end
   end

   # API_ImportFromCSV
   def importFromCSV( dbid, records_csv, clist, skipfirst = nil, msInUTC = nil )

      @dbid, @records_csv, @clist, @skipfirst, @msInUTC = dbid, records_csv, clist, skipfirst, msInUTC
      @clist ||= "0"

      xmlRequestData = toXML( :records_csv, @records_csv )
      xmlRequestData << toXML( :clist, @clist )
      xmlRequestData << toXML( :skipfirst, "1" ) if @skipfirst
      xmlRequestData << toXML( :msInUTC, "1" ) if @msInUTC

      sendRequest( :importFromCSV, xmlRequestData )

      @num_recs_added = getResponseValue( :num_recs_added )
      @num_recs_input = getResponseValue( :num_recs_input )
      @num_recs_updated = getResponseValue( :num_recs_updated )
      @rids = getResponseElement( :rids )
      @update_id = getResponseValue( :update_id )

      return self if @chainAPIcalls

      if block_given?
         @rids.each{ |rid| yield rid }
      else
         return @num_recs_added, @num_recs_input, @num_recs_updated, @rids, @update_id
      end
   end

   # API_ImportFromCSV, using the active table id. 
   def _importFromCSV( *args ) importFromCSV( @dbid, args ) end

   # API_InstallAppZip
   def installAppZip( dbid )
     @dbid = dbid
     sendRequest( :installAppZip )
     return self if @chainAPIcalls
     @responseCode
   end  
   
   # API_ListDBPages
   def listDBPages(dbid)
      @dbid = dbid
      
      sendRequest( :listDBPages )
      
      @pages = getResponseValue( :pages )
      return self if @chainAPIcalls
      if block_given?
        if @pages 
           @pages.each{ |element| yield element }
        else
           yield nil
        end  
      else
        @pages
      end        
    end  
    
   # API_ListDBPages, using the active table id. 
   def _listDBPages() listDBPages(@dbid) end
   
   # API_ProvisionUser
   def provisionUser( dbid, roleid, email, fname, lname )
      @dbid, @roleid, @email, @fname, @lname = dbid, roleid, email, fname, lname 
      
      xmlRequestData = toXML( :roleid, @roleid)
      xmlRequestData << toXML( :email, @email )
      xmlRequestData << toXML( :fname, @fname )
      xmlRequestData << toXML( :lname, @lname )
      
      sendRequest( :provisionUser, xmlRequestData )
      
      @userid = getResponseValue( :userid )
      
      return self if @chainAPIcalls
      @userid
   end  

   # API_ProvisionUser, using the active table id. 
   def _provisionUser( roleid, email, fname, lname ) provisionUser( @dbid, roleid, email, fname, lname ) end

   # API_PurgeRecords
   def purgeRecords( dbid, query = nil, qid = nil, qname = nil )
      @dbid = dbid
      xmlRequestData = getQueryRequestXML( query, qid, qname )
      sendRequest( :purgeRecords, xmlRequestData )
      @num_records_deleted = getResponseValue( :num_records_deleted )

      return self if @chainAPIcalls
      @num_records_deleted
   end

   # API_PurgeRecords, using the active table id. 
   def _purgeRecords( query = nil, qid = nil, qname = nil ) purgeRecords( @dbid, query, qid, qname ) end

   # API_RemoveUserFromRole
   def removeUserFromRole( dbid, userid, roleid )
      @dbid, @userid, @roleid = dbid, userid, roleid 
      
      xmlRequestData = toXML( :userid, @userid )
      xmlRequestData << toXML( :roleid, @roleid )
      
      sendRequest( :removeUserFromRole, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  

   # API_RemoveUserFromRole, using the active table id. 
   def _removeUserFromRole( userid, roleid ) removeUserFromRole( @dbid, userid, roleid ) end
     
   # API_RenameApp
   def renameApp( dbid, newappname )
      @dbid, @newappname = dbid, newappname 
      
      xmlRequestData = toXML( :newappname , @newappname )
      
      sendRequest( :renameApp, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  

   # API_RenameApp, using the active table id. 
   def _renameApp( newappname ) renameApp( @dbid, newappname ) end

   # API_RunImport
   def runImport( dbid, id )
      @dbid, @id = dbid, id
      
      xmlRequestData = toXML( :id , @id )
      
      sendRequest( :runImport, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  

   # API_RunImport, using the active table id. 
   def _runImport( id ) runImport( @dbid, id ) end

   # API_SendInvitation
   def sendInvitation( dbid, userid, usertext = "Welcome to my application!" )
      @dbid, @userid, @usertext = dbid, userid, usertext 
      
      xmlRequestData = toXML( :userid, @userid )
      xmlRequestData << toXML( :usertext, @usertext )
      
      sendRequest( :sendInvitation, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  

   # API_SendInvitation, using the active table id. 
   def _sendInvitation( userid, usertext = "Welcome to my application!" ) sendInvitation( @dbid, userid, usertext ) end

   # API_SetAppData
   def setAppData( dbid, appdata )
      @dbid, @appdata = dbid, appdata 

      xmlRequestData = toXML( :appdata , @appdata )
      
      sendRequest( :setAppData )
     
      return self if @chainAPIcalls
      @appdata
   end  

   # API_SetAppData, using the active table id. 
   def _setAppData( appdata ) setAppData( @dbid, appdata ) end

   # API_SetDBvar
   def setDBvar( dbid, varname, value )
      @dbid, @varname, @value = dbid, varname, value 
      
      xmlRequestData = toXML( :varname, @varname )
      xmlRequestData << toXML( :value, @value )
      
      sendRequest( :setDBvar, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  

   # API_SetDBvar, using the active table id. 
   def _setDBvar( varname, value ) setDBvar( @dbid, varname, value ) end

   # API_SetFieldProperties
   def setFieldProperties( dbid, properties, fid )

      @dbid, @properties, @fid = dbid, properties, fid

      if @properties and @properties.is_a?( Hash )

         xmlRequestData = toXML( :fid, @fid )

         @properties.each{ |key, value|
                              if isValidFieldProperty?( key )
                                 xmlRequestData << toXML( key, value )
                              else
                                 raise "setFieldProperties: Invalid field property '#{key}'.  Valid properties are " + @validFieldProperties.join( "," )
                              end
                         }

         sendRequest( :setFieldProperties, xmlRequestData )
      else
         raise "setFieldProperties: @properties is not a Hash of key/value pairs"
      end

      return self if @chainAPIcalls
      @requestSucceeded
   end
   
   # API_SetFieldProperties, using the active table id. 
   def _setFieldProperties( properties, fid ) setFieldProperties( @dbid, properties, fid ) end

   # API_SetKeyField
   def setKeyField( dbid, fid )
      @dbid, @fid = dbid, fid
      
      xmlRequestData = toXML( :fid, @fid )
      
      sendRequest( :setKeyField, xmlRequestData )
      
      return self if @chainAPIcalls
      @requestSucceeded
   end  

   # API_SetKeyField, using the active table id.
   def _setKeyField(fid) setKeyField( @dbid, fid ) end

   # API_SignOut
   def signOut
      sendRequest( :signOut )
      @ticket = @username = @password = nil

      return self if @chainAPIcalls
      @requestSucceeded
    end
    
   # -----------------------------------------------------------------------------------
   # NOTE: API_UploadFile
   # To do the equivalent of API_UploadFile, use the updateFile method below. 
   # -----------------------------------------------------------------------------------
   #def uploadFile( dbid, rid, uploadDataFileName )
   #end
   #def _uploadFile( rid, uploadDataFileName )
     
   # API_UserRoles
   def userRoles( dbid )
      @dbid = dbid
      
      sendRequest( :userRoles )
      
      @users = getResponseElement( :users )
      return self if @chainAPIcalls
      
      if block_given?
        if @users
          user_list = getResponseElements("qdbapi/users/user")
          user_list.each{|user| yield user}
        else
          yield nil
        end          
      else
        @users        
      end
   end
   
   # API_UserRoles, using the active table id. 
   def _userRoles() userRoles( @dbid ) end
    
   # ------------------- End of API_ wrapper methods -----------------------------------------
   # -----------------------------------------------------------------------------------------------

   # ------------------- Helper methods ---------------------------------------------------------
   # These methods are focused on reducing the amount of code you
   # have to write to get stuff done using the QuickBase::Client.
   # -----------------------------------------------------------------------------------------------
   
   # Use this if you aren't sure whether a particular record already exists or not
   def addOrEditRecord( dbid, fvlist, rid = nil, disprec = nil, fform = nil, ignoreError = nil, update_id = nil, key = nil  )
      if rid or key
        editRecord( dbid, rid, fvlist, disprec, fform, ignoreError, update_id, key )
        if !@requestSucceeded
          addRecord( dbid, fvlist, disprec, fform, ignoreError, update_id )
        end
      else    
        addRecord( dbid, fvlist, disprec, fform, ignoreError, update_id )
      end  
    end  
    
   # Get a record as a Hash, using the record id and dbid .
   # e.g. getRecord("24105","8emtadvk"){|myRecord| p myRecord}
   def getRecord(rid, dbid = @dbid, fieldNames = nil)
      rec = nil
      fieldNames ||= getFieldNames(dbid)
      iterateRecords(dbid, fieldNames,"{'3'.EX.'#{rid}'}"){|r| rec = r }
      if block_given?
        yield rec
      else
        rec  
      end        
    end     
    
   # Get an array of records as Hashes, using the record ids and dbid .
   # e.g. getRecords(["24105","24107"],"8emtadvk"){|myRecord| p myRecord}
   def getRecords(rids, dbid = @dbid, fieldNames = nil)
      records = []
      if rids.length > 0
        query = ""
        rids.each{|rid| query << "{'3'.EX.'#{rid}'}OR"}
        query[-2] = "" 
        fieldNames ||= getFieldNames(dbid)
        iterateRecords(dbid,fieldNames,query){|r| records << r }
      end
      if block_given?
        records.each{|rec|yield rec}
      else
        records  
      end        
   end     
    
   # Loop through the list of Pages for an application
    def iterateDBPages(dbid)
        listDBPages(dbid){|page|
             if page.is_a?( REXML::Element) and page.name == "page" 
                @pageid = page.attributes["id"]
                @pagetype = page.attributes["type"]
                @pagename = page.text if page.has_text?
                @page = { "name" => @pagename, "id" => @pageid, "type" => @pagetype }
                yield @page
             end
        }
    end

   # Get an array Pages for an application. Each item in the array is a Hash.
    def getDBPagesAsArray(dbid)
       dbPagesArray = []
       iterateDBPages(dbid){|page| dbPagesArray << page }
       dbPagesArray
     end
     
    alias getDBPages getDBPagesAsArray 

   #   - creates a QuickBase::Client,
   #   - signs into QuickBase
   #   - connects to a specific application
   #   - runs code in the associated block
   #   - signs out of QuickBase
   #
   #   e.g. QuickBase::Client.processDatabase( "user", "password", "my DB" ) { |qbClient,dbid| qbClient.getDBInfo( dbid ) }
   
   def Client.processDatabase( username, password, appname, chainAPIcalls = nil )
      if username and password and appname and block_given?
         begin
            qbClient = Client.new( username, password, appname )
            @chainAPIcalls = chainAPIcalls
            yield qbClient, qbClient.dbid
         rescue StandardError
         ensure
            qbClient.signOut
            @chainAPIcalls = nil
         end
      end
   end

   # This method changes all the API_ wrapper methods to return 'self' instead of their
   # normal return values. The change is in effect only within the associated block.
   # This allows mutliple API_ calls to be 'chained' together without needing 'qbClient' in front of each call.
   #
   # e.g. qbClient.chainAPIcallsBlock {
   #                                        qbClient
   #                                           .addField( @dbid, "a text field", "text" )
   #                                           .addField( @dbid, "a choice field", "text" )
   #                                           .fieldAddChoices( @dbid, @fid, %w{ one two three four five } )
   #                                      }
   
   def chainAPIcallsBlock
      if block_given?
         @chainAPIcalls = true
         yield
      end
      @chainAPIcalls = nil
   end

   # Set the active database table subsequent method calls.
   def setActiveTable( dbid )
      @dbid = dbid
   end

   # Set the active database and record for subsequent method calls.
   def setActiveRecord( dbid, rid )
      if dbid and rid
         getRecordInfo( dbid, rid )
      end
      @rid
   end
   def _setActiveRecord( rid ) setActiveRecord( @dbid, rid ) end

   # Change a named field's value in the active record.
   # e.g. setFieldValue( "Location", "Miami" )
   def setFieldValue( fieldName, fieldValue, dbid = nil, rid = nil, key =nil )
      @dbid ||= dbid
      @rid ||= rid
      @key ||= key
      if @dbid and (@rid or @key)
         clearFieldValuePairList
         addFieldValuePair( fieldName, nil, nil, fieldValue )
         editRecord( @dbid, @rid, @fvlist, nil, nil, nil, nil, nil, @key )
      end
   end

   # Set several named fields' values. Will modify the active record if there is one.
   # e.g. setFieldValues( {"Location" => "Miami", "Phone" => "343-4567" } )
   def setFieldValues( fields, editRecord=true )
      if fields.is_a?(Hash)
          clearFieldValuePairList
          fields.each{ |fieldName,fieldValue|
             addFieldValuePair( fieldName, nil, nil, fieldValue )
          }
          if editRecord and @dbid and (@rid or @key)
            editRecord( @dbid, @rid, @fvlist, nil, nil, nil, nil, nil, @key )
          end
      end
   end

   # Change a field's value in multiple records.  If the optional test
   # field/operator/value are supplied, only records matching the test field will be
   # modified, otherwise all records will be modified.
   # e.g. changeRecords( "Status", "special", "Account Balance", ">", "100000.00" )
   def changeRecords( fieldNameToSet, fieldValueToSet, fieldNameToTest, test, fieldValueToTest )

      if @dbid and @fields and fieldNameToSet and fieldValueToSet and fieldNameToTest and test and fieldValueToTest

         numRecsChanged = 0
         numRecs = _getNumRecords

         if numRecs > "0"

            fieldType = "text"
            if fieldNameToTest
               fieldNameToTestID = lookupFieldIDByName( fieldNameToTest )
               field = lookupField( fieldNameToTestID ) if fieldNameToTestID
               fieldType = field.attributes[ "field_type" ] if field
            end

            fieldNameToSetID = lookupFieldIDByName( fieldNameToSet )

            if fieldNameToSetID
               clearFieldValuePairList
               addFieldValuePair( nil, fieldNameToSetID, nil, fieldValueToSet )
               (1..numRecs.to_i).each{ |rid|
                  _getRecordInfo( rid.to_s )
                  if @num_fields and @update_id and @field_data_list
                     if fieldNameToTestID and test and fieldValueToTest
                        field_data = lookupFieldData( fieldNameToTestID )
                        if field_data  and field_data.is_a?( REXML::Element )
                           valueElement = field_data.elements[ "value" ]
                           value = valueElement.text if valueElement.has_text?
                           value = formatFieldValue( value, fieldType )
                           match = eval( "\"#{value}\" #{test} \"#{fieldValueToTest}\"" ) if value
                           if match
                              editRecord( @dbid, rid.to_s, @fvlist )
                              if @rid
                                 numRecsChanged += 1
                              end
                           end
                        end
                     else
                        editRecord( @dbid, rid.to_s, @fvlist )
                        if @rid
                           numRecsChanged += 1
                        end
                     end
                  end
               }
            end
         end
      end
      numRecsChanged
   end

   # Delete all records in the active table that match
   # the field/operator/value. e.g. deleteRecords( "Status", "==", "inactive" ).
   # To delete ALL records, call deleteRecords() with no parameters. This is the
   # same as calling _purgeRecords.
   def deleteRecords( fieldNameToTest = nil, test = nil, fieldValueToTest = nil)
      numRecsDeleted = 0
      if @dbid and @fields and fieldNameToTest and test and fieldValueToTest

         numRecs = _getNumRecords

         if numRecs > "0"

            fieldNameToTestID = lookupFieldIDByName( fieldNameToTest )
            fieldToTest = lookupField( fieldNameToTestID ) if fieldNameToTestID
            fieldType = fieldToTest.attributes[ "field_type" ] if fieldToTest

            if fieldNameToTestID
               (1..numRecs.to_i).each{ |rid|
                  _getRecordInfo( rid.to_s )
                  if @num_fields and @update_id and @field_data_list
                     field_data = lookupFieldData( fieldNameToTestID )
                     if field_data and field_data.is_a?( REXML::Element )
                        valueElement = field_data.elements[ "value" ]
                        value = valueElement.text if valueElement.has_text?
                        value = formatFieldValue( value, fieldType )
                        match = eval( "\"#{value}\" #{test} \"#{fieldValueToTest}\"" ) if value
                        if match
                           if _deleteRecord( rid.to_s )
                              numRecsDeleted += 1
                           end
                        end
                     end
                  end
               }
            end
         end
      elsif @dbid
         numRecsDeleted = _purgeRecords
      end
      numRecsDeleted
   end

   # Get all the values for one or more fields from a specified table.
   #
   # e.g. getAllValuesForFields( "dhnju5y7", [ "Name", "Phone" ] )
   #
   # The results are returned in Hash, e.g. { "Name" => values[ "Name" ], "Phone" => values[ "Phone" ] }
   # The parameters after 'fieldNames' are passed directly to the doQuery() API_ call.
   #
   #  Invalid 'fieldNames' will be treated as field IDs by default,  e.g. getAllValuesForFields( "dhnju5y7", [ "3" ] ) 
   #  returns a list of Record ID#s even if the 'Record ID#' field name has been changed.
   
   def getAllValuesForFields( dbid, fieldNames = nil, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      if dbid

         getSchema(dbid)
         
         values = {}
         fieldIDs = {}
         if fieldNames and fieldNames.is_a?( String )
            values[ fieldNames ] = []
            fieldID = lookupFieldIDByName( fieldNames )
            if fieldID 
               fieldIDs[ fieldNames ] = fieldID 
            elsif fieldNames.match(/[0-9]+/) # assume fieldNames is a field ID  
               fieldIDs[ fieldNames ] = fieldNames
            end
         elsif fieldNames and fieldNames.is_a?( Array )
            fieldNames.each{ |name|
               if name
                  values[ name ] = []
                  fieldID = lookupFieldIDByName( name )
                  if fieldID
                     fieldIDs[ fieldID ] = name 
                  elsif name.match(/[0-9]+/) # assume name is a field ID
                     fieldIDs[ name ] = name
                  end
               end
            }
         elsif fieldNames.nil?
            getFieldNames(dbid).each{|name|
                  values[ name ] = []
                  fieldID = lookupFieldIDByName( name )
                  fieldIDs[ fieldID ] = name
            }         
         end
         
         if clist
            clist << "."
            clist = fieldIDs.keys.join('.')
         elsif qid.nil? and qname.nil?
            clist = fieldIDs.keys.join('.')
         end
         
         if clist
            clist = clist.split('.')
            clist.uniq!
            clist = clist.join(".")
         end

         doQuery( dbid, query, qid, qname, clist, slist, fmt, options )

         if @records and values.length > 0 and fieldIDs.length > 0
            @records.each { |r|
               if r.is_a?( REXML::Element) and r.name == "record"
                  values.each{ |k,v| v << "" }
                  r.each{ |f|
                     if f.is_a?( REXML::Element) and f.name == "f"
                       fid = f.attributes[ "id" ]
                       name = fieldIDs[ fid ] if fid
                       if name and values[ name ]
                          v = values[ name ]
                          v[-1] = f.text if v and f.has_text?
                       end
                     end
                  }
               end
            }
         end
      end

      if values and block_given?
         values.each{ |field, values| yield field, values }
      else
         values
      end
    end
    
  alias getRecordsHash getAllValuesForFields
   
   # Get all the values for one or more fields from a specified table.
   # This also formats the field values instead of returning the raw value.
   def getAllValuesForFieldsAsArray( dbid, fieldNames = nil, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      ret = []
      valuesForFields = getAllValuesForFields(dbid, fieldNames, query, qid, qname, clist, slist,fmt,options)
      if valuesForFields
         fieldNames ||= getFieldNames(@dbid) 
         if fieldNames and fieldNames[0]
            ret = Array.new(valuesForFields[fieldNames[0]].length) 
            fieldType = {}
            fieldNames.each{|field|fieldType[field]=lookupFieldTypeByName(field)}
            valuesForFields.each{ |field,values|
               values.each_index { |i| 
                  ret[i] ||= {} 
                  ret[i][field]=formatFieldValue(values[i],fieldType[field])
               }
            }
         end
      end
      ret
   end
  
  alias getRecordsArray getAllValuesForFieldsAsArray

   # Get all the values for one or more fields from a specified table, in JSON format.
   # This formats the field values instead of returning raw values.
   def getAllValuesForFieldsAsJSON( dbid, fieldNames = nil, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
     ret = getAllValuesForFieldsAsArray(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options)
     ret = JSON.generate(ret) if ret
   end

   alias getRecordsAsJSON getAllValuesForFieldsAsJSON

   # Get all the values for one or more fields from a specified table, in human-readable JSON format.
   # This formats the field values instead of returning raw values.
   def getAllValuesForFieldsAsPrettyJSON( dbid, fieldNames = nil, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
     ret = getAllValuesForFieldsAsArray(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options)
     ret = JSON.pretty_generate(ret) if ret
   end
   
   alias getRecordsAsPrettyJSON getAllValuesForFieldsAsPrettyJSON

   # Set the values of fields in all records returned by a query.
   # fieldValuesToSet must be a Hash of fieldnames+values, e.g. {"Location" => "Miami", "Phone" => "343-4567"}
   def editRecords(dbid,fieldValuesToSet,query=nil,qid=nil,qname=nil)
      edited_rids = []
      if fieldValuesToSet and fieldValuesToSet.is_a?(Hash)
         verifyFieldList(fieldValuesToSet.keys,nil,dbid)
         recordIDs = getAllValuesForFields(dbid,["3"],query,qid,qname,"3")
         if recordIDs
            numRecords = recordIDs["3"].length
            (0..(numRecords-1)).each {|i|
               @rid = recordIDs["3"][i]
               setFieldValues(fieldValuesToSet)
               edited_rids << @rid
            }   
         end
      else
         raise "'fieldValuesToSet' must be a Hash of field names and values."
      end
      edited_rids 
   end
   
   # Loop through records returned from a query. Each record is a field+value Hash.
   # e.g. iterateRecords( "dhnju5y7", ["Name","Address"] ) { |values| puts values["Name"], values["Address"] }
   def iterateRecords( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      if block_given?   
         queryResults = getAllValuesForFields(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options)
         if queryResults
            numRecords = 0
            numRecords = queryResults[fieldNames[0]].length if queryResults[fieldNames[0]]
            (0..(numRecords-1)).each{|recNum|
               recordHash = {}
               fieldNames.each{|fieldName|
                  recordHash[fieldName]=queryResults[fieldName][recNum]
               }
               yield recordHash
            }
         end
      else
         raise "'iterateRecords' must be called with a block."
      end
   end
   
   # Same as iterateRecords but with fields optionally filtered by Ruby regular expressions.
   # e.g. iterateFilteredRecords( "dhnju5y7", [{"Name" => "[A-E].+"},"Address"] ) { |values| puts values["Name"], values["Address"] }
   def iterateFilteredRecords( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      fields = []
      regexp = {}
      fieldNames.each{|field|
         if field.is_a?(Hash)
            fields << field.keys[0]
            regexp[field.keys[0]] = field.values[0]
         elsif field.is_a?(String)
            fields << field
         end
      }
      regexp = nil if regexp.length == 0
      iterateRecords(dbid,fields,query,qid,qname,clist,slist,fmt,options){|record|
         if regexp
            match = true
            fields.each{|field|
               if regexp[field] 
                  unless record[field] and record[field].match(regexp[field])
                     match = false 
                     break
                  end
               end
            }
            yield record if match
         else
            yield record
         end
      }
   end

   # e.g. getFilteredRecords( "dhnju5y7", [{"Name" => "[A-E].+"},"Address"] ) { |values| puts values["Name"], values["Address"] }
   def getFilteredRecords( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      filteredRecords = []
      iterateFilteredRecords(dbid, fieldNames, query, qid, qname, clist, slist, fmt, options){ |filteredRecord| 
         filteredRecords << filteredRecord 
      }
      filteredRecords
   end
    
   alias findRecords getFilteredRecords
   alias find_records getFilteredRecords

   # Get records from two or more tables and/or queries with the same value in a 
   # 'join' field and loop through the joined results.
   # The 'joinfield' does not have to have the same name in each table.
   # Fields with the same name in each table will be merged, with the value from the last 
   # table being assigned. This is similar to an SQL JOIN.
   def iterateJoinRecords(tablesAndFields)
   
      raise "'iterateJoinRecords' must be called with a block." if not block_given?   
   
      if tablesAndFields and tablesAndFields.is_a?(Array)
         
         # get all the records from QuickBase that we might need - fewer API calls is faster than processing extra data
         tables = []
         numRecords = {}
         tableRecords = {}
         joinfield = {}
         
         tablesAndFields.each{|tableAndFields|
            if tableAndFields and tableAndFields.is_a?(Hash)
               if tableAndFields["dbid"] and tableAndFields["fields"] and tableAndFields["joinfield"]
                  if tableAndFields["fields"].is_a?(Array)
                     tables << tableAndFields["dbid"]
                     joinfield[tableAndFields["dbid"]] = tableAndFields["joinfield"]
                     tableAndFields["fields"] << tableAndFields["joinfield"] if not tableAndFields["fields"].include?(tableAndFields["joinfield"])
                     tableRecords[tableAndFields["dbid"]] = getAllValuesForFields( tableAndFields["dbid"],
                                                                                                          tableAndFields["fields"],
                                                                                                          tableAndFields["query"],
                                                                                                          tableAndFields["qid"],
                                                                                                          tableAndFields["qname"],
                                                                                                          tableAndFields["clist"],
                                                                                                          tableAndFields["slist"],
                                                                                                          "structured",
                                                                                                          tableAndFields["options"])
                     numRecords[tableAndFields["dbid"]] = tableRecords[tableAndFields["dbid"]][tableAndFields["fields"][0]].length                                                                                     
                  else
                     raise "'tableAndFields[\"fields\"]' must be an Array of fields to retrieve."
                  end
               else
                  raise "'tableAndFields' is missing one of 'dbid', 'fields' or 'joinfield'."
               end
            else
               raise "'tableAndFields' must be a Hash"
            end
         }
         
         numTables = tables.length
         
         # go through the records in the first table
         (0..(numRecords[tables[0]]-1)).each{|i|
         
            # get the value of the join field in each record of the first table
            joinfieldValue = tableRecords[tables[0]][joinfield[tables[0]]][i]

            # save the other tables' record indices of records containing the joinfield value 
            tableIndices = []
            
            (1..(numTables-1)).each{|tableNum| 
               tableIndices[tableNum] = []
               (0..(numRecords[tables[tableNum]]-1)).each{|j|
                  if joinfieldValue == tableRecords[tables[tableNum]][joinfield[tables[tableNum]]][j]
                     tableIndices[tableNum] << j
                  end
               }
            }
            
            # if all the tables had at least one matching record, build a joined record and yield it
            buildJoinRecord = true   
            (1..(numTables-1)).each{|tableNum|
               buildJoinRecord = false if not tableIndices[tableNum].length > 0
            }
            
            if buildJoinRecord
            
               joinRecord = {}
               
               tableRecords[tables[0]].each_key{|field|
                  joinRecord[field] = tableRecords[tables[0]][field][i]
               }
               
               # nested loops for however many tables we have
               currentIndex = []
               numTables.times{ currentIndex << 0 }
               loop {
                  (1..(numTables-1)).each{|tableNum|   
                     index = tableIndices[tableNum][currentIndex[tableNum]]
                     tableRecords[tables[tableNum]].each_key{|field|
                        joinRecord[field] = tableRecords[tables[tableNum]][field][index]
                     }
                     if currentIndex[tableNum] == tableIndices[tableNum].length-1
                        currentIndex[tableNum] = -1
                     else
                        currentIndex[tableNum] += 1
                     end   
                     if tableNum == numTables-1
                        yield joinRecord
                     end
                  }
                  finishLooping = true
                  (1..(numTables-1)).each{|tableNum|
                     finishLooping = false if currentIndex[tableNum] != -1
                  }
                  break if finishLooping
               }
            end
         }
      else
         raise "'tablesAndFields' must be Array of Hashes of table query parameters."
      end
   end
   
   # Get an array of records from two or more tables and/or queries with the same value in a 'join' field.
   # The 'joinfield' does not have to have the same name in each table.
   # Fields with the same name in each table will be merged, with the value from the last 
   # table being assigned. This is similar to an SQL JOIN.
   def getJoinRecords(tablesAndFields)
      joinRecords = []
      iterateJoinRecords(tablesAndFields)  { |joinRecord|
         joinRecords << joinRecord.dup
      } 
      joinRecords
   end
   
   # Get values from the same fields in two or more tables and/or queries and loop through the merged results.
   # The merged records will be unique. This is similar to an SQL UNION.
   def iterateUnionRecords(tables,fieldNames)
   
      raise "'iterateUnionRecords' must be called with a block." if not block_given?   
   
      if tables and tables.is_a?(Array)
         if fieldNames and fieldNames.is_a?(Array)
            tableRecords = []
            tables.each{|table|
               if table and table.is_a?(Hash) and table["dbid"]
                  tableRecords << getAllValuesForFields( table["dbid"],
                                                                        fieldNames,
                                                                        table["query"],
                                                                        table["qid"],
                                                                        table["qname"],
                                                                        table["clist"],
                                                                        table["slist"],
                                                                        "structured",
                                                                        table["options"])
               else
                  raise "'table' must be a Hash that includes an entry for 'dbid'."
               end
            }
         else
            raise "'fieldNames' must be an Array of field names valid in all the tables."
         end
      else
         raise "'tables' must be an Array of Hashes."
      end
      usedRecords = {}
      tableRecords.each{|queryResults|
         if queryResults
            numRecords = 0
            numRecords = queryResults[fieldNames[0]].length if queryResults[fieldNames[0]]
            (0..(numRecords-1)).each{|recNum|
               recordHash = {}
               fieldNames.each{|fieldName|
                  recordHash[fieldName]=queryResults[fieldName][recNum]
               }
               if not usedRecords[recordHash.values.join]
                  usedRecords[recordHash.values.join]=true
                  yield recordHash
               end
            }
         end
      }
   end

   # Returns an Array of values from the same fields in two or more tables and/or queries.
   # The merged records will be unique. This is similar to an SQL UNION.
   def getUnionRecords(tables,fieldNames)
      unionRecords = []
      iterateUnionRecords(tables,fieldNames) { |unionRecord| 
         unionRecords << unionRecord.dup 
      }
      unionRecords
   end

   # (The QuickBase API does not supply a method for this.) 
   # Loop through summary records, like the records in a QuickBase Summary report.
   # Fields with 'Total' and 'Average' checked in the target table will be summed and/or averaged.
   # Other fields with duplicate values will be merged into a single 'record'.
   # The results will be sorted by the merged fields, in ascending order.
   # e.g. -  
   #    iterateSummaryRecords( "vavaa4sdd", ["Customer", "Amount"] ) {|record| 
   #        puts "Customer: #{record['Customer']}, Amount #{record['Amount']}
   #    } 
   # would print the total Amount for each Customer, sorted by Customer.
   def iterateSummaryRecords( dbid, fieldNames,query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
   
      getSchema(dbid)
      
      slist = ""
      summaryRecord = {}
      doesTotal = {}
      doesAverage = {}
      summaryField = {}
      fieldType = {}
      
      fieldNames.each{ |fieldName|
         fieldType[fieldName] = lookupFieldTypeByName(fieldName)
         isSummaryField = true     
         doesTotal[fieldName] = isTotalField?(fieldName)
         doesAverage[fieldName] = isAverageField?(fieldName)
         if doesTotal[fieldName] 
            summaryRecord["#{fieldName}:Total"] = 0 
            isSummaryField = false
         end   
         if doesAverage[fieldName] 
            summaryRecord["#{fieldName}:Average"] = 0 
            isSummaryField = false
         end
         if isSummaryField
            summaryField[fieldName] = true
            fieldID = lookupFieldIDByName(fieldName)  
            slist << "#{fieldID}."
         end
      }
      slist[-1] = ""
      
      count = 0
      
      iterateRecords( dbid, fieldNames, query, qid, qname, clist, slist, fmt, options) { |record|
         
         summaryFieldValuesHaveChanged = false
         fieldNames.each{ |fieldName| 
            if summaryField[fieldName] and record[fieldName] != summaryRecord[fieldName]   
               summaryFieldValuesHaveChanged = true
               break
            end
         }

         if summaryFieldValuesHaveChanged
         
            summaryRecord["Count"] = count
            fieldNames.each{|fieldName| 
               if doesTotal[fieldName] 
                  summaryRecord["#{fieldName}:Total"] = formatFieldValue(summaryRecord["#{fieldName}:Total"],fieldType[fieldName]) 
               end   
               if doesAverage[fieldName]
                  summaryRecord["#{fieldName}:Average"] = summaryRecord["#{fieldName}:Average"]/count if count > 0
                  summaryRecord["#{fieldName}:Average"] = formatFieldValue(summaryRecord["#{fieldName}:Average"],fieldType[fieldName])
               end   
            }
            
            yield summaryRecord 
            
            count=0
            summaryRecord = {}
            fieldNames.each{|fieldName| 
               if doesTotal[fieldName] 
                  summaryRecord["#{fieldName}:Total"] = 0 
               end   
               if doesAverage[fieldName] 
                  summaryRecord["#{fieldName}:Average"] = 0 
               end   
            }
         end
         
         count += 1
         fieldNames.each{|fieldName| 
               if doesTotal[fieldName] 
                  summaryRecord["#{fieldName}:Total"] += record[fieldName].to_i 
               end
               if doesAverage[fieldName] 
                  summaryRecord["#{fieldName}:Average"] += record[fieldName].to_i 
               end
               if summaryField[fieldName]               
                  summaryRecord[fieldName] = record[fieldName]
               end   
         }
      }
      
      summaryRecord["Count"] = count
      fieldNames.each{|fieldName| 
         if doesTotal[fieldName] 
            summaryRecord["#{fieldName}:Total"] = formatFieldValue(summaryRecord["#{fieldName}:Total"],fieldType[fieldName]) 
         end   
         if doesAverage[fieldName] 
            summaryRecord["#{fieldName}:Average"] = summaryRecord["#{fieldName}:Average"]/count
            summaryRecord["#{fieldName}:Average"] = formatFieldValue(summaryRecord["#{fieldName}:Average"],fieldType[fieldName])
         end   
      }
      yield summaryRecord 
   
   end

   # Collect summary records into an array. 
   def getSummaryRecords( dbid, fieldNames,query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      summaryRecords = []
      iterateSummaryRecords(dbid, fieldNames,query, qid, qname, clist, slist, fmt = "structured", options){|summaryRecord|
         summaryRecords << summaryRecord.dup
      }
      summaryRecords
   end

   # Loop through a list of records returned from a query. 
   # Each record will contain all the fields with values formatted for readability by QuickBase via API_GetRecordInfo.
  def iterateRecordInfos(dbid, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil)
      getSchema(dbid)
      recordIDFieldName = lookupFieldNameFromID("3")
      fieldNames = getFieldNames
      fieldIDs = {}
      fieldNames.each{|name|fieldIDs[name] = lookupFieldIDByName(name)}
      iterateRecords(dbid, [recordIDFieldName], query, qid, qname, clist, slist, fmt, options){|r|
        getRecordInfo(dbid,r[recordIDFieldName])
        fieldValues = {}
        fieldIDs.each{|k,v| 
          fieldValues[k] = getFieldDataPrintableValue(v)
          fieldValues[k] ||= getFieldDataValue(v)
        }        
        yield fieldValues
      }
  end

  # Returns table or record values using REST syntax. e.g. -
  # puts processRESTRequest("8emtadvk/24105") # prints record 24105 from Community Forum
  # puts processRESTRequest("8emtadvk") # prints name of table with dbid of '8emtadvk'
  # puts qbc.processRESTRequest("6ewwzuuj/Function Name") # prints list of QuickBase Functions
  def processRESTRequest(requestString)
    ret = nil
    request = requestString.dup
    request.gsub!("//","ESCAPED/")
    requestParts = request.split('/')
    requestParts.each{|part| part.gsub!("ESCAPED/","//") }
    applicationName = nil
    applicationDbid= nil
    tableName = nil
    tableDbid = nil
    requestType = ""
    
    requestParts.each_index{|i|
      if i == 0
        dbid = findDBByName(requestParts[0].dup)
        if dbid
          applicationDbid= dbid.dup # app/
          applicationName = requestParts[0].dup
          ret = "dbid:#{applicationDbid}"
        elsif QuickBase::Misc.isDbidString?(requestParts[0].dup) and getSchema(requestParts[0].dup)
          tableDbid = requestParts[0].dup # dbid/
          tableName = getTableName(tableDbid)
          ret = "table:#{tableName}"
        else
          ret = "Unable to process '#{requestParts[0].dup}' part of '#{requestString}'." 
        end
      elsif i == 1
        if applicationDbid
          getSchema(applicationDbid)
          tableDbid = lookupChdbid(requestParts[1].dup)
          if tableDbid # app/chdbid/
            tableName = requestParts[1].dup
            ret = "dbid:#{tableDbid}"
          else
            getSchema(applicationDbid.dup)
            tableDbid = lookupChdbid(applicationName.dup)
            if tableDbid # app+appchdbid/
              tableName = applicationName 
              ret, requestType = processRESTFieldNameOrRecordKeyRequest(tableDbid,requestParts[1].dup)
            else
              ret = "Unable to process '#{requestParts[1].dup}' part of '#{requestString}'." 
            end  
          end
        elsif tableDbid
          ret, requestType = processRESTFieldNameOrRecordKeyRequest(tableDbid,requestParts[1].dup)
        else
          ret = "Unable to process '#{requestParts[1].dup}' part of '#{requestString}'." 
        end        
      elsif (i==2 or i == 3) and ["keyFieldValue","recordID"].include?(requestType)
        fieldValues = ret.split(/\n/)
        fieldValues.each{|fieldValue|
          if fieldValue.index("#{requestParts[i].dup}:") == 0
            ret = fieldValue.gsub("#{requestParts[i].dup}:","")
            break
          end
        }
      elsif i == 2 and tableDbid
        ret, requestType = processRESTFieldNameOrRecordKeyRequest(tableDbid,requestParts[2].dup)
      else
        ret = "Unable to process '#{requestString}'." 
      end  
    }
    ret
  end  

  def processRESTFieldNameOrRecordKeyRequest(dbid,fieldNameOrRecordKey)
    returnvalue = ""
    requestType = ""
    getSchema(dbid)
    fieldNames = getFieldNames
    if fieldNames.include?(fieldNameOrRecordKey) # name of a field in the table
      requestType = "fieldName"
      iterateRecordInfos(dbid){|r| 
         returnvalue << "#{fieldNameOrRecordKey}:#{r[fieldNameOrRecordKey]}\n" if r
      }
    elsif @key_fid # key field value
      requestType = "keyFieldValue"
      iterateRecordInfos(dbid,"{'#{@key_fid}'.EX.'#{fieldNameOrRecordKey}'}"){|r|
        r.each{|k,v| returnvalue << "#{k}:#{v}\n"} if r
      }
    elsif fieldNameOrRecordKey.match(/[0-9]+/) # guess that this is a Record #ID value
      requestType = "recordID"
      iterateRecordInfos(dbid,"{'3'.EX.'#{fieldNameOrRecordKey}'}"){|r|
        r.each{|k,v| returnvalue << "#{k}:#{v}\n"} if r
      }
    else # guess that the first non-built-in field is a secondary non-numeric key field
      requestType = "field6"
      iterateRecordInfos(dbid,"{'6'.TV.'#{fieldNameOrRecordKey}'}"){|r|
        if r
          returnvalue << "Record:\n"
          r.each{|k,v| returnvalue << "#{k}:#{v}\n"}
        end
      }
    end
    return returnvalue, requestType
  end

   # Find the lowest value for one or more fields in the records returned by a query.
   # e.g. minimumsHash = min("dfdfafff",["Date Sent","Quantity","Part Name"])
   def min( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      min = {}
      hasValues = false
      iterateRecords(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options){|record|
         fieldNames.each{|field|
            value = record[field]
            if value
               baseFieldType = lookupBaseFieldTypeByName(field)
               case baseFieldType
                  when "int32","int64","bool" 
                     value = record[field].to_i
                  when "float"   
                     value = record[field].to_f
               end
            end
            if min[field].nil? or  (value and value < min[field])
               min[field] = value
               hasValues = true
            end
         }
      }
      min = nil if not hasValues
      min
   end

   # Find the highest value for one or more fields in the records returned by a query.
   # e.g. maximumsHash = max("dfdfafff",["Date Sent","Quantity","Part Name"])
   def max( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      max = {}
      hasValues = false
      iterateRecords(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options){|record|
         fieldNames.each{|field|
            value = record[field]
            if value
               baseFieldType = lookupBaseFieldTypeByName(field)
               case baseFieldType
                  when "int32","int64","bool" 
                     value = record[field].to_i
                  when "float"   
                     value = record[field].to_f
               end
            end
            if max[field].nil? or (value and value > max[field])
               max[field] = value
               hasValues = true
            end
         }
      }
      max = nil if not hasValues
      max
   end

   # Returns the number non-null values for one or more fields in the records returned by a query.
   # e.g. countsHash = count("dfdfafff",["Date Sent","Quantity","Part Name"])
   def count( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      count = {}
      fieldNames.each{|field| count[field]=0 }
      hasValues = false
      iterateRecords(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options){|record|
         fieldNames.each{|field|
            if record[field] and record[field].length > 0
               count[field] += 1
               hasValues = true
            end
         }
      }
      count = nil if not hasValues
      count
   end

   # Returns the sum of the values for one or more fields in the records returned by a query.
   # e.g. sumsHash = sum("dfdfafff",["Date Sent","Quantity","Part Name"])
   def sum( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      sum = {}
      hasValues = false
      iterateRecords(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options){|record|
         fieldNames.each{|field|
            value = record[field]
            if value
               baseFieldType = lookupBaseFieldTypeByName(field)
               case baseFieldType
                  when "int32","int64","bool" 
                     value = record[field].to_i
                  when "float"   
                     value = record[field].to_f
               end
               if sum[field].nil? 
                  sum[field] = value
               else
                  sum[field] = sum[field] + value
               end
               hasValues = true
            end
         }
      }
      sum = nil if not hasValues
      sum
   end
   
   # Returns the average of the values for one or more fields in the records returned by a query.
   # e.g. averagesHash = average("dfdfafff",["Date Sent","Quantity","Part Name"])
   def average( dbid, fieldNames, query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil )
      count = {}
      fieldNames.each{|field| count[field]=0 }
      sum = {}
      iterateRecords(dbid,fieldNames,query,qid,qname,clist,slist,fmt,options){|record|
         fieldNames.each{|field|
            value = record[field]
            if value
               baseFieldType = lookupBaseFieldTypeByName(field)
               case baseFieldType
                  when "int32","int64","bool" 
                     value = record[field].to_i
                  when "float"   
                     value = record[field].to_f
               end
               if sum[field].nil?
                  sum[field] = value
               else
                  sum[field] = sum[field] + value
               end
               count[field] += 1
            end
         }
      }
      average = {}
      hasValues = false
      fieldNames.each{|field| 
         if sum[field] and count[field] > 0
            average[field] = (sum[field]/count[field]) 
            hasValues = true
         end
      }
      average = nil if not hasValues
      average
   end

   # Query records, sum the values in a numeric field, calculate each record's percentage 
   # of the sum and put the percent in a percent field each record.
   def applyPercentToRecords( dbid, numericField, percentField, 
                                             query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil) 
      fieldNames = Array[numericField]
      total = sum( dbid, fieldNames, query, qid, qname, clist, slist, fmt, options )
      fieldNames << "3" # Record ID#
      iterateRecords( dbid, fieldNames, query, qid, qname, clist, slist, fmt, options ){|record|
         result = percent( [total[numericField],record[numericField]] )
         clearFieldValuePairList
         addFieldValuePair( percentField, nil, nil, result.to_s )
         editRecord( dbid, record["3"], fvlist )
      }
   end
   
   # Query records, get the average of the values in a numeric field, calculate each record's deviation
   # from the average and put the deviation in a percent field each record.
   def applyDeviationToRecords( dbid, numericField, deviationField, 
                                                query = nil, qid = nil, qname = nil, clist = nil, slist = nil, fmt = "structured", options = nil) 
      fieldNames = Array[numericField]
      avg = average( dbid, fieldNames, query, qid, qname, clist, slist, fmt, options )
      fieldNames << "3" # Record ID#
      iterateRecords( dbid, fieldNames, query, qid, qname, clist, slist, fmt, options ){|record|
         result = deviation( [avg[numericField],record[numericField]] )
         clearFieldValuePairList
         addFieldValuePair( deviationField, nil, nil, result.to_s )
         editRecord( dbid, record["3"], fvlist )
      }
   end
   
   # Given an array of two numbers, return the second number as a percentage of the first number.
   def percent( inputValues )
      raise "'inputValues' must not be nil" if inputValues.nil?
      raise "'inputValues' must be an Array" if not inputValues.is_a?(Array)
      raise "'inputValues' must have at least two elements" if inputValues.length < 2
      total = inputValues[0].to_f
      total = 1.0 if total == 0.00
      value = inputValues[1].to_f
      ((value/total)*100)
   end
   
   # Given an array of two numbers, return the difference between the numbers as a positive number.
   def deviation( inputValues )
      raise "'inputValues' must not be nil" if inputValues.nil?
      raise "'inputValues' must be an Array" if not inputValues.is_a?(Array)
      raise "'inputValues' must have at least two elements" if inputValues.length < 2
      value = inputValues[0].to_f - inputValues[1].to_f
      value.abs
   end

   # Get an array of the existing choices for a multiple-choice text field.
   def getFieldChoices(dbid,fieldName=nil,fid=nil)
      getSchema(dbid)
      if fieldName
         fid = lookupFieldIDByName(fieldName)
      elsif not fid
         raise "'fieldName' or 'fid' must be specified"
      end
      field = lookupField( fid )
      if field
         choices = []
         choicesProc = proc { |element|
            if element.is_a?(REXML::Element)
               if element.name == "choice" and element.has_text?
                  choices << element.text
               end
            end
         }
         processChildElements(field,true,choicesProc)
         choices = nil if choices.length == 0
         choices
      else   
         nil
      end
   end

   # Get an array of all the record IDs for a specified table.
   # e.g. IDs = getAllRecordIDs( "dhnju5y7" ){ |id| puts "Record #{id}" }
   def getAllRecordIDs( dbid )
      rids = []
      if dbid
         getSchema( dbid )
         next_record_id = getResponseElement( "table/original/next_record_id" )
         if next_record_id and next_record_id.has_text?
            next_record_id = next_record_id.text
            (1..next_record_id.to_i).each{ |rid|
               begin
                  _getRecordInfo( rid )
                  rids << rid.to_s if update_id
               rescue
               end
            }
         end
      end
      if block_given?
        rids.each { |id| yield id }
      else
        rids
      end
   end

   # Finds records with the same values in a specified list of fields.  
   # The field list may be a list of field IDs or a list of field names.
   # Returns a hash with the structure { "duplicated values" => [ rid, rid, ... ] }
   def findDuplicateRecordIDs(  fnames, fids, dbid = @dbid, ignoreCase = true )
      verifyFieldList( fnames, fids, dbid )
      duplicates = {}
      if @fids
         cslist = @fids.join( "." )
         ridFields = lookupFieldsByType( "recordid" )
         if ridFields and ridFields.last
           cslist << "."
           recordidFid = ridFields.last.attributes["id"]
           cslist << recordidFid
           valuesUsed = {}
            doQuery( @dbid, nil, nil, nil, cslist ) { |record|
               next unless record.is_a?( REXML::Element) and record.name == "record"
               recordID = ""
               recordValues = []
               record.each { |f|
                  if f.is_a?( REXML::Element) and f.name == "f" and  f.has_text?
                     if recordidFid == f.attributes["id"]
                        recordID = f.text
                     else
                        recordValues << f.text
                     end
                  end
              }
              if not valuesUsed[ recordValues ]
                 valuesUsed[ recordValues ] = []
              end
              valuesUsed[ recordValues ] << recordID
            }

            valuesUsed.each{ |valueArray, recordArray|
               if recordArray.length > 1
                 duplicates[ valueArray ] = recordArray
               end
            }
         end
      end
      if block_given?
         duplicates.each{ |duplicate| yield duplicate }
      else
         duplicates
      end
   end

   # Finds records with the same values in a specified
   # list of fields and deletes all but the first or last duplicate record.
   # The field list may be a list of field IDs or a list of field names.
   # The 'options' parameter can be used to keep the oldest record instead of the
   # newest record, and to control whether to ignore the case of field values when
   # deciding which records are duplicates.  Returns the number of records deleted.
   def deleteDuplicateRecords(  fnames, fids = nil, options = nil, dbid = @dbid )
      num_deleted = 0
      if options and not options.is_a?( Hash )
         raise "deleteDuplicateRecords: 'options' parameter must be a Hash"
      else
         options = {}
         options[ "keeplastrecord" ] = true
         options[ "ignoreCase" ] = true
      end
      findDuplicateRecordIDs( fnames, fids, dbid, options[ "ignoreCase" ] ) { |dupeValues, recordIDs|
         if options[ "keeplastrecord" ]
           recordIDs[0..(recordIDs.length-2)].each{ |rid| num_deleted += 1 if deleteRecord( dbid, rid ) }
         elsif  options[ "keepfirstrecord" ]
           recordIDs[1..(recordIDs.length-1)].each{ |rid| num_deleted += 1 if deleteRecord( dbid, rid ) }
         end
      }
      num_deleted
   end

   # Make one or more copies of a record.
   def copyRecord(  rid, numCopies = 1, dbid = @dbid )
      clearFieldValuePairList
      getRecordInfo( dbid, rid ) { |field|
         if field and field.elements[ "value" ] and field.elements[ "value" ].has_text?
            if field.elements[ "fid" ].text.to_i > 5 #skip built-in fields
               addFieldValuePair( field.elements[ "name" ].text, nil, nil, field.elements[ "value" ].text )
            end
         end
      }
      newRecordIDs = []
      if @fvlist and @fvlist.length > 0
         numCopies.times {
           addRecord( dbid, @fvlist )
           newRecordIDs << @rid if @rid and @update_id
         }
      end
      if block_given?
         newRecordIDs.each{ |newRecordID| yield newRecordID }
      else
         newRecordIDs
      end
   end

   # Import data directly from an Excel file into a table
   # The field names are expected to be on line 1 by default.
   # By default, data will be read starting from row 2 and ending on the first empty row.
   # Commas in field values will be converted to semi-colons.
   # e.g. importFromExcel( @dbid, "my_spreadsheet.xls", 'h' )
   def importFromExcel( dbid,excelFilename,lastColumn = 'j',lastDataRow = 0,worksheetNumber = 1,fieldNameRow = 1,firstDataRow = 2,firstColumn = 'a')
      num_recs_imported = 0
      if require 'win32ole'
         if FileTest.readable?( excelFilename )
            getSchema( dbid )

            excel = WIN32OLE::new( 'Excel.Application' )
            workbook = excel.Workbooks.Open( excelFilename )
            worksheet = workbook.Worksheets( worksheetNumber )
            worksheet.Select

            fieldNames = nil
            rows = nil
            skipFirstRow = nil

            if fieldNameRow > 0
               fieldNames = worksheet.Range("#{firstColumn}#{fieldNameRow}:#{lastColumn}#{fieldNameRow}")['Value']
               skipFirstRow = true
            end

            if lastDataRow <= 0
               lastDataRow = 1
               while worksheet.Range("#{firstColumn}#{lastDataRow}")['Value']
                  lastDataRow += 1  
               end
            end
      
            if firstDataRow > 0 and lastDataRow >= firstDataRow
               rows = worksheet.Range("#{firstColumn}#{firstDataRow}:#{lastColumn}#{lastDataRow}")['Value']
            end
      
            workbook.Close
            excel.Quit

            csvData = ""
            targetFieldIDs = []

            if fieldNames and fieldNames.length > 0
                 fieldNames.each{ |fieldNameRow|
                  fieldNameRow.each{ |fieldName|
                     if fieldName
                        fieldName.gsub!( ",", ";" ) #strip commas
                        csvData << "#{fieldName},"
                             targetFieldIDs << lookupFieldIDByName( fieldName )
                     else
                        csvData << ","
                     end
                  }
                  csvData[-1] = "\n"
               }
            end

            rows.each{ |row|
               row.each{ |cell|
                 if cell
                     cell = cell.to_s
                     cell.gsub!( ",", ";" ) #strip commas
                     csvData << "#{cell},"
                 else
                     csvData << ","
                 end
               }
               csvData[-1] = "\n"
             }

             clist = targetFieldIDs.join( '.' )
             num_recs_imported = importFromCSV( dbid, formatImportCSV( csvData ), clist, skipFirstRow )
         else
            raise "importFromExcel: '#{excelFilename}' is not a readable file."
         end
      end
      num_recs_imported
   end

   # Import data directly from an Excel file into the active table.
   def _importFromExcel(excelFilename,lastColumn = 'j',lastDataRow = 0,worksheetNumber = 1,fieldNameRow = 1,firstDataRow = 2,firstColumn = 'a')
      importFromExcel( @dbid, excelFilename, lastColumn, lastDataRow, worksheetNumber, fieldNameRow, firstDataRow, firstColumn )
   end

   # Add records from lines in a CSV file.
   # If dbid is not specified, the active table will be used.
   # values in subsequent lines.  The file must not contain commas inside field names or values.
   def importCSVFile( filename, dbid = @dbid, targetFieldNames = nil, validateLines = true )
      importSVFile( filename, ",", dbid, targetFieldNames, validateLines )
   end

   # Import records from a text file in Tab-Separated-Values format.
   def importTSVFile( filename, dbid = @dbid, targetFieldNames = nil, validateLines = true )
      importSVFile( filename, "\t", dbid, targetFieldNames, validateLines )
   end

   # Add records from lines in a separated values text file, using a specified field name/value separator.
   #
   # e.g. importSVFile( "contacts.txt", "::", "dhnju5y7", [ "Name", "Phone", "Email" ] )
   #
   # If targetFieldNames is not specified, the first line in the file
   # must be a list of field names that match the values in subsequent lines.
   #
   # If there are no commas in any of the field names or values, the file will be
   # treated as if it were a CSV file and imported using the QuickBase importFromCSV API call.
   # Otherwise, records will be added using addRecord() for each line.
   # Lines with the wrong number of fields will be skipped.
   # Double-quoted fields can contain the field separator, e.g. f1,"f,2",f3
   # Spaces will not be trimmed from the beginning or end of field values.
   def importSVFile( filename, fieldSeparator = ",", dbid = @dbid, targetFieldNames = nil, validateLines = true )
      num_recs_imported = 0
      if FileTest.readable?( filename )
         if dbid
            getSchema( dbid )

            targetFieldIDs = []

            if targetFieldNames and targetFieldNames.is_a?( Array )
               targetFieldNames.each{ |fieldName|
                  targetFieldIDs << lookupFieldIDByName( fieldName )
               }
               return 0 if targetFieldIDs.length != targetFieldNames.length
            end

            useAddRecord = false
            invalidLines = []
            validLines = []

            linenum = 1
            IO.foreach( filename ){ |line|

               if fieldSeparator != "," and line.index( "," )
                  useAddRecord = true
               end

               if linenum == 1 and targetFieldNames.nil?
                  targetFieldNames = splitString( line, fieldSeparator )
                  targetFieldNames.each{ |fieldName| fieldName.strip!
                     targetFieldIDs << lookupFieldIDByName( fieldName )
                  }
                  return 0 if targetFieldIDs.length != targetFieldNames.length
               else
                  fieldValues = splitString( line, fieldSeparator )
                  if !validateLines 
                     validLines[ linenum ] = fieldValues
                  elsif validateLines and fieldValues.length == targetFieldIDs.length
                     validLines[ linenum ] = fieldValues
                  else
                     invalidLines[ linenum ] = fieldValues
                  end
               end

               linenum += 1
            }

            if targetFieldIDs.length > 0 and validLines.length > 0
               if useAddRecord
                  validLines.each{ |line|
                     clearFieldValuePairList
                     targetFieldIDs.each_index{ |i|
                        addFieldValuePair( nil, targetFieldIDs[i], nil, line[i] )
                     }
                     addRecord( dbid, @fvlist )
                     num_recs_imported += 1 if @rid
                  }
               else
                  csvdata = ""
                  validLines.each{ |line| 
                     if line 
                        csvdata << line.join( ',' ) 
                        csvdata << "\n"
                     end
                  }
                  clist = targetFieldIDs.join( '.' )
                  num_recs_imported = importFromCSV( dbid, formatImportCSV( csvdata ), clist )
               end
            end

         end
      end
      return num_recs_imported, invalidLines
   end

   # Make a CSV file using the results of a query.
   # Specify a different separator in the second paramater.
   # Fields containing the separator will be double-quoted.
   #
   # e.g. makeSVFile( "contacts.txt", "\t", nil ) 
   # e.g. makeSVFile( "contacts.txt", ",", "dhnju5y7", nil, nil, "List Changes" ) 
   def makeSVFile( filename, fieldSeparator = ",", dbid = @dbid, query = nil, qid = nil, qname = nil )
      File.open( filename, "w" ) { |file|

         if dbid
            doQuery( dbid, query, qid, qname )
         end

         if @records and @fields

            # ------------- write field names on first line ----------------
            output = ""
            fieldNamesBlock = proc { |element|
               if element.is_a?(REXML::Element) and element.name == "label" and element.has_text?
                  output << "#{element.text}#{fieldSeparator}"
               end
            }
            processChildElements( @fields, true, fieldNamesBlock )

            output << "\n"
            output.sub!( "#{fieldSeparator}\n", "\n" )
            file.write( output )

            # ------------- write records ----------------
            output = ""
            valuesBlock = proc { |element|
               if element.is_a?(REXML::Element)
                  if element.name == "record"
                     if output.length > 1
                        output << "\n"
                        output.sub!( "#{fieldSeparator}\n", "\n" )
                        file.write( output )
                     end
                     output = ""
                  elsif  element.name == "f"
                     if  element.has_text?
                        text = element.text
                        text.gsub!("<BR/>","\n")
                        text = "\"#{text}\"" if text.include?( fieldSeparator )
                        output << "#{text}#{fieldSeparator}"
                     else
                        output << "#{fieldSeparator}"
                     end
                  end
               end
            }

            processChildElements( @records, false, valuesBlock )
            if output.length > 1
              output << "\n"
              output.sub!( "#{fieldSeparator}\n", "\n" )
              file.write( output )
              output = ""
            end
         end
      }
   end
    
   # Create a CSV file using the records for a Report.
   def makeCSVFileForReport(filename,dbid=@dbid,query=nil,qid=nil,qname=nil)
      csv = getCSVForReport(dbid,query,qid,qname)
      File.open(filename,"w"){|f|f.write(csv || "")}
   end
   
   # Get the CSV data for a Report.
   def getCSVForReport(dbid,query=nil,qid=nil,qname=nil)
      genResultsTable(dbid,query,nil,nil,nil,nil,"csv",qid,qname)
   end  

   # Upload a file into a new record in a table.
   # Additional field values can optionally be set.
   # e.g. uploadFile( "dhnju5y7", "contacts.txt", "Contacts File", { "Notes" => "#{Time.now}" }
   def uploadFile( dbid, filename, fileAttachmentFieldName, additionalFieldsToSet = nil )
      if dbid and filename and fileAttachmentFieldName
         clearFieldValuePairList
         addFieldValuePair( fileAttachmentFieldName, nil, filename, nil )
         if additionalFieldsToSet and additionalFieldsToSet.is_a?( Hash )
            additionalFieldsToSet.each{ |fieldName,fieldValue|
               addFieldValuePair( fieldName, nil, nil, fieldValue )
            }
         end
         return addRecord( dbid, @fvlist )
      end
      nil
   end
   
   # Add a File Attachment into a new record in a table, using a string containing the file contents.
   # Additional field values can optionally be set.
   # e.g. uploadFile( "dhnju5y7", "contacts.txt", "fred: 1-222-333-4444", "Contacts File", { "Notes" => "#{Time.now}" }
   def uploadFileContents( dbid, filename, fileContents, fileAttachmentFieldName, additionalFieldsToSet = nil )
      if dbid and filename and fileAttachmentFieldName
         clearFieldValuePairList
         addFieldValuePair( fileAttachmentFieldName, nil, filename, fileContents )
         if additionalFieldsToSet and additionalFieldsToSet.is_a?( Hash )
            additionalFieldsToSet.each{ |fieldName,fieldValue|
               addFieldValuePair( fieldName, nil, nil, fieldValue )
            }
         end
         return addRecord( dbid, @fvlist )
      end
      nil
   end
   
   # Upload a file into a new record in the active table.
   # e.g. uploadFile( "contacts.txt", "Contacts File" )
   def _uploadFile( filename, fileAttachmentFieldName )
      uploadFile( @dbid, filename, fileAttachmentFieldName )
   end

   # Get the URL string for downloading a file from a File Attachment field
   def getFileDownloadURL(dbid, rid, fid, vid = "0",org="www",domain="quickbase",ssl="s")
      "http#{ssl}://#{org}.#{domain}.com/up/#{dbid}/a/r#{rid}/e#{fid}/v#{vid}"
   end

   # Update the file attachment in an existing record in a table.
   # Additional field values can optionally be set.
   # e.g. updateFile( "dhnju5y7", "6", "contacts.txt", "Contacts File", { "Notes" => "#{Time.now}" }
   def updateFile( dbid, rid, filename, fileAttachmentFieldName, additionalFieldsToSet = nil )
      if dbid and rid and filename and fileAttachmentFieldName
         clearFieldValuePairList
         addFieldValuePair( fileAttachmentFieldName, nil, filename, nil )
         if additionalFieldsToSet and additionalFieldsToSet.is_a?( Hash )
            additionalFieldsToSet.each{ |fieldName,fieldValue|
               addFieldValuePair( fieldName, nil, nil, fieldValue )
            }
         end
         return editRecord( dbid, rid, @fvlist )
      end
      nil
   end
   
   # Update the file attachment in an existing record in the active record in the active table.
   # e.g. _updateFile( "contacts.txt", "Contacts File" )
   def _updateFile( filename, fileAttachmentFieldName )
      updateFile( @dbid, @rid, filename, fileAttachmentFieldName )
   end
   
   # Remove the file from a File Attachment field in an existing record.
   # e.g. removeFileAttachment( "bdxxxibz4", "6", "Document" )
   def removeFileAttachment( dbid, rid , fileAttachmentFieldName )
      updateFile( dbid, rid, "delete", fileAttachmentFieldName )
   end  
   
   # Remove the file from a File Attachment field in an existing record in the active table
   # e.g. _removeFileAttachment( "6", "Document" )
   def _removeFileAttachment( rid , fileAttachmentFieldName )
      updateFile( @dbid, rid, "delete", fileAttachmentFieldName )
   end  

   # Translate a simple SQL SELECT statement to a QuickBase query and run it.
   # 
   #  If any supplied field names are numeric, they will be treated as QuickBase field IDs if
   #  they aren't valid field names. 
   #
   # * e.g. doSQLQuery( "SELECT FirstName,Salary FROM Contacts WHERE LastName = "Doe" ORDER BY FirstName )
   # * e.g. doSQLQuery( "SELECT * FROM Books WHERE Author = "Freud" )
   #
   # Note: This method is here primarily for Rails integration.
   # Note: This assumes, like SQL, that your column (i.e. field) names do not contain spaces.
   def doSQLQuery( sqlString, returnOptions = nil )

      ret = nil
      sql = sqlString.dup
      dbid = nil
      clist = nil
      slist = nil
      state = nil
      dbname = ""
      columns = []
      sortFields = []
      limit = nil
      offset = nil
      options = nil
      getRecordCount = false

      queryFields = []
      query = "{'["
      queryState = "getFieldName"
      queryField = ""
      
      sql.split(' ').each{ |token|
         case token
            when "SELECT" then state = "getColumns";next
            when "count(*)" then state = "getCount";next
            when "FROM" then state = "getTable";next
            when "WHERE" then state = "getFilter" ;next
            when "ORDER" then state = "getBy";next
            when "BY" then state = "getSort";next
            when "LIMIT" then state = "getLimit";next
            when "OFFSET" then state = "getOffset";next
         end
         if state == "getColumns"
            if token.index( "," )
               token.split(",").each{ |column| columns << column if column.length > 0 }
            else
               columns << "#{token} "
            end
         elsif state == "getCount"
            getRecordCount = true
         elsif state == "getTable"
            dbname = token.strip
         elsif state == "getFilter"
            if token == "AND"
               query.strip!
               query << "'}AND{'["
               queryState = "getFieldName"
            elsif token == "OR"
               query.strip!
               query << "'}OR{'["
               queryState = "getFieldName"
            elsif token == "="
               query << "]'.TV.'"
               queryState = "getFieldValue"
               queryFields << queryField
               queryField  = ""
            elsif token == "<>" or token == "!="
               query << "]'.XTV.'"
               queryState = "getFieldValue"
               queryFields << queryField
               queryField  = ""
            elsif queryState == "getFieldValue"
               fieldValue = token.dup
               if fieldValue[-2,2] == "')"
                  fieldValue[-1,1] = ""
               end
               if fieldValue[-1] == "'"
                  fieldValue.gsub!("'","")
                  query << "#{fieldValue}"
               else   
                  fieldValue.gsub!("'","")
                  query << "#{fieldValue} "
               end
            elsif queryState == "getFieldName"
               fieldName = token.gsub("(","").gsub(")","").gsub( "#{dbname}.","")
               query << "#{fieldName}"
               queryField << "#{fieldName} "
            end
         elsif state == "getSort"
            if token.contains( "," )
               token.split(",").each{ |sortField| sortFields << sortField if sortField.length > 0 }
            else
               sortFields << "#{token} "
            end
         elsif state == "getLimit"
            limit = token.dup
            if options.nil?
               options = "num-#{limit}" 
            else
               options << ".num-#{limit}"
            end
         elsif state == "getOffset"   
            offset = token.dup
            if options.nil?
               options = "skp-#{offset}" 
            else
               options << ".skp-#{offset}"
            end
         end
      }
      
      if dbname and @dbid.nil?
         dbid = findDBByname( dbname )
      else
         dbid = lookupChdbid( dbname )
      end
      dbid ||= @dbid

      if dbid
         getDBInfo( dbid )
         getSchema( dbid )
         if columns.length > 0
            if columns[0] == "* "
               columns = getFieldNames( dbid )
            end
            columnNames = []
            columns.each{ |column|
               column.strip!
               fid = lookupFieldIDByName( column )
               if fid.nil? and column.match(/[0-9]+/)
                  fid = column
                  columnNames << lookupFieldNameFromID(fid)
               else   
                  columnNames << column
               end
               if fid
                  if clist
                     clist << ".#{fid}"
                  else
                     clist = fid
                  end
               end
            }
         end
         if sortFields.length > 0
            sortFields.each{ |sortField|
               sortField.strip!
               fid = lookupFieldIDByName( sortField )
               if fid.nil?
                  fid = sortField if sortField.match(/[0-9]+/)
               end
               if fid 
                  if slist
                     slist << ".#{fid}"
                  else
                     slist = fid
                  end
               end
            }
         end
         if queryFields.length > 0
            query.strip!
            query << "'}"
            queryFields.each{ |fieldName|
               fieldName.strip!
               fid = lookupFieldIDByName( fieldName )
               if fid
                  query.gsub!( "'[#{fieldName} ]'", "'#{fid}'" )
               end
            }
         else
            query = nil
         end
         if getRecordCount 
            ret = getNumRecords(dbid)
         elsif returnOptions == :Hash
            ret = getAllValuesForFields(dbid, columnNames, query, nil, nil, clist, slist,"structured",options)
         elsif returnOptions == :Array
            ret = getAllValuesForFieldsAsArray(dbid, columnNames, query, nil, nil, clist, slist,"structured",options)
         else
            ret = doQuery( dbid, query, nil, nil, clist, slist, "structured", options )
         end
      end
      ret
   end
   
   # Translate a simple SQL UPDATE statement to a QuickBase editRecord call.
   #
   # Note: This method is here primarily for Rails integration.
   # Note: This assumes, like SQL, that your column (i.e. field) names do not contain spaces.
   # Note: This assumes that Record ID# is the key field in your table.
   def doSQLUpdate(sqlString)
   
      sql = sqlString.dup
      dbname = ""
      state = nil
      fieldName = ""
      fieldValue = ""
      sqlQuery = "SELECT 3 FROM "
      
      clearFieldValuePairList

      sql.split(' ').each{ |token|
         case token
            when "UPDATE" 
               state = "getTable" unless state == "getFilter"
               next
            when "SET" 
               state = "getFieldName"  unless state == "getFilter"
               next
            when "=" 
               sqlQuery << " = " if state == "getFilter"
               state = "getFieldValue" unless state == "getFilter"
               next
            when "WHERE" 
               sqlQuery << " WHERE "
               state = "getFilter"
               next
         end
         if state == "getTable"
            dbname = token.dup
            sqlQuery << dbname
         elsif state  == "getFieldName" 
            fieldName = token.gsub('[','').gsub(']','')
         elsif state  == "getFieldValue" 
            test = token
            if test[-1,1] == "'" or test[-2,2] == "',"
               fieldValue << token
               if fieldValue[-2,2] == "',"
                  state = "getFieldName"
                  fieldValue.gsub!("',","")
               end
               fieldValue.gsub!("'","")
               if fieldName.length > 0 
                  addFieldValuePair(fieldName,nil,nil,fieldValue)
                  fieldName = ""
                  fieldValue = ""
               end
            else   
               fieldValue << "#{token} "
            end
         elsif state == "getFilter"   
            sqlQuery << token
         end
      }
      
      rows = doSQLQuery(sqlQuery,:Array)
      if rows and @dbid and @fvlist
         idFieldName = lookupFieldNameFromID("3")
         rows.each{ |row|
            recordID = row[idFieldName]
            editRecord(@dbid,recordID,@fvlist) if recordID
         }
      end
      
   end
   
   # Translate a simple SQL INSERT statement to a QuickBase addRecord call.
   #
   # Note: This method is here primarily for Rails integration.
   # Note: This assumes, like SQL, that your column (i.e. field) names do not contain spaces.
   def doSQLInsert(sqlString)
   
      sql = sqlString.dup
      dbname = ""
      state = nil
      fieldName = ""
      fieldValue = ""
      fieldNames = []
      fieldValues = []
      index = 0
      
      clearFieldValuePairList
      
      sql.gsub!("("," ")
      sql.gsub!(")"," ")

      sql.split(' ').each{ |token|
         case token
            when "INSERT", "INTO" 
               state = "getTable"
               next
            when "VALUES" 
               state = "getFieldValue"
               next
         end
         if state == "getTable"
            dbname = token.strip
            state =   "getFieldName"
         elsif state  == "getFieldName" 
            fieldName = token.dup
            fieldName.gsub!("],","")
            fieldName.gsub!('[','')
            fieldName.gsub!(']','')
            fieldName.gsub!(',','')
            fieldNames << fieldName
         elsif state  == "getFieldValue" 
            test = token.dup
            if test[-1,1] == "'" or test[-2,2] == "',"
               fieldValue << token.dup
               if fieldValue[-2,2] == "',"
                  fieldValue.gsub!("',",'')
               end
               fieldValue.gsub!('\'','')
               if fieldValue.length > 0 and fieldNames[index] 
                  addFieldValuePair(fieldNames[index],nil,nil,fieldValue)
                  fieldName = ""
                  fieldValue = ""
               end
               index += 1
            elsif token == ","
               addFieldValuePair(fieldNames[index],nil,nil,"")
               fieldName = ""
               fieldValue = ""
               index += 1
            else
               fieldValue << "#{token.dup} "
            end
         end
      }
      
      if dbname and @dbid.nil?
         dbid = findDBByname( dbname )
      else
         dbid = lookupChdbid( dbname )
      end
      dbid ||= @dbid

      recordid = nil
      if dbid
         recordid,updateid = addRecord(dbid,@fvlist)
      end   
      recordid
      
   end
   
   # Iterate @records XML and yield only 'record' elements.
   def eachRecord( records = @records )
      if records and block_given?
         records.each { |record|
            if record.is_a?( REXML::Element) and record.name == "record"
               @record = record
               yield record
            end
         }
      end
      nil
   end
   
   # Iterate record XML and yield only 'f' elements.
   def eachField( record = @record )
      if record and block_given?
         record.each{ |field|
             if field.is_a?( REXML::Element) and field.name == "f" and field.attributes["id"]
                @field = field
                yield field
             end
         }
      end
      nil      
   end
   
   # Log requests to QuickBase and responses from QuickBase in a file.
   # Useful for utilities that run unattended.
   def logToFile( filename )
      setLogger( Logger.new( filename ) )
   end
    
   # Add method aliases that follow the ruby method naming convention.   
   # E.g. sendRequest will be aliased as send_request.
   def alias_methods
     aliased_methods = []
     public_methods.each{|old_method|
       if old_method.match(/[A-Z]+/)
          new_method = old_method.gsub(/[A-Z]+/){|uc| "_#{uc.downcase}"}
          aliased_methods << new_method
          instance_eval( "alias #{new_method} #{old_method}")
       end
     }
     aliased_methods
   end

   # ------------------- End of Helper methods --------------------------------------------------
   # -----------------------------------------------------------------------------------------------

end #class Client ----------------------------------------------------

# To subscribe to events fired by the Client class, derive from this
# class, override handle( event ), and call subscribe( event, self ).
# See Client.subscribe() for a list of events.
class EventHandler
   def handle( event )
      puts event if event and event.is_a?( String )
   end
end

# To log QuickBase requests and responses to a file, make an instance
# of this class and call Client.setLogger( loggerInstance ).
# Call Client.setLogger( nil ) to turn logging off.
# The log file is written in CSV format to make it importable by QuickBase.
class Logger
  attr_reader :file, :filename, :append

  def initialize( filename, append = true )
     @requestEntryNum = @responseEntryNum = 0
     changeLogFile( filename, append )
  end

  def closeLogFile()
     if @file
        @file.close
        @file = nil
        @filename = nil
        @append = true
        @requestEntryNum = @responseEntryNum = 0
     end
  end

  def changeLogFile( filename, append = true )
     if @file and @filename and @filename != filename
        closeLogFile()
     end
     begin
        @append = append
        skipHeader = (@append == true and FileTest.exist?( filename ))
        @file = File.open( filename, @append ? "a" : "w" )
        @filename = filename
        @file.print( "entry,request time,dbid,api,request,response time, response" ) unless skipHeader
     rescue StandardError => e
        closeLogFile()
        puts "Logger error: #{e}"
     end
  end

  def logRequest( dbidForRequestURL, api_Request, requestXML )
     if @file
        @requestEntryNum += 1
        entry =  "\n#{@requestEntryNum},"
        entry << "#{getTimeString()},"
        entry << "#{dbidForRequestURL},"
        entry << "#{api_Request},"

        maxChars = requestXML.length > 256 ? 256 : requestXML.length

        request = requestXML[0,maxChars]
        request.gsub!( ",", "_" )
        entry << "#{request}"

        @file.print( entry )
     end
  end

  def logResponse( error, responseXML )
     if @file
        @responseEntryNum += 1

        if @responseEntryNum != @requestEntryNum
           entry =  "\n#{@responseEntryNum},,,,#{getTimeString()},"
        else
           entry =  ",#{getTimeString()},"
        end

        maxChars = responseXML.length > 256 ? 256 : responseXML.length

        response = responseXML[0,maxChars]
        response.gsub!( ",", "_" )
        entry << "#{response}"

        @file.print( entry )
     end
  end

  def getTimeString()
     t = Time.now
     t.strftime( "%Y-%m-%d-%H-%M-%S" )
  end

end # class Logger --------------

end #module QuickBase ---------------------------------------------

# This enables finding XML elements recursively using Ruby method syntax
class REXML::Element

  attr_accessor :element_hash

  def method_missing(method_name,*method_args)
    ret = nil 
    if elements
       if method_args and method_args.length > 0
          if method_args[0].length > 1
             searchProc = proc { |e| 
                if e.is_a?(REXML::Element) and e.name == method_name.to_s and e.attributes
                  if e.attributes[method_args[0][0].to_s] and e.attributes[method_args[0][0].to_s] == method_args[0][1].to_s
                     ret = e 
                  end
                end  
             }
          else  
             searchProc = proc { |e| 
                if e.is_a?(REXML::Element) and e.name == method_name.to_s and e.attributes
                  if e.attributes["id"] and e.attributes["id"] == method_args[0][0].to_s
                     ret = e 
                  end
                  if ret.nil? and e.attributes["name"] and e.attributes["name"] == method_args[0][0].to_s
                    ret = e
                  end  
                end  
             }
          end   
       else
          searchProc = proc { |e| 
             if e.is_a?(REXML::Element) and e.name == method_name.to_s 
               ret = e 
             end  
          }
       end
    end 
    processChildElements( self, false, searchProc ) 
    if ret and !ret.has_elements? and ret.has_text?
       ret = ret.text.dup 
    end
    ret
  end

  # Convert REXML Element tree into Hash.
  # Sibling elements with duplicate names become Arrays.
  def to_h(include_element=proc{|e|true})
    to_hash_proc = proc {|e|
       if e.is_a?(REXML::Element) and include_element.call(e)  
         e.element_hash = {}
         e.element_hash["name"] = e.name
         if e.has_attributes?
            e.element_hash["attributes"] = {}
            e.attributes.each{|k,v|e.element_hash["attributes"][k]=v}
         end
         if e.has_text?
           text = e.text.strip
           e.element_hash["value"] = text if text.length > 0
         end
         if e.parent and e.parent.is_a?(REXML::Element)
           if e.parent.element_hash and e.parent.element_hash[e.name]
              if e.parent.element_hash[e.name].is_a?(Array)
                e.parent.element_hash[e.name] << e.element_hash
              elsif e.parent.element_hash
                tmp = e.parent.element_hash[e.name].dup
                e.parent.element_hash[e.name] = []
                e.parent.element_hash[e.name] << tmp
                e.parent.element_hash[e.name] << e.element_hash
              end
           elsif e.parent.element_hash
             e.parent.element_hash[e.name] = e.element_hash
           end
         end
       end
    }
    processChildElements( self, false, to_hash_proc )
    element_hash
  end  
  
  def processChildElements( element, leafElementsOnly, block )
      if element
         if element.is_a?( Array )
            element.each{ |e| processChildElements( e, leafElementsOnly, block ) }
         elsif element.is_a?( REXML::Element ) and element.has_elements?
            block.call( element ) if not leafElementsOnly
            element.each{ |e|
               if e.is_a?( REXML::Element ) and e.has_elements?
                 processChildElements( e, leafElementsOnly, block )
               else
                 block.call( e )
               end
            }
         end
       end
  end   
end


if __FILE__ == $0 and ARGV.length > 0
   if ARGV[0] == "run"
      if ARGV.length > 1
        puts "Please type 'ruby QuickBaseCommandLineClient.rb run #{ARGV[1]}'"
      else
        puts "Please type 'ruby QuickBaseCommandLineClient.rb run'"
      end
   elsif ARGV[0] == "runwebclient"
      ARGV.shift
      if ARGV.length > 1
         puts "Please type 'ruby QuickBaseWebClient.rb runwebclient #{ARGV[0]} #{ARGV[1]}'"
      elsif ARGV.length > 0
         puts "Please type 'ruby QuickBaseWebClient.rb runwebclient #{ARGV[0]}'"
      else
         puts "Please type 'ruby QuickBaseWebClient.rb runwebclient #{ARGV[0]}'"
      end
   end
end
